<template>
  <q-page class="dl-page dl-expo">
    <div class="dl-page__inner">
      <router-link :to="{ name: 'inicio' }" class="dl-back">
        <q-icon name="arrow_back" size="18px" />
        Volver al inicio
      </router-link>

      <div v-if="loading" class="dl-states">
        <q-spinner color="primary" size="34px" class="q-mb-sm" />
        <p class="dl-states__text">Cargando la expo…</p>
      </div>

      <div v-else-if="error" class="dl-states">
        <q-icon name="wifi_off" size="44px" color="negative" />
        <h2 class="dl-states__title">No se pudo cargar la expo</h2>
        <p class="dl-states__text">{{ error }}</p>
        <q-btn
          no-caps
          unelevated
          color="primary"
          class="q-mt-sm"
          label="Reintentar"
          @click="load"
        />
      </div>

      <template v-else-if="!event">
        <div class="dl-states">
          <img :src="usagiImg" alt="Usagi" class="dl-expo__mascot" />
          <h1 class="dl-states__title">La expo todavía no está abierta</h1>
          <p class="dl-states__text">
            Cuando se publique el evento vas a poder elegir un desafío y
            competir por el mejor puntaje.
          </p>
          <q-btn
            no-caps
            unelevated
            color="primary"
            class="q-mt-sm"
            label="Ir a los cursos"
            :to="{ name: 'cursos' }"
          />
        </div>
      </template>

      <template v-else>
        <header class="dl-expo__hero">
          <div class="dl-expo__hero-main">
            <span class="dl-expo__eyebrow">Competencia de la expo</span>
            <h1 class="dl-page__title">{{ event.titulo }}</h1>
            <p class="dl-page__lead">{{ event.descripcion }}</p>
            <div class="dl-expo__dates">
              <q-icon name="event" size="18px" />
              {{ formatRange(event.iniciaEn, event.terminaEn) }}
              <span
                class="dl-badge"
                :class="
                  isOpen ? 'dl-badge--available' : 'dl-badge--locked'
                "
              >
                <q-icon :name="isOpen ? 'play_circle' : 'lock_clock'" />
                {{ isOpen ? 'Abierta' : 'Cerrada' }}
              </span>
            </div>
          </div>
          <img :src="usagiImg" alt="Usagi" class="dl-expo__hero-mascot" />
        </header>

        <section class="dl-card q-mt-md dl-expo__explain">
          <h2 class="dl-card__title">Práctica y competencia son distintas</h2>
          <div class="dl-expo__split">
            <div class="dl-expo__split-item">
              <q-icon name="menu_book" size="24px" color="primary" />
              <div>
                <strong>Práctica</strong>
                <p>
                  Las lecciones de los cursos corrigen al instante y muestran la
                  explicación. Sirven para aprender, sin reloj.
                </p>
              </div>
            </div>
            <div class="dl-expo__split-item">
              <q-icon name="emoji_events" size="24px" color="orange" />
              <div>
                <strong>Competencia</strong>
                <p>
                  Los desafíos usan un banco aparte y suman puntos contra el
                  reloj. La solución se muestra recién cuando el desafío cierra.
                </p>
              </div>
            </div>
          </div>
        </section>

        <h2 class="dl-section-title q-mt-lg">Desafíos</h2>
        <p class="dl-expo__lead-small">
          Podés jugar como invitado o con tu cuenta. El ranking toma tu
          <strong>mejor intento válido</strong>: repetir no suma puntos.
        </p>

        <div v-if="challenges.length" class="dl-expo__grid">
          <article
            v-for="challenge in challenges"
            :key="challenge.id"
            class="dl-expo__card"
          >
            <div class="dl-expo__card-top">
              <span
                class="dl-badge"
                :class="difficultyClass(challenge.dificultad)"
              >
                {{ difficultyLabel(challenge.dificultad) }}
              </span>
              <span class="dl-expo__card-time">
                <q-icon name="timer" size="16px" />
                {{ formatDuration(challenge.duracionSegundos) }}
              </span>
            </div>

            <h3 class="dl-expo__card-title">{{ challenge.titulo }}</h3>
            <p class="dl-expo__card-text">{{ challenge.descripcion }}</p>

            <dl class="dl-expo__facts">
              <div>
                <dt>Preguntas</dt>
                <dd>{{ challenge.totalPreguntas }}</dd>
              </div>
              <div>
                <dt>Puntos por acierto</dt>
                <dd>{{ challenge.puntosPorAcierto }}</dd>
              </div>
              <div>
                <dt>Intentos</dt>
                <dd>{{ challenge.intentosPermitidos }}</dd>
              </div>
            </dl>

            <q-btn
              no-caps
              unelevated
              color="primary"
              class="dl-btn-main full-width"
              :label="isOpen ? 'VER DESAFÍO' : 'VER RANKING'"
              :to="{ name: 'desafio', params: { challengeId: challenge.id } }"
            />
          </article>
        </div>

        <div v-else class="dl-states">
          <q-icon name="construction" size="44px" color="grey-6" />
          <h2 class="dl-states__title">Todavía no hay desafíos publicados</h2>
          <p class="dl-states__text">
            El evento existe, pero sus desafíos aún no están disponibles.
          </p>
        </div>

        <section class="dl-card q-mt-lg">
          <h2 class="dl-card__title">Cómo se decide el ranking</h2>
          <ul class="dl-expo__rules">
            <li>
              <q-icon name="workspace_premium" size="18px" color="positive" />
              Cuenta el <strong>mejor intento válido</strong> de cada
              participante en cada desafío.
            </li>
            <li>
              <q-icon name="timer" size="18px" color="primary" />
              Desempate: más puntos, luego menor tiempo medido por el servidor y
              por último la finalización más temprana.
            </li>
            <li>
              <q-icon name="block" size="18px" color="orange" />
              Una partida incompleta o vencida queda en tu historial, pero no
              compite. No se pueden borrar partidas para recuperar intentos.
            </li>
            <li>
              <q-icon name="lock" size="18px" color="grey-7" />
              Los puntos y los tiempos oficiales los calcula el servidor. El
              celular no puede modificarlos.
            </li>
          </ul>
        </section>
      </template>
    </div>
  </q-page>
