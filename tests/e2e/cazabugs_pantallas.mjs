// Cazabugs en todos los tamaños de pantalla (celulares, tablets, PC y celular
// de lado): durante la ronda el juego tiene que entrar completo en la pantalla,
// sin tener que bajar, y las casillas tienen que ser lo bastante grandes para
// tocarlas.
//
//   node tests/e2e/serve.mjs   (en otra terminal)
//   node tests/e2e/cazabugs_pantallas.mjs [--fotos carpeta]
//
// Usa la práctica (no necesita que el minijuego esté desbloqueado).

import path from 'node:path'

import {
  BASE_URL,
  createRunner,
  entrarComoInvitado,
  launchBrowser,
  sleep
} from './helpers.mjs'

const runner = createRunner('Cazabugs en todas las pantallas')
const TAMANOS = [
  { nombre: 'Android chico 320x568', w: 320, h: 568, movil: true },
  { nombre: 'Android 360x640', w: 360, h: 640, movil: true },
  { nombre: 'iPhone SE 375x667', w: 375, h: 667, movil: true },
  { nombre: 'iPhone 390x844', w: 390, h: 844, movil: true },
  { nombre: 'Android 412x915', w: 412, h: 915, movil: true },
  { nombre: 'iPhone Max 430x932', w: 430, h: 932, movil: true },
  { nombre: 'Tablet 768x1024', w: 768, h: 1024, movil: true },
  { nombre: 'Celular de lado 667x375', w: 667, h: 375, movil: true },
  { nombre: 'Celular de lado 844x390', w: 844, h: 390, movil: true },
  { nombre: 'Celular de lado 915x412', w: 915, h: 412, movil: true },
  { nombre: 'PC 1024x768', w: 1024, h: 768, movil: false },
  { nombre: 'PC 1366x768', w: 1366, h: 768, movil: false },
  { nombre: 'PC 1920x1080', w: 1920, h: 1080, movil: false },
  { nombre: 'Ventana chica 500x600', w: 500, h: 600, movil: false },
  { nombre: 'Ventana baja 700x450', w: 700, h: 450, movil: false },
  { nombre: 'Ventana baja 1000x450', w: 1000, h: 450, movil: false },
  { nombre: 'Ventana con devtools 1280x500', w: 1280, h: 500, movil: false },
  { nombre: 'Ventana angosta 420x900', w: 420, h: 900, movil: false }
]
const fotosIdx = process.argv.indexOf('--fotos')
const fotos = fotosIdx > -1 ? process.argv[fotosIdx + 1] : null

const browser = await launchBrowser()
try {
  const page = await browser.newPage()
  await page.setViewport({
    width: 390,
    height: 844,
    isMobile: true,
    hasTouch: true
  })
  await entrarComoInvitado(page)

  for (const t of TAMANOS) {
    await page.setViewport({
      width: t.w,
      height: t.h,
      deviceScaleFactor: 1,
      isMobile: t.movil,
      hasTouch: t.movil
    })
    // Cambiar entre celular y PC recarga la página: se espera a que termine.
    await sleep(1500)
    await page.goto(`${BASE_URL}/#/`, { waitUntil: 'networkidle0' })
    await page.goto(`${BASE_URL}/#/expo/minijuego`, {
      waitUntil: 'networkidle0'
    })
    await page
      .waitForSelector('.cb__menu', { timeout: 30000 })
      .catch(async error => {
        console.log(
          'DEBUG',
          t.nombre,
          await page.evaluate(() => location.hash),
          (await page.evaluate(() => document.body.innerText)).slice(0, 300)
        )
        throw error
      })
    await sleep(500)
    const menu = await page.evaluate(() => ({
      alto: document.documentElement.scrollHeight,
      ventana: innerHeight,
      ancho:
        document.documentElement.scrollWidth -
        document.documentElement.clientWidth
    }))
    runner.check(
      `${t.nombre}: el menú no se desborda a los costados`,
      menu.ancho <= 1,
      `${menu.ancho}px`
    )
    if (fotos) {
      await page.screenshot({
        path: path.join(fotos, `menu_${t.w}x${t.h}.png`)
      })
    }

    // Práctica
    for (const boton of await page.$$('.q-btn')) {
      if (/practicar/i.test(await boton.evaluate(e => e.textContent))) {
        await boton.evaluate(e => e.scrollIntoView({ block: 'center' }))
        await boton.click()
        break
      }
    }
    await page.waitForSelector('.cb__tablero', { timeout: 15000 })
    await page.waitForFunction(() => !document.querySelector('.cb__cuenta'), {
      timeout: 15000
    })
    await sleep(800)
    const j = await page.evaluate(() => {
      const caja = el => {
        const r = el.getBoundingClientRect()
        return {
          top: r.top,
          bottom: r.bottom,
          left: r.left,
          right: r.right,
          w: r.width,
          h: r.height
        }
      }
      const tablero = caja(document.querySelector('.cb__tablero'))
      const celda = caja(document.querySelector('.cb__agujero'))
      const hud = caja(document.querySelector('.cb__hud'))
      const encabezado = caja(document.querySelector('.q-header'))
      return {
        tablero,
        celda,
        hud,
        encabezado,
        scrollY: window.scrollY,
        alto: document.documentElement.scrollHeight,
        ventana: innerHeight,
        ancho: innerWidth,
        scrollX:
          document.documentElement.scrollWidth -
          document.documentElement.clientWidth
      }
    })
    const cabeVertical = j.alto <= j.ventana + 1
    runner.check(
      `${t.nombre}: la ronda entra en la pantalla sin bajar`,
      cabeVertical &&
        j.tablero.bottom <= j.ventana + 1 &&
        j.tablero.top >= j.encabezado.bottom - 1,
      `alto de página ${j.alto} / ventana ${j.ventana}; tablero ${Math.round(j.tablero.top)}-${Math.round(j.tablero.bottom)}`
    )
    runner.check(
      `${t.nombre}: el tablero cabe a lo ancho`,
      j.tablero.left >= -1 && j.tablero.right <= j.ancho + 1 && j.scrollX <= 1
    )
    runner.check(
      `${t.nombre}: se ve el puntaje y el tiempo`,
      j.hud.top >= j.encabezado.bottom - 1 && j.hud.bottom <= j.ventana
    )
    const minimo = Math.min(j.celda.w, j.celda.h)
    runner.check(
      `${t.nombre}: cada casilla se puede tocar bien`,
      minimo >= (t.h <= 420 ? 40 : 56),
      `${Math.round(j.celda.w)}x${Math.round(j.celda.h)} px`
    )
    if (fotos) {
      await page.screenshot({
        path: path.join(fotos, `juego_${t.w}x${t.h}.png`)
      })
    }
  }
} finally {
  await browser.close()
}
process.exitCode = runner.summary('cazabugs en todas las pantallas') ? 1 : 0
