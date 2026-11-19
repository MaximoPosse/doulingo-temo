// Lógica pura del minijuego "Cazabugs".
//
// Aparecen bichos en un tablero de 3 x 4 agujeros y hay que tocarlos antes de
// que se escondan, sin tocar a los amigos. Todo lo que aparece sale de una
// semilla que entrega el servidor, por lo que el servidor puede repetir la
// partida a partir de los toques y calcular el puntaje oficial (mismo
// algoritmo en SQL, supabase/migrations/0015). Esta copia sirve para mostrar el
// juego en pantalla y tiene que dar siempre lo mismo que el servidor.
//
// Tipos de bicho:
//   bug     🐛 10 puntos
//   rapido  🦟 20 puntos, se esconde más rápido
//   grande  🪲 hay que tocarlo 2 veces, 30 puntos
//   dorado  🐞 60 puntos, aparece muy poco tiempo
//   amigo   Usagi: tocarlo resta 25 puntos y corta la racha
// Cada bicho seguido sin fallar sube la racha: ×2 desde el 5.º, ×3 desde el
// 9.º y ×4 desde el 13.º.

export const COLUMNAS = 3
export const FILAS = 4
export const CELDAS = COLUMNAS * FILAS
export const DURACION_MS = 45000
export const PASO_MS = 300
export const PASOS = DURACION_MS / PASO_MS
export const INTERVALO_MIN_MS = 60
export const MAX_TOQUES = 500
export const PUNTOS_POR_TIPO = { bug: 10, rapido: 20, grande: 30, dorado: 60 }
export const PENALIDAD_AMIGO = 25
export const PUNTAJE_POR_PUNTO = 40
export const PUNTOS_MAXIMOS = 100

// Generador pseudoaleatorio congruencial (igual en SQL). BigInt para que la
// multiplicación no pierda precisión.
const A = 1103515245n
const C = 12345n
const M = 2147483648n

export function crearAzar(semilla) {
  let estado = BigInt(semilla)
  return n => {
    estado = (A * estado + C) % M
    return Number((estado / 65536n) % BigInt(n))
  }
}

// Todo lo que va a aparecer en la partida: [{ i, t, celda, tipo, vida }]
export function cronograma(semilla) {
  const azar = crearAzar(semilla)
  const libre = Array.from({ length: CELDAS }, () => 0)
  const lista = []
  for (let k = 0; k < PASOS; k++) {
    const t = k * PASO_MS
    // Siempre se sacan los 3 números, aparezca algo o no.
    const rAparece = azar(100)
    const rCelda = azar(CELDAS)
    const rTipo = azar(100)
    const prob = 55 + Math.floor((Math.min(k, 100) * 30) / 100)
    if (rAparece < prob && libre[rCelda] <= t) {
      const base = Math.max(800, 1500 - k * 6)
      let tipo
      let vida
      if (rTipo < 58) {
        tipo = 'bug'
        vida = base
      } else if (rTipo < 76) {
        tipo = 'rapido'
        vida = Math.floor((base * 60) / 100)
      } else if (rTipo < 86) {
        tipo = 'grande'
        vida = Math.floor((base * 13) / 10)
      } else if (rTipo < 92) {
        tipo = 'dorado'
        vida = Math.floor((base * 50) / 100)
      } else {
        tipo = 'amigo'
        vida = base
      }
      lista.push({ i: lista.length, t, celda: rCelda, tipo, vida })
      libre[rCelda] = t + vida + 100
    }
  }
  return lista
}

export function multiplicador(racha) {
  return 1 + Math.min(Math.floor((racha - 1) / 4), 3)
}

// Motor de la partida: se le van pasando los toques en orden.
export function crearMotor(lista) {
  const resuelto = new Set()
  const golpes = new Map()
  const porCelda = Array.from({ length: CELDAS }, () => [])
  for (const e of lista) porCelda[e.celda].push(e)
  const estado = {
    puntaje: 0,
    racha: 0,
    mejorRacha: 0,
    aciertos: 0,
    fallos: 0,
    amigos: 0,
    toques: 0
  }

  return {
    estado,
    // Bichos visibles en el instante t que todavía no se resolvieron.
    activosEn(t) {
      const visibles = []
      for (const e of lista) {
        if (e.t > t) break
        if (t < e.t + e.vida && !resuelto.has(e.i)) visibles.push(e)
      }
      return visibles
    },
    golpesDe(i) {
      return golpes.get(i) ?? 0
    },
    // Aplica un toque en el instante t sobre la celda. Devuelve qué pasó.
    tocar(t, celda) {
      estado.toques++
      const e = porCelda[celda].find(
        x => x.t <= t && t < x.t + x.vida && !resuelto.has(x.i)
      )
      if (!e) {
        estado.fallos++
        estado.racha = 0
        return { resultado: 'fallo', delta: 0, bicho: null }
      }
      if (e.tipo === 'amigo') {
        resuelto.add(e.i)
        estado.amigos++
        estado.racha = 0
        const antes = estado.puntaje
        estado.puntaje = Math.max(0, estado.puntaje - PENALIDAD_AMIGO)
        return { resultado: 'amigo', delta: estado.puntaje - antes, bicho: e }
      }
      if (e.tipo === 'grande') {
        const n = (golpes.get(e.i) ?? 0) + 1
        golpes.set(e.i, n)
        if (n < 2) return { resultado: 'golpe', delta: 0, bicho: e }
      }
      resuelto.add(e.i)
      estado.aciertos++
      estado.racha++
      estado.mejorRacha = Math.max(estado.mejorRacha, estado.racha)
      const mult = multiplicador(estado.racha)
      const delta = PUNTOS_POR_TIPO[e.tipo] * mult
      estado.puntaje += delta
      return { resultado: 'acierto', delta, mult, bicho: e }
    }
  }
}

// Repite una partida completa a partir de la semilla y la lista de toques
// [[t, celda], ...]. Es lo que hace el servidor para validar.
export function reproducir(semilla, toques) {
  if (!Array.isArray(toques) || toques.length > MAX_TOQUES) {
    throw new Error('Toques no válidos.')
  }
  let anterior = -Infinity
  const motor = crearMotor(cronograma(semilla))
  for (const toque of toques) {
    if (!Array.isArray(toque) || toque.length !== 2) {
      throw new Error('Toques no válidos.')
    }
    const [t, celda] = toque
    if (
      !Number.isInteger(t) ||
      !Number.isInteger(celda) ||
      t < 0 ||
      t >= DURACION_MS ||
      celda < 0 ||
      celda >= CELDAS ||
      t - anterior < INTERVALO_MIN_MS
    ) {
      throw new Error('Toques no válidos.')
    }
    anterior = t
    motor.tocar(t, celda)
  }
  return { ...motor.estado }
}

// Puntos que suma al ranking una partida con ese puntaje.
export function puntosDelPuntaje(puntaje) {
  return Math.min(PUNTOS_MAXIMOS, Math.floor(puntaje / PUNTAJE_POR_PUNTO))
}
