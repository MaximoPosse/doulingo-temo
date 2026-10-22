// Intentos y respuestas del participante.
//
// El servidor es la única fuente de verdad del resultado:
//   - `iniciar_intento` crea el intento (idempotente por clave);
//   - `registrar_respuesta` corrige contra `soluciones` y guarda la
//     primera respuesta de cada actividad;
//   - `finalizar_intento` calcula aciertos, errores y aprobación, y
//     actualiza el progreso de la lección.
// El cliente nunca envía aciertos ni porcentajes: solo la opción elegida.

import { getSupabaseClient } from '@/lib/supabase'

const MENSAJES = {
  PR_AUTH_REQUIRED: 'Necesitás una sesión para registrar intentos.',
  PR_INVALID_KEY: 'No se pudo identificar el intento. Volvé a empezar.',
  PR_LESSON_NOT_PUBLISHED: 'La lección no está disponible.',
  PR_LESSON_EMPTY: 'La lección no tiene actividades.',
  PR_ATTEMPT_NOT_FOUND:
    'No encontramos ese intento. Volvé a empezar la lección.',
  PR_ATTEMPT_CLOSED: 'Ese intento ya está cerrado.',
  PR_ATTEMPT_INCOMPLETE: 'Todavía quedan actividades sin responder.',
  PR_QUESTION_NOT_IN_ATTEMPT: 'La actividad no pertenece a esta lección.',
  PR_OPTION_NOT_IN_QUESTION: 'La opción no pertenece a la actividad.',
  PR_SOLUTION_NOT_FOUND: 'La actividad no tiene una solución cargada.'
}

function mensajeError(err, fallback) {
  const raw = `${err?.message ?? ''} ${err?.details ?? ''}`
  for (const [code, message] of Object.entries(MENSAJES)) {
    if (raw.includes(code)) return message
  }
  if (/fetch|network|failed to|load failed/i.test(raw)) {
    return 'No se pudo contactar al servidor. Revisá tu conexión.'
  }
  return err?.message && err.message.length <= 140 ? err.message : fallback
}

async function rpc(nombre, args, fallback) {
  let result
  try {
    result = await getSupabaseClient().rpc(nombre, args)
  } catch (err) {
    throw new Error(mensajeError(err, fallback))
  }
  if (result.error) throw new Error(mensajeError(result.error, fallback))
  return result.data?.[0] ?? null
}

function unwrap(result, fallback) {
  if (result.error) throw new Error(mensajeError(result.error, fallback))
  return result.data ?? []
}

// ---------- Intento en curso ----------

export async function iniciarIntento(leccionId, clave) {
  const row = await rpc(
    'iniciar_intento',
    { p_leccion: leccionId, p_clave: clave },
    'No se pudo iniciar el intento.'
  )
  if (!row) throw new Error('El servidor no devolvió el intento.')
  return {
    id: row.intento,
    leccionId: row.leccion,
    totalActividades: row.total_actividades,
    estado: row.estado,
    iniciadoEn: row.iniciado_en,
    reutilizado: row.reutilizado === true
  }
}

export async function registrarRespuesta(intentoId, actividadId, opcionId) {
  const row = await rpc(
    'registrar_respuesta',
    { p_intento: intentoId, p_pregunta: actividadId, p_opcion: opcionId },
    'No se pudo registrar la respuesta.'
  )
  if (!row) throw new Error('El servidor no devolvió el resultado.')
  return {
    correcto: row.correcto === true,
    explicacion: row.explicacion ?? '',
    opcionCorrectaId: row.opcion_correcta_id,
    opcionElegidaId: row.opcion_elegida_id,
    repetida: row.repetida === true
  }
}

export async function finalizarIntento(intentoId) {
  const row = await rpc(
    'finalizar_intento',
    { p_intento: intentoId },
    'No se pudo guardar el resultado.'
  )
  if (!row) throw new Error('El servidor no devolvió el resultado.')
  return {
    id: row.intento,
    leccionId: row.leccion,
    totalActividades: row.total_actividades,
    aciertos: row.aciertos,
    errores: row.errores,
    aprobada: row.aprobada === true,
    estado: row.estado,
    iniciadoEn: row.iniciado_en,
    finalizadoEn: row.finalizado_en,
    reutilizado: row.reutilizado === true
  }
}

// ---------- Historial ----------

// Intentos del participante con el título de la lección. Los que están
// `en_curso` quedaron sin terminar (se salió, se cerró la app o se perdió
// la conexión): se muestran, pero no cuentan como resultado.
export async function fetchAttempts() {
  const rows = unwrap(
    await getSupabaseClient()
      .from('intentos')
      .select(
        'id, leccion_id, estado, total_actividades, aciertos, errores, ' +
          'aprobada, iniciado_en, finalizado_en, lecciones(titulo, orden)'
      )
      .order('iniciado_en', { ascending: false })
      .limit(60),
    'No se pudo leer el historial de intentos.'
  )
  return rows.map(row => ({
    id: row.id,
    lessonId: row.leccion_id,
    lessonTitle: row.lecciones?.titulo ?? 'Lección',
    estado: row.estado,
    totalActividades: row.total_actividades,
    aciertos: row.aciertos,
    errores: row.errores,
    aprobada: row.aprobada === true,
    iniciadoEn: row.iniciado_en,
    finalizadoEn: row.finalizado_en
  }))
}

// Respuestas guardadas de los intentos indicados, con el enunciado de la
// actividad y el texto de la opción elegida.
export async function fetchAttemptAnswers(attemptIds) {
  if (!attemptIds.length) return []
  const rows = unwrap(
    await getSupabaseClient()
      .from('intentos_respuestas')
      .select(
        'intento_id, actividad_id, correcto, opcion_id, ' +
          'preguntas(enunciado, orden), opciones(texto)'
      )
      .in('intento_id', attemptIds)
      .order('respondido_en', { ascending: true }),
    'No se pudieron leer las respuestas del historial.'
  )
  return rows.map(row => ({
    attemptId: row.intento_id,
    activityId: row.actividad_id,
    question: row.preguntas?.enunciado ?? 'Actividad',
    order: row.preguntas?.orden ?? 0,
    option: row.opciones?.texto ?? '',
    correct: row.correcto === true
  }))
}

// Borra los intentos propios (las respuestas caen en cascada).
export async function clearAttempts() {
  const uid = (await getSupabaseClient().auth.getSession()).data.session?.user
    ?.id
  if (!uid) return
  const { error } = await getSupabaseClient()
    .from('intentos')
    .delete()
    .eq('participante_id', uid)
  if (error) {
    throw new Error(
      mensajeError(error, 'No se pudo borrar el historial de intentos.')
    )
  }
}
