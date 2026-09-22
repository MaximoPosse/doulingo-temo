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
│   └── useProgress.js       # Progreso del participante (completada/aprobada)
├── css/
│   ├── app.scss             # Identidad visual global (botones, badges)
│   └── quasar.variables.scss # Paleta de colores de la marca
├── data/                    # Estructura de datos (fuente de verdad)
│   ├── courses.js           # Catálogo de cursos
│   ├── javascriptCourse.js  # Unidades, lecciones y actividades del curso JS
│   └── courseRepository.js  # Acceso a datos (única puerta hacia las pantallas)
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

## Flujo de datos

Todas las pantallas leen contenido a través de **`courseRepository.js`**; el
avance del participante se lee/escribe con **`useProgress.js`**.

```
courses.js ─┐
             ├─► courseRepository.js ──► CoursesPage ──► CourseCard
javascriptCourse.js ─┘                                 ─emite "select"──► router → /cursos/:slug
courseRepository.js ──► CourseDetailPage ──► UnitCard ─emite "select"──► router → /unidad/:unitId
courseRepository.js ──► CourseUnitPage ──► LessonCard ─emite "select"──► router → /leccion/:lessonId
courseRepository.js ──► LessonPage ──► useProgress.completeAttempt() ──► localStorage
```

Las vistas nunca escriben contenido educativo "a mano" en el HTML: toda la
información (cursos, unidades, ejercicios) vive en `src/data/` y se inyecta
mediante props. `courseRepository` es el punto donde, en una etapa posterior,
estas lecturas pasarán a consultar la base de datos compartida sin modificar
las pantallas.
