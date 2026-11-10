// Pruebas de la etapa 6: competencia de expo (evento, desafíos y partidas).
//
//   node tests/e2e/challenges.mjs
//
// Verifica contra el proyecto real que:
//   - el banco del desafío está separado del banco de práctica y sus
//     soluciones no se pueden leer por REST ni con check_answer();
//   - el servidor crea la partida, fija preguntas y reglas, y es idempotente;
//   - el servidor valida identidad, pertenencia, vigencia, opción y pregunta;
//   - los puntos y los tiempos los calcula el servidor;
//   - una respuesta repetida (incluso simultánea) no vuelve a sumar;
//   - finalizar es idempotente y clasifica finalizada / incompleta / vencida;
//   - el ranking usa el mejor intento válido por participante;
//   - el cliente no puede insertar, modificar ni borrar puntajes oficiales.
//
// Requiere `supabase/migrations/0006_desafios.sql` y `0007_seed_desafios.sql`
// aplicadas y los invitados anónimos habilitados en el proyecto.

import { randomUUID } from 'node:crypto'

import {
  createRunner,
  createSupabaseClient,
  rest,
  rpc,
  sleep,
  SUPABASE_KEY,
  SUPABASE_URL
} from './helpers.mjs'

// Desafíos internos de la semilla (es_prueba = true).
const CHALLENGE = '50000000-0000-0000-0000-000000000101' // 4 preguntas, 2 intentos, 300 s
const EXPIRED_CHALLENGE = '50000000-0000-0000-0000-000000000102' // 1 s, sin tolerancia
const ONE_ATTEMPT_CHALLENGE = '50000000-0000-0000-0000-000000000103' // 1 intento

const runner = createRunner('=== Etapa 6: competencia de expo ===')

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
  process.exit(runner.summary('DESAFÍOS') ? 1 : 0)
}

const clientB = await createSupabaseClient()
const { data: sessionB } = await clientB.auth.signInAnonymously()

const clientC = await createSupabaseClient()
const { data: sessionC } = await clientC.auth.signInAnonymously()

const tokenA = sessionA.session.access_token
const tokenB = sessionB?.session?.access_token
const tokenC = sessionC?.session?.access_token
const uidA = sessionA.user.id

runner.check('Setup: tres invitados con identidad propia', !!tokenB && !!tokenC)

// --- Contenido del desafío (lectura pública, sin soluciones) ---
const questionsRes = await rest(
  `desafio_preguntas?select=id,orden,enunciado&desafio_id=eq.${CHALLENGE}&order=orden`
)
const questions = Array.isArray(questionsRes.body) ? questionsRes.body : []
runner.check(
  'Contenido: el desafío de prueba tiene 4 preguntas',
  questions.length === 4,
  String(questions.length)
)

const optionsByQuestion = new Map()
for (const question of questions) {
  const options = await rest(
    `desafio_opciones?select=id,orden,texto&pregunta_id=eq.${question.id}&order=orden`
  )
  optionsByQuestion.set(question.id, options.body ?? [])
}
runner.check(
  'Contenido: cada pregunta tiene 4 opciones legibles',
  questions.every(question => optionsByQuestion.get(question.id).length === 4)
)

// La semilla garantiza que la primera opción es la correcta en este desafío.
function opcionCorrecta(question) {
  return optionsByQuestion.get(question.id)[0]?.id
}
function opcionIncorrecta(question) {
  return optionsByQuestion.get(question.id)[1]?.id
}

const solutionsRes = await rest(
  `desafio_soluciones?select=pregunta_id,opcion_correcta_id&limit=1`
)
runner.check(
  'Separación: las soluciones del desafío no se leen por REST',
  solutionsRes.status >= 400 ||
    (Array.isArray(solutionsRes.body) && solutionsRes.body.length === 0),
  `status=${solutionsRes.status}`
)

const checkDesafio = await clientA.rpc('check_answer', {
  p_pregunta: questions[0]?.id,
  p_opcion: opcionCorrecta(questions[0])
})
runner.check(
  'Separación: check_answer() no revela soluciones del desafío',
  tieneCodigo(checkDesafio, 'PR_QUESTION_NOT_PUBLISHED'),
  detalle(checkDesafio)
)

