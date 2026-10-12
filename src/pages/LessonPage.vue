<template>
  <q-page class="dl-lesson">
    <div class="dl-lesson__inner">
      <!-- Cargando -->
      <div v-if="loading" class="dl-lesson__state">
        <q-spinner color="primary" size="34px" class="q-mb-sm" />
        <p class="dl-lesson__state-text">Cargando la lección…</p>
      </div>

      <!-- Error de consulta -->
      <div v-else-if="error" class="dl-lesson__state">
        <q-icon name="wifi_off" size="44px" color="negative" />
        <h2 class="dl-lesson__state-title">No se pudo cargar la lección</h2>
        <p class="dl-lesson__state-text">{{ error }}</p>
        <q-btn
          no-caps
          unelevated
          color="primary"
          class="q-mt-sm"
          label="Reintentar"
          @click="load"
        />
      </div>

      <!-- No encontrada -->
      <template v-else-if="!lesson">
        <div class="dl-lesson__notfound">
          <img :src="usagiImg" alt="Usagi" class="dl-lesson__notfound-mascot" />
          <h2 class="dl-lesson__notfound-title">Lección no encontrada</h2>
          <p class="dl-lesson__notfound-text">
            El identificador <strong>{{ lessonParam }}</strong> no corresponde a
            ninguna lección de esta unidad.
          </p>
          <q-btn
            no-caps
            unelevated
            size="lg"
            class="dl-btn-main"
            :label="`Volver a la unidad`"
            @click="goToUnit"
          />
        </div>
      </template>

      <!-- Bloqueada -->
      <template v-else-if="!canStart">
        <div class="dl-lesson__notfound">
          <q-icon name="lock" size="56px" color="grey-5" />
          <h2 class="dl-lesson__notfound-title">Lección bloqueada</h2>
          <p class="dl-lesson__notfound-text">
            Aprobá la lección anterior para habilitar
            <strong>{{ lesson.title }}</strong
            >.
          </p>
          <q-btn
            no-caps
            unelevated
            size="lg"
            class="dl-btn-main"
            label="Volver a la unidad"
            @click="goToUnit"
          />
        </div>
      </template>

      <!-- Contenido -->
      <template v-else>
        <!-- FASE 1: Introducción (teoría) -->
        <template v-if="phase === 'intro'">
          <router-link
            :to="{ name: 'unidad', params: { slug, unitId } }"
            class="dl-lesson__back"
          >
            <q-icon name="arrow_back" size="18px" />
            Volver a la unidad
          </router-link>

          <div class="dl-lesson__meta">
            <span class="dl-lesson__unit"
              >Unidad {{ unit.order }} · {{ unit.title }}</span
            >
            <span class="dl-lesson__sep">/</span>
            <span class="dl-lesson__lesson">{{ lesson.title }}</span>
          </div>

          <div class="dl-lesson__intro">
            <h1 class="dl-lesson__intro-title">{{ lesson.title }}</h1>

            <div class="dl-lesson__explanation">
              <h2 class="dl-lesson__subtitle">Explicación</h2>
              <p class="dl-lesson__explanation-text">{{
                lesson.explanation
              }}</p>
            </div>

            <div v-if="lesson.codeExample" class="dl-lesson__example">
              <h2 class="dl-lesson__subtitle">Ejemplo de código</h2>
              <pre
                class="dl-lesson__code"
              ><code>{{ lesson.codeExample }}</code></pre>
            </div>

            <div class="dl-lesson__intro-actions">
              <q-btn
                no-caps
                unelevated
                size="lg"
                class="dl-btn-main dl-btn-main--big"
                :label="startLabel"
                @click="startActivities"
              />
            </div>
          </div>
        </template>

        <!-- FASE 2: Actividades -->
        <template v-else-if="phase === 'activity'">
          <div class="dl-lesson__bar">
            <router-link
              :to="{ name: 'unidad', params: { slug, unitId } }"
              class="dl-lesson__close"
            >
              <q-icon name="close" size="22px" />
            </router-link>
            <div class="dl-lesson__track">
              <div
                class="dl-lesson__track-fill"
                :style="{ width: `${barPct}%` }"
              />
            </div>
          </div>

          <div class="dl-lesson__meta">
            <span class="dl-lesson__unit">{{ unit.title }}</span>
            <span class="dl-lesson__sep">/</span>
            <span class="dl-lesson__lesson">{{ lesson.title }}</span>
            <span class="dl-lesson__counter"
              >Actividad {{ currentIndex + 1 }} de {{ totalActivities }}</span
            >
          </div>

          <div class="dl-lesson__prompt">
            <div class="dl-lesson__mascot">
              <q-icon name="sms" size="22px" />
            </div>
            <div class="dl-lesson__bubble">
              <h2 class="dl-lesson__question">{{ currentActivity.prompt }}</h2>
            </div>
          </div>

          <pre
            v-if="currentActivity.code"
            class="dl-lesson__code"
          ><code>{{ currentActivity.code }}</code></pre>

          <div class="dl-lesson__options">
            <button
              v-for="option in currentActivity.options"
              :key="option.id"
              type="button"
              class="dl-lesson__option"
              :class="optionClass(option.id)"
              :disabled="checked || submitting"
              @click="selectOption(option.id)"
            >
              <span class="dl-lesson__option-letter">{{
                optionLetter(option.id)
              }}</span>
              <span class="dl-lesson__option-text">{{ option.text }}</span>
              <span
                v-if="checked"
                class="dl-lesson__option-check"
                :class="{
                  'dl-lesson__option-check--ok': option.id === checkedAnswerId,
                  'dl-lesson__option-check--bad':
                    option.id === selectedOptionId &&
                    option.id !== checkedAnswerId
                }"
              >
                <q-icon
                  :name="
                    option.id === checkedAnswerId
                      ? 'check'
                      : option.id === selectedOptionId
                        ? 'close'
                        : 'remove'
                  "
                  size="14px"
                />
              </span>
            </button>
          </div>

          <!-- No se pudo comprobar -->
          <transition name="dl-fade">
            <div v-if="checkError" class="dl-lesson__check-error">
              <q-icon name="error_outline" size="26px" />
              <div>
                <strong>No se pudo comprobar tu respuesta</strong>
                <p>
                  {{ checkError }} Revisá tu conexión y volvé a intentar. Tu
                  intento no se contabilizó.
                </p>
              </div>
            </div>
          </transition>

          <transition name="dl-fade">
            <div
              v-if="checked"
              class="dl-lesson__feedback"
              :class="`dl-lesson__feedback--${isCorrect ? 'ok' : 'bad'}`"
            >
              <q-icon
                :name="isCorrect ? 'check_circle' : 'error'"
                size="26px"
              />
              <div>
                <strong>{{
                  isCorrect ? '¡Correcto!' : 'Respuesta incorrecta'
                }}</strong>
                <p>{{ feedbackText }}</p>
              </div>
            </div>
          </transition>

          <div class="dl-lesson__actions">
            <template v-if="!checked">
              <q-btn
                no-caps
                unelevated
                size="lg"
                :label="submitting ? 'COMPROBANDO…' : 'CONFIRMAR'"
                class="dl-btn-main dl-btn-main--big"
                :disable="!selectedOptionId || submitting"
                @click="check"
              />
            </template>
            <template v-else>
              <q-btn
                v-if="currentIndex < totalActivities - 1"
                no-caps
                unelevated
                size="lg"
                label="CONTINUAR"
                class="dl-btn-main dl-btn-main--big"
                @click="next"
              />
              <q-btn
                v-else
                no-caps
                unelevated
                size="lg"
                label="VER RESULTADOS"
                class="dl-btn-main dl-btn-main--big"
                @click="finish"
              />
            </template>
          </div>
        </template>

        <!-- FASE 3: Resultados -->
        <template v-else>
          <div class="dl-lesson__result">
            <div
              class="dl-lesson__result-banner"
              :class="
                passed
                  ? 'dl-lesson__result-banner--ok'
                  : 'dl-lesson__result-banner--bad'
              "
            >
              <img
                :src="usagiImg"
                alt="Usagi"
                class="dl-lesson__result-mascot"
              />
              <span
                class="dl-badge"
                :class="passed ? 'dl-badge--available' : 'dl-badge--locked'"
              >
                <q-icon :name="passed ? 'check_circle' : 'replay'" />
                {{ passed ? 'Lección aprobada' : 'No alcanzaste el mínimo' }}
              </span>

              <h2 class="dl-lesson__result-title">{{ resultHeadline }}</h2>
              <p class="dl-lesson__result-summary">
                {{ lesson.title }}
              </p>

              <div class="dl-lesson__result-stats">
                <div class="dl-lesson__result-stat">
                  <span class="dl-lesson__result-stat-value">{{
                    totalActivities
                  }}</span>
                  <span class="dl-lesson__result-stat-label">Actividades</span>
                </div>
                <div class="dl-lesson__result-stat dl-lesson__result-stat--ok">
                  <span class="dl-lesson__result-stat-value">{{
                    correctCount
                  }}</span>
                  <span class="dl-lesson__result-stat-label">Correctas</span>
                </div>
                <div class="dl-lesson__result-stat dl-lesson__result-stat--bad">
                  <span class="dl-lesson__result-stat-value">{{
                    incorrectCount
                  }}</span>
                  <span class="dl-lesson__result-stat-label">Incorrectas</span>
                </div>
                <div class="dl-lesson__result-stat">
                  <span class="dl-lesson__result-stat-value"
                    >{{ percentage }}%</span
                  >
                  <span class="dl-lesson__result-stat-label">Aciertos</span>
                </div>
              </div>

              <p class="dl-lesson__result-note">
                Para aprobar una lección de 3 actividades necesitás al menos 2
                correctas (60%). Estos resultados corresponden a este intento y
                todavía no forman parte de un ranking compartido.
              </p>

              <div class="dl-lesson__result-actions">
                <q-btn
                  v-if="passed && nextLesson"
                  no-caps
                  unelevated
                  size="lg"
                  class="dl-btn-main dl-btn-main--big"
                  label="Siguiente lección"
                  @click="goToNextLesson"
                />
                <q-btn
                  no-caps
                  unelevated
                  size="lg"
                  class="dl-btn-main"
                  label="Intentar nuevamente"
                  @click="restart"
                />
                <q-btn
                  no-caps
                  outline
                  size="lg"
                  class="dl-btn-ghost"
                  label="Volver a la unidad"
                  @click="goToUnit"
                />
              </div>
            </div>
          </div>
        </template>
      </template>
    </div>
  </q-page>
