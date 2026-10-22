// Estado de sesión del participante.
//
// Tres situaciones posibles:
//   - sin-sesion : visitante sin sesión (público). Puede leer el contenido
//                  publicado y usar la app; su avance queda solo en el
//                  dispositivo.
//   - invitado   : sesión anónima autenticada propia de este dispositivo
//                  (is_anonymous = true). Tiene identificador propio y su
//                  historial en la base, atado a ese identificador.
//   - cuenta     : sesión con correo y contraseña (invitado convertido o
//                  cuenta registrada).
//
// La sesión se persiste en el dispositivo (Supabase Auth), por lo que al
// abrir la app se restaura sin volver a pedir credenciales.

import { computed, ref } from 'vue'

import {
  ensureProfile,
  exchangeAuthCode,
  fetchProfile,
  getCurrentSession,
  markPermanentAccount,
  onAuthStateChange,
  registerAccount,
  requestPasswordRecovery,
  resendConfirmation as resendConfirmationEmail,
  saveAlias,
  signInWithPassword,
  signOutSession,
  startGuestSession,
  updatePassword,
  upgradeGuestToAccount
} from '@/data/authRepository'
import { attachToUser } from '@/composables/useProgress'
import { registerDeepLinkHandler } from '@/lib/deepLink'

const LAST_UID_KEY = 'doulingo-last-uid'

const session = ref(null)
const profile = ref(null)
const status = ref('cargando')
const authError = ref(null)
const notice = ref(null)
const accountChanged = ref(false)
const recoveryMode = ref(false)

let readyPromise = null
let unsubscribe = null

function readLastUid() {
  try {
    return localStorage.getItem(LAST_UID_KEY)
  } catch {
    return null
  }
}

function writeLastUid(uid) {
  try {
    localStorage.setItem(LAST_UID_KEY, uid)
  } catch {
    /* almacenamiento no disponible: el historial queda solo en memoria */
  }
}

const user = computed(() => session.value?.user ?? null)
const isGuest = computed(
  () => !!session.value && session.value.user?.is_anonymous === true
)
const isPermanent = computed(() => !!session.value && !isGuest.value)
const publicName = computed(() => {
  if (!profile.value) return isGuest.value ? 'Invitado' : 'Participante'
  return `${profile.value.alias}#${profile.value.alias_sufijo}`
})
const alias = computed(() => profile.value?.alias ?? '')

function setStatus() {
  if (!session.value) {
    status.value = 'sin-sesion'
  } else if (isGuest.value) {
    status.value = 'invitado'
  } else {
    status.value = 'cuenta'
  }
}

// Se llama en cada cambio de sesión: deja el perfil y el historial listos.
async function applySession(newSession, { checkAccountChange = true } = {}) {
  session.value = newSession
  setStatus()

  if (!newSession) {
    profile.value = null
    attachToUser(null)
    return
  }

  const uid = newSession.user.id
  const previousUid = readLastUid()
  if (checkAccountChange && previousUid && previousUid !== uid) {
    // Se entró con una cuenta distinta a la que se usaba en este
    // dispositivo: los historiales NO se fusionan automáticamente.
    accountChanged.value = true
  }
  writeLastUid(uid)

  try {
    profile.value = await ensureProfile(
      uid,
      newSession.user.user_metadata?.alias,
      { esInvitado: newSession.user.is_anonymous === true }
    )
  } catch {
    profile.value = null
  }
  attachToUser(uid)
}

export function initAuth() {
  if (!readyPromise) {
    readyPromise = (async () => {
      try {
        const current = await getCurrentSession()
        await applySession(current)
      } catch (err) {
        authError.value = err?.message ?? 'No se pudo leer la sesión.'
        status.value = 'sin-sesion'
      }

      unsubscribe = onAuthStateChange((event, newSession) => {
        // El trabajo se posterga: dentro del callback de Auth no se deben
        // encadenar llamadas al cliente (pueden quedar esperando).
        setTimeout(async () => {
          if (event === 'PASSWORD_RECOVERY') {
            recoveryMode.value = true
            notice.value =
              'Acceso recuperado: definí una nueva contraseña para tu cuenta.'
          }
          if (event === 'SIGNED_OUT') {
            await applySession(null)
            return
          }
          await applySession(newSession)
        }, 0)
      })

      // Dentro del APK, el enlace de confirmación o de recuperación abre la
      // app con el esquema propio (doulingo://auth/callback?code=...): se
      // intercepta para completar el intercambio PKCE.
      try {
        await registerDeepLinkHandler(code => completeDeepLink(code))
      } catch {
        /* en la web no hay deep links: se sigue con el flujo normal */
      }
    })()
  }
  return readyPromise
}

// Completa el acceso a partir del código PKCE del deep link del APK.
export async function completeDeepLink(code) {
  authError.value = null
  try {
    await exchangeAuthCode(code)
    const current = await getCurrentSession()
    await applySession(current)
    return { ok: true }
  } catch (err) {
    authError.value = err?.message ?? 'No se pudo completar el acceso.'
    return { ok: false }
  }
}

export function stopAuth() {
  if (unsubscribe) {
    unsubscribe()
    unsubscribe = null
  }
}

