# Doulingo · Base de datos Supabase

Registro y documentación operativa del proyecto de base de datos de la
aplicación **Doulingo** (proyecto escolar). El diccionario de datos está en
`docs/05-modelo-datos.md`; el diagrama entidad-relación lo elabora el equipo.

## Registro del proyecto

- **Nombre del proyecto:** `doulingo`
- **Propósito:** almacenar el contenido educativo de la plataforma (cursos,
  unidades, lecciones, preguntas, opciones y soluciones) de forma relacional
  como fuente única de verdad. La aplicación Vue/Quasar consulta este backend
  vía REST (PostgREST) usando las credenciales anónimas del cliente.
- **Organización de tablas (resumen):**

  | Tabla        | Contenido                                                        | Relación                          |
  | ------------ | ---------------------------------------------------------------- | --------------------------------- |
  | `cursos`     | Catálogo de cursos (`estado`: disponible / proximamente)         | —                                 |
  | `unidades`   | Unidades de cada curso (`disponible` indica contenido publicado) | `curso_id` FK a `cursos`          |
  | `lecciones`  | Teoría + ejemplo de código de cada lección                       | `unidad_id` FK a `unidades`       |
  | `preguntas`  | Enunciados (opción múltiple)                                     | `leccion_id` FK a `lecciones`     |
  | `opciones`   | Opciones visibles de cada pregunta (**sin** marca de solución)   | `pregunta_id` FK a `preguntas`    |
  | `soluciones` | Opción correcta + explicación de cada pregunta (**privada**)     | `pregunta_id` PK/FK a `preguntas` |
  - Todas las secuencias (`orden` de unidades, lecciones, preguntas y
    opciones) se almacenan en una columna `orden int > 0`; la aplicación nunca
    depende del orden físico de inserción.
  - Las opciones no guardan cuál es la correcta: eso vive únicamente en
    `soluciones`, que no es consultable públicamente.

## Estructura de archivos

```
supabase/
├── README.md                 ← este archivo
└── migrations/
    ├── 0001_schema.sql       ← tablas, PKs, FKs y restricciones
    ├── 0002_seed.sql         ← datos iniciales (curso JavaScript)
    └── 0003_rls.sql          ← RLS + función check_answer()
```

## Cómo crear el proyecto y aplicar el esquema

1. Crear un proyecto en [supabase.com](https://supabase.com) llamado
   **`doulingo`** (lanzar la base).
2. Ir a **SQL Editor** y ejecutar, **en orden**, los tres archivos:
   `0001_schema.sql`, `0002_seed.sql` y `0003_rls.sql`.
3. En **Settings → API** copiar la **Project URL** y la **publishable key**
   (o **anon public key** en proyectos antiguos) y guardarlas localmente en
   `.env` (nunca en el repositorio):

   ```env
   VITE_SUPABASE_URL=https://TU-PROYECTO.supabase.co
   VITE_SUPABASE_PUBLISHABLE_KEY=tu-publishable-key-publica
   ```

   Ver `.env.example` en la raíz del proyecto para la referencia.

## Seguridad (RLS)

- **Lectura pública** (usuario anónimo): cursos `disponible` y el listado de
  unidades de esos cursos (metadatos, incluyendo la columna `disponible` para
  poder mostrarlas como "en preparación"). El **contenido** de una unidad
  no publicada queda oculto: sus lecciones/preguntas/opciones solo se leen si
  la unidad es `disponible`. Verificado mediante políticas `for select` con
  `using (...)`.
- **Escritura bloqueada**: el rol `anon`/`authenticated` no puede insertar,
  modificar ni borrar contenido (`revoke` explícito). El contenido y las
  soluciones se cargan desde **Table Editor (admin)** o SQL Editor.
- **Soluciones ocultas**: la tabla `soluciones` no tiene política de lectura
  y además se revocan sus permisos → `SELECT` directo devuelve vacío/denegado.
- **Comprobación de respuestas**: la aplicación llama a la función
  `check_answer(pregunta_id, opcion_id)` (RPC). La función es
  `SECURITY DEFINER`, valida en el servidor que la pregunta exista y esté
  publicada, que la opción pertenezca a esa pregunta, y recién entonces
  compara contra `soluciones` y devuelve `correcto` + `explicacion`.
- **Credenciales**: la app usa únicamente la _anon key_ (pública por diseño)
  mediante variables de entorno. La **service_role key** y las contraseñas
  **nunca** se usan en el frontend ni se documentan aquí.

## Notas

- Los archivos `0001` a `0003` son idempotentes (re-ejecutables) gracias a
  `ON CONFLICT DO NOTHING` y `create ... if not exists` / `drop policy if
exists`.
- El progreso del participante (lecciones completadas/aprobadas) NO se
  almacena en esta base: sigue en `localStorage` (`useProgress`).
