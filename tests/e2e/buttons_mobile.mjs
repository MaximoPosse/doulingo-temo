// Botones en modo celular: se emula un teléfono (pantalla táctil) y se TOCA
// cada botón importante, en vez de hacer clic con el mouse.
//
//   node tests/e2e/serve.mjs   (en otra terminal)
//   node tests/e2e/buttons_mobile.mjs
//
// Recorre la página principal, los 6 cursos, unidades, lecciones, la expo y
// el perfil. Si un botón no responde al toque, la prueba lo marca.

import {
  BASE_URL,
  createRunner,
  entrarComoInvitado,
  launchBrowser,
  sleep
} from './helpers.mjs'

const runner = createRunner('Botones en modo celular (toques)')
const CURSOS = ['javascript', 'python', 'php', 'java', 'csharp', 'cpp']
const UNIDAD = n => `10000000-0000-0000-0000-00000000000${n}`

const browser = await launchBrowser()
const page = await browser.newPage()
const errores = []
page.on('pageerror', e => errores.push(String(e)))

async function ruta() {
  return page.evaluate(() => location.hash)
}

// Toca el centro de un elemento (lo centra en pantalla antes, como haría un
// dedo al desplazarse). Devuelve true si algo recibió el toque.
async function tocar(selector, indice = 0) {
  const elementos = await page.$$(selector)
  const el = elementos[indice]
  if (!el) throw new Error(`no existe ${selector}[${indice}]`)
  await el.evaluate(nodo => nodo.scrollIntoView({ block: 'center' }))
  await sleep(250)
  const caja = await el.boundingBox()
  const x = caja.x + caja.width / 2
  const y = caja.y + caja.height / 2
  // ¿Lo que está en ese punto es el botón (o algo dentro)? Si hay otra cosa
  // encima, el toque no le llega.
  const encima = await page.evaluate(
    (px, py, nodo) => {
      const arriba = document.elementFromPoint(px, py)
      return !!arriba && (nodo.contains(arriba) || arriba.contains(nodo))
    },
    x,
    y,
    el
  )
  await page.touchscreen.tap(x, y)
  await sleep(500)
  return encima
}

async function tocarTexto(selector, texto) {
  const elementos = await page.$$(selector)
  for (let i = 0; i < elementos.length; i++) {
    const t = await elementos[i].evaluate(n => n.textContent)
    if (new RegExp(texto, 'i').test(t)) return tocar(selector, i)
  }
  throw new Error(`no hay ${selector} con el texto ${texto}`)
}

async function ir(hash) {
  await page.goto(`${BASE_URL}/#${hash}`, { waitUntil: 'networkidle0' })
  await sleep(800)
}

