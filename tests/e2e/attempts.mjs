// Pruebas de la etapa 5: intentos, respuestas e historial en el servidor.
//
//   node tests/e2e/attempts.mjs
//
// Verifica contra el proyecto real que:
//   - el intento se crea una sola vez aunque se repita la petición;
//   - el servidor corrige y no deja reescribir una respuesta del intento;
//   - el resultado (aciertos, errores, aprobación) lo calcula el servidor;
//   - finalizar dos veces no duplica el progreso ni el historial;
//   - un intento sin terminar no cuenta como lección completada;
//   - cada participante solo ve y borra sus propios intentos y respuestas;
//   - el cliente no puede escribir intentos ni progreso directamente.
//
// Requiere `supabase/migrations/0005_intentos.sql` aplicada y los invitados
// anónimos habilitados en el proyecto.

import { randomUUID } from 'node:crypto'

import {
  createRunner,
  createSupabaseClient,
  rest,
  rpc,
  SUPABASE_KEY,
  SUPABASE_URL
} from './helpers.mjs'

const LESSON = '20000000-0000-0000-0000-200000000001'
const OTHER_LESSON = '20000000-0000-0000-0000-200000000002'

const runner = createRunner('=== Etapa 5: intentos y respuestas ===')

function detalle(result) {
  return JSON.stringify(result?.error ?? result?.data ?? result)
}

function tieneCodigo(result, code) {
  return (
    result?.error != null &&
    `${result.error.message ?? ''} ${result.error.details ?? ''}`.includes(code)
  )
}

