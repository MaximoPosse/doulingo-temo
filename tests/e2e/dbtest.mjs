// Pruebas de la base de datos real: contenido publicado, RLS y RPC.
//
//   node tests/e2e/dbtest.mjs
//
// Comprueba contra el proyecto Supabase que:
//   - el contenido publicado es visible y el no publicado está oculto;
//   - las soluciones no se pueden leer directamente;
//   - el rol anónimo no puede escribir contenido;
//   - la RPC check_answer valida en el servidor;
//   - la app refleja el contenido y no guarda progreso en un contexto limpio.

import {
  BASE_URL,
  createRunner,
  launchBrowser,
  rest,
  rpc,
  sleep
} from './helpers.mjs'

const runner = createRunner('=== Base de datos: RLS, RPC y contenido ===')

const catalog = await rest(
  'cursos?select=id,slug,titulo,nivel,estado,icono,orden&order=orden'
)
const course = Array.isArray(catalog.body) ? catalog.body[0] : null
runner.check(
  'Catálogo: 1 curso visible (RLS estado=disponible)',
  catalog.status === 200 && catalog.body.length === 1,
  JSON.stringify(catalog.body)
)
runner.check(
  'Catálogo: curso "javascript" disponible',
  course?.slug === 'javascript' &&
    course?.estado === 'disponible' &&
    course?.nivel === 'Principiante'
)

const units = await rest(
  `unidades?select=id,titulo,orden,disponible&curso_id=eq.${course?.id}&order=orden`
)
const unitList = Array.isArray(units.body) ? units.body : []
runner.check(
  'Unidades: 5 del curso',
  units.status === 200 && unitList.length === 5,
  String(unitList.length)
)
runner.check(
  'Unidades: solo la 1 disponible',
  unitList[0]?.disponible === true &&
    unitList.slice(1).every(unit => unit.disponible === false),
  JSON.stringify(unitList.map(unit => unit.disponible))
)
runner.check(
  'Unidades: orden 1..5 sin repetir',
  JSON.stringify(unitList.map(unit => unit.orden)) ===
    JSON.stringify([1, 2, 3, 4, 5])
)

const lessons = await rest(
  `lecciones?select=id,titulo,orden&unidad_id=eq.${unitList[0]?.id}&order=orden`
)
runner.check(
  'Lecciones visibles de unidad 1: 2',
  lessons.status === 200 && lessons.body?.length === 2,
  JSON.stringify(lessons.body)
)

const hiddenLessons = await rest(
  `lecciones?select=id&unidad_id=eq.${unitList[1]?.id}`
)
runner.check(
  'RLS: lecciones de unidad NO disponible ocultas (0 filas)',
  hiddenLessons.status === 200 && hiddenLessons.body?.length === 0,
  JSON.stringify(hiddenLessons.body)
)

const questions = await rest(
  `preguntas?select=id,enunciado,orden&leccion_id=eq.${lessons.body?.[0]?.id}&order=orden`
)
runner.check(
  'Preguntas de la lección 1: 3',
  questions.status === 200 && questions.body?.length === 3,
  JSON.stringify(questions.body?.map(question => question.orden))
)
runner.check(
  'Preguntas: orden 1,2,3',
  JSON.stringify(questions.body?.map(question => question.orden)) ===
    JSON.stringify([1, 2, 3])
)

const question = questions.body?.[0]
const options = await rest(
  `opciones?select=id,texto,orden&pregunta_id=eq.${question?.id}&order=orden`
)
runner.check(
  'Opciones de la pregunta 1: 4',
  options.status === 200 && options.body?.length === 4,
  String(options.body?.length)
)
runner.check(
  'Opciones: no exponen la respuesta correcta',
  !Object.keys(options.body?.[0] ?? {}).some(key =>
    /correct|solucion/i.test(key)
  ),
  JSON.stringify(Object.keys(options.body?.[0] ?? {}))
)

const solutions = await rest(
  `soluciones?select=*&pregunta_id=eq.${question?.id}`
)
runner.check(
  'RLS: soluciones no públicas (401)',
  solutions.status === 401,
  `status=${solutions.status}`
)

const insert = await rest('cursos', {
  method: 'POST',
  headers: { 'content-type': 'application/json', Prefer: 'return=minimal' },
  body: JSON.stringify({
    id: '11111111-1111-1111-1111-111111111111',
    slug: 'test-hack',
    titulo: 'x',
    descripcion: 'x',
    nivel: 'Principiante',
    estado: 'disponible',
    color: '#ffffff',
    icono: 'i',
    orden: 1
  })
})
runner.check(
  'RLS: insert anónimo bloqueado (401)',
  insert.status === 401,
  `status=${insert.status}`
)

const update = await rest('cursos?id=eq.00000000-0000-0000-0000-000000000001', {
  method: 'PATCH',
  headers: { 'content-type': 'application/json' },
  body: JSON.stringify({ titulo: 'hack' })
})
runner.check(
  'RLS: update anónimo bloqueado (401)',
  update.status === 401,
  `status=${update.status}`
)

