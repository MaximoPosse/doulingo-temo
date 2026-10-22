# 09 · Pruebas de la etapa de base de datos (Supabase)

Registro de las pruebas de la integración con Supabase: consultas de contenido,
seguridad (RLS), comprobación de respuestas y estados de UI.

## Entorno

- Aplicación Vue 3 + Quasar servida en `http://localhost:9100` (`npm run dev`).
- Backend: proyecto Supabase `doulingo` con `supabase/migrations/*.sql`
  aplicados.
- Herramienta de navegador: Microsoft Edge en modo headless controlado con
  `puppeteer-core`.
- Nota: sin `.env` configurado la app **no** consulta datos; muestra los estados
  de error con botón Reintentar (ver casos 6 y 7, ejecutables sin backend).

## Preparación

1. Aplicar `0001_schema.sql`, `0002_seed.sql`, `0003_rls.sql` en el SQL Editor
   (o el combinado `supabase/setup.sql`).
2. Completar `.env` con `VITE_SUPABASE_URL` y `VITE_SUPABASE_PUBLISHABLE_KEY`
   (en proyectos antiguos, la clave pública se llama "anon key":
   `VITE_SUPABASE_ANON_KEY`). Nunca usar la clave secreta
   (`service_role` / `sb_secret_...`) en el frontend.
3. `npm run dev` y abrir `http://localhost:9100`; para probar la build de
   producción, `npm run build` y servir `dist/spa`.

## Casos

| #   | Caso                                     | Pasos                                                                         | Resultado esperado                                                                                                           | Estado                                 |
| --- | ---------------------------------------- | ----------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- | -------------------------------------- |
| 1   | Curso disponible y sus unidades          | Abrir `/cursos`; entrar a "JavaScript desde cero".                            | Aparece el curso disponible; al abrirlo se listan sus 5 unidades (1 disponible y 4 en preparación).                          | **OK**                                 |
| 2   | Filtrado por relación (curso → unidades) | Abrir el curso y contar unidades.                                             | Solo se muestran unidades cuyo `curso_id` corresponde al curso abierto.                                                      | **OK**                                 |
| 3   | Cambiar un título en la base             | Editar el `titulo` de una unidad en Supabase; recargar la app.                | El nuevo título aparece sin tocar código: la base es la fuente de verdad.                                                    | Pendiente (edición manual en Supabase) |
| 4   | Respeto del campo `orden`                | Insertar/editar filas con `orden` fuera de secuencia; recargar.               | Unidades, lecciones y preguntas se muestran ordenadas por `orden`, no por orden de inserción.                                | **OK**                                 |
| 5   | Identificador inexistente                | Abrir `/cursos/no-existe`, una unidad y una lección inexistentes.             | Mensajes claros de "no encontrado"; la app no se rompe.                                                                      | **OK**                                 |
| 6   | Sin conexión al consultar contenido      | Con backend inalcanzable/sin `.env`, abrir `/cursos` y `/cursos/:slug`.       | Estado de error con mensaje y botón **Reintentar**; al restablecer, Reintentar vuelve a cargar.                              | **OK** (headless)                      |
| 7   | Sin conexión al comprobar una respuesta  | En una actividad, cortar la conexión y presionar CONFIRMAR.                   | No se marca como incorrecta: aparece "No se pudo comprobar tu respuesta" y se puede reintentar sin contabilizar.             | **OK** (headless)                      |
| 8   | Visitante no modifica (RLS)              | Con la anon key, intentar INSERT/UPDATE/DELETE sobre `cursos`/`unidades`/etc. | La operación es denegada; no se modifica ningún contenido.                                                                   | **OK** (REST 401)                      |
| 9   | Soluciones no consultables               | Con la anon key, hacer `SELECT` sobre `soluciones`.                           | No se obtienen filas. La respuesta solo se conoce vía `check_answer()` (RPC).                                                | **OK** (REST 401)                      |
| 10  | Completar una lección                    | Recorrer una lección, responder las 3 actividades y ver resultados.           | Se obtiene el resultado; con ≥ 2 correctas la lección queda aprobada y se habilita la siguiente; progreso en `localStorage`. | **OK** (headless)                      |
| 11  | Unidad sin lecciones publicadas          | Abrir directamente la URL de una unidad en preparación.                       | Mensaje "Esta unidad no tiene lecciones publicadas todavía".                                                                 | **OK** (headless)                      |
| 12  | Dos navegadores                          | Abrir la app en dos navegadores/perfiles distintos con la misma base.         | Ambos ven el mismo contenido publicado (compartido) y avances independientes.                                                | **OK** (headless)                      |

