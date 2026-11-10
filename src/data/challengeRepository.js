// Competencia de expo: evento, desafíos, partidas y ranking.
//
// El servidor es la única fuente de verdad:
//   - `iniciar_partida` crea la partida y fija sus preguntas y reglas;
//   - `responder_partida` valida y corrige la primera respuesta, y calcula
//     los puntos;
//   - `finalizar_partida` cierra la partida y calcula el resultado;
//   - `resultado_partida` entrega el detalle (la solución solo se revela
//     cuando el desafío o el evento cerraron);
//   - `ranking_desafio` devuelve el mejor intento válido por participante.
// El cliente nunca envía puntos, aciertos ni tiempos oficiales.

import { getSupabaseClient } from '@/lib/supabase'

const MENSAJES = {
  PR_AUTH_REQUIRED: 'Necesitás una sesión para jugar un desafío.',
  PR_INVALID_KEY: 'No se pudo identificar la partida. Volvé a empezar.',
  PR_DESAFIO_NOT_FOUND: 'El desafío no existe.',
  PR_DESAFIO_CERRADO: 'El desafío no está abierto en este momento.',
  PR_DESAFIO_SIN_PREGUNTAS: 'El desafío no tiene preguntas cargadas.',
  PR_DESAFIO_INCOMPLETO: 'El desafío tiene preguntas sin solución válida.',
  PR_INTENTOS_AGOTADOS:
    'Ya usaste todos los intentos permitidos en este desafío.',
  PR_PARTIDA_NOT_FOUND:
    'No encontramos esa partida. Volvé a empezar el desafío.',
  PR_PARTIDA_CERRADA: 'Esa partida ya está cerrada.',
  PR_PARTIDA_EXPIRADA: 'El tiempo de la partida terminó.',
  PR_PARTIDA_EN_CURSO: 'La partida todavía está en curso.',
  PR_PREGUNTA_NO_ASIGNADA: 'La pregunta no pertenece a esta partida.',
  PR_OPCION_INVALIDA: 'La opción no pertenece a la pregunta indicada.',
  PR_SOLUCION_NO_DISPONIBLE: 'La pregunta no tiene una solución cargada.'
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

function client() {
  return getSupabaseClient()
}

function unwrap(result, fallback) {
  if (result.error) throw new Error(mensajeError(result.error, fallback))
  return result.data ?? []
}

async function rpc(nombre, args, fallback) {
  let result
  try {
    result = await client().rpc(nombre, args)
  } catch (err) {
    throw new Error(mensajeError(err, fallback))
  }
  if (result.error) throw new Error(mensajeError(result.error, fallback))
  return result.data ?? []
}

// ---------- Evento y desafíos ----------

function mapEvent(row) {
  return {
    id: row.id,
    slug: row.slug,
    titulo: row.titulo,
    descripcion: row.descripcion,
    iniciaEn: row.inicia_en,
    terminaEn: row.termina_en,
    estado: row.estado
  }
}

function mapChallenge(row) {
  return {
    id: row.id,
    eventoId: row.evento_id,
    slug: row.slug,
    titulo: row.titulo,
    descripcion: row.descripcion,
    dificultad: row.dificultad,
    duracionSegundos: row.duracion_segundos,
    puntosPorAcierto: row.puntos_por_acierto,
    intentosPermitidos: row.intentos_permitidos,
    toleranciaSegundos: row.tolerancia_segundos,
    estado: row.estado,
    orden: row.orden,
    totalPreguntas: Array.isArray(row.desafio_preguntas)
      ? row.desafio_preguntas.length
      : 0,
    event: row.eventos ? mapEvent(row.eventos) : null
  }
}

// Evento público de la expo con sus desafíos publicados. Los eventos y
// desafíos internos de prueba (`es_prueba`) se ocultan en la interfaz.
export async function fetchExpo() {
  const eventResult = await client()
    .from('eventos')
    .select(
      'id, slug, titulo, descripcion, inicia_en, termina_en, estado, es_prueba'
    )
    .eq('estado', 'publicado')
    .eq('es_prueba', false)
    .order('inicia_en', { ascending: true })
    .limit(1)
    .maybeSingle()

  if (eventResult.error) {
    throw new Error(
      mensajeError(eventResult.error, 'No se pudo cargar la expo.')
    )
  }
  if (!eventResult.data) return { event: null, challenges: [] }

  const event = mapEvent(eventResult.data)
  const challengeRows = unwrap(
    await client()
      .from('desafios')
      .select(
        'id, evento_id, slug, titulo, descripcion, dificultad, ' +
          'duracion_segundos, puntos_por_acierto, intentos_permitidos, ' +
          'tolerancia_segundos, estado, orden, desafio_preguntas(id)'
      )
      .eq('evento_id', event.id)
      .eq('estado', 'publicado')
      .eq('es_prueba', false)
      .order('orden', { ascending: true }),
    'No se pudieron cargar los desafíos.'
  )

  return { event, challenges: challengeRows.map(mapChallenge) }
}

// Detalle de un desafío y de su evento. Devuelve null si no está visible.
export async function fetchChallenge(challengeId) {
  const result = await client()
    .from('desafios')
    .select(
      'id, evento_id, slug, titulo, descripcion, dificultad, ' +
        'duracion_segundos, puntos_por_acierto, intentos_permitidos, ' +
        'tolerancia_segundos, estado, orden, ' +
        'eventos(id, slug, titulo, descripcion, inicia_en, termina_en, estado), ' +
        'desafio_preguntas(id)'
    )
    .eq('id', challengeId)
    .maybeSingle()

  if (result.error) {
    throw new Error(
      mensajeError(result.error, 'No se pudo cargar el desafío.')
    )
  }
  return result.data ? mapChallenge(result.data) : null
}

// ---------- Partidas ----------

function mapPartida(row) {
  return {
    id: row.id,
    desafioId: row.desafio_id,
    estado: row.estado,
    totalPreguntas: row.total_preguntas,
    puntos: row.puntos,
    aciertos: row.aciertos,
    errores: row.errores,
    iniciadoEn: row.iniciado_en,
    expiraEn: row.expira_en,
    finalizadoEn: row.finalizado_en,
    duracionMs: row.duracion_ms
  }
}

// Partidas propias de un desafío, de la más reciente a la más vieja. Se usa
// para saber cuántos intentos se consumieron y si hay una partida en curso
// para continuar.
export async function fetchMyPartidas(challengeId) {
  const rows = unwrap(
    await client()
      .from('partidas')
      .select(
        'id, desafio_id, estado, total_preguntas, puntos, aciertos, errores, ' +
          'iniciado_en, expira_en, finalizado_en, duracion_ms'
      )
      .eq('desafio_id', challengeId)
      .order('iniciado_en', { ascending: false })
      .limit(20),
    'No se pudo leer tu historial del desafío.'
  )
  return rows.map(mapPartida)
}

// Historial completo de desafíos del participante (para el perfil). Incluye
// el título del desafío y conserva las partidas incompletas o vencidas.
export async function fetchMyChallengeHistory(limit = 30) {
  const rows = unwrap(
    await client()
      .from('partidas')
      .select(
        'id, desafio_id, estado, total_preguntas, puntos, aciertos, errores, ' +
          'iniciado_en, expira_en, finalizado_en, duracion_ms, ' +
          'desafios(id, slug, titulo, dificultad)'
      )
      .order('iniciado_en', { ascending: false })
      .limit(limit),
    'No se pudo leer tu historial de desafíos.'
  )
  return rows.map(row => ({
    ...mapPartida(row),
    challengeTitle: row.desafios?.titulo ?? 'Desafío',
    challengeSlug: row.desafios?.slug ?? null,
    challengeDifficulty: row.desafios?.dificultad ?? null
  }))
}

export async function startChallenge(challengeId, clave) {
  const rows = await rpc(
    'iniciar_partida',
    { p_desafio: challengeId, p_clave: clave },
    'No se pudo iniciar la partida.'
  )
  const row = rows[0]
  if (!row) throw new Error('El servidor no devolvió la partida.')
  return {
    id: row.partida,
    desafioId: row.desafio,
    estado: row.estado,
    totalPreguntas: row.total_preguntas,
    puntosPorAcierto: row.puntos_por_acierto,
    duracionSegundos: row.duracion_segundos,
    toleranciaSegundos: row.tolerancia_segundos,
    iniciadoEn: row.iniciado_en,
    expiraEn: row.expira_en,
    intentosUsados: row.intentos_usados,
    intentosPermitidos: row.intentos_permitidos,
    reutilizado: row.reutilizado === true
  }
}

export async function answerChallenge(partidaId, preguntaId, opcionId) {
  const rows = await rpc(
    'responder_partida',
    {
      p_partida: partidaId,
      p_pregunta: preguntaId,
      p_opcion: opcionId
    },
    'No se pudo registrar la respuesta.'
  )
  const row = rows[0]
  if (!row) throw new Error('El servidor no devolvió el resultado.')
  return {
    correcto: row.correcto === true,
    puntosObtenidos: row.puntos_obtenidos,
    puntosTotales: row.puntos_totales,
    respondidas: row.respondidas,
    totalPreguntas: row.total_preguntas,
    repetida: row.repetida === true,
    expiraEn: row.expira_en
  }
}

export async function finishChallenge(partidaId) {
  const rows = await rpc(
    'finalizar_partida',
    { p_partida: partidaId },
    'No se pudo finalizar la partida.'
  )
  const row = rows[0]
  if (!row) throw new Error('El servidor no devolvió el resultado.')
  return {
    id: row.partida,
    desafioId: row.desafio,
    estado: row.estado,
    totalPreguntas: row.total_preguntas,
    respondidas: row.respondidas,
    aciertos: row.aciertos,
    errores: row.errores,
    puntos: row.puntos,
    duracionMs: row.duracion_ms,
    iniciadoEn: row.iniciado_en,
    expiraEn: row.expira_en,
    finalizadoEn: row.finalizado_en,
    reutilizado: row.reutilizado === true
  }
}

// Preguntas asignadas a la partida (foto tomada al comenzar) con sus
// opciones. No incluye la solución.
export async function fetchPartidaQuestions(partidaId) {
  const rows = unwrap(
    await client()
      .from('partida_preguntas')
      .select(
        'desafio_pregunta_id, orden, ' +
          'desafio_preguntas(id, enunciado, codigo, dificultad, ' +
          'desafio_opciones(id, orden, texto))'
      )
      .eq('partida_id', partidaId)
      .order('orden', { ascending: true }),
    'No se pudieron cargar las preguntas de la partida.'
  )

  return rows.map(row => {
    const question = row.desafio_preguntas ?? {}
    return {
      id: question.id ?? row.desafio_pregunta_id,
      order: row.orden,
      prompt: question.enunciado ?? 'Pregunta',
      code: question.codigo ?? null,
      difficulty: question.dificultad ?? 'facil',
      options: (question.desafio_opciones ?? [])
        .slice()
        .sort((a, b) => a.orden - b.orden)
        .map(option => ({
          id: option.id,
          text: option.texto
        }))
    }
  })
}

// Respuestas ya guardadas de la partida: permite continuar donde quedó.
export async function fetchPartidaAnswers(partidaId) {
  const rows = unwrap(
    await client()
      .from('partida_respuestas')
      .select(
        'desafio_pregunta_id, desafio_opcion_id, correcto, ' +
          'puntos_obtenidos, respondido_en'
      )
      .eq('partida_id', partidaId),
    'No se pudieron leer las respuestas de la partida.'
  )
  return rows.map(row => ({
    questionId: row.desafio_pregunta_id,
    optionId: row.desafio_opcion_id,
    correct: row.correcto === true,
    points: row.puntos_obtenidos,
    answeredAt: row.respondido_en
  }))
}

// ---------- Resultado y ranking ----------

// Hora oficial del servidor (solo para mostrar el temporizador). Las
// validaciones de vigencia las hace cada función con now().
export async function fetchServerNow() {
  const rows = await rpc(
    'hora_servidor',
    {},
    'No se pudo leer la hora del servidor.'
  )
  return rows[0]?.hora ?? null
}

export async function fetchChallengeResult(partidaId) {
  const rows = await rpc(
    'resultado_partida',
    { p_partida: partidaId },
    'No se pudo cargar el detalle de la partida.'
  )
  return rows.map(row => ({
    order: row.orden,
    prompt: row.enunciado,
    code: row.codigo,
    difficulty: row.dificultad,
    chosenOptionId: row.opcion_elegida_id,
    chosenOptionText: row.opcion_elegida_texto ?? '',
    correctOptionId: row.opcion_correcta_id,
    correctOptionText: row.opcion_correcta_texto ?? '',
    correct: row.correcto === true,
    explanation: row.explicacion ?? '',
    points: row.puntos_obtenidos,
    answered: row.respondida === true,
    timeMs: row.tiempo_ms,
    revealed: row.revelado === true
  }))
}

export async function fetchRanking(challengeId, limit = 20) {
  const rows = await rpc(
    'ranking_desafio',
    { p_desafio: challengeId, p_limite: limit },
    'No se pudo cargar el ranking.'
  )
  return rows.map(row => ({
    position: Number(row.posicion),
    alias: row.alias,
    aliasSuffix: row.alias_sufijo,
    name: `${row.alias}#${row.alias_sufijo}`,
    points: row.puntos,
    correct: row.aciertos,
    total: row.total_preguntas,
    durationMs: row.duracion_ms,
    finishedAt: row.finalizado_en,
    isMe: row.es_yo === true,
    partidaId: row.partida
  }))
}
