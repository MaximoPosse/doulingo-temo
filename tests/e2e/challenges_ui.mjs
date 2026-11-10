// Etapa 6 · Interfaz: expo, juego del desafío, resultado e historial.
//
//   node tests/e2e/challenges_ui.mjs
//
// Requiere:
//   - la app servida (por defecto http://localhost:9100);
//   - las migraciones 0006_desafios.sql y 0007_seed_desafios.sql aplicadas.
//
// Usa el desafío interno 50000000-0000-0000-0000-000000000101 por URL directa
// (la expo pública lo oculta porque es_prueba = true). Así la interfaz se
// prueba sin depender de los datos de producción de la expo.

import { BASE_URL, createRunner, launchBrowser, sleep } from './helpers.mjs'

const runner = createRunner('=== Etapa 6 · Desafíos (interfaz) ===')
const browser = await launchBrowser()

const CHALLENGE_PATH =
  '#/expo/50000000-0000-0000-0000-000000000101'
const EXPIRED_PATH = '#/expo/50000000-0000-0000-0000-000000000102'

async function openApp(page, path = '#/') {
  await page.goto(`${BASE_URL}/${path}`, { waitUntil: 'networkidle0' })
}

async function startChallenge(page) {
  await page.waitForSelector('.dl-challenge__start .dl-btn-main', {
    timeout: 20000
  })
  await page.waitForFunction(
    () => {
      const button = document.querySelector(
        '.dl-challenge__start .dl-btn-main'
      )
      return button && !button.disabled
    },
    { timeout: 20000 }
  )
  await page.click('.dl-challenge__start .dl-btn-main')
  await page.waitForSelector('.dl-challenge__playbar', { timeout: 20000 })
}

// Responde las 4 preguntas del desafío de prueba. La primera opción es la
// correcta en la semilla. En la última, el botón FINALIZAR PARTIDA cierra.
async function answerAll(page, { failFinalize = false } = {}) {
  let intercept = failFinalize
  if (failFinalize) {
    await page.setRequestInterception(true)
    page.on('request', request => {
      if (
        intercept &&
        request.url().includes('/rest/v1/rpc/finalizar_partida')
      ) {
        request.abort('failed')
      } else {
        request.continue()
      }
    })
  }

  for (let i = 0; i < 4; i++) {
    await page.waitForSelector('.dl-challenge__option', { timeout: 15000 })
    const options = await page.$$('.dl-challenge__option')
    await options[0].click()
    await sleep(120)
    await page.click('.dl-challenge__actions .dl-btn-main')
    await page.waitForSelector('.dl-challenge__feedback', { timeout: 15000 })
    await sleep(220)
    await page.click('.dl-challenge__actions .dl-btn-main')
    await sleep(320)
  }

  return {
    resume: async () => {
      intercept = false
    }
  }
}

async function clickByText(page, selector, text) {
  await page.$$eval(
    selector,
    (nodes, wanted) => {
      const button = nodes.find(node =>
        node.innerText.toUpperCase().includes(wanted)
      )
      button?.click()
    },
    text.toUpperCase()
  )
}

