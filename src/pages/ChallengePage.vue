<template>
  <q-page class="dl-challenge">
    <div class="dl-challenge__inner">
      <router-link :to="{ name: 'expo' }" class="dl-challenge__back">
        <q-icon name="arrow_back" size="18px" />
        Volver a la expo
      </router-link>

      <div v-if="loading" class="dl-challenge__state">
        <q-spinner color="primary" size="34px" class="q-mb-sm" />
        <p class="dl-challenge__state-text">Cargando el desafío…</p>
      </div>

      <div v-else-if="error || !challenge" class="dl-challenge__state">
        <q-icon name="wifi_off" size="44px" color="negative" />
        <h2 class="dl-challenge__state-title">
          No se pudo cargar el desafío
        </h2>
        <p class="dl-challenge__state-text">
          {{ error || 'El desafío no existe o no está disponible.' }}
        </p>
        <div class="dl-challenge__state-actions">
          <q-btn
            no-caps
            unelevated
            color="primary"
            label="Reintentar"
            @click="loadChallenge"
          />
          <q-btn
            no-caps
            outline
            class="dl-btn-ghost"
            label="Volver a la expo"
            :to="{ name: 'expo' }"
          />
        </div>
      </div>

      <template v-else>
        <header class="dl-challenge__header">
          <div>
            <div class="dl-challenge__eyebrow">
              {{ challenge.event?.titulo || 'Expo' }}
            </div>
            <h1 class="dl-challenge__title">{{ challenge.titulo }}</h1>
            <p class="dl-challenge__description">
              {{ challenge.descripcion }}
            </p>
          </div>
          <div class="dl-challenge__header-badges">
            <span
              class="dl-badge"
              :class="difficultyClass(challenge.dificultad)"
            >
              {{ difficultyLabel(challenge.dificultad) }}
            </span>
            <span
              class="dl-badge"
              :class="isOpen ? 'dl-badge--available' : 'dl-badge--locked'"
            >
              <q-icon :name="isOpen ? 'play_circle' : 'lock_clock'" />
              {{ isOpen ? 'Abierto' : 'Cerrado' }}
            </span>
          </div>
        </header>

        <!-- ============================ INTRO ============================ -->
        <template v-if="phase === 'intro'">
          <section class="dl-challenge__rules-card">
            <h2 class="dl-challenge__section-title">Reglas del desafío</h2>
            <div class="dl-challenge__rules-grid">
              <div class="dl-challenge__rule">
                <span class="dl-challenge__rule-value">{{
                  challenge.totalPreguntas
                }}</span>
                <span class="dl-challenge__rule-label">Preguntas</span>
              </div>
              <div class="dl-challenge__rule">
                <span class="dl-challenge__rule-value">{{
                  formatDuration(challenge.duracionSegundos)
                }}</span>
                <span class="dl-challenge__rule-label">Duración</span>
              </div>
              <div class="dl-challenge__rule">
                <span class="dl-challenge__rule-value">{{
                  challenge.puntosPorAcierto
                }}</span>
                <span class="dl-challenge__rule-label">Puntos por acierto</span>
              </div>
              <div class="dl-challenge__rule">
                <span class="dl-challenge__rule-value">{{
                  maxPoints
                }}</span>
                <span class="dl-challenge__rule-label">Puntaje máximo</span>
              </div>
              <div class="dl-challenge__rule">
                <span class="dl-challenge__rule-value">{{
                  challenge.intentosPermitidos
                }}</span>
                <span class="dl-challenge__rule-label">Intentos</span>
              </div>
              <div class="dl-challenge__rule">
                <span class="dl-challenge__rule-value">{{
                  formatDuration(challenge.toleranciaSegundos)
                }}</span>
                <span class="dl-challenge__rule-label">Plazo de cierre</span>
              </div>
            </div>
            <p class="dl-challenge__rule-note">
              El tiempo empieza y termina en el servidor. El plazo de cierre es
              la tolerancia para finalizar y guardar lo respondido cuando se
              corta la conexión.
            </p>
          </section>

          <section class="dl-challenge__status-card">
            <div class="dl-challenge__status-main">
              <h2 class="dl-challenge__section-title">Tu situación</h2>
              <p v-if="isGuest" class="dl-challenge__status-text">
                Estás jugando como <strong>invitado</strong>. Tu puntaje queda
                guardado en este dispositivo y en la base; podés convertirlo en
                cuenta permanente desde tu perfil.
              </p>
              <p v-else-if="session" class="dl-challenge__status-text">
                Estás jugando como <strong>{{ publicName }}</strong>.
              </p>
              <p v-else class="dl-challenge__status-text">
                Podés jugar sin cuenta: al empezar se crea un invitado para
                guardar tu partida.
              </p>

              <div class="dl-challenge__status-facts">
                <span>
                  <strong>{{ attemptsUsed }}</strong> de
                  {{ challenge.intentosPermitidos }} intentos usados
                </span>
                <span v-if="bestPartida">
                  Mejor intento:
                  <strong>{{ bestPartida.puntos }} pts</strong>
                  ({{ bestPartida.aciertos }}/{{ bestPartida.totalPreguntas }})
                </span>
                <span v-else>Sin intentos válidos todavía</span>
              </div>
            </div>

            <div
              v-if="openPartida"
              class="dl-challenge__open"
              :class="{ 'dl-challenge__open--expired': openPartidaExpired }"
            >
              <q-icon
                :name="openPartidaExpired ? 'timer_off' : 'pending_actions'"
                size="22px"
              />
              <div>
                <strong>
                  {{
                    openPartidaExpired
                      ? 'Tenés una partida sin terminar (tiempo agotado)'
                      : 'Tenés una partida sin terminar'
                  }}
                </strong>
                <p>
                  {{ answeredFromPartida(openPartida) }} de
                  {{ openPartida.totalPreguntas }} preguntas respondidas.
                  {{
                    openPartidaExpired
                      ? 'Finalizala para guardar lo que alcanzaste a responder.'
                      : 'Podés continuar donde quedaste.'
                  }}
                </p>
              </div>
            </div>

            <div v-if="personalError" class="dl-challenge__inline-error">
              <q-icon name="error_outline" size="20px" />
              {{ personalError }}
            </div>

            <div class="dl-challenge__start">
              <q-btn
                no-caps
                unelevated
                size="lg"
                class="dl-btn-main dl-btn-main--big"
                :label="startLabel"
                :loading="starting"
                :disable="startDisabled"
                @click="begin(false)"
              />
              <q-btn
                v-if="openPartida && attemptsLeft > 0"
                no-caps
                outline
                size="lg"
                class="dl-btn-ghost"
                :label="`Empezar otra partida (${attemptsLeft} intento${
                  attemptsLeft === 1 ? '' : 's'
                })`"
                :loading="starting"
                @click="begin(true)"
              />
            </div>

            <p v-if="!openPartida && !isOpen" class="dl-challenge__status-text">
              El evento o el desafío ya cerraron: se puede ver el ranking, pero
              no empezar una partida nueva.
            </p>
            <p
              v-else-if="!openPartida && attemptsLeft <= 0"
              class="dl-challenge__status-text"
            >
              Ya usaste todos los intentos de este desafío. El ranking toma tu
              mejor intento válido.
            </p>

            <div v-if="startError" class="dl-challenge__inline-error">
              <q-icon name="error_outline" size="20px" />
              <div>
                <strong>No se pudo empezar</strong>
                <p>{{ startError }}</p>
              </div>
            </div>
          </section>

          <section class="dl-challenge__ranking-card">
            <div class="dl-challenge__ranking-head">
              <h2 class="dl-challenge__section-title">Ranking</h2>
              <q-btn
                no-caps
                flat
                dense
                color="primary"
                label="Actualizar"
                :loading="rankingLoading"
                @click="loadRanking"
              />
            </div>
            <p class="dl-challenge__ranking-note">
              Mejor intento válido por participante. Desempate: puntos, tiempo
              del servidor y finalización más temprana.
            </p>
            <div v-if="rankingError" class="dl-challenge__inline-error">
              <q-icon name="error_outline" size="20px" />
              {{ rankingError }}
            </div>
            <table v-else-if="ranking.length" class="dl-ranking">
              <thead>
                <tr>
                  <th>#</th>
                  <th>Participante</th>
                  <th>Puntos</th>
                  <th>Aciertos</th>
                  <th>Tiempo</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="row in ranking.slice(0, 5)"
                  :key="row.partidaId"
                  :class="{ 'dl-ranking__me': row.isMe }"
                >
                  <td>{{ row.position }}</td>
                  <td>
                    {{ row.name }}
                    <span v-if="row.isMe" class="dl-ranking__tag">vos</span>
                  </td>
                  <td><strong>{{ row.points }}</strong></td>
                  <td>{{ row.correct }}/{{ row.total }}</td>
                  <td>{{ formatMs(row.durationMs) }}</td>
                </tr>
              </tbody>
            </table>
            <p v-else class="dl-challenge__empty">
              Todavía no hay partidas válidas en este desafío.
            </p>
          </section>
        </template>

        <!-- =========================== JUGANDO =========================== -->
        <template v-else-if="phase === 'playing'">
          <div class="dl-challenge__playbar">
            <div class="dl-challenge__timer" :class="{ 'is-expired': timeExpired }">
              <q-icon name="timer" size="20px" />
              <span>{{ timerLabel }}</span>
            </div>
            <div class="dl-challenge__playpoints">
              <span class="dl-challenge__playpoints-value">{{
                partida?.puntos ?? 0
              }}</span>
              <span class="dl-challenge__playpoints-label">puntos</span>
            </div>
            <q-btn
              no-caps
              flat
              dense
              color="primary"
              label="FINALIZAR"
              :disable="finishing"
              @click="confirmFinish = true"
            />
          </div>

          <div class="dl-challenge__track">
            <div
              class="dl-challenge__track-fill"
              :style="{ width: `${progressPct}%` }"
            />
          </div>
          <div class="dl-challenge__playmeta">
            <span>
              Pregunta {{ Math.min(currentIndex + 1, questions.length) }} de
              {{ questions.length }}
            </span>
            <span>{{ answeredCount }} respondidas</span>
          </div>

          <div v-if="timeExpired" class="dl-challenge__timeout">
            <q-icon name="timer_off" size="24px" />
            <div>
              <strong>Se terminó el tiempo</strong>
              <p>
                Ya no se aceptan respuestas nuevas. Finalizá la partida para
                guardar lo que respondiste.
              </p>
            </div>
          </div>

          <div v-if="confirmFinish" class="dl-challenge__confirm">
            <q-icon name="flag" size="24px" />
            <div>
              <strong>¿Finalizar la partida ahora?</strong>
              <p>
                Las preguntas sin responder no suman. Después no se puede
                continuar esta partida.
              </p>
              <div class="dl-challenge__confirm-actions">
                <q-btn
                  no-caps
                  unelevated
                  color="primary"
                  label="SÍ, FINALIZAR"
                  :loading="finishing"
                  @click="finishNow"
                />
                <q-btn
                  no-caps
                  flat
                  label="SEGUIR JUGANDO"
                  @click="confirmFinish = false"
                />
              </div>
            </div>
          </div>

          <template v-if="currentQuestion">
            <div class="dl-challenge__question">
              <div class="dl-challenge__question-icon">
                <q-icon name="help" size="22px" />
              </div>
              <div class="dl-challenge__question-bubble">
                <h2 class="dl-challenge__question-text">
                  {{ currentQuestion.prompt }}
                </h2>
              </div>
            </div>

            <pre
              v-if="currentQuestion.code"
              class="dl-challenge__code"
            ><code>{{ currentQuestion.code }}</code></pre>

            <div class="dl-challenge__options">
              <button
                v-for="option in currentQuestion.options"
                :key="option.id"
                type="button"
                class="dl-challenge__option"
                :class="optionClass(option.id)"
                :disabled="checked || submitting || timeExpired"
                @click="selectOption(option.id)"
              >
                <span class="dl-challenge__option-letter">{{
                  optionLetter(option.id)
                }}</span>
                <span class="dl-challenge__option-text">{{ option.text }}</span>
              </button>
            </div>

            <div v-if="answerError" class="dl-challenge__inline-error">
              <q-icon name="error_outline" size="20px" />
              <div>
                <strong>No se pudo registrar tu respuesta</strong>
                <p>{{ answerError }}</p>
              </div>
            </div>

            <div
              v-if="checked && answerResult"
              class="dl-challenge__feedback"
              :class="
                answerResult.correcto
                  ? 'dl-challenge__feedback--ok'
                  : 'dl-challenge__feedback--bad'
              "
            >
              <q-icon
                :name="answerResult.correcto ? 'check_circle' : 'error'"
                size="26px"
              />
              <div>
                <strong>
                  {{
                    answerResult.correcto
                      ? '¡Correcto!'
                      : 'Respuesta incorrecta'
                  }}
                </strong>
                <p v-if="answerResult.correcto">
                  Sumaste {{ answerResult.puntosObtenidos }} puntos.
                </p>
                <p v-else>
                  No suma puntos. La opción correcta y la explicación se
                  muestran cuando el desafío cierre.
                </p>
              </div>
            </div>

            <div class="dl-challenge__actions">
              <q-btn
                v-if="!checked"
                no-caps
                unelevated
                size="lg"
                class="dl-btn-main dl-btn-main--big"
                :label="submitting ? 'GUARDANDO…' : 'CONFIRMAR'"
                :disable="selectedOptionId === null || submitting || timeExpired"
                @click="confirmAnswer"
              />
              <q-btn
                v-else
                no-caps
                unelevated
                size="lg"
                class="dl-btn-main dl-btn-main--big"
                :label="
                  currentIndex < questions.length - 1
                    ? 'CONTINUAR'
                    : 'FINALIZAR PARTIDA'
                "
                :disable="finishing"
                @click="nextQuestion"
              />
            </div>
          </template>

          <div v-else class="dl-challenge__state">
            <q-icon name="task_alt" size="48px" color="positive" />
            <h2 class="dl-challenge__state-title">Respondiste todo</h2>
            <p class="dl-challenge__state-text">
              Finalizá la partida para que el servidor calcule el resultado.
            </p>
            <q-btn
              no-caps
              unelevated
              size="lg"
              class="dl-btn-main dl-btn-main--big"
              label="FINALIZAR PARTIDA"
              :loading="finishing"
              @click="finishNow"
            />
          </div>
        </template>

        <!-- =========================== RESULTADO ========================= -->
        <template v-else>
          <section class="dl-challenge__result">
            <div
              class="dl-challenge__result-banner"
              :class="resultBannerClass"
            >
              <span class="dl-badge" :class="resultStateClass">
                <q-icon :name="resultStateIcon" />
                {{ resultStateLabel }}
              </span>

              <div v-if="saveState === 'saving'" class="dl-challenge__save">
                <q-spinner size="18px" />
                Guardando el resultado en el servidor…
              </div>
              <div
                v-else-if="saveState === 'failed'"
                class="dl-challenge__save dl-challenge__save--failed"
              >
                <q-icon name="cloud_off" size="20px" />
                <span>
                  No se pudo finalizar la partida. {{ finishError }}
                </span>
              </div>
              <div v-else class="dl-challenge__save dl-challenge__save--saved">
                <q-icon name="cloud_done" size="20px" />
                Resultado guardado en el servidor.
              </div>

              <div v-if="result" class="dl-challenge__score">
                <span class="dl-challenge__score-value">{{ result.puntos }}</span>
                <span class="dl-challenge__score-label">puntos</span>
              </div>
              <p v-if="result" class="dl-challenge__result-message">
                {{ resultMessage }}
              </p>

              <div v-if="result" class="dl-challenge__result-stats">
                <div class="dl-challenge__result-stat">
                  <span class="dl-challenge__result-stat-value">{{
                    result.aciertos
                  }}</span>
                  <span class="dl-challenge__result-stat-label">Aciertos</span>
                </div>
                <div class="dl-challenge__result-stat">
                  <span class="dl-challenge__result-stat-value">{{
                    result.respondidas
                  }}</span>
                  <span class="dl-challenge__result-stat-label"
                    >Respondidas</span
                  >
                </div>
                <div class="dl-challenge__result-stat">
                  <span class="dl-challenge__result-stat-value">{{
                    result.totalPreguntas
                  }}</span>
                  <span class="dl-challenge__result-stat-label">Preguntas</span>
                </div>
                <div class="dl-challenge__result-stat">
                  <span class="dl-challenge__result-stat-value">{{
                    formatMs(result.duracionMs)
                  }}</span>
                  <span class="dl-challenge__result-stat-label">Tiempo</span>
                </div>
              </div>

              <div class="dl-challenge__result-actions">
                <template v-if="saveState === 'failed'">
                  <q-btn
                    no-caps
                    unelevated
                    size="lg"
                    class="dl-btn-main dl-btn-main--big"
                    label="REINTENTAR GUARDADO"
                    :loading="finishing"
                    @click="finishNow"
                  />
                  <q-btn
                    no-caps
                    outline
                    size="lg"
                    class="dl-btn-ghost"
                    label="Volver a la expo"
                    :to="{ name: 'expo' }"
                  />
                </template>
                <template v-else-if="saveState === 'saved'">
                  <q-btn
                    v-if="canPlayAgain"
                    no-caps
                    unelevated
                    size="lg"
                    class="dl-btn-main dl-btn-main--big"
                    label="JUGAR DE NUEVO"
                    @click="restart"
                  />
                  <q-btn
                    no-caps
                    outline
                    size="lg"
                    class="dl-btn-ghost"
                    label="Volver a la expo"
                    :to="{ name: 'expo' }"
                  />
                </template>
              </div>

              <p
                v-if="saveState === 'saved' && !canPlayAgain"
                class="dl-challenge__result-note"
              >
                No te quedan intentos en este desafío. El ranking conserva tu
                mejor intento válido.
              </p>
            </div>
          </section>

          <section class="dl-challenge__detail-card">
            <div class="dl-challenge__detail-head">
              <h2 class="dl-challenge__section-title">Tus respuestas</h2>
              <span v-if="resultDetail.length" class="dl-challenge__detail-hint">
                {{
                  resultRevealed
                    ? 'El desafío cerró: se muestran las soluciones.'
                    : 'Las soluciones se muestran cuando el desafío cierre.'
                }}
              </span>
            </div>

            <div v-if="detailError" class="dl-challenge__inline-error">
              <q-icon name="error_outline" size="20px" />
              {{ detailError }}
            </div>
            <div v-else-if="detailLoading" class="dl-challenge__state">
              <q-spinner size="22px" />
              <p class="dl-challenge__state-text">Cargando el detalle…</p>
            </div>
            <ul v-else-if="resultDetail.length" class="dl-challenge__answers">
              <li
                v-for="answer in resultDetail"
                :key="answer.order"
                class="dl-challenge__answer"
              >
                <q-icon
                  :name="
                    !answer.answered
                      ? 'remove_circle_outline'
                      : answer.correct
                        ? 'check_circle'
                        : 'cancel'
                  "
                  size="20px"
                  :color="
                    !answer.answered
                      ? 'grey-6'
                      : answer.correct
                        ? 'positive'
                        : 'negative'
                  "
                />
                <div class="dl-challenge__answer-body">
                  <span class="dl-challenge__answer-question">
                    {{ answer.order }}. {{ answer.prompt }}
                  </span>
                  <span v-if="answer.answered" class="dl-challenge__answer-line">
                    Elegiste:
                    <strong>{{ answer.chosenOptionText }}</strong>
                    <template v-if="answer.correct">
                      · +{{ answer.points }} puntos
                    </template>
                  </span>
                  <span v-else class="dl-challenge__answer-line">
                    Sin responder.
                  </span>
                  <span
                    v-if="answer.revealed && !answer.correct"
                    class="dl-challenge__answer-line"
                  >
                    Correcta: <strong>{{ answer.correctOptionText }}</strong>
                  </span>
                  <span
                    v-if="answer.revealed && answer.explanation"
                    class="dl-challenge__answer-explain"
                  >
                    {{ answer.explanation }}
                  </span>
                </div>
              </li>
            </ul>
            <p v-else class="dl-challenge__empty">
              No hay respuestas guardadas en esta partida.
            </p>
          </section>

          <section class="dl-challenge__ranking-card">
            <div class="dl-challenge__ranking-head">
              <h2 class="dl-challenge__section-title">Ranking</h2>
              <q-btn
                no-caps
                flat
                dense
                color="primary"
                label="Actualizar"
                :loading="rankingLoading"
                @click="loadRanking"
              />
            </div>
            <p class="dl-challenge__ranking-note">
              Solo compiten las partidas finalizadas con todas las respuestas
              dentro del plazo. Se toma el mejor intento de cada participante.
            </p>
            <div v-if="rankingError" class="dl-challenge__inline-error">
              <q-icon name="error_outline" size="20px" />
              {{ rankingError }}
            </div>
            <table v-else-if="ranking.length" class="dl-ranking">
              <thead>
                <tr>
                  <th>#</th>
                  <th>Participante</th>
                  <th>Puntos</th>
                  <th>Aciertos</th>
                  <th>Tiempo</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="row in ranking"
                  :key="row.partidaId"
                  :class="{ 'dl-ranking__me': row.isMe }"
                >
                  <td>{{ row.position }}</td>
                  <td>
                    {{ row.name }}
                    <span v-if="row.isMe" class="dl-ranking__tag">vos</span>
                  </td>
                  <td><strong>{{ row.points }}</strong></td>
                  <td>{{ row.correct }}/{{ row.total }}</td>
                  <td>{{ formatMs(row.durationMs) }}</td>
                </tr>
              </tbody>
            </table>
            <p v-else class="dl-challenge__empty">
              Todavía no hay partidas válidas en este desafío.
            </p>
          </section>
        </template>
      </template>
    </div>
  </q-page>
</template>

<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'

import { useAuth } from '@/composables/useAuth'
import {
  answerChallenge,
  fetchChallenge,
  fetchChallengeResult,
  fetchMyPartidas,
  fetchPartidaAnswers,
  fetchPartidaQuestions,
  fetchRanking,
  fetchServerNow,
  finishChallenge,
  startChallenge
} from '@/data/challengeRepository'

const route = useRoute()
const challengeId = route.params.challengeId

const { session, initAuth, startGuest, isGuest, publicName } = useAuth()

const challenge = ref(null)
const loading = ref(true)
const error = ref(null)
const personalError = ref(null)
const rankingError = ref(null)
const rankingLoading = ref(false)

const phase = ref('intro') // intro | playing | result
const starting = ref(false)
const startError = ref(null)
const finishing = ref(false)
const finishError = ref(null)
const saveState = ref('idle') // idle | saving | saved | failed
const confirmFinish = ref(false)

const partida = ref(null)
const questions = ref([])
const answers = ref({})
const currentIndex = ref(0)
const selectedOptionId = ref(null)
const checked = ref(false)
const submitting = ref(false)
const answerError = ref(null)
const answerResult = ref(null)

const result = ref(null)
const resultDetail = ref([])
const detailError = ref(null)
const detailLoading = ref(false)
const ranking = ref([])
const myPartidas = ref([])

const nowTick = ref(Date.now())
const serverOffset = ref(0)
let timer = null

const nowMs = computed(() => nowTick.value + serverOffset.value)

const event = computed(() => challenge.value?.event ?? null)

const isOpen = computed(() => {
  if (!challenge.value || !event.value) return false
  if (challenge.value.estado !== 'publicado') return false
  if (event.value.estado !== 'publicado') return false
  return (
    nowMs.value >= new Date(event.value.iniciaEn).getTime() &&
    nowMs.value <= new Date(event.value.terminaEn).getTime()
  )
})

const attemptsUsed = computed(() => myPartidas.value.length)
const attemptsLeft = computed(() =>
  Math.max(
    0,
    (challenge.value?.intentosPermitidos ?? 0) - attemptsUsed.value
  )
)
const openPartida = computed(
  () =>
    myPartidas.value.find(partida => partida.estado === 'en_curso') ?? null
)
const openPartidaExpired = computed(
  () =>
    !!openPartida.value &&
    nowMs.value > new Date(openPartida.value.expiraEn).getTime()
)
const bestPartida = computed(() => {
  const valid = myPartidas.value.filter(p => p.estado === 'finalizada')
  if (!valid.length) return null
  return valid.slice().sort(comparePartidas)[0]
})

const maxPoints = computed(
  () =>
    (challenge.value?.totalPreguntas ?? 0) *
    (challenge.value?.puntosPorAcierto ?? 0)
)

const currentQuestion = computed(
  () => questions.value[currentIndex.value] ?? null
)
const answeredCount = computed(() => Object.keys(answers.value).length)
const progressPct = computed(() => {
  const total = questions.value.length
  if (!total) return 0
  return Math.round((answeredCount.value / total) * 100)
})

const remainingSeconds = computed(() => {
  if (!partida.value?.expiraEn) return 0
  const end = new Date(partida.value.expiraEn).getTime()
  return Math.max(0, Math.ceil((end - nowMs.value) / 1000))
})
const timeExpired = computed(
  () => !!partida.value && remainingSeconds.value <= 0
)
const timerLabel = computed(() => {
  const seconds = remainingSeconds.value
  const minutes = Math.floor(seconds / 60)
  const rest = seconds % 60
  return `${String(minutes).padStart(2, '0')}:${String(rest).padStart(2, '0')}`
})

const startLabel = computed(() => {
  if (openPartida.value) return 'CONTINUAR PARTIDA'
  return 'EMPEZAR DESAFÍO'
})
const startDisabled = computed(() => {
  if (starting.value) return true
  if (openPartida.value) return false
  return !isOpen.value || attemptsLeft.value <= 0
})

const resultStateLabel = computed(() => {
  if (!result.value) return 'Partida'
  return (
    {
      finalizada: 'Partida válida',
      incompleta: 'Partida incompleta',
      vencida: 'Partida vencida'
    }[result.value.estado] ?? result.value.estado
  )
})
const resultStateClass = computed(() =>
  result.value?.estado === 'finalizada'
    ? 'dl-badge--available'
    : 'dl-badge--locked'
)
const resultStateIcon = computed(() =>
  result.value?.estado === 'finalizada'
    ? 'workspace_premium'
    : result.value?.estado === 'vencida'
      ? 'timer_off'
      : 'pending_actions'
)
const resultBannerClass = computed(() => {
  if (saveState.value !== 'saved') return 'dl-challenge__result-banner--pending'
  return result.value?.estado === 'finalizada'
    ? 'dl-challenge__result-banner--ok'
    : 'dl-challenge__result-banner--bad'
})
const resultMessage = computed(() => {
  if (!result.value) return ''
  if (result.value.estado === 'finalizada') {
    return 'Respondiste todo dentro del plazo. Este resultado compite en el ranking.'
  }
  if (result.value.estado === 'vencida') {
    return 'Se terminó el tiempo antes de finalizar. La partida queda en tu historial, pero no compite.'
  }
  return 'No respondiste todas las preguntas. La partida queda en tu historial, pero no compite.'
})
const resultRevealed = computed(() =>
  resultDetail.value.some(answer => answer.revealed)
)
const canPlayAgain = computed(
  () => isOpen.value && attemptsLeft.value > 0 && saveState.value === 'saved'
)

function comparePartidas(a, b) {
  if (b.puntos !== a.puntos) return b.puntos - a.puntos
  const durationA = a.duracionMs ?? Number.MAX_SAFE_INTEGER
  const durationB = b.duracionMs ?? Number.MAX_SAFE_INTEGER
  if (durationA !== durationB) return durationA - durationB
  return (
    new Date(a.finalizadoEn ?? 0).getTime() -
    new Date(b.finalizadoEn ?? 0).getTime()
  )
}

function nuevaClave() {
  try {
    return crypto.randomUUID()
  } catch {
    return `partida-${Date.now()}-${Math.random().toString(16).slice(2, 10)}`
  }
}

function answeredFromPartida(partidaRow) {
  return partidaRow.aciertos + partidaRow.errores
}

async function loadChallenge() {
  loading.value = true
  error.value = null
  try {
    challenge.value = await fetchChallenge(challengeId)
    if (!challenge.value) {
      error.value = 'El desafío no existe o no está disponible.'
    }
  } catch (err) {
    error.value = err?.message ?? 'No se pudo cargar el desafío.'
  } finally {
    loading.value = false
  }
}

async function loadPersonal() {
  personalError.value = null
  if (!session.value) {
    myPartidas.value = []
    return
  }
  try {
    myPartidas.value = await fetchMyPartidas(challengeId)
  } catch (err) {
    personalError.value =
      err?.message ?? 'No se pudo leer tu historial del desafío.'
  }
}

async function loadRanking() {
  rankingLoading.value = true
  rankingError.value = null
  try {
    ranking.value = await fetchRanking(challengeId, 100)
  } catch (err) {
    rankingError.value = err?.message ?? 'No se pudo cargar el ranking.'
  } finally {
    rankingLoading.value = false
  }
}

async function loadServerOffset() {
  try {
    const serverNow = await fetchServerNow()
    if (serverNow) {
      serverOffset.value = new Date(serverNow).getTime() - Date.now()
    }
  } catch {
    // Si falla, el temporizador usa el reloj local. Las reglas oficiales
    // siguen validándose en el servidor.
    serverOffset.value = 0
  }
}

function resetQuestion() {
  selectedOptionId.value = null
  checked.value = false
  answerError.value = null
  answerResult.value = null
}

async function resumePartida(partidaRow) {
  partida.value = partidaRow
  questions.value = await fetchPartidaQuestions(partidaRow.id)
  const existing = await fetchPartidaAnswers(partidaRow.id)
  answers.value = Object.fromEntries(
    existing.map(answer => [answer.questionId, answer])
  )
  const firstUnanswered = questions.value.findIndex(
    question => !answers.value[question.id]
  )
  currentIndex.value =
    firstUnanswered === -1 ? questions.value.length : firstUnanswered
  resetQuestion()
  confirmFinish.value = false
  phase.value = 'playing'
}

async function begin(forceNew) {
  if (starting.value) return
  starting.value = true
  startError.value = null
  try {
    await initAuth()
    if (!session.value) {
      const guest = await startGuest()
      if (!guest.ok) {
        throw new Error('No se pudo iniciar la sesión de invitado.')
      }
    }
    await loadServerOffset()
    await loadPersonal()

    if (!forceNew && openPartida.value) {
      await resumePartida(openPartida.value)
      return
    }

    if (!isOpen.value) {
      throw new Error('El desafío no está abierto en este momento.')
    }
    if (attemptsLeft.value <= 0) {
      throw new Error(
        'Ya usaste todos los intentos permitidos en este desafío.'
      )
    }

    const nueva = await startChallenge(challengeId, nuevaClave())
    partida.value = nueva
    questions.value = await fetchPartidaQuestions(nueva.id)
    answers.value = {}
    currentIndex.value = 0
    resetQuestion()
    confirmFinish.value = false
    phase.value = 'playing'
    await loadPersonal()
    await loadRanking()
  } catch (err) {
    startError.value = err?.message ?? 'No se pudo empezar la partida.'
  } finally {
    starting.value = false
  }
}

function selectOption(optionId) {
  if (checked.value || submitting.value || timeExpired.value) return
  selectedOptionId.value = optionId
}

function optionLetter(optionId) {
  const index = currentQuestion.value?.options.findIndex(
    option => option.id === optionId
  )
  return ['A', 'B', 'C', 'D'][index] ?? '?'
}

function optionClass(optionId) {
  if (!checked.value) {
    return optionId === selectedOptionId.value
      ? 'dl-challenge__option--selected'
      : ''
  }
  return optionId === selectedOptionId.value
    ? 'dl-challenge__option--chosen'
    : ''
}

async function confirmAnswer() {
  if (
    !partida.value ||
    !currentQuestion.value ||
    selectedOptionId.value === null ||
    checked.value ||
    submitting.value
  ) {
    return
  }
  submitting.value = true
  answerError.value = null
  try {
    const response = await answerChallenge(
      partida.value.id,
      currentQuestion.value.id,
      selectedOptionId.value
    )
    answers.value = {
      ...answers.value,
      [currentQuestion.value.id]: {
        optionId: selectedOptionId.value,
        correct: response.correcto,
        points: response.puntosObtenidos
      }
    }
    partida.value = {
      ...partida.value,
      puntos: response.puntosTotales,
      expiraEn: response.expiraEn ?? partida.value.expiraEn
    }
    answerResult.value = response
    checked.value = true
    if (timeExpired.value) {
      await finishNow()
    }
  } catch (err) {
    answerError.value = err?.message ?? 'No se pudo registrar la respuesta.'
    if (timeExpired.value) {
      await finishNow()
    }
  } finally {
    submitting.value = false
  }
}

async function nextQuestion() {
  if (currentIndex.value < questions.value.length - 1) {
    currentIndex.value += 1
    resetQuestion()
    return
  }
  await finishNow()
}

async function finishNow() {
  if (finishing.value || !partida.value) return
  finishing.value = true
  confirmFinish.value = false
  phase.value = 'result'
  saveState.value = 'saving'
  finishError.value = null
  detailError.value = null
  resultDetail.value = []
  try {
    const final = await finishChallenge(partida.value.id)
    result.value = final
    saveState.value = 'saved'
    try {
      await loadPersonal()
    } catch {
      /* el resultado ya está guardado */
    }
    try {
      await loadRanking()
    } catch {
      /* el ranking se puede reintentar */
    }
    detailLoading.value = true
    try {
      resultDetail.value = await fetchChallengeResult(partida.value.id)
    } catch (err) {
      detailError.value =
        err?.message ?? 'No se pudo cargar el detalle de la partida.'
    } finally {
      detailLoading.value = false
    }
  } catch (err) {
    finishError.value = err?.message ?? 'No se pudo finalizar la partida.'
    saveState.value = 'failed'
  } finally {
    finishing.value = false
  }
}

async function restart() {
  phase.value = 'intro'
  partida.value = null
  questions.value = []
  answers.value = {}
  currentIndex.value = 0
  resetQuestion()
  confirmFinish.value = false
  result.value = null
  resultDetail.value = []
  detailError.value = null
  saveState.value = 'idle'
  finishError.value = null
  startError.value = null
  await loadPersonal()
  await loadRanking()
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

function formatDuration(seconds) {
  if (seconds < 60) return `${seconds} s`
  const minutes = Math.floor(seconds / 60)
  const rest = seconds % 60
  return rest ? `${minutes} min ${rest} s` : `${minutes} min`
}

function formatMs(ms) {
  if (ms === null || ms === undefined) return '—'
  const seconds = Math.round(Number(ms) / 100) / 10
  if (seconds < 60) return `${seconds} s`
  const minutes = Math.floor(seconds / 60)
  const rest = Math.round((seconds % 60) * 10) / 10
  return `${minutes} min ${rest} s`
}

onMounted(async () => {
  timer = setInterval(() => {
    nowTick.value = Date.now()
  }, 500)
  await initAuth()
  await Promise.all([loadChallenge(), loadServerOffset()])
  await Promise.all([loadRanking(), loadPersonal()])
})

onBeforeUnmount(() => {
  if (timer) clearInterval(timer)
})
</script>

<style lang="scss" scoped>
.dl-challenge {
  background: #ffffff;
  min-height: 100vh;

  &__inner {
    max-width: 820px;
    margin: 0 auto;
    padding: 28px 20px 72px;
  }

  &__back {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    color: #6b6b6b;
    font-weight: 800;
    text-transform: uppercase;
    font-size: 13px;
    letter-spacing: 0.4px;
    text-decoration: none;
    margin-bottom: 16px;

    &:hover {
      color: $dl-green-dark;
    }
  }

  &__header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 16px;
    margin-bottom: 22px;
  }

  &__eyebrow {
    font-size: 12px;
    font-weight: 800;
    text-transform: uppercase;
    letter-spacing: 0.6px;
    color: $dl-green-dark;
    margin-bottom: 4px;
  }

  &__title {
    font-size: 30px;
    font-weight: 800;
    color: $dl-ink-dark;
    margin: 0 0 6px;
  }

  &__description {
    font-size: 15px;
    line-height: 1.6;
    color: #6b6b6b;
    margin: 0;
  }

  &__header-badges {
    display: flex;
    flex-direction: column;
    gap: 8px;
    align-items: flex-end;
  }

  &__section-title {
    font-size: 18px;
    font-weight: 800;
    color: $dl-ink-dark;
    margin: 0 0 14px;
  }

  &__rules-card,
  &__status-card,
  &__ranking-card,
  &__detail-card {
    background: #ffffff;
    border: 2px solid $dl-gray;
    border-radius: 18px;
    padding: 22px;
    margin-bottom: 18px;
  }

  &__rules-grid {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 12px;
  }

  &__rule {
    background: #f8faf7;
    border: 1px solid #e5e5e5;
    border-radius: 14px;
    padding: 12px 14px;
  }

  &__rule-value {
    display: block;
    font-size: 22px;
    font-weight: 800;
    color: $dl-ink-dark;
  }

  &__rule-label {
    display: block;
    font-size: 11px;
    font-weight: 800;
    text-transform: uppercase;
    letter-spacing: 0.4px;
    color: #8a8a8a;
    margin-top: 2px;
  }

  &__rule-note {
    font-size: 12px;
    line-height: 1.55;
    color: #8a8a8a;
    margin: 14px 0 0;
  }

  &__status-text {
    font-size: 14px;
    line-height: 1.6;
    color: #6b6b6b;
    margin: 0 0 10px;
  }

  &__status-facts {
    display: flex;
    flex-wrap: wrap;
    gap: 8px 22px;
    font-size: 14px;
    color: $dl-ink;

    strong {
      color: $dl-ink-dark;
    }
  }

  &__open {
    display: flex;
    gap: 12px;
    align-items: flex-start;
    background: #eef6fd;
    color: #176a9e;
    border-radius: 14px;
    padding: 14px 16px;
    margin-top: 16px;

    strong {
      font-size: 14px;
    }

    p {
      margin: 4px 0 0;
      font-size: 13px;
      line-height: 1.55;
    }

    &--expired {
      background: #fff8e6;
      color: #8a5b00;
    }
  }

  &__start {
    display: flex;
    flex-wrap: wrap;
    gap: 12px;
    margin-top: 18px;
  }

  &__inline-error {
    display: flex;
    gap: 10px;
    align-items: flex-start;
    background: #ffe9e9;
    color: #c00015;
    border-radius: 14px;
    padding: 14px 16px;
    margin-top: 16px;
    font-size: 14px;
    line-height: 1.55;

    strong {
      display: block;
      margin-bottom: 2px;
    }

    p {
      margin: 0;
    }
  }

  &__ranking-head,
  &__detail-head {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    gap: 12px;
    flex-wrap: wrap;
  }

  &__ranking-note {
    font-size: 12px;
    line-height: 1.55;
    color: #8a8a8a;
    margin: 0 0 14px;
  }

  &__detail-hint {
    font-size: 12px;
    color: #8a8a8a;
    margin-bottom: 14px;
  }

  &__empty {
    font-size: 14px;
    color: #8a8a8a;
    margin: 0;
  }

  &__state {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 6px;
    text-align: center;
    padding: 44px 0;
  }

  &__state-title {
    font-size: 22px;
    font-weight: 800;
    color: $dl-ink-dark;
    margin: 4px 0 0;
  }

  &__state-text {
    font-size: 14px;
    line-height: 1.55;
    color: #6b6b6b;
    margin: 0;
    max-width: 480px;
  }

  &__state-actions {
    display: flex;
    gap: 10px;
    flex-wrap: wrap;
    justify-content: center;
    margin-top: 10px;
  }

  // ---------- Jugando ----------
  &__playbar {
    display: flex;
    align-items: center;
    gap: 16px;
    background: #f8faf7;
    border: 2px solid $dl-gray;
    border-radius: 14px;
    padding: 10px 14px;
  }

  &__timer {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    font-size: 20px;
    font-weight: 800;
    color: $dl-green-dark;
    min-width: 96px;

    &.is-expired {
      color: $dl-red;
    }
  }

  &__playpoints {
    display: flex;
    align-items: baseline;
    gap: 4px;
    margin-right: auto;
  }

  &__playpoints-value {
    font-size: 20px;
    font-weight: 800;
    color: $dl-ink-dark;
  }

  &__playpoints-label {
    font-size: 12px;
    font-weight: 800;
    text-transform: uppercase;
    color: #8a8a8a;
  }

  &__track {
    height: 14px;
    background: $dl-gray;
    border-radius: 999px;
    overflow: hidden;
    margin-top: 16px;
  }

  &__track-fill {
    height: 100%;
    background: $dl-green;
    border-radius: 999px;
    transition: width 0.3s ease;
  }

  &__playmeta {
    display: flex;
    justify-content: space-between;
    gap: 12px;
    font-size: 13px;
    font-weight: 700;
    color: #8a8a8a;
    margin: 8px 0 18px;
  }

  &__timeout {
    display: flex;
    gap: 12px;
    align-items: flex-start;
    background: #fff8e6;
    color: #8a5b00;
    border-radius: 14px;
    padding: 14px 16px;
    margin-bottom: 18px;

    strong {
      font-size: 15px;
    }

    p {
      margin: 4px 0 0;
      font-size: 13px;
      line-height: 1.55;
    }
  }

  &__confirm {
    display: flex;
    gap: 12px;
    align-items: flex-start;
    background: #eef6fd;
    color: #176a9e;
    border-radius: 14px;
    padding: 16px 18px;
    margin-bottom: 18px;

    strong {
      font-size: 15px;
    }

    p {
      margin: 4px 0 10px;
      font-size: 13px;
      line-height: 1.55;
    }
  }

  &__confirm-actions {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
  }

  &__question {
    display: flex;
    gap: 14px;
    margin-bottom: 18px;
  }

  &__question-icon {
    flex: 0 0 auto;
    width: 50px;
    height: 50px;
    border-radius: 50%;
    background: #ffeed9;
    color: $dl-orange;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  &__question-bubble {
    background: #f6fbf4;
    border: 2px solid $dl-gray;
    border-radius: 16px 16px 16px 4px;
    padding: 16px 18px;
  }

  &__question-text {
    font-size: 19px;
    line-height: 1.45;
    font-weight: 800;
    color: $dl-ink-dark;
    margin: 0;
  }

  &__code {
    background: #1e1e1e;
    color: #e5e5e5;
    font-family: 'JetBrains Mono', 'Consolas', 'Courier New', monospace;
    font-size: 13.5px;
    line-height: 1.6;
    border-radius: 12px;
    padding: 16px 18px;
    overflow-x: auto;
    margin: 0 0 18px;
    white-space: pre;
  }

  &__options {
    display: flex;
    flex-direction: column;
    gap: 12px;
    margin-bottom: 20px;
  }

  &__option {
    display: flex;
    align-items: center;
    gap: 14px;
    width: 100%;
    text-align: left;
    background: #ffffff;
    border: 2px solid $dl-gray;
    border-radius: 14px;
    padding: 14px 16px;
    cursor: pointer;
    transition:
      background 0.15s ease,
      border-color 0.15s ease,
      box-shadow 0.15s ease;

    &:hover:not(:disabled) {
      background: #f6fbf4;
      border-color: #b5e3a3;
    }

    &:disabled {
      cursor: default;
    }

    &--selected {
      background: #f6fbf4;
      border-color: $dl-blue;
      box-shadow: 0 3px 0 rgba(28, 176, 246, 0.3);
    }

    &--chosen {
      background: #eef6fd;
      border-color: $dl-blue;
    }
  }

  &__option-letter {
    flex: 0 0 34px;
    width: 34px;
    height: 34px;
    border-radius: 10px;
    background: #f0f4f0;
    color: #6b6b6b;
    font-weight: 800;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  &__option-text {
    flex: 1 1 0;
    font-size: 16px;
    font-weight: 700;
    color: $dl-ink-dark;
  }

  &__feedback {
    display: flex;
    gap: 12px;
    align-items: flex-start;
    border-radius: 14px;
    padding: 16px 18px;
    margin-bottom: 18px;

    strong {
      font-size: 16px;
    }

    p {
      margin: 4px 0 0;
      font-size: 14px;
      line-height: 1.55;
    }

    &--ok {
      background: #e9f7e2;
      color: $dl-green-dark;
    }

    &--bad {
      background: #ffe9e9;
      color: #c00015;
    }
  }

  &__actions {
    display: flex;
    justify-content: flex-end;
  }

  // ---------- Resultado ----------
  &__result {
    display: flex;
    justify-content: center;
    margin-bottom: 18px;
  }

  &__result-banner {
    max-width: 620px;
    width: 100%;
    border: 2px solid $dl-gray;
    border-radius: 22px;
    padding: 28px 24px;
    text-align: center;
    display: flex;
    flex-direction: column;
    align-items: center;

    &--ok {
      background: #f4fbf0;
      border-color: #b5e3a3;
    }

    &--bad {
      background: #fff8f0;
      border-color: #ffd9a3;
    }

    &--pending {
      background: #f6f9fc;
      border-color: #cfe3f3;
    }
  }

  &__save {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    border-radius: 12px;
    padding: 10px 14px;
    margin: 14px 0 8px;
    font-size: 13px;
    font-weight: 700;
    text-align: left;

    &--saved {
      background: #e9f7e2;
      color: $dl-green-dark;
    }

    &--failed {
      background: #ffe9e9;
      color: #c00015;
    }
  }

  &__score {
    display: flex;
    align-items: baseline;
    gap: 6px;
    margin: 8px 0 0;
  }

  &__score-value {
    font-size: 56px;
    font-weight: 800;
    line-height: 1;
    color: $dl-ink-dark;
  }

  &__score-label {
    font-size: 14px;
    font-weight: 800;
    text-transform: uppercase;
    color: #8a8a8a;
  }

  &__result-message {
    font-size: 14px;
    line-height: 1.55;
    color: #6b6b6b;
    margin: 8px 0 18px;
    max-width: 460px;
  }

  &__result-stats {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 10px;
    width: 100%;
    margin-bottom: 20px;
  }

  &__result-stat {
    background: #ffffff;
    border: 2px solid $dl-gray;
    border-radius: 14px;
    padding: 12px 6px;
  }

  &__result-stat-value {
    display: block;
    font-size: 22px;
    font-weight: 800;
    color: $dl-ink-dark;
  }

  &__result-stat-label {
    display: block;
    font-size: 11px;
    font-weight: 800;
    text-transform: uppercase;
    letter-spacing: 0.4px;
    color: #8a8a8a;
    margin-top: 2px;
  }

  &__result-actions {
    display: flex;
    flex-wrap: wrap;
    justify-content: center;
    gap: 12px;
  }

  &__result-note {
    font-size: 12px;
    line-height: 1.55;
    color: #8a8a8a;
    margin: 14px 0 0;
    max-width: 460px;
  }

  // ---------- Detalle ----------
  &__answers {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  &__answer {
    display: flex;
    gap: 10px;
    align-items: flex-start;
    border-bottom: 1px solid #f0f0f0;
    padding-bottom: 12px;

    &:last-child {
      border-bottom: 0;
      padding-bottom: 0;
    }
  }

  &__answer-body {
    display: flex;
    flex-direction: column;
    gap: 2px;
    font-size: 13px;
    color: $dl-ink;
  }

  &__answer-question {
    font-weight: 800;
    color: $dl-ink-dark;
  }

  &__answer-line {
    line-height: 1.5;
  }

  &__answer-explain {
    font-size: 12px;
    line-height: 1.55;
    color: #6b6b6b;
    margin-top: 2px;
  }
}

.dl-ranking {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;

  th {
    text-align: left;
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.4px;
    color: #8a8a8a;
    padding: 6px 8px;
    border-bottom: 2px solid $dl-gray;
  }

  td {
    padding: 8px;
    border-bottom: 1px solid #f0f0f0;
    color: $dl-ink;
  }

  &__me td {
    background: #f6fbf4;
    font-weight: 700;
  }

  &__tag {
    display: inline-block;
    background: $dl-green;
    color: #ffffff;
    font-size: 10px;
    font-weight: 800;
    border-radius: 999px;
    padding: 1px 6px;
    margin-left: 4px;
    text-transform: uppercase;
  }
}

@media (max-width: 640px) {
  .dl-challenge__rules-grid,
  .dl-challenge__result-stats {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .dl-challenge__header {
    flex-direction: column;
  }

  .dl-challenge__header-badges {
    flex-direction: row;
  }

  .dl-challenge__title {
    font-size: 24px;
  }

  .dl-challenge__score-value {
    font-size: 44px;
  }

  .dl-ranking {
    display: block;
    overflow-x: auto;
    white-space: nowrap;
  }
}
</style>
