// Pruebas del alias público y del sufijo que distingue participantes.
//
// El alias es elegido por la persona (3-20 caracteres: minúsculas, dígitos y
// guion bajo). Para que dos participantes con el mismo alias se distingan,
// cada perfil lleva además un sufijo de 4 caracteres hexadecimales derivado
// del identificador de Auth. La combinación alias+sufijo es única en la base.
//
// Estas pruebas se ejecutan contra el proyecto Supabase real: comprueban que
// la unicidad está activa, que el perfil ajeno es visible pero no editable y
// que un choque de alias+sufijo se distingue de un conflicto de
// identificador (que es el caso normal cuando el perfil ya existe).

import {
  createRunner,
  createSupabaseClient,
  SUPABASE_KEY,
  SUPABASE_URL
} from './helpers.mjs'

const runner = createRunner('=== ALIAS Y SUFIJO · perfiles públicos ===')

async function nuevoInvitado() {
  const client = await createSupabaseClient()
  const { data, error } = await client.auth.signInAnonymously()
  if (error) throw new Error(error.message)
  return { client, session: data.session, uid: data.user.id }
}

function perfilDe(client, uid) {
  return client
    .from('perfiles')
    .select('id, alias, alias_sufijo, es_invitado')
    .eq('id', uid)
    .maybeSingle()
    .then(({ data }) => data)
}

try {
  // --- Invitado con perfil ---
  const a = await nuevoInvitado()
  const perfilA = await perfilDe(a.client, a.uid)
  runner.check(
    'A1 El invitado tiene perfil con alias y sufijo',
    !!perfilA &&
      typeof perfilA.alias === 'string' &&
      /^[0-9a-f]{4}$/.test(perfilA.alias_sufijo ?? ''),
    JSON.stringify(perfilA)
  )
  runner.check(
    'A2 El alias cumple las reglas (3-20, minúsculas, dígitos, guion bajo)',
    !!perfilA && /^[a-z0-9_]{3,20}$/.test(perfilA.alias),
    perfilA?.alias
  )
  runner.check(
    'A3 El invitado arranca marcado como invitado',
    perfilA?.es_invitado === true
  )

  // --- Tres invitados: alias base igual, sufijos distintos ---
  const b = await nuevoInvitado()
  const c = await nuevoInvitado()
  const [perfilB, perfilC] = await Promise.all([
    perfilDe(b.client, b.uid),
    perfilDe(c.client, c.uid)
  ])
  const nombres = [perfilA, perfilB, perfilC]
    .filter(Boolean)
    .map(p => `${p.alias}#${p.alias_sufijo}`)
  runner.check(
    'A4 Tres invitados se distinguen (alias#sufijo distintos)',
    new Set(nombres).size === nombres.length && nombres.length === 3,
    nombres.join(' | ')
  )
  runner.check(
    'A5 Cada invitado tiene su propio identificador',
    new Set([a.uid, b.uid, c.uid]).size === 3
  )

  // --- El perfil ajeno es visible (público) pero no editable ---
  const visto = await a.client
    .from('perfiles')
    .select('id, alias, alias_sufijo')
    .eq('id', b.uid)
    .maybeSingle()
  runner.check(
    'A6 El alias de otra persona es visible (es público)',
    !!visto.data && visto.data.alias_sufijo === perfilB?.alias_sufijo,
    JSON.stringify(visto.data ?? visto.error?.message)
  )

  const intruso = await c.client
    .from('perfiles')
    .update({ alias: 'secuestrado' })
    .eq('id', a.uid)
    .select('id, alias')
  runner.check(
    'A7 Nadie puede cambiar el alias de otra persona (RLS)',
    !intruso.error && (intruso.data ?? []).length === 0,
    intruso.error?.message ?? JSON.stringify(intruso.data)
  )

  // --- Insertar con el identificador propio cuando el perfil ya existe ---
  const propio = await b.client
    .from('perfiles')
    .insert({
      id: b.uid,
      alias: perfilB.alias,
      alias_sufijo: 'ffff'
    })
    .select('id, alias, alias_sufijo')
  runner.check(
    'A8 Insertar de nuevo el propio perfil choca por el identificador',
    !!propio.error && propio.error.code === '23505',
    `${propio.error?.code ?? 'sin error'} ${propio.error?.message ?? ''}`
  )
  runner.check(
    'A9 El error dice que es la clave primaria (perfiles_pkey)',
    String(propio.error?.message ?? '').includes('perfiles_pkey'),
    propio.error?.message ?? ''
  )

  // --- No se puede crear un perfil en nombre de otra persona ---
  const ajeno = await b.client
    .from('perfiles')
    .insert({
      id: a.uid,
      alias: 'ajeno',
      alias_sufijo: 'beef'
    })
    .select('id, alias')
  runner.check(
    'A10 No se puede insertar un perfil con el identificador de otra persona',
    !!ajeno.error,
    `${ajeno.error?.code ?? 'sin error'} ${ajeno.error?.message ?? ''}`
  )

  // --- El sufijo que la app propone es el que ya usa la base ---
  const sufijoEsperado = a.uid.replace(/-/g, '').slice(0, 4)
  runner.check(
    'A11 El sufijo coincide con los 4 primeros del identificador',
    perfilA?.alias_sufijo === sufijoEsperado,
    `${perfilA?.alias_sufijo} vs ${sufijoEsperado}`
  )
} catch (error) {
  runner.check('Alias · sin excepciones', false, error.message)
}

console.log(`\nProyecto: ${SUPABASE_URL} (clave ${SUPABASE_KEY.slice(0, 12)}…)`)
process.exit(runner.summary('ALIAS') ? 1 : 0)
