<template>
  <q-page class="dl-page cb" :class="{ 'cb--juego': jugando }">
    <div class="dl-page__inner cb__inner">
      <router-link v-if="!jugando" :to="{ name: 'expo' }" class="cb__back">
        <q-icon name="arrow_back" size="18px" />
        Volver a la expo
      </router-link>

      <header v-if="!jugando && fase !== 'fin'" class="cb__head">
        <div class="cb__head-texto">
          <span class="cb__eyebrow">Minijuego de la expo</span>
          <h1 class="cb__title">Cazabugs 🐛</h1>
          <p class="cb__lead">
            ¡Hay bugs en el código! Tocalos antes de que se escondan. Con
            <strong>rachas</strong> los puntos se multiplican, pero
            <strong>no toques a Usagi</strong>.
          </p>
        </div>
        <div class="cb__score" aria-live="polite">
          <span class="cb__score-value">{{ mejor?.puntos ?? 0 }}</span>
          <span class="cb__score-label">pts de ranking</span>
        </div>
      </header>

      <div v-if="cargando" class="cb__estado">
        <q-spinner color="primary" size="34px" />
        <p>Cargando el minijuego…</p>
      </div>

      <template v-else>
        <q-banner v-if="errorCarga" rounded class="dl-error-banner q-mb-md">
          <q-icon name="error_outline" size="22px" color="negative" />
          {{ errorCarga }}
        </q-banner>

        <!-- ============ MENÚ ============ -->
        <section v-if="fase === 'menu'" class="cb__menu">
          <div v-if="!desbloqueado" class="cb__bloqueo">
            <q-icon name="lock" size="24px" />
            <div>
              <strong
                >Las rondas con puntos se desbloquean al terminar el Gran
                desafío.</strong
              >
              Mientras tanto, practicá todo lo que quieras (sin puntos).
              <q-btn
                v-if="desafioId"
                no-caps
                flat
                dense
                color="primary"
                label="Ir al desafío"
                :to="{ name: 'desafio', params: { challengeId: desafioId } }"
              />
            </div>
          </div>

          <div class="cb__tarjetas">
            <article class="cb__bicho" title="Bug: 10 puntos">
              <span class="cb__bicho-cara">🐛</span>
              <strong>Bug</strong>
              <span>+10</span>
            </article>
            <article
              class="cb__bicho"
              title="Veloz: 20 puntos, se esconde rápido"
            >
              <span class="cb__bicho-cara">🦟</span>
              <strong>Veloz</strong>
              <span>+20</span>
            </article>
            <article
              class="cb__bicho"
              title="Gordo: 30 puntos, hay que tocarlo 2 veces"
            >
              <span class="cb__bicho-cara">🪲</span>
              <strong>Gordo</strong>
              <span>+30</span>
            </article>
            <article
              class="cb__bicho cb__bicho--oro"
              title="Dorado: 60 puntos, dura muy poco"
            >
              <span class="cb__bicho-cara">🐞</span>
              <strong>Dorado</strong>
              <span>+60</span>
            </article>
            <article
              class="cb__bicho cb__bicho--amigo"
              title="Usagi: no tocar, resta 25 puntos"
            >
              <img :src="usagiImg" alt="Usagi" class="cb__amigo-img" />
              <strong>Usagi</strong>
              <span>−25</span>
            </article>
          </div>

          <ul class="cb__reglas">
            <li>
              ⏱ <strong>45 segundos</strong>. El gordo 🪲 necesita 2 toques y el
              veloz 🦟 se esconde rápido.
            </li>
            <li>
              🔥 <strong>Racha</strong>: ×2 desde el 5.º bicho seguido, ×3 desde
              el 9.º y ×4 desde el 13.º.
            </li>
            <li>
              ❌ Un fallo o tocar a <strong>Usagi</strong> corta la racha.
            </li>
            <li>
              💨 Cada bicho que se te escapa sin tocarlo resta
              <strong>5 puntos</strong> y corta la racha.
            </li>
            <li>
              🏆 Cada 40 puntos suman 1 de ranking (máx. 100).
              <strong>Hay una sola ronda con puntos</strong>: ¡aprovechala!
            </li>
          </ul>

          <div v-if="miTotal" class="cb__mejor">
            Tu total en la expo: <strong>{{ miTotal.total }} pts</strong> (Gran
            desafío {{ miTotal.gran }} + Cazabugs {{ miTotal.mini }})
            <span v-if="miTotal.posicion"> · puesto {{ miTotal.posicion }}</span>
          </div>
          <div v-if="mejor" class="cb__mejor">
            Tu ronda con puntos: <strong>{{ mejor.puntaje }}</strong> puntos ({{
              mejor.puntos
            }}
            de ranking) · racha {{ mejor.mejorRacha }}
          </div>

          <div class="cb__acciones">
            <q-btn
              no-caps
              unelevated
              class="dl-btn-main dl-btn-main--big"
              :label="
                rondaUsada
                  ? 'Ya usaste tu ronda con puntos'
                  : iniciando
                    ? 'Preparando…'
                    : '🎮 Jugar con puntos (1 sola vez)'
              "
              :disable="!desbloqueado || iniciando || rondaUsada"
              :loading="iniciando"
              @click="empezar(true)"
            />
            <q-btn
              no-caps
              outline
              color="primary"
              label="Practicar (sin puntos)"
              :disable="iniciando"
              @click="empezar(false)"
            />
          </div>
          <label class="cb__sonido">
            <q-toggle v-model="sonido" color="primary" dense />
            Sonido y vibración
          </label>
        </section>

        <!-- ============ JUEGO ============ -->
        <section v-else-if="jugando" class="cb__juego">
          <div class="cb__lateral">
            <div class="cb__hud">
              <div class="cb__hud-item">
                <span class="cb__hud-label">Puntos</span>
                <span class="cb__hud-valor">{{ hud.puntaje }}</span>
              </div>
              <div class="cb__racha" :class="{ 'is-fuego': hud.racha >= 5 }">
                <span class="cb__racha-mult">×{{ hud.mult }}</span>
                <span class="cb__racha-n">🔥 {{ hud.racha }}</span>
              </div>
              <div class="cb__hud-item">
                <span class="cb__hud-label">Tiempo</span>
                <span
                  class="cb__hud-valor"
                  :class="{ 'is-poco': segundos <= 10 }"
                  >{{ segundos }}</span
                >
              </div>
            </div>
            <div class="cb__barra">
              <div
                class="cb__barra-fill"
                :class="{ 'is-poco': segundos <= 10 }"
                :style="{ width: `${progreso}%` }"
              />
            </div>
            <div class="cb__lateral-pie">
              <span class="cb__pista">
                {{ oficial ? 'Ronda con puntos' : 'Práctica (sin puntos)' }} ·
                ¡no toques a Usagi!
              </span>
              <button type="button" class="cb__salir" @click="salir">
                ✕ Salir
              </button>
            </div>
          </div>

          <div class="cb__cuerpo">
            <div
              class="cb__tablero"
              :class="{ 'is-golpe': sacudir, 'is-fuego': hud.racha >= 9 }"
            >
              <button
                v-for="(celda, i) in celdas"
                :key="i"
                type="button"
                class="cb__agujero"
                :class="{
                  'is-amigo': celda.bicho?.tipo === 'amigo',
                  'is-dorado': celda.bicho?.tipo === 'dorado',
                  'is-por-irse': celda.porIrse
                }"
                :aria-label="`Casilla ${i + 1}`"
                @pointerdown.prevent="tocar(i)"
              >
                <span class="cb__hoyo" />
                <span
                  v-if="celda.bicho"
                  :key="celda.bicho.i"
                  class="cb__criatura"
                  :class="`cb__criatura--${celda.bicho.tipo}`"
                >
                  <img
                    v-if="celda.bicho.tipo === 'amigo'"
                    :src="usagiImg"
                    alt="Usagi"
                    class="cb__amigo-img"
                  />
                  <template v-else>{{ EMOJI[celda.bicho.tipo] }}</template>
                  <span v-if="celda.bicho.tipo === 'grande'" class="cb__vida">
                    <i :class="{ 'is-roto': celda.golpes >= 1 }" />
                    <i />
                  </span>
                </span>
                <span
                  v-if="celda.efecto"
                  :key="celda.efecto"
                  class="cb__efecto"
                  >{{ celda.efectoEmoji }}</span
                >
              </button>

              <span
                v-for="p in pops"
                :key="p.id"
                class="cb__pop"
                :class="p.clase"
                :style="{ left: p.x + '%', top: p.y + '%' }"
                >{{ p.texto }}</span
              >

              <div v-if="fase === 'cuenta'" class="cb__cuenta">
                <span :key="cuenta">{{ cuenta > 0 ? cuenta : '¡YA!' }}</span>
              </div>
            </div>
          </div>
        </section>

        <!-- ============ FIN ============ -->
        <section v-else class="cb__fin" :class="`is-${medalla.clase}`">
          <div class="cb__fin-cabeza">
            <div class="cb__medalla">{{ medalla.emoji }}</div>
            <div>
              <h2 class="cb__fin-titulo">{{ medalla.titulo }}</h2>
              <p class="cb__fin-puntaje">
                <strong>{{ resumen.puntaje }}</strong> puntos
              </p>
            </div>
          </div>
          <ul class="cb__fin-datos">
            <li>
              🎯 Cazados: <strong>{{ resumen.aciertos }}</strong>
            </li>
            <li>
              💨 En vacío: <strong>{{ resumen.fallos }}</strong>
            </li>
            <li>
              🐌 Escapados: <strong>{{ resumen.escapados }}</strong>
            </li>
            <li>
              😿 Usagi: <strong>{{ resumen.amigos }}</strong>
            </li>
            <li>
              🔥 Racha: <strong>{{ resumen.mejorRacha }}</strong>
            </li>
          </ul>

          <template v-if="oficial">
            <p v-if="enviando" class="cb__fin-aviso">Guardando tu ronda…</p>
            <p v-else-if="errorEnvio" class="cb__fin-aviso is-error">
              {{ errorEnvio }}
              <q-btn
                flat
                dense
                no-caps
                color="primary"
                label="Reintentar"
                @click="enviar"
              />
            </p>
            <div v-else-if="oficialRes" class="cb__oficial">
              <strong>{{
                oficialRes.mejoro ? '¡Ronda guardada!' : 'Ronda guardada'
              }}</strong>
              <p>
                Puntaje oficial: <strong>{{ oficialRes.puntaje }}</strong> → +{{
                  oficialRes.puntos
                }}
                pts de ranking, que ya suman a tu total. Esa fue tu única ronda
                con puntos; podés seguir practicando.
              </p>
              <p v-if="miTotal">
                Tu total en la expo ahora:
                <strong>{{ miTotal.total }} pts</strong> (Gran desafío
                {{ miTotal.gran }} + Cazabugs {{ miTotal.mini }}<template
                  v-if="miTotal.posicion"
                  >, puesto {{ miTotal.posicion }}</template
                >).
              </p>
            </div>
          </template>
          <p v-else class="cb__fin-aviso">
            En la práctica no se suman puntos. ¡Probá una ronda con puntos!
          </p>

          <div class="cb__acciones">
            <q-btn
              no-caps
              unelevated
              class="dl-btn-main dl-btn-main--big"
              :label="
                rondaUsada ? '🔄 Practicar otra vez' : '🔄 Jugar otra vez'
              "
              :disable="enviando"
              @click="empezar(!rondaUsada && oficial && desbloqueado)"
            />
            <q-btn
              no-caps
              outline
              color="primary"
              label="Volver al menú"
              :disable="enviando"
              @click="fase = 'menu'"
            />
          </div>
        </section>
      </template>
    </div>
  </q-page>
