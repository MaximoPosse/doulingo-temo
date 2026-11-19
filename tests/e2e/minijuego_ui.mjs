// Minijuego "Ruta del robot" desde la interfaz.
//
//   node tests/e2e/serve.mjs   (en otra terminal)
//   node tests/e2e/minijuego_ui.mjs          (contra el proyecto real)
//   MOCK=1 node tests/e2e/minijuego_ui.mjs   (con las 3 consultas del minijuego
//                                             simuladas: no hace falta que la
//                                             base tenga 0014 aplicada)
//
// Entra como invitado, arma programas con los bloques (incluido un bucle),
// los ejecuta y comprueba el recorrido, el choque, los puntos y el desbloqueo
// de niveles. En modo real hace falta haber terminado el Gran desafío; la
// prueba lo hace sola (responde mal 3 veces) con una cuenta nueva.

import crypto from 'node:crypto'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

import {
  BASE_URL,
  createRunner,
  createSupabaseClient,
  launchBrowser,
  sleep
} from './helpers.mjs'

const here = path.dirname(fileURLToPath(import.meta.url))
const lib = await import(
  pathToUrl(path.resolve(here, '../../src/lib/rutaRobot.js'))
)
function pathToUrl(p) {
  return new URL(`file:///${p.replace(/\\/g, '/')}`).href
}

const MOCK = process.env.MOCK === '1'
const runner = createRunner(
  `Minijuego Ruta del robot (${MOCK ? 'simulado' : 'proyecto real'})`
)

// Niveles de prueba para el modo simulado (los mismos que 0014).
const NIVELES = JSON.parse(
  fs.readFileSync(path.join(here, 'minijuego_niveles.json'), 'utf8')
)

