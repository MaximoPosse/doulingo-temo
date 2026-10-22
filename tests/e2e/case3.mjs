// Caso 3: modificar un título desde Supabase y comprobar el cambio en la app.
//
//   1) En Supabase → Table Editor → tabla `unidades` → editar el `titulo` de
//      la unidad 1 (id 10000000-0000-0000-0000-000000000001).
//   2) node tests/e2e/case3.mjs ["nuevo titulo"]
//
// El script NO escribe en la base: solo comprueba que la app refleje el cambio
// sin necesidad de recompilar.

import {
  BASE_URL,
  createRunner,
  launchBrowser,
  rest,
  sleep
} from './helpers.mjs'

const UNIT_ID = '10000000-0000-0000-0000-000000000001'
const runner = createRunner('=== Caso 3: cambio de datos desde el panel ===')
const expected = process.argv[2] ?? null

async function titleInDb() {
  const { body } = await rest(`unidades?select=titulo&id=eq.${UNIT_ID}`)
  return body?.[0]?.titulo ?? null
}

const initial = await titleInDb()
console.log(`Título actual en la base: "${initial}"`)

let current = initial
const limit = Date.now() + 120000
while (Date.now() < limit) {
  await sleep(3000)
  current = await titleInDb()
  if (expected) {
    if (current === expected) break
  } else if (current !== initial) {
    break
  }
}

runner.check(
  'El título cambió en Supabase',
  current !== initial,
  `"${initial}" -> "${current}"`
)
if (expected)
  runner.check(
    'El título coincide con el esperado',
    current === expected,
    String(current)
  )
if (current === initial) {
  console.log(
    '\nNo se detectó ningún cambio: editá el título en el Table Editor de Supabase y volvé a ejecutar.'
  )
  process.exit(2)
}

const browser = await launchBrowser()
const page = await browser.newPage()
try {
  await page.goto(`${BASE_URL}/#/cursos/javascript`, {
    waitUntil: 'networkidle0'
  })
  await page.waitForSelector('.dl-unit__card', { timeout: 20000 })
  await sleep(500)
  const texts = await page.$$eval('.dl-unit__card', elements =>
    elements.map(element => element.innerText.replace(/\s+/g, ' ').trim())
  )
  runner.check(
    'La app muestra el título nuevo (sin recompilar)',
    texts.some(text => text.includes(current)),
    texts[0]?.slice(0, 90)
  )

  await page.reload({ waitUntil: 'networkidle0' })
  await page.waitForSelector('.dl-unit__card', { timeout: 20000 })
  await sleep(500)
  const textsAfter = await page.$$eval('.dl-unit__card', elements =>
    elements.map(element => element.innerText.replace(/\s+/g, ' ').trim())
  )
  runner.check(
    'Tras recargar sigue mostrando el título nuevo',
    textsAfter.some(text => text.includes(current))
  )
  runner.check(
    'Se siguen listando las 5 unidades',
    textsAfter.length === 5,
    String(textsAfter.length)
  )
} catch (error) {
  runner.check('Verificación en la app sin excepciones', false, error.message)
}
await browser.close()

process.exit(runner.summary('CASO 3') ? 1 : 0)
