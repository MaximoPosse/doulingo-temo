// Lógica del minijuego "Ruta del robot" (sin base de datos ni navegador).
//
//   node tests/e2e/ruta_robot_logica.mjs
//
// Comprueba el conteo de bloques, la expansión de bucles, la simulación
// (giros, choques, estrellas, meta), los puntos y que cada nivel se pueda
// resolver con el "par" que declara.

import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

import { createRunner } from './helpers.mjs'

const here = path.dirname(fileURLToPath(import.meta.url))
const lib = await import(
  new URL(
    `file:///${path.resolve(here, '../../src/lib/rutaRobot.js').replace(/\\/g, '/')}`
  ).href
)
const niveles = JSON.parse(
  fs.readFileSync(path.join(here, 'minijuego_niveles.json'), 'utf8')
)
const runner = createRunner('Ruta del robot (lógica)')

// ---- bloques y bucles ----
runner.check(
  'contar: 3 instrucciones = 3 bloques',
  lib.contarBloques(['A', 'I', 'A']) === 3
)
runner.check(
  'contar: un bucle cuenta 1 más lo de adentro',
  lib.contarBloques([{ r: 4, p: ['A'] }]) === 2
)
runner.check(
  'contar: bucles anidados',
  lib.contarBloques([{ r: 2, p: ['A', { r: 3, p: ['D'] }] }]) === 4
)
runner.check(
  'expandir: repetir ×3 avanzar',
  lib.expandir([{ r: 3, p: ['A'] }]).join('') === 'AAA'
)
runner.check(
  'expandir: bucle dentro de bucle',
  lib.expandir([{ r: 2, p: ['A', { r: 2, p: ['I'] }] }]).join('') === 'AIIAII'
)
for (const [nombre, programa] of [
  ['instrucción desconocida', ['X']],
  ['repetir 0 veces', [{ r: 0, p: ['A'] }]],
  ['repetir 10 veces', [{ r: 10, p: ['A'] }]],
  [
    'demasiados bucles anidados',
    [{ r: 2, p: [{ r: 2, p: [{ r: 2, p: [{ r: 2, p: ['A'] }] }] }] }]
  ],
  [
    'recorrido demasiado largo',
    [{ r: 9, p: [{ r: 9, p: [{ r: 9, p: ['A'] }] }] }]
  ]
]) {
  let lanzo = false
  try {
    lib.expandir(programa)
  } catch {
    lanzo = true
  }
  runner.check(`expandir rechaza: ${nombre}`, lanzo)
}

// ---- simulación ----
const nivel1 = niveles[0]
const ok = lib.simular(nivel1, [{ r: 4, p: ['A'] }])
runner.check(
  'nivel 1: repetir ×4 avanzar llega a la meta',
  ok.llego && !ok.choco
)
runner.check('nivel 1: recoge la estrella del camino', ok.estrellas === 1)
runner.check(
  'nivel 1: 2 bloques con par 4 dan los 15 puntos máximos',
  lib.puntosDelIntento(nivel1, ok, 2) === 15
)
const corto = lib.simular(nivel1, ['A', 'A'])
runner.check('quedarse corto no llega ni choca', !corto.llego && !corto.choco)
const choque = lib.simular(nivel1, ['I', 'A', 'A', 'A'])
runner.check('salirse del tablero es un choque', choque.choco && !choque.llego)
runner.check(
  'un choque no da puntos',
  lib.puntosDelIntento(nivel1, choque, 4) === 0
)
const muro = lib.simular(nivel1, ['A', 'D', 'A'])
runner.check('chocar con un obstáculo es un choque', muro.choco)
runner.check(
  'pasarse del par resta de a un punto de bonificación',
  lib.puntosDelIntento(nivel1, ok, nivel1.par + 3) === 5 + 3 + 4
)
runner.check(
  'la bonificación nunca es negativa',
  lib.puntosDelIntento(nivel1, ok, nivel1.par + 30) === 5 + 3
)

// ---- cada nivel se puede resolver con su par ----
function resolver(nivel) {
  const DF = [-1, 0, 1, 0]
  const DC = [0, 1, 0, -1]
  const k = nivel.estrellas.length
  const mascara = p => {
    const i = nivel.estrellas.indexOf(p)
    return i >= 0 ? 1 << i : 0
  }
  let cola = [
    { p: nivel.inicio, r: nivel.rumbo, m: mascara(nivel.inicio), prog: [] }
  ]
  const visto = new Set([`${cola[0].p}|${cola[0].r}|${cola[0].m}`])
  while (cola.length) {
    const sig = []
    for (const e of cola) {
      if (e.p === nivel.meta && e.m === (1 << k) - 1) return e.prog
      if (e.p === nivel.meta) continue
      for (const a of ['A', 'I', 'D']) {
        let { p, r, m } = e
        if (a === 'I') r = (r + 3) % 4
        else if (a === 'D') r = (r + 1) % 4
        else {
          const f = Math.floor(p / nivel.n) + DF[r]
          const c = (p % nivel.n) + DC[r]
          const q = f * nivel.n + c
          if (
            f < 0 ||
            f >= nivel.n ||
            c < 0 ||
            c >= nivel.n ||
            nivel.muros.includes(q)
          )
            continue
          p = q
          m |= mascara(p)
        }
        const clave = `${p}|${r}|${m}`
        if (visto.has(clave)) continue
        visto.add(clave)
        sig.push({ p, r, m, prog: [...e.prog, a] })
      }
    }
    cola = sig
  }
  return null
}
let total = 0
niveles.forEach((nivel, i) => {
  const solucion = resolver(nivel)
  const res = solucion && lib.simular(nivel, solucion)
  runner.check(
    `nivel ${i + 1} ${nivel.nombre}: se resuelve con ${nivel.par} bloques`,
    !!solucion && solucion.length === nivel.par && res.llego
  )
  runner.check(
    `nivel ${i + 1}: la solución recoge todas las estrellas`,
    !!res && res.estrellas === nivel.estrellas.length
  )
  total += lib.PUNTOS_MAXIMOS_POR_NIVEL(nivel)
})
runner.check(
  'el puntaje máximo del minijuego es 114',
  total === 114,
  String(total)
)
runner.check(
  'los niveles van de menor a mayor par',
  niveles.every((n, i) => i === 0 || n.par >= niveles[i - 1].par)
)

process.exitCode = runner.summary('ruta del robot (lógica)') ? 1 : 0
