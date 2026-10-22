// Pruebas de la etapa de autenticación (Supabase Auth).
//
//   node tests/e2e/auth.mjs        -> fase A (API de Supabase Auth)
//   node tests/e2e/auth.mjs ui     -> además, fase B (recorrido en la app)
//
// Requisitos del proyecto (panel de Supabase):
//   - Authentication → Providers → Anonymous Sign Ins: habilitado.
//   - SQL de supabase/migrations/0004_auth.sql aplicado.

import {
  BASE_URL,
  createRunner,
  createSupabaseClient,
  launchBrowser,
  sleep,
  SUPABASE_KEY,
  SUPABASE_URL
} from './helpers.mjs'

const RUN_UI = process.argv.includes('ui')
const runner = createRunner('=== FASE A · API de Supabase Auth ===')

function newClient() {
  return createSupabaseClient()
}

const mail = `usagi.${Math.random().toString(36).slice(2, 10)}@maxxspace.com`
const PASSWORD = 'Usagi-2026!segura'

// --- A1: alta de invitado anónimo (sesión propia por dispositivo) ---
const guestA = await newClient()
const { data: guestAData, error: guestAError } =
  await guestA.auth.signInAnonymously()
if (guestAError) {
  runner.check(
    'A1 Invitado anónimo puede crear su sesión',
    false,
    guestAError.message
  )
  console.log('   -> Habilitá "Anonymous Sign Ins" en el panel de Supabase.')
} else {
  runner.check('A1 Invitado anónimo puede crear su sesión', true)
  runner.check(
    'A1 La sesión anónima es propia (is_anonymous)',
    guestAData.user?.is_anonymous === true
  )
  runner.check(
    'A1 La sesión trae un identificador propio',
    !!guestAData.user?.id
  )
}

// --- A2: dos invitados distintos ---
const guestB = await newClient()
const { data: guestBData, error: guestBError } =
  await guestB.auth.signInAnonymously()
if (!guestBError) {
  runner.check(
    'A2 Dos invitados tienen identificadores distintos',
    guestAData?.user?.id !== guestBData?.user?.id,
    `${guestAData?.user?.id?.slice(0, 8)} vs ${guestBData?.user?.id?.slice(0, 8)}`
  )
} else {
  runner.check(
    'A2 Dos invitados tienen identificadores distintos',
    false,
    guestBError.message
  )
}

// --- A3: el alta anónima repetida no reutiliza la cuenta ajena ---
const guestC = await newClient()
const { data: guestCData } = await guestC.auth.signInAnonymously()
if (!guestBError) {
  runner.check(
    'A3 Cada alta anónima crea una identidad nueva (no hay cuenta compartida)',
    guestCData?.user?.id !== guestBData?.user?.id
  )
}

// --- A4: alta con correo (la cuenta se crea; la confirmación la decide el panel) ---
const signup = await fetch(`${SUPABASE_URL}/auth/v1/signup`, {
  method: 'POST',
  headers: { apikey: SUPABASE_KEY, 'content-type': 'application/json' },
  body: JSON.stringify({
    email: mail,
    password: PASSWORD,
    data: { alias: 'usagi' }
  })
})
const signupBody = await signup.json()
// El proyecto tiene un cupo de correos por hora: si está agotado, los casos
// que necesitan enviar correo se omiten (no son un error del código). El cupo
// puede agotarse a mitad de la corrida, así que se revisa en cada respuesta.
function cupoAgotado(respuesta, cuerpo) {
  return (
    respuesta.status === 429 ||
    String(cuerpo?.error_code ?? '').includes('over_email_send_rate_limit')
  )
}
const MOTIVO_CORREO = 'el proyecto agotó el cupo de correos por hora'
const CORREO_LIMITADO = cupoAgotado(signup, signupBody)
if (CORREO_LIMITADO) {
  runner.skip('A4 Registro: la cuenta se crea', MOTIVO_CORREO)
  runner.skip(
    'A4 Registro: con confirmación activa no hay sesión todavía',
    MOTIVO_CORREO
  )
  runner.skip('A4 Registro: correo ya utilizado -> aviso claro', MOTIVO_CORREO)
} else {
  runner.check(
    'A4 Registro: la cuenta se crea',
    signup.status === 200,
    `http ${signup.status}`
  )
  runner.check(
    'A4 Registro: con confirmación activa no hay sesión todavía',
    signupBody.session === undefined || signupBody.session === null,
    JSON.stringify({ id: signupBody.id ?? signupBody.user?.id })
  )
}

