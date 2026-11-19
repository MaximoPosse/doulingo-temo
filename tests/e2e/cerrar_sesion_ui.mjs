// Después de cerrar sesión, los botones "Inicio" y los de volver tienen que
// seguir funcionando (varias veces, en celular).
//   node tests/e2e/serve.mjs   (en otra terminal)
//   node tests/e2e/cerrar_sesion_ui.mjs
import {
  BASE_URL,
  createRunner,
  entrarComoInvitado,
  launchBrowser,
  sleep
} from './helpers.mjs'

const runner = createRunner('Cerrar sesión y volver al inicio')
const browser = await launchBrowser()
try {
  const page = await browser.newPage()
  await page.setViewport({ width: 390, height: 844, isMobile: true, hasTouch: true })
  const hash = () => page.evaluate(() => location.hash)
  // Toque real en el centro del botón (como un dedo): si algo lo tapa, falla.
  const clic = async texto => {
    const centro = await page.evaluate(t => {
      const b = [...document.querySelectorAll('.dl-nav .q-btn')].find(e =>
        e.textContent.trim().toLowerCase().endsWith(t.toLowerCase())
      )
      if (!b) return null
      const r = b.getBoundingClientRect()
      return { x: r.x + r.width / 2, y: r.y + r.height / 2 }
    }, texto)
    if (!centro) return false
    await page.touchscreen.tap(centro.x, centro.y)
    return true
  }

  for (let vuelta = 1; vuelta <= 3; vuelta++) {
    await entrarComoInvitado(page)
    await page.goto(`${BASE_URL}/#/perfil`, { waitUntil: 'networkidle0' })
    await page.waitForFunction(
      () => [...document.querySelectorAll('.q-btn')].some(b => /cerrar sesi/i.test(b.textContent)),
      { timeout: 20000 }
    )
    await page.evaluate(() => {
      [...document.querySelectorAll('.q-btn')].find(b => /cerrar sesi/i.test(b.textContent)).click()
    })
    await page.waitForFunction(() => location.hash.includes('acceso'), { timeout: 20000 })
    await sleep(800)
    // Inicio del menú
    runner.check(`vuelta ${vuelta}: "Inicio" del menú funciona tras cerrar sesión`, (await clic('Inicio')) && (await page.waitForFunction(() => location.hash === '#/' || location.hash === '', { timeout: 5000 }).then(() => true).catch(() => false)), await hash())
    // otro botón: Acceder y volver
    await clic('Acceder')
    await sleep(500)
    runner.check(`vuelta ${vuelta}: "Acceder" funciona`, (await hash()).includes('acceso'), await hash())
    await clic('Inicio')
    await sleep(500)
    runner.check(`vuelta ${vuelta}: "Inicio" otra vez`, ['#/', ''].includes(await hash()), await hash())
  }
} catch (e) {
  runner.check('sin excepciones', false, String(e.message ?? e))
} finally {
  await browser.close()
}
process.exitCode = runner.summary('cerrar sesión') ? 1 : 0
