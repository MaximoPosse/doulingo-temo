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
| [`docs/09-pruebas-supabase.md`](docs/09-pruebas-supabase.md) | Pruebas de la etapa de base de datos (Supabase).                |
| [`supabase/README.md`](supabase/README.md)                   | Proyecto Supabase: esquema, seed, RLS y seguridad.              |

## Estado actual

Aplicación funcional con el **contenido alojado en una base de datos
relacional Supabase**:

- Página de inicio (landing) que presenta el proyecto.
- Catálogo de cursos con tarjetas reutilizables (`CourseCard`).
- Curso **JavaScript desde cero** con **una unidad funcional**
  (`Fundamentos de JavaScript`) formada por **2 lecciones** con explicación,
  ejemplo de código y **6 actividades** de opción múltiple con devolución.
  El resto de las unidades (variables, condicionales, bucles, funciones) está
  **identificado pero en preparación** (`disponible = false`).
- Pantallas de detalle por curso y por **unidad** con estados
  (pendiente / bloqueada / disponible / completada) y progreso.
- Lección completa en tres fases: **introducción** (teoría + código),
  **actividades** (selección, verificación textual, contador, respuesta única)
  y **resultados** (aciertos, porcentaje, aprobar/reprobar, repetir).
- Reglas de avance: aprobar una lección la cierra y habilita la siguiente; la
  unidad se completa al aprobar todas sus lecciones (ver `docs/06`).
- **Contenido consultado desde Supabase** (solo lectura de lo publicado) con
  estados de **carga**, **error + reintento**, **vacío** y **contenido
  inexistente**. Las **soluciones no se descargan al cliente**: se validan en
  el servidor con la función `check_answer()` (RPC).
- Progreso persistente en `localStorage` (`useProgress`).
- Router con rutas nombradas y página 404.

## Tecnologías

- **Vue.js 3** (Composition API, `<script setup>`)
- **Quasar v2** (framework de componentes y CLI) junto a **Vite**
- **Vue Router** (rutas nombradas con modo hash)
- **Supabase** (Postgres + PostgREST) con **Row Level Security** y una función
  `SECURITY DEFINER` para comprobar respuestas.
- **SCSS** para estilos (variables en `src/css/quasar.variables.scss`)

## Estructura del proyecto

```
.
├── index.html
├── package.json
├── quasar.config.js
├── .env.example              # Plantilla de credenciales públicas (Supabase)
├── supabase/                 # Base de datos: esquema, seed y RLS (SQL)
│   ├── README.md
│   └── migrations/
│       ├── 0001_schema.sql
│       ├── 0002_seed.sql
│       └── 0003_rls.sql
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
    │   ├── useProgress.js    # Progreso del participante (localStorage)
    │   └── useRemoteData.js  # Carga remota: loading / error (reintento) / datos
    ├── css/
    │   ├── app.scss          # Identidad visual global
    │   └── quasar.variables.scss
    ├── data/
    │   └── courseRepository.js # Consultas a Supabase (única puerta de datos)
    ├── lib/
    │   └── supabase.js       # Cliente centralizado (VITE_SUPABASE_*)
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

1. Crear el proyecto Supabase y aplicar los scripts SQL (ver
   [`supabase/README.md`](supabase/README.md)).
2. Copiar `.env.example` a `.env` y completar `VITE_SUPABASE_URL` y
   `VITE_SUPABASE_ANON_KEY` (Supabase → Project Settings → API).

```bash
npm install
npm run dev          # o: quasar dev  (entorno con recarga en caliente)
npm run lint:check   # formato + lint
npm run build        # genera ./dist/spa
```

Sin un `.env` configurado, la aplicación arranca y muestra los estados de error
con botón **Reintentar** en lugar de datos.

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
