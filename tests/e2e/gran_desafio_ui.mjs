// Gran desafío desde la interfaz: vidas visibles y fin de partida sin vidas.
//
//   node tests/e2e/serve.mjs   (en otra terminal)
//   node tests/e2e/gran_desafio_ui.mjs
//
// Entra como invitado, empieza el Gran desafío, responde siempre la opción A
// y comprueba que los corazones bajen con cada error, que al llegar a cero el
// botón pase a "VER MI RESULTADO" y que se muestre el resultado guardado.

import {
  BASE_URL,
  createRunner,
  entrarComoInvitado,
  launchBrowser,
  sleep
} from './helpers.mjs'

const runner = createRunner('Gran desafío (interfaz, vidas)')
const DESAFIO = '50000000-0000-0000-0000-000000000010'

const browser = await launchBrowser()
try {
  const page = await browser.newPage()
  await page.setViewport({ width: 390, height: 844, isMobile: true })
  await entrarComoInvitado(page)
  await page.goto(`${BASE_URL}/#/expo/${DESAFIO}`, {
    waitUntil: 'networkidle0'
  })
  await page.waitForSelector('.dl-challenge__rules-card', { timeout: 20000 })

  const reglas = await page.evaluate(() => document.body.innerText)
  runner.check(
    'la intro muestra las 3 vidas',
    /Vidas/i.test(reglas) && /3 vidas/i.test(reglas)
  )

  // Empezar (se crea un invitado si no hay sesión).
  for (const boton of await page.$$('.q-btn')) {
    const texto = await boton.evaluate(el => el.textContent)
    if (/empezar desaf/i.test(texto)) {
      await boton.click()
      break
    }
  }
  await page.waitForSelector('.dl-challenge__option', { timeout: 30000 })

  const vivos = () =>
    page.$$eval('.dl-challenge__lives .is-alive', els => els.length)
  runner.check('empieza con 3 corazones', (await vivos()) === 3)

  let corazones = 3
  let intentos = 0
  let terminoPorVidas = false
  while (intentos < 20) {
    intentos++
    await page.waitForSelector('.dl-challenge__option', { timeout: 15000 })
    const opciones = await page.$$('.dl-challenge__option')
    await opciones[0].click()
    await sleep(150)
    const confirmar = await page.$('.dl-challenge__actions .dl-btn-main')
    await confirmar.click()
    await page
      .waitForSelector('.dl-challenge__feedback', { timeout: 15000 })
      .catch(async error => {
        const texto = await page.evaluate(() => document.body.innerText)
        console.log('DEBUG pantalla:', texto.slice(0, 600))
        throw error
      })
    await sleep(250)
    const ahora = await vivos()
    const feedback = await page.$eval(
      '.dl-challenge__feedback',
      el => el.className
    )
    const fueError = /--bad/.test(feedback)
    if (fueError) {
      runner.check(
        `error ${3 - ahora}: resta un corazón`,
        ahora === corazones - 1,
        `${corazones} -> ${ahora}`
      )
    }
    corazones = ahora
    const etiqueta = await page.$eval(
      '.dl-challenge__actions .dl-btn-main',
      el => el.textContent.trim()
    )
    if (corazones === 0) {
      runner.check(
        'sin vidas el botón dice "VER MI RESULTADO"',
        /ver mi resultado/i.test(etiqueta),
        etiqueta
      )
      await page.click('.dl-challenge__actions .dl-btn-main')
      terminoPorVidas = true
      break
    }
    await page.click('.dl-challenge__actions .dl-btn-main')
    await sleep(250)
  }
  runner.check('la partida termina al quedarse sin vidas', terminoPorVidas)

  await page.waitForSelector('.dl-challenge__result-banner', { timeout: 30000 })
  await sleep(1500)
  const resultado = await page.evaluate(() => document.body.innerText)
  runner.check(
    'el resultado dice que se quedó sin vidas',
    /sin vidas/i.test(resultado)
  )
  runner.check(
    'la partida queda guardada como válida',
    /partida v[aá]lida/i.test(resultado)
  )
  runner.check(
    'no ofrece jugar de nuevo (un solo intento)',
    !/jugar de nuevo|otro intento/i.test(resultado)
  )
} finally {
  await browser.close()
}
process.exitCode = runner.summary('gran desafío UI') ? 1 : 0
