<template>
  <q-page class="dl-page">
    <div class="dl-page__inner">
      <router-link :to="{ name: 'cursos' }" class="dl-back">
        <q-icon name="arrow_back" size="18px" />
        Volver a los cursos
      </router-link>

      <div v-if="loading" class="dl-states">
        <q-spinner color="primary" size="34px" class="q-mb-sm" />
        <p class="dl-states__text">Cargando tu cuenta…</p>
      </div>

      <template v-else>
        <h1 class="dl-page__title">Mi cuenta</h1>
        <p class="dl-page__lead">
          Tu identidad pública es el alias con sufijo. Permite que otras
          personas te distingan aunque compartan un alias similar.
        </p>

        <q-banner v-if="authError" rounded class="dl-error-banner q-mb-md">
          <q-icon name="error_outline" size="22px" color="negative" />
          {{ authError }}
        </q-banner>
        <q-banner v-if="notice" rounded class="dl-notice-banner q-mb-md">
          <q-icon name="check_circle" size="22px" color="positive" />
          {{ notice }}
        </q-banner>

        <!-- Identidad -->
        <section class="dl-card">
          <h2 class="dl-card__title">Identidad</h2>

          <div class="dl-identity">
            <div class="dl-identity__public">
              <span class="dl-identity__label">Nombre público</span>
              <span class="dl-identity__name">{{ publicName }}</span>
              <span
                class="dl-badge"
                :class="isGuest ? 'dl-badge--locked' : 'dl-badge--available'"
              >
                <q-icon :name="isGuest ? 'person' : 'verified_user'" />
                {{ isGuest ? 'Invitado' : 'Cuenta permanente' }}
              </span>
            </div>

            <div class="dl-identity__fields">
              <q-input
                v-model="aliasDraft"
                outlined
                label="Alias público"
                hint="3 a 20 caracteres: minúsculas, números y guion bajo"
                :rules="[aliasRule]"
                class="q-mb-sm"
              />
              <q-btn
                no-caps
                unelevated
                color="primary"
                class="dl-btn-main"
                label="GUARDAR ALIAS"
                :loading="busy"
                @click="submitAlias"
              />
            </div>
          </div>

          <q-separator class="q-my-md" />

          <ul class="dl-privacy">
            <li>
              <q-icon name="public" size="18px" color="primary" />
              <span>
                <strong>Se muestra públicamente:</strong> tu alias y su sufijo
                (por ejemplo <code>{{ publicName }}</code
                >) y, en la etapa de competencia, tus resultados.
              </span>
            </li>
            <li>
              <q-icon name="lock" size="18px" color="grey-7" />
              <span>
                <strong>Se guarda en privado:</strong> tu correo electrónico y
                tu identificador de cuenta. No se guardan contraseñas en las
                tablas del proyecto: eso vive únicamente en Supabase Auth.
              </span>
            </li>
            <li v-if="isGuest">
              <q-icon name="warning" size="18px" color="orange" />
              <span>
                <strong>Historial de invitado:</strong> si cerrás sesión, borrás
                los datos del navegador o cambiás de dispositivo podés perder el
                acceso a tu historial. Conviene convertir la cuenta.
              </span>
            </li>
          </ul>
        </section>

        <!-- Historial -->
        <section class="dl-card q-mt-md">
          <h2 class="dl-card__title">Historial</h2>
          <div class="dl-stats">
            <div class="dl-stat">
              <span class="dl-stat__value">{{ approved.length }}</span>
              <span class="dl-stat__label">Lecciones aprobadas</span>
            </div>
            <div class="dl-stat">
              <span class="dl-stat__value">{{ pendingLessons }}</span>
              <span class="dl-stat__label">Lecciones pendientes</span>
            </div>
            <div class="dl-stat">
              <span class="dl-stat__value">{{ finalizedAttempts.length }}</span>
              <span class="dl-stat__label">Intentos guardados</span>
            </div>
            <div class="dl-stat">
              <span class="dl-stat__value">{{
                inProgressAttempts.length
              }}</span>
              <span class="dl-stat__label">Sin terminar</span>
            </div>
            <div class="dl-stat">
              <span class="dl-stat__value">{{ identityType }}</span>
              <span class="dl-stat__label">Tipo de sesión</span>
            </div>
          </div>

          <ul v-if="approvedDetails.length" class="dl-history">
            <li v-for="lesson in approvedDetails" :key="lesson.id">
              <q-icon name="check_circle" size="18px" color="positive" />
              {{ lesson.title }}
            </li>
          </ul>
          <p v-else class="dl-card__empty">
            Todavía no aprobaste ninguna lección. Tu avance se guarda solo en
            este dispositivo hasta que inicies sesión.
          </p>

          <q-banner
            v-if="attemptsError"
            rounded
            class="dl-error-banner q-mt-md"
          >
            <q-icon name="error_outline" size="22px" color="negative" />
            {{ attemptsError }}
          </q-banner>
        </section>

        <!-- Último intento -->
        <section v-if="lastAttempt" class="dl-card q-mt-md">
          <h2 class="dl-card__title">Último intento</h2>
          <div class="dl-last">
            <div class="dl-last__main">
              <span class="dl-last__lesson">{{ lastAttempt.lessonTitle }}</span>
              <span class="dl-last__date">{{
                formatDate(lastAttempt.finalizadoEn)
              }}</span>
            </div>
            <span class="dl-badge" :class="attemptBadgeClass(lastAttempt)">
              <q-icon
                :name="lastAttempt.aprobada ? 'check_circle' : 'replay'"
              />
              {{ attemptLabel(lastAttempt) }}
            </span>
            <div class="dl-last__numbers">
              <span
                ><strong>{{ lastAttempt.aciertos }}</strong> correctas de
                {{ lastAttempt.totalActividades }}</span
              >
              <span
                ><strong>{{ lastAttempt.errores }}</strong> incorrectas</span
              >
            </div>
          </div>
        </section>

        <!-- Intentos -->
        <section class="dl-card q-mt-md">
          <h2 class="dl-card__title">Intentos</h2>
          <p class="dl-card__empty q-mb-sm">
            Cada intento conserva su fecha, sus respuestas y su resultado. Los
            intentos sin terminar no cuentan como lección completada.
          </p>

          <ul v-if="attempts.length" class="dl-attempts">
            <li
              v-for="attempt in attempts"
              :key="attempt.id"
              class="dl-attempt"
            >
              <div class="dl-attempt__row">
                <div class="dl-attempt__main">
                  <span class="dl-attempt__lesson">{{
                    attempt.lessonTitle
                  }}</span>
                  <span class="dl-attempt__meta">
                    {{ formatDate(attempt.finalizadoEn || attempt.iniciadoEn) }}
                    · {{ attemptDetail(attempt) }}
                  </span>
                </div>
                <span class="dl-badge" :class="attemptBadgeClass(attempt)">
                  {{ attemptLabel(attempt) }}
                </span>
                <q-btn
                  no-caps
                  flat
                  dense
                  color="primary"
                  :label="
                    expandedAttemptId === attempt.id
                      ? 'Ocultar respuestas'
                      : 'Ver respuestas'
                  "
                  @click="toggleAnswers(attempt)"
                />
              </div>

              <div
                v-if="expandedAttemptId === attempt.id"
                class="dl-attempt__answers"
              >
                <div
                  v-if="loadingAnswers === attempt.id"
                  class="dl-attempt__loading"
                >
                  <q-spinner size="18px" />
                  Cargando respuestas…
                </div>
                <template v-else>
                  <div
                    v-for="answer in answersFor(attempt)"
                    :key="answer.activityId"
                    class="dl-answer"
                  >
                    <q-icon
                      :name="answer.correct ? 'check_circle' : 'cancel'"
                      size="18px"
                      :color="answer.correct ? 'positive' : 'negative'"
                    />
                    <div>
                      <span class="dl-answer__question">
                        {{ answer.order }}. {{ answer.question }}
                      </span>
                      <span class="dl-answer__choice">
                        Elegiste: {{ answer.option }}
                      </span>
                    </div>
                  </div>
                  <p v-if="!answersFor(attempt).length" class="dl-card__empty">
                    No hay respuestas guardadas en este intento.
                  </p>
                </template>
              </div>
            </li>
          </ul>

          <p v-else class="dl-card__empty">
            Todavía no hay intentos guardados. Al terminar una lección vas a ver
            acá el resultado y el detalle de tus respuestas.
          </p>
        </section>

        <!-- Acciones -->
        <section class="dl-card q-mt-md">
          <h2 class="dl-card__title">Acciones</h2>

          <q-btn
            v-if="isGuest"
            no-caps
            unelevated
            color="primary"
            class="dl-btn-main dl-btn-main--big full-width"
            label="CONVERTIR MI CUENTA PERMANENTE"
            :to="{ name: 'acceso', query: { modo: 'convertir' } }"
          />
          <p v-if="isGuest" class="dl-card__empty">
            Conservás tu identificador, tu alias y tu historial: no se crea otra
            cuenta ni se copian resultados desde el cliente.
          </p>

          <q-btn
            no-caps
            outline
            color="negative"
            class="dl-btn-ghost full-width q-mt-sm"
            label="CERRAR SESIÓN"
            :loading="busy"
            @click="submitSignOut"
          />
          <p class="dl-card__empty">
            Si cerrás sesión como invitado, tu historial queda guardado en este
            dispositivo, pero no vas a poder recuperarlo si borrás los datos o
            cambiás de dispositivo.
          </p>

          <q-btn
            no-caps
            flat
            color="grey-8"
            class="full-width q-mt-xs"
            label="Borrar mi historial de este dispositivo"
            @click="submitClear"
          />
        </section>
      </template>
    </div>
  </q-page>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'

