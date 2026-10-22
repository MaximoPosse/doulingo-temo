// Recorrido de la interfaz: botones, navegación y estados de la app.
//
//   node tests/e2e/buttons.mjs
//
// Requiere la app servida (por defecto http://localhost:9100, la build de
// producción servida con `node tests/e2e/serve.mjs`).

import { BASE_URL, createRunner, launchBrowser, sleep } from './helpers.mjs'

const runner = createRunner('=== Recorrido de botones e interfaz ===')
const browser = await launchBrowser()
const page = await browser.newPage()
const pageErrors = []
page.on('pageerror', error => pageErrors.push(String(error)))

const pathIs = async part =>
  (await page.evaluate(() => location.hash)).includes(part)

async function clickNth(selector, index = 0) {
  const elements = await page.$$(selector)
  if (!elements[index]) throw new Error(`no existe ${selector}[${index}]`)
  await elements[index].click()
  await sleep(450)
}

async function clickLabel(containerSelector, text) {
  const handle = await page.evaluateHandle(
    (selector, label) => {
      const container = document.querySelector(selector)
      if (!container) return null
      return (
        [...container.querySelectorAll('button')].find(button =>
          button.innerText.trim().toLowerCase().includes(label.toLowerCase())
        ) ?? null
      )
    },
    containerSelector,
    text
  )
  const element = handle.asElement()
  if (!element)
    throw new Error(`no existe botón "${text}" en ${containerSelector}`)
  await element.click()
  await sleep(450)
}

async function runLessonAllCorrect() {
  await page.click('.dl-lesson__intro-actions .dl-btn-main')
  await sleep(400)
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
    await page.click('.dl-lesson__actions .dl-btn-main')
    await sleep(300)
  }
  await page.waitForSelector('.dl-lesson__result-banner', { timeout: 15000 })
}