if (!CORREO_LIMITADO) {
  await sleep(61000) // el límite de envío de correo es de 1 minuto por dirección
  const duplicate = await fetch(`${SUPABASE_URL}/auth/v1/signup`, {
    method: 'POST',
    headers: { apikey: SUPABASE_KEY, 'content-type': 'application/json' },
    body: JSON.stringify({
      email: mail,
      password: PASSWORD,
      data: { alias: 'usagi' }
    })
  })
  const duplicateBody = await duplicate.json()
  if (cupoAgotado(duplicate, duplicateBody)) {
    runner.skip(
      'A4 Registro: correo ya utilizado -> aviso claro',
      MOTIVO_CORREO
    )
  } else {
    // Con el ofuscado de correo de Supabase (activo por defecto) un alta
    // repetida responde "email_address_invalid" en lugar de "email_exists":
    // las dos respuestas son válidas y la app las traduce a un aviso claro.
    runner.check(
      'A4 Registro: correo ya utilizado -> aviso claro',
      /already registered|already been registered|registered|email_address_invalid/i.test(
        JSON.stringify(duplicateBody)
      ),
      JSON.stringify(duplicateBody).slice(0, 140)
    )
  }
}

// --- A5: contraseña inválida ---
const badLogin = await fetch(
  `${SUPABASE_URL}/auth/v1/token?grant_type=password`,
  {
    method: 'POST',
    headers: { apikey: SUPABASE_KEY, 'content-type': 'application/json' },
    body: JSON.stringify({ email: mail, password: 'clave-incorrecta' })
  }
)
const badLoginBody = await badLogin.json()
runner.check(
  'A5 Login: contraseña inválida -> aviso claro',
  badLogin.status >= 400 &&
    /invalid login credentials/i.test(JSON.stringify(badLoginBody)),
  JSON.stringify(badLoginBody).slice(0, 140)
)

// --- A6: recuperación de acceso ---
if (CORREO_LIMITADO) {
  runner.skip('A6 Recuperación: la solicitud se acepta', MOTIVO_CORREO)
} else {
  const recover = await fetch(
    `${SUPABASE_URL}/auth/v1/recover?redirect_to=${encodeURIComponent('http://localhost:9100/')}`,
    {
      method: 'POST',
      headers: { apikey: SUPABASE_KEY, 'content-type': 'application/json' },
      body: JSON.stringify({ email: mail })
    }
  )
  const recoverBody = await recover.json().catch(() => ({}))
  if (cupoAgotado(recover, recoverBody)) {
    runner.skip('A6 Recuperación: la solicitud se acepta', MOTIVO_CORREO)
  } else {
    runner.check(
      'A6 Recuperación: la solicitud se acepta',
      recover.status === 200,
      `http ${recover.status}`
    )
  }
}

// --- A7: RLS · aislamiento de los datos de cada participante ---
const uidA = guestAData?.user?.id
const uidB = guestBData?.user?.id
if (uidA && uidB) {
  const LESSON = '20000000-0000-0000-0000-200000000001'
  const insert = await guestB.from('participant_progress').insert({
    id: uidB,
    leccion_id: LESSON,
    estado: 'aprobada',
    intentos: 1,
    mejor_aciertos: 3,
    total_actividades: 3
  })
  runner.check(
    'A7 El invitado puede guardar su propio progreso',
    !insert.error,
    insert.error?.message
  )

  const own = await guestB
    .from('participant_progress')
    .select('leccion_id')
    .eq('id', uidB)
  runner.check(
    'A7 El invitado lee su propio progreso',
    own.data?.length === 1,
    JSON.stringify(own.data)
  )

  const other = await guestA
    .from('participant_progress')
    .select('leccion_id')
    .eq('id', uidB)
  runner.check(
    'A7 RLS: el invitado NO lee el progreso de otro',
    other.data?.length === 0,
    JSON.stringify(other.data)
  )

  const foreignInsert = await guestA.from('participant_progress').insert({
    id: uidB,
    leccion_id: LESSON,
    estado: 'aprobada'
  })
  runner.check(
    'A7 RLS: no puede escribir en el progreso de otro',
    !!foreignInsert.error,
    foreignInsert.error?.message
  )

  // Con `select` PostgREST devuelve las filas que la RLS dejó pasar:
  // si la política bloquea la actualización, la lista llega vacía.
  const foreignUpdate = await guestA
    .from('participant_progress')
    .update({ estado: 'intentada' })
    .eq('id', uidB)
    .select('estado')
  runner.check(
    'A7 RLS: no puede modificar el progreso de otro',
    !foreignUpdate.error && (foreignUpdate.data?.length ?? 0) === 0,
    `error=${foreignUpdate.error?.message ?? 'ninguno'} data=${JSON.stringify(foreignUpdate.data)}`
  )

  const profileB = await guestB
    .from('perfiles')
    .select('alias, alias_sufijo')
    .eq('id', uidB)
    .maybeSingle()
  runner.check(
    'A7 El perfil propio existe con alias y sufijo',
    !!profileB?.data?.alias,
    JSON.stringify(profileB.data)
  )
  const aliasHijack = await guestA
    .from('perfiles')
    .update({ alias: 'secuestrado' })
    .eq('id', uidB)
    .select()
  runner.check(
    'A7 RLS: no puede cambiar el alias de otro',
    aliasHijack.data?.length === 0,
    JSON.stringify(aliasHijack.data)
  )
  const publicAlias = await guestA
    .from('perfiles')
    .select('alias')
    .eq('id', uidB)
    .maybeSingle()
  runner.check(
    'A7 El alias de otro es visible (es público)',
    !!publicAlias?.data?.alias,
    JSON.stringify(publicAlias.data)
  )

  // Conversión de invitado a cuenta permanente: mismo identificador.
  const before = guestBData.user.id
  const conversion = await guestB.auth.updateUser({
    email: `conv.${Math.random().toString(36).slice(2, 8)}@maxxspace.com`,
    password: PASSWORD
  })
  const CONVERSION_LIMITADA =
    !!conversion.error &&
    String(conversion.error.message ?? '').includes('rate limit')
  if (CONVERSION_LIMITADA) {
    runner.skip('A8 Conversión: la cuenta invitada se convierte', MOTIVO_CORREO)
    runner.skip('A8 Conversión: conserva el MISMO identificador', MOTIVO_CORREO)
    runner.skip('A8 Conversión: deja de ser anonymous', MOTIVO_CORREO)
  } else {
    runner.check(
      'A8 Conversión: la cuenta invitada se convierte',
      !conversion.error,
      conversion.error?.message
    )
    runner.check(
      'A8 Conversión: conserva el MISMO identificador',
      conversion.data?.user?.id === before,
      `${before?.slice(0, 8)} -> ${conversion.data?.user?.id?.slice(0, 8)}`
    )
    runner.check(
      'A8 Conversión: deja de ser anonymous',
      conversion.data?.user?.is_anonymous === false,
      String(conversion.data?.user?.is_anonymous)
    )
  }
  const history = await guestB
    .from('participant_progress')
    .select('leccion_id')
    .eq('id', uidB)
  runner.check(
    'A8 Conversión: conserva el historial',
    history.data?.length === 1,
    JSON.stringify(history.data)
  )
} else {
  runner.check(
    'A7 RLS: aislamiento de datos por participante',
    false,
    'faltan sesiones de invitado'
  )
}