// --- 1. Inicio de partida: servidor, reglas e idempotencia ---
const clave1 = randomUUID()
const inicio1 = await clientA.rpc('iniciar_partida', {
  p_desafio: CHALLENGE,
  p_clave: clave1
})
const partida1 = inicio1.data?.[0]

if (!partida1?.partida) {
  runner.check(
    'Partida: el servidor crea la partida y fija las reglas',
    false,
    detalle(inicio1)
  )
  runner.skip(
    'Resto de la suite',
    'falta aplicar supabase/migrations/0006_desafios.sql y 0007_seed_desafios.sql'
  )
  process.exit(runner.summary('DESAFÍOS') ? 1 : 0)
}

runner.check(
  'Partida: el servidor fija 4 preguntas, 10 puntos y 300 s',
  partida1.total_preguntas === 4 &&
    partida1.puntos_por_acierto === 10 &&
    partida1.duracion_segundos === 300 &&
    partida1.tolerancia_segundos === 10 &&
    partida1.estado === 'en_curso' &&
    partida1.reutilizado === false,
  detalle(inicio1)
)
runner.check(
  'Partida: el servidor registra el inicio y el vencimiento',
  !!partida1.iniciado_en && !!partida1.expira_en
)

const repetido1 = await clientA.rpc('iniciar_partida', {
  p_desafio: CHALLENGE,
  p_clave: clave1
})
runner.check(
  'Idempotencia: la misma clave devuelve la MISMA partida',
  repetido1.data?.[0]?.partida === partida1.partida &&
    repetido1.data?.[0]?.reutilizado === true,
  detalle(repetido1)
)

const clave2 = randomUUID()
const inicio2 = await clientA.rpc('iniciar_partida', {
  p_desafio: CHALLENGE,
  p_clave: clave2
})
const partida2 = inicio2.data?.[0]
runner.check(
  'Intentos: una clave nueva consume otro intento del mismo desafío',
  !inicio2.error &&
    partida2?.partida !== partida1.partida &&
    partida2?.reutilizado === false &&
    partida2?.intentos_usados === 2,
  detalle(inicio2)
)

const preguntasAsignadas = await authRest(
  tokenA,
  `partida_preguntas?select=desafio_pregunta_id,orden&partida_id=eq.${partida1.partida}&order=orden`
)
runner.check(
  'Partida: el servidor guardó las 4 preguntas asignadas',
  preguntasAsignadas.status === 200 &&
    preguntasAsignadas.body.length === 4 &&
    preguntasAsignadas.body.every(row => row.desafio_pregunta_id),
  JSON.stringify(preguntasAsignadas.body)
)

// --- 2. Validaciones de respuesta ---
const [q1, q2, q3, q4] = questions

const respuestaIncorrecta = await clientA.rpc('responder_partida', {
  p_partida: partida1.partida,
  p_pregunta: q1.id,
  p_opcion: opcionIncorrecta(q1)
})
runner.check(
  'Puntos: una respuesta incorrecta suma 0 y lo calcula el servidor',
  !respuestaIncorrecta.error &&
    respuestaIncorrecta.data?.[0]?.correcto === false &&
    respuestaIncorrecta.data?.[0]?.puntos_obtenidos === 0 &&
    respuestaIncorrecta.data?.[0]?.puntos_totales === 0,
  detalle(respuestaIncorrecta)
)

const dobleEnvio = await clientA.rpc('responder_partida', {
  p_partida: partida1.partida,
  p_pregunta: q1.id,
  p_opcion: opcionCorrecta(q1)
})
runner.check(
  'Anti-duplicados: la segunda respuesta devuelve la existente y no suma',
  dobleEnvio.data?.[0]?.repetida === true &&
    dobleEnvio.data?.[0]?.correcto === false &&
    dobleEnvio.data?.[0]?.puntos_totales === 0,
  detalle(dobleEnvio)
)

const opcionAjena = await clientA.rpc('responder_partida', {
  p_partida: partida1.partida,
  p_pregunta: q1.id,
  p_opcion: opcionCorrecta(q2)
})
runner.check(
  'Validación: opción de otra pregunta -> PR_OPCION_INVALIDA',
  tieneCodigo(opcionAjena, 'PR_OPCION_INVALIDA'),
  detalle(opcionAjena)
)

