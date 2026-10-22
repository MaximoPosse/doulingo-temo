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
              <span class="dl-stat__value">{{ attempted.length }}</span>
              <span class="dl-stat__label">Lecciones intentadas</span>
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

const router = useRouter()
const {
  profile,
  isGuest,
  publicName,
  authError,
  notice,
  signOut,
  changeAlias
} = useAuth()
const { progress, clearHistory } = useProgress()

const aliasDraft = ref('')
const busy = ref(false)
const loading = ref(true)
const lessonTitles = ref(new Map())

const identityType = computed(() => (isGuest.value ? 'Invitado' : 'Permanente'))
const approved = computed(() => progress.value.approvedLessons)
const attempted = computed(() => progress.value.attemptedLessons)

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
  await loadTitles()
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
</style>