</template>

<script setup>
import { computed, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getUnits, getActivities, checkAnswer } from '@/data/courseRepository'
import { useProgress } from '@/composables/useProgress'
import { useRemoteData } from '@/composables/useRemoteData'
import usagiImg from '@/assets/usagi.webp'

const route = useRoute()
const router = useRouter()

const slug = route.params.slug
const unitId = route.params.unitId
const lessonParam = route.params.lessonId

const { lessonStatus, completeAttempt } = useProgress()

const { data, loading, error, load } = useRemoteData(async () => {
  const units = await getUnits(slug)
  const unit = units.find(u => u.id === unitId) ?? null
  const lessons = unit ? unit.lessons : []
  const lesson = lessons.find(l => l.id === lessonParam) ?? null
  const activities = lesson
    ? await getActivities(slug, unitId, lessonParam)
    : []
  return { unit, lessons, lesson, activities }
})

const unit = computed(() => data.value?.unit ?? null)
const lessons = computed(() => data.value?.lessons ?? [])
const lesson = computed(() => data.value?.lesson ?? null)
const activities = computed(() => data.value?.activities ?? [])

const lessonIndex = computed(() =>
  lessons.value.findIndex(l => l.id === lessonParam)
)

const lessonState = computed(() =>
  lesson.value && unit.value
    ? lessonStatus(unit.value, lesson.value, lessonIndex.value, lessons.value)
    : 'pendiente'
)

