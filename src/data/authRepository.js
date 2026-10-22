// Acceso y sesión: todas las operaciones de Supabase Auth y de los datos
// asociados al participante (perfil y progreso).
//
// El identificador del participante es el id de Supabase Auth. Las
// contraseñas solo existen en Supabase Auth: en esta base no se guarda
// ninguna. La clave que usa la aplicación es pública (anon/publishable) y
// por eso todas las consultas de datos personales pasan por RLS.

import { getSupabaseClient } from '@/lib/supabase'
import { isNativeApp } from '@/lib/deepLink'

const ALIAS_MIN = 3
const ALIAS_MAX = 20

// ---------- Utilidades ----------

function authErrorMessage(err, fallback) {
  const raw = `${err?.message ?? ''} ${err?.code ?? ''}`.toLowerCase()

  if (raw.includes('anonymous sign-ins are disabled')) {
    return (
      'El acceso como invitado no está habilitado en el proyecto. ' +
      'Activalo en Supabase → Authentication → Providers → Anonymous Sign Ins.'
    )
  }
  if (
    raw.includes('user already registered') ||
    raw.includes('already registered') ||
    raw.includes('email_exists')
  ) {
    return 'Ese correo ya tiene una cuenta. Iniciá sesión o recuperá tu acceso.'
  }
  // Supabase oculta si el correo ya existe (ofuscado de correo): el alta de
  // un correo repetido responde como si el correo fuera inválido.
  if (raw.includes('email_address_invalid') || raw.includes('is invalid')) {
    return (
      'Ese correo no es válido o ya tiene una cuenta. ' +
      'Si ya te registraste, iniciá sesión o recuperá tu acceso.'
    )
  }
  if (raw.includes('invalid login credentials')) {
    return 'Correo o contraseña incorrectos.'
  }
  if (raw.includes('email not confirmed')) {
    return 'Confirmá tu correo antes de iniciar sesión.'
  }
  if (
    raw.includes('signups not allowed') ||
    raw.includes('signup is disabled')
  ) {
    return 'El registro está deshabilitado en el proyecto de Supabase.'
  }
  if (
    raw.includes('over_email_send_rate_limit') ||
    raw.includes('email rate limit')
  ) {
    return (
      'El proyecto alcanzó el límite de correos por hora que puede enviar. ' +
      'Probá de nuevo en un rato.'
    )
  }
  if (raw.includes('rate limit') || raw.includes('too many')) {
    return 'Demasiados intentos seguidos. Probá de nuevo en unos instantes.'
  }
  if (
    raw.includes('fetch') ||
    raw.includes('network') ||
    raw.includes('failed to')
  ) {
    return 'No se pudo contactar al servidor. Revisá tu conexión.'
  }
  // El enlace se abre en otro dispositivo o el código ya venció: con PKCE
  // el verificador queda en el dispositivo donde se pidió el correo.
  if (
    raw.includes('pkce') ||
    raw.includes('code verifier') ||
    raw.includes('invalid code') ||
    raw.includes('otp_expired') ||
    raw.includes('access_denied')
  ) {
    return (
      'El enlace de acceso no sirve o ya venció. ' +
      'Pedí un correo nuevo y abrilo en este mismo dispositivo.'
    )
  }
  if (raw.includes('perfiles_pkey')) {
    return 'Ese perfil ya existe.'
  }
  if (raw.includes('duplicate key') || raw.includes('unique constraint')) {
    return 'Ese alias ya está en uso con ese sufijo. Probá con otro alias.'
  }
  // Cualquier otro error desconocido no se muestra crudo: se devuelve el
  // mensaje genérico en español de cada operación.
  const mensaje = err?.message ?? ''
  if (mensaje.length > 120 || /\bhttps?:\/\//.test(mensaje)) {
    return fallback
  }
  return mensaje || fallback
}