## Automatizado

- `npm run lint:check` (oxfmt + oxlint) y `npm run build` deben pasar sin errores.
- Pruebas headless (Edge + `puppeteer-core`) contra la build de producción
  servida en `http://localhost:9100`:
  - `smoke.mjs`: estado de error sin backend (caso 6).
  - `dbtest.mjs`: catálogo, unidades, no encontrados, unidad sin lecciones,
    completar lección, `localStorage` y dos contextos (casos 1, 2, 5, 10, 11, 12).
  - `case7.mjs`: fallo de conexión al comprobar y reintento (caso 7), abortando
    la petición a `check_answer`.
  - `buttons.mjs`: recorrido completo pulsando **todos los botones** navegando
    por clics reales (landing, nav, tarjetas, links de volver, empezar/confirmar/
    continuar/ver resultados, repasar, siguiente lección, intentar nuevamente, X).
  - Verificaciones REST con la anon key para RLS y `check_answer` (casos 4, 8, 9).
- Herramientas locales en `edgetest/` (fuera del repositorio).

## Re-verificación

Ejecutada contra el proyecto Supabase real, en las dos formas de servir la
app:

| Suite                                   | Build de producción (`http://localhost:9100`) | Dev de Quasar (`http://localhost:9000`) |
| --------------------------------------- | --------------------------------------------- | --------------------------------------- |
| `buttons.mjs` (todos los botones)       | 26/26 OK                                      | 26/26 OK                                |
| `dbtest.mjs` (REST + RLS + RPC + UI)    | 25/25 OK                                      | —                                       |
| `case7.mjs` (fallo de red al comprobar) | 5/5 OK                                        | —                                       |

`dbtest.mjs` verifica, contra la base real: 1 curso visible por RLS
(`estado = 'disponible'`), 5 unidades con `orden` 1..5 y solo la 1 con
`disponible = true`, 2 lecciones visibles en la unidad 1 y **0** lecciones
visibles en las unidades en preparación, 3 preguntas ordenadas por `orden`, 4
opciones por pregunta que **no** exponen cuál es la correcta,
`SELECT` a `soluciones` → 401, `INSERT`/`UPDATE`/`DELETE` anónimos → 401, RPC
`check_answer` con exactamente 1 de 4 opciones correcta (devuelve
`correcto`, `explicacion` y `opcion_correcta_id`), `PR_OPTION_NOT_IN_QUESTION`
para una opción ajena o inexistente y `PR_QUESTION_NOT_PUBLISHED` para una
pregunta inexistente; en la UI, `/cursos` lista el curso de la base, las rutas
inexistentes muestran su mensaje y un contexto de navegador limpio no arrastra
progreso previo.

## Diagnóstico: "No se pudo contactar al servidor"

Si la app no puede leer la base, el mensaje friendly (`unwrap()`) es correcto,
pero la causa suele estar fuera del código. Orden de verificación:

1. **DNS del proyecto** (causa más frecuente):

   ```powershell
   nslookup <ref>.supabase.co 1.1.1.1
   ```

   Si responde `Non-existent domain` (NXDOMAIN) también en resolvers públicos
   (1.1.1.1 / 8.8.8.8), el proyecto no está disponible; si responde bien en
   1.1.1.1 pero no con el DNS del ISP, es caché negativa local → se resuelve
   cambiando el DNS de la interfaz o reintentando.

2. **Credenciales**: `VITE_SUPABASE_URL` y `VITE_SUPABASE_PUBLISHABLE_KEY` en
   `.env` (se reinicia el dev server para que las tome).
3. **Alcance de red**: la CSP de `index.html` permite `connect-src` a
   `https://*.supabase.co`; si se cambia el dominio del proyecto, hay que
   actualizar esa lista.
