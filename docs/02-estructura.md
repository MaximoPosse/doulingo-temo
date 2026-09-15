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
                    │ /cursos/:slug/unidad/:unitId/leccion│
                    │ /:lessonId                          │  Resolver actividad (LessonPage)
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
| `/cursos/:slug/unidad/:unitId/leccion/:lessonId` · `leccion` | `pages/LessonPage.vue`       | Resolución de una actividad con verificación y pantalla de resultado.     |
| `/:catchAll(.*)*` · `no-encontrada`                          | `pages/ErrorNotFound.vue`    | Página 404.                                                               |

Vistas futuras: inicio de sesión, perfil del usuario, resultados globales,
página de "racha" y detalle de un lenguaje particular (Python, HTML/CSS).

## Arquitectura de carpetas

```
src/
├── assets/                  # Imágenes e íconos propios (usagi.webp)
├── boot/                    # Archivos de arranque de Quasar
├── components/              # Componentes reutilizables
│   ├── AppHeader.vue        # Encabezado global con navegación
│   ├── CourseCard.vue       # Tarjeta de curso (recibe datos, emite "select")
│   └── UnitCard.vue         # Tarjeta de unidad (recibe datos, emite "select")
├── composables/
│   └── useProgress.js       # Estado de progreso persistente (localStorage)
├── css/
│   ├── app.scss             # Identidad visual global (botones, badges)
│   └── quasar.variables.scss # Paleta de colores de la marca
├── data/                    # Estructura de datos (fuente de verdad)
│   ├── courses.js           # Catálogo de cursos
│   └── javascriptCourse.js  # Unidades, lecciones y ejercicios del curso JS
├── layouts/
│   └── MainLayout.vue       # Layout base (header global + router-view)
├── pages/                   # Vistas (una por ruta)
│   ├── IndexPage.vue
│   ├── CoursesPage.vue
│   ├── CourseDetailPage.vue
│   ├── LessonPage.vue
│   └── ErrorNotFound.vue
└── router/
    ├── index.js             # Instancia del router
    └── routes.js            # Definición de rutas con nombres
```

## Flujo de datos

```
courses.js ──► CoursesPage ──► CourseCard (props: course) ─emite "select"──► router → /cursos/:slug
javascriptCourse.js ──► CourseDetailPage ──► UnitCard (props: unit/units) ─emite "select"──► router → lección
javascriptCourse.js ──► LessonPage ──► useProgress.completeLesson() ──► localStorage
```

Las vistas nunca escriben contenido educativo "a mano" en el HTML: toda la
información (cursos, unidades, ejercicios) vive en `src/data/` y se inyecta
mediante props.
