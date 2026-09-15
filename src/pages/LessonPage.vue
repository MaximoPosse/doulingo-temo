<template>
  <q-page class="dl-lesson">
    <div class="dl-lesson__inner">
      <!-- Ejercicios -->
      <template v-if="!finished">
        <div class="dl-lesson__bar">
          <router-link
            :to="{ name: 'curso', params: { slug } }"
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
            >Ejercicio {{ currentIndex + 1 }} de {{ totalExercises }}</span
          >
        </div>

        <div class="dl-lesson__prompt">
          <div class="dl-lesson__mascot">
            <q-icon name="sms" size="22px" />
          </div>
          <div class="dl-lesson__bubble">
            <h2 class="dl-lesson__question">{{ currentExercise.prompt }}</h2>
          </div>
        </div>

        <pre
          v-if="currentExercise.code"
          class="dl-lesson__code"
        ><code>{{ currentExercise.code }}</code></pre>

        <div class="dl-lesson__options">
          <button
            v-for="(option, index) in currentExercise.options"
            :key="index"
            type="button"
            class="dl-lesson__option"
            :class="optionClass(index)"
            :disabled="checked"
            @click="selectOption(index)"
          >
            <span class="dl-lesson__option-letter">{{ letters[index] }}</span>
            <span class="dl-lesson__option-text">{{ option }}</span>
            <span
              v-if="checked"
              class="dl-lesson__option-check"
              :class="{
                'dl-lesson__option-check--ok': index === currentExercise.answer,
                'dl-lesson__option-check--bad':
                  index === selected && index !== currentExercise.answer
              }"
            >
              <q-icon
                :name="
                  index === currentExercise.answer
                    ? 'check'
                    : index === selected
                      ? 'close'
                      : 'remove'
                "
                size="14px"
              />
            </span>
          </button>
        </div>

        <transition name="dl-fade">
          <div
            v-if="checked"
            class="dl-lesson__feedback"
            :class="`dl-lesson__feedback--${isCorrect ? 'ok' : 'bad'}`"
          >
            <q-icon :name="isCorrect ? 'check_circle' : 'error'" size="24px" />
            <div>
              <strong>{{
                isCorrect ? '¡Correcto!' : 'Respuesta incorrecta'
              }}</strong>
              <p>
                {{
                  isCorrect
                    ? currentExercise.explanation
                    : `La respuesta correcta es "${currentExercise.options[currentExercise.answer]}". ${currentExercise.explanation}`
                }}
              </p>
            </div>
          </div>
        </transition>

        <div class="dl-lesson__actions">
          <template v-if="!checked">
            <q-btn
              no-caps
              unelevated
              size="lg"
              label="COMPROBAR"
              class="dl-btn-main dl-btn-main--big"
              :disable="selected === null"
              @click="check"
            />
          </template>
          <template v-else>
            <q-btn
              v-if="currentIndex < totalExercises - 1"
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
              label="VER RESULTADO"
              class="dl-btn-main dl-btn-main--big"
              @click="finish"
            />
          </template>
        </div>
      </template>

      <!-- Resultado -->
      <template v-else>
        <div class="dl-lesson__result">
          <div class="dl-lesson__result-card">
            <img :src="usagiImg" alt="Usagi" class="dl-lesson__result-mascot" />

            <span
              class="dl-badge"
              :class="passed ? 'dl-badge--completed' : 'dl-badge--locked'"
            >
              <q-icon :name="passed ? 'check_circle' : 'replay'" />
              {{ passed ? 'Lección completada' : 'Vuelve a intentarlo' }}
            </span>

            <h2 class="dl-lesson__result-title">
              {{ resultHeadline }}
            </h2>
            <p class="dl-lesson__result-score">
              Acertaste <strong>{{ score }}</strong> de
              {{ totalExercises }} ejercicios.
            </p>
            <p class="dl-lesson__result-sub">
              {{ resultSub }}
            </p>

            <div class="dl-lesson__result-actions">
              <q-btn
                no-caps
                unelevated
                size="lg"
                class="dl-btn-main dl-btn-main--big"
                label="Repetir lección"
                @click="restart"
              />
              <q-btn
                no-caps
                outline
                size="lg"
                class="dl-btn-ghost"
                label="Volver al curso"
                @click="goToCourse"
              />
            </div>
          </div>
        </div>
      </template>
    </div>
  </q-page>
</template>

