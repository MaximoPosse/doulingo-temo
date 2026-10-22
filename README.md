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
| [`docs/10-auth.md`](docs/10-auth.md)                         | Acceso, identidad y sesión (Supabase Auth).                     |
| [`docs/11-pruebas-auth.md`](docs/11-pruebas-auth.md)         | Pruebas de la etapa de autenticación.                           |
| [`docs/12-apk.md`](docs/12-apk.md)                           | El APK (Android) y el esquema de URL propio.                    |
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
  inexistente**. Las **soluciones no se descargan al cliente**: se validan en el
  servidor con la función `check_answer()` (RPC).
- **Acceso con Supabase Auth**:
  - **visitante** sin sesión (solo lectura del contenido publicado);
  - **invitado** con sesión anónima propia (practica y guarda su historial);
  - **cuenta permanente** con correo y contraseña (misma identidad, mismo
    identificador, historial conservado).
  - **Alias público** de 3 a 20 caracteres (`alias#sufijo`), visible para
    todos; el correo y el identificador **no** se exponen.
  - Página de acceso (`/acceso`) con registro, ingreso, recuperación de
    contraseña y conversión de invitado a cuenta.
  - Página protegida (`/perfil`): identidad, historial, privacidad y cierre de
    sesión; sin sesión, redirige a `/acceso`.
  - **RLS ampliada**: `participant_progress` solo es accesible para el
    participante dueño de cada fila (`auth.uid()`), y `perfiles` solo se
    modifica en la fila propia.
  - Detalle del diseño en [`docs/10-auth.md`](docs/10-auth.md).
- **Versión Android (APK)** con **Capacitor**: la misma SPA se empaqueta como
  aplicación nativa y declara el **esquema de URL propio**
  (`doulingo://auth/callback`) para que los enlaces de confirmación de correo
  y de recuperación de contraseña abran la app. Ver
  [`docs/12-apk.md`](docs/12-apk.md).
- Progreso persistente en `localStorage` por identificador de participante
  (`useProgress`) y sincronizado con la tabla `participant_progress`.
- Router con rutas nombradas y página 404.

## Tecnologías

- **Vue.js 3** (Composition API, `<script setup>`)
- **Quasar v2** (framework de componentes y CLI) junto a **Vite**
- **Vue Router** (rutas nombradas con modo hash)
- **Capacitor 8** (empaquetado Android de la SPA y deep links)
- **Supabase** (Postgres + PostgREST + Auth) con **Row Level Security** y una
  función `SECURITY DEFINER` para comprobar respuestas.
- **SCSS** para estilos (variables en `src/css/quasar.variables.scss`)

## Estructura del proyecto

```
.
├── index.html
├── package.json
├── quasar.config.js
├── .env.example              # Plantilla de credenciales públicas (Supabase)
├── supabase/                 # Base de datos: esquema, seed, RLS y auth (SQL)
│   ├── README.md
│   ├── setup.sql             # Los cuatro archivos SQL en un solo script
│   └── migrations/
│       ├── 0001_schema.sql
│       ├── 0002_seed.sql
│       ├── 0003_rls.sql
│       └── 0004_auth.sql     # perfiles, progreso y RLS ampliada
├── src-capacitor/            # Versión Android (Capacitor)
│   ├── capacitor.config.js   # appId, appName y esquema del WebView
│   └── android/              # Proyecto Android (Manifest, Gradle, Activity)
├── public/
├── docs/                     # Documentación de diseño y decisiones
├── tests/e2e/                # Pruebas automáticas (Puppeteer + Supabase real)
└── src/
    ├── App.vue
    ├── assets/usagi.webp     # Mascota oficial (fondo transparente)
    ├── components/
    │   ├── CourseCard.vue    # Tarjeta reutilizable de curso
    │   ├── UnitCard.vue      # Tarjeta reutilizable de unidad
    │   └── LessonCard.vue    # Tarjeta reutilizable de lección
    ├── composables/
    │   ├── useAuth.js        # Sesión, identidad y acciones de acceso
    │   ├── useProgress.js    # Progreso del participante (local + base)
    │   └── useRemoteData.js  # Carga remota: loading / error (reintento) / datos
    ├── css/
    │   ├── app.scss          # Identidad visual global
    │   └── quasar.variables.scss
    ├── data/
    │   ├── authRepository.js # Operaciones de Auth, perfil y progreso
    │   └── courseRepository.js # Consultas a Supabase (única puerta de datos)
    ├── lib/
    │   ├── deepLink.js       # Deep link del APK (appUrlOpen) + código PKCE
    │   └── supabase.js       # Cliente centralizado (VITE_SUPABASE_*)
    ├── layouts/MainLayout.vue
    ├── pages/
    │   ├── IndexPage.vue         # /  (inicio)
    │   ├── CoursesPage.vue       # /cursos
    │   ├── CourseDetailPage.vue  # /cursos/:slug
    │   ├── CourseUnitPage.vue    # /cursos/:slug/unidad/:unitId
    │   ├── LessonPage.vue        # /cursos/:slug/unidad/:unitId/leccion/:lessonId
    │   ├── AuthPage.vue          # /acceso (invitado, registro, ingreso)
    │   ├── ProfilePage.vue       # /perfil (protegida)
    │   └── ErrorNotFound.vue     # 404
    └── router/
        ├── index.js          # Router + guard de sesión
        └── routes.js         # Rutas con nombres
```

