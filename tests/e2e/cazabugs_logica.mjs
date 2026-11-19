// Lógica del minijuego "Cazabugs" (sin base de datos ni navegador).
//
//   node tests/e2e/cazabugs_logica.mjs
//
// Comprueba que la partida sea determinista (misma semilla = mismo cronograma),
// el reparto de bichos, el puntaje (rachas, bichos gordos, dorados, Usagi), el
// rechazo de toques imposibles y que una partida perfecta no pase del máximo.

import path from 'node:path'
import { fileURLToPath } from 'node:url'

import { createRunner } from './helpers.mjs'

const here = path.dirname(fileURLToPath(import.meta.url))
const lib = await import(
  new URL(
    `file:///${path.resolve(here, '../../src/lib/cazabugs.js').replace(/\\/g, '/')}`
  ).href
)
const runner = createRunner('Cazabugs (lógica)')

// ---- cronograma ----
const a = lib.cronograma(12345)
const b = lib.cronograma(12345)
const c = lib.cronograma(54321)
runner.check(
  'misma semilla = mismo cronograma',
  JSON.stringify(a) === JSON.stringify(b)
)
runner.check(
  'otra semilla = otro cronograma',
  JSON.stringify(a) !== JSON.stringify(c)
)
runner.check(
  'aparecen entre 70 y 130 bichos en 45 s',
  a.length >= 70 && a.length <= 130,
  String(a.length)
)
runner.check(
  'ningún bicho aparece fuera de tiempo ni en una casilla inexistente',
  a.every(
    e =>
      e.t >= 0 &&
      e.t < lib.DURACION_MS &&
      e.celda >= 0 &&
      e.celda < lib.CELDAS &&
      e.vida >= 300
  )
)
let solapados = 0
for (const e of a) {
  if (
    a.some(
      o =>
        o.i !== e.i &&
        o.celda === e.celda &&
        o.t < e.t + e.vida &&
        e.t < o.t + o.vida
    )
  )
    solapados++
}
runner.check(
  'nunca hay dos bichos a la vez en la misma casilla',
  solapados === 0
)
const reparto = {}
for (let s = 1; s <= 40; s++)
  for (const e of lib.cronograma(s * 7919))
    reparto[e.tipo] = (reparto[e.tipo] ?? 0) + 1
const total = Object.values(reparto).reduce((x, y) => x + y, 0)
runner.check(
  'bug es lo más común y los amigos y los dorados son poco frecuentes',
  reparto.bug > reparto.rapido &&
    reparto.rapido > reparto.dorado &&
    reparto.amigo / total < 0.12 &&
    reparto.dorado / total < 0.1,
  JSON.stringify(reparto)
)
const temprano = lib.cronograma(99).filter(e => e.t < 3000)
const tarde = lib.cronograma(99).filter(e => e.t > 40000)
runner.check(
  'los bichos duran menos a medida que avanza la ronda',
  Math.min(...tarde.map(e => e.vida)) <
    Math.min(...temprano.map(e => e.vida)) || tarde.every(e => e.vida <= 1250)
)

// ---- puntaje ----
const crono = lib.cronograma(2024)
const comunes = crono.filter(e => e.tipo === 'bug')
function golpear(motor, e, delta = 100) {
  return motor.tocar(e.t + delta, e.celda)
}
let motor = lib.crearMotor(crono)
const r1 = golpear(motor, comunes[0])
runner.check(
  'tocar un bug suma 10',
  r1.resultado === 'acierto' && r1.delta === 10
)
runner.check(
  'el mismo bug no se puede cazar dos veces',
  motor.tocar(comunes[0].t + 200, comunes[0].celda).resultado === 'fallo'
)

motor = lib.crearMotor(crono)
let vacio = null
for (let t = 100; t < 44000 && !vacio; t += 100) {
  for (let celda = 0; celda < lib.CELDAS && !vacio; celda++) {
    if (!crono.some(e => e.celda === celda && e.t <= t && t < e.t + e.vida)) {
      vacio = { t, celda }
    }
  }
}
runner.check(
  'tocar una casilla vacía es un fallo y corta la racha',
  motor.tocar(vacio.t, vacio.celda).resultado === 'fallo' &&
    motor.estado.fallos === 1 &&
    motor.estado.racha === 0
)

// racha: 13 bugs seguidos (se arma un cronograma propio para controlar el caso)
const conFin = lista => lista.map(e => ({ ...e, fin: e.t + e.vida }))
const falso = conFin(
  Array.from({ length: 14 }, (_, i) => ({
    i,
    t: i * 1000,
    celda: i % 12,
    tipo: 'bug',
    vida: 800
  }))
)
motor = lib.crearMotor(falso)
const deltas = []
for (const e of falso) deltas.push(motor.tocar(e.t + 100, e.celda).delta)
runner.check(
  'racha: ×1 hasta el 4.º, ×2 del 5.º al 8.º, ×3 del 9.º al 12.º y ×4 desde el 13.º',
  JSON.stringify(deltas) ===
    JSON.stringify([10, 10, 10, 10, 20, 20, 20, 20, 30, 30, 30, 30, 40, 40]),
  deltas.join(',')
)
runner.check(
  'el puntaje suma todo',
  motor.estado.puntaje === deltas.reduce((x, y) => x + y, 0)
)
runner.check('la mejor racha queda registrada', motor.estado.mejorRacha === 14)

