<template>
  <q-page class="dl-page rr">
    <div class="dl-page__inner rr__inner">
      <router-link :to="{ name: 'expo' }" class="rr__back">
        <q-icon name="arrow_back" size="20px" />
        Volver a la expo
      </router-link>

      <header class="rr__head">
        <div>
          <span class="rr__eyebrow">Minijuego de la expo</span>
          <h1 class="rr__title">Ruta del robot</h1>
          <p class="rr__lead">
            Programá al robot con bloques para que llegue a la meta
            <strong>🏁</strong>, recoja las estrellas <strong>⭐</strong> y
            esquive los obstáculos <strong>🧱</strong>. Usá
            <strong>Repetir</strong> para ahorrar bloques: ¡menos bloques, más
            puntos!
          </p>
        </div>
        <div class="rr__score" aria-live="polite">
          <span class="rr__score-value">{{ totalPuntos }}</span>
          <span class="rr__score-label">puntos del minijuego</span>
        </div>
      </header>

      <div v-if="cargando" class="rr__estado">
        <q-spinner color="primary" size="34px" />
        <p>Cargando el minijuego…</p>
      </div>

      <q-banner v-else-if="errorCarga" rounded class="dl-error-banner">
        <q-icon name="error_outline" size="22px" color="negative" />
        {{ errorCarga }}
        <template #action>
          <q-btn
            flat
            no-caps
            color="primary"
            label="Reintentar"
            @click="cargar"
          />
        </template>
      </q-banner>

      <template v-else>
        <!-- Bloqueado hasta terminar el Gran desafío -->
        <section v-if="!desbloqueado" class="rr__bloqueo">
          <q-icon name="lock" size="30px" />
          <div>
            <strong>Se desbloquea al terminar el Gran desafío</strong>
            <p>
              Cuando termines tu partida del desafío vas a poder jugar los 6
              niveles y sumar puntos al ranking. Mientras tanto, practicá sin
              puntos.
            </p>
            <q-btn
              v-if="desafioId"
              no-caps
              unelevated
              class="dl-btn-main"
              label="Ir al desafío"
              :to="{ name: 'desafio', params: { challengeId: desafioId } }"
            />
          </div>
        </section>

        <!-- Niveles -->
        <nav class="rr__niveles" aria-label="Niveles">
          <button
            type="button"
            class="rr__nivel"
            :class="{ 'is-activo': esPractica }"
            @click="elegir(PRACTICA)"
          >
            <span class="rr__nivel-num">🎯</span>
            <span class="rr__nivel-nombre">Práctica</span>
            <span class="rr__nivel-info">sin puntos</span>
          </button>
          <button
            v-for="(nivel, i) in niveles"
            :key="nivel.id"
            type="button"
            class="rr__nivel"
            :class="{
              'is-activo': nivelActual?.id === nivel.id,
              'is-bloqueado': !nivelDisponible(i)
            }"
            :disabled="!nivelDisponible(i)"
            @click="elegir(nivel)"
          >
            <span class="rr__nivel-num">{{
              nivelDisponible(i) ? nivel.orden : '🔒'
            }}</span>
            <span class="rr__nivel-nombre">{{ nivel.nombre }}</span>
            <span class="rr__nivel-info">
              <template v-if="resultados[nivel.id]">
                {{ '⭐'.repeat(resultados[nivel.id].estrellas) }}
                {{ resultados[nivel.id].puntos }} pts
              </template>
              <template v-else>{{
                nivelDisponible(i) ? 'sin jugar' : 'bloqueado'
              }}</template>
            </span>
          </button>
        </nav>

        <div v-if="nivelActual" class="rr__juego">
          <!-- Tablero -->
          <section class="rr__tablero-col">
            <p class="rr__consejo">
              <q-icon name="lightbulb" size="18px" />
              {{ nivelActual.consejo }}
            </p>
            <div class="rr__tablero-marco">
              <div
                class="rr__tablero"
                :class="{ 'is-choque': choque, 'is-meta': enMeta }"
                :style="{ '--n': nivelActual.n }"
                role="img"
                :aria-label="`Tablero de ${nivelActual.n} por ${nivelActual.n}`"
              >
                <div
                  v-for="i in nivelActual.n * nivelActual.n"
                  :key="i"
                  class="rr__casilla"
                  :class="{
                    'is-muro': nivelActual.muros.includes(i - 1),
                    'is-meta': nivelActual.meta === i - 1,
                    'is-huella': huellas.includes(i - 1)
                  }"
                >
                  <span v-if="nivelActual.muros.includes(i - 1)">🧱</span>
                  <span v-else-if="nivelActual.meta === i - 1">🏁</span>
                  <span
                    v-else-if="
                      nivelActual.estrellas.includes(i - 1) &&
                      !recogidas.includes(i - 1)
                    "
                    class="rr__estrella"
                    >⭐</span
                  >
                  <span
                    v-else-if="nivelActual.inicio === i - 1 && pos !== i - 1"
                    class="rr__inicio"
                    >●</span
                  >
                </div>

                <div
                  class="rr__robot"
                  :style="{
                    '--fila': Math.floor(pos / nivelActual.n),
                    '--col': pos % nivelActual.n,
                    '--rumbo': rumbo
                  }"
                >
                  <span class="rr__robot-flecha"><span>▲</span></span>
                  <span class="rr__robot-cara">{{
                    choque ? '😵' : enMeta ? '🥳' : '🤖'
                  }}</span>
                </div>
              </div>

              <div v-if="celebrando" class="rr__confeti" aria-hidden="true">
                <span
                  v-for="c in confeti"
                  :key="c.id"
                  :style="{
                    left: c.x + '%',
                    animationDelay: c.d + 's',
                    fontSize: c.s + 'rem'
                  }"
                  >{{ c.e }}</span
                >
              </div>
            </div>

            <div class="rr__leyenda">
              <span>🤖 Robot (la flecha ▲ muestra hacia dónde mira)</span>
              <span>🏁 Meta</span>
              <span>⭐ Estrella +3</span>
              <span>🧱 Obstáculo</span>
            </div>

            <p class="rr__mensaje" role="status" :class="`is-${tonoMensaje}`">
              {{ mensaje }}
            </p>

            <div
              v-if="resultadoServidor"
              class="rr__resultado"
              :class="{ 'is-record': resultadoServidor.mejoro }"
            >
              <strong>
                {{
                  resultadoServidor.mejoro
                    ? '¡Nuevo récord en este nivel!'
                    : 'Nivel superado'
                }}
              </strong>
              <p>
                +{{ resultadoServidor.puntos }} puntos ·
                {{ resultadoServidor.estrellas }}/{{
                  nivelActual.estrellas.length
                }}
                estrellas · {{ resultadoServidor.bloques }} bloques (par:
                {{ nivelActual.par }})
              </p>
              <p>
                Tu mejor en este nivel:
                <strong>{{ resultadoServidor.mejorPuntos }}</strong>
                pts · Total del minijuego:
                <strong>{{ resultadoServidor.total }}</strong> pts (ya suman al
                ranking)
              </p>
              <div class="rr__resultado-acciones">
                <q-btn
                  v-if="haySiguiente"
                  no-caps
                  unelevated
                  class="dl-btn-main"
                  label="Siguiente nivel"
                  @click="irAlSiguiente"
                />
                <q-btn
                  no-caps
                  flat
                  label="Mejorar mi recorrido"
                  @click="reiniciarTablero(true)"
                />
              </div>
            </div>
            <q-banner v-if="errorEnvio" rounded class="dl-error-banner q-mt-sm">
              <q-icon name="error_outline" size="22px" color="negative" />
              {{ errorEnvio }}
              <template #action>
                <q-btn
                  flat
                  no-caps
                  color="primary"
                  label="Reintentar"
                  @click="enviar"
                />
              </template>
            </q-banner>
          </section>

          <!-- Programa -->
          <section class="rr__programa-col">
            <h2 class="rr__subtitulo">Tu programa</h2>

            <div class="rr__paleta" role="group" aria-label="Bloques">
              <button
                type="button"
                class="rr__bloque rr__bloque--a"
                :disabled="!editable || bloquesUsados >= MAX_BLOQUES"
                @click="agregar('A')"
              >
                <span class="rr__bloque-icono">⬆</span>Avanzar
              </button>
              <button
                type="button"
                class="rr__bloque rr__bloque--i"
                :disabled="!editable || bloquesUsados >= MAX_BLOQUES"
                @click="agregar('I')"
              >
                <span class="rr__bloque-icono">↶</span>Girar izquierda
              </button>
              <button
                type="button"
                class="rr__bloque rr__bloque--d"
                :disabled="!editable || bloquesUsados >= MAX_BLOQUES"
                @click="agregar('D')"
              >
                <span class="rr__bloque-icono">↷</span>Girar derecha
              </button>
              <button
                type="button"
                class="rr__bloque rr__bloque--r"
                :disabled="
                  !editable ||
                  bloquesUsados >= MAX_BLOQUES ||
                  destino.length >= MAX_ANIDADO
                "
                @click="agregar('R')"
              >
                <span class="rr__bloque-icono">🔁</span>Repetir
              </button>
            </div>

            <div class="rr__contador">
              <span>
                Bloques: <strong>{{ bloquesUsados }}</strong> /
                {{ MAX_BLOQUES }}
              </span>
              <span class="rr__par">
                Par del nivel: {{ nivelActual.par }}
                <q-icon name="info" size="16px">
                  <q-tooltip>
                    Con tantos bloques o menos obtenés la bonificación completa
                    (+7). Cada bloque de más resta 1.
                  </q-tooltip>
                </q-icon>
              </span>
            </div>

            <div class="rr__lista" :class="{ 'is-vacia': !programa.length }">
              <button
                type="button"
                class="rr__fila rr__fila--raiz"
                :class="{ 'is-destino': destino.length === 0 }"
                :disabled="!editable"
                @click="destino = []"
              >
                ▶ Inicio del programa
              </button>
              <p v-if="!programa.length" class="rr__vacio">
                Tocá los bloques de arriba para armar tu programa.
              </p>
              <template v-for="fila in filas" :key="fila.clave">
                <div
                  v-if="fila.tipo === 'bloque'"
                  class="rr__fila rr__fila--bloque"
                  :style="{ '--nivel': fila.nivel }"
                >
                  <span class="rr__fila-texto">{{ NOMBRES[fila.bloque] }}</span>
                  <button
                    type="button"
                    class="rr__fila-quitar"
                    :disabled="!editable"
                    :aria-label="`Quitar ${NOMBRES[fila.bloque]}`"
                    @click="quitar(fila.ruta)"
                  >
                    ✕
                  </button>
                </div>
                <div
                  v-else-if="fila.tipo === 'bucle'"
                  class="rr__fila rr__fila--bucle"
                  :class="{ 'is-destino': igual(destino, fila.ruta) }"
                  :style="{ '--nivel': fila.nivel }"
                >
                  <button
                    type="button"
                    class="rr__fila-texto rr__fila-texto--btn"
                    :disabled="!editable"
                    @click="destino = fila.ruta"
                  >
                    🔁 Repetir
                  </button>
                  <span class="rr__veces">
                    <button
                      type="button"
                      :disabled="!editable || fila.bloque.r <= 1"
                      aria-label="Una repetición menos"
                      @click="fila.bloque.r--"
                    >
                      −
                    </button>
                    <strong>×{{ fila.bloque.r }}</strong>
                    <button
                      type="button"
                      :disabled="!editable || fila.bloque.r >= MAX_REPETICIONES"
                      aria-label="Una repetición más"
                      @click="fila.bloque.r++"
                    >
                      +
                    </button>
                  </span>
                  <button
                    type="button"
                    class="rr__fila-quitar"
                    :disabled="!editable"
                    aria-label="Quitar el bucle"
                    @click="quitar(fila.ruta)"
                  >
                    ✕
                  </button>
                </div>
                <div
                  v-else
                  class="rr__fila rr__fila--fin"
                  :style="{ '--nivel': fila.nivel }"
                >
                  fin del bucle
                </div>
              </template>
            </div>
            <p v-if="destino.length" class="rr__ayuda">
              Los bloques nuevos se agregan <strong>dentro del bucle</strong>
              marcado.
              <button type="button" class="rr__link" @click="destino = []">
                Volver al programa principal
              </button>
            </p>

            <div class="rr__controles">
              <q-btn
                no-caps
                unelevated
                class="dl-btn-main dl-btn-main--big"
                :label="ejecutando ? 'Ejecutando…' : '▶ Ejecutar'"
                :disable="!programa.length || ejecutando || enviando"
                :loading="enviando"
                @click="ejecutar"
              />
              <q-btn
                no-caps
                outline
                color="primary"
                label="↺ Reiniciar robot"
                :disable="ejecutando"
                @click="reiniciarTablero(false)"
              />
              <q-btn
                no-caps
                flat
                label="Deshacer"
                :disable="!editable || !programa.length"
                @click="deshacer"
              />
              <q-btn
                no-caps
                flat
                label="Borrar todo"
                :disable="!editable || !programa.length"
                @click="borrarTodo"
              />
            </div>
            <label class="rr__veloz">
              <q-toggle v-model="rapido" color="primary" dense />
              Velocidad rápida
            </label>
          </section>
        </div>
      </template>
    </div>
  </q-page>