<script setup>
import { computed, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { javascriptCourse } from '@/data/javascriptCourse'
import { useProgress } from '@/composables/useProgress'
import usagiImg from '@/assets/usagi.webp'

const route = useRoute()
const router = useRouter()

const slug = route.params.slug
const unitId = route.params.unitId
const lessonId = route.params.lessonId

const { completeLesson } = useProgress()

const unit = computed(() => javascriptCourse.units.find(u => u.id === unitId))
const lesson = computed(() => unit.value?.lessons.find(l => l.id === lessonId))
const lessonIndex = computed(() =>
  unit.value ? unit.value.lessons.findIndex(l => l.id === lessonId) : -1
)

const exercises = computed(() => lesson.value?.exercises ?? [])
const totalExercises = computed(() => exercises.value.length)
const currentIndex = ref(0)
const selected = ref(null)
const checked = ref(false)
const score = ref(0)
const finished = ref(false)
const passed = ref(false)

const currentExercise = computed(() => exercises.value[currentIndex.value])
const isCorrect = computed(
  () => currentExercise.value && selected.value === currentExercise.value.answer
)

const barPct = computed(() => {
  const done = currentIndex.value + (checked.value ? 1 : 0)
  return totalExercises.value === 0
    ? 0
    : Math.round((done / totalExercises.value) * 100)
})

const letters = ['A', 'B', 'C', 'D']

const resultHeadline = computed(() => {
  if (score.value === totalExercises.value)
    return '¡Perfecto! Usagi está orgullosa de ti.'
  if (passed.value) return '¡Buen trabajo!'
  return 'Casi lo logras'
})

const resultSub = computed(() => {
  if (passed.value) {
    return 'Sigues así y dominarás JavaScript muy pronto.'
  }
  return 'Repasa la lección y vuelve a intentarlo: cada error es un paso hacia adelante.'
})

function optionClass(index) {
  if (!checked.value) {
    return selected.value === index ? 'dl-lesson__option--selected' : ''
  }
  if (index === currentExercise.value.answer)
    return 'dl-lesson__option--correct'
  if (index === selected.value) return 'dl-lesson__option--wrong'
  return 'dl-lesson__option--dimmed'
}

function selectOption(index) {
  if (checked.value) return
  selected.value = index
}

function check() {
  if (selected.value === null) return
  checked.value = true
  if (selected.value === currentExercise.value.answer) {
    score.value += 1
  }
}

function next() {
  currentIndex.value += 1
  selected.value = null
  checked.value = false
}

function finish() {
  passed.value = score.value >= Math.ceil(totalExercises.value / 2)
  finished.value = true
  if (passed.value && unit.value && lesson.value) {
    completeLesson(
      lesson.value.id,
      unit.value.id,
      lessonIndex.value,
      unit.value.lessons
    )
  }
}

function restart() {
  currentIndex.value = 0
  selected.value = null
  checked.value = false
  score.value = 0
  finished.value = false
  passed.value = false
}

function goToCourse() {
  router.push({ name: 'curso', params: { slug } })
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
    margin: 20px 0 28px;
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
    font-size: 20px;
    line-height: 1.4;
    font-weight: 800;
    color: $dl-ink-dark;
    margin: 0;
  }

  &__code {
    background: #1e1e1e;
    color: #e5e5e5;
    font-family: 'JetBrains Mono', 'Consolas', 'Courier New', monospace;
    font-size: 14px;
    line-height: 1.55;
    border-radius: 12px;
    padding: 16px 18px;
    overflow-x: auto;
    margin: 0 0 20px;
    white-space: pre;
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

    .dl-lesson__option--correct & {
      background: rgba(255, 255, 255, 0.25);
      color: inherit;
    }

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
      line-height: 1.5;
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

  &__result {
    display: flex;
    justify-content: center;
  }

  &__result-card {
    max-width: 520px;
    width: 100%;
    background: #ffffff;
    border: 2px solid $dl-gray;
    border-radius: 22px;
    padding: 36px 28px;
    text-align: center;
    display: flex;
    flex-direction: column;
    align-items: center;
  }

  &__result-mascot {
    width: 150px;
    height: 150px;
    object-fit: contain;
    margin-bottom: 12px;
  }

  &__result-title {
    font-size: 26px;
    font-weight: 800;
    color: $dl-ink-dark;
    margin: 12px 0 6px;
  }

  &__result-score {
    font-size: 16px;
    color: $dl-ink;
    margin: 0 0 6px;
  }

  &__result-sub {
    font-size: 14px;
    line-height: 1.5;
    color: #6b6b6b;
    margin: 0 0 24px;
  }

  &__result-actions {
    display: flex;
    flex-wrap: wrap;
    justify-content: center;
    gap: 14px;
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
</style>