if (RUN_UI) {
  console.log('\n=== FASE B · Recorrido en la aplicación ===')
  const browser = await launchBrowser()
  try {
    const context = await browser.createBrowserContext()
    const page = await context.newPage()
    const pageErrors = []
    page.on('pageerror', error => pageErrors.push(String(error)))

    // B1: ruta protegida sin sesión -> redirige al acceso.
    await page.goto(`${BASE_URL}/#/perfil`, { waitUntil: 'networkidle0' })
    await sleep(1500)
    const hash = await page.evaluate(() => location.hash)
    runner.check(
      'B1 Ruta protegida sin sesión redirige a /acceso',
      hash.includes('/acceso'),
      hash
    )

    // B2: acceso como invitado.
    await page.goto(`${BASE_URL}/#/acceso`, { waitUntil: 'networkidle0' })
    await sleep(800)
    const clicked = await page.evaluate(() => {
      const button = [...document.querySelectorAll('button')].find(candidate =>
        candidate.innerText.includes('INVITADO')
      )
      if (!button) return false
      button.click()
      return true
    })
    runner.check('B2 Se ofrece el acceso como invitado', clicked)
    await sleep(2500)
    const body = await page.evaluate(() =>
      document.body.innerText.replace(/\s+/g, ' ')
    )
    const guestBlocked = /no está habilitado|Anonymous/i.test(body)
    runner.check(
      'B2 El invitado obtiene sesión (o explica que está deshabilitado)',
      !guestBlocked,
      body.slice(0, 160)
    )

    if (!guestBlocked) {
      await page.goto(`${BASE_URL}/#/perfil`, { waitUntil: 'networkidle0' })
      await sleep(1500)
      const profile = await page.evaluate(() =>
        document.body.innerText.replace(/\s+/g, ' ')
      )
      runner.check(
        'B3 La página de perfil muestra el nombre público alias#sufijo',
        /[a-z0-9_]+#[0-9a-f]{4}/i.test(profile),
        profile.slice(0, 160)
      )

      // B4: la sesión se restaura al reabrir la app.
      const before = await page.evaluate(
        () => document.body.innerText.match(/[a-z0-9_]+#[0-9a-f]{4}/i)?.[0]
      )
      await page.reload({ waitUntil: 'networkidle0' })
      await sleep(1800)
      const after = await page.evaluate(
        () => document.body.innerText.match(/[a-z0-9_]+#[0-9a-f]{4}/i)?.[0]
      )
      runner.check(
        'B4 Al reabrir la app se restaura la sesión',
        !!before && before === after,
        `${before} -> ${after}`
      )

      // B5: cerrar sesión.
      await page.evaluate(() => {
        const button = [...document.querySelectorAll('button')].find(
          candidate => candidate.innerText.includes('CERRAR SESIÓN')
        )
        button?.click()
      })
      await sleep(2000)
      const hashAfter = await page.evaluate(() => location.hash)
      runner.check(
        'B5 Cerrar sesión vuelve al acceso',
        hashAfter.includes('/acceso'),
        hashAfter
      )
    }

    runner.check(
      'B6 Sin errores de página en el flujo de acceso',
      pageErrors.length === 0,
      pageErrors.join(' | ')
    )
  } catch (error) {
    runner.check('B Fase B sin excepciones', false, error.message)
  }
  await browser.close()
}

process.exit(runner.summary('AUTH') ? 1 : 0)
