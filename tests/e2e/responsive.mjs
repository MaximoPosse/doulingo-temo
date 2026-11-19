// Auditoría de diseño adaptable: recorre las pantallas principales con los
// anchos de celulares más comunes (de 320 a 430 px, más una tablet chica) y
// verifica que no haya desplazamiento horizontal, elementos que se salgan
// de la pantalla ni botones demasiado chicos para tocar.
//
//   node tests/e2e/serve.mjs   (en otra terminal)
//   node tests/e2e/responsive.mjs [--shots carpeta]
//
// No necesita sesión: solo recorre las rutas públicas.

import fs from 'node:fs'
import path from 'node:path'

import {
  BASE_URL,
  createRunner,
  launchBrowser,
  sleep,
  entrarComoInvitado
} from './helpers.mjs'

const runner = createRunner('Diseño adaptable (celulares)')

const ANCHOS = [
  { w: 320, h: 568, nombre: 'Android chico 320' },
  { w: 360, h: 740, nombre: 'Android 360' },
  { w: 375, h: 667, nombre: 'iPhone SE 375' },
  { w: 390, h: 844, nombre: 'iPhone 390' },
  { w: 412, h: 915, nombre: 'Android 412' },
  { w: 430, h: 932, nombre: 'iPhone Max 430' },
  { w: 600, h: 960, nombre: 'Tablet chica 600' }
]

const RUTAS = [
  '/',
  '/cursos',
  '/cursos/javascript',
  '/cursos/python',
  '/cursos/php',
  '/cursos/java',
  '/cursos/csharp',
  '/cursos/cpp',
  '/cursos/python/unidad/10000002-0000-0000-0000-000000000001',
  '/cursos/javascript/unidad/10000000-0000-0000-0000-000000000001',
  '/cursos/javascript/unidad/10000000-0000-0000-0000-000000000001/leccion/20000000-0000-0000-0000-200000000001',
  '/expo',
  '/expo/minijuego',
  '/expo/50000000-0000-0000-0000-000000000010',
  '/ranking',
  '/acceso',
  '/ruta-que-no-existe'
]

const shotsIdx = process.argv.indexOf('--shots')
const shotsDir = shotsIdx > -1 ? process.argv[shotsIdx + 1] : null
if (shotsDir) fs.mkdirSync(shotsDir, { recursive: true })

const browser = await launchBrowser()
try {
  const page = await browser.newPage()
  await entrarComoInvitado(page)
  for (const ancho of ANCHOS) {
    await page.setViewport({
      width: ancho.w,
      height: ancho.h,
      deviceScaleFactor: 2,
      isMobile: true,
      hasTouch: true
    })
    for (const ruta of RUTAS) {
      await page.goto(`${BASE_URL}/#${ruta}`, { waitUntil: 'networkidle0' })
      await sleep(400)
      const info = await page.evaluate(() => {
        const vw = document.documentElement.clientWidth
        const doc = document.documentElement
        const fuera = []
        for (const el of document.querySelectorAll('body *')) {
          const r = el.getBoundingClientRect()
          if (r.width === 0 || r.height === 0) continue
          const estilo = getComputedStyle(el)
          if (estilo.position === 'fixed' || estilo.visibility === 'hidden')
            continue
          if (el.closest('.q-drawer, .q-menu, .q-dialog, [aria-hidden=true]'))
            continue
          // Lo que está dentro de un contenedor con desplazamiento propio (por
          // ejemplo la tabla del ranking) no ensancha la página.
          let dentroDeScroll = false
          for (
            let padre = el.parentElement;
            padre && padre !== document.body;
            padre = padre.parentElement
          ) {
            const x = getComputedStyle(padre).overflowX
            if (x === 'auto' || x === 'scroll') {
              dentroDeScroll = true
              break
            }
          }
          if (dentroDeScroll) continue
          if (r.right > vw + 1 || r.left < -1) {
            fuera.push(
              `${el.tagName.toLowerCase()}.${String(el.className).split(' ').slice(0, 2).join('.')} (${Math.round(r.left)}..${Math.round(r.right)})`
            )
          }
        }
        const chicos = []
        for (const el of document.querySelectorAll('button, a.q-btn, .q-btn')) {
          const r = el.getBoundingClientRect()
          if (r.width && r.height && (r.height < 32 || r.width < 32)) {
            chicos.push(
              `${(el.textContent || el.getAttribute('aria-label') || '').trim().slice(0, 20)} ${Math.round(r.width)}x${Math.round(r.height)}`
            )
          }
        }
        return {
          scroll: doc.scrollWidth - vw,
          fuera: fuera.slice(0, 4),
          chicos: chicos.slice(0, 4)
        }
      })
      runner.check(
        `${ancho.nombre} · ${ruta}: sin desborde horizontal`,
        info.scroll <= 1 && info.fuera.length === 0,
        info.scroll > 1
          ? `scroll horizontal de ${info.scroll}px`
          : info.fuera.join(' | ')
      )
      if (info.chicos.length)
        console.log(
          `   aviso (botones chicos) ${ruta}: ${info.chicos.join(', ')}`
        )
      if (shotsDir && [320, 390].includes(ancho.w)) {
        const nombre = `${ancho.w}_${ruta.replace(/\W+/g, '_') || 'inicio'}.png`
        await page.screenshot({
          path: path.join(shotsDir, nombre),
          fullPage: true
        })
      }
    }
  }
} finally {
  await browser.close()
}
process.exitCode = runner.summary('diseño adaptable') ? 1 : 0
