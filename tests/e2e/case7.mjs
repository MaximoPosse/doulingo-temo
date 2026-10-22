// Caso 7: fallo de red al comprobar una respuesta.
//
//   node tests/e2e/case7.mjs
//
// La app no debe marcar la opción como incorrecta cuando falla la red, debe
// avisar y permitir reintentar; la lección debe poder completarse igual.

import { BASE_URL, createRunner, launchBrowser, sleep } from './helpers.mjs'

const runner = createRunner('=== Caso 7: fallo de red al comprobar ===')
const browser = await launchBrowser()
const page = await browser.newPage()

try {
  await page.goto(`${BASE_URL}/#/`, { waitUntil: 'networkidle0' })
  await page.waitForSelector('.dl-hero, .dl-course-card', { timeout: 20000 })
  await sleep(800)
  await page.evaluate(() => {
    location.hash =
      '#/cursos/javascript/unidad/10000000-0000-0000-0000-000000000001/leccion/20000000-0000-0000-0000-200000000001'
  })
  await page.waitForSelector('.dl-lesson__intro', { timeout: 20000 })
  // Espera a que la app cree el intento en el servidor antes de responder.
  await page.waitForFunction(
    () =>
      !document.querySelector('.dl-lesson__intro-actions .dl-btn-main')
        ?.disabled,
    { timeout: 20000 }
  )
  await page.click('.dl-lesson__intro-actions .dl-btn-main')
  await page.waitForSelector('.dl-lesson__option', { timeout: 20000 })
  await page.waitForSelector('.dl-lesson__option:not([disabled])', {
    timeout: 20000
  })

  // Corta la comunicación con la RPC de comprobación/guardado de respuestas.
  let interceptOn = true
  await page.setRequestInterception(true)
  page.on('request', request => {
    if (
      interceptOn &&
      request.url().includes('/rest/v1/rpc/registrar_respuesta')
    )
      request.abort('failed')
    else request.continue()
  })

  const options = await page.$$('.dl-lesson__option')
  await options[0].click()
  await sleep(200)
  await page.click('.dl-lesson__actions .dl-btn-main')
  await page.waitForSelector('.dl-lesson__check-error, .dl-lesson__feedback', {
    timeout: 20000
  })
  await sleep(400)

  const errorText = await page
    .$eval('.dl-lesson__check-error', element =>
      element.innerText.replace(/\s+/g, ' ').trim()
    )
    .catch(() => '')
  runner.check(
    'Fallo de red muestra mensaje de error',
    errorText.length > 0,
    errorText
  )
  runner.check(
    'Fallo de red NO marca la opción como incorrecta',
    (await page.$('.dl-lesson__option--wrong')) === null
  )

  // Reintento: se vuelve a comprobar y ahora sí funciona.
  interceptOn = false
  await sleep(200)
  const buttons = await page.$$('.dl-lesson__actions .dl-btn-main')
  await buttons[0].click()
  await page.waitForSelector('.dl-lesson__feedback', { timeout: 20000 })
  await sleep(300)
  runner.check(
    'Reintento tras falla de red funciona',
    (await page.$('.dl-lesson__feedback')) !== null
  )

  // Sigue siendo posible completar la lección.
  let guard = 0
  while (guard++ < 6) {
    const feedback = await page.$('.dl-lesson__feedback')
    const remaining = await page.$$('.dl-lesson__option')
    if (!remaining.length) break
    if (!feedback) {
      await remaining[0].click()
      await sleep(150)
      await page.click('.dl-lesson__actions .dl-btn-main')
    } else {
      await page.click('.dl-lesson__actions .dl-btn-main')
    }
    await sleep(400)
  }
  runner.check(
    'Lección completable pese a la falla previa',
    (await page.$('.dl-lesson__result-banner')) !== null
  )

  // El resultado se muestra recién cuando el servidor confirma el guardado.
  await page.waitForSelector('.dl-lesson__save--saved', { timeout: 20000 })

  // Con sesión (aquí, invitado) el progreso local vive en una clave por
  // participante: `doulingo-progress:<uid>`.
  const stored = await page.evaluate(() => {
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i)
      if (key && key.startsWith('doulingo-progress')) {
        const value = localStorage.getItem(key)
        if (value && value.includes('20000000-0000-0000-0000-200000000001'))
          return `${key}=${value}`
      }
    }
    return null
  })
  runner.check(
    'Progreso guardado (local, con la lección completada)',
    !!stored,
    String(stored).slice(0, 140)
  )
} catch (error) {
  runner.check('Caso 7 sin excepciones', false, error.message)
}

await browser.close()
process.exit(runner.summary('CASO 7') ? 1 : 0)
