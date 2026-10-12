// Carga remota con estados de UI: loading / error (con reintento) / datos.
//
// Uso:
//   const { data, loading, error, load } = useRemoteData(async () => ({ ... }))
//
// `load` se ejecuta al crearse y queda expuesto para reintentar tras un error.

import { ref } from 'vue'

export function useRemoteData(fetcher) {
  const data = ref(null)
  const loading = ref(true)
  const error = ref(null)

  async function load() {
    loading.value = true
    error.value = null
    try {
      data.value = await fetcher()
    } catch (err) {
      data.value = null
      error.value = err?.message ?? 'Ocurrió un error inesperado.'
    } finally {
      loading.value = false
    }
  }

  load()

  return { data, loading, error, load }
}
