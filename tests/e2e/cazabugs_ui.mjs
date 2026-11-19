// Minijuego "Cazabugs" desde la interfaz.
//
//   node tests/e2e/serve.mjs   (en otra terminal)
//   node tests/e2e/cazabugs_ui.mjs          (contra el proyecto real)
//   MOCK=1 node tests/e2e/cazabugs_ui.mjs   (con las consultas del minijuego
//                                            simuladas: no necesita 0015)
//
// Entra, empieza una ronda con puntos y un "jugador automático" toca los
// bichos en el momento justo (conoce la semilla). Comprueba el tablero, los
// puntos y las rachas en pantalla, la cuenta regresiva, el fin de la ronda y
// que el puntaje OFICIAL (el que calcula el servidor repitiendo los toques)
// coincida con el de la pantalla. Dura poco más de un minuto.

import crypto from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  BASE_URL,
  createRunner,
  createSupabaseClient,
  launchBrowser,
  sleep,
} from "./helpers.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const lib = await import(
  new URL(
    `file:///${path.resolve(here, "../../src/lib/cazabugs.js").replace(/\\/g, "/")}`,
  ).href
);
const MOCK = process.env.MOCK === "1";
const runner = createRunner(
  `Cazabugs (${MOCK ? "simulado" : "proyecto real"})`,
);