const preguntaAjena = await clientA.rpc('responder_partida', {
  p_partida: partida1.partida,
  p_pregunta: '60000000-0000-0000-0000-000000920101',
  p_opcion: '70000000-0000-0000-0000-000000920101'
})
runner.check(
  'Validación: pregunta de otro desafío -> PR_PREGUNTA_NO_ASIGNADA',
  tieneCodigo(preguntaAjena, 'PR_PREGUNTA_NO_ASIGNADA'),
  detalle(preguntaAjena)
)

const respuestaDeOtro = await clientB.rpc('responder_partida', {
  p_partida: partida1.partida,
  p_pregunta: q2.id,
  p_opcion: opcionCorrecta(q2)
})
runner.check(
  'Aislamiento: B no puede responder la partida de A -> PR_PARTIDA_NOT_FOUND',
  tieneCodigo(respuestaDeOtro, 'PR_PARTIDA_NOT_FOUND'),
  detalle(respuestaDeOtro)
)

const partidaInexistente = await clientA.rpc('responder_partida', {
  p_partida: '99999999-9999-9999-9999-999999999999',
  p_pregunta: q1.id,
  p_opcion: opcionCorrecta(q1)
})
runner.check(
  'Validación: partida inexistente -> PR_PARTIDA_NOT_FOUND',
  tieneCodigo(partidaInexistente, 'PR_PARTIDA_NOT_FOUND'),
  detalle(partidaInexistente)
)

// --- 3. Cierre del primer intento (0 puntos, todas respondidas) ---
for (const question of [q2, q3, q4]) {
  await clientA.rpc('responder_partida', {
    p_partida: partida1.partida,
    p_pregunta: question.id,
    p_opcion: opcionIncorrecta(question)
  })
}
const final1 = await clientA.rpc('finalizar_partida', {
  p_partida: partida1.partida
})
runner.check(
  'Cierre: la partida finalizada guarda 0 puntos y 4 respuestas',
  final1.data?.[0]?.estado === 'finalizada' &&
    final1.data?.[0]?.respondidas === 4 &&
    final1.data?.[0]?.aciertos === 0 &&
    final1.data?.[0]?.errores === 4 &&
    final1.data?.[0]?.puntos === 0 &&
    final1.data?.[0]?.reutilizado === false,
  detalle(final1)
)

const final1bis = await clientA.rpc('finalizar_partida', {
  p_partida: partida1.partida
})
runner.check(
  'Cierre repetido: devuelve el mismo resultado sin recalcular',
  final1bis.data?.[0]?.reutilizado === true &&
    final1bis.data?.[0]?.puntos === 0 &&
    final1bis.data?.[0]?.estado === 'finalizada',
  detalle(final1bis)
)

const respuestaTrasCierre = await clientA.rpc('responder_partida', {
  p_partida: partida1.partida,
  p_pregunta: q1.id,
  p_opcion: opcionCorrecta(q1)
})
runner.check(
  'Anti-duplicados: responder de nuevo tras cerrar devuelve la respuesta existente',
  respuestaTrasCierre.data?.[0]?.repetida === true &&
    respuestaTrasCierre.data?.[0]?.correcto === false,
  detalle(respuestaTrasCierre)
)

// --- 4. Segundo intento: puntos, doble envío simultáneo y resultado ---
const respuestaA1 = await clientA.rpc('responder_partida', {
  p_partida: partida2.partida,
  p_pregunta: q1.id,
  p_opcion: opcionCorrecta(q1)
})
runner.check(
  'Puntos: una respuesta correcta suma los 10 puntos del servidor',
  respuestaA1.data?.[0]?.correcto === true &&
    respuestaA1.data?.[0]?.puntos_obtenidos === 10 &&
    respuestaA1.data?.[0]?.puntos_totales === 10,
  detalle(respuestaA1)
)