</template>

<script setup>
import { computed, onMounted, onUnmounted, reactive, ref } from 'vue'

import usagiImg from '@/assets/amigos/usagi-de-pie.webp'
import { fetchExpo, fetchRanking } from '@/data/challengeRepository'
import {
  enviarRonda,
  fetchDesbloqueado,
  fetchMiMejor,
  iniciarRonda
} from '@/data/minigameRepository'
import {
  CELDAS,
  DURACION_MS,
  INTERVALO_MIN_MS,
  cronograma,
  crearMotor,
  multiplicador
} from '@/lib/cazabugs'

const EMOJI = { bug: '🐛', rapido: '🦟', grande: '🪲', dorado: '🐞' }

const cargando = ref(true)
const errorCarga = ref(null)
const desbloqueado = ref(false)
const desafioId = ref(null)
const mejor = ref(null)
const iniciando = ref(false)
const sonido = ref(true)

const fase = ref('menu') // menu | cuenta | jugando | fin
const oficial = ref(false)
const cuenta = ref(3)
const segundos = ref(45)
const progreso = ref(100)
const sacudir = ref(false)
const hud = reactive({ puntaje: 0, racha: 0, mult: 1 })
const celdas = ref(crearCeldas())
const pops = ref([])
const resumen = reactive({
  puntaje: 0,
  aciertos: 0,
  fallos: 0,
  amigos: 0,
  escapados: 0,
  mejorRacha: 0
})
const rondaUsada = ref(false)
const miTotal = ref(null)
const enviando = ref(false)
const errorEnvio = ref(null)
const oficialRes = ref(null)

