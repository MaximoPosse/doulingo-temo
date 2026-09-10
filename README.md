# Doulingo

Aplicación móvil educativa inspirada en la lógica de aprendizaje progresivo de
**Duolingo**, pero orientada a la enseñanza de **lenguajes de programación**.
Una persona sin conocimientos previos avanza por unidades y lecciones breves,
resuelve actividades, recibe retroalimentación inmediata y conserva su progreso.

> Estado actual: el repositorio contiene la **página de inicio** (landing) del
> proyecto. La mascota oficial es **Usagi**, del anime _Chiikawa_, en lugar del
> búho clásico.

## Tabla de contenidos

1. [Problema](#problema)
2. [Tecnologías](#tecnologias)
3. [Estructura del proyecto](#estructura-del-proyecto)
4. [Cómo ejecutar](#como-ejecutar)
5. [Características de la página de inicio](#caracteristicas-de-la-pagina-de-inicio)
6. [Ruta de desarrollo (roadmap)](#ruta-de-desarrollo-roadmap)
7. [Notas de estilo](#notas-de-estilo)

## Problema

Aprender a programar suele exigir mucha teoría previa, cursos largos o
material denso. Doulingo plantea el aprendizaje como Duolingo plantea los
idiomas:

- **Unidades y lecciones breves** (3 a 5 minutos por actividad).
- **Retroalimentación inmediata** para que el estudiante corrija al instante.
- **Progreso guardado** y visible (racha, niveles, unidades completadas).
- **Gamificación** para mantener la motivación.

No hay lenguaje de programación asignado todavía: la arquitectura está
diseñada para integrar varios cursos bajo una misma estructura pedagógica y
técnica.

## Tecnologías

- **Vue.js 3** (Composition API, `<script setup>`)
- **Quasar v2** (framework de componentes y CLI) junto a **Vite**
- **Vue Router** (routing)
- **SCSS** para estilos personalizados (variables en
  `src/css/quasar.variables.scss`)

## Estructura del proyecto

```
.
├── index.html                 # HTML base (título "Doulingo")
├── package.json               # Dependencias y scripts
├── quasar.config.js           # Configuración de Quasar CLI
├── public/                    # Recursos estáticos (iconos, favicon)
└── src/
    ├── App.vue                # Componente raíz (router-view)
    ├── assets/
    │   └── usagi.webp         # Mascota oficial (Usagi, sin fondo)
    ├── boot/                  # Archivos de arranque de Quasar
    ├── components/            # Componentes Vue reutilizables
    ├── css/
    │   ├── app.scss           # Estilos globales de la app
    │   └── quasar.variables.scss  # Paleta de colores (marca Doulingo)
    ├── layouts/
    │   └── MainLayout.vue     # Layout base (por ahora solo monta el router)
    ├── pages/
    │   ├── IndexPage.vue      # Página de inicio (landing)
    │   └── ErrorNotFound.vue  # Página 404
    └── router/
        └── routes.js          # Definición de rutas
```

## Cómo ejecutar

Requisitos: **Node.js 22.12+** (se usó Node 24 durante el desarrollo).

```bash
# 1. Instalar dependencias
npm install

# 2. Entorno de desarrollo (recarga en caliente)
npm run dev      # o: quasar dev

# 3. Lint + formato (revisión)
npm run lint:check

# 4. Construcción de producción
npm run build    # genera ./dist/spa
```

Para previsualizar la carpeta de producción se puede servir `dist/spa` con
cualquier servidor estático, por ejemplo:

```bash
npx serve dist/spa
```

## Características de la página de inicio

La landing está construida en `src/pages/IndexPage.vue` y reproduce la
estructura de navegación y conversión de la web de Duolingo, adaptada a la
enseñanza de programación:

- **Encabezado fijo**: logo con Usagi, selector de idioma y botón "Empezar".
- **Hero**: titular "La forma gratuita, divertida y efectiva de aprender a
  programar", subtítulo, llamadas a la acción **EMPIEZA GRATIS** y
  **YA TENGO UNA CUENTA**, y la mascota **Usagi** con globo de diálogo.
- **Banda de garantías**: gratis, sin conocimientos previos, a tu ritmo.
- **Tarjetas de características**: lecciones breves, retroalimentación
  inmediata, progreso visible y gamificación.
- **Camino de aprendizaje**: demo visual del mapa de unidades con nodos
  (completado / actual / bloqueado), encabezado por Usagi como guía.
- **Pie de página**: marca y créditos.

Responsive: en pantallas pequeñas el hero se reordena en columna y el
selector de idioma se oculta.

## Ruta de desarrollo (roadmap)

- [x] Página de inicio (landing) con la mascota Usagi.
- [ ] Sistema de login/registro (mock primero).
- [ ] Mapa de unidades y lecciones (estilo Duolingo).
- [ ] Tipos de actividad: elección múltiple, completar código, verdadero/falso.
- [ ] Retroalimentación inmediata y barras de vida.
- [ ] Persistencia del progreso (racha, XP, unidades).
- [ ] Curso base de un lenguaje de programación.

## Notas de estilo

La paleta usada sigue la identidad de Duolingo, con la marca Doulingo:

| Variable                 | Color                       |
| ------------------------ | --------------------------- |
| `$primary`               | `#58cc02` (verde)           |
| `$secondary`             | `#1cb0f6` (azul)            |
| `$accent`                | `#ce82ff` (lila)            |
| `$dl-gold`               | `#ffc800`                   |
| `$dl-ink`/`$dl-ink-dark` | texto `#4b4b4b` / `#3c3c3c` |

Todas las variables se encuentran en `src/css/quasar.variables.scss`.

La imagen de la mascota vive en `src/assets/usagi.webp` (formato con
transparencia) y se importa como módulo en `IndexPage.vue` para que Vite la
procese y optimice en el build.