</template>

<script setup>
import { computed, onMounted, onUnmounted, ref } from 'vue'

import {
  enviarRuta,
  fetchDesbloqueado,
  fetchMisResultados,
  fetchNiveles
} from '@/data/minigameRepository'
import { fetchExpo } from '@/data/challengeRepository'
import {
  MAX_ANIDADO,
  MAX_BLOQUES,
  MAX_REPETICIONES,
  contarBloques,
  simular
} from '@/lib/rutaRobot'

// Nivel de práctica: se juega solo en el navegador, sin puntos.
const PRACTICA = {
  id: 'practica',
  orden: 0,
  nombre: 'Práctica',
  consejo: 'Probá los bloques sin presión: acá no se suman puntos.',
  n: 5,
  inicio: 20,
  rumbo: 0,
  meta: 4,
  muros: [16, 13],
  estrellas: [12],
  par: 8
}

const NOMBRES = {
  A: '⬆ Avanzar',
  I: '↶ Girar a la izquierda',
  D: '↷ Girar a la derecha'
}

const cargando = ref(true)
const errorCarga = ref(null)
const desbloqueado = ref(false)
const desafioId = ref(null)
const niveles = ref([])
const resultados = ref({})
const nivelActual = ref(null)

const programa = ref([])
const destino = ref([]) // ruta (índices) del bucle donde se agregan bloques
const pos = ref(0)
const rumbo = ref(0)
const huellas = ref([])
const recogidas = ref([])
const choque = ref(false)
const enMeta = ref(false)
const ejecutando = ref(false)
const rapido = ref(false)
const mensaje = ref('Armá tu programa y tocá Ejecutar.')
const tonoMensaje = ref('neutro')
const enviando = ref(false)
const errorEnvio = ref(null)
const resultadoServidor = ref(null)
const celebrando = ref(false)
const confeti = ref([])