## Cómo ejecutar

Requisitos: **Node.js 22.12+** (probado con Node 24).

1. Crear el proyecto Supabase y aplicar los scripts SQL (ver
   [`supabase/README.md`](supabase/README.md)).
2. Copiar `.env.example` a `.env` y completar `VITE_SUPABASE_URL` y
   `VITE_SUPABASE_PUBLISHABLE_KEY` (Supabase → Project Settings → API).
3. En Supabase → Authentication: **habilitar “Anonymous Sign Ins”** para el
   acceso como invitado y cargar el **Site URL** y los **Redirect URLs** de la
   app (incluido el esquema propio del APK).

```bash
npm install
npm run dev          # o: quasar dev  (entorno con recarga en caliente)
npm run lint:check   # formato + lint
npm run build        # genera ./dist/spa
```

Sin un `.env` configurado, la aplicación arranca y muestra los estados de error
con botón **Reintentar** en lugar de datos.

### Versión Android (APK)

Requiere **JDK 21** y el **SDK de Android** (ver
[`docs/12-apk.md`](docs/12-apk.md)):

```bash
npx quasar build -m capacitor   # arma la web en src-capacitor/www
cd src-capacitor
npx cap sync android            # copia la web al proyecto Android
npx cap open android            # Android Studio → Build → APK
```

El esquema de URL de la app es `doulingo://auth/callback` (declarado en el
`AndroidManifest.xml` de `src-capacitor/android`) y tiene que estar en
Supabase → Authentication → URL Configuration → Redirect URLs.

Servir la build de producción:

```bash
npx serve dist/spa
```

Pruebas automáticas (ver `tests/e2e/README.md`):

```bash
npm run serve:e2e           # sirve la build en http://localhost:9100
npm run test:e2e:buttons    # recorrido de la interfaz
npm run test:e2e:db         # contenido, RLS y RPC contra Supabase
npm run test:e2e:auth-ui    # pantalla de acceso
npm run test:e2e:auth       # API de Supabase Auth (+ "ui" para el recorrido)
npm run test:e2e:alias      # alias público, sufijo y aislamiento del perfil
```

## Navegación interna

| Ruta                                             | Nombre          | Vista                                             |
| ------------------------------------------------ | --------------- | ------------------------------------------------- |
| `/`                                              | `inicio`        | Landing                                           |
| `/cursos`                                        | `cursos`        | Catálogo                                          |
| `/cursos/:slug`                                  | `curso`         | Detalle del curso + unidades                      |
| `/cursos/:slug/unidad/:unitId`                   | `unidad`        | Lecciones de la unidad                            |
| `/cursos/:slug/unidad/:unitId/leccion/:lessonId` | `leccion`       | Lección completa                                  |
| `/acceso`                                        | `acceso`        | Acceso: invitado, registro, ingreso, recuperación |
| `/perfil`                                        | `perfil`        | **Protegida**: identidad, historial y privacidad  |
| cualquier otra                                   | `no-encontrada` | 404                                               |

## Notas de estilo

Paleta principal: verde `#58cc02`, azul `#1cb0f6`, dorado `#ffc800`, lila
`#ce82ff`, texto `#3c3c3c`. Detalles y justificación en
[`docs/04-identidad-visual.md`](docs/04-identidad-visual.md).