// Dos envíos simultáneos de la misma pregunta: la restricción única y el
// bloqueo de la fila hacen que solo uno sume.
const [simultanea1, simultanea2] = await Promise.all([
  clientA.rpc('responder_partida', {
    p_partida: partida2.partida,
    p_pregunta: q2.id,
    p_opcion: opcionCorrecta(q2)
  }),
  clientA.rpc('responder_partida', {
    p_partida: partida2.partida,
    p_pregunta: q2.id,
    p_opcion: opcionCorrecta(q2)
  })
])
const repetidas = [simultanea1, simultanea2].filter(
  result => result.data?.[0]?.repetida === true
)
runner.check(
  'Reintentos simultáneos: solo una respuesta suma (20 puntos, no 30)',
  !simultanea1.error &&
    !simultanea2.error &&
    repetidas.length === 1 &&
    simultanea1.data?.[0]?.puntos_totales === 20 &&
    simultanea2.data?.[0]?.puntos_totales === 20,
  `${detalle(simultanea1)} / ${detalle(simultanea2)}`
)

for (const question of [q3, q4]) {
  await clientA.rpc('responder_partida', {
    p_partida: partida2.partida,
    p_pregunta: question.id,
    p_opcion: opcionCorrecta(question)
  })
}
const final2 = await clientA.rpc('finalizar_partida', {
  p_partida: partida2.partida
})
runner.check(
  'Resultado: 4 aciertos y 40 puntos calculados en el servidor',
  final2.data?.[0]?.estado === 'finalizada' &&
    final2.data?.[0]?.aciertos === 4 &&
    final2.data?.[0]?.errores === 0 &&
    final2.data?.[0]?.puntos === 40 &&
    Number(final2.data?.[0]?.duracion_ms) >= 0,
  detalle(final2)
)

const resultado2 = await clientA.rpc('resultado_partida', {
  p_partida: partida2.partida
})
const detalle2 = resultado2.data ?? []
runner.check(
  'Resultado: el detalle muestra las 4 respuestas guardadas',
  detalle2.length === 4 && detalle2.every(row => row.respondida === true),
  detalle(resultado2)
)
runner.check(
  'Resultado: mientras el desafío sigue abierto no revela la solución',
  detalle2.length === 4 &&
    detalle2.every(
      row =>
        row.revelado === false &&
        row.opcion_correcta_id === null &&
        row.explicacion === null
    ),
  detalle(resultado2)
)

const resultadoAjeno = await clientB.rpc('resultado_partida', {
  p_partida: partida2.partida
})
runner.check(
  'Aislamiento: B no puede ver el resultado de A -> PR_PARTIDA_NOT_FOUND',
  tieneCodigo(resultadoAjeno, 'PR_PARTIDA_NOT_FOUND'),
  detalle(resultadoAjeno)
)

// --- 5. Dos jugadores simultáneos ---
const inicioB = await clientB.rpc('iniciar_partida', {
  p_desafio: CHALLENGE,
  p_clave: randomUUID()
})
const partidaB = inicioB.data?.[0]
runner.check(
  'Jugador B: inicia su propia partida',
  !inicioB.error && !!partidaB?.partida,
  detalle(inicioB)
)

// A abre otra partida (en el desafío de un intento) y responde a la vez que
// B en su propia partida: dos jugadores concurrentes, sin mezclar resultados.
const inicioA103 = await clientA.rpc('iniciar_partida', {
  p_desafio: ONE_ATTEMPT_CHALLENGE,
  p_clave: randomUUID()
})
const partidaA103 = inicioA103.data?.[0]
let carreraA
let carreraB
if (partidaA103?.partida) {
  ;[carreraA, carreraB] = await Promise.all([
    clientA.rpc('responder_partida', {
      p_partida: partidaA103.partida,
      p_pregunta: '60000000-0000-0000-0000-000000930101',
      p_opcion: '70000000-0000-0000-0000-000000930101'
    }),
    clientB.rpc('responder_partida', {
      p_partida: partidaB.partida,
      p_pregunta: q1.id,
      p_opcion: opcionCorrecta(q1)
    })
  ])
} else {
  carreraA = { error: inicioA103.error }
  carreraB = await clientB.rpc('responder_partida', {
    p_partida: partidaB.partida,
    p_pregunta: q1.id,
    p_opcion: opcionCorrecta(q1)
  })
}
runner.check(
  'Dos jugadores simultáneos: cada uno recibe el resultado de su partida',
  !inicioA103.error &&
    !carreraA.error &&
    !carreraB.error &&
    carreraA.data?.[0]?.puntos_totales === 10 &&
    carreraB.data?.[0]?.puntos_totales === 10,
  `${detalle(inicioA103)} / ${detalle(carreraA)} / ${detalle(carreraB)}`
)