let reloj = null
let tiempoConfeti = null

const esPractica = computed(() => nivelActual.value?.id === PRACTICA.id)
const totalPuntos = computed(() =>
  Object.values(resultados.value).reduce((suma, r) => suma + r.puntos, 0)
)
const bloquesUsados = computed(() => contarBloques(programa.value))
const editable = computed(() => !ejecutando.value && !enviando.value)
const indiceActual = computed(() =>
  niveles.value.findIndex(n => n.id === nivelActual.value?.id)
)
const haySiguiente = computed(
  () => !esPractica.value && indiceActual.value < niveles.value.length - 1
)

function nivelDisponible(i) {
  if (!desbloqueado.value) return false
  if (i === 0) return true
  return !!resultados.value[niveles.value[i - 1].id]
}

function igual(a, b) {
  return a.length === b.length && a.every((v, i) => v === b[i])
}

// Lista del programa en la ruta indicada (la raíz es []).
function listaEn(ruta) {
  let lista = programa.value
  for (const i of ruta) lista = lista[i].p
  return lista
}

// Filas para mostrar el programa con sangría (bucles incluidos).
const filas = computed(() => {
  const salida = []
  function recorrer(lista, ruta, nivel) {
    lista.forEach((bloque, i) => {
      const r = [...ruta, i]
      const clave = r.join('-')
      if (typeof bloque === 'string') {
        salida.push({ tipo: 'bloque', bloque, ruta: r, nivel, clave })
      } else {
        salida.push({ tipo: 'bucle', bloque, ruta: r, nivel, clave })
        recorrer(bloque.p, r, nivel + 1)
        salida.push({ tipo: 'fin', ruta: r, nivel, clave: clave + '-fin' })
      }
    })
  }
  recorrer(programa.value, [], 0)
  return salida
})