try {
  // ----------------------------------------------------------------
  // 1. Expo pública y navegación
  // ----------------------------------------------------------------
  const contextA = await browser.createBrowserContext()
  const pageA = await contextA.newPage()
  const errorsA = []
  pageA.on('pageerror', error => errorsA.push(String(error)))

  await openApp(pageA)
  await pageA.waitForSelector('.dl-hero, .dl-course-card', { timeout: 20000 })

  const navExpo = await pageA.$$eval('.dl-nav .q-btn', buttons =>
    buttons.some(button => button.innerText.trim() === 'Expo')
  )
  runner.check('Navegación: existe el enlace "Expo"', navExpo)

  await pageA.evaluate(() => {
    location.hash = '#/expo'
  })
  await pageA.waitForSelector('.dl-expo', { timeout: 20000 })
  await pageA.waitForSelector('.dl-expo__grid .dl-expo__card', {
    timeout: 20000
  })

  const expoTitle = await pageA.$eval(
    '.dl-expo__hero .dl-page__title',
    node => node.innerText.trim()
  )
  runner.check(
    'Expo: muestra el evento publicado',
    expoTitle.length > 0,
    expoTitle
  )
  const publicCards = await pageA.$$('.dl-expo__card')
  runner.check(
    'Expo: lista los desafíos públicos (3)',
    publicCards.length === 3,
    String(publicCards.length)
  )
  const expoSplit = await pageA.$eval(
    '.dl-expo__explain',
    node => node.innerText
  )
  runner.check(
    'Expo: diferencia práctica y competencia',
    expoSplit.includes('Práctica') && expoSplit.includes('Competencia')
  )

  // ----------------------------------------------------------------
  // 2. Desafío completo como invitado
  // ----------------------------------------------------------------
  await pageA.evaluate(path => {
    location.hash = path
  }, CHALLENGE_PATH)
  await pageA.waitForSelector('.dl-challenge__rules-card', { timeout: 20000 })

  const rules = await pageA.$eval(
    '.dl-challenge__rules-card',
    node => node.innerText
  )
  runner.check(
    'Desafío: muestra preguntas, duración, puntos e intentos',
    rules.includes('Preguntas') &&
      rules.includes('Duración') &&
      rules.includes('Puntos por acierto') &&
      rules.includes('Intentos')
  )
  runner.check(
    'Desafío: avisa que el tiempo lo controla el servidor',
    rules.includes('servidor')
  )

  await startChallenge(pageA)
  runner.check(
    'Juego: como invitado se crea la partida y aparece el tablero',
    (await pageA.$('.dl-challenge__playbar')) !== null
  )

  await answerAll(pageA)
  await pageA.waitForSelector('.dl-challenge__result-banner', {
    timeout: 20000
  })
  await pageA.waitForSelector('.dl-challenge__save--saved', {
    timeout: 20000
  })

  const scoreA = await pageA.$eval(
    '.dl-challenge__score-value',
    node => node.innerText.trim()
  )
  runner.check('Resultado: el invitado ve su puntaje final (40)', scoreA === '40', scoreA)

  const stateA = await pageA.$eval(
    '.dl-challenge__result-banner .dl-badge',
    node => node.innerText.trim()
  )
  runner.check(
    'Resultado: la partida válida se marca como tal',
    stateA.includes('Partida válida'),
    stateA
  )

  const saveA = await pageA.$eval(
    '.dl-challenge__save--saved',
    node => node.innerText.trim()
  )
  runner.check(
    'Resultado: se confirma el guardado en el servidor',
    saveA.includes('Resultado guardado'),
    saveA
  )

  await pageA.waitForSelector('.dl-challenge__answer', { timeout: 20000 })
  const answerRowsA = await pageA.$$('.dl-challenge__answer')
  runner.check(
    'Detalle: se listan las 4 respuestas de la partida',
    answerRowsA.length === 4,
    String(answerRowsA.length)
  )

  const detailHint = await pageA.$eval(
    '.dl-challenge__detail-hint',
    node => node.innerText.trim()
  )
  runner.check(
    'Detalle: mientras el desafío sigue abierto no revela la solución',
    detailHint.includes('se muestran cuando el desafío cierre'),
    detailHint
  )
  const revealedA = await pageA.$eval(
    '.dl-challenge__answers',
    node => node.innerText.includes('Correcta:')
  )
  runner.check('Detalle: no se muestra la opción correcta', !revealedA)

  await pageA.waitForSelector('.dl-ranking__me', { timeout: 20000 })
  const meRow = await pageA.$eval(
    '.dl-ranking__me',
    node => node.innerText.trim()
  )
  runner.check(
    'Ranking: el invitado se reconoce en su mejor intento (40)',
    meRow.includes('40') && meRow.includes('vos'),
    meRow
  )

  // ----------------------------------------------------------------
  // 3. Perfil: historial de desafíos
  // ----------------------------------------------------------------
  await pageA.evaluate(() => {
    location.hash = '#/perfil'
  })
  await pageA.waitForSelector('.dl-card__title', { timeout: 20000 })
  await pageA
    .waitForFunction(
      () => document.body.innerText.includes('Desafíos de la expo'),
      { timeout: 20000 }
    )
    .catch(() => {})
  await sleep(700)

  const profileText = await pageA.$eval('.dl-page__inner', node => node.innerText)
  runner.check(
    'Perfil: aparece la sección "Desafíos de la expo"',
    profileText.includes('Desafíos de la expo')
  )
  runner.check(
    'Perfil: el historial lista la partida del desafío',
    profileText.includes('Prueba normal')
  )
  runner.check(
    'Perfil: la partida figura como válida',
    profileText.includes('Válida')
  )
  runner.check(
    'Perfil: la métrica de desafíos válidos está presente',
    profileText.includes('Desafíos válidos')
  )
  runner.check(
    'Perfil: no hay errores de página',
    errorsA.length === 0,
    errorsA[0]
  )

  // ----------------------------------------------------------------
  // 4. Partida vencida: el reloj del servidor cierra el juego
  // ----------------------------------------------------------------
  const contextB = await browser.createBrowserContext()
  const pageB = await contextB.newPage()
  await openApp(pageB, EXPIRED_PATH)
  await pageB.waitForSelector('.dl-challenge__rules-card', { timeout: 20000 })
  await startChallenge(pageB)

  const timeoutShown = await pageB
    .waitForSelector('.dl-challenge__timeout', { timeout: 15000 })
    .then(() => true)
    .catch(() => false)
  runner.check(
    'Vencida: la interfaz avisa que se terminó el tiempo',
    timeoutShown
  )
  // Deja pasar un instante para que el servidor también vea la partida vencida.
  await sleep(350)
  const optionsDisabled = await pageB.$$eval(
    '.dl-challenge__option',
    nodes => nodes.every(node => node.disabled)
  )
  runner.check(
    'Vencida: no se pueden elegir respuestas fuera del plazo',
    optionsDisabled
  )

  await clickByText(pageB, '.dl-challenge__playbar button', 'FINALIZAR')
  await pageB.waitForSelector('.dl-challenge__confirm', { timeout: 10000 })
  await clickByText(pageB, '.dl-challenge__confirm button', 'SÍ, FINALIZAR')
  await pageB.waitForSelector('.dl-challenge__save--saved', {
    timeout: 20000
  })

  const expiredState = await pageB.$eval(
    '.dl-challenge__result-banner .dl-badge',
    node => node.innerText.trim()
  )
  const expiredScore = await pageB.$eval(
    '.dl-challenge__score-value',
    node => node.innerText.trim()
  )
  runner.check(
    'Vencida: el resultado queda como "Partida vencida" con 0 puntos',
    expiredState.includes('Partida vencida') && expiredScore === '0',
    `${expiredState} / ${expiredScore}`
  )

  // ----------------------------------------------------------------
  // 5. Fallo de red al guardar: aviso y reintento
  // ----------------------------------------------------------------
  const contextC = await browser.createBrowserContext()
  const pageC = await contextC.newPage()
  await openApp(pageC, CHALLENGE_PATH)
  await pageC.waitForSelector('.dl-challenge__rules-card', { timeout: 20000 })
  await startChallenge(pageC)
  const runC = await answerAll(pageC, { failFinalize: true })

  const failedBanner = await pageC
    .waitForSelector('.dl-challenge__save--failed', { timeout: 20000 })
    .then(() => true)
    .catch(() => false)
  runner.check(
    'Fallo al guardar: se avisa que el resultado no se guardó',
    failedBanner
  )
  const retryButton = await pageC.$$eval(
    '.dl-challenge__result-actions button',
    buttons =>
      buttons.some(button => button.innerText.includes('REINTENTAR GUARDADO'))
  )
  runner.check(
    'Fallo al guardar: ofrece REINTENTAR GUARDADO',
    retryButton
  )

  await runC.resume()
  await clickByText(
    pageC,
    '.dl-challenge__result-actions button',
    'REINTENTAR GUARDADO'
  )
  const savedAfterRetry = await pageC
    .waitForSelector('.dl-challenge__save--saved', { timeout: 20000 })
    .then(() => true)
    .catch(() => false)
  runner.check(
    'Reintentar guardado: el resultado queda guardado',
    savedAfterRetry
  )

  await contextA.close()
  await contextB.close()
  await contextC.close()
} catch (error) {
  runner.check('Etapa 6 UI sin excepciones', false, error.message)
}

await browser.close()
process.exit(runner.summary('DESAFÍOS UI') ? 1 : 0)
