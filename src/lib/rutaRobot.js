// Lógica pura del minijuego "Ruta del robot".
//
// La usan la pantalla del juego (para animar el recorrido) y las pruebas.
// La misma simulación está escrita en SQL (supabase/migrations/0014): el
// servidor es quien decide el resultado y los puntos; esta copia solo sirve
// para mostrar el recorrido paso a paso y tiene que dar siempre lo mismo.
//
// Un programa es una lista de bloques:
//   'A'                      avanzar una casilla
//   'I'  / 'D'               girar a la izquierda / a la derecha
//   { r: 3, p: [bloques] }   repetir 3 veces los bloques de adentro
//
// Rumbos: 0 arriba, 1 derecha, 2 abajo, 3 izquierda.

export const MAX_BLOQUES = 40
export const MAX_PASOS = 200
export const MAX_REPETICIONES = 9
export const MAX_ANIDADO = 2

const DF = [-1, 0, 1, 0]
const DC = [0, 1, 0, -1]

// Cantidad de bloques escritos: cada instrucción cuenta 1 y cada bucle cuenta
// 1 más lo que tiene adentro (por eso un bucle ahorra bloques).
export function contarBloques(programa) {
  let total = 0
  for (const bloque of programa) {
    total += 1
    if (typeof bloque === 'object' && bloque !== null) {
      total += contarBloques(bloque.p ?? [])
    }
  }
  return total
}

// Convierte el programa en la lista plana de pasos que se ejecutan.
export function expandir(programa, profundidad = 0) {
  if (profundidad > MAX_ANIDADO) throw new Error('Demasiados bucles anidados.')
  const pasos = []
  for (const bloque of programa) {
    if (typeof bloque === 'string') {
      if (!['A', 'I', 'D'].includes(bloque)) {
        throw new Error('Instrucción no válida.')
      }
      pasos.push(bloque)
    } else if (bloque && typeof bloque === 'object') {
      const veces = Number(bloque.r)
      if (!Number.isInteger(veces) || veces < 1 || veces > MAX_REPETICIONES) {
        throw new Error('Cantidad de repeticiones no válida.')
      }
      const interno = expandir(bloque.p ?? [], profundidad + 1)
      for (let i = 0; i < veces; i++) pasos.push(...interno)
    } else {
      throw new Error('Bloque no válido.')
    }
    if (pasos.length > MAX_PASOS)
      throw new Error('El recorrido es demasiado largo.')
  }
  return pasos
}

// Ejecuta el programa en el nivel y devuelve el recorrido completo.
//   nivel: { n, inicio, rumbo, meta, muros, estrellas }
// Cada elemento de `camino` es el estado después de un paso.
export function simular(nivel, programa) {
  const pasos = expandir(programa)
  let pos = nivel.inicio
  let rumbo = nivel.rumbo
  const recogidas = []
  const camino = [{ pos, rumbo, paso: null, estrellas: 0 }]
  let llego = false
  let choco = false
  for (const paso of pasos) {
    if (paso === 'I') {
      rumbo = (rumbo + 3) % 4
    } else if (paso === 'D') {
      rumbo = (rumbo + 1) % 4
    } else {
      const fila = Math.floor(pos / nivel.n) + DF[rumbo]
      const col = (pos % nivel.n) + DC[rumbo]
      const siguiente = fila * nivel.n + col
      if (
        fila < 0 ||
        fila >= nivel.n ||
        col < 0 ||
        col >= nivel.n ||
        nivel.muros.includes(siguiente)
      ) {
        choco = true
        camino.push({
          pos,
          rumbo,
          paso,
          estrellas: recogidas.length,
          choco: true
        })
        break
      }
      pos = siguiente
      if (nivel.estrellas.includes(pos) && !recogidas.includes(pos)) {
        recogidas.push(pos)
      }
    }
    camino.push({ pos, rumbo, paso, estrellas: recogidas.length })
    if (pos === nivel.meta) {
      llego = true
      break
    }
  }
  return {
    llego,
    choco,
    pasos: pasos.length,
    ejecutados: camino.length - 1,
    estrellas: recogidas.length,
    recogidas,
    camino
  }
}

// Puntos de un intento exitoso (la misma cuenta que hace el servidor).
export function puntosDelIntento(nivel, resultado, bloques) {
  if (!resultado.llego) return 0
  const exceso = Math.max(bloques - nivel.par, 0)
  return 5 + 3 * resultado.estrellas + Math.max(0, 7 - exceso)
}

export const PUNTOS_MAXIMOS_POR_NIVEL = nivel =>
  5 + 3 * nivel.estrellas.length + 7