function agregar(tipo) {
  if (!editable.value || bloquesUsados.value >= MAX_BLOQUES) return
  resultadoServidor.value = null
  const lista = listaEn(destino.value)
  if (tipo === 'R') {
    if (destino.value.length >= MAX_ANIDADO) return
    lista.push({ r: 2, p: [] })
    destino.value = [...destino.value, lista.length - 1]
  } else {
    lista.push(tipo)
  }
}

function quitar(ruta) {
  if (!editable.value) return
  const padre = listaEn(ruta.slice(0, -1))
  padre.splice(ruta[ruta.length - 1], 1)
  // Si el destino quedó dentro de lo borrado, se vuelve al padre.
  if (
    destino.value.length >= ruta.length &&
    ruta.every((v, i) => destino.value[i] === v)
  ) {
    destino.value = ruta.slice(0, -1)
  }
  resultadoServidor.value = null
}

function deshacer() {
  if (!editable.value) return
  const lista = listaEn(destino.value)
  if (lista.length) {
    lista.pop()
  } else if (destino.value.length) {
    destino.value = destino.value.slice(0, -1)
  } else {
    return
  }
  resultadoServidor.value = null
}

function borrarTodo() {
  if (!editable.value) return
  programa.value = []
  destino.value = []
  resultadoServidor.value = null
}

function detener() {
  clearInterval(reloj)
  reloj = null
  ejecutando.value = false
}