import { useAuth } from '@/composables/useAuth'
import { useProgress } from '@/composables/useProgress'
import { getUnits } from '@/data/courseRepository'
import { fetchAttemptAnswers, fetchAttempts } from '@/data/attemptRepository'

const router = useRouter()
const {
  profile,
  isGuest,
  publicName,
  authError,
  notice,
  signOut,
  changeAlias,
  initAuth
} = useAuth()
const { progress, clearHistory } = useProgress()

const aliasDraft = ref('')
const busy = ref(false)
const loading = ref(true)
const lessonTitles = ref(new Map())
const attempts = ref([])
const attemptsError = ref(null)
const answersByAttempt = ref({})
const expandedAttemptId = ref(null)
const loadingAnswers = ref(null)

const identityType = computed(() => (isGuest.value ? 'Invitado' : 'Permanente'))
const approved = computed(() => progress.value.approvedLessons)

const pendingLessons = computed(() =>
  Math.max(lessonTitles.value.size - approved.value.length, 0)
)
const finalizedAttempts = computed(() =>
  attempts.value.filter(attempt => attempt.estado === 'finalizado')
)
const inProgressAttempts = computed(() =>
  attempts.value.filter(attempt => attempt.estado === 'en_curso')
)
const lastAttempt = computed(() => finalizedAttempts.value[0] ?? null)

