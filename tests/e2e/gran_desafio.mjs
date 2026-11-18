// Gran desafío de la expo: 20 preguntas con dificultad creciente y 3 vidas.
//
//   node tests/e2e/gran_desafio.mjs
//
// Contra el proyecto real: crea una cuenta de prueba (correo ficticio) y
// comprueba que la partida tenga 20 preguntas (4 fáciles, 8 intermedias y 8
// difíciles, en ese orden), que se juegue una sola vez, que cada respuesta
// incorrecta reste una de las 3 vidas, que sin vidas se rechacen más
// respuestas y que la partida cierre como finalizada con los puntos logrados.
// Requiere 0010-0013 aplicadas y "Confirm email" desactivado.

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

const inicio = await supabase.rpc('iniciar_partida', {
  p_desafio: DESAFIO,
  p_clave: `gran-${id}-${crypto.randomUUID()}`
})
const fila = Array.isArray(inicio.data) ? inicio.data[0] : inicio.data
runner.check(
  'partida creada con 20 preguntas',
  fila?.total_preguntas === 20,
  inicio.error?.message ?? String(fila?.total_preguntas)
)
runner.check(
  'un solo intento permitido',
  fila?.intentos_permitidos === 1,
  String(fila?.intentos_permitidos)
)
if (!fila) process.exit(runner.summary('gran desafío') ? 1 : 0)

const preguntas = await supabase
  .from('partida_preguntas')
  .select('desafio_pregunta_id, orden, desafio_preguntas(dificultad)')
  .eq('partida_id', fila.partida)
  .order('orden', { ascending: true })
const lista = preguntas.data ?? []
const niveles = lista.map(p => p.desafio_preguntas.dificultad)
const cuenta = n => niveles.filter(x => x === n).length
runner.check(
  '4 fáciles, 8 intermedias y 8 difíciles',
  cuenta('facil') === 4 && cuenta('intermedio') === 8 && cuenta('dificil') === 8
)
runner.check(
  'la dificultad solo sube',
  niveles.every((n, i) => i === 0 || orden[n] >= orden[niveles[i - 1]])
)

const guardada = await supabase
  .from('partidas')
  .select('vidas')
  .eq('id', fila.partida)
  .single()
runner.check('la partida empieza con 3 vidas', guardada.data?.vidas === 3)

// Responde la pregunta i con su primera opción (A).
async function responder(i) {
  const idPregunta = lista[i].desafio_pregunta_id
  const opciones = await supabase
    .from('desafio_opciones')
    .select('id, orden')
    .eq('pregunta_id', idPregunta)
    .order('orden', { ascending: true })
  const respuesta = await supabase.rpc('responder_partida', {
    p_partida: fila.partida,
    p_pregunta: idPregunta,
    p_opcion: opciones.data[0].id
  })
  return respuesta
}

// Se responde siempre la opción A hasta quedarse sin vidas. Cada respuesta
// incorrecta resta una vida; las correctas no.
let vidasPrevias = 3
let sinVidasEn = null
let acertadas = 0
for (let i = 0; i < lista.length; i++) {
  const r = await responder(i)
  if (r.error) {
    runner.check(
      'sin vidas el servidor rechaza más respuestas',
      /SIN_VIDAS/.test(r.error.message),
      r.error.message
    )
    sinVidasEn = i
    break
  }
  const fila0 = Array.isArray(r.data) ? r.data[0] : r.data
  if (fila0.correcto) {
    acertadas++
    runner.check(
      `respuesta ${i + 1} correcta: no resta vidas`,
      fila0.vidas_restantes === vidasPrevias
    )
  } else {
    runner.check(
      `respuesta ${i + 1} incorrecta: resta una vida`,
      fila0.vidas_restantes === vidasPrevias - 1,
      `${vidasPrevias} -> ${fila0.vidas_restantes}`
    )
    vidasPrevias = fila0.vidas_restantes
  }
}
runner.check(
  'la partida se corta al quedarse sin vidas (antes de la pregunta 20)',
  sinVidasEn !== null && sinVidasEn < 20,
  String(sinVidasEn)
)

const cierre = await supabase.rpc('finalizar_partida', {
  p_partida: fila.partida
})
const final = Array.isArray(cierre.data) ? cierre.data[0] : cierre.data
runner.check(
  'sin vidas la partida cierra como finalizada (cuenta en el ranking)',
  final?.estado === 'finalizada',
  cierre.error?.message ?? final?.estado
)
runner.check(
  'los puntos coinciden con los aciertos (10 por acierto)',
  final?.puntos === acertadas * 10 && final?.errores === 3,
  `${final?.puntos} pts, ${final?.errores} errores`
)

const segundo = await supabase.rpc('iniciar_partida', {
  p_desafio: DESAFIO,
  p_clave: `gran-${id}-2-${crypto.randomUUID()}`
})
runner.check(
  'no se puede jugar una segunda vez',
  !!segundo.error && /INTENTOS_AGOTADOS/.test(segundo.error.message),
  segundo.error?.message ?? 'no hubo error'
)

process.exitCode = runner.summary('gran desafío') ? 1 : 0