let motor = null
let ronda = null
let toques = []
let t0 = 0
let ultimoToque = -1000
let raf = 0
let popId = 0
let audio = null
let temporizadores = []

function crearCeldas() {
  return Array.from({ length: CELDAS }, () => ({
    bicho: null,
    golpes: 0,
    porIrse: false,
    efecto: 0,
    efectoEmoji: ''
  }))
}

const jugando = computed(
  () => fase.value === 'cuenta' || fase.value === 'jugando'
)

const medalla = computed(() => {
  const p = resumen.puntaje
  if (p >= 3200)
    return { emoji: '💎', titulo: '¡Maestro de los bugs!', clase: 'diamante' }
  if (p >= 2000)
    return { emoji: '🥇', titulo: '¡Cazador de oro!', clase: 'oro' }
  if (p >= 1000) return { emoji: '🥈', titulo: '¡Gran ronda!', clase: 'plata' }
  if (p >= 400)
    return { emoji: '🥉', titulo: '¡Buen comienzo!', clase: 'bronce' }
  return { emoji: '🐛', titulo: '¡Los bugs ganaron esta vez!', clase: 'bug' }
})

// ---------- sonido y vibración ----------
function iniciarAudio() {
  if (audio || !sonido.value) return
  try {
    const Contexto = window.AudioContext ?? window.webkitAudioContext
    if (Contexto) audio = new Contexto()
  } catch {
    audio = null
  }
}

