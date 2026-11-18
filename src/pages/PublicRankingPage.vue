<template>
  <q-page class="public-ranking">
    <main class="public-ranking__shell">
      <header class="public-ranking__header">
        <MascotCorner name="hachiware-helado" />
        <div>
          <span class="public-ranking__eyebrow">Ranking en vivo · Expo</span>
          <h1>{{ event?.titulo || 'Ranking de la expo' }}</h1>
          <p>Mejores puestos · actualización automática</p>
        </div>
        <q-btn
          unelevated
          no-caps
          color="primary"
          icon="refresh"
          label="Actualizar"
          :loading="loading"
          @click="reload"
        />
      </header>
      <q-banner
        v-if="offline || realtimeUnavailable"
        class="public-ranking__offline"
        rounded
      >
        <q-icon :name="offline ? 'wifi_off' : 'sync_problem'" />
        {{
          offline
            ? 'Pantalla sin conexión. Reintentando automáticamente…'
            : 'Actualización en vivo no disponible. La pantalla seguirá consultando periódicamente.'
        }}
      </q-banner>
      <div class="public-ranking__meta"
        ><span class="live-dot"></span> En vivo <span>·</span> Última
        actualización: {{ updatedLabel }}</div
      >
      <div v-if="error" class="public-ranking__error">{{ error }}</div>
      <div v-else-if="loading && !rows.length" class="public-ranking__loading"
        ><q-spinner size="48px"
      /></div>
      <div v-if="!loading && rows.length" class="podium">
        <article
          v-for="row in rows.slice(0, 3)"
          :key="`podium-${row.position}`"
          class="podium__card"
          :class="`podium__card--${row.position}`"
        >
          <span class="podium__medal">{{
            row.position === 1 ? '🏆' : row.position === 2 ? '🥈' : '🥉'
          }}</span>
          <span class="podium__position">{{ row.position }}° puesto</span>
          <strong>{{ row.alias }}</strong
          ><b>{{ row.points }} pts</b>
          <small>{{ row.challenge }}</small>
        </article>
      </div>
      <table
        v-if="!loading && rows.length > 3"
        class="public-ranking__table public-ranking__table--rest"
      >
        <thead
          ><tr
            ><th>Puesto</th><th>Alias</th><th>Puntaje</th><th>Desafío</th></tr
          ></thead
        >
        <tbody
          ><tr
            v-for="row in rows.slice(3)"
            :key="`${row.position}-${row.alias}-${row.challenge}`"
          >
            <td class="position">{{ row.position }}</td
            ><td class="alias">{{ row.alias }}</td
            ><td class="points">{{ row.points }}</td
            ><td>{{ row.challenge }}</td>
          </tr></tbody
        >
      </table>
      <p v-if="!loading && !rows.length" class="public-ranking__empty"
        >Todavía no hay resultados finalizados.</p
      >
    </main>
  </q-page>
</template>

