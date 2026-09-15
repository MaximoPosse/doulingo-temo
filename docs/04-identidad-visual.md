# 04 · Identidad visual de Doulingo

## Paleta de colores

La paleta está inspirada en Duolingo (tonos vivos, saturados y amigables) y se
define en `src/css/quasar.variables.scss`.

| Variable Quasar                        | Hex                   | Uso                                                            |
| -------------------------------------- | --------------------- | -------------------------------------------------------------- |
| `$primary` / `$positive` / `$dl-green` | `#58cc02`             | Botones principales, premios y estados correctos.              |
| `$dl-green-dark`                       | `#58a700`             | Sombra de botones verdes (efecto de grosor) y texto de marca.  |
| `$secondary` / `$info` / `$dl-blue`    | `#1cb0f6`             | Unidad actual, enlaces activos y barra de progreso de lección. |
| `$dl-gold`                             | `#ffc800`             | Globos de diálogo, acentos y mensajes de la mascota.           |
| `$dl-orange`                           | `#ff9600`             | Badge de "próximamente" y avisos.                              |
| `$accent`                              | `#ce82ff`             | Lila de refuerzo (tarjetas de gamificación).                   |
| `$dl-ink / $dl-ink-dark`               | `#4b4b4b` / `#3c3c3c` | Textos.                                                        |
| `$dl-gray`                             | `#e5e5e5`             | Bordes, fondos de estado bloqueado y pistas.                   |
| `$dl-red` / `$negative`                | `#ff4b4b`             | Respuestas incorrectas y avisos de error.                      |

**Justificación**: los colores vivos y de alto contraste generan una
percepción lúdica y reducen la sensación de "estudio formal". El verde es el
color de acción ("adelante"), el azul marca la posición actual dentro del
recorrido y el gris comunica bloqueo sin agredir al usuario.

## Tipografías

- **Familia principal**: `Nunito`, `Quicksand`, fallback `Segoe UI`, sans-serif.
  Definida globalmente en `src/css/app.scss`. Se eligió por su forma redondeada
  (`Nunito`) que refuerza el tono amigable e informal de la app.
- **Familia de código** (bloques de ejemplo): `JetBrains Mono`, `Consolas`,
  `Courier New`, monospace. Distingue claramente el código del texto natural.
- Pesos usados: **800** para títulos y botones, **700** para textos destacados
  y **400-500** para párrafos.

## Botones

- **Botón principal (verde)**: relleno `#58cc02`, texto blanco en mayúsculas
  (`font-weight 800`), esquinas redondeadas y **sombra inferior de 4-6 px** que
  simula grosor físico. Al pulsar, baja 2 px y la sombra se reduce (efecto
  "chunky" de Duolingo). Clases globales: `.dl-btn-main` con variantes
  `--small`, `--big` y `--blue`.
- **Botón fantasma / tarjeta blanca**: fondo blanco, borde `2px $dl-gray`,
  sombra inferior gris. Se usa en acciones secundarias como **VER CURSOS**.
- Los botones siempre usan `no-caps` en mayúsculas explícitas para mantener el
  control tipográfico.

## Tarjetas

- **Tarjeta de curso** (`CourseCard`): fondo blanco, borde `2px gris`,
  esquinas de 16-18 px; zona visual de 78 px con el **color del curso**, luego
  badges de estado, título, descripción y metadatos. En `:hover` se eleva
  4 px con sombra y el borde adopta el color del curso.
- **Tarjeta de unidad** (`UnitCard`): fila con **círculo de estado** (azul =
  disponible, verde = completada, gris = bloqueada) unido a una línea vertical
  que simula el camino de aprendizaje; dentro, barra de progreso
  _x/y lecciones_ y badge de estado.
- Los cursos "próximamente" conservan la estructura pero con opacidad reducida
  y candado, sin interacción.

## Íconos

- Set **Material Icons** (incluido en `@quasar/extras`), cargado en
  `quasar.config.js`.
- Semántica: `code`/`data_object` para lenguajes, `check_circle` para
  "completado", `lock` para "bloqueado", `play_circle` para "disponible",
  `schedule` para "próximamente", `flash_on`/`trending_up`/`emoji_events` para
  beneficios y `chevron_right` para acciones.

## Mascota

- Usagi (del anime _Chiikawa_) es la guía que reemplaza al búho de Duolingo.
  Aparece en el header, en el hero de inicio, en las páginas de catálogo y en
  las pantallas de resultado. El archivo `src/assets/usagi.webp` tiene fondo
  transparente.

## Estados visuales

| Estado     | Color        | Ícono                          | Acción                                 |
| ---------- | ------------ | ------------------------------ | -------------------------------------- |
| Disponible | Verde / Azul | `check_circle` / `play_circle` | Inicia unidad o curso.                 |
| Completada | Verde        | `check_circle`                 | Muestra progreso; permite repasar.     |
| Bloqueada  | Gris         | `lock`                         | Sin interacción hasta desbloquear.     |
| Correcto   | Verde        | `check_circle`                 | Avanza con retroalimentación positiva. |
| Incorrecto | Rojo         | `error`                        | Explica la respuesta correcta.         |