function tono(
  frecuencia,
  duracion,
  tipo = 'sine',
  volumen = 0.12,
  retraso = 0
) {
  if (!sonido.value || !audio) return
  try {
    const osc = audio.createOscillator()
    const ganancia = audio.createGain()
    osc.type = tipo
    osc.frequency.value = frecuencia
    const inicio = audio.currentTime + retraso
    ganancia.gain.setValueAtTime(volumen, inicio)
    ganancia.gain.exponentialRampToValueAtTime(0.0001, inicio + duracion)
    osc.connect(ganancia).connect(audio.destination)
    osc.start(inicio)
    osc.stop(inicio + duracion)
  } catch {
    /* sin sonido */
  }
}

function vibrar(patron) {
  if (!sonido.value) return
  try {
    navigator.vibrate?.(patron)
  } catch {
    /* sin vibración */
  }
}

const SONIDOS = {
  acierto: racha => tono(520 + Math.min(racha, 12) * 40, 0.12, 'triangle'),
  dorado: () => {
    tono(880, 0.1, 'triangle')
    tono(1175, 0.1, 'triangle', 0.12, 0.08)
    tono(1568, 0.18, 'triangle', 0.12, 0.16)
  },
  golpe: () => tono(300, 0.08, 'square', 0.08),
  fallo: () => tono(180, 0.1, 'sine', 0.06),
  amigo: () => {
    tono(160, 0.25, 'sawtooth', 0.12)
    tono(120, 0.3, 'sawtooth', 0.12, 0.1)
  },
  cuenta: () => tono(440, 0.12, 'square', 0.08),
  ya: () => tono(880, 0.25, 'square', 0.1),
  fin: () => {
    tono(660, 0.15, 'triangle')
    tono(440, 0.3, 'triangle', 0.12, 0.15)
  }
}

// ---------- efectos visuales ----------
function agregarPop(celda, texto, clase) {
  const columna = celda % 3
  const fila = Math.floor(celda / 3)
  const id = ++popId
  pops.value.push({
    id,
    texto,
    clase,
    x: columna * 33.33 + 16.66,
    y: fila * 25 + 8
  })
  temporizadores.push(
    setTimeout(() => {
      pops.value = pops.value.filter(p => p.id !== id)
    }, 800)
  )
}

function efectoEnCelda(celda, emoji) {
  const c = celdas.value[celda]
  c.efecto++
  c.efectoEmoji = emoji
  temporizadores.push(
    setTimeout(() => {
      c.efecto = 0
      c.efectoEmoji = ''
    }, 350)
  )
}

function sacudirTablero() {
  sacudir.value = true
  temporizadores.push(
    setTimeout(() => {
      sacudir.value = false
    }, 350)
  )
}

// ---------- juego ----------
function sincronizarHud() {
  const e = motor.estado
  hud.puntaje = e.puntaje
  hud.racha = e.racha
  hud.mult = e.racha > 0 ? multiplicador(e.racha) : 1
}

function avisarEscapados(lista) {
  if (!lista?.length) return
  for (const b of lista) {
    agregarPop(b.celda, '−5', 'is-mal')
    efectoEnCelda(b.celda, '💨')
  }
  SONIDOS.fallo()
  vibrar(10)
  sincronizarHud()
}

function tocar(celda) {
  if (fase.value !== 'jugando') return
  const t = Math.round(performance.now() - t0)
  if (t < 0 || t >= DURACION_MS || t - ultimoToque < INTERVALO_MIN_MS) return
  ultimoToque = t
  toques.push([t, celda])
  const r = motor.tocar(t, celda)
  sincronizarHud()
  avisarEscapados(r.escapados)
  if (r.resultado === 'acierto') {
    const dorado = r.bicho.tipo === 'dorado'
    agregarPop(
      celda,
      `+${r.delta}${r.mult > 1 ? ` ×${r.mult}` : ''}`,
      dorado ? 'is-oro' : 'is-bien'
    )
    efectoEnCelda(celda, dorado ? '✨' : '💥')
    if (dorado) SONIDOS.dorado()
    else SONIDOS.acierto(motor.estado.racha)
    vibrar(12)
  } else if (r.resultado === 'golpe') {
    efectoEnCelda(celda, '💢')
    SONIDOS.golpe()
    vibrar(8)
  } else if (r.resultado === 'amigo') {
    agregarPop(celda, r.delta === 0 ? '¡Usagi!' : `${r.delta}`, 'is-mal')
    efectoEnCelda(celda, '😿')
    sacudirTablero()
    SONIDOS.amigo()
    vibrar([40, 40, 60])
  } else {
    efectoEnCelda(celda, '💨')
    SONIDOS.fallo()
  }
  // Se actualiza al instante lo que se ve en esa casilla.
  pintar(t)
}

function pintar(t) {
  const visibles = motor.activosEn(t)
  const porCelda = new Map(visibles.map(b => [b.celda, b]))
  for (let i = 0; i < CELDAS; i++) {
    const c = celdas.value[i]
    const b = porCelda.get(i) ?? null
    if ((c.bicho?.i ?? null) !== (b?.i ?? null)) {
      c.bicho = b
      c.golpes = 0
    }
    c.golpes = b ? motor.golpesDe(b.i) : 0
    c.porIrse = !!b && t > b.t + b.vida - 350
  }
}

