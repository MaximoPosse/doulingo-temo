<template>
  <q-page class="dl-page">
    <div class="dl-page__inner dl-auth">
      <div class="dl-auth__card">
        <img
          :src="usagiImg"
          alt="Usagi, la mascota de Doulingo"
          class="dl-auth__mascot"
        />
        <h1 class="dl-auth__title">{{ title }}</h1>
        <p class="dl-auth__lead">{{ lead }}</p>

        <!-- Avisos y errores -->
        <q-banner
          v-if="authError"
          rounded
          class="dl-auth__banner dl-error-banner"
        >
          <q-icon name="error_outline" size="22px" color="negative" />
          {{ authError }}
        </q-banner>
        <q-banner
          v-if="notice"
          rounded
          class="dl-auth__banner dl-notice-banner"
        >
          <q-icon name="check_circle" size="22px" color="positive" />
          {{ notice }}
        </q-banner>

        <!-- Ya hay sesión -->
        <div v-if="hasSession" class="dl-auth__block">
          <q-banner rounded class="dl-notice-banner">
            <q-icon name="badge" size="22px" color="primary" />
            Sesión activa como <strong>{{ publicName }}</strong> ({{
              isGuest ? 'invitado' : 'cuenta permanente'
            }}).
          </q-banner>
          <q-btn
            no-caps
            unelevated
            color="primary"
            class="dl-btn-main dl-btn-main--big full-width q-mt-md"
            label="Ir a mi cuenta"
            :to="{ name: 'perfil' }"
          />
        </div>

        <!-- Enlace de recuperación de contraseña -->
        <form
          v-else-if="recoveryMode"
          class="dl-auth__block"
          @submit.prevent="submitPassword"
        >
          <p class="dl-auth__hint">
            Definí la nueva contraseña de tu cuenta. Cuando la guardes vas a
            poder entrar con tu correo.
          </p>
          <q-input
            v-model="password"
            outlined
            type="password"
            label="Nueva contraseña"
            autocomplete="new-password"
            :rules="[value => !!value || 'Ingresá una contraseña']"
            class="q-mb-sm"
          />
          <q-input
            v-model="password2"
            outlined
            type="password"
            label="Repetí la contraseña"
            autocomplete="new-password"
            :rules="[
              value => value === password || 'Las contraseñas no coinciden'
            ]"
            class="q-mb-md"
          />
          <q-btn
            no-caps
            unelevated
            color="primary"
            class="dl-btn-main dl-btn-main--big full-width"
            type="submit"
            label="GUARDAR CONTRASEÑA"
            :loading="busy"
          />
        </form>

        <!-- Conversión de invitado a cuenta permanente -->
        <form
          v-else-if="mode === 'convertir'"
          class="dl-auth__block"
          @submit.prevent="submitConvert"
        >
          <p class="dl-auth__hint">
            Convertí tu sesión de invitado en una cuenta permanente: conservás
            el mismo identificador, tu alias y tu historial. No se crea otra
            cuenta ni se copian resultados.
          </p>
          <q-input
            v-model="email"
            outlined
            type="email"
            label="Correo electrónico"
            autocomplete="email"
            :rules="[value => !!value || 'Ingresá un correo']"
            class="q-mb-sm"
          />
          <q-input
            v-model="password"
            outlined
            type="password"
            label="Contraseña"
            autocomplete="new-password"
            :rules="[value => !!value || 'Ingresá una contraseña']"
            class="q-mb-md"
          />
          <q-btn
            no-caps
            unelevated
            color="primary"
            class="dl-btn-main dl-btn-main--big full-width"
            type="submit"
            label="CONVERTIR MI CUENTA"
            :loading="busy"
          />
        </form>

        <!-- Acceso normal -->
        <template v-else>
          <q-tabs
            v-model="tab"
            dense
            no-caps
            align="justify"
            class="dl-auth__tabs"
          >
            <q-tab name="invitado" label="Invitado" />
            <q-tab name="registro" label="Crear cuenta" />
            <q-tab name="entrar" label="Ingresar" />
          </q-tabs>
          <q-separator />

          <q-tab-panels v-model="tab" animated class="dl-auth__panels">
            <!-- Invitado -->
            <q-tab-panel name="invitado" class="dl-auth__block">
              <p class="dl-auth__hint">
                Entrás como invitado con una sesión propia de este dispositivo.
                No necesitás correo ni contraseña y podés practicar desde ya.
              </p>
              <q-btn
                no-caps
                unelevated
                color="primary"
                class="dl-btn-main dl-btn-main--big full-width"
                label="CONTINUAR COMO INVITADO"
                :loading="busy"
                @click="submitGuest"
              />
              <p class="dl-auth__note">
                <q-icon name="info" size="16px" />
                Un invitado puede perder el acceso a su historial si cierra
                sesión, elimina los datos del navegador o cambia de dispositivo.
                Convertirte en cuenta permanente lo evita.
              </p>
            </q-tab-panel>

            <!-- Registro -->
            <q-tab-panel name="registro" class="dl-auth__block">
              <p class="dl-auth__hint">
                Creá tu cuenta con correo y contraseña. Te enviamos un correo
                para confirmarla (según la configuración del proyecto).
              </p>
              <q-input
                v-model="alias"
                outlined
                label="Alias público"
                hint="3 a 20 caracteres: minúsculas, números y guion bajo"
                :rules="[aliasRule]"
                class="q-mb-sm"
              />
              <q-input
                v-model="email"
                outlined
                type="email"
                label="Correo electrónico"
                autocomplete="email"
                :rules="[value => !!value || 'Ingresá un correo']"
                class="q-mb-sm"
              />
              <q-input
                v-model="password"
                outlined
                type="password"
                label="Contraseña"
                autocomplete="new-password"
                :rules="[value => !!value || 'Ingresá una contraseña']"
                class="q-mb-md"
              />
              <q-btn
                no-caps
                unelevated
                color="primary"
                class="dl-btn-main dl-btn-main--big full-width"
                type="submit"
                label="CREAR CUENTA"
                :loading="busy"
                @click="submitRegister"
              />
              <q-btn
                v-if="pendingEmail"
                flat
                no-caps
                class="dl-auth__link full-width"
                label="Reenviar correo de confirmación"
                @click="submitResend"
              />
            </q-tab-panel>

            <!-- Ingreso -->
            <q-tab-panel name="entrar" class="dl-auth__block">
              <p class="dl-auth__hint">
                Entrá con el correo y la contraseña de tu cuenta.
              </p>
              <q-input
                v-model="email"
                outlined
                type="email"
                label="Correo electrónico"
                autocomplete="email"
                :rules="[value => !!value || 'Ingresá un correo']"
                class="q-mb-sm"
              />
              <q-input
                v-model="password"
                outlined
                type="password"
                label="Contraseña"
                autocomplete="current-password"
                :rules="[value => !!value || 'Ingresá una contraseña']"
                class="q-mb-md"
              />
              <q-btn
                no-caps
                unelevated
                color="primary"
                class="dl-btn-main dl-btn-main--big full-width"
                label="ENTRAR"
                :loading="busy"
                @click="submitSignIn"
              />
              <q-btn
                flat
                no-caps
                class="dl-auth__link full-width"
                label="Olvidé mi contraseña"
                @click="tab = 'recuperar'"
              />
            </q-tab-panel>

            <!-- Recuperación -->
            <q-tab-panel name="recuperar" class="dl-auth__block">
              <p class="dl-auth__hint">
                Escribí tu correo y te enviamos un enlace para definir una nueva
                contraseña.
              </p>
              <q-input
                v-model="email"
                outlined
                type="email"
                label="Correo electrónico"
                autocomplete="email"
                class="q-mb-md"
              />
              <q-btn
                no-caps
                unelevated
                color="primary"
                class="dl-btn-main dl-btn-main--big full-width"
                label="ENVIAR ENLACE"
                :loading="busy"
                @click="submitRecovery"
              />
              <q-btn
                flat
                no-caps
                class="dl-auth__link full-width"
                label="Volver a ingresar"
                @click="tab = 'entrar'"
              />
            </q-tab-panel>
          </q-tab-panels>
        </template>
      </div>
    </div>
  </q-page>
