# 02 · Estructura general de la aplicación

## Mapa de pantallas (vistas)

```
                    ┌──────────────┐
                    │  / (inicio)  │  Landing: propósito + CTA para comenzar
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │ /cursos      │  Catálogo de cursos (CourseCard)
                    └──────┬───────┘
                           │
                    ┌──────▼──────────────┐
                    │ /cursos/:slug       │  Detalle del curso + unidades (UnitCard)
                    │ (Ej. /cursos/js)    │
                    └──────┬──────────────┘
                           │
                    ┌──────▼──────────────────────────────┐
                    │ /cursos/:slug/unidad/:unitId        │  Lista de lecciones
                    │                                     │  de la unidad (LessonCard)
                    └──────┬──────────────────────────────┘
                           │
                    ┌──────▼──────────────────────────────┐
                    │ /cursos/:slug/unidad/:unitId/leccion│
                    │ /:lessonId                          │  Lección completa:
                    │                                     │  intro ─ actividades ─ resultados
                    └─────────────────────────────────────┘

                    ┌──────────────────────┐
                    │ /:catchAll (404)     │  Página no encontrada
                    └──────────────────────┘
```

## Vistas planificadas

| Ruta (nombre)                                                | Página / archivo             | Contenido                                                                 |
| ------------------------------------------------------------ | ---------------------------- | ------------------------------------------------------------------------- |
| `/` · `inicio`                                               | `pages/IndexPage.vue`        | Propósito del proyecto, mascota Usagi, llamadas a la acción y beneficios. |
| `/cursos` · `cursos`                                         | `pages/CoursesPage.vue`      | Lista de cursos disponibles con tarjetas.                                 |
| `/cursos/:slug` · `curso`                                    | `pages/CourseDetailPage.vue` | Cabecera del curso y mapa de unidades con su estado.                      |
| `/cursos/:slug/unidad/:unitId` · `unidad`                    | `pages/CourseUnitPage.vue`   | Cabecera de la unidad y lista de lecciones con su estado (`LessonCard`).  |
| `/cursos/:slug/unidad/:unitId/leccion/:lessonId` · `leccion` | `pages/LessonPage.vue`       | Lección completa: intro (teoría + código), actividades y resultados.      |
| `/:catchAll(.*)*` · `no-encontrada`                          | `pages/ErrorNotFound.vue`    | Página 404.                                                               |

Vistas futuras: inicio de sesión, perfil del usuario, resultados globales,
página de "racha" y detalle de un lenguaje particular (Python, HTML/CSS).

## Arquitectura de carpetas

```
src/
├── assets/                  # Imágenes e íconos propios (usagi.webp)
├── boot/                    # Archivos de arranque de Quasar
├── components/              # Componentes reutilizables
│   ├── CourseCard.vue       # Tarjeta de curso (recibe datos, emite "select")
│   ├── UnitCard.vue         # Tarjeta de unidad (recibe datos, emite "select")
│   └── LessonCard.vue       # Tarjeta de lección (estado + botón de acción)
├── composables/
│   ├── useProgress.js       # Progreso del participante (completada/aprobada)
│   └── useRemoteData.js     # Carga remota: loading / error (reintento) / datos
├── css/
│   ├── app.scss             # Identidad visual global (botones, badges)
│   └── quasar.variables.scss # Paleta de colores de la marca
├── data/
│   └── courseRepository.js  # Acceso a datos (única puerta hacia las pantallas)
├── lib/
│   └── supabase.js          # Cliente centralizado de Supabase (env vars)
├── layouts/
│   └── MainLayout.vue       # Layout base (header global + router-view)
├── pages/                   # Vistas (una por ruta)
│   ├── IndexPage.vue
│   ├── CoursesPage.vue
│   ├── CourseDetailPage.vue
│   ├── CourseUnitPage.vue
│   ├── LessonPage.vue
│   └── ErrorNotFound.vue
└── router/
    ├── index.js             # Instancia del router
    └── routes.js            # Definición de rutas con nombres
```

El contenido educativo ya **no** vive en el frontend: se consulta a la base de
datos relacional **Supabase** (ver `supabase/`). El esquema, los datos iniciales
y las políticas de seguridad (RLS) se versionan como scripts SQL.

## Flujo de datos

Todas las pantallas leen contenido a través de **`courseRepository.js`**
(consultas asíncronas a Supabase); el avance del participante se lee/escribe con
**`useProgress.js`**.

```
Supabase (Postgres + RLS) ─► src/lib/supabase.js ─► courseRepository.js ─► CourseDetailPage ─► UnitCard ─emite "select"──► router → /unidad/:unitId
courseRepository.js ─► CourseUnitPage ─► LessonCard ─emite "select"──► router → /leccion/:lessonId
courseRepository.js ─► LessonPage ─► useProgress.completeAttempt() ─► localStorage
                                 └─ ► checkAnswer() [RPC] ─► Supabase (valida contra `soluciones`)
```

Las vistas nunca escriben contenido educativo "a mano" en el HTML: toda la
información (cursos, unidades, ejercicios) se inyecta mediante props. Las
soluciones **nunca** se descargan al cliente: se validan en el servidor con la
función `check_answer()` y solo se devuelve `correcto` + `explicacion`. Cada
vista maneja estados de **carga**, **error con reintento**, **vacío** y
**contenido inexistente** (ver `src/composables/useRemoteData.js`).