<script setup>
import MascotCorner from '@/components/MascotCorner.vue'
import { computed, onMounted, onUnmounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import {
  fetchPublicRanking,
  subscribeToPublicRanking
} from '@/data/publicRankingRepository'
import { getSupabaseClient } from '@/lib/supabase'

const route = useRoute()
const eventId = route.params.eventId || import.meta.env.VITE_EXPO_EVENT_ID || ''
const rows = ref([])
const event = ref(null)
const loading = ref(true)
const error = ref('')
const offline = ref(!navigator.onLine)
const realtimeUnavailable = ref(false)
const updated = ref(null)
let stop = () => {}
let interval
const updatedLabel = computed(() =>
  updated.value
    ? new Intl.DateTimeFormat('es', {
        dateStyle: 'short',
        timeStyle: 'medium'
      }).format(updated.value)
    : '—'
)
async function reload() {
  if (!eventId) {
    error.value = 'Falta configurar VITE_EXPO_EVENT_ID.'
    loading.value = false
    return
  }
  loading.value = true
  error.value = ''
  try {
    const client = getSupabaseClient()
    const [ranking, eventResult] = await Promise.all([
      fetchPublicRanking(eventId),
      client.from('eventos').select('titulo').eq('id', eventId).maybeSingle()
    ])
    if (eventResult.error) throw eventResult.error
    rows.value = ranking
    event.value = eventResult.data
    updated.value = new Date()
    offline.value = false
  } catch (e) {
    error.value = 'No se pudo cargar el ranking. Revisá la conexión.'
  } finally {
    loading.value = false
  }
}
onMounted(async () => {
  window.addEventListener('online', () => {
    offline.value = false
    reload()
  })
  window.addEventListener('offline', () => {
    offline.value = true
  })
  await reload()
  stop = subscribeToPublicRanking(eventId, reload, status => {
    realtimeUnavailable.value = status !== 'SUBSCRIBED'
    if (status === 'SUBSCRIBED') reload()
  })
  interval = window.setInterval(reload, 30000)
})
onUnmounted(() => {
  stop()
  clearInterval(interval)
})
</script>

<style scoped>
.public-ranking {
  min-height: 100vh;
  color: #f0f0f0;
  background:
    radial-gradient(circle at 8% 8%, rgba(248, 200, 72, 0.18), transparent 32%),
    linear-gradient(135deg, #1c1809 0%, #211b0b 52%, #171717 100%);
}
.public-ranking__shell {
  max-width: 1240px;
  margin: auto;
  padding: clamp(28px, 6vh, 76px) 4vw;
}
.public-ranking__header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 24px;
  margin-bottom: 20px;
  padding: clamp(22px, 4vw, 42px);
  border-radius: 30px;
  background: linear-gradient(120deg, #1a1a1a, #141414);
  border: 1px solid #3a331a;
  box-shadow: 0 18px 55px #00000080;
}
.public-ranking h1 {
  margin: 8px 0 4px;
  font-size: clamp(2.2rem, 5.5vw, 5.4rem);
  line-height: 0.98;
  letter-spacing: -0.06em;
  color: #f0f0f0;
}
.public-ranking__eyebrow {
  color: #ffd24d;
  font-size: 0.78rem;
  font-weight: 900;
  text-transform: uppercase;
  letter-spacing: 0.16em;
}
.public-ranking__header p {
  margin: 12px 0 0;
  color: #b5b5b5;
  font-size: clamp(1rem, 1.8vw, 1.35rem);
}
.public-ranking__meta {
  display: flex;
  align-items: center;
  gap: 9px;
  margin: 18px 4px;
  color: #b5b5b5;
  font-size: clamp(0.85rem, 1.4vw, 1rem);
  font-weight: 700;
}
.live-dot {
  width: 9px;
  height: 9px;
  border-radius: 50%;
  background: #f8c848;
  box-shadow: 0 0 0 5px #f8c84833;
}
.public-ranking__offline {
  background: #2b210c;
  color: #ffd88a;
  margin: 12px 0;
}
.podium {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 18px;
  align-items: stretch;
  margin: 22px 0 28px;
}
.podium__card {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 210px;
  padding: 22px 16px;
  overflow: hidden;
  text-align: center;
  border: 1px solid #6b5a1c;
  border-radius: 24px;
  background: linear-gradient(145deg, #1d1a0e, #2f2509);
  box-shadow: 0 14px 32px #a07e251c;
}
.podium__card--1 {
  min-height: 245px;
  transform: translateY(-12px);
  border-color: #c99a1e;
  background: linear-gradient(145deg, #1d1a0e, #3a2d0a);
  box-shadow: 0 20px 40px #a07e2538;
}
.podium__card--2 {
  background: linear-gradient(145deg, $dl-surface, #222222);
  border-color: #555555;
}
.podium__card--3 {
  background: linear-gradient(145deg, #221a0f, #2b2016);
  border-color: #8a5a2a;
}
.podium__medal {
  font-size: 2.4rem;
  line-height: 1;
}
.podium__position {
  margin: 10px 0 6px;
  color: #d9c07a;
  font-size: 0.78rem;
  font-weight: 900;
  text-transform: uppercase;
  letter-spacing: 0.1em;
}
.podium strong {
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: clamp(1.15rem, 2.4vw, 1.8rem);
}
.podium b {
  margin-top: 5px;
  color: #ffd24d;
  font-size: clamp(1.25rem, 2.8vw, 2rem);
}
.podium small {
  margin-top: 8px;
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  color: #b5b5b5;
}
.public-ranking__table {
  width: 100%;
  border-collapse: separate;
  border-spacing: 0 9px;
  font-size: clamp(1rem, 2.1vw, 1.55rem);
}
.public-ranking__table th {
  color: #b5b5b5;
  text-align: left;
  font-size: 0.66em;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  padding: 8px 18px;
}
.public-ranking__table td {
  background: #141414;
  padding: 16px 18px;
  border-top: 1px solid #2c2c2c;
  border-bottom: 1px solid #2c2c2c;
}
.public-ranking__table td:first-child {
  border-left: 1px solid #2c2c2c;
  border-radius: 15px 0 0 15px;
}
.public-ranking__table td:last-child {
  border-right: 1px solid #2c2c2c;
  border-radius: 0 15px 15px 0;
}
.public-ranking__table tr:hover td {
  background: #171717;
}
.public-ranking__table--rest {
  margin-top: -4px;
}
.position,
.points {
  font-weight: 900;
  color: #ffd24d;
}
.alias {
  font-weight: 850;
}
.public-ranking__empty,
.public-ranking__loading,
.public-ranking__error {
  text-align: center;
  padding: 55px;
  color: #b5b5b5;
}
@media (max-width: 680px) {
  .public-ranking__header {
    align-items: flex-start;
    flex-direction: column;
  }
  .public-ranking__header .q-btn {
    width: 100%;
  }
  .podium {
    gap: 8px;
  }
  .podium__card {
    min-height: 160px;
    padding: 12px 6px;
  }
  .podium__card--1 {
    min-height: 185px;
    transform: translateY(-7px);
  }
  .podium__medal {
    font-size: 1.8rem;
  }
  .public-ranking__table {
    font-size: 0.93rem;
  }
  .public-ranking__table th,
  .public-ranking__table td {
    padding: 11px 7px;
  }
  .public-ranking__table th:last-child,
  .public-ranking__table td:last-child {
    display: none;
  }
}
</style>