const aliasRule = value => {
  const clean = (value ?? '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_]+/g, '_')
    .replace(/^_+|_+$/g, '')
  if (clean.length < 3) return 'El alias necesita al menos 3 caracteres'
  if (clean.length > 20) return 'El alias admite hasta 20 caracteres'
  return true
}

const approvedDetails = computed(() =>
  approved.value.map(id => ({
    id,
    title: lessonTitles.value.get(id) ?? 'Lección'
  }))
)

function formatDate(value) {
  if (!value) return ''
  try {
    return new Intl.DateTimeFormat('es', {
      dateStyle: 'short',
      timeStyle: 'short'
    }).format(new Date(value))
  } catch {
    return value
  }
}

function attemptLabel(attempt) {
  if (attempt.estado === 'en_curso') return 'Sin terminar'
  return attempt.aprobada ? 'Aprobado' : 'Reprobado'
}

function attemptBadgeClass(attempt) {
  if (attempt.estado === 'en_curso') return 'dl-badge--locked'
  return attempt.aprobada ? 'dl-badge--available' : 'dl-badge--locked'
}

function attemptDetail(attempt) {
  if (attempt.estado === 'en_curso') {
    const answered = attempt.aciertos + attempt.errores
    return `${answered} de ${attempt.totalActividades} respondidas`
  }
  return `${attempt.aciertos} de ${attempt.totalActividades} correctas`
}

function answersFor(attempt) {
  return answersByAttempt.value[attempt.id] ?? []
}

async function toggleAnswers(attempt) {
  if (expandedAttemptId.value === attempt.id) {
    expandedAttemptId.value = null
    return
  }
  expandedAttemptId.value = attempt.id
  if (answersByAttempt.value[attempt.id]) return
  loadingAnswers.value = attempt.id
  try {
    answersByAttempt.value = {
      ...answersByAttempt.value,
      [attempt.id]: await fetchAttemptAnswers([attempt.id])
    }
  } catch (err) {
    notice.value = ''
    authError.value =
      err?.message ?? 'No se pudieron leer las respuestas del intento.'
  } finally {
    loadingAnswers.value = null
  }
}

async function loadAttempts() {
  attemptsError.value = null
  try {
    attempts.value = await fetchAttempts()
  } catch (err) {
    attemptsError.value =
      err?.message ?? 'No se pudo leer el historial de intentos.'
  }
}

async function loadTitles() {
  try {
    const units = await getUnits('javascript')
    const map = new Map()
    for (const unit of units) {
      for (const lesson of unit.lessons) map.set(lesson.id, lesson.title)
    }
    lessonTitles.value = map
  } catch {
    /* sin títulos: se muestra el identificador de la lección */
  }
}

onMounted(async () => {
  aliasDraft.value = profile.value?.alias ?? ''
  await initAuth()
  await Promise.all([loadTitles(), loadAttempts()])
  loading.value = false
})

async function submitAlias() {
  busy.value = true
  await changeAlias(aliasDraft.value)
  busy.value = false
}

async function submitSignOut() {
  busy.value = true
  await signOut()
  busy.value = false
  router.push({ name: 'acceso' })
}

async function submitClear() {
  busy.value = true
  try {
    await clearHistory()
    attempts.value = []
    answersByAttempt.value = {}
    expandedAttemptId.value = null
    notice.value = 'Se borró tu historial (en el dispositivo y en la base).'
  } catch (err) {
    notice.value = ''
    authError.value = err?.message ?? 'No se pudo borrar el historial.'
  } finally {
    busy.value = false
  }
}
</script>

<style scoped>
.dl-card {
  background: #ffffff;
  border: 2px solid #e5e5e5;
  border-radius: 16px;
  padding: 20px;
}

.dl-card__title {
  font-size: 19px;
  font-weight: 800;
  color: #3c3c3c;
  margin: 0 0 12px;
}

.dl-card__empty {
  color: #8a8a8a;
  font-size: 13px;
  margin: 10px 0 0;
}

.dl-identity {
  display: flex;
  flex-wrap: wrap;
  gap: 18px;
  justify-content: space-between;
}

.dl-identity__public {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.dl-identity__label {
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 1px;
  color: #9a9a9a;
}

.dl-identity__name {
  font-size: 24px;
  font-weight: 800;
  color: #58a700;
}

.dl-identity__fields {
  flex: 1 1 260px;
  max-width: 340px;
}

.dl-privacy {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.dl-privacy li {
  display: flex;
  gap: 8px;
  align-items: flex-start;
  color: #6b6b6b;
  font-size: 14px;
}

.dl-stats {
  display: flex;
  gap: 18px;
  flex-wrap: wrap;
}

.dl-stat {
  display: flex;
  flex-direction: column;
}

.dl-stat__value {
  font-size: 26px;
  font-weight: 800;
  color: #3c3c3c;
}

.dl-stat__label {
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 1px;
  color: #9a9a9a;
}

.dl-history {
  list-style: none;
  margin: 16px 0 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 6px;
  color: #6b6b6b;
}

.dl-last {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 14px;
}

.dl-last__main {
  flex: 1 1 200px;
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.dl-last__lesson {
  font-size: 18px;
  font-weight: 800;
  color: #3c3c3c;
}

.dl-last__date {
  font-size: 13px;
  color: #8a8a8a;
}

.dl-last__numbers {
  display: flex;
  flex-wrap: wrap;
  gap: 14px;
  font-size: 14px;
  color: #6b6b6b;
}

.dl-attempts {
  list-style: none;
  margin: 16px 0 0;
  padding: 0;
  display: flex;
  flex-direction: column;
}

.dl-attempt {
  border-top: 1px solid #efefef;
  padding: 12px 0;
}

.dl-attempt:first-child {
  border-top: none;
  padding-top: 0;
}

.dl-attempt__row {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 10px;
}

.dl-attempt__main {
  flex: 1 1 220px;
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.dl-attempt__lesson {
  font-size: 15px;
  font-weight: 800;
  color: #3c3c3c;
}

.dl-attempt__meta {
  font-size: 13px;
  color: #8a8a8a;
}

.dl-attempt__answers {
  margin-top: 10px;
  padding: 10px 12px;
  background: #f8faf8;
  border-radius: 12px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.dl-attempt__loading {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
  color: #6b6b6b;
}

.dl-answer {
  display: flex;
  gap: 8px;
  align-items: flex-start;
  font-size: 14px;
}

.dl-answer__question {
  display: block;
  font-weight: 700;
  color: #3c3c3c;
}

.dl-answer__choice {
  display: block;
  color: #6b6b6b;
}
</style>
