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
| [`docs/05-modelo-datos.md`](docs/05-modelo-datos.md)         | Diagrama entidad-relación y tablas (PK, FK, restricciones).     |
| [`docs/06-reglas-avance.md`](docs/06-reglas-avance.md)       | Completada vs aprobada, umbral, desbloqueo y repetición.        |
| [`docs/07-pruebas.md`](docs/07-pruebas.md)                   | Registro de pruebas (9 casos obligatorios + complementarios).   |
| [`docs/08-aportes.md`](docs/08-aportes.md)                   | Aportes del equipo.                                             |

## Estado actual

Aplicación funcional con:

- Página de inicio (landing) que presenta el proyecto.
- Catálogo de cursos con tarjetas reutilizables (`CourseCard`).
- Curso **JavaScript desde cero** con **una unidad funcional**
  (`Fundamentos de JavaScript`) formada por **2 lecciones** con explicación,
  ejemplo de código y **6 actividades** de opción múltiple con devolución.
  El resto de las unidades (variables, condicionales, bucles, funciones) está
  identificado pero **en preparación** (`published: false`).
- Pantallas de detalle por curso y por **unidad** con estados
  (pendiente / bloqueada / disponible / completada) y progreso.
- Lección completa en tres fases: **introducción** (teoría + código),
  **actividades** (selección, verificación textual, contador, respuesta única)
  y **resultados** (aciertos, porcentaje, aprobar/reprobar, repetir).
- Reglas de avance: aprobar una lección la cierra y habilita la siguiente; la
  unidad se completa al aprobar todas sus lecciones (ver `docs/06`).
- Progreso persistente en `localStorage` (`useProgress`), con acceso a datos
  centralizado en `courseRepository`.
- Router con rutas nombradas, avisos para lecciones/cursos inexistentes y
  página 404.

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
    │   ├── CourseCard.vue    # Tarjeta reutilizable de curso
    │   ├── UnitCard.vue      # Tarjeta reutilizable de unidad
    │   └── LessonCard.vue    # Tarjeta reutilizable de lección
    ├── composables/
    │   └── useProgress.js    # Progreso del participante (localStorage)
    ├── css/
    │   ├── app.scss          # Identidad visual global
    │   └── quasar.variables.scss
    ├── data/                 # Estructura de datos y acceso centralizado
    │   ├── courses.js
    │   ├── javascriptCourse.js
    │   └── courseRepository.js
    ├── layouts/MainLayout.vue
    ├── pages/
    │   ├── IndexPage.vue         # /  (inicio)
    │   ├── CoursesPage.vue       # /cursos
    │   ├── CourseDetailPage.vue  # /cursos/:slug
    │   ├── CourseUnitPage.vue    # /cursos/:slug/unidad/:unitId
    │   ├── LessonPage.vue        # /cursos/:slug/unidad/:unitId/leccion/:lessonId
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
| `/cursos/:slug/unidad/:unitId`                   | `unidad`        | Lecciones de la unidad       |
| `/cursos/:slug/unidad/:unitId/leccion/:lessonId` | `leccion`       | Lección completa             |
| cualquier otra                                   | `no-encontrada` | 404                          |

## Notas de estilo

Paleta principal: verde `#58cc02`, azul `#1cb0f6`, dorado `#ffc800`, lila
`#ce82ff`, texto `#3c3c3c`. Detalles y justificación en
[`docs/04-identidad-visual.md`](docs/04-identidad-visual.md).