const canStart = computed(() =>
  ['disponible', 'aprobada', 'reprobada'].includes(lessonState.value)
)

const startLabel = computed(() => {
  if (lessonState.value === 'aprobada') return 'Repasar lección'
  if (lessonState.value === 'reprobada') return 'Reintentar lección'
  return 'Comenzar actividades'
})

// ---------- Estado del intento ----------
const phase = ref('intro') // 'intro' | 'activity' | 'results'
const currentIndex = ref(0)
const selectedOptionId = ref(null)
const checked = ref(false)
const submitting = ref(false)
const checkError = ref(null)
const checkedResult = ref(null) // { correcto, explicacion, opcion_correcta_id }
const correctCount = ref(0)

const totalActivities = computed(() => activities.value.length)
const currentActivity = computed(() => activities.value[currentIndex.value])
const isCorrect = computed(() => checkedResult.value?.correcto === true)
const checkedAnswerId = computed(() => checkedResult.value?.opcion_correcta_id)
const incorrectCount = computed(
  () => totalActivities.value - correctCount.value
)
const percentage = computed(() =>
  totalActivities.value === 0
    ? 0
    : Math.round((correctCount.value / totalActivities.value) * 100)
)
const passed = computed(
  () => correctCount.value >= Math.ceil(totalActivities.value * 0.6)
)