try {
  await page.setViewport({
    width: Number(process.env.ANCHO ?? 390),
    height: Number(process.env.ALTO ?? 844),
    deviceScaleFactor: 2,
    isMobile: true,
    hasTouch: true
  })
  await entrarComoInvitado(page)

  // ---- Inicio ----
  await ir('/')
  runner.check(
    'Inicio: botón EMPIEZA GRATIS (toque)',
    await tocar('.dl-hero__cta .dl-btn-main')
  )
  runner.check(
    'Inicio: EMPIEZA GRATIS lleva a /cursos',
    (await ruta()).includes('/cursos')
  )

  await ir('/')
  await tocar('.dl-hero__cta .dl-btn-ghost, .dl-hero__cta .dl-btn-ghost--card')
  runner.check(
    'Inicio: VER CURSOS lleva a /cursos',
    (await ruta()).includes('/cursos')
  )

  // Tarjetas de lenguaje de la página principal
  for (const slug of CURSOS) {
    await ir('/')
    const tarjetas = await page.$$('.dl-lang')
    const idx = CURSOS.indexOf(slug)
    const tocada = await tocar('.dl-lang', idx)
    const ok = (await ruta()).includes(`/cursos/${slug}`)
    runner.check(
      `Inicio: tarjeta de ${slug} (toque)`,
      tocada && ok,
      `${tarjetas.length} tarjetas; ruta ${await ruta()}`
    )
  }

  await ir('/')
  await tocar('.dl-teaser .dl-btn-main')
  runner.check(
    'Inicio: IR A LA EXPO lleva a /expo',
    (await ruta()).includes('/expo')
  )

  // ---- Menú del encabezado ----
  for (const [texto, destino] of [
    ['Cursos', '/cursos'],
    ['Expo', '/expo'],
    ['Inicio', '#/']
  ]) {
    await ir('/perfil')
    await tocarTexto('.dl-nav .q-btn', texto)
    const r = await ruta()
    runner.check(
      `Menú: "${texto}" (toque)`,
      destino === '#/' ? r === '#/' : r.includes(destino),
      r
    )
  }
  await ir('/')
  await tocarTexto('.dl-nav .q-btn', 'invitado|#')
  runner.check(
    'Menú: cuenta lleva al perfil',
    (await ruta()).includes('/perfil')
  )

  // ---- Cursos ----
  await ir('/cursos')
  const cantidad = (await page.$$('.dl-course-card')).length
  runner.check(
    'Cursos: aparecen los 6 cursos',
    cantidad === 6,
    String(cantidad)
  )
  for (let i = 0; i < CURSOS.length; i++) {
    await ir('/cursos')
    await tocar('.dl-course-card', i)
    runner.check(
      `Cursos: tarjeta ${i + 1} abre /cursos/${CURSOS[i]} (toque)`,
      (await ruta()).includes(`/cursos/${CURSOS[i]}`),
      await ruta()
    )
  }

  // ---- Un curso: unidad y lección (cada lenguaje) ----
  const unidades = {
    javascript: 1,
    python: 2,
    php: 3,
    java: 4,
    csharp: 5,
    cpp: 6
  }
  for (const slug of CURSOS) {
    await ir(`/cursos/${slug}`)
    await page.waitForSelector('.dl-unit__card', { timeout: 15000 })
    await tocar('.dl-unit__card', 0)
    runner.check(
      `${slug}: unidad 1 abre (toque)`,
      (await ruta()).includes('/unidad/'),
      await ruta()
    )
    await page.waitForSelector('.dl-lesson-card', { timeout: 15000 })
    await tocar('.dl-lesson-card', 0)
    runner.check(
      `${slug}: lección 1 abre (toque)`,
      (await ruta()).includes('/leccion/'),
      await ruta()
    )
    await page.waitForSelector('.dl-lesson__intro', { timeout: 15000 })
    await tocar('.dl-lesson__intro-actions .dl-btn-main')
    await page.waitForSelector('.dl-lesson__option', { timeout: 15000 })
    await tocar('.dl-lesson__option', 0)
    const seleccionada = await page.$('.dl-lesson__option--selected')
    runner.check(`${slug}: tocar una opción la selecciona`, !!seleccionada)
    await tocar('.dl-lesson__actions .dl-btn-main')
    await page
      .waitForSelector('.dl-lesson__feedback, .dl-lesson__check-error', {
        timeout: 15000
      })
      .catch(() => null)
    runner.check(
      `${slug}: COMPROBAR muestra la corrección`,
      !!(await page.$('.dl-lesson__feedback'))
    )
    void unidades
    void UNIDAD
  }

  // ---- Expo ----
  await ir('/expo')
  await page.waitForSelector('.dl-expo__card', { timeout: 20000 })
  await tocar('.dl-expo__card .q-btn')
  runner.check(
    'Expo: VER DESAFÍO abre el desafío (toque)',
    (await ruta()).includes('/expo/'),
    await ruta()
  )
  await page.waitForSelector('.dl-challenge__rules-card', { timeout: 20000 })
  await sleep(500)

  // ---- Perfil: cerrar sesión ----
  await ir('/perfil')
  await page.waitForFunction(
    () => /cerrar sesi/i.test(document.body.textContent),
    { timeout: 30000 }
  )
  await tocarTexto('.q-btn', 'cerrar sesi')
  await sleep(1500)
  runner.check(
    'Perfil: CERRAR SESIÓN vuelve al acceso (toque)',
    (await ruta()).includes('/acceso'),
    await ruta()
  )

  runner.check(
    'Sin errores de JavaScript en el recorrido',
    errores.length === 0,
    errores[0] ?? ''
  )
} catch (error) {
  runner.check(
    'Recorrido completo sin excepciones',
    false,
    String(error.message ?? error)
  )
} finally {
  await browser.close()
}
process.exitCode = runner.summary('botones en celular') ? 1 : 0