// Se cierra la partida de A en 103 como incompleta para no dejarla abierta.
if (partidaA103?.partida) {
  await clientA.rpc('finalizar_partida', {
    p_partida: partidaA103.partida
  })
}

// B completa con 3 aciertos y 1 error: 30 puntos.
await clientB.rpc('responder_partida', {
  p_partida: partidaB.partida,
  p_pregunta: q2.id,
  p_opcion: opcionCorrecta(q2)
})
await clientB.rpc('responder_partida', {
  p_partida: partidaB.partida,
  p_pregunta: q3.id,
  p_opcion: opcionCorrecta(q3)
})
await clientB.rpc('responder_partida', {
  p_partida: partidaB.partida,
  p_pregunta: q4.id,
  p_opcion: opcionIncorrecta(q4)
})
const finalB = await clientB.rpc('finalizar_partida', {
  p_partida: partidaB.partida
})
runner.check(
  'Jugador B: cierra con 30 puntos y 1 error',
  finalB.data?.[0]?.estado === 'finalizada' &&
    finalB.data?.[0]?.puntos === 30 &&
    finalB.data?.[0]?.aciertos === 3 &&
    finalB.data?.[0]?.errores === 1,
  detalle(finalB)
)

// --- 6. Ranking: mejor intento válido por participante ---
const rankingA = await clientA.rpc('ranking_desafio', {
  p_desafio: CHALLENGE,
  p_limite: 200
})
const filasRanking = rankingA.data ?? []
const filaA = filasRanking.find(row => row.partida === partida2.partida)
const filaB = filasRanking.find(row => row.partida === partidaB.partida)
runner.check(
  'Ranking: A aparece con su MEJOR intento (40), no con el de 0',
  !!filaA &&
    filaA.puntos === 40 &&
    filaA.es_yo === true &&
    !filasRanking.some(row => row.partida === partida1.partida),
  JSON.stringify(filasRanking.slice(0, 5))
)
runner.check(
  'Ranking: B aparece con 30 puntos y no se marca como A',
  !!filaB && filaB.puntos === 30 && filaB.es_yo === false,
  JSON.stringify(filaB)
)
runner.check(
  'Ranking: cada participante aparece una sola vez',
  filasRanking.filter(row => row.es_yo === true).length === 1,
  JSON.stringify(filasRanking.filter(row => row.es_yo))
)
runner.check(
  'Ranking: A queda antes que B por tener más puntos',
  !!filaA &&
    !!filaB &&
    Number(filaA.posicion) < Number(filaB.posicion),
  `A=${filaA?.posicion} B=${filaB?.posicion}`
)

const rankingB = await clientB.rpc('ranking_desafio', {
  p_desafio: CHALLENGE,
  p_limite: 200
})
const filaBComoYo = (rankingB.data ?? []).find(
  row => row.partida === partidaB.partida
)
runner.check(
  'Ranking: "es_yo" se calcula para cada participante',
  filaBComoYo?.es_yo === true &&
    (rankingB.data ?? []).find(row => row.partida === partida2.partida)
      ?.es_yo === false,
  JSON.stringify(filaBComoYo)
)

// --- 7. Partida vencida: el tiempo lo controla el servidor ---
const inicioVencida = await clientA.rpc('iniciar_partida', {
  p_desafio: EXPIRED_CHALLENGE,
  p_clave: randomUUID()
})
const partidaVencida = inicioVencida.data?.[0]
runner.check(
  'Vencida: la partida de 1 s se inicia con su propio vencimiento',
  !inicioVencida.error && partidaVencida?.duracion_segundos === 1,
  detalle(inicioVencida)
)

await sleep(1400)

