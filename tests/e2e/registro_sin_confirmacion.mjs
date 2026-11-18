// Registro con correo y usuario SIN confirmación de correo.
//
//   node tests/e2e/serve.mjs   (en otra terminal)
//   node tests/e2e/registro_sin_confirmacion.mjs [cantidad]
//
// Crea varias cuentas de prueba desde la interfaz (correo ficticio + usuario
// + contraseña generada al azar), verifica que se entra al instante, que se
// puede cerrar sesión y volver a ingresar, y que el perfil muestra el usuario.
// Requiere "Confirm email" desactivado en Supabase. Las cuentas quedan en la
// base como cuentas de prueba (correo e2e-...@example.com).

import crypto from 'node:crypto'

import { BASE_URL, createRunner, launchBrowser, sleep } from './helpers.mjs'

const runner = createRunner('Registro sin confirmación de correo')
const cantidad = Number(process.argv[2] ?? 3)
const lote = Date.now().toString(36)

const browser = await launchBrowser()
try {
  for (let i = 1; i <= cantidad; i++) {
    const usuario = `e2e_${lote}_${i}`
    const correo = `e2e-${lote}-${i}@example.com`
    const clave = crypto.randomBytes(9).toString('base64url')

    const context = await browser.createBrowserContext()
    const page = await context.newPage()
    await page.setViewport({ width: 390, height: 844, isMobile: true })
    await page.goto(`${BASE_URL}/#/acceso`, { waitUntil: 'networkidle0' })

    // Pestaña "Crear cuenta"
    await page.evaluate(() => {
      const tab = [...document.querySelectorAll('.q-tab')].find(el =>
        /crear cuenta/i.test(el.textContent)
      )
      tab?.click()
    })
    await sleep(500)
    const campos = await page.$$('.q-tab-panel input')
    // En la pestaña activa: usuario, correo y contraseña (los visibles).
    const visibles = []
    for (const campo of campos) {
      if (await campo.isVisible()) visibles.push(campo)
    }
    if (visibles.length < 3) {
      runner.check(`cuenta ${i}: formulario de registro visible`, false)
      await context.close()
      continue
    }
    await visibles[0].click({ clickCount: 3 })
    await visibles[0].type(usuario)
    await visibles[1].type(correo)
    await visibles[2].type(clave)
    await page.evaluate(() => {
      const boton = [...document.querySelectorAll('.q-btn')].find(
        el => /crear cuenta/i.test(el.textContent) && !el.closest('.q-tab')
      )
      boton?.click()
    })

    // Entra al instante: pasa a /perfil con sesión.
    let enPerfil = false
    for (let t = 0; t < 30 && !enPerfil; t++) {
      await sleep(500)
      enPerfil = page.url().includes('/perfil')
    }
    const aviso = await page.evaluate(
      () =>
        document.querySelector('.dl-error-banner, .dl-notice-banner')
          ?.textContent ?? ''
    )
    runner.check(
      `cuenta ${i}: se registra y entra sin confirmar el correo`,
      enPerfil,
      enPerfil ? '' : aviso.trim().slice(0, 120)
    )
    if (!enPerfil) {
      await context.close()
      continue
    }

    await sleep(1500)
    const texto = await page.evaluate(() => document.body.innerText)
    runner.check(
      `cuenta ${i}: el perfil muestra el usuario ${usuario}`,
      texto.toLowerCase().includes(usuario.toLowerCase())
    )

    // Cierra sesión y vuelve a ingresar con correo y contraseña.
    await page.waitForFunction(
      () => /cerrar sesi/i.test(document.body.textContent),
      { timeout: 30000 }
    )
    for (const boton of await page.$$('.q-btn')) {
      const etiqueta = await boton.evaluate(el => el.textContent)
      if (/cerrar sesi/i.test(etiqueta)) {
        await boton.evaluate(el => el.scrollIntoView({ block: 'center' }))
        await boton.click()
        break
      }
    }
    await sleep(2500)
    await page.goto(`${BASE_URL}/#/acceso`, { waitUntil: 'networkidle0' })
    await page.evaluate(() => {
      const tab = [...document.querySelectorAll('.q-tab')].find(el =>
        /ingresar/i.test(el.textContent)
      )
      tab?.click()
    })
    await sleep(500)
    const campos2 = []
    for (const campo of await page.$$('.q-tab-panel input')) {
      if (await campo.isVisible()) campos2.push(campo)
    }
    if (campos2.length < 2) {
      const texto2 = await page.evaluate(() => document.body.innerText)
      console.log('DEBUG acceso:', texto2.slice(0, 300))
    }
    await campos2[0].type(correo)
    await campos2[1].type(clave)
    await page.evaluate(() => {
      const boton = [...document.querySelectorAll('.q-btn')].find(el =>
        /^\s*entrar\s*$/i.test(el.textContent)
      )
      boton?.click()
    })
    let volvio = false
    for (let t = 0; t < 30 && !volvio; t++) {
      await sleep(500)
      volvio = page.url().includes('/perfil')
    }
    runner.check(
      `cuenta ${i}: vuelve a ingresar con correo y contraseña`,
      volvio
    )
    await context.close()
  }
} finally {
  await browser.close()
}
process.exitCode = runner.summary('registro sin confirmación') ? 1 : 0