function cuadro() {
  const t = performance.now() - t0
  if (t >= DURACION_MS) {
    terminar()
    return
  }
  avisarEscapados(motor.avanzar(t))
  pintar(t)
  segundos.value = Math.max(0, Math.ceil((DURACION_MS - t) / 1000))
  progreso.value = Math.max(0, 100 - (t / DURACION_MS) * 100)
  raf = requestAnimationFrame(cuadro)
}

function limpiarTemporizadores() {
  temporizadores.forEach(clearTimeout)
  temporizadores = []
}

async function empezar(conPuntos) {
  window.scrollTo(0, 0)
  limpiarTemporizadores()
  cancelAnimationFrame(raf)
  iniciarAudio()
  audio?.resume?.()
  errorEnvio.value = null
  oficialRes.value = null
  let semilla
  if (conPuntos) {
    iniciando.value = true
    try {
      ronda = await iniciarRonda()
      semilla = ronda.semilla
    } catch (err) {
      errorCarga.value = err?.message ?? 'No se pudo empezar la ronda.'
      if (/única ronda/i.test(errorCarga.value)) rondaUsada.value = true
      iniciando.value = false
      return
    } finally {
      iniciando.value = false
    }
    errorCarga.value = null
  } else {
    ronda = null
    semilla = 1 + Math.floor(Math.random() * 2147483000)
  }
  oficial.value = conPuntos
  motor = crearMotor(cronograma(semilla))
  toques = []
  ultimoToque = -1000
  celdas.value = crearCeldas()
  pops.value = []
  segundos.value = 45
  progreso.value = 100
  sincronizarHud()
  fase.value = 'cuenta'
  cuenta.value = 3
  SONIDOS.cuenta()
  const paso = () => {
    cuenta.value--
    if (cuenta.value > 0) {
      SONIDOS.cuenta()
      temporizadores.push(setTimeout(paso, 800))
    } else {
      SONIDOS.ya()
      temporizadores.push(
        setTimeout(() => {
          fase.value = 'jugando'
          t0 = performance.now()
          raf = requestAnimationFrame(cuadro)
        }, 450)
      )
    }
  }
  temporizadores.push(setTimeout(paso, 800))
}

function salir() {
  if (oficial.value && ronda) rondaUsada.value = true
  cancelAnimationFrame(raf)
  limpiarTemporizadores()
  celdas.value = crearCeldas()
  pops.value = []
  fase.value = 'menu'
}

async function terminar() {
  cancelAnimationFrame(raf)
  limpiarTemporizadores()
  motor.cerrar()
  sincronizarHud()
  Object.assign(resumen, {
    puntaje: motor.estado.puntaje,
    aciertos: motor.estado.aciertos,
    fallos: motor.estado.fallos,
    amigos: motor.estado.amigos,
    escapados: motor.estado.escapados,
    mejorRacha: motor.estado.mejorRacha
  })
  celdas.value = crearCeldas()
  fase.value = 'fin'
  SONIDOS.fin()
  if (oficial.value && ronda) await enviar()
}

async function enviar() {
  if (enviando.value || !ronda) return
  enviando.value = true
  errorEnvio.value = null
  try {
    // El servidor exige que haya pasado casi todo el tiempo de la ronda.
    oficialRes.value = await enviarRonda(ronda.id, toques)
    rondaUsada.value = true
    mejor.value = {
      puntaje: oficialRes.value.mejorPuntaje,
      puntos: oficialRes.value.mejorPuntos,
      aciertos: Math.max(mejor.value?.aciertos ?? 0, oficialRes.value.aciertos),
      mejorRacha: Math.max(
        mejor.value?.mejorRacha ?? 0,
        oficialRes.value.mejorRacha
      ),
      rondas: (mejor.value?.rondas ?? 0) + 1
    }
    await cargarTotal()
  } catch (err) {
    errorEnvio.value = err?.message ?? 'No se pudo guardar la ronda.'
  } finally {
    enviando.value = false
  }
}

// Total de la persona en el ranking del desafío (Gran desafío + Cazabugs).
async function cargarTotal() {
  if (!desafioId.value) return
  try {
    const filas = await fetchRanking(desafioId.value, 1000)
    const yo = filas.find(f => f.isMe)
    if (!yo) {
      miTotal.value = null
      return
    }
    const mini = mejor.value?.puntos ?? 0
    miTotal.value = {
      total: yo.points,
      mini,
      gran: yo.points - mini,
      posicion: yo.position
    }
  } catch {
    miTotal.value = null
  }
}

async function cargar() {
  cargando.value = true
  try {
    const [abierto, propio, expo] = await Promise.all([
      fetchDesbloqueado().catch(() => false),
      fetchMiMejor().catch(() => null),
      fetchExpo().catch(() => ({ challenges: [] }))
    ])
    desbloqueado.value = abierto
    mejor.value = propio
    rondaUsada.value = !!propio
    desafioId.value =
      expo.challenges?.find(c => c.minijuego)?.id ??
      expo.challenges?.[0]?.id ??
      null
  } catch (err) {
    errorCarga.value = err?.message ?? 'No se pudo cargar el minijuego.'
  } finally {
    cargando.value = false
  }
  await cargarTotal()
}

