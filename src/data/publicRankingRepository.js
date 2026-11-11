import { getSupabaseClient } from '@/lib/supabase'

export async function fetchPublicRanking(eventId, limit = 100) {
  const { data, error } = await getSupabaseClient().rpc('ranking_evento', {
    p_evento: eventId,
    p_limite: limit
  })
  if (error) throw error
  return (data ?? []).map(row => ({
    position: Number(row.posicion),
    alias: row.alias,
    points: row.puntaje,
    challenge: row.desafio
  }))
}

export function subscribeToPublicRanking(eventId, onChange, onStatus) {
  const channel = getSupabaseClient()
    .channel(`ranking-publico-${eventId}`)
    .on('postgres_changes', {
      // La tabla ya es una proyección pública mínima. La consulta RPC vuelve
      // a filtrar por evento; así evitamos incompatibilidades del filtro UUID
      // entre versiones/configuraciones de Realtime.
      event: '*', schema: 'public', table: 'resultados_publicos'
    }, onChange)
    .subscribe(onStatus)
  return () => getSupabaseClient().removeChannel(channel)
}
