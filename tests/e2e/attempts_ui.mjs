// Etapa 5 · Interfaz: guardado del intento, perfil e historial.
//
//   node tests/e2e/attempts_ui.mjs
//
// Requiere:
//   - la app servida (por defecto http://localhost:9100);
//   - la migración 0005_intentos.sql aplicada en Supabase.

import { BASE_URL, createRunner, launchBrowser, sleep } from './helpers.mjs'

const runner = createRunner('=== Etapa 5 · Intentos (interfaz) ===')
const browser = await launchBrowser()

const LESSON_PATH =
  '#/cursos/javascript/unidad/10000000-0000-0000-0000-000000000001/leccion/20000000-0000-0000-0000-200000000001'

// Recorre una lección de principio a fin. Si `failFinalize` es true, corta la
// llamada a finalizar_intento para provocar el estado "no se pudo guardar".
async function runLesson(page, { failFinalize = false } = {}) {
  await page.waitForSelector('.dl-lesson__intro', { timeout: 20000 })
  await page.waitForFunction(
    () =>
      !document.querySelector('.dl-lesson__intro-actions .dl-btn-main')
        ?.disabled,
    { timeout: 20000 }
  )
  await page.click('.dl-lesson__intro-actions .dl-btn-main')
  await sleep(400)

  let interceptFinalize = failFinalize
  await page.setRequestInterception(true)
  page.on('request', request => {
    if (
      interceptFinalize &&
      request.url().includes('/rest/v1/rpc/finalizar_intento')
    )
      request.abort('failed')
    else request.continue()
  })

  for (let i = 0; i < 3; i++) {
    await page.waitForSelector('.dl-lesson__option', { timeout: 15000 })
    const options = await page.$$('.dl-lesson__option')
    await options[0].click()
    await sleep(150)
    await page.click('.dl-lesson__actions .dl-btn-main')
    await page.waitForSelector(
      '.dl-lesson__feedback, .dl-lesson__check-error',
      {
        timeout: 15000
      }
    )
    await sleep(250)
    if (i < 2) {
      await page.click('.dl-lesson__actions .dl-btn-main')
      await sleep(300)
    }
  }
  // Última actividad: VER RESULTADOS.
  await page.click('.dl-lesson__actions .dl-btn-main')
  await page.waitForSelector('.dl-lesson__result-banner', { timeout: 15000 })
  return {
    resume: async () => {
      interceptFinalize = false
    }
  }
}

async function openProfile(page) {
  await page.evaluate(() => {
    location.hash = '#/perfil'
  })
  await page.waitForSelector('.dl-stats, .dl-profile', { timeout: 20000 })
  await sleep(600)
}