function reiniciarTablero(limpiarMensaje) {
  detener()
  clearTimeout(tiempoConfeti)
  celebrando.value = false
  const nivel = nivelActual.value
  if (!nivel) return
  pos.value = nivel.inicio
  rumbo.value = nivel.rumbo
  huellas.value = [nivel.inicio]
  recogidas.value = []
  choque.value = false
  enMeta.value = false
  errorEnvio.value = null
  if (limpiarMensaje) {
    resultadoServidor.value = null
    mensaje.value = 'Armá tu programa y tocá Ejecutar.'
    tonoMensaje.value = 'neutro'
  }
}

function elegir(nivel) {
  detener()
  nivelActual.value = nivel
  programa.value = []
  destino.value = []
  resultadoServidor.value = null
  mensaje.value = 'Armá tu programa y tocá Ejecutar.'
  tonoMensaje.value = 'neutro'
  reiniciarTablero(false)
}

function irAlSiguiente() {
  const siguiente = niveles.value[indiceActual.value + 1]
  if (siguiente && nivelDisponible(indiceActual.value + 1)) elegir(siguiente)
}

function lanzarConfeti() {
  const emojis = ['🎉', '⭐', '✨', '🎊', '🌟']
  confeti.value = Array.from({ length: 22 }, (_, i) => ({
    id: i,
    x: Math.round(Math.random() * 92) + 2,
    d: Math.round(Math.random() * 80) / 100,
    s: 1 + Math.round(Math.random() * 10) / 10,
    e: emojis[i % emojis.length]
  }))
  celebrando.value = true
  clearTimeout(tiempoConfeti)
  tiempoConfeti = setTimeout(() => {
    celebrando.value = false
  }, 2600)
}

function ejecutar() {
  if (!programa.value.length || ejecutando.value) return
  reiniciarTablero(false)
  resultadoServidor.value = null
  let recorrido
  try {
    recorrido = simular(nivelActual.value, programa.value)
  } catch (err) {
    mensaje.value = err?.message ?? 'El programa no es válido.'
    tonoMensaje.value = 'error'
    return
  }
  ejecutando.value = true
  mensaje.value = 'Ejecutando tu programa…'
  tonoMensaje.value = 'neutro'
  let i = 0
  reloj = setInterval(
    () => {
      i++
      const estado = recorrido.camino[i]
      if (!estado) {
        terminar(recorrido)
        return
      }
      pos.value = estado.pos
      rumbo.value = estado.rumbo
      if (!huellas.value.includes(estado.pos)) huellas.value.push(estado.pos)
      if (
        nivelActual.value.estrellas.includes(estado.pos) &&
        !recogidas.value.includes(estado.pos)
      ) {
        recogidas.value.push(estado.pos)
      }
      if (estado.choco) {
        terminar(recorrido)
      } else if (i >= recorrido.camino.length - 1) {
        terminar(recorrido)
      }
    },
    rapido.value ? 90 : 240
  )
}

async function terminar(recorrido) {
  detener()
  if (recorrido.choco) {
    choque.value = true
    mensaje.value =
      '¡Ups! El robot chocó con un obstáculo o con el borde. Revisá tu programa.'
    tonoMensaje.value = 'error'
    return
  }
  if (!recorrido.llego) {
    mensaje.value =
      'El programa terminó antes de llegar a la meta. ¡Agregá más bloques!'
    tonoMensaje.value = 'aviso'
    return
  }
  enMeta.value = true
  lanzarConfeti()
  if (esPractica.value) {
    mensaje.value = `¡Llegaste a la meta con ${bloquesUsados.value} bloques! Probá los niveles con puntos cuando se desbloqueen.`
    tonoMensaje.value = 'ok'
    return
  }
  mensaje.value = '¡Llegaste a la meta! Guardando tu resultado…'
  tonoMensaje.value = 'ok'
  await enviar()
}

async function enviar() {
  if (enviando.value) return
  enviando.value = true
  errorEnvio.value = null
  try {
    const resultado = await enviarRuta(
      nivelActual.value.id,
      JSON.parse(JSON.stringify(programa.value))
    )
    resultadoServidor.value = resultado
    resultados.value = {
      ...resultados.value,
      [nivelActual.value.id]: {
        puntos: resultado.mejorPuntos,
        bloques:
          resultados.value[nivelActual.value.id]?.bloques ?? resultado.bloques,
        estrellas: Math.max(
          resultado.estrellas,
          resultados.value[nivelActual.value.id]?.estrellas ?? 0
        )
      }
    }
    mensaje.value = resultado.mejoro
      ? '¡Resultado guardado!'
      : 'Resultado guardado (tu mejor puntaje de este nivel sigue siendo mayor).'
    tonoMensaje.value = 'ok'
  } catch (err) {
    errorEnvio.value = err?.message ?? 'No se pudo enviar tu ruta.'
    mensaje.value = 'No pudimos guardar tu resultado.'
    tonoMensaje.value = 'error'
  } finally {
    enviando.value = false
  }
}