try {
  await page.goto(`${BASE_URL}/?buttons=1#/`, { waitUntil: 'networkidle0' })
  runner.check('Landing carga hero', (await page.$('.dl-hero')) !== null)
  await clickNth('.dl-hero__cta .dl-btn-main', 0)
  runner.check('EMPIEZA GRATIS -> /cursos', await pathIs('/cursos'))
  await page.waitForSelector('.dl-course-card', { timeout: 15000 })

  await clickNth('.dl-nav .q-btn', 0)
  runner.check('Nav "Inicio" -> /', await pathIs('#/'))
  await clickNth('.dl-nav .q-btn', 1)
  await page.waitForSelector('.dl-course-card', { timeout: 15000 })
  runner.check('Nav "Cursos" -> /cursos', await pathIs('/cursos'))

  await clickNth('.dl-course-card', 0)
  await page.waitForSelector('.dl-unit__card', { timeout: 15000 })
  runner.check(
    'Tarjeta de curso -> /cursos/javascript',
    await pathIs('/cursos/javascript')
  )
  runner.check(
    'Curso muestra 5 unidades',
    (await page.$$('.dl-unit__card')).length === 5
  )

  await clickNth('.dl-unit__card', 1)
  runner.check(
    'Unidad pendiente no navega',
    (await pathIs('/cursos/javascript')) && !(await pathIs('/unidad/'))
  )

  await clickNth('.dl-back', 0)
  runner.check('Link "Volver a cursos"', await pathIs('/cursos'))
  await page.waitForSelector('.dl-course-card', { timeout: 15000 })
  await clickNth('.dl-course-card', 0)
  await page.waitForSelector('.dl-unit__card', { timeout: 15000 })

  await clickNth('.dl-unit__card', 0)
  await page.waitForSelector('.dl-lesson-card', { timeout: 15000 })
  runner.check(
    'Unidad 1 abre',
    await pathIs('/unidad/10000000-0000-0000-0000-000000000001')
  )
  runner.check(
    'Unidad 1 lista 2 lecciones',
    (await page.$$('.dl-lesson-card')).length === 2
  )
  await clickNth('.dl-lesson-card', 1)
  runner.check('Lección bloqueada no navega', !(await pathIs('/leccion/')))

  await clickNth('.dl-back', 0)
  runner.check('Link "Volver al curso"', await pathIs('/cursos/javascript'))
  await page.waitForSelector('.dl-unit__card', { timeout: 15000 })
  await clickNth('.dl-unit__card', 0)
  await page.waitForSelector('.dl-lesson-card', { timeout: 15000 })

  await clickNth('.dl-lesson-card', 0)
  await page.waitForSelector('.dl-lesson__intro', { timeout: 15000 })
  runner.check(
    'Lección 1 abre (intro)',
    await pathIs('/leccion/20000000-0000-0000-0000-200000000001')
  )

  await clickNth('.dl-lesson__back', 0)
  runner.check('Intro: "Volver a la unidad"', await pathIs('/unidad/'))
  await page.waitForSelector('.dl-lesson-card', { timeout: 15000 })
  await clickNth('.dl-lesson-card', 0)
  await page.waitForSelector('.dl-lesson__intro', { timeout: 15000 })

  await page.click('.dl-lesson__intro-actions .dl-btn-main')
  await page.waitForSelector('.dl-lesson__option', { timeout: 15000 })
  runner.check('Comenzar actividades -> fase actividades', true)
  await clickNth('.dl-lesson__close', 0)
  runner.check('Botón X -> vuelve a la unidad', await pathIs('/unidad/'))
  await page.waitForSelector('.dl-lesson-card', { timeout: 15000 })
  await clickNth('.dl-lesson-card', 0)
  await page.waitForSelector('.dl-lesson__intro', { timeout: 15000 })

  await runLessonAllCorrect()
  runner.check(
    'Resultado aparece',
    (await page.$('.dl-lesson__result-banner')) !== null
  )
  const badge = await page.$eval(
    '.dl-lesson__result-banner .dl-badge',
    element => element.innerText.replace(/\s+/g, ' ').trim()
  )
  runner.check('Resultado: lección aprobada', /aprobada/i.test(badge))
  const stats = await page.$$eval('.dl-lesson__result-stat-value', elements =>
    elements.map(element => element.innerText.trim())
  )
  runner.check(
    'Estadísticas 3/3 100%',
    JSON.stringify(stats) === JSON.stringify(['3', '3', '0', '100%'])
  )

  await clickLabel('.dl-lesson__result-actions', 'Intentar nuevamente')
  runner.check(
    '"Intentar nuevamente" -> intro',
    (await page.$('.dl-lesson__intro')) !== null
  )
  const startLabel = await page.$eval(
    '.dl-lesson__intro-actions .dl-btn-main',
    element => element.innerText.trim()
  )
  runner.check(
    'Botón de inicio ahora "Repasar lección"',
    /repasar/i.test(startLabel)
  )

  await runLessonAllCorrect()
  await clickLabel('.dl-lesson__result-actions', 'Siguiente lección')
  await page.waitForSelector('.dl-lesson__intro, .dl-lesson__notfound', {
    timeout: 15000
  })
  runner.check(
    '"Siguiente lección" -> lección 2',
    await pathIs('/leccion/20000000-0000-0000-0000-200000000002')
  )
  const blocked = await page
    .$eval('.dl-lesson__notfound-title', element => element.innerText.trim())
    .catch(() => null)
  runner.check('Lección 2 ya desbloqueada', blocked !== 'Lección bloqueada')

  await clickNth('.dl-lesson__back', 0)
  await page.waitForSelector('.dl-lesson-card', { timeout: 15000 })
  const badges = await page.$$eval('.dl-lesson-card .dl-badge', elements =>
    elements.map(element => element.innerText.replace(/\s+/g, ' ').trim())
  )
  runner.check(
    'Unidad: lección 1 "Aprobada"',
    /aprobada/i.test(badges[0] ?? '')
  )
  runner.check(
    'Unidad: lección 2 "Disponible"',
    /disponible/i.test(badges[1] ?? '')
  )

  runner.check(
    'Sin errores de página',
    pageErrors.length === 0,
    pageErrors.join(' | ')
  )
} catch (error) {
  runner.check('Sin excepción en el recorrido', false, error.message)
}

await browser.close()
process.exit(runner.summary('BOTONES') ? 1 : 0)