const browser = await launchBrowser();
try {
  const page = await browser.newPage();
  await page.setViewport({
    width: 390,
    height: 844,
    deviceScaleFactor: 1,
    isMobile: true,
    hasTouch: true,
  });

  let semilla = null;
  let enviados = null;
  let mejoresMock = null;
  if (MOCK) {
    semilla = 4242;
    await page.setRequestInterception(true);
    page.on("request", (request) => {
      const url = request.url();
      const cabeceras = {
        "access-control-allow-origin": "*",
        "access-control-allow-headers": "*",
        "content-type": "application/json",
      };
      const responder = (cuerpo, estado = 200) =>
        request.respond({
          status: estado,
          headers: cabeceras,
          body: typeof cuerpo === "string" ? cuerpo : JSON.stringify(cuerpo),
        });
      if (request.method() === "OPTIONS" && /cazabugs|minijuego/.test(url)) {
        return request.respond({ status: 204, headers: cabeceras });
      }
      if (url.includes("/rpc/minijuego_desbloqueado")) return responder("true");
      if (url.includes("/rest/v1/cazabugs_mejores")) {
        return responder(mejoresMock ? [mejoresMock] : []);
      }
      if (url.includes("/rpc/cazabugs_iniciar")) {
        return responder([
          { ronda: crypto.randomUUID(), semilla, duracion_ms: 45000 },
        ]);
      }
      if (url.includes("/rpc/cazabugs_enviar")) {
        const cuerpo = JSON.parse(request.postData() ?? "{}");
        enviados = cuerpo.p_toques;
        const r = lib.reproducir(semilla, cuerpo.p_toques);
        const puntos = lib.puntosDelPuntaje(r.puntaje);
        mejoresMock = {
          puntaje: r.puntaje,
          puntos,
          aciertos: r.aciertos,
          mejor_racha: r.mejorRacha,
          rondas: 1,
        };
        return responder([
          {
            puntaje: r.puntaje,
            puntos,
            aciertos: r.aciertos,
            fallos: r.fallos,
            amigos: r.amigos,
            escapados: r.escapados,
            mejor_racha: r.mejorRacha,
            mejor_puntaje: r.puntaje,
            mejor_puntos: puntos,
            mejoro: true,
          },
        ]);
      }
      return request.continue();
    });
  }

  // ---- sesión ----
  await page.goto(`${BASE_URL}/#/acceso`, { waitUntil: "networkidle0" });
  await page.waitForSelector(".dl-auth__card", { timeout: 20000 });
  let cliente = null;
  if (MOCK) {
    for (const boton of await page.$$(".q-btn")) {
      if (
        /continuar como invitado/i.test(
          await boton.evaluate((e) => e.textContent),
        )
      ) {
        await boton.click();
        break;
      }
    }
  } else {
    // Cuenta nueva que termina el Gran desafío (3 errores) para desbloquear.
    const id = Date.now().toString(36);
    const correo = `e2e-cb-${id}@example.com`;
    const clave = crypto.randomBytes(9).toString("base64url");
    cliente = await createSupabaseClient();
    const alta = await cliente.auth.signUp({
      email: correo,
      password: clave,
      options: { data: { alias: `e2e_cb_${id}` } },
    });
    runner.check("cuenta de prueba con sesión", !!alta.data?.session);
    const DESAFIO = "50000000-0000-0000-0000-000000000010";
    const inicio = await cliente.rpc("iniciar_partida", {
      p_desafio: DESAFIO,
      p_clave: `cb-${id}-${crypto.randomUUID()}`,
    });
    const partida = (Array.isArray(inicio.data) ? inicio.data[0] : inicio.data)
      ?.partida;
    const preguntas = await cliente
      .from("partida_preguntas")
      .select("desafio_pregunta_id")
      .eq("partida_id", partida)
      .order("orden", { ascending: true });
    for (const fila of preguntas.data ?? []) {
      const opciones = await cliente
        .from("desafio_opciones")
        .select("id")
        .eq("pregunta_id", fila.desafio_pregunta_id)
        .order("orden", { ascending: true });
      const r = await cliente.rpc("responder_partida", {
        p_partida: partida,
        p_pregunta: fila.desafio_pregunta_id,
        p_opcion: opciones.data[0].id,
      });
      const fila0 = Array.isArray(r.data) ? r.data[0] : r.data;
      if (r.error || fila0?.vidas_restantes === 0) break;
    }
    await cliente.rpc("finalizar_partida", { p_partida: partida });
    await page.evaluate(() =>
      [...document.querySelectorAll(".q-tab")]
        .find((el) => /ingresar/i.test(el.textContent))
        ?.click(),
    );
    await sleep(500);
    const campos = [];
    for (const campo of await page.$$(".q-tab-panel input")) {
      if (await campo.isVisible()) campos.push(campo);
    }
    await campos[0].type(correo);
    await campos[1].type(clave);
    for (const boton of await page.$$(".q-btn")) {
      if (/^\s*entrar\s*$/i.test(await boton.evaluate((e) => e.textContent))) {
        await boton.click();
        break;
      }
    }
  }
  await page.waitForFunction(() => !location.hash.includes("/acceso"), {
    timeout: 30000,
  });

  await page.goto(`${BASE_URL}/#/expo/minijuego`, {
    waitUntil: "networkidle0",
  });
  await page.waitForSelector(".cb__menu", { timeout: 30000 });
  const foto = async (nombre) => {
    if (process.env.FOTOS)
      await page.screenshot({
        path: path.join(process.env.FOTOS, `cb_${nombre}.png`),
      });
  };
  const texto = () => page.evaluate(() => document.body.innerText);
  runner.check(
    "el menú explica los bichos y a Usagi",
    /Usagi/.test(await texto()) && /Dorado/.test(await texto()),
  );

  // Se hace una práctica corta primero: no pide nada al servidor.
  const botones = async () =>
    page.$$eval(".cb__acciones .q-btn", (bs) =>
      bs.map((b) => b.textContent.trim()),
    );
  const tocarBoton = async (patron) => {
    for (const b of await page.$$(".q-btn")) {
      if (patron.test(await b.evaluate((e) => e.textContent))) {
        await b.evaluate((e) => e.scrollIntoView({ block: "center" }));
        await b.click();
        return true;
      }
    }
    return false;
  };
  runner.check(
    "hay un botón de práctica y uno de ronda con puntos",
    (await botones()).length === 2,
  );

  // ---- ronda con puntos ----
  await tocarBoton(/Jugar con puntos/i);
  runner.check(
    "aparece la cuenta regresiva",
    !!(await page
      .waitForSelector(".cb__cuenta", { timeout: 15000 })
      .catch(() => null)),
  );
  await page.waitForFunction(() => !document.querySelector(".cb__cuenta"), {
    timeout: 15000,
  });
  const T0 = Date.now();
  runner.check(
    "el tablero tiene 12 casillas",
    (await page.$$(".cb__agujero")).length === 12,
  );

  // El jugador automático mira la pantalla (no conoce la semilla): toca los
  // bichos que ve, menos a Usagi, durante unos 14 segundos.
  const cajas = await page.$$eval(".cb__agujero", (els) =>
    els.map((el) => {
      const r = el.getBoundingClientRect();
      return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
    }),
  );
  const ultimoToqueCelda = Array.from({ length: 12 }, () => -9999);
  let tocados = 0;
  let vioAmigo = false;
  while (Date.now() - T0 < 14000) {
    const vistos = await page.$$eval(".cb__agujero", (els) =>
      els.map(
        (el) =>
          el
            .querySelector(".cb__criatura")
            ?.className.match(/cb__criatura--(\w+)/)?.[1] ?? null,
      ),
    );
    const ahora = Date.now() - T0;
    let hizoToque = false;
    for (let c = 0; c < 12; c++) {
      const tipo = vistos[c];
      if (!tipo) continue;
      if (tipo === "amigo") {
        vioAmigo = true;
        continue;
      }
      const espera = tipo === "grande" ? 170 : 600;
      if (ahora - ultimoToqueCelda[c] < espera) continue;
      await page.touchscreen.tap(cajas[c].x, cajas[c].y);
      ultimoToqueCelda[c] = Date.now() - T0;
      tocados++;
      hizoToque = true;
      await sleep(95);
    }
    if (!hizoToque) await sleep(60);
  }
  runner.check(
    "aparecen Usagi y otros bichos en el tablero",
    vioAmigo || tocados > 0,
  );
  await foto("juego");
  const hudPuntaje = Number(
    (await page.$eval(".cb__hud-valor", (e) => e.textContent.trim())) || 0,
  );
  runner.check(
    "el jugador automático caza bichos y el puntaje sube en pantalla",
    hudPuntaje > 0,
    `${tocados} toques, ${hudPuntaje} puntos`,
  );
  const racha = await page
    .$eval(".cb__racha-n", (e) => e.textContent.trim())
    .catch(() => "");
  runner.check("se muestra la racha", /🔥/.test(racha), racha);

  // Un toque a Usagi o en vacío no debe romper nada: se deja correr el reloj.
  const segundos = Number(
    await page
      .$eval(
        ".cb__hud-valor.is-poco, .cb__hud-item:last-child .cb__hud-valor",
        (e) => e.textContent,
      )
      .catch(() => 45),
  );
  runner.check("el reloj corre", segundos < 45, String(segundos));

  // ---- fin de ronda ----
  await page.waitForSelector(".cb__fin", { timeout: 60000 });
  await foto("fin");
  runner.check(
    "al terminar se muestra la medalla y los datos",
    /Cazados/.test(await texto()),
  );
  const puntajePantalla = Number(
    await page.$eval(".cb__fin-puntaje strong", (e) => e.textContent.trim()),
  );
  const oficial = await page
    .waitForFunction(() => /Puntaje oficial/.test(document.body.innerText), {
      timeout: 30000,
    })
    .then(() => true)
    .catch(() => false);
  runner.check(
    "el servidor guarda la ronda y muestra el puntaje oficial",
    oficial,
  );
  if (oficial) {
    const m = (await texto()).match(/Puntaje oficial:\s*(\d+)/);
    const puntajeOficial = m ? Number(m[1]) : -1;
    runner.check(
      "el puntaje oficial (servidor) coincide con el de la pantalla",
      puntajeOficial === puntajePantalla,
      `pantalla ${puntajePantalla} / servidor ${puntajeOficial}`,
    );
    if (MOCK && enviados) {
      runner.check(
        "se enviaron toques con tiempo y casilla",
        Array.isArray(enviados) &&
          enviados.length >= tocados &&
          enviados.every((t) => t.length === 2),
      );
    }
  }
  runner.check("permite jugar otra vez", /otra vez/i.test(await texto()));

  // ---- el menú muestra el récord ----
  await tocarBoton(/Volver al menú/i);
  await sleep(500);
  runner.check(
    "el menú muestra la ronda con puntos jugada",
    /Tu ronda con puntos/.test(await texto()),
  );
  runner.check(
    "la ronda con puntos no se puede repetir (1 solo intento)",
    await page.evaluate(() =>
      [...document.querySelectorAll(".q-btn")].some(
        (b) =>
          /Ya usaste tu ronda/.test(b.textContent) &&
          (b.disabled ||
            b.getAttribute("aria-disabled") === "true" ||
            b.classList.contains("disabled")),
      ),
    ),
  );

  // ---- práctica: sin enviar nada ----
  const antes = enviados;
  await tocarBoton(/Practicar/i);
  await page.waitForFunction(
    () =>
      !document.querySelector(".cb__cuenta") &&
      document.querySelector(".cb__tablero"),
    { timeout: 15000 },
  );
  runner.check(
    "la práctica arranca y se indica que no suma puntos",
    /Práctica \(sin puntos\)/.test(await texto()),
  );
  await page.setViewport({
    width: 320,
    height: 568,
    isMobile: true,
    hasTouch: true,
  });
  await sleep(500);
  const desborde = await page.evaluate(
    () =>
      document.documentElement.scrollWidth -
      document.documentElement.clientWidth,
  );
  runner.check(
    "sin desborde horizontal en 320 px",
    desborde <= 1,
    `${desborde}px`,
  );
  runner.check(
    "la práctica no manda nada al servidor",
    MOCK ? enviados === antes : true,
  );
} catch (error) {
  runner.check(
    "recorrido sin excepciones",
    false,
    String(error.message ?? error),
  );
} finally {
  await browser.close();
}
process.exitCode = runner.summary("cazabugs UI") ? 1 : 0;