</template>

<script setup>
import { computed } from 'vue'

import usagiImg from '@/assets/usagi.webp'
import { fetchExpo } from '@/data/challengeRepository'
import { useRemoteData } from '@/composables/useRemoteData'

const { data, loading, error, load } = useRemoteData(fetchExpo)

const event = computed(() => data.value?.event ?? null)
const challenges = computed(() => data.value?.challenges ?? [])

const isOpen = computed(() => {
  if (!event.value || event.value.estado !== 'publicado') return false
  const now = Date.now()
  return (
    now >= new Date(event.value.iniciaEn).getTime() &&
    now <= new Date(event.value.terminaEn).getTime()
  )
})

function formatRange(start, end) {
  try {
    const formatter = new Intl.DateTimeFormat('es', {
      day: '2-digit',
      month: 'short',
      year: 'numeric'
    })
    return `${formatter.format(new Date(start))} — ${formatter.format(
      new Date(end)
    )}`
  } catch {
    return ''
  }
}

function formatDuration(seconds) {
  if (seconds < 60) return `${seconds} s`
  const minutes = Math.floor(seconds / 60)
  const rest = seconds % 60
  return rest ? `${minutes} min ${rest} s` : `${minutes} min`
}

function difficultyLabel(difficulty) {
  return (
    {
      facil: 'Fácil',
      intermedio: 'Intermedio',
      dificil: 'Difícil'
    }[difficulty] ?? difficulty
  )
}

function difficultyClass(difficulty) {
  return {
    facil: 'dl-badge--available',
    intermedio: 'dl-badge--info',
    dificil: 'dl-badge--locked'
  }[difficulty]
}

</script>

<style lang="scss" scoped>
.dl-expo {
  &__hero {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 24px;
    background: linear-gradient(135deg, #f6fbf4 0%, #fff8e6 100%);
    border: 2px solid #dcefd2;
    border-radius: 22px;
    padding: 28px 26px;
  }

  &__hero-main {
    flex: 1 1 auto;
  }

  &__hero-mascot {
    flex: 0 0 auto;
    width: 150px;
    height: 150px;
    object-fit: contain;
  }

  &__mascot {
    width: 140px;
    height: 140px;
    object-fit: contain;
  }

  &__eyebrow {
    display: inline-block;
    font-size: 12px;
    font-weight: 800;
    letter-spacing: 0.8px;
    text-transform: uppercase;
    color: $dl-green-dark;
    margin-bottom: 6px;
  }

  &__dates {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-wrap: wrap;
    font-size: 13px;
    font-weight: 700;
    color: #6b6b6b;
    margin-top: 12px;
  }

  &__split {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 16px;
  }

  &__split-item {
    display: flex;
    gap: 12px;
    align-items: flex-start;
    background: #f8faf7;
    border: 1px solid #e5e5e5;
    border-radius: 14px;
    padding: 14px 16px;

    strong {
      display: block;
      font-size: 15px;
      color: $dl-ink-dark;
      margin-bottom: 4px;
    }

    p {
      margin: 0;
      font-size: 13px;
      line-height: 1.55;
      color: #6b6b6b;
    }
  }

  &__lead-small {
    font-size: 14px;
    line-height: 1.6;
    color: #6b6b6b;
    margin: 0 0 18px;
  }

  &__grid {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 18px;
  }

  &__card {
    display: flex;
    flex-direction: column;
    background: #ffffff;
    border: 2px solid $dl-gray;
    border-radius: 18px;
    padding: 18px;
  }

  &__card-top {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
    margin-bottom: 12px;
  }

  &__card-time {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    font-size: 12px;
    font-weight: 800;
    color: #8a8a8a;
  }

  &__card-title {
    font-size: 19px;
    font-weight: 800;
    color: $dl-ink-dark;
    margin: 0 0 6px;
  }

  &__card-text {
    font-size: 13px;
    line-height: 1.55;
    color: #6b6b6b;
    margin: 0 0 14px;
    flex: 1 1 auto;
  }

  &__facts {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 6px;
    margin: 0 0 16px;

    dt {
      font-size: 10px;
      font-weight: 800;
      text-transform: uppercase;
      letter-spacing: 0.3px;
      color: #8a8a8a;
    }

    dd {
      margin: 2px 0 0;
      font-size: 16px;
      font-weight: 800;
      color: $dl-ink-dark;
    }
  }

  &__rules {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 10px;

    li {
      display: flex;
      gap: 10px;
      align-items: flex-start;
      font-size: 14px;
      line-height: 1.55;
      color: $dl-ink;
    }
  }
}

@media (max-width: 900px) {
  .dl-expo__grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 620px) {
  .dl-expo__grid,
  .dl-expo__split {
    grid-template-columns: 1fr;
  }

  .dl-expo__hero {
    flex-direction: column;
    text-align: center;
  }

  .dl-expo__dates {
    justify-content: center;
  }
}
</style>