const respuestaVencida = await clientA.rpc('responder_partida', {
  p_partida: partidaVencida.partida,
  p_pregunta: '60000000-0000-0000-0000-000000920101',
  p_opcion: '70000000-0000-0000-0000-000000920101'
})
runner.check(
  'Vencida: fuera del plazo no se aceptan respuestas -> PR_PARTIDA_EXPIRADA',
  tieneCodigo(respuestaVencida, 'PR_PARTIDA_EXPIRADA'),
  detalle(respuestaVencida)
)

const finalVencida = await clientA.rpc('finalizar_partida', {
  p_partida: partidaVencida.partida
})
runner.check(
  'Vencida: cerrar fuera de la tolerancia marca estado "vencida"',
  finalVencida.data?.[0]?.estado === 'vencida' &&
    finalVencida.data?.[0]?.respondidas === 0 &&
    finalVencida.data?.[0]?.puntos === 0 &&
    finalVencida.data?.[0]?.reutilizado === false,
  detalle(finalVencida)
)
const finalVencidaBis = await clientA.rpc('finalizar_partida', {
  p_partida: partidaVencida.partida
})
runner.check(
  'Vencida: el cierre repetido es idempotente',
  finalVencidaBis.data?.[0]?.reutilizado === true &&
    finalVencidaBis.data?.[0]?.estado === 'vencida',
  detalle(finalVencidaBis)
)

const resultadoVencida = await clientA.rpc('resultado_partida', {
  p_partida: partidaVencida.partida
})
runner.check(
  'Vencida: el detalle muestra las preguntas sin responder',
  (resultadoVencida.data ?? []).length === 2 &&
    (resultadoVencida.data ?? []).every(row => row.respondida === false),
  detalle(resultadoVencida)
)

const rankingVencida = await clientA.rpc('ranking_desafio', {
  p_desafio: EXPIRED_CHALLENGE,
  p_limite: 200
})
runner.check(
  'Ranking: una partida vencida no compite',
  !(rankingVencida.data ?? []).some(
    row => row.partida === partidaVencida.partida
  ),
  JSON.stringify(rankingVencida.data ?? [])
)

// --- 8. Partida incompleta, cierre anticipado y agotamiento de intentos ---
const claveIncompleta = randomUUID()
const inicioIncompleta = await clientC.rpc('iniciar_partida', {
  p_desafio: ONE_ATTEMPT_CHALLENGE,
  p_clave: claveIncompleta
})
const partidaIncompleta = inicioIncompleta.data?.[0]
runner.check(
  'Incompleta: C inicia el desafío de un solo intento',
  !inicioIncompleta.error && !!partidaIncompleta?.partida,
  detalle(inicioIncompleta)
)

await clientC.rpc('responder_partida', {
  p_partida: partidaIncompleta.partida,
  p_pregunta: '60000000-0000-0000-0000-000000930101',
  p_opcion: '70000000-0000-0000-0000-000000930101'
})
const finalIncompleta = await clientC.rpc('finalizar_partida', {
  p_partida: partidaIncompleta.partida
})
runner.check(
  'Incompleta: cerrar antes de responder todo marca "incompleta"',
  finalIncompleta.data?.[0]?.estado === 'incompleta' &&
    finalIncompleta.data?.[0]?.respondidas === 1 &&
    finalIncompleta.data?.[0]?.puntos === 10,
  detalle(finalIncompleta)
)

const respuestaTarde = await clientC.rpc('responder_partida', {
  p_partida: partidaIncompleta.partida,
  p_pregunta: '60000000-0000-0000-0000-000000930102',
  p_opcion: '70000000-0000-0000-0000-000000930201'
})
runner.check(
  'Incompleta: una partida cerrada no acepta respuestas nuevas -> PR_PARTIDA_CERRADA',
  tieneCodigo(respuestaTarde, 'PR_PARTIDA_CERRADA'),
  detalle(respuestaTarde)
)

const segundoIntento = await clientC.rpc('iniciar_partida', {
  p_desafio: ONE_ATTEMPT_CHALLENGE,
  p_clave: randomUUID()
})
runner.check(
  'Intentos: agotar el límite -> PR_INTENTOS_AGOTADOS',
  tieneCodigo(segundoIntento, 'PR_INTENTOS_AGOTADOS'),
  detalle(segundoIntento)
)