4. **Prueba directa de la API**:

   ```powershell
   Invoke-WebRequest "https://<ref>.supabase.co/rest/v1/cursos?select=id&limit=1" `
     -Headers @{ apikey = $KEY; Authorization = "Bearer $KEY" }
   ```

   Un `401` con `apikey` válida significa credenciales incorrectas; un error de
   resolución de nombre significa que el proyecto no responde.

## Resultados

Ejecutado contra un proyecto Supabase real (tablas creadas con `setup.sql`).

- Build y lint: **OK** (`npm run lint:check` y `npm run build` sin errores).
- Caso 6 (sin conexión / sin `.env`): **OK** en modo headless. En `/cursos` y
  `/cursos/javascript` se muestra el estado de error con el botón **Reintentar**
  y sin errores de página (`pageerror` vacío).
- Caso 1: **OK** — tarjeta "JavaScript desde cero" con descripción, badge
  "DISPONIBLE" y "5 unidades".
- Caso 2: **OK** — se listan 5 unidades del curso; unidad 1 "DISPONIBLE" y las
  unidades 2-5 "PENDIENTE".
- Caso 4: **OK** — unidades ordenadas por `orden` (1→5) tanto por REST como en
  la UI; lecciones y preguntas también ordenadas.
- Caso 5: **OK** — `/cursos/no-existe` → "No encontramos un curso…"; unidad y
  lección inexistentes → "Unidad no encontrada" / "Lección no encontrada".
- Caso 7: **OK** — con `check_answer` abortado, se muestra "No se pudo comprobar
  tu respuesta … Tu intento no se contabilizó", **no** se marca incorrecta, el
  botón CONFIRMAR sigue disponible y el reintento con conexión responde
  "¡Correcto!".
- Caso 8: **OK** — `INSERT` anónimo → `401 permission denied`.
- Caso 9: **OK** — `SELECT` a `soluciones` → `401 permission denied for table
soluciones`; la respuesta solo se obtiene vía RPC `check_answer`.
- Caso 10: **OK** — 3/3 correctas, resultado "¡Perfecto! LECCIÓN APROBADA 100%
  ACIERTOS", y `localStorage` (`doulingo-progress`) registra la lección como
  intentada y aprobada.
- Caso 11: **OK** — unidad en preparación → "Esta unidad no tiene lecciones
  publicadas todavía".
- Caso 12: **OK** — dos contextos de navegador ven las mismas 5 unidades.
- RPC `check_answer`: **OK** — opción correcta → `correcto:true`; incorrecta →
  `correcto:false`; opción de otra pregunta → `PR_OPTION_NOT_IN_QUESTION`.
- Recorrido de botones: **OK** — 26/26 comprobaciones en `buttons.mjs`
  (landing, navegación, tarjetas, links de volver, intro, CONFIRMAR/CONTINUAR,
  VER RESULTADOS, "Intentar nuevamente", "Repasar lección", "Siguiente lección",
  "Volver a la unidad", botón X), sin errores de página. Re-verificado también
  contra el dev server (`http://localhost:9000`).
- Incidente real (DNS): durante una sesión el subdominio del proyecto devolvió
  `Non-existent domain` desde el DNS del ISP; con 1.1.1.1 y 8.8.8.8 también
  NXDOMAIN y luego volvió a resolver solo, con la API respondiendo `200`. La app
  se comportó correctamente (estado de error con **Reintentar**, sin errores de
  página) y no requirió cambios de código. Ver sección "Diagnóstico".
- Corrección: se detectó que al pasar de una lección a la siguiente el
  componente reutilizado no recargaba los datos (los params de ruta no son
  reactivos). Se corrigió con `:key="$route.fullPath"` en el `router-view`.
- Pendiente: caso 3 (edición manual de un título en Supabase), por ser un cambio
  de datos en el panel.

## Etapa 4 (autenticación)

La ampliación del esquema con `perfiles` y `participant_progress`, las políticas
RLS por participante y las pruebas de acceso, sesión y alias están en
[`docs/10-auth.md`](10-auth.md) y [`docs/11-pruebas-auth.md`](11-pruebas-auth.md).
El script de base de datos combinado se regeneró en `supabase/setup.sql`
(incluye `0004_auth.sql`).
