// Verificaciones puntuales de la etapa 4 sobre el proyecto real:
//   1. RLS: un invitado no puede modificar el progreso de otro (y la fila queda igual).
//   2. Conversión a cuenta permanente sin depender del envío de correos:
//      updateUser({ password }) mantiene el mismo identificador y deja de ser
//      anónimo, y el perfil se marca como permanente.
//   3. Estado del cupo de envío de correos del proyecto.

import { createSupabaseClient, rpc } from './helpers.mjs'

const results = []
const check = (name, cond, extra = '') => {
  results.push(!!cond)
  console.log(
    `${cond ? 'PASS' : 'FAIL'}  ${name}${extra ? ' :: ' + extra : ''}`
  )
}

const guestA = await createSupabaseClient()
const guestB = await createSupabaseClient()
const a = await guestA.auth.signInAnonymously()
const b = await guestB.auth.signInAnonymously()
if (a.error || b.error) {
  console.log(
    'No se pudieron crear las sesiones de invitado:',
    a.error ?? b.error
  )
  process.exit(1)
}
const uidB = b.data.user.id
const LESSON = '20000000-0000-0000-0000-200000000001'

// --- 1. RLS sobre el progreso ajeno ---
const insert = await guestB.from('participant_progress').insert({
  id: uidB,
  leccion_id: LESSON,
  estado: 'aprobada',
  intentos: 1,
  mejor_aciertos: 3,
  total_actividades: 3
})
check(
  'El invitado guarda su propio progreso',
  !insert.error,
  insert.error?.message
)

const before = await guestB
  .from('participant_progress')
  .select('estado, mejor_aciertos')
  .eq('id', uidB)
  .maybeSingle()
check(
  'El progreso propio sigue siendo "aprobada"',
  before.data?.estado === 'aprobada'
)

const update = await guestA
  .from('participant_progress')
  .update({ estado: 'intentada' })
  .eq('id', uidB)
  .select('estado')
check(
  'RLS: el invitado NO lee filas ajenas al actualizar (0 filas)',
  !update.error && (update.data?.length ?? 0) === 0,
  `error=${update.error?.message ?? 'ninguno'} data=${JSON.stringify(update.data)}`
)

const after = await guestB
  .from('participant_progress')
  .select('estado, mejor_aciertos')
  .eq('id', uidB)
  .maybeSingle()
check(
  'RLS: la fila del otro participante quedó intacta',
  after.data?.estado === 'aprobada' && after.data?.mejor_aciertos === 3,
  JSON.stringify(after.data)
)

const insertForeign = await guestA.from('participant_progress').insert({
  id: uidB,
  leccion_id: LESSON,
  estado: 'aprobada'
})
check(
  'RLS: no puede escribir en el progreso de otro',
  !!insertForeign.error,
  insertForeign.error?.message
)

// --- 2. Conversión a cuenta permanente (sin correo: solo contraseña) ---
const profileBefore = await guestB
  .from('perfiles')
  .select('alias, alias_sufijo, es_invitado')
  .eq('id', uidB)
  .maybeSingle()
check(
  'El trigger creó el perfil con alias y sufijo',
  !!profileBefore.data?.alias && !!profileBefore.data?.alias_sufijo,
  JSON.stringify(profileBefore.data)
)
check(
  'El perfil empieza como invitado',
  profileBefore.data?.es_invitado === true
)

const conversion = await guestB.auth.updateUser({
  password: 'Usagi-2026!segura'
})
check(
  'Conversión: la cuenta invitada se convierte',
  !conversion.error,
  conversion.error?.message
)
check(
  'Conversión: conserva el MISMO identificador',
  conversion.data?.user?.id === uidB,
  `${uidB.slice(0, 8)} -> ${conversion.data?.user?.id?.slice(0, 8)}`
)
check(
  'Conversión: deja de ser anonymous',
  conversion.data?.user?.is_anonymous === false,
  String(conversion.data?.user?.is_anonymous)
)

const mark = await rpc('marcar_cuenta_permanente')
check(
  'La función marcar_cuenta_permanente responde sin error',
  !mark.error,
  `http=${mark.status} ${mark.error?.message ?? ''}`
)

const profileAfter = await guestB
  .from('perfiles')
  .select('alias, alias_sufijo, es_invitado')
  .eq('id', uidB)
  .maybeSingle()
check(
  'El perfil queda como cuenta permanente (mismo id y alias)',
  profileAfter.data?.es_invitado === false &&
    profileAfter.data?.alias === profileBefore.data?.alias,
  JSON.stringify(profileAfter.data)
)

const history = await guestB
  .from('participant_progress')
  .select('leccion_id, estado')
  .eq('id', uidB)
check(
  'Conversión: conserva el historial',
  history.data?.length === 1,
  JSON.stringify(history.data)
)

// --- 3. Cupo de envío de correos del proyecto ---
const signup = await fetch(
  `${(await import('./helpers.mjs')).SUPABASE_URL}/auth/v1/signup`,
  {
    method: 'POST',
    headers: {
      apikey: (await import('./helpers.mjs')).SUPABASE_KEY,
      'content-type': 'application/json'
    },
    body: JSON.stringify({
      email: `cupo.${Math.random().toString(36).slice(2, 8)}@maxxspace.com`,
      password: 'Usagi-2026!segura',
      data: { alias: 'cupo' }
    })
  }
)
const signupBody = await signup.json()
check(
  'Alta con correo (envía confirmación) o límite de envío del proyecto',
  signup.status === 200 ||
    signupBody.error_code === 'over_email_send_rate_limit',
  `http=${signup.status} ${JSON.stringify(signupBody).slice(0, 120)}`
)

const failed = results.filter(result => !result).length
console.log(
  `\nRESUMEN VERIFICACIÓN: ${results.length - failed}/${results.length} OK`
)
process.exit(failed ? 1 : 0)
