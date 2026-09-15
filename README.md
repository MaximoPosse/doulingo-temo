# Doulingo

Aplicación móvil educativa inspirada en la lógica de aprendizaje progresivo de
**Duolingo**, pero orientada a la enseñanza de **lenguajes de programación**.
Una persona sin conocimientos previos avanza por unidades y lecciones breves,
resuelve actividades, recibe retroalimentación inmediata y conserva su progreso.

La mascota oficial es **Usagi**, del anime _Chiikawa_, en lugar del búho clásico.

## Documentación del proyecto

| Documento                                                    | Contenido                                                       |
| ------------------------------------------------------------ | --------------------------------------------------------------- |
| [`docs/01-objetivo.md`](docs/01-objetivo.md)                 | Objetivo general, problema, usuario y funcionalidades.          |
| [`docs/02-estructura.md`](docs/02-estructura.md)             | Mapas de pantallas, rutas y arquitectura de carpetas.           |
| [`docs/03-wireframes.md`](docs/03-wireframes.md)             | Bocetos (wireframes) de las pantallas principales.              |
| [`docs/04-identidad-visual.md`](docs/04-identidad-visual.md) | Paleta, tipografías, botones, tarjetas, íconos y justificación. |

## Estado actual

Aplicación funcional con:

- Página de inicio (landing) que presenta el proyecto.
- Catálogo de cursos con tarjetas reutilizables (`CourseCard`).
- Curso **JavaScript desde cero** con 5 unidades, 15 lecciones y más de 40
  ejercicios.
- Mapa de unidades con estados (disponible / bloqueada / completada) y
  barra de progreso (`UnitCard`).
- Pantalla de actividad con opción múltiple y verdadero/falso, verificación
  inmediata, explicación y pantalla de resultado.
- Progreso persistente en `localStorage` (`useProgress`).
- Router con rutas nombradas y página 404.

Cursos restantes (Python, HTML y CSS) aparecen como **próximamente**.

## Tecnologías

- **Vue.js 3** (Composition API, `<script setup>`)
- **Quasar v2** (framework de componentes y CLI) junto a **Vite**
- **Vue Router** (rutas nombradas con modo hash)
- **SCSS** para estilos (variables en `src/css/quasar.variables.scss`)

## Estructura del proyecto

```
.
├── index.html
├── package.json
├── quasar.config.js
├── public/
├── docs/                     # Documentación de diseño y decisiones
└── src/
    ├── App.vue
    ├── assets/usagi.webp     # Mascota oficial (fondo transparente)
    ├── components/
    │   ├── AppHeader.vue     # Header global con navegación
    │   ├── CourseCard.vue    # Tarjeta reutilizable de curso
    │   └── UnitCard.vue      # Tarjeta reutilizable de unidad
    ├── composables/
    │   └── useProgress.js    # Progreso persistente (localStorage)
    ├── css/
    │   ├── app.scss          # Identidad visual global
    │   └── quasar.variables.scss
    ├── data/                 # Estructura de datos (cursos y ejercicios)
    │   ├── courses.js
    │   └── javascriptCourse.js
    ├── layouts/MainLayout.vue
    ├── pages/
    │   ├── IndexPage.vue         # /  (inicio)
    │   ├── CoursesPage.vue       # /cursos
    │   ├── CourseDetailPage.vue  # /cursos/:slug
    │   ├── LessonPage.vue        # lección / actividad
    │   └── ErrorNotFound.vue     # 404
    └── router/routes.js      # Rutas con nombres
```

## Cómo ejecutar

Requisitos: **Node.js 22.12+** (probado con Node 24).

```bash
npm install
npm run dev      # o: quasar dev  (entorno con recarga en caliente)
npm run lint:check   # formato + lint
npm run build        # genera ./dist/spa
```

Servir la build de producción:

```bash
npx serve dist/spa
```

## Navegación interna

| Ruta                                             | Nombre          | Vista                        |
| ------------------------------------------------ | --------------- | ---------------------------- |
| `/`                                              | `inicio`        | Landing                      |
| `/cursos`                                        | `cursos`        | Catálogo                     |
| `/cursos/:slug`                                  | `curso`         | Detalle del curso + unidades |
| `/cursos/:slug/unidad/:unitId/leccion/:lessonId` | `leccion`       | Actividad                    |
| cualquier otra                                   | `no-encontrada` | 404                          |

## Notas de estilo

Paleta principal: verde `#58cc02`, azul `#1cb0f6`, dorado `#ffc800`, lila
`#ce82ff`, texto `#3c3c3c`. Detalles y justificación en
[`docs/04-identidad-visual.md`](docs/04-identidad-visual.md).