async function cargar() {
  cargando.value = true
  errorCarga.value = null
  try {
    const [lista, dados, abierto, expo] = await Promise.all([
      fetchNiveles(),
      fetchMisResultados().catch(() => ({})),
      fetchDesbloqueado().catch(() => false),
      fetchExpo().catch(() => ({ challenges: [] }))
    ])
    niveles.value = lista
    resultados.value = dados
    desbloqueado.value = abierto
    desafioId.value =
      expo.challenges?.find(c => c.minijuego)?.id ??
      expo.challenges?.[0]?.id ??
      null
    if (!lista.length) {
      throw new Error('Todavía no hay niveles cargados en el minijuego.')
    }
    // Se arranca en el primer nivel sin superar (o en la práctica si está bloqueado).
    const primero = abierto
      ? (lista.find((n, i) => nivelDisponible(i) && !dados[n.id]) ??
        lista[lista.length - 1])
      : PRACTICA
    elegir(primero)
  } catch (err) {
    errorCarga.value = err?.message ?? 'No se pudo cargar el minijuego.'
  } finally {
    cargando.value = false
  }
}

onMounted(cargar)
onUnmounted(() => {
  detener()
  clearTimeout(tiempoConfeti)
})
</script>

<style lang="scss" scoped>
.rr {
  &__inner {
    max-width: 1100px;
  }

  &__back {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    font-weight: 800;
    text-decoration: none;
    text-transform: uppercase;
    font-size: 13px;
    letter-spacing: 0.4px;
    color: $dl-ink;
    margin-bottom: 14px;
  }

  &__head {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 16px;
    flex-wrap: wrap;
    margin-bottom: 18px;
  }

  &__eyebrow {
    font-size: 13px;
    font-weight: 800;
    text-transform: uppercase;
    letter-spacing: 0.6px;
    color: $dl-green-dark;
  }

  &__title {
    margin: 4px 0 8px;
    color: $dl-ink-dark;
  }

  &__lead {
    max-width: 640px;
    margin: 0;
    line-height: 1.5;
    color: $dl-ink;
  }

  &__score {
    display: flex;
    flex-direction: column;
    align-items: center;
    background: $dl-surface;
    border: 2px solid $dl-gray;
    border-radius: 16px;
    padding: 10px 18px;
    min-width: 130px;
  }

  &__score-value {
    font-size: 34px;
    font-weight: 900;
    color: $dl-green-dark;
    line-height: 1;
  }

  &__score-label {
    font-size: 12px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.3px;
    color: #a3a3a3;
  }

  &__estado {
    text-align: center;
    padding: 40px 0;
    color: #a3a3a3;
  }

  &__bloqueo {
    display: flex;
    gap: 14px;
    align-items: flex-start;
    background: #211b0b;
    border: 2px solid #6b5a1c;
    border-radius: 16px;
    padding: 16px;
    margin-bottom: 18px;
    color: $dl-ink-dark;

    p {
      margin: 4px 0 10px;
      color: $dl-ink;
      line-height: 1.45;
    }
  }

  /* ---- niveles ---- */
  &__niveles {
    display: flex;
    gap: 10px;
    overflow-x: auto;
    padding: 4px 2px 12px;
    margin-bottom: 8px;
    scroll-snap-type: x proximity;
  }

  &__nivel {
    flex: 0 0 auto;
    scroll-snap-align: start;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2px;
    min-width: 108px;
    padding: 10px 12px;
    background: $dl-surface;
    border: 2px solid $dl-gray;
    border-radius: 14px;
    color: $dl-ink-dark;
    cursor: pointer;
    font-family: inherit;

    &.is-activo {
      border-color: $dl-yellow;
      background: #2a2410;
    }

    &.is-bloqueado {
      opacity: 0.55;
      cursor: not-allowed;
    }
  }

  &__nivel-num {
    font-size: 20px;
    font-weight: 900;
    color: $dl-green-dark;
  }

  &__nivel-nombre {
    font-size: 13px;
    font-weight: 800;
    text-align: center;
  }

  &__nivel-info {
    font-size: 11px;
    color: #a3a3a3;
    white-space: nowrap;
  }

  /* ---- juego ---- */
  &__juego {
    display: grid;
    grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
    gap: 24px;
    align-items: start;
  }

  &__subtitulo {
    margin: 0 0 10px;
    color: $dl-ink-dark;
  }

  &__consejo {
    display: flex;
    gap: 8px;
    align-items: flex-start;
    margin: 0 0 10px;
    color: $dl-ink;
    font-size: 14px;

    .q-icon {
      color: $dl-green-dark;
      margin-top: 2px;
    }
  }

  &__tablero-marco {
    position: relative;
    background: $dl-surface;
    border: 2px solid $dl-gray;
    border-radius: 18px;
    padding: 10px;
    max-width: 28rem;
    margin: 0 auto;
  }

  &__tablero {
    --gap: 4px;
    position: relative;
    display: grid;
    grid-template-columns: repeat(var(--n), 1fr);
    gap: var(--gap);
    aspect-ratio: 1;

    &.is-choque {
      animation: rr-temblor 0.4s ease;
    }
  }

  &__casilla {
    display: grid;
    place-items: center;
    aspect-ratio: 1;
    background: #1d1d1d;
    border-radius: 8px;
    font-size: clamp(1rem, 5vw, 1.7rem);
    position: relative;

    &.is-muro {
      background: #3a2a1a;
    }

    &.is-meta {
      background: #2a2410;
      box-shadow: inset 0 0 0 2px $dl-yellow;
    }

    &.is-huella::after {
      content: '';
      position: absolute;
      width: 22%;
      height: 22%;
      border-radius: 50%;
      background: rgba(248, 200, 72, 0.35);
    }
  }

  &__estrella {
    animation: rr-brillo 1.6s ease-in-out infinite;
  }

  &__inicio {
    color: #5a5a5a;
    font-size: 0.8rem;
  }

  &__robot {
    position: absolute;
    top: 0;
    left: 0;
    width: calc((100% - (var(--n) - 1) * var(--gap)) / var(--n));
    aspect-ratio: 1;
    display: grid;
    place-items: center;
    transform: translate(
      calc(var(--col) * (100% + var(--gap))),
      calc(var(--fila) * (100% + var(--gap)))
    );
    transition: transform 0.2s ease;
    pointer-events: none;
    z-index: 2;
  }

  &__robot-cara {
    font-size: clamp(1.2rem, 6vw, 2.1rem);
    filter: drop-shadow(0 2px 3px rgba(0, 0, 0, 0.6));
  }

  &__robot-flecha {
    position: absolute;
    inset: 0;
    display: grid;
    justify-items: center;
    align-items: start;
    transform: rotate(calc(var(--rumbo) * 90deg));
    transition: transform 0.2s ease;

    span {
      font-size: clamp(0.55rem, 2.2vw, 0.85rem);
      color: $dl-yellow;
      line-height: 1;
    }
  }

  &__leyenda {
    display: flex;
    flex-wrap: wrap;
    gap: 6px 14px;
    justify-content: center;
    margin: 10px 0;
    font-size: 12px;
    color: #a3a3a3;
  }

  &__mensaje {
    margin: 8px 0;
    padding: 10px 12px;
    border-radius: 12px;
    background: #1d1d1d;
    color: $dl-ink;
    font-weight: 700;

    &.is-ok {
      background: #10240a;
      color: #9be36b;
    }

    &.is-error {
      background: #3a1414;
      color: #ff8a8a;
    }

    &.is-aviso {
      background: #211b0b;
      color: #ffd88a;
    }
  }

  &__resultado {
    background: #211b0b;
    border: 2px solid #6b5a1c;
    border-radius: 14px;
    padding: 12px 14px;
    color: $dl-ink;

    p {
      margin: 6px 0;
      font-size: 14px;
    }

    strong {
      color: $dl-green-dark;
    }

    &.is-record {
      border-color: $dl-yellow;
      animation: rr-latido 0.9s ease 2;
    }
  }

  &__resultado-acciones {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin-top: 8px;
  }

  /* ---- paleta ---- */
  &__paleta {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 8px;
    margin-bottom: 10px;
  }

  &__bloque {
    display: flex;
    align-items: center;
    gap: 10px;
    min-height: 54px;
    padding: 8px 12px;
    border: none;
    border-radius: 14px;
    font-family: inherit;
    font-weight: 800;
    font-size: 14px;
    color: #1a1a1a;
    cursor: pointer;
    text-align: left;
    box-shadow: 0 4px 0 rgba(0, 0, 0, 0.45);
    transition: transform 0.08s ease;

    &:active:not(:disabled) {
      transform: translateY(2px);
      box-shadow: 0 2px 0 rgba(0, 0, 0, 0.45);
    }

    &:disabled {
      opacity: 0.4;
      cursor: not-allowed;
    }

    &--a {
      background: #f8c848;
    }

    &--i {
      background: #7cc7f2;
    }

    &--d {
      background: #ff9fb2;
    }

    &--r {
      background: #b9a0ff;
    }
  }

  &__bloque-icono {
    font-size: 22px;
    line-height: 1;
  }

  &__contador {
    display: flex;
    justify-content: space-between;
    flex-wrap: wrap;
    gap: 6px;
    font-size: 13px;
    color: #a3a3a3;
    margin-bottom: 8px;
  }

  &__par {
    display: inline-flex;
    align-items: center;
    gap: 4px;
  }

  &__lista {
    background: $dl-surface;
    border: 2px solid $dl-gray;
    border-radius: 14px;
    padding: 8px;
    max-height: 18rem;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  &__vacio {
    margin: 6px 4px;
    color: #8f8f8f;
    font-size: 13px;
  }

  &__fila {
    --nivel: 0;
    display: flex;
    align-items: center;
    gap: 8px;
    margin-left: calc(var(--nivel) * 18px);
    padding: 6px 10px;
    border-radius: 10px;
    background: #1d1d1d;
    font-size: 14px;
    font-weight: 700;
    color: $dl-ink-dark;
    font-family: inherit;
    border: 2px solid transparent;
    text-align: left;

    &--raiz {
      margin-left: 0;
      background: transparent;
      color: #a3a3a3;
      cursor: pointer;
      font-size: 12px;

      &.is-destino {
        border-color: $dl-yellow;
        color: $dl-green-dark;
      }
    }

    &--bloque {
      justify-content: space-between;
    }

    &--bucle {
      background: #241d36;
      color: #d9c8ff;

      &.is-destino {
        border-color: #b9a0ff;
      }
    }

    &--fin {
      background: transparent;
      color: #8f8f8f;
      font-size: 11px;
      padding: 0 10px;
    }
  }

  &__fila-texto {
    flex: 1 1 auto;

    &--btn {
      background: none;
      border: none;
      color: inherit;
      font: inherit;
      text-align: left;
      cursor: pointer;
      padding: 0;
    }
  }

  &__fila-quitar {
    border: none;
    background: #2a2a2a;
    color: #ff8a8a;
    border-radius: 8px;
    width: 28px;
    height: 28px;
    cursor: pointer;
    font-weight: 900;

    &:disabled {
      opacity: 0.4;
    }
  }

  &__veces {
    display: inline-flex;
    align-items: center;
    gap: 6px;

    button {
      width: 28px;
      height: 28px;
      border-radius: 8px;
      border: none;
      background: #3a2f5c;
      color: #ffffff;
      font-weight: 900;
      cursor: pointer;

      &:disabled {
        opacity: 0.4;
      }
    }
  }

  &__ayuda {
    margin: 8px 0 0;
    font-size: 13px;
    color: #d9c8ff;
  }

  &__link {
    background: none;
    border: none;
    padding: 0;
    color: $dl-green-dark;
    font: inherit;
    font-weight: 800;
    text-decoration: underline;
    cursor: pointer;
  }

  &__controles {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin-top: 12px;
  }

  &__veloz {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    margin-top: 10px;
    font-size: 13px;
    color: #a3a3a3;
  }

  &__confeti {
    position: absolute;
    inset: 0;
    overflow: hidden;
    pointer-events: none;
    z-index: 5;

    span {
      position: absolute;
      top: -2rem;
      animation: rr-caer 2.2s ease-in forwards;
    }
  }
}

@keyframes rr-caer {
  to {
    transform: translateY(26rem) rotate(260deg);
    opacity: 0;
  }
}

@keyframes rr-temblor {
  0%,
  100% {
    transform: translateX(0);
  }
  25% {
    transform: translateX(-6px);
  }
  75% {
    transform: translateX(6px);
  }
}

@keyframes rr-brillo {
  0%,
  100% {
    transform: scale(1);
  }
  50% {
    transform: scale(1.18);
  }
}

@keyframes rr-latido {
  0%,
  100% {
    transform: scale(1);
  }
  50% {
    transform: scale(1.02);
  }
}

@media (max-width: 860px) {
  .rr__juego {
    grid-template-columns: minmax(0, 1fr);
  }
}

@media (max-width: 420px) {
  .rr__bloque {
    font-size: 13px;
    padding: 8px;
  }

  .rr__score {
    width: 100%;
    flex-direction: row;
    justify-content: center;
    gap: 10px;
  }
}

@media (prefers-reduced-motion: reduce) {
  .rr__estrella,
  .rr__resultado.is-record,
  .rr__tablero.is-choque,
  .rr__confeti span {
    animation: none;
  }

  .rr__robot,
  .rr__robot-flecha {
    transition: none;
  }
}
</style>