const remove = await rest('cursos?id=eq.00000000-0000-0000-0000-000000000001', {
  method: 'DELETE'
})
runner.check(
  'RLS: delete anónimo bloqueado (401)',
  remove.status === 401,
  `status=${remove.status}`
)

if (question) {
  const results = []
  for (const option of options.body) {
    const result = await rpc('check_answer', {
      p_pregunta: question.id,
      p_opcion: option.id
    })
    results.push({ option, result })
  }
  const correct = results.filter(
    item =>
      item.result.status === 200 && item.result.body?.[0]?.correcto === true
  )
  runner.check(
    'RPC: exactamente 1 de 4 opciones es correcta',
    correct.length === 1,
    JSON.stringify(
      results.map(item => [item.result.status, item.result.body?.[0]?.correcto])
    )
  )
  runner.check(
    'RPC: devuelve explicación no vacía',
    typeof correct[0]?.result.body?.[0]?.explicacion === 'string' &&
      correct[0].result.body[0].explicacion.length > 10
  )
  runner.check(
    'RPC: devuelve opcion_correcta_id',
    correct[0]?.result.body?.[0]?.opcion_correcta_id === correct[0]?.option?.id
  )

  const secondQuestion = questions.body?.[1]
  const otherOption = await rest(
    `opciones?select=id&pregunta_id=eq.${secondQuestion?.id}&limit=1`
  )
  const foreignOption = await rpc('check_answer', {
    p_pregunta: question.id,
    p_opcion: otherOption.body?.[0]?.id
  })
  runner.check(
    'RPC: opción de otra pregunta -> PR_OPTION_NOT_IN_QUESTION',
    foreignOption.status >= 400 &&
      /PR_OPTION_NOT_IN_QUESTION/.test(JSON.stringify(foreignOption.body)),
    JSON.stringify(foreignOption.body)
  )

  const unknownQuestion = await rpc('check_answer', {
    p_pregunta: '99999999-9999-9999-9999-999999999999',
    p_opcion: options.body[0].id
  })
  runner.check(
    'RPC: pregunta inexistente -> PR_QUESTION_NOT_PUBLISHED',
    unknownQuestion.status >= 400 &&
      /PR_QUESTION_NOT_PUBLISHED/.test(JSON.stringify(unknownQuestion.body)),
    JSON.stringify(unknownQuestion.body)
  )

  const unknownOption = await rpc('check_answer', {
    p_pregunta: question.id,
    p_opcion: '99999999-9999-9999-9999-999999999999'
  })
  runner.check(
    'RPC: opción inexistente -> PR_OPTION_NOT_IN_QUESTION',
    unknownOption.status >= 400 &&
      /PR_OPTION_NOT_IN_QUESTION/.test(JSON.stringify(unknownOption.body)),
    JSON.stringify(unknownOption.body)
  )
}

console.log('\n=== App: catálogo, no-encontrado, contexto limpio ===')
const browser = await launchBrowser()
try {
  const contextA = await browser.createBrowserContext()
  const pageA = await contextA.newPage()
  await pageA.goto(`${BASE_URL}/#/cursos`, { waitUntil: 'networkidle0' })
  await pageA.waitForSelector('.dl-course-card', { timeout: 20000 })
  runner.check(
    'App: /cursos lista el curso de la DB',
    (await pageA.$$('.dl-course-card')).length === 1
  )

  await pageA.goto(`${BASE_URL}/#/cursos/no-existe`, {
    waitUntil: 'networkidle0'
  })
  await sleep(1200)
  const missingCourse = await pageA.evaluate(() =>
    document.body.innerText.replace(/\s+/g, ' ')
  )
  runner.check(
    'App: curso inexistente muestra mensaje',
    /no (encontr|existe)|no encontrad/i.test(missingCourse),
    missingCourse.slice(0, 140)
  )

  await pageA.goto(
    `${BASE_URL}/#/leccion/20000000-0000-0000-0000-200000000001`,
    { waitUntil: 'networkidle0' }
  )
  await sleep(1200)
  const missingLesson = await pageA.evaluate(() =>
    document.body.innerText.replace(/\s+/g, ' ')
  )
  runner.check(
    'App: lección inexistente muestra mensaje',
    /no (encontr|existe)|no encontrad/i.test(missingLesson),
    missingLesson.slice(0, 140)
  )

  const contextB = await browser.createBrowserContext()
  const pageB = await contextB.newPage()
  await pageB.goto(`${BASE_URL}/#/cursos`, { waitUntil: 'networkidle0' })
  await pageB.waitForSelector('.dl-course-card', { timeout: 20000 })
  const stored = await pageB.evaluate(() =>
    localStorage.getItem('doulingo-progress')
  )
  runner.check(
    'App: contexto limpio sin progreso previo',
    stored === null,
    String(stored)
  )
} catch (error) {
  runner.check('App: flujo sin excepciones', false, error.message)
}
await browser.close()

process.exit(runner.summary('DB') ? 1 : 0)
