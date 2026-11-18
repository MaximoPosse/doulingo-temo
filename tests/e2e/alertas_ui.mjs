// Acceso obligatorio y alertas emergentes.
//
//   node tests/e2e/serve.mjs   (en otra terminal)
//   node tests/e2e/alertas_ui.mjs
//
// Sin sesión, cualquier pantalla de la app (cursos, lecciones, expo, perfil)
// manda a la pantalla de acceso con una alerta. Al entrar como invitado, al
// crear una cuenta, al iniciar sesión y al cerrar sesión sale una alerta.

import crypto from 'node:crypto'

import { BASE_URL, createRunner, launchBrowser, sleep } from './helpers.mjs'

const runner = createRunner('Acceso obligatorio y alertas')
const browser = await launchBrowser()

async function alertas(page) {
  return page.$$eval('.q-notification', nodos =>
    nodos.map(n => n.innerText.replace(/\s+/g, ' ').trim())
  )
}

async function esperarAlerta(page, patron, ms = 15000) {
  const limite = Date.now() + ms
  while (Date.now() < limite) {
    const textos = await alertas(page)
    if (textos.some(t => patron.test(t))) return true
    await sleep(250)
  }
  return false
}

async function tocarBoton(page, patron) {
  for (const boton of await page.$$('.q-btn')) {
    const texto = await boton.evaluate(el => el.textContent)
    if (patron.test(texto)) {
      await boton.evaluate(el => el.scrollIntoView({ block: 'center' }))
      await boton.click()
      return true
    }
  }
  return false
}

try {
  const contexto = await browser.createBrowserContext()
  const page = await contexto.newPage()
  await page.setViewport({ width: 390, height: 844, isMobile: true })

  // 1. Sin sesión, las pantallas protegidas mandan al acceso con una alerta.
  const protegidas = [
    '/cursos',
    '/cursos/javascript',
    '/expo',
    '/expo/50000000-0000-0000-0000-000000000010',
    '/perfil'
  ]
  for (const ruta of protegidas) {
    await page.goto(`${BASE_URL}/#${ruta}`, { waitUntil: 'networkidle0' })
    await sleep(600)
    const enAcceso = await page.evaluate(() =>
      location.hash.includes('/acceso')
    )
    runner.check(`sin sesión: ${ruta} manda al acceso`, enAcceso)
    runner.check(
      `sin sesión: ${ruta} muestra una alerta`,
      await esperarAlerta(
        page,
        /entr[aá] como invitado o cre[aá] una cuenta/i,
        5000
      )
    )
  }

  // El inicio, el acceso y el ranking público siguen abiertos.
  for (const ruta of ['/', '/ranking']) {
    await page.goto(`${BASE_URL}/#${ruta}`, { waitUntil: 'networkidle0' })
    await sleep(600)
    const quedo = await page.evaluate(
      r => (r === '/' ? location.hash === '#/' : location.hash.includes(r)),
      ruta
    )
    runner.check(`sin sesión: ${ruta} se puede ver`, quedo)
  }

  // 2. Entrar como invitado: alerta y pasa a los cursos.
  await page.goto(`${BASE_URL}/#/cursos`, { waitUntil: 'networkidle0' })
  await page.waitForSelector('.dl-auth__card', { timeout: 20000 })
  await tocarBoton(page, /continuar como invitado/i)
  runner.check(
    'invitado: sale la alerta "Entraste como invitado"',
    await esperarAlerta(page, /entraste como invitado/i)
  )
  await page.waitForFunction(() => location.hash.includes('/cursos'), {
    timeout: 20000
  })
  runner.check('invitado: después de entrar va a lo que se quería abrir', true)

  // 3. Cerrar sesión: alerta y vuelve al acceso.
  await page.goto(`${BASE_URL}/#/perfil`, { waitUntil: 'networkidle0' })
  await page.waitForFunction(
    () => /cerrar sesi/i.test(document.body.textContent),
    { timeout: 30000 }
  )
  await tocarBoton(page, /cerrar sesi/i)
  runner.check(
    'cerrar sesión: sale la alerta "Cerraste sesión"',
    await esperarAlerta(page, /cerraste sesi/i)
  )

  // 4. Crear cuenta: alerta.
  const id = Date.now().toString(36)
  const clave = crypto.randomBytes(9).toString('base64url')
  await page.goto(`${BASE_URL}/#/acceso`, { waitUntil: 'networkidle0' })
  await page.evaluate(() =>
    [...document.querySelectorAll('.q-tab')]
      .find(el => /crear cuenta/i.test(el.textContent))
      ?.click()
  )
  await sleep(500)
  const campos = []
  for (const campo of await page.$$('.q-tab-panel input')) {
    if (await campo.isVisible()) campos.push(campo)
  }
  await campos[0].type(`e2e_al_${id}`)
  await campos[1].type(`e2e-al-${id}@example.com`)
  await campos[2].type(clave)
  await page.evaluate(() =>
    [...document.querySelectorAll('.q-btn')]
      .find(el => /crear cuenta/i.test(el.textContent) && !el.closest('.q-tab'))
      ?.click()
  )
  runner.check(
    'crear cuenta: sale la alerta "Cuenta creada"',
    await esperarAlerta(page, /cuenta creada/i)
  )

  // 5. Cerrar sesión e iniciar sesión de nuevo: alerta de bienvenida.
  await page.goto(`${BASE_URL}/#/perfil`, { waitUntil: 'networkidle0' })
  await page.waitForFunction(
    () => /cerrar sesi/i.test(document.body.textContent),
    { timeout: 30000 }
  )
  await tocarBoton(page, /cerrar sesi/i)
  await esperarAlerta(page, /cerraste sesi/i)
  await page.goto(`${BASE_URL}/#/acceso`, { waitUntil: 'networkidle0' })
  await page.waitForSelector('.dl-auth__tabs', { timeout: 20000 })
  await page.evaluate(() =>
    [...document.querySelectorAll('.q-tab')]
      .find(el => /ingresar/i.test(el.textContent))
      ?.click()
  )
  await sleep(500)
  const campos2 = []
  for (const campo of await page.$$('.q-tab-panel input')) {
    if (await campo.isVisible()) campos2.push(campo)
  }
  await campos2[0].type(`e2e-al-${id}@example.com`)
  await campos2[1].type(clave)
  await tocarBoton(page, /^\s*entrar\s*$/i)
  runner.check(
    'iniciar sesión: sale la alerta de bienvenida',
    await esperarAlerta(page, /iniciaste sesi/i)
  )
} finally {
  await browser.close()
}
process.exitCode = runner.summary('acceso y alertas') ? 1 : 0
