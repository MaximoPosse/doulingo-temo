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
├── setup.sql                 ← los cinco archivos en un solo script
└── migrations/
    ├── 0001_schema.sql       ← tablas, PKs, FKs y restricciones
    ├── 0002_seed.sql         ← datos iniciales (curso JavaScript)
    ├── 0003_rls.sql          ← RLS + función check_answer()
    ├── 0004_auth.sql         ← perfiles, progreso del participante y RLS ampliada
    └── 0005_intentos.sql     ← intentos, respuestas y resultado calculado en el servidor
```

## Cómo crear el proyecto y aplicar el esquema

1. Crear un proyecto en [supabase.com](https://supabase.com) llamado
   **`doulingo`** (lanzar la base).
2. Ir a **SQL Editor** y ejecutar, **en orden**, los cinco archivos:
   `0001_schema.sql`, `0002_seed.sql`, `0003_rls.sql`, `0004_auth.sql` y
   `0005_intentos.sql` (o pegar `setup.sql`, que es la concatenación de los
   cinco).
3. En **Settings → API** copiar la **Project URL** y la **publishable key**
   (o **anon public key** en proyectos antiguos) y guardarlas localmente en
   `.env` (nunca en el repositorio):

   ```env
   VITE_SUPABASE_URL=https://TU-PROYECTO.supabase.co
   VITE_SUPABASE_PUBLISHABLE_KEY=tu-publishable-key-publica
   ```

   Ver `.env.example` en la raíz del proyecto para la referencia.

## Autenticación (etapa 4)

`0004_auth.sql` agrega:

| Tabla                  | Contenido                                                    | Acceso                                            |
| ---------------------- | ------------------------------------------------------------ | ------------------------------------------------- |
| `perfiles`             | Alias público (3-20 caracteres) + sufijo derivado del id     | Lectura pública; escritura solo de la fila propia |
| `participant_progress` | Estado del participante por lección (`intentada`/`aprobada`) | Solo el propio participante (`auth.uid()`)        |

Configuración necesaria en el panel:

1. **Authentication → Providers → Anonymous Sign Ins → Enable** (si no, el
   acceso como invitado no funciona).
2. **Authentication → URL Configuration**: _Site URL_ y _Redirect URLs_ con los
   orígenes de la app (desarrollo, publicación y el esquema propio del APK).
3. **Correo**: el SMTP incluido solo entrega a miembros del equipo y tiene cupo
   de envíos por hora; para probar confirmaciones reales conviene usar un
   SMTP propio.

Detalle completo del diseño en [`docs/10-auth.md`](../docs/10-auth.md).

## Intentos y respuestas (etapa 5)

`0005_intentos.sql` agrega el historial por participante y mueve el cálculo
del resultado al servidor:

| Tabla                 | Contenido                                                                 | Acceso                                     |
| --------------------- | ------------------------------------------------------------------------- | ------------------------------------------ |
| `intentos`            | Un intento por lección: inicio, fin, total, aciertos, errores y resultado | Solo el propio participante (`auth.uid()`) |
| `intentos_respuestas` | Una respuesta por actividad e intento (opción elegida + corrección)       | Solo el propio participante                |

| Función                                           | Qué hace                                                                                        |
| ------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `iniciar_intento(leccion, clave)`                 | Crea el intento del usuario. Repetir la misma `clave` devuelve el MISMO intento (idempotencia). |
| `registrar_respuesta(intento, actividad, opcion)` | Corrige contra `soluciones` y guarda la primera respuesta de la actividad.                      |
| `finalizar_intento(intento)`                      | Calcula aciertos/errores/aprobación, actualiza `participant_progress` y es idempotente.         |

Reglas del modelo:

- La **corrección, los totales, el porcentaje y la aprobación los calcula el
  servidor**: el dispositivo nunca envía aciertos.
- Una **respuesta por actividad e intento**: la primera queda firme; no se puede
  "reintentar" dentro del mismo intento para subir el resultado.
- `finalizar_intento` no baja un progreso ya aprobado: mantiene `aprobada` y
  conserva el mejor resultado.
- Un intento **sin terminar** (`en_curso`, por salida, cierre o corte de
  conexión) no cuenta como lección completada.
- El cliente **no puede insertar ni modificar** `intentos` ni el progreso por
  REST: solo puede leerlos y borrarlos (borrado propio, con cascada a las
  respuestas).
- La tabla `participant_progress` sigue existiendo como resumen por lección,
  pero ahora **la escribe únicamente `finalizar_intento()`**.

Detalle del diseño en [`docs/13-intentos.md`](../docs/13-intentos.md).

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
exists`. `0004` y `0005` también: usan `create ... if not exists`,
  `create or replace function` y `drop policy if exists`.
- Con la sesión iniciada, el avance por lección se guarda en la base
  (`participant_progress` como resumen y `intentos`/`intentos_respuestas` como
  historial); el dispositivo conserva además una copia local (`localStorage`,
  `useProgress`) para funcionar sin conexión.