const correctOptionText = computed(() => {
  const found = currentActivity.value?.options.find(
    o => o.id === checkedAnswerId.value
  )
  return found?.text ?? ''
})

const feedbackText = computed(() => {
  if (!checkedResult.value) return ''
  if (isCorrect.value) return checkedResult.value.explicacion
  return `La opción correcta es "${correctOptionText.value}". ${checkedResult.value.explicacion}`
})

const nextLesson = computed(() =>
  lessonIndex.value >= 0 && lessonIndex.value < lessons.value.length - 1
    ? lessons.value[lessonIndex.value + 1]
    : null
)

const resultHeadline = computed(() => {
  if (passed.value && correctCount.value === totalActivities.value) {
    return '¡Perfecto!'
  }
  if (passed.value) return '¡Aprobaste!'
  return 'Casi lo lográs'
})

const barPct = computed(() => {
  const done = currentIndex.value + (checked.value ? 1 : 0)
  return totalActivities.value === 0
    ? 0
    : Math.round((done / totalActivities.value) * 100)
})

function optionLetter(optionId) {
  const index = currentActivity.value.options.findIndex(o => o.id === optionId)
  return ['A', 'B', 'C', 'D'][index] ?? '?'
}

function optionClass(optionId) {
  if (!checked.value) {
    return optionId === selectedOptionId.value
      ? 'dl-lesson__option--selected'
      : ''
  }
  if (optionId === checkedAnswerId.value) return 'dl-lesson__option--correct'
  if (optionId === selectedOptionId.value) return 'dl-lesson__option--wrong'
  return 'dl-lesson__option--dimmed'
}

function startActivities() {
  phase.value = 'activity'
}

function selectOption(optionId) {
  if (checked.value || submitting.value) return
  selectedOptionId.value = optionId
}

// Comprueba la respuesta en el servidor (RPC check_answer). Si la conexión
// falla, NO se muestra como incorrecta: queda un mensaje y se puede reintentar.
async function check() {
  if (selectedOptionId.value === null) return
  if (checked.value || submitting.value) return // no se envía dos veces
  submitting.value = true
  checkError.value = null
  try {
    const result = await checkAnswer(
      currentActivity.value.id,
      selectedOptionId.value
    )
    if (!result) throw new Error('El servidor no devolvió un resultado.')
    checkedResult.value = result
    checked.value = true
    if (result.correcto) {
      correctCount.value += 1
    }
  } catch (err) {
    checkError.value = err?.message ?? 'Ocurrió un error inesperado.'
  } finally {
    submitting.value = false
  }
}