const mismaClaveTrasAgotar = await clientC.rpc('iniciar_partida', {
  p_desafio: ONE_ATTEMPT_CHALLENGE,
  p_clave: claveIncompleta
})
runner.check(
  'Idempotencia: la misma clave sigue devolviendo la partida tras agotar intentos',
  mismaClaveTrasAgotar.data?.[0]?.partida === partidaIncompleta.partida &&
    mismaClaveTrasAgotar.data?.[0]?.reutilizado === true,
  detalle(mismaClaveTrasAgotar)
)

const rankingIncompleta = await clientC.rpc('ranking_desafio', {
  p_desafio: ONE_ATTEMPT_CHALLENGE,
  p_limite: 200
})
runner.check(
  'Ranking: una partida incompleta no compite',
  !(rankingIncompleta.data ?? []).some(
    row => row.partida === partidaIncompleta.partida
  ),
  JSON.stringify(rankingIncompleta.data ?? [])
)

// --- 9. Aislamiento de partidas, preguntas y respuestas ---
const partidasDeB = await authRest(
  tokenB,
  `partidas?select=id&id=eq.${partida1.partida}`
)
runner.check(
  'Aislamiento: B no ve la partida de A (0 filas)',
  partidasDeB.status === 200 && partidasDeB.body.length === 0,
  JSON.stringify(partidasDeB.body)
)

const preguntasDeB = await authRest(
  tokenB,
  `partida_preguntas?select=partida_id&partida_id=eq.${partida1.partida}`
)
runner.check(
  'Aislamiento: B no ve las preguntas asignadas a A (0 filas)',
  preguntasDeB.status === 200 && preguntasDeB.body.length === 0,
  JSON.stringify(preguntasDeB.body)
)

const respuestasDeB = await authRest(
  tokenB,
  `partida_respuestas?select=partida_id&partida_id=eq.${partida1.partida}`
)
runner.check(
  'Aislamiento: B no ve las respuestas de A (0 filas)',
  respuestasDeB.status === 200 && respuestasDeB.body.length === 0,
  JSON.stringify(respuestasDeB.body)
)

const respuestasPropias = await authRest(
  tokenA,
  `partida_respuestas?select=desafio_pregunta_id,correcto,puntos_obtenidos&partida_id=eq.${partida2.partida}`
)
runner.check(
  'Historial: A ve sus 4 respuestas y sus puntos',
  respuestasPropias.status === 200 &&
    respuestasPropias.body.length === 4 &&
    respuestasPropias.body.every(row => row.puntos_obtenidos === 10),
  JSON.stringify(respuestasPropias.body)
)

const finalizarAjeno = await clientA.rpc('finalizar_partida', {
  p_partida: partidaB.partida
})
runner.check(
  'Aislamiento: A no puede finalizar la partida de B',
  tieneCodigo(finalizarAjeno, 'PR_PARTIDA_NOT_FOUND'),
  detalle(finalizarAjeno)
)

// --- 10. Puntajes oficiales: escritura directa bloqueada ---
const insercionPartida = await authRest(tokenA, 'partidas', {
  method: 'POST',
  headers: { 'content-type': 'application/json', Prefer: 'return=minimal' },
  body: JSON.stringify({
    participante_id: uidA,
    desafio_id: CHALLENGE,
    clave_idempotencia: randomUUID(),
    total_preguntas: 4,
    puntos: 9999,
    aciertos: 4,
    errores: 0,
    puntos_por_acierto: 10,
    duracion_segundos: 300,
    expira_en: new Date(Date.now() + 300000).toISOString()
  })
})
runner.check(
  'Puntaje manipulado: insertar una partida por REST está bloqueado',
  insercionPartida.status >= 400,
  `status=${insercionPartida.status}`
)

const actualizacionPuntaje = await authRest(
  tokenA,
  `partidas?id=eq.${partida2.partida}`,
  {
    method: 'PATCH',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ puntos: 9999, aciertos: 999 })
  }
)
runner.check(
  'Puntaje manipulado: modificar puntos por REST está bloqueado',
  actualizacionPuntaje.status >= 400,
  `status=${actualizacionPuntaje.status}`
)

