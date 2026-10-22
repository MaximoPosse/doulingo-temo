// Comprobaciones de la pantalla de acceso que NO dependen de la configuración
// del proyecto (correo, SMTP, etc.).
//
//   node tests/e2e/auth_ui.mjs
//
// Verifica la ruta protegida, el acceso como invitado, los mensajes de error
// claros y las reglas del alias.

import { BASE_URL, createRunner, launchBrowser, sleep } from './helpers.mjs'

const runner = createRunner(
  '=== Pantalla de acceso (sin configuración externa) ==='
)
const browser = await launchBrowser()
const pageErrors = []

// Cada comprobación usa un contexto nuevo: así una sesión creada en un paso
// (por ejemplo, el acceso como invitado) no tapa los formularios del siguiente.
const newPage = async () => {
  const context = await browser.createBrowserContext()
  const page = await context.newPage()
  page.on('pageerror', error => pageErrors.push(String(error)))
  return page
}

const text = page =>
  page.evaluate(() => document.body.innerText.replace(/\s+/g, ' '))

// Espera a que aparezca un texto (las llamadas a Supabase tardan).
const waitForText = async (page, pattern, timeout = 20000) => {
  const limit = Date.now() + timeout
  let current = ''
  while (Date.now() < limit) {
    current = await text(page)
    if (pattern.test(current)) return current
    await sleep(500)
  }
  return current
}

try {
  // 1. Ruta protegida sin sesión.
  const guardPage = await newPage()
  await guardPage.goto(`${BASE_URL}/#/perfil`, { waitUntil: 'networkidle0' })
  await sleep(1500)
  const hash = await guardPage.evaluate(() => location.hash)
  runner.check(
    'Ruta protegida /perfil redirige a /acceso sin sesión',
    hash.includes('/acceso'),
    hash
  )

  // 2. Acceso como invitado: debe funcionar o explicar cómo habilitarlo.
  const guestPage = await newPage()
  await guestPage.goto(`${BASE_URL}/#/acceso`, { waitUntil: 'networkidle0' })
  await sleep(1000)
  await guestPage.evaluate(() => {
    const button = [...document.querySelectorAll('button')].find(candidate =>
      candidate.innerText.includes('INVITADO')
    )
    button?.click()
  })
  await sleep(3000)
  const guestText = await waitForText(
    guestPage,
    /Sesión activa|Mi cuenta|no está habilitado|Anonymous/i
  )
  runner.check(
    'El acceso como invitado funciona (o explica cómo habilitarlo)',
    /no está habilitado|Anonymous/i.test(guestText) ||
      /Sesión activa|Mi cuenta/i.test(guestText),
    guestText.slice(0, 180)
  )

  // 3. Credenciales inválidas -> mensaje claro.
  const loginPage = await newPage()
  await loginPage.goto(`${BASE_URL}/#/acceso`, { waitUntil: 'networkidle0' })
  await sleep(800)
  await loginPage.evaluate(() => {
    const tab = [...document.querySelectorAll('.q-tab')].find(candidate =>
      candidate.innerText.includes('Ingresar')
    )
    tab?.click()
  })
  await sleep(700)
  await loginPage.evaluate(() => {
    const inputs = [...document.querySelectorAll('input')]
    const mail = inputs.find(input => input.type === 'email')
    const pass = inputs.find(input => input.type === 'password')
    const setValue = (element, value) => {
      const setter = Object.getOwnPropertyDescriptor(
        window.HTMLInputElement.prototype,
        'value'
      ).set
      setter.call(element, value)
      element.dispatchEvent(new Event('input', { bubbles: true }))
    }
    if (mail) setValue(mail, 'alguien@example.com')
    if (pass) setValue(pass, 'clave-incorrecta')
  })
  await sleep(400)
  await loginPage.evaluate(() => {
    const button = [...document.querySelectorAll('button')].find(
      candidate => candidate.innerText.trim() === 'ENTRAR'
    )
    button?.click()
  })
  await sleep(3000)
  const loginText = await waitForText(
    loginPage,
    /incorrecto|Correo o contraseña/i
  )
  runner.check(
    'Credenciales inválidas muestran mensaje claro (sin datos crudos)',
    /incorrecto|Correo o contraseña/i.test(loginText) &&
      !/AuthApiError|status: 400/i.test(loginText),
    loginText.slice(0, 200)
  )

  // 4. El registro explica las reglas del alias.
  const registerPage = await newPage()
  await registerPage.goto(`${BASE_URL}/#/acceso`, { waitUntil: 'networkidle0' })
  await sleep(700)
  await registerPage.evaluate(() => {
    const tab = [...document.querySelectorAll('.q-tab')].find(candidate =>
      candidate.innerText.includes('Crear cuenta')
    )
    tab?.click()
  })
  await sleep(700)
  const registerText = await text(registerPage)
  runner.check(
    'El registro explica las reglas del alias',
    /3 a 20 caracteres/.test(registerText),
    registerText.slice(0, 160)
  )

  runner.check(
    'Sin errores de página',
    pageErrors.length === 0,
    pageErrors.join(' | ')
  )
} catch (error) {
  runner.check('Recorrido sin excepciones', false, error.message)
}

await browser.close()
process.exit(runner.summary('UI AUTH') ? 1 : 0)