async function authRest(token, tablePath, options = {}) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${tablePath}`, {
    ...options,
    headers: {
      apikey: SUPABASE_KEY,
      Authorization: `Bearer ${token}`,
      ...options.headers
    }
  })
  const text = await response.text()
  let body = text
  try {
    body = JSON.parse(text)
  } catch {
    /* respuesta sin JSON */
  }
  return { status: response.status, body }
}

// --- Participantes de prueba ---
const clientA = await createSupabaseClient()
const { data: sessionA, error: errorA } = await clientA.auth.signInAnonymously()

if (errorA) {
  runner.check('Setup: invitado A puede iniciar sesión', false, errorA.message)
  runner.skip(
    'Resto de la suite',
    'requiere invitados anónimos habilitados en Supabase'
  )
  process.exit(runner.summary('INTENTOS') ? 1 : 0)
}

const clientB = await createSupabaseClient()
const { data: sessionB } = await clientB.auth.signInAnonymously()

const tokenA = sessionA.session.access_token
const tokenB = sessionB?.session?.access_token
const uidA = sessionA.user.id
const uidB = sessionB?.user?.id

runner.check('Setup: dos invitados con identidad propia', !!uidA && !!uidB)

// --- Contenido de la lección y opciones correctas ---
const questionRows = await rest(
  `preguntas?select=id,orden,enunciado&leccion_id=eq.${LESSON}&order=orden`
)
const questions = Array.isArray(questionRows.body) ? questionRows.body : []
runner.check(
  'Contenido: la lección tiene 3 actividades',
  questions.length === 3,
  String(questions.length)
)

const optionsByQuestion = new Map()
const correctByQuestion = new Map()
for (const question of questions) {
  const options = await rest(
    `opciones?select=id,texto&pregunta_id=eq.${question.id}&order=orden`
  )
  optionsByQuestion.set(question.id, options.body ?? [])
  for (const option of options.body ?? []) {
    const check = await rpc('check_answer', {
      p_pregunta: question.id,
      p_opcion: option.id
    })
    if (check.body?.[0]?.correcto === true) {
      correctByQuestion.set(question.id, option.id)
    }
  }
}
runner.check(
  'Contenido: cada actividad tiene una opción correcta identificable',
  questions.every(question => correctByQuestion.has(question.id))
)

function opcionCorrecta(question) {
  return correctByQuestion.get(question.id)
}

function opcionIncorrecta(question) {
  return optionsByQuestion
    .get(question.id)
    .find(option => option.id !== opcionCorrecta(question))?.id
}

// --- 1. Crear intento e idempotencia ---
const clave1 = randomUUID()
const inicio1 = await clientA.rpc('iniciar_intento', {
  p_leccion: LESSON,
  p_clave: clave1
})
const intento1 = inicio1.data?.[0]

// Si las funciones no existen todavía, no se puede seguir: se informa que
// falta aplicar la migración y se cierra con éxito (no es un fallo del código).
if (!intento1?.intento) {
  runner.check(
    'Intento: se crea con el total de actividades del servidor',
    false,
    detalle(inicio1)
  )
  runner.skip(
    'Resto de la suite',
    'falta aplicar supabase/migrations/0005_intentos.sql en el proyecto'
  )
  process.exit(runner.summary('INTENTOS') ? 1 : 0)
}

runner.check(
  'Intento: se crea con el total de actividades del servidor',
  intento1?.total_actividades === 3,
  detalle(inicio1)
)
runner.check(
  'Intento: la primera creación no es reutilizada',
  intento1?.reutilizado === false
)

const repetido = await clientA.rpc('iniciar_intento', {
  p_leccion: LESSON,
  p_clave: clave1
})
runner.check(
  'Idempotencia: repetir la misma clave devuelve el MISMO intento',
  repetido.data?.[0]?.intento === intento1?.intento &&
    repetido.data?.[0]?.reutilizado === true,
  detalle(repetido)
)

const clave2 = randomUUID()
const inicio2 = await clientA.rpc('iniciar_intento', {
  p_leccion: LESSON,
  p_clave: clave2
})
const intento2 = inicio2.data?.[0]
runner.check(
  'Historial: una clave nueva crea otro intento',
  !inicio2.error &&
    intento2?.intento !== intento1?.intento &&
    intento2?.reutilizado === false,
  detalle(inicio2)
)

// --- 2. Corrección en el servidor y respuestas bloqueadas ---
const [q1, q2, q3] = questions
const primerIntento = intento1?.intento

const primera = await clientA.rpc('registrar_respuesta', {
  p_intento: primerIntento,
  p_pregunta: q1.id,
  p_opcion: opcionIncorrecta(q1)
})
runner.check(
  'Corrección: el servidor marca incorrecta la opción equivocada',
  !primera.error && primera.data?.[0]?.correcto === false,
  detalle(primera)
)
runner.check(
  'Corrección: devuelve la explicación y la opción correcta',
  typeof primera.data?.[0]?.explicacion === 'string' &&
    primera.data[0].explicacion.length > 10 &&
    primera.data?.[0]?.opcion_correcta_id === opcionCorrecta(q1)
)

const reenvio = await clientA.rpc('registrar_respuesta', {
  p_intento: primerIntento,
  p_pregunta: q1.id,
  p_opcion: opcionCorrecta(q1)
})
runner.check(
  'Anti-duplicados: la segunda respuesta de la actividad no cambia el resultado',
  reenvio.data?.[0]?.repetida === true &&
    reenvio.data?.[0]?.correcto === false &&
    reenvio.data?.[0]?.opcion_elegida_id === opcionIncorrecta(q1),
  detalle(reenvio)
)

const opcionAjena = await clientA.rpc('registrar_respuesta', {
  p_intento: primerIntento,
  p_pregunta: q2.id,
  p_opcion: opcionIncorrecta(q1)
})
runner.check(
  'Validación: opción de otra actividad -> PR_OPTION_NOT_IN_QUESTION',
  tieneCodigo(opcionAjena, 'PR_OPTION_NOT_IN_QUESTION'),
  detalle(opcionAjena)
)

const otraLeccion = await clientA.rpc('registrar_respuesta', {
  p_intento: primerIntento,
  p_pregunta: '30000000-0000-0000-0000-320100000000',
  p_opcion: '40000000-0000-0000-0000-421010000000'
})
runner.check(
  'Validación: actividad de otra lección -> PR_QUESTION_NOT_IN_ATTEMPT',
  tieneCodigo(otraLeccion, 'PR_QUESTION_NOT_IN_ATTEMPT'),
  detalle(otraLeccion)
)

// --- 3. Finalizar: cálculo del servidor e idempotencia ---
const incompleto = await clientA.rpc('finalizar_intento', {
  p_intento: primerIntento
})
runner.check(
  'Validación: no se finaliza con actividades sin responder',
  tieneCodigo(incompleto, 'PR_ATTEMPT_INCOMPLETE'),
  detalle(incompleto)
)

await clientA.rpc('registrar_respuesta', {
  p_intento: primerIntento,
  p_pregunta: q2.id,
  p_opcion: opcionCorrecta(q2)
})
await clientA.rpc('registrar_respuesta', {
  p_intento: primerIntento,
  p_pregunta: q3.id,
  p_opcion: opcionCorrecta(q3)
})

const final1 = await clientA.rpc('finalizar_intento', {
  p_intento: primerIntento
})
const resultado1 = final1.data?.[0]
runner.check(
  'Resultado: 2 aciertos, 1 error y aprobada (lo calcula el servidor)',
  !final1.error &&
    resultado1?.aciertos === 2 &&
    resultado1?.errores === 1 &&
    resultado1?.aprobada === true &&
    resultado1?.estado === 'finalizado',
  detalle(final1)
)
runner.check(
  'Resultado: la primera finalización no es reutilizada',
  resultado1?.reutilizado === false
)

const final1bis = await clientA.rpc('finalizar_intento', {
  p_intento: primerIntento
})
runner.check(
  'Idempotencia: finalizar dos veces devuelve el mismo resultado',
  final1bis.data?.[0]?.reutilizado === true &&
    final1bis.data?.[0]?.aciertos === 2 &&
    final1bis.data?.[0]?.aprobada === true,
  detalle(final1bis)
)

const respuestasCerradas = await clientA.rpc('registrar_respuesta', {
  p_intento: primerIntento,
  p_pregunta: q1.id,
  p_opcion: opcionCorrecta(q1)
})
runner.check(
  'Validación: no se responde un intento finalizado -> PR_ATTEMPT_CLOSED',
  tieneCodigo(respuestasCerradas, 'PR_ATTEMPT_CLOSED'),
  detalle(respuestasCerradas)
)

const progreso = await authRest(
  tokenA,
  `participant_progress?select=leccion_id,estado,intentos,mejor_aciertos&leccion_id=eq.${LESSON}`
)
const filaProgreso = Array.isArray(progreso.body) ? progreso.body[0] : null
runner.check(
  'Progreso: una fila aprobada con 1 intento y 2 aciertos',
  progreso.status === 200 &&
    progreso.body.length === 1 &&
    filaProgreso?.estado === 'aprobada' &&
    filaProgreso?.intentos === 1 &&
    filaProgreso?.mejor_aciertos === 2,
  JSON.stringify(progreso.body)
)

// --- 4. Segundo intento reprobado: no baja el progreso ya aprobado ---
for (const question of questions) {
  await clientA.rpc('registrar_respuesta', {
    p_intento: intento2.intento,
    p_pregunta: question.id,
    p_opcion: opcionIncorrecta(question)
  })
}
const final2 = await clientA.rpc('finalizar_intento', {
  p_intento: intento2.intento
})
runner.check(
  'Resultado: un intento con 0 aciertos queda reprobado',
  final2.data?.[0]?.aciertos === 0 &&
    final2.data?.[0]?.errores === 3 &&
    final2.data?.[0]?.aprobada === false,
  detalle(final2)
)

const progreso2 = await authRest(
  tokenA,
  `participant_progress?select=estado,intentos,mejor_aciertos&leccion_id=eq.${LESSON}`
)
runner.check(
  'Progreso: sigue aprobada, suma el intento y conserva el mejor resultado',
  progreso2.body?.[0]?.estado === 'aprobada' &&
    progreso2.body?.[0]?.intentos === 2 &&
    progreso2.body?.[0]?.mejor_aciertos === 2,
  JSON.stringify(progreso2.body)
)

// --- 5. Intento sin terminar (se sale / se corta la conexión) ---
const clave3 = randomUUID()
const inicio3 = await clientA.rpc('iniciar_intento', {
  p_leccion: LESSON,
  p_clave: clave3
})
const intento3 = inicio3.data?.[0]
await clientA.rpc('registrar_respuesta', {
  p_intento: intento3.intento,
  p_pregunta: q1.id,
  p_opcion: opcionCorrecta(q1)
})

const historialA = await authRest(
  tokenA,
  'intentos?select=id,estado,total_actividades,aciertos,errores,aprobada&order=iniciado_en.asc'
)
const porId = new Map((historialA.body ?? []).map(row => [row.id, row]))
runner.check(
  'Historial: quedan 3 intentos (2 finalizados y 1 sin terminar)',
  historialA.status === 200 &&
    historialA.body.length === 3 &&
    porId.get(intento3.intento)?.estado === 'en_curso',
  JSON.stringify(historialA.body)
)
runner.check(
  'Sin terminar: no se cuenta como lección completada',
  porId.get(intento3.intento)?.aprobada === false,
  JSON.stringify(porId.get(intento3.intento))
)

const respuestasA = await authRest(
  tokenA,
  `intentos_respuestas?select=intento_id,actividad_id,correcto&intento_id=eq.${primerIntento}`
)
runner.check(
  'Historial: el intento guarda una respuesta por actividad',
  respuestasA.status === 200 &&
    respuestasA.body.length === 3 &&
    respuestasA.body.filter(row => row.correcto).length === 2,
  JSON.stringify(respuestasA.body)
)

// --- 6. Aislamiento entre participantes ---
const intentoAjeno = await clientB.rpc('finalizar_intento', {
  p_intento: primerIntento
})
runner.check(
  'Aislamiento: B no puede finalizar el intento de A',
  tieneCodigo(intentoAjeno, 'PR_ATTEMPT_NOT_FOUND'),
  detalle(intentoAjeno)
)

const intentosDeB = await authRest(tokenB, 'intentos?select=id,estado')
runner.check(
  'Aislamiento: B no ve los intentos de A',
  intentosDeB.status === 200 &&
    (intentosDeB.body ?? []).every(
      row => row.id !== primerIntento && row.id !== intento2.intento
    ),
  JSON.stringify(intentosDeB.body)
)

const respuestasDeB = await authRest(
  tokenB,
  `intentos_respuestas?select=intento_id&intento_id=eq.${primerIntento}`
)
runner.check(
  'Aislamiento: B no ve las respuestas de A (0 filas)',
  respuestasDeB.status === 200 && respuestasDeB.body.length === 0,
  JSON.stringify(respuestasDeB.body)
)

const progresoDeB = await authRest(tokenB, 'participant_progress?select=id')
runner.check(
  'Aislamiento: B no ve el progreso de A',
  progresoDeB.status === 200 && progresoDeB.body.length === 0,
  JSON.stringify(progresoDeB.body)
)

// --- 7. Escritura directa bloqueada ---
const insercionDirecta = await authRest(tokenA, 'intentos', {
  method: 'POST',
  headers: { 'content-type': 'application/json', Prefer: 'return=minimal' },
  body: JSON.stringify({
    participante_id: uidA,
    leccion_id: LESSON,
    clave_idempotencia: randomUUID(),
    total_actividades: 3,
    aciertos: 3,
    errores: 0,
    aprobada: true
  })
})
runner.check(
  'Escritura directa: insertar un intento por REST está bloqueado',
  insercionDirecta.status >= 400,
  `status=${insercionDirecta.status}`
)

const actualizacionDirecta = await authRest(
  tokenA,
  `participant_progress?id=eq.${uidA}&leccion_id=eq.${LESSON}`,
  {
    method: 'PATCH',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ estado: 'aprobada', mejor_aciertos: 3 })
  }
)
runner.check(
  'Escritura directa: cambiar el progreso por REST está bloqueado',
  actualizacionDirecta.status >= 400,
  `status=${actualizacionDirecta.status}`
)

const insercionRespuesta = await authRest(tokenA, 'intentos_respuestas', {
  method: 'POST',
  headers: { 'content-type': 'application/json', Prefer: 'return=minimal' },
  body: JSON.stringify({
    intento_id: primerIntento,
    actividad_id: q1.id,
    opcion_id: opcionCorrecta(q1),
    correcto: true
  })
})
runner.check(
  'Escritura directa: insertar una respuesta por REST está bloqueado',
  insercionRespuesta.status >= 400,
  `status=${insercionRespuesta.status}`
)

// --- 8. Validaciones de sesión y contenido ---
const anonimo = await createSupabaseClient()
const sinSesion = await anonimo.rpc('iniciar_intento', {
  p_leccion: LESSON,
  p_clave: randomUUID()
})
runner.check(
  'Sesión: sin sesión no se inicia un intento -> PR_AUTH_REQUIRED',
  tieneCodigo(sinSesion, 'PR_AUTH_REQUIRED'),
  detalle(sinSesion)
)

const leccionInexistente = await clientA.rpc('iniciar_intento', {
  p_leccion: '99999999-9999-9999-9999-999999999999',
  p_clave: randomUUID()
})
runner.check(
  'Contenido: lección inexistente -> PR_LESSON_NOT_PUBLISHED',
  tieneCodigo(leccionInexistente, 'PR_LESSON_NOT_PUBLISHED'),
  detalle(leccionInexistente)
)

// La unidad 1 está publicada y tiene dos lecciones: la segunda también se
// puede comenzar (no está oculta). El caso de unidad no publicada no tiene
// lecciones en la semilla, por lo que se cubre con la lección inexistente.
const leccionPublicada = await clientA.rpc('iniciar_intento', {
  p_leccion: OTHER_LESSON,
  p_clave: randomUUID()
})
runner.check(
  'Contenido: la segunda lección publicada también se puede comenzar',
  !leccionPublicada.error &&
    leccionPublicada.data?.[0]?.leccion === OTHER_LESSON &&
    leccionPublicada.data?.[0]?.total_actividades === 3,
  detalle(leccionPublicada)
)

const intentoInexistente = await clientA.rpc('finalizar_intento', {
  p_intento: '99999999-9999-9999-9999-999999999999'
})
runner.check(
  'Validación: intento inexistente -> PR_ATTEMPT_NOT_FOUND',
  tieneCodigo(intentoInexistente, 'PR_ATTEMPT_NOT_FOUND'),
  detalle(intentoInexistente)
)

// --- 9. Borrado del historial propio ---
const borradoA = await authRest(tokenA, `intentos?participante_id=eq.${uidA}`, {
  method: 'DELETE'
})
const intentosTrasBorrar = await authRest(tokenA, 'intentos?select=id')
const respuestasTrasBorrar = await authRest(
  tokenA,
  `intentos_respuestas?select=intento_id&intento_id=eq.${primerIntento}`
)
runner.check(
  'Borrado: el participante borra sus intentos (204) y la cascada limpia respuestas',
  borradoA.status === 204 &&
    (intentosTrasBorrar.body ?? []).length === 0 &&
    (respuestasTrasBorrar.body ?? []).length === 0,
  `delete=${borradoA.status} intentos=${JSON.stringify(intentosTrasBorrar.body)}`
)

if (tokenB) {
  await authRest(tokenB, `intentos?participante_id=eq.${uidB}`, {
    method: 'DELETE'
  })
  await authRest(tokenB, `participant_progress?id=eq.${uidB}`, {
    method: 'DELETE'
  })
}
await authRest(tokenA, `participant_progress?id=eq.${uidA}`, {
  method: 'DELETE'
})

process.exit(runner.summary('INTENTOS') ? 1 : 0)