const partidaTrasIntento = await authRest(
  tokenA,
  `partidas?select=puntos,aciertos,errores&id=eq.${partida2.partida}`
)
runner.check(
  'Puntaje manipulado: los puntos oficiales siguen siendo 40',
  partidaTrasIntento.status === 200 &&
    partidaTrasIntento.body?.[0]?.puntos === 40 &&
    partidaTrasIntento.body?.[0]?.aciertos === 4 &&
    partidaTrasIntento.body?.[0]?.errores === 0,
  JSON.stringify(partidaTrasIntento.body)
)

const borradoPartida = await authRest(
  tokenA,
  `partidas?id=eq.${partida2.partida}`,
  { method: 'DELETE' }
)
runner.check(
  'Puntaje manipulado: borrar la partida para reiniciar intentos está bloqueado',
  borradoPartida.status >= 400,
  `status=${borradoPartida.status}`
)

const insercionRespuesta = await authRest(tokenA, 'partida_respuestas', {
  method: 'POST',
  headers: { 'content-type': 'application/json', Prefer: 'return=minimal' },
  body: JSON.stringify({
    partida_id: partida2.partida,
    desafio_pregunta_id: q1.id,
    desafio_opcion_id: opcionCorrecta(q1),
    correcto: true,
    puntos_obtenidos: 9999,
    tiempo_ms: 0
  })
})
runner.check(
  'Puntaje manipulado: insertar respuestas por REST está bloqueado',
  insercionRespuesta.status >= 400,
  `status=${insercionRespuesta.status}`
)

const insercionPregunta = await authRest(tokenA, 'partida_preguntas', {
  method: 'POST',
  headers: { 'content-type': 'application/json', Prefer: 'return=minimal' },
  body: JSON.stringify({
    partida_id: partida2.partida,
    desafio_pregunta_id: q1.id,
    orden: 9
  })
})
runner.check(
  'Puntaje manipulado: cambiar las preguntas asignadas por REST está bloqueado',
  insercionPregunta.status >= 400,
  `status=${insercionPregunta.status}`
)

// --- 11. Hora del servidor, sesión y contenido inexistente ---
const hora = await rpc('hora_servidor', {})
const horaServidor = hora.body?.[0]?.hora
runner.check(
  'Tiempo: hora_servidor() responde y coincide con la hora real',
  hora.status === 200 &&
    !!horaServidor &&
    Math.abs(new Date(horaServidor).getTime() - Date.now()) < 5 * 60 * 1000,
  JSON.stringify(hora.body)
)

const anonimo = await createSupabaseClient()
const sinSesion = await anonimo.rpc('iniciar_partida', {
  p_desafio: CHALLENGE,
  p_clave: randomUUID()
})
const errorSinSesion = `${sinSesion.error?.message ?? ''} ${
  sinSesion.error?.details ?? ''
}`
runner.check(
  'Sesión: sin sesión no se inicia una partida (rechazo del servidor)',
  !!sinSesion.error &&
    (tieneCodigo(sinSesion, 'PR_AUTH_REQUIRED') ||
      /permission denied|not allowed|JWT/i.test(errorSinSesion)),
  detalle(sinSesion)
)

const desafioInexistente = await clientA.rpc('iniciar_partida', {
  p_desafio: '99999999-9999-9999-9999-999999999999',
  p_clave: randomUUID()
})
runner.check(
  'Contenido: desafío inexistente -> PR_DESAFIO_NOT_FOUND',
  tieneCodigo(desafioInexistente, 'PR_DESAFIO_NOT_FOUND'),
  detalle(desafioInexistente)
)

const rankingPublico = await rpc('ranking_desafio', {
  p_desafio: CHALLENGE,
  p_limite: 5
})
runner.check(
  'Ranking: se puede consultar sin sesión (público)',
  rankingPublico.status === 200 && Array.isArray(rankingPublico.body),
  `status=${rankingPublico.status}`
)

process.exit(runner.summary('DESAFÍOS') ? 1 : 0)
