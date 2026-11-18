// Gran desafío de la expo: 20 preguntas con dificultad creciente y rotación.
//
//   node tests/e2e/gran_desafio.mjs
//
// Contra el proyecto real: crea una cuenta de prueba (correo ficticio), juega
// los tres intentos permitidos y comprueba que cada partida tenga 20
// preguntas (4 fáciles, 8 intermedias y 8 difíciles, en ese orden), que se
// roten entre intentos, que el cuarto intento se rechace y que una
// partida se pueda responder y cerrar.
// Requiere 0010-0012 aplicadas y "Confirm email" desactivado.

import crypto from 'node:crypto'

import { createRunner, createSupabaseClient } from './helpers.mjs'

const runner = createRunner('Gran desafío (dificultad creciente y rotación)')
const DESAFIO = '50000000-0000-0000-0000-000000000010'

const supabase = await createSupabaseClient()
const id = Date.now().toString(36)
const signup = await supabase.auth.signUp({
  email: `e2e-gran-${id}@example.com`,
  password: crypto.randomBytes(9).toString('base64url'),
  options: { data: { alias: `e2e_gran_${id}` } }
})
runner.check(
  'cuenta de prueba creada con sesión inmediata',
  !!signup.data?.session,
  signup.error?.message ?? ''
)
if (!signup.data?.session) {
  process.exit(runner.summary('gran desafío') ? 1 : 0)
}

const orden = { facil: 1, intermedio: 2, dificil: 3 }
const vistas = new Map()
const partidas = []

for (let intento = 1; intento <= 3; intento++) {
  const inicio = await supabase.rpc('iniciar_partida', {
    p_desafio: DESAFIO,
    p_clave: `gran-${id}-${intento}-${crypto.randomUUID()}`
  })
  const fila = Array.isArray(inicio.data) ? inicio.data[0] : inicio.data
  runner.check(
    `intento ${intento}: partida creada con 20 preguntas`,
    fila?.total_preguntas === 20,
    inicio.error?.message ?? String(fila?.total_preguntas)
  )
  if (!fila) continue
  partidas.push(fila.partida)

  const preguntas = await supabase
    .from('partida_preguntas')
    .select('desafio_pregunta_id, orden, desafio_preguntas(dificultad)')
    .eq('partida_id', fila.partida)
    .order('orden', { ascending: true })
  const lista = preguntas.data ?? []
  const niveles = lista.map(p => p.desafio_preguntas.dificultad)
  const cuenta = n => niveles.filter(x => x === n).length
  runner.check(
    `intento ${intento}: 4 fáciles, 8 intermedias y 8 difíciles`,
    cuenta('facil') === 4 &&
      cuenta('intermedio') === 8 &&
      cuenta('dificil') === 8
  )
  runner.check(
    `intento ${intento}: la dificultad solo sube`,
    niveles.every((n, i) => i === 0 || orden[n] >= orden[niveles[i - 1]])
  )
  const nuevas = lista.filter(p => !vistas.has(p.desafio_pregunta_id)).length
  if (intento === 2) {
    runner.check(
      'intento 2: la mayoría de las preguntas son nuevas (rotación)',
      nuevas >= 14,
      `${nuevas} nuevas de 20`
    )
  }
  lista.forEach(p => vistas.set(p.desafio_pregunta_id, true))
}

const cuarto = await supabase.rpc('iniciar_partida', {
  p_desafio: DESAFIO,
  p_clave: `gran-${id}-4-${crypto.randomUUID()}`
})
runner.check(
  'el cuarto intento se rechaza (3 permitidos)',
  !!cuarto.error && /INTENTOS_AGOTADOS/.test(cuarto.error.message),
  cuarto.error?.message ?? 'no hubo error'
)

// Se responde una pregunta y se cierra la primera partida.
if (partidas[0]) {
  const primera = await supabase
    .from('partida_preguntas')
    .select(
      'desafio_pregunta_id, desafio_preguntas(desafio_opciones(id, orden))'
    )
    .eq('partida_id', partidas[0])
    .order('orden', { ascending: true })
    .limit(1)
  const pregunta = primera.data?.[0]
  const opciones = pregunta?.desafio_preguntas?.desafio_opciones ?? []
  opciones.sort((a, b) => a.orden - b.orden)
  const respuesta = await supabase.rpc('responder_partida', {
    p_partida: partidas[0],
    p_pregunta: pregunta?.desafio_pregunta_id,
    p_opcion: opciones[0]?.id
  })
  runner.check(
    'se puede responder una pregunta de la partida',
    !respuesta.error,
    respuesta.error?.message ?? ''
  )
  const cierre = await supabase.rpc('finalizar_partida', {
    p_partida: partidas[0]
  })
  runner.check(
    'la partida se puede cerrar (queda como incompleta)',
    !cierre.error,
    cierre.error?.message ?? ''
  )
}

process.exitCode = runner.summary('gran desafío') ? 1 : 0