const browser = await launchBrowser()
try {
  const page = await browser.newPage()
  await page.setViewport({
    width: 390,
    height: 844,
    deviceScaleFactor: 1,
    isMobile: true,
    hasTouch: true
  })

  // ---- estado simulado ----
  const mejores = {}
  if (MOCK) {
    await page.setRequestInterception(true)
    page.on('request', request => {
      const url = request.url()
      const cabeceras = {
        'access-control-allow-origin': '*',
        'access-control-allow-headers': '*',
        'content-type': 'application/json'
      }
      if (request.method() === 'OPTIONS' && /minijuego|enviar_ruta/.test(url)) {
        return request.respond({ status: 204, headers: cabeceras })
      }
      if (url.includes('/rest/v1/minijuego_niveles')) {
        return request.respond({
          status: 200,
          headers: cabeceras,
          body: JSON.stringify(NIVELES)
        })
      }
      if (url.includes('/rest/v1/minijuego_resultados')) {
        const filas = Object.entries(mejores).map(([nivel_id, r]) => ({
          nivel_id,
          puntos: r.puntos,
          bloques: r.bloques,
          estrellas: r.estrellas
        }))
        return request.respond({
          status: 200,
          headers: cabeceras,
          body: JSON.stringify(filas)
        })
      }
      if (url.includes('/rpc/minijuego_desbloqueado')) {
        return request.respond({
          status: 200,
          headers: cabeceras,
          body: 'true'
        })
      }
      if (url.includes('/rpc/enviar_ruta')) {
        const cuerpo = JSON.parse(request.postData() ?? '{}')
        const nivel = NIVELES.find(n => n.id === cuerpo.p_nivel)
        const sim = lib.simular(nivel, cuerpo.p_programa)
        const bloques = lib.contarBloques(cuerpo.p_programa)
        const puntos = lib.puntosDelIntento(nivel, sim, bloques)
        const previo = mejores[nivel.id]?.puntos ?? 0
        if (sim.llego && puntos > previo) {
          mejores[nivel.id] = { puntos, bloques, estrellas: sim.estrellas }
        }
        const total = Object.values(mejores).reduce((s, r) => s + r.puntos, 0)
        return request.respond({
          status: 200,
          headers: cabeceras,
          body: JSON.stringify([
            {
              llego: sim.llego,
              choco: sim.choco,
              bloques,
              pasos: sim.pasos,
              estrellas: sim.estrellas,
              puntos,
              mejor_puntos: mejores[nivel.id]?.puntos ?? 0,
              mejoro: sim.llego && puntos > previo,
              total_minijuego: total
            }
          ])
        })
      }
      return request.continue()
    })
  }

  // ---- sesión (como toda la app) ----
  await page.goto(`${BASE_URL}/#/acceso`, { waitUntil: 'networkidle0' })
  await page.waitForSelector('.dl-auth__card', { timeout: 20000 })
  let correo = null
  let clave = null
  let cliente = null
  if (MOCK) {
    for (const boton of await page.$$('.q-btn')) {
      if (
        /continuar como invitado/i.test(
          await boton.evaluate(e => e.textContent)
        )
      ) {
        await boton.click()
        break
      }
    }
    await page.waitForFunction(() => !location.hash.includes('/acceso'), {
      timeout: 30000
    })
  } else {
    // Cuenta nueva que termina el Gran desafío (3 errores) para desbloquear.
    const id = Date.now().toString(36)
    correo = `e2e-mini-${id}@example.com`
    clave = crypto.randomBytes(9).toString('base64url')
    cliente = await createSupabaseClient()
    const alta = await cliente.auth.signUp({
      email: correo,
      password: clave,
      options: { data: { alias: `e2e_mini_${id}` } }
    })
    runner.check('cuenta de prueba con sesión', !!alta.data?.session)
    const DESAFIO = '50000000-0000-0000-0000-000000000010'
    const inicio = await cliente.rpc('iniciar_partida', {
      p_desafio: DESAFIO,
      p_clave: `mini-${id}-${crypto.randomUUID()}`
    })
    const partida = (Array.isArray(inicio.data) ? inicio.data[0] : inicio.data)
      ?.partida
    const preguntas = await cliente
      .from('partida_preguntas')
      .select('desafio_pregunta_id')
      .eq('partida_id', partida)
      .order('orden', { ascending: true })
    for (const fila of preguntas.data ?? []) {
      const opciones = await cliente
        .from('desafio_opciones')
        .select('id')
        .eq('pregunta_id', fila.desafio_pregunta_id)
        .order('orden', { ascending: true })
      const r = await cliente.rpc('responder_partida', {
        p_partida: partida,
        p_pregunta: fila.desafio_pregunta_id,
        p_opcion: opciones.data[0].id
      })
      const fila0 = Array.isArray(r.data) ? r.data[0] : r.data
      if (r.error || fila0?.vidas_restantes === 0) break
    }
    await cliente.rpc('finalizar_partida', { p_partida: partida })
    // Se entra en la página con esa misma cuenta.
    await page.evaluate(
      (c, k) => {
        window.__acceso = { c, k }
      },
      correo,
      clave
    )
    await page.evaluate(() =>
      [...document.querySelectorAll('.q-tab')]
        .find(el => /ingresar/i.test(el.textContent))
        ?.click()
    )
    await sleep(500)
    const campos = []
    for (const campo of await page.$$('.q-tab-panel input')) {
      if (await campo.isVisible()) campos.push(campo)
    }
    await campos[0].type(correo)
    await campos[1].type(clave)
    for (const boton of await page.$$('.q-btn')) {
      if (/^\s*entrar\s*$/i.test(await boton.evaluate(e => e.textContent))) {
        await boton.click()
        break
      }
    }
    await page.waitForFunction(() => !location.hash.includes('/acceso'), {
      timeout: 30000
    })
  }

  // ---- utilidades de toque ----
  async function tocar(selector, indice = 0) {
    const elementos = await page.$$(selector)
    const el = elementos[indice]
    if (!el) throw new Error(`no existe ${selector}[${indice}]`)
    await el.evaluate(n => n.scrollIntoView({ block: 'center' }))
    await sleep(200)
    const caja = await el.boundingBox()
    await page.touchscreen.tap(
      caja.x + caja.width / 2,
      caja.y + caja.height / 2
    )
    await sleep(250)
  }
  async function tocarTexto(selector, patron) {
    const elementos = await page.$$(selector)
    for (let i = 0; i < elementos.length; i++) {
      const t = await elementos[i].evaluate(n => n.textContent)
      if (patron.test(t)) return tocar(selector, i)
    }
    throw new Error(`no hay ${selector} con ${patron}`)
  }
  const foto = async nombre => {
    if (process.env.FOTOS)
      await page.screenshot({
        path: path.join(process.env.FOTOS, `mini_${nombre}.png`),
        fullPage: true
      })
  }
  const texto = () => page.evaluate(() => document.body.innerText)
  async function esperarTexto(patron, ms = 20000) {
    const limite = Date.now() + ms
    while (Date.now() < limite) {
      if (patron.test(await texto())) return true
      await sleep(250)
    }
    return false
  }

  await page.goto(`${BASE_URL}/#/expo/minijuego`, { waitUntil: 'networkidle0' })
  await page.waitForSelector('.rr__niveles', { timeout: 30000 })

  const niveles = await page.$$('.rr__nivel')
  runner.check(
    'aparecen la práctica y los 6 niveles',
    niveles.length === 7,
    String(niveles.length)
  )
  runner.check(
    'el primer nivel está disponible y el segundo bloqueado hasta superar el 1',
    (
      await page.$$eval('.rr__nivel', n => [n[1].disabled, n[2].disabled])
    ).join() === 'false,true'
  )

  // Nivel 1: un bucle ahorra bloques (repetir 4 veces avanzar).
  await tocarTexto('.rr__bloque', /Repetir/)
  const filasBucle = await page.$$('.rr__fila--bucle')
  runner.check(
    '"Repetir" agrega un bucle y lo marca como destino',
    filasBucle.length === 1
  )
  await tocarTexto('.rr__bloque', /Avanzar/)
  await tocarTexto('.rr__veces button', /\+/)
  await tocarTexto('.rr__veces button', /\+/)
  const veces = await page.$eval('.rr__veces strong', e => e.textContent.trim())
  runner.check('el bucle sube a ×4', veces === '×4', veces)
  const bloques = await page.$eval('.rr__contador strong', e =>
    e.textContent.trim()
  )
  runner.check(
    'el programa usa 2 bloques (bucle + avanzar)',
    bloques === '2',
    bloques
  )

  await foto('programa')
  await tocarTexto('.rr__controles .q-btn', /Ejecutar/)
  runner.check(
    'el robot llega a la meta y se guarda el resultado',
    await esperarTexto(/Nivel superado|Nuevo récord/i, 25000)
  )
  await foto('resultado')
  runner.check(
    'suma 15 puntos (5 + 1 estrella + 7 de bonificación)',
    /\+15 puntos/.test(await texto())
  )
  runner.check(
    'el puntaje total del minijuego se actualiza',
    (await page.$eval('.rr__score-value', e => e.textContent.trim())) === '15'
  )
  const abiertos = await page.$$eval('.rr__nivel', n => n.map(x => x.disabled))
  runner.check('se desbloquea el nivel 2', abiertos[2] === false)

  if (!MOCK) {
    // En el proyecto real los puntos del minijuego suman al ranking.
    const DESAFIO = '50000000-0000-0000-0000-000000000010'
    const ranking = await cliente.rpc('ranking_desafio', {
      p_desafio: DESAFIO,
      p_limite: 200
    })
    const yo = (ranking.data ?? []).find(fila => fila.es_yo)
    runner.check(
      'el ranking del desafío suma los 15 puntos del minijuego',
      !!yo && yo.puntos >= 15,
      yo ? `${yo.puntos} pts` : (ranking.error?.message ?? 'no figura')
    )
  }

  // Nivel 2: chocar.
  await tocarTexto('.rr__btn-siguiente, .q-btn', /Siguiente nivel/)
  await sleep(500)
  await tocarTexto('.rr__bloque', /Girar izquierda/)
  await tocarTexto('.rr__bloque', /Avanzar/)
  await tocarTexto('.rr__controles .q-btn', /Ejecutar/)
  runner.check(
    'chocar con un obstáculo muestra el aviso y no suma',
    await esperarTexto(/chocó/i, 15000)
  )
  runner.check(
    'el total sigue en 15 tras el choque',
    (await page.$eval('.rr__score-value', e => e.textContent.trim())) === '15'
  )

  // Práctica: se juega sin enviar nada.
  await tocarTexto('.rr__nivel', /Práctica/)
  await sleep(300)
  await tocarTexto('.rr__bloque', /Avanzar/)
  await tocarTexto('.rr__controles .q-btn', /Borrar todo/)
  runner.check(
    'borrar todo vacía el programa',
    (await page.$eval('.rr__contador strong', e => e.textContent.trim())) ===
      '0'
  )

  // El robot respeta el tablero en celular chico.
  await page.setViewport({
    width: 320,
    height: 568,
    isMobile: true,
    hasTouch: true
  })
  await sleep(500)
  const desborde = await page.evaluate(
    () =>
      document.documentElement.scrollWidth -
      document.documentElement.clientWidth
  )
  runner.check(
    'sin desborde horizontal en 320 px',
    desborde <= 1,
    `${desborde}px`
  )
} catch (error) {
  runner.check(
    'recorrido sin excepciones',
    false,
    String(error.message ?? error)
  )
} finally {
  await browser.close()
}
process.exitCode = runner.summary('minijuego UI') ? 1 : 0
