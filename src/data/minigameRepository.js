// Minijuego "Cazabugs": estado de desbloqueo, mejor resultado propio y rondas.
//
// El servidor entrega la semilla de cada ronda y, al terminar, repite la
// partida con los toques para calcular el puntaje oficial (cazabugs_enviar).
// Acá solo se piden esos datos; nunca se manda un puntaje.

import { getSupabaseClient } from '@/lib/supabase'

const MENSAJES = {
  PR_AUTH_REQUIRED: 'Entrá como invitado o con tu cuenta para jugar.',
  PR_MINIJUEGO_BLOQUEADO:
    'El minijuego se desbloquea cuando terminás el Gran desafío.',
  PR_RONDA_NO_EXISTE: 'Esa ronda no existe.',
  PR_RONDA_CERRADA: 'Esa ronda ya se envió.',
  PR_RONDA_YA_JUGADA: 'Ya usaste tu única ronda con puntos. ¡Podés practicar!',
  PR_RONDA_FUERA_DE_TIEMPO:
    'La ronda se envió fuera de tiempo. Se perdió esa ronda.',
  PR_TOQUES_INVALIDOS: 'No se pudo validar la ronda.'
}

function mensajeError(err, fallback) {
  const raw = `${err?.message ?? ''} ${err?.details ?? ''} ${err?.hint ?? ''}`
  for (const [codigo, mensaje] of Object.entries(MENSAJES)) {
    if (raw.includes(codigo)) return mensaje
  }
  if (/fetch|network|failed to|load failed/i.test(raw)) {
    return 'No se pudo contactar al servidor. Revisá tu conexión.'
  }
  return fallback
}

function client() {
  return getSupabaseClient()
}

export async function fetchDesbloqueado() {
  const { data, error } = await client().rpc('minijuego_desbloqueado')
  if (error)
    throw new Error(
      mensajeError(error, 'No se pudo leer el estado del minijuego.')
    )
  return data === true
}

// Mejor resultado propio: { puntaje, puntos, aciertos, mejorRacha, rondas }
export async function fetchMiMejor() {
  const { data, error } = await client()
    .from('cazabugs_mejores')
    .select('puntaje, puntos, aciertos, mejor_racha, rondas')
    .maybeSingle()
  if (error)
    throw new Error(mensajeError(error, 'No se pudo leer tu mejor resultado.'))
  if (!data) return null
  return {
    puntaje: data.puntaje,
    puntos: data.puntos,
    aciertos: data.aciertos,
    mejorRacha: data.mejor_racha,
    rondas: data.rondas
  }
}

export async function iniciarRonda() {
  const { data, error } = await client().rpc('cazabugs_iniciar')
  if (error)
    throw new Error(mensajeError(error, 'No se pudo empezar la ronda.'))
  const fila = Array.isArray(data) ? data[0] : data
  if (!fila) throw new Error('El servidor no devolvió la ronda.')
  return {
    id: fila.ronda,
    semilla: fila.semilla,
    duracionMs: fila.duracion_ms
  }
}

export async function enviarRonda(rondaId, toques) {
  const { data, error } = await client().rpc('cazabugs_enviar', {
    p_ronda: rondaId,
    p_toques: toques
  })
  if (error) throw new Error(mensajeError(error, 'No se pudo enviar la ronda.'))
  const fila = Array.isArray(data) ? data[0] : data
  if (!fila) throw new Error('El servidor no devolvió el resultado.')
  return {
    puntaje: fila.puntaje,
    puntos: fila.puntos,
    aciertos: fila.aciertos,
    fallos: fila.fallos,
    amigos: fila.amigos,
    escapados: fila.escapados ?? 0,
    mejorRacha: fila.mejor_racha,
    mejorPuntaje: fila.mejor_puntaje,
    mejorPuntos: fila.mejor_puntos,
    mejoro: fila.mejoro === true
  }
}