</template>

<script setup>
import { computed, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import usagiImg from '@/assets/usagi.webp'
import { useAuth } from '@/composables/useAuth'

const route = useRoute()
const router = useRouter()

const {
  session,
  authError,
  notice,
  recoveryMode,
  isGuest,
  publicName,
  register,
  signIn,
  startGuest,
  requestRecovery,
  resendConfirmation,
  setNewPassword,
  convertToAccount,
  clearMessages
} = useAuth()

const tab = ref('invitado')
const email = ref('')
const password = ref('')
const password2 = ref('')
const alias = ref('')
const busy = ref(false)
const pendingEmail = ref('')

const mode = computed(() => route.query.modo ?? '')
const nextPath = computed(() => route.query.next ?? '')
const hasSession = computed(() => !!session.value && mode.value === '')

const title = computed(() => {
  if (recoveryMode.value) return 'Definí tu nueva contraseña'
  if (mode.value === 'convertir') return 'Convertí tu cuenta'
  return 'Accedé a Arabytes'
})

const lead = computed(() => {
  if (recoveryMode.value) {
    return 'Confirmamos tu correo: elegí una contraseña nueva para tu cuenta.'
  }
  if (mode.value === 'convertir') {
    return 'Tu sesión de invitado se convierte en una cuenta permanente.'
  }
  return 'Entrá como invitado, creá tu cuenta o ingresá con tu correo.'
})

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

watch(
  () => route.query.modo,
  () => clearMessages()
)

async function run(action, redirect = true) {
  busy.value = true
  const result = await action()
  busy.value = false
  if (result.ok && redirect) {
    router.push(nextPath.value || '/perfil')
  }
  return result
}

async function submitGuest() {
  await run(() => startGuest(), false)
  if (nextPath.value) router.push(nextPath.value)
}

async function submitRegister() {
  const result = await run(
    () =>
      register({
        email: email.value,
        password: password.value,
        alias: alias.value
      }),
    false
  )
  if (result.ok) {
    pendingEmail.value = email.value
    if (result.confirmed) router.push(nextPath.value || '/perfil')
  }
}

async function submitSignIn() {
  await run(() => signIn({ email: email.value, password: password.value }))
}

async function submitRecovery() {
  await run(() => requestRecovery(email.value), false)
}

async function submitResend() {
  await run(() => resendConfirmation(pendingEmail.value), false)
}

async function submitPassword() {
  await run(() => setNewPassword(password.value), false)
}

async function submitConvert() {
  await run(() =>
    convertToAccount({ email: email.value, password: password.value })
  )
}
</script>

<style scoped>
.dl-auth {
  display: flex;
  justify-content: center;
}

.dl-auth__card {
  width: 100%;
  max-width: 520px;
  background: #ffffff;
  border: 2px solid #e5e5e5;
  border-radius: 18px;
  padding: 24px;
  box-shadow: 0 10px 24px rgba(0, 0, 0, 0.05);
}

.dl-auth__mascot {
  width: 64px;
  height: 64px;
  object-fit: contain;
}

.dl-auth__title {
  font-size: 26px;
  font-weight: 800;
  color: #3c3c3c;
  margin: 8px 0 4px;
}

.dl-auth__lead {
  color: #6b6b6b;
  margin: 0 0 16px;
}

.dl-auth__banner {
  margin-bottom: 14px;
}

.dl-auth__tabs {
  color: #6b6b6b;
}

.dl-auth__panels {
  background: transparent;
}

.dl-auth__block {
  padding: 18px 4px 4px;
}

.dl-auth__hint {
  color: #6b6b6b;
  margin: 0 0 14px;
}

.dl-auth__note {
  display: flex;
  gap: 6px;
  align-items: flex-start;
  color: #8a8a8a;
  font-size: 13px;
  margin: 14px 0 0;
}

.dl-auth__link {
  color: #58a700;
  font-weight: 700;
  margin-top: 8px;
}
</style>