async function refreshProfile() {
  const uid = session.value?.user?.id
  if (!uid) return null
  try {
    profile.value = (await fetchProfile(uid)) ?? profile.value
  } catch {
    /* se conserva el perfil en memoria */
  }
  return profile.value
}

export async function startGuest() {
  authError.value = null
  notice.value = null
  try {
    const newSession = await startGuestSession()
    await applySession(newSession)
    return { ok: true }
  } catch (err) {
    authError.value =
      err?.message ?? 'No se pudo iniciar la sesión de invitado.'
    return { ok: false }
  }
}

export async function register({ email, password, alias: newAlias }) {
  authError.value = null
  notice.value = null
  try {
    const { session: newSession } = await registerAccount({
      email,
      password,
      alias: newAlias
    })
    if (newSession) {
      await applySession(newSession)
      notice.value =
        '¡Cuenta creada! Ya podés entrar con tu correo y contraseña.'
      return { ok: true, confirmed: true }
    }
    notice.value =
      'Te enviamos un correo para confirmar la cuenta. ' +
      'Confirmalo y después podés iniciar sesión.'
    return { ok: true, confirmed: false }
  } catch (err) {
    authError.value = err?.message ?? 'No se pudo crear la cuenta.'
    return { ok: false }
  }
}

export async function signIn({ email, password }) {
  authError.value = null
  notice.value = null
  try {
    const newSession = await signInWithPassword({ email, password })
    await applySession(newSession)
    return { ok: true }
  } catch (err) {
    authError.value = err?.message ?? 'No se pudo iniciar sesión.'
    return { ok: false }
  }
}

export async function signOut() {
  authError.value = null
  notice.value = null
  try {
    await signOutSession()
    await applySession(null)
    notice.value =
      'Cerraste sesión. Tu historial de invitado queda guardado en este ' +
      'dispositivo, pero si lo borrás o cambiás de dispositivo no vas a ' +
      'poder recuperarlo.'
    return { ok: true }
  } catch (err) {
    authError.value = err?.message ?? 'No se pudo cerrar la sesión.'
    return { ok: false }
  }
}

export async function requestRecovery(email) {
  authError.value = null
  notice.value = null
  try {
    await requestPasswordRecovery(email)
    notice.value =
      'Si el correo está registrado, te enviamos un enlace para definir una ' +
      'nueva contraseña.'
    return { ok: true }
  } catch (err) {
    authError.value = err?.message ?? 'No se pudo enviar el correo.'
    return { ok: false }
  }
}

export async function resendConfirmation(email) {
  authError.value = null
  notice.value = null
  try {
    await resendConfirmationEmail(email)
    notice.value = 'Reenviamos el correo de confirmación.'
    return { ok: true }
  } catch (err) {
    authError.value = err?.message ?? 'No se pudo reenviar el correo.'
    return { ok: false }
  }
}

export async function setNewPassword(password) {
  authError.value = null
  notice.value = null
  try {
    await updatePassword(password)
    recoveryMode.value = false
    notice.value = '¡Contraseña actualizada!'
    return { ok: true }
  } catch (err) {
    authError.value = err?.message ?? 'No se pudo actualizar la contraseña.'
    return { ok: false }
  }
}

// Conversión de invitado a cuenta permanente: conserva el mismo
// identificador de Auth y, por lo tanto, el mismo historial.
export async function convertToAccount({ email, password }) {
  authError.value = null
  notice.value = null
  try {
    await upgradeGuestToAccount({ email, password })
    await applySession(session.value)
    // El perfil pasa a marcar la cuenta como permanente (si la base tiene
    // la función); si falla, la identidad y el historial siguen intactos.
    try {
      await markPermanentAccount()
      await refreshProfile()
    } catch {
      /* la función puede no estar aplicada todavía */
    }
    notice.value =
      '¡Listo! Tu cuenta ahora es permanente: conservás tu alias, tu ' +
      'historial y tu identificador.'
    return { ok: true }
  } catch (err) {
    authError.value = err?.message ?? 'No se pudo convertir la cuenta.'
    return { ok: false }
  }
}

export async function changeAlias(newAlias) {
  authError.value = null
  notice.value = null
  const uid = session.value?.user?.id
  if (!uid) {
    authError.value = 'Necesitás una sesión para cambiar el alias.'
    return { ok: false }
  }
  try {
    profile.value = await saveAlias(uid, newAlias)
    notice.value = 'Alias actualizado.'
    return { ok: true }
  } catch (err) {
    authError.value = err?.message ?? 'No se pudo guardar el alias.'
    return { ok: false }
  }
}

export function dismissAccountChanged() {
  accountChanged.value = false
}

export function clearMessages() {
  authError.value = null
  notice.value = null
}

export function useAuth() {
  return {
    session,
    user,
    profile,
    status,
    authError,
    notice,
    accountChanged,
    recoveryMode,
    isGuest,
    isPermanent,
    publicName,
    alias,
    initAuth,
    stopAuth,
    completeDeepLink,
    refreshProfile,
    startGuest,
    register,
    signIn,
    signOut,
    requestRecovery,
    resendConfirmation,
    setNewPassword,
    convertToAccount,
    changeAlias,
    dismissAccountChanged,
    clearMessages
  }
}