onMounted(cargar)
onUnmounted(() => {
  cancelAnimationFrame(raf)
  limpiarTemporizadores()
  try {
    audio?.close?.()
  } catch {
    /* nada */
  }
})
</script>

<style lang="scss" scoped>
.cb {
  &__inner {
    max-width: 720px;
    padding-top: 16px;
    padding-bottom: calc(24px + env(safe-area-inset-bottom));
  }

  &__back {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    font-weight: 800;
    text-decoration: none;
    text-transform: uppercase;
    font-size: 12px;
    letter-spacing: 0.4px;
    color: $dl-ink;
    margin-bottom: 8px;
  }

  &__head {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 12px;
    margin-bottom: 12px;
  }

  &__head-texto {
    min-width: 0;
  }

  &__eyebrow {
    font-size: 12px;
    font-weight: 800;
    text-transform: uppercase;
    letter-spacing: 0.6px;
    color: $dl-green-dark;
  }

  &__title {
    margin: 2px 0 4px;
    color: $dl-ink-dark;
  }

  &__lead {
    margin: 0;
    max-width: 440px;
    line-height: 1.4;
    font-size: 14px;
    color: $dl-ink;
  }

  &__score {
    flex: 0 0 auto;
    display: flex;
    flex-direction: column;
    align-items: center;
    background: $dl-surface;
    border: 2px solid $dl-gray;
    border-radius: 14px;
    padding: 6px 14px;
  }

  &__score-value {
    font-size: 28px;
    font-weight: 900;
    color: $dl-green-dark;
    line-height: 1;
  }

  &__score-label {
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
    color: #a3a3a3;
  }

  &__estado {
    text-align: center;
    padding: 40px 0;
    color: #a3a3a3;
  }

  /* ---- menú ---- */
  &__bloqueo {
    display: flex;
    gap: 10px;
    align-items: flex-start;
    background: #211b0b;
    border: 2px solid #6b5a1c;
    border-radius: 14px;
    padding: 10px 12px;
    margin-bottom: 10px;
    font-size: 14px;
    line-height: 1.4;
    color: $dl-ink;

    strong {
      color: $dl-ink-dark;
    }

    .q-icon {
      flex: 0 0 auto;
      margin-top: 2px;
    }
  }

  &__tarjetas {
    display: grid;
    grid-template-columns: repeat(5, minmax(0, 1fr));
    gap: 6px;
    margin-bottom: 10px;
  }

  &__bicho {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0;
    padding: 8px 2px;
    background: $dl-surface;
    border: 2px solid $dl-gray;
    border-radius: 12px;
    text-align: center;
    font-size: 12px;
    font-weight: 700;
    color: $dl-ink;

    strong {
      color: $dl-ink-dark;
      font-size: 13px;
    }

    &--oro {
      border-color: $dl-yellow;
      background: #211b0b;
    }

    &--amigo {
      border-color: #7a2a2a;
      background: #2a1414;
    }
  }

  &__bicho-cara {
    font-size: clamp(1.6rem, 7vw, 2.2rem);
    line-height: 1.15;
  }

  &__amigo-img {
    width: clamp(1.8rem, 8vw, 2.5rem);
    height: clamp(1.8rem, 8vw, 2.5rem);
    object-fit: contain;
  }

  &__reglas {
    list-style: none;
    margin: 0 0 10px;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 3px;
    font-size: 13px;
    line-height: 1.35;
    color: $dl-ink;
  }

  &__mejor {
    margin-bottom: 10px;
    padding: 8px 12px;
    border-radius: 12px;
    background: #10240a;
    color: #9be36b;
    font-size: 13px;
  }

  &__acciones {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin-bottom: 8px;
  }

  &__sonido {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    font-size: 13px;
    color: #a3a3a3;
  }

  /* ---- juego: ocupa justo la pantalla, sin scroll ---- */
  &--juego &__inner {
    padding: 6px 10px calc(8px + env(safe-area-inset-bottom));
  }

  &--juego {
    min-height: 0;
  }

  &__juego {
    height: calc(100vh - var(--hdr, 0px) - 16px - env(safe-area-inset-bottom));
    height: calc(100dvh - var(--hdr, 0px) - 16px - env(safe-area-inset-bottom));
    min-height: 300px;
    display: flex;
    flex-direction: column;
    gap: 6px;
    user-select: none;
    -webkit-user-select: none;
  }

  &__lateral {
    flex: 0 0 auto;
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  &__cuerpo {
    flex: 1 1 0;
    min-height: 0;
    min-width: 0;
    container-type: size;
    display: grid;
    place-items: center;
  }

  &__hud {
    display: grid;
    grid-template-columns: 1fr auto 1fr;
    align-items: center;
    gap: 8px;
  }

  &__hud-item {
    display: flex;
    flex-direction: column;

    &:last-child {
      align-items: flex-end;
    }
  }

  &__hud-label {
    font-size: 10px;
    font-weight: 800;
    text-transform: uppercase;
    color: #a3a3a3;
  }

  &__hud-valor {
    font-size: clamp(22px, 6vw, 30px);
    font-weight: 900;
    color: $dl-ink-dark;
    line-height: 1;
    font-variant-numeric: tabular-nums;

    &.is-poco {
      color: #ff6b6b;
      animation: cb-latido 0.5s ease infinite;
    }
  }

  &__racha {
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 2px 12px;
    border-radius: 12px;
    background: #1d1d1d;
    transition: background 0.2s ease;

    &.is-fuego {
      background: #3a2a0a;
      animation: cb-latido 0.7s ease infinite;
    }
  }

  &__racha-mult {
    font-size: 20px;
    font-weight: 900;
    color: $dl-green-dark;
    line-height: 1;
  }

  &__racha-n {
    font-size: 11px;
    font-weight: 800;
    color: $dl-ink;
  }

  &__barra {
    height: 8px;
    border-radius: 6px;
    background: #1d1d1d;
    overflow: hidden;
  }

  &__barra-fill {
    height: 100%;
    background: $dl-yellow;
    border-radius: 6px;

    &.is-poco {
      background: #ff6b6b;
    }
  }

  &__lateral-pie {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 8px;
  }

  &__pista {
    font-size: 12px;
    color: #a3a3a3;
  }

  &__salir {
    flex: 0 0 auto;
    padding: 2px 10px;
    border: 1px solid $dl-gray;
    border-radius: 10px;
    background: transparent;
    color: #a3a3a3;
    font: inherit;
    font-size: 12px;
    font-weight: 800;
    cursor: pointer;
  }

  &__tablero {
    --gap: 2.2cqw;
    position: relative;
    width: min(100cqw, 75cqh, 680px);
    aspect-ratio: 3 / 4;
    container-type: inline-size;
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    grid-template-rows: repeat(4, 1fr);
    gap: var(--gap);
    padding: var(--gap);
    background: $dl-surface;
    border: 2px solid $dl-gray;
    border-radius: 18px;
    touch-action: manipulation;

    &.is-golpe {
      animation: cb-temblor 0.35s ease;
      border-color: #ff6b6b;
    }

    &.is-fuego {
      border-color: $dl-yellow;
      box-shadow: 0 0 22px rgba(248, 200, 72, 0.35);
    }
  }

  &__agujero {
    position: relative;
    display: grid;
    place-items: center;
    width: 100%;
    height: 100%;
    min-width: 0;
    min-height: 0;
    padding: 0;
    border: none;
    border-radius: 14px;
    background: #181818;
    cursor: pointer;
    overflow: hidden;
    -webkit-tap-highlight-color: transparent;
    touch-action: manipulation;

    &:active {
      background: #222222;
    }

    &.is-dorado {
      background: #2a2208;
    }

    &.is-amigo {
      background: #2a1717;
    }
  }

  &__hoyo {
    position: absolute;
    bottom: 10%;
    width: 70%;
    height: 22%;
    border-radius: 50%;
    background: #050505;
    box-shadow: inset 0 4px 8px rgba(0, 0, 0, 0.9);
  }

  &__criatura {
    position: relative;
    z-index: 1;
    font-size: 17cqw;
    line-height: 1;
    animation: cb-aparecer 0.14s ease-out;
    filter: drop-shadow(0 4px 4px rgba(0, 0, 0, 0.6));

    &--rapido {
      font-size: 13cqw;
    }

    &--dorado {
      filter: drop-shadow(0 0 12px #f8c848) drop-shadow(0 0 4px #fff3b0);
      animation:
        cb-aparecer 0.14s ease-out,
        cb-brillo 0.5s ease-in-out infinite;
    }

    &--amigo .cb__amigo-img {
      width: 20cqw;
      height: 20cqw;
    }
  }

  &__agujero.is-por-irse &__criatura {
    animation: cb-temblar 0.12s linear infinite;
    opacity: 0.8;
  }

  &__vida {
    position: absolute;
    bottom: -4px;
    left: 50%;
    display: flex;
    gap: 3px;
    transform: translateX(-50%);

    i {
      width: 3.4cqw;
      height: 1.6cqw;
      border-radius: 3px;
      background: #7cc7f2;

      &.is-roto {
        background: #ff6b6b;
        opacity: 0.4;
      }
    }
  }

  &__efecto {
    position: absolute;
    z-index: 2;
    font-size: 17cqw;
    pointer-events: none;
    animation: cb-explota 0.35s ease-out forwards;
  }

  &__pop {
    position: absolute;
    z-index: 4;
    transform: translateX(-50%);
    font-size: clamp(14px, 5.5cqw, 26px);
    font-weight: 900;
    pointer-events: none;
    text-shadow: 0 2px 4px rgba(0, 0, 0, 0.8);
    animation: cb-sube 0.8s ease-out forwards;
    white-space: nowrap;

    &.is-bien {
      color: #9be36b;
    }

    &.is-oro {
      color: #ffd24d;
    }

    &.is-mal {
      color: #ff6b6b;
    }
  }

  &__cuenta {
    position: absolute;
    inset: 0;
    z-index: 6;
    display: grid;
    place-items: center;
    border-radius: 16px;
    background: rgba(0, 0, 0, 0.72);

    span {
      font-size: 22cqw;
      font-weight: 900;
      color: $dl-yellow;
      animation: cb-cuenta 0.8s ease-out;
    }
  }

  /* ---- fin ---- */
  &__fin {
    text-align: center;
    padding: 14px 14px 16px;
    background: $dl-surface;
    border: 2px solid $dl-gray;
    border-radius: 18px;

    &.is-oro,
    &.is-diamante {
      border-color: $dl-yellow;
      box-shadow: 0 0 24px rgba(248, 200, 72, 0.3);
    }
  }

  &__fin-cabeza {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 14px;
    text-align: left;
  }

  &__medalla {
    font-size: clamp(3rem, 14vw, 4.2rem);
    line-height: 1;
    animation: cb-rebote 0.7s ease;
  }

  &__fin-titulo {
    margin: 0;
    color: $dl-ink-dark;
  }

  &__fin-puntaje {
    margin: 0;
    font-size: 18px;
    color: $dl-ink;

    strong {
      font-size: 36px;
      color: $dl-green-dark;
    }
  }

  &__fin-datos {
    list-style: none;
    margin: 10px 0;
    padding: 0;
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 4px 12px;
    text-align: left;
    font-size: 14px;
    color: $dl-ink;
  }

  &__fin-aviso {
    margin: 0 0 10px;
    color: #a3a3a3;

    &.is-error {
      color: #ff8a8a;
    }
  }

  &__oficial {
    margin: 0 0 10px;
    padding: 10px 12px;
    border-radius: 12px;
    background: #211b0b;
    border: 2px solid #6b5a1c;
    color: $dl-ink;
    font-size: 14px;

    p {
      margin: 4px 0 0;
    }

    strong {
      color: $dl-green-dark;
    }
  }

  &__fin &__acciones {
    justify-content: center;
    margin-bottom: 0;
  }
}

@keyframes cb-aparecer {
  from {
    transform: translateY(40%) scale(0.4);
    opacity: 0;
  }
  to {
    transform: translateY(0) scale(1);
    opacity: 1;
  }
}

@keyframes cb-temblar {
  0%,
  100% {
    transform: translateX(-3px);
  }
  50% {
    transform: translateX(3px);
  }
}

@keyframes cb-brillo {
  0%,
  100% {
    filter: drop-shadow(0 0 8px #f8c848);
  }
  50% {
    filter: drop-shadow(0 0 18px #ffe27a) drop-shadow(0 0 6px #ffffff);
  }
}

@keyframes cb-explota {
  from {
    transform: scale(0.5);
    opacity: 1;
  }
  to {
    transform: scale(1.6);
    opacity: 0;
  }
}

@keyframes cb-sube {
  from {
    transform: translate(-50%, 0);
    opacity: 1;
  }
  to {
    transform: translate(-50%, -44px);
    opacity: 0;
  }
}

@keyframes cb-temblor {
  0%,
  100% {
    transform: translateX(0);
  }
  20% {
    transform: translateX(-8px);
  }
  60% {
    transform: translateX(8px);
  }
}

@keyframes cb-latido {
  0%,
  100% {
    transform: scale(1);
  }
  50% {
    transform: scale(1.12);
  }
}

@keyframes cb-cuenta {
  from {
    transform: scale(2);
    opacity: 0;
  }
  to {
    transform: scale(1);
    opacity: 1;
  }
}

@keyframes cb-rebote {
  0% {
    transform: scale(0.2) rotate(-20deg);
  }
  60% {
    transform: scale(1.25) rotate(8deg);
  }
  100% {
    transform: scale(1) rotate(0);
  }
}

/* Pantallas bajas (celular de lado): HUD a la izquierda y tablero a la derecha. */
@media (orientation: landscape) and (max-height: 540px) {
  .cb__juego {
    flex-direction: row;
    gap: 12px;
  }

  .cb__lateral {
    flex: 0 0 min(34vw, 230px);
    justify-content: center;
  }

  .cb__lateral-pie {
    flex-direction: column;
    align-items: stretch;
  }

  .cb__hud {
    grid-template-columns: 1fr 1fr;
  }

  .cb__racha {
    grid-column: 1 / -1;
    order: 3;
  }

  .cb__fin-cabeza {
    gap: 8px;
  }

  .cb__lead {
    display: none;
  }
}

@media (max-width: 380px) {
  .cb__bicho strong {
    font-size: 11px;
  }

  .cb__fin-datos {
    grid-template-columns: minmax(0, 1fr);
  }
}

@media (min-width: 900px) {
  .cb__inner {
    max-width: 900px;
  }
}

@media (prefers-reduced-motion: reduce) {
  .cb__criatura,
  .cb__efecto,
  .cb__pop,
  .cb__medalla,
  .cb__tablero.is-golpe,
  .cb__hud-valor.is-poco,
  .cb__racha.is-fuego,
  .cb__cuenta span {
    animation: none;
  }
}
</style>