function next() {
  currentIndex.value += 1
  selectedOptionId.value = null
  checked.value = false
  checkError.value = null
  checkedResult.value = null
}

function finish() {
  const total = totalActivities.value
  const correct = correctCount.value
  // La lección queda completada (intentada) y aprobada si alcanza el umbral.
  completeAttempt(lessonParam, { correct, total })
  phase.value = 'results'
}

function restart() {
  phase.value = 'intro'
  currentIndex.value = 0
  selectedOptionId.value = null
  checked.value = false
  submitting.value = false
  checkError.value = null
  checkedResult.value = null
  correctCount.value = 0
}

function goToUnit() {
  router.push({ name: 'unidad', params: { slug, unitId } })
}

function goToNextLesson() {
  if (nextLesson.value) {
    router.push({
      name: 'leccion',
      params: { slug, unitId, lessonId: nextLesson.value.id }
    })
  }
}
</script>

<style lang="scss" scoped>
.dl-lesson {
  background: #ffffff;
  min-height: 100vh;

  &__inner {
    max-width: 720px;
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

  &__bar {
    display: flex;
    align-items: center;
    gap: 14px;
  }

  &__close {
    color: $dl-ink;
    text-decoration: none;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 40px;
    height: 40px;
    border-radius: 50%;
    transition: background 0.15s ease;

    &:hover {
      background: #f0f4f0;
    }
  }

  &__track {
    flex: 1 1 0;
    height: 16px;
    background: $dl-gray;
    border-radius: 999px;
    overflow: hidden;
  }

  &__track-fill {
    height: 100%;
    background: $dl-green;
    border-radius: 999px;
    transition: width 0.3s ease;
  }

  &__meta {
    display: flex;
    align-items: baseline;
    gap: 8px;
    margin: 20px 0 24px;
    flex-wrap: wrap;
  }

  &__unit {
    font-size: 13px;
    font-weight: 800;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    color: #8a8a8a;
  }

  &__sep {
    color: $dl-gray;
  }

  &__lesson {
    font-size: 16px;
    font-weight: 800;
    color: $dl-ink-dark;
  }

  &__counter {
    margin-left: auto;
    font-size: 13px;
    font-weight: 700;
    color: #8a8a8a;
  }

  // ---------- Intro ----------
  &__intro {
    background: #f6fbf4;
    border: 2px solid $dl-gray;
    border-radius: 18px;
    padding: 28px 24px;
  }

  &__intro-title {
    font-size: 26px;
    font-weight: 800;
    color: $dl-ink-dark;
    margin: 0 0 18px;
  }

  &__subtitle {
    font-size: 16px;
    font-weight: 800;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    color: $dl-green-dark;
    margin: 0 0 8px;
  }

  &__explanation {
    margin-bottom: 20px;
  }

  &__explanation-text {
    font-size: 16px;
    line-height: 1.65;
    color: $dl-ink;
    margin: 0;
  }

  &__example {
    margin-bottom: 24px;
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
    margin: 0;
    white-space: pre;
  }

  &__intro-actions {
    display: flex;
    justify-content: flex-end;
  }

  // ---------- Actividades ----------
  &__prompt {
    display: flex;
    gap: 14px;
    margin-bottom: 20px;
  }

  &__mascot {
    flex: 0 0 auto;
    width: 54px;
    height: 54px;
    border-radius: 50%;
    background: #ffeed9;
    color: $dl-orange;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  &__bubble {
    background: #f6fbf4;
    border: 2px solid $dl-gray;
    border-radius: 16px 16px 16px 4px;
    padding: 16px 18px;
  }

  &__question {
    font-size: 19px;
    line-height: 1.45;
    font-weight: 800;
    color: $dl-ink-dark;
    margin: 0;
  }

  &__options {
    display: flex;
    flex-direction: column;
    gap: 12px;
    margin-bottom: 24px;
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

    &--correct {
      background: $dl-green;
      border-color: $dl-green;
      color: #ffffff;
    }

    &--wrong {
      background: $dl-red;
      border-color: $dl-red;
      color: #ffffff;
    }

    &--dimmed {
      opacity: 0.5;
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

    .dl-lesson__option--correct &,
    .dl-lesson__option--wrong & {
      background: rgba(255, 255, 255, 0.25);
      color: inherit;
    }
  }

  &__option-text {
    flex: 1 1 0;
    font-size: 16px;
    font-weight: 700;
    color: $dl-ink-dark;

    .dl-lesson__option--correct &,
    .dl-lesson__option--wrong & {
      color: inherit;
    }
  }

  &__option-check {
    flex: 0 0 auto;
    width: 28px;
    height: 28px;
    border-radius: 50%;
    background: #e6e6e6;
    color: #8a8a8a;
    display: flex;
    align-items: center;
    justify-content: center;

    &--ok {
      background: $dl-green-dark;
      color: #ffffff;
    }

    &--bad {
      background: #c00015;
      color: #ffffff;
    }
  }

  &__feedback {
    display: flex;
    gap: 12px;
    align-items: flex-start;
    border-radius: 14px;
    padding: 16px 18px;
    margin-bottom: 20px;

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

  // ---------- Resultados ----------
  &__result {
    display: flex;
    justify-content: center;
  }

  &__result-banner {
    max-width: 560px;
    width: 100%;
    border: 2px solid $dl-gray;
    border-radius: 22px;
    padding: 32px 24px;
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
  }

  &__result-mascot {
    width: 140px;
    height: 140px;
    object-fit: contain;
    margin-bottom: 10px;
  }

  &__result-title {
    font-size: 26px;
    font-weight: 800;
    color: $dl-ink-dark;
    margin: 12px 0 4px;
  }

  &__result-summary {
    font-size: 14px;
    color: #6b6b6b;
    margin: 0 0 20px;
  }

  &__result-stats {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 10px;
    width: 100%;
    margin-bottom: 18px;
  }

  &__result-stat {
    background: #ffffff;
    border: 2px solid $dl-gray;
    border-radius: 14px;
    padding: 12px 6px;

    &--ok {
      border-color: #b5e3a3;
    }

    &--bad {
      border-color: #ffc9c9;
    }
  }

  &__result-stat-value {
    display: block;
    font-size: 24px;
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

  &__result-note {
    font-size: 13px;
    line-height: 1.5;
    color: #6b6b6b;
    margin: 0 0 22px;
    max-width: 440px;
  }

  &__result-actions {
    display: flex;
    flex-wrap: wrap;
    justify-content: center;
    gap: 12px;
  }

  // ---------- Auxiliares ----------
  &__state {
    text-align: center;
    padding: 48px 0;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 6px;
  }

  &__state-title {
    font-size: 20px;
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

  &__check-error {
    display: flex;
    gap: 12px;
    align-items: flex-start;
    background: #fff8e6;
    color: #8a5b00;
    border-radius: 14px;
    padding: 16px 18px;
    margin-bottom: 20px;

    strong {
      font-size: 16px;
    }

    p {
      margin: 4px 0 0;
      font-size: 14px;
      line-height: 1.55;
    }
  }

  &__notfound {
    text-align: center;
    padding: 48px 0;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 10px;
  }

  &__notfound-mascot {
    width: 150px;
    height: 150px;
    object-fit: contain;
  }

  &__notfound-title {
    font-size: 24px;
    font-weight: 800;
    color: $dl-ink-dark;
    margin: 0;
  }

  &__notfound-text {
    font-size: 15px;
    color: $dl-ink;
    margin: 0 0 8px;
  }
}

.dl-fade-enter-active,
.dl-fade-leave-active {
  transition:
    opacity 0.2s ease,
    transform 0.2s ease;
}

.dl-fade-enter-from,
.dl-fade-leave-to {
  opacity: 0;
  transform: translateY(6px);
}

@media (max-width: 480px) {
  .dl-lesson__result-stats {
    grid-template-columns: repeat(2, 1fr);
  }
}
</style>