const mezcla = conFin([
  { i: 0, t: 0, celda: 0, tipo: 'bug', vida: 1000 },
  { i: 1, t: 1500, celda: 1, tipo: 'amigo', vida: 1000 },
  { i: 2, t: 3000, celda: 2, tipo: 'grande', vida: 1500 },
  { i: 3, t: 5000, celda: 3, tipo: 'dorado', vida: 600 },
  { i: 4, t: 7000, celda: 4, tipo: 'rapido', vida: 500 }
])
motor = lib.crearMotor(mezcla)
motor.tocar(100, 0)
runner.check(
  'tras un bug: 10 puntos y racha 1',
  motor.estado.puntaje === 10 && motor.estado.racha === 1
)
const amigo = motor.tocar(1600, 1)
runner.check(
  'tocar a Usagi resta 25 (sin bajar de 0), corta la racha y cuenta',
  amigo.resultado === 'amigo' &&
    motor.estado.puntaje === 0 &&
    motor.estado.racha === 0 &&
    motor.estado.amigos === 1
)
const g1 = motor.tocar(3100, 2)
runner.check(
  'el bicho gordo necesita 2 toques: el primero no puntúa',
  g1.resultado === 'golpe' && motor.estado.puntaje === 0
)
const g2 = motor.tocar(3300, 2)
runner.check(
  'el 2.º toque al gordo suma 30',
  g2.resultado === 'acierto' && g2.delta === 30
)
runner.check(
  'el dorado suma 60 (racha 2 → ×1)',
  motor.tocar(5100, 3).delta === 60
)
runner.check('el veloz suma 20', motor.tocar(7100, 4).delta === 20)
runner.check(
  'el puntaje final es la suma',
  motor.estado.puntaje === 110,
  String(motor.estado.puntaje)
)

const fuera = lib.crearMotor(mezcla)
runner.check(
  'tocar después de que el bicho se escondió es un fallo',
  fuera.tocar(1000, 0).resultado === 'fallo'
)
runner.check(
  'tocar justo antes de que aparezca es un fallo',
  fuera.tocar(1499, 1).resultado === 'fallo'
)

// ---- bichos escapados ----
const esc = lib.crearMotor(
  conFin([
    { i: 0, t: 0, celda: 0, tipo: 'bug', vida: 1000 },
    { i: 1, t: 200, celda: 1, tipo: 'bug', vida: 1000 },
    { i: 2, t: 400, celda: 2, tipo: 'amigo', vida: 1000 },
    { i: 3, t: 3000, celda: 3, tipo: 'bug', vida: 1000 }
  ])
)
esc.tocar(100, 0) // +10, racha 1
const tras = esc.tocar(1300, 5) // el bug 1 se escondió a los 1200: -5 y racha a 0
runner.check(
  'un bicho que se escapa resta 5 y corta la racha',
  tras.escapados.length === 1 &&
    esc.estado.escapados === 1 &&
    esc.estado.puntaje === 5 &&
    esc.estado.racha === 0
)
runner.check(
  'Usagi que se esconde no cuenta como escapado',
  esc.estado.escapados === 1
)
esc.cerrar()
runner.check(
  'al cerrar la ronda se cuentan los que se escaparon antes de las 45 s',
  esc.estado.escapados === 2 && esc.estado.puntaje === 0,
  JSON.stringify(esc.estado)
)
runner.check(
  'sin tocar nada el puntaje nunca baja de 0',
  lib.reproducir(5, []).puntaje === 0 && lib.reproducir(5, []).escapados > 50
)
const lim = lib.crearMotor(
  conFin([{ i: 0, t: 44000, celda: 0, tipo: 'bug', vida: 1500 }])
)
lim.cerrar()
runner.check(
  'el que sigue visible al terminar no se cuenta',
  lim.estado.escapados === 0
)

// ---- validación de toques ----
for (const [nombre, toques] of [
  ['tiempo negativo', [[-1, 0]]],
  ['casilla 12', [[100, 12]]],
  ['fuera de la duración', [[45000, 0]]],
  [
    'dos toques a menos de 60 ms',
    [
      [100, 1],
      [150, 2]
    ]
  ],
  ['no es una lista', {}],
  ['toque incompleto', [[5]]],
  ['tiempo decimal', [[1.5, 0]]],
  ['más de 500 toques', Array.from({ length: 501 }, (_, i) => [i * 60, 0])]
]) {
  let rechazo = false
  try {
    lib.reproducir(1, toques)
  } catch {
    rechazo = true
  }
  runner.check(`reproducir rechaza: ${nombre}`, rechazo)
}
runner.check('una partida sin toques da 0', lib.reproducir(1, []).puntaje === 0)

// ---- partida "perfecta": no hay que superar el máximo de ranking ----
const perfecto = lib.cronograma(31337).filter(e => e.tipo !== 'amigo')
const toques = []
let ultimo = -100
for (const e of perfecto) {
  const t = Math.max(e.t + 40, ultimo + 60)
  if (t < e.t + e.vida && t < lib.DURACION_MS) {
    toques.push([t, e.celda])
    ultimo = t
    if (e.tipo === 'grande') {
      const t2 = t + 60
      if (t2 < e.t + e.vida) {
        toques.push([t2, e.celda])
        ultimo = t2
      }
    }
  }
}
const perfecta = lib.reproducir(31337, toques)
runner.check(
  'una partida casi perfecta puntúa mucho',
  perfecta.puntaje > 3000,
  String(perfecta.puntaje)
)
runner.check(
  'los puntos de ranking nunca pasan de 100',
  lib.puntosDelPuntaje(perfecta.puntaje) <= 100 &&
    lib.puntosDelPuntaje(10 ** 6) === 100
)
runner.check(
  'cada 40 de puntaje valen 1 punto de ranking',
  lib.puntosDelPuntaje(39) === 0 &&
    lib.puntosDelPuntaje(40) === 1 &&
    lib.puntosDelPuntaje(1234) === 30
)

process.exitCode = runner.summary('cazabugs (lógica)') ? 1 : 0
