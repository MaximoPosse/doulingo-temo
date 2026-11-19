// Minijuego "Ruta del robot": niveles, resultados propios y envío de rutas.
//
// El servidor es quien simula el recorrido y calcula los puntos (función
// enviar_ruta). Acá solo se leen los niveles (públicos) y los resultados de la
// propia persona, y se envía el programa armado.

import { getSupabaseClient } from '@/lib/supabase'

const MENSAJES = {
  PR_AUTH_REQUIRED: 'Entrá como invitado o con tu cuenta para jugar.',
  PR_MINIJUEGO_BLOQUEADO:
    'El minijuego se desbloquea cuando terminás el Gran desafío.',
  PR_NIVEL_NO_EXISTE: 'Ese nivel no existe.',
  PR_PROGRAMA_INVALIDO: 'El programa no es válido. Revisá los bloques.'
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

function mapNivel(fila) {
  return {
    id: fila.id,
    orden: fila.orden,
    nombre: fila.nombre,
    consejo: fila.consejo,
    n: fila.n,
    inicio: fila.inicio,
    rumbo: fila.rumbo,
    meta: fila.meta,
    muros: fila.muros ?? [],
    estrellas: fila.estrellas ?? [],
    par: fila.par
  }
}

export async function fetchNiveles() {
  const { data, error } = await client()
    .from('minijuego_niveles')
    .select(
      'id, orden, nombre, consejo, n, inicio, rumbo, meta, muros, estrellas, par'
    )
    .order('orden', { ascending: true })
  if (error)
    throw new Error(mensajeError(error, 'No se pudieron cargar los niveles.'))
  return (data ?? []).map(mapNivel)
}

// Mejor resultado propio de cada nivel: { [nivelId]: { puntos, bloques, estrellas } }
export async function fetchMisResultados() {
  const { data, error } = await client()
    .from('minijuego_resultados')
    .select('nivel_id, puntos, bloques, estrellas')
  if (error)
    throw new Error(mensajeError(error, 'No se pudieron leer tus resultados.'))
  return Object.fromEntries(
    (data ?? []).map(fila => [
      fila.nivel_id,
      { puntos: fila.puntos, bloques: fila.bloques, estrellas: fila.estrellas }
    ])
  )
}

export async function fetchDesbloqueado() {
  const { data, error } = await client().rpc('minijuego_desbloqueado')
  if (error)
    throw new Error(
      mensajeError(error, 'No se pudo leer el estado del minijuego.')
    )
  return data === true
}

export async function enviarRuta(nivelId, programa) {
  const { data, error } = await client().rpc('enviar_ruta', {
    p_nivel: nivelId,
    p_programa: programa
  })
  if (error) throw new Error(mensajeError(error, 'No se pudo enviar tu ruta.'))
  const fila = Array.isArray(data) ? data[0] : data
  if (!fila) throw new Error('El servidor no devolvió el resultado.')
  return {
    llego: fila.llego === true,
    choco: fila.choco === true,
    bloques: fila.bloques,
    pasos: fila.pasos,
    estrellas: fila.estrellas,
    puntos: fila.puntos,
    mejorPuntos: fila.mejor_puntos,
    mejoro: fila.mejoro === true,
    total: fila.total_minijuego
  }
}