// Normaliza el alias: minúsculas, solo letras/dígitos/guion bajo, 3-20.
export function normalizeAlias(alias) {
  const cleaned = (alias ?? '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_]+/g, '_')
    .replace(/^_+|_+$/g, '')
  if (cleaned.length < ALIAS_MIN) return ''
  return cleaned.slice(0, ALIAS_MAX)
}

export function validateAlias(alias) {
  const normalized = normalizeAlias(alias)
  if (!normalized) {
    return `El alias debe tener al menos ${ALIAS_MIN} caracteres.`
  }
  if (normalized.length > ALIAS_MAX) {
    return `El alias puede tener hasta ${ALIAS_MAX} caracteres.`
  }
  return null
}

// URL a la que Supabase devuelve al usuario tras confirmar el correo o
// recuperar la contraseña. En web es el origen de la app; en el APK se
// devuelve con el esquema propio de la app (doulingo://auth/callback), que
// además debe estar declarado en Supabase → Authentication → URL
// Configuration → Redirect URLs.
export function authRedirectUrl() {
  if (isNativeApp()) {
    return (
      import.meta.env.VITE_SUPABASE_NATIVE_REDIRECT_URL ??
      'doulingo://auth/callback'
    )
  }
  const configured = import.meta.env.VITE_SUPABASE_REDIRECT_URL
  if (configured) return configured
  return `${window.location.origin}/`
}

// ---------- Sesión ----------

export async function getCurrentSession() {
  const { data, error } = await getSupabaseClient().auth.getSession()
  if (error)
    throw new Error(authErrorMessage(error, 'No se pudo leer la sesión.'))
  return data.session ?? null
}

export function onAuthStateChange(callback) {
  const { data } = getSupabaseClient().auth.onAuthStateChange(
    (event, session) => {
      callback(event, session)
    }
  )
  return () => data.subscription.unsubscribe()
}

// Invitado: crea una sesión anónima autenticada PROPIA de este dispositivo.
// Nunca se comparte una cuenta entre personas.
export async function startGuestSession() {
  const { data, error } = await getSupabaseClient().auth.signInAnonymously()
  if (error)
    throw new Error(
      authErrorMessage(error, 'No se pudo iniciar la sesión de invitado.')
    )
  return data.session
}

export async function registerAccount({ email, password, alias }) {
  const cleanAlias = normalizeAlias(alias)
  const { data, error } = await getSupabaseClient().auth.signUp({
    email: email.trim(),
    password,
    options: {
      data: { alias: cleanAlias },
      emailRedirectTo: authRedirectUrl()
    }
  })
  if (error)
    throw new Error(authErrorMessage(error, 'No se pudo crear la cuenta.'))
  // Con confirmación de correo activa, `session` viene en null: la cuenta
  // existe pero hay que confirmar el correo antes de entrar.
  return { session: data.session ?? null, user: data.user ?? null }
}

export async function signInWithPassword({ email, password }) {
  const { data, error } = await getSupabaseClient().auth.signInWithPassword({
    email: email.trim(),
    password
  })
  if (error)
    throw new Error(authErrorMessage(error, 'No se pudo iniciar sesión.'))
  return data.session
}

export async function signOutSession() {
  const { error } = await getSupabaseClient().auth.signOut()
  if (error)
    throw new Error(authErrorMessage(error, 'No se pudo cerrar la sesión.'))
}

export async function requestPasswordRecovery(email) {
  const { error } = await getSupabaseClient().auth.resetPasswordForEmail(
    email.trim(),
    { redirectTo: authRedirectUrl() }
  )
  if (error)
    throw new Error(authErrorMessage(error, 'No se pudo enviar el correo.'))
}

export async function resendConfirmation(email) {
  const { error } = await getSupabaseClient().auth.resend({
    type: 'signup',
    email: email.trim(),
    options: { emailRedirectTo: authRedirectUrl() }
  })
  if (error)
    throw new Error(authErrorMessage(error, 'No se pudo reenviar el correo.'))
}

export async function updatePassword(password) {
  const { error } = await getSupabaseClient().auth.updateUser({ password })
  if (error)
    throw new Error(
      authErrorMessage(error, 'No se pudo actualizar la contraseña.')
    )
}

// Completa el intercambio del código PKCE que llega en el enlace de
// confirmación de correo o de recuperación de contraseña. En el APK ese
// enlace llega como deep link (doulingo://auth/callback?code=...).
export async function exchangeAuthCode(code) {
  const { error } = await getSupabaseClient().auth.exchangeCodeForSession(code)
  if (error)
    throw new Error(
      authErrorMessage(error, 'No se pudo completar el acceso con el enlace.')
    )
}

// Conversión de invitado a cuenta permanente: se completa la MISMA sesión
// (mismo id de Auth) con correo y contraseña. No se crea otra cuenta ni se
// copian resultados desde el cliente: la identidad y el historial se
// conservan porque siguen atados al mismo id.
export async function upgradeGuestToAccount({ email, password }) {
  const { data, error } = await getSupabaseClient().auth.updateUser({
    email: email.trim(),
    password
  })
  if (error)
    throw new Error(authErrorMessage(error, 'No se pudo convertir la cuenta.'))
  return data.user ?? null
}

// ---------- Perfil ----------

export async function fetchProfile(uid) {
  const { data, error } = await getSupabaseClient()
    .from('perfiles')
    .select('id, alias, alias_sufijo, es_invitado, creado_en')
    .eq('id', uid)
    .maybeSingle()
  if (error)
    throw new Error(authErrorMessage(error, 'No se pudo leer el perfil.'))
  return data ?? null
}

// El perfil puede no existir todavía (por ejemplo, si el trigger de la base
// no está aplicado): el propio participante se lo crea con su alias.
export async function ensureProfile(uid, alias, { esInvitado = true } = {}) {
  const existente = await fetchProfile(uid)
  if (existente) return existente
  const cleanAlias = normalizeAlias(alias) || 'invitado'
  const hex = uid.replace(/-/g, '')
  // El sufijo son 4 caracteres del identificador. Si la combinación
  // alias+sufijo ya está tomada por otra persona, se prueban las ventanas
  // siguientes del identificador: el alias repetido nunca bloquea el alta.
  for (let offset = 0; offset <= 28; offset++) {
    const sufijo = hex.slice(offset, offset + 4)
    const { data, error } = await getSupabaseClient()
      .from('perfiles')
      .insert({
        id: uid,
        alias: cleanAlias,
        alias_sufijo: sufijo,
        es_invitado: esInvitado
      })
      .select('id, alias, alias_sufijo, es_invitado, creado_en')
      .maybeSingle()
    if (!error) return data
    // Si el conflicto es el identificador, el perfil ya existía: no hay que
    // seguir probando ventanas.
    const detalle = `${error.message ?? ''} ${error.details ?? ''}`
    if (detalle.includes('(id)') || detalle.includes('perfiles_pkey')) break
  }
  // Si otro proceso lo creó primero, se vuelve a leer.
  return fetchProfile(uid)
}

export async function saveAlias(uid, alias) {
  const cleanAlias = normalizeAlias(alias)
  const { data, error } = await getSupabaseClient()
    .from('perfiles')
    .update({ alias: cleanAlias, actualizado_en: new Date().toISOString() })
    .eq('id', uid)
    .select('id, alias, alias_sufijo, es_invitado, creado_en')
    .maybeSingle()
  if (error)
    throw new Error(authErrorMessage(error, 'No se pudo guardar el alias.'))
  return data ?? null
}

// ---------- Progreso del participante ----------

export async function fetchProgress(uid) {
  const { data, error } = await getSupabaseClient()
    .from('participant_progress')
    .select('leccion_id, estado, intentos, mejor_aciertos, total_actividades')
    .eq('id', uid)
  if (error)
    throw new Error(authErrorMessage(error, 'No se pudo leer el progreso.'))
  return data ?? []
}

// El progreso se escribe ÚNICAMENTE desde la función finalizar_intento() del
// servidor, con las respuestas guardadas. El cliente solo lo lee y lo borra.

// Borra el historial del participante en la base (solo sus filas: la RLS
// solo permite borrar lo propio).
export async function clearServerProgress(uid) {
  const { error } = await getSupabaseClient()
    .from('participant_progress')
    .delete()
    .eq('id', uid)
  if (error)
    throw new Error(authErrorMessage(error, 'No se pudo borrar el progreso.'))
}

// Marca el perfil como cuenta permanente (fin de la etapa de invitado).
export async function markPermanentAccount() {
  const { error } = await getSupabaseClient().rpc('marcar_cuenta_permanente')
  if (error) {
    throw new Error(authErrorMessage(error, 'No se pudo actualizar el perfil.'))
  }
}