try {
  // ----------------------------------------------------------------
  // 1. Guardado confirmado en el servidor
  // ----------------------------------------------------------------
  const contextA = await browser.createBrowserContext()
  const pageA = await contextA.newPage()
  const errorsA = []
  pageA.on('pageerror', error => errorsA.push(String(error)))

  await pageA.goto(`${BASE_URL}/#/`, { waitUntil: 'networkidle0' })
  await pageA.waitForSelector('.dl-hero, .dl-course-card', { timeout: 20000 })
  await pageA.evaluate(path => {
    location.hash = path
  }, LESSON_PATH)
  await runLesson(pageA)

  const savedBanner = await pageA
    .waitForSelector('.dl-lesson__save--saved', { timeout: 20000 })
    .then(() => true)
    .catch(() => false)
  runner.check('Lección: el resultado se guarda y se confirma', savedBanner)
  runner.check(
    'Lección: no aparece el aviso de guardado fallido',
    (await pageA.$('.dl-lesson__save--failed')) === null
  )
  runner.check(
    'Lección: sin errores de página',
    errorsA.length === 0,
    errorsA[0]
  )

  // ----------------------------------------------------------------
  // 2. Perfil: último intento, historial y respuestas
  // ----------------------------------------------------------------
  await openProfile(pageA)
  runner.check(
    'Perfil: muestra el último intento',
    (await pageA.$('.dl-last')) !== null
  )
  const attemptRows = await pageA.$$('.dl-attempt')
  runner.check(
    'Perfil: el historial lista el intento guardado',
    attemptRows.length >= 1,
    String(attemptRows.length)
  )
  runner.check(
    'Perfil: el intento figura como finalizado (badge)',
    (await pageA.$('.dl-attempt .dl-badge')) !== null
  )

  // "Ver respuestas" despliega el detalle sin recargar.
  await pageA.$$eval('.dl-attempt__row button', buttons => {
    const toggle = buttons.find(button =>
      button.innerText.includes('Ver respuestas')
    )
    toggle?.click()
  })
  const opened = await pageA
    .waitForSelector('.dl-attempt__answers .dl-answer, .dl-answer', {
      timeout: 15000
    })
    .then(() => true)
    .catch(() => false)
  runner.check('Perfil: "Ver respuestas" muestra el detalle', opened)
  const answerRows = await pageA.$$('.dl-answer')
  runner.check(
    'Perfil: se listan las respuestas del intento',
    answerRows.length === 3,
    String(answerRows.length)
  )

  // Métricas del perfil coherentes con un guardado confirmado.
  const statValues = await pageA.$$eval('.dl-stat__value', nodes =>
    nodes.map(node => node.innerText.trim())
  )
  runner.check(
    'Perfil: hay al menos 1 intento guardado',
    statValues.includes('1') || Number(statValues[2]) >= 1,
    JSON.stringify(statValues)
  )

  // ----------------------------------------------------------------
  // 3. Aislamiento: otro dispositivo (otro invitado) no ve ese historial
  // ----------------------------------------------------------------
  const contextB = await browser.createBrowserContext()
  const pageB = await contextB.newPage()
  await pageB.goto(`${BASE_URL}/#/`, { waitUntil: 'networkidle0' })
  await pageB.waitForSelector('.dl-hero, .dl-course-card', { timeout: 20000 })
  // Crea una sesión de invitado nueva respondiendo la intro sin completar.
  await pageB.evaluate(path => {
    location.hash = path
  }, LESSON_PATH)
  await pageB.waitForSelector('.dl-lesson__intro', { timeout: 20000 })
  await pageB.waitForFunction(
    () =>
      !document.querySelector('.dl-lesson__intro-actions .dl-btn-main')
        ?.disabled,
    { timeout: 20000 }
  )
  await pageB.click('.dl-lesson__intro-actions .dl-btn-main')
  await sleep(500)
  await openProfile(pageB)
  const rowsB = await pageB.$$('.dl-attempt')
  runner.check(
    'Aislamiento: otro invitado no ve el historial del primero',
    rowsB.length === 0,
    String(rowsB.length)
  )

  // ----------------------------------------------------------------
  // 4. Fallo de red al guardar: aviso y REINTENTAR GUARDADO
  // ----------------------------------------------------------------
  const contextC = await browser.createBrowserContext()
  const pageC = await contextC.newPage()
  await pageC.goto(`${BASE_URL}/#/`, { waitUntil: 'networkidle0' })
  await pageC.waitForSelector('.dl-hero, .dl-course-card', { timeout: 20000 })
  await pageC.evaluate(path => {
    location.hash = path
  }, LESSON_PATH)
  const runC = await runLesson(pageC, { failFinalize: true })

  const failedBanner = await pageC
    .waitForSelector('.dl-lesson__save--failed', { timeout: 20000 })
    .then(() => true)
    .catch(() => false)
  runner.check(
    'Fallo al guardar: se avisa que el resultado no se guardó',
    failedBanner
  )
  const retryBtn = await pageC.$$eval(
    '.dl-lesson__result-actions button',
    buttons =>
      buttons.some(button => button.innerText.includes('REINTENTAR GUARDADO'))
  )
  runner.check('Fallo al guardar: ofrece REINTENTAR GUARDADO', retryBtn)

  // Reintento en la misma pantalla de resultados (sin recargar): se
  // restablece la red y el botón vuelve a intentar el guardado.
  await runC.resume()
  await pageC.$$eval('.dl-lesson__result-actions button', buttons => {
    const retry = buttons.find(button =>
      button.innerText.includes('REINTENTAR GUARDADO')
    )
    retry?.click()
  })
  const savedAfterRetry = await pageC
    .waitForSelector('.dl-lesson__save--saved', { timeout: 20000 })
    .then(() => true)
    .catch(() => false)
  runner.check(
    'Reintentar guardado: el resultado queda guardado',
    savedAfterRetry
  )

  // Recién ahora figura en el historial del participante.
  await openProfile(pageC)
  const rowsC = await pageC.$$('.dl-attempt')
  runner.check(
    'Tras reintentar: el intento figura en el historial',
    rowsC.length >= 1,
    String(rowsC.length)
  )

  await contextA.close()
  await contextB.close()
  await contextC.close()
} catch (error) {
  runner.check('Etapa 5 UI sin excepciones', false, error.message)
}

await browser.close()
process.exit(runner.summary('INTENTOS UI') ? 1 : 0)
