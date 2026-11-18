// Encabezado fijo y flecha "volver arriba".
//
//   node tests/e2e/serve.mjs   (en otra terminal)
//   node tests/e2e/scroll_ui.mjs
//
// Comprueba, en celular y en escritorio, que al bajar el encabezado
// (Inicio, Cursos, Expo, Acceder) acompaña el desplazamiento, que la flecha
// aparece recién después de bajar y que al tocarla vuelve al principio.

import { BASE_URL, createRunner, launchBrowser, sleep } from './helpers.mjs'

const runner = createRunner('Encabezado fijo y flecha para volver arriba')

const pantallas = [
  { nombre: 'celular 360', w: 360, h: 740, movil: true },
  { nombre: 'celular 412', w: 412, h: 915, movil: true },
  { nombre: 'escritorio 1280', w: 1280, h: 800, movil: false }
]
const rutas = ['/', '/cursos', '/expo']

const browser = await launchBrowser()
try {
  const page = await browser.newPage()
  for (const pantalla of pantallas) {
    await page.setViewport({
      width: pantalla.w,
      height: pantalla.h,
      isMobile: pantalla.movil,
      hasTouch: pantalla.movil
    })
    for (const ruta of rutas) {
      const nombre = `${pantalla.nombre} · ${ruta}`
      await page.goto(`${BASE_URL}/#${ruta}`, { waitUntil: 'networkidle0' })
      await sleep(1500)

      const alInicio = await page.evaluate(() => ({
        flecha: !!document.querySelector('.q-page-scroller .dl-to-top'),
        scroll: window.scrollY
      }))
      runner.check(`${nombre}: sin flecha al estar arriba`, !alInicio.flecha)

      // Baja hasta el final de la página.
      await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight))
      await sleep(900)
      const abajo = await page.evaluate(() => {
        const encabezado = document.querySelector('.q-header')
        const caja = encabezado.getBoundingClientRect()
        return {
          scroll: window.scrollY,
          top: Math.round(caja.top),
          visible: caja.bottom > 0 && caja.height > 0,
          flecha: !!document.querySelector('.q-page-scroller .dl-to-top')
        }
      })
      if (abajo.scroll < 200) {
        runner.skip(`${nombre}: página demasiado corta para desplazarse`)
        continue
      }
      runner.check(
        `${nombre}: el encabezado baja a la par (queda pegado arriba)`,
        abajo.top === 0 && abajo.visible,
        `top=${abajo.top}`
      )
      runner.check(`${nombre}: aparece la flecha al bajar`, abajo.flecha)

      if (abajo.flecha) {
        await page.click('.q-page-scroller .dl-to-top')
        await sleep(1200)
        const arriba = await page.evaluate(() => window.scrollY)
        runner.check(
          `${nombre}: la flecha vuelve al principio`,
          arriba < 5,
          `scrollY=${arriba}`
        )
      }
    }
  }
} finally {
  await browser.close()
}
process.exitCode = runner.summary('encabezado y flecha') ? 1 : 0
