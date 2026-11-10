# 05 · Modelo de datos (diccionario de datos)

## Consideración previa

Doulingo separa **dos mundos de datos**:

1. **Contenido educativo (publicación)**: lo que se enseña (cursos, unidades,
   lecciones, preguntas, opciones y soluciones). Es "el producto". En esta etapa
   vive en **Supabase** y la aplicación lo consume a través de
   `src/data/courseRepository.js`.
2. **Avance del participante (progreso)**: si una persona completó o aprobó una
   lección y cuántos aciertos obtuvo en su intento. Es individual y hoy se
   guarda en `localStorage` a través de `useProgress.js` (ver el final).

Las pantallas nunca hablan con la base directamente: piden datos al
repositorio, que centraliza todas las consultas.

## Diagrama entidad-relación

_(Pendiente: el diagrama se elabora manualmente por el equipo.)_

## Diccionario de datos

### CURSOS

| Campo       | Tipo    | PK  | FK  | Nulo | Restricciones                         |
| ----------- | ------- | --- | --- | ---- | ------------------------------------- |
| id          | uuid    | ✓   | –   | no   | default `gen_random_uuid()`           |
| slug        | text    | –   | –   | no   | UNIQUE (identificador url-safe)       |
| titulo      | text    | –   | –   | no   | –                                     |
| descripcion | text    | –   | –   | no   | –                                     |
| nivel       | text    | –   | –   | no   | ej. "Principiante"                    |
| estado      | text    | –   | –   | no   | CHECK: `disponible` \| `proximamente` |
| color       | text    | –   | –   | no   | CHECK: `^#[0-9a-fA-F]{6}$`            |
| icono       | text    | –   | –   | no   | nombre de ícono Material              |
| orden       | integer | –   | –   | no   | CHECK: `orden > 0`                    |

### UNIDADES

| Campo       | Tipo    | PK  | FK          | Nulo | Restricciones                           |
| ----------- | ------- | --- | ----------- | ---- | --------------------------------------- |
| id          | uuid    | ✓   | –           | no   | default `gen_random_uuid()`             |
| curso_id    | uuid    | –   | → CURSOS.id | no   | on delete cascade                       |
| orden       | integer | –   | –           | no   | CHECK: `orden > 0`; UNIQUE con curso_id |
| titulo      | text    | –   | –           | no   | –                                       |
| descripcion | text    | –   | –           | no   | –                                       |
| icono       | text    | –   | –           | no   | nombre de ícono Material                |
| disponible  | boolean | –   | –           | no   | default `false`                         |

`disponible = false` identifica unidades con contenido aún incompleto
("en preparación"). El contenido (lecciones/preguntas/opciones) de una unidad
no disponible queda oculto por RLS.

### LECCIONES

| Campo          | Tipo    | PK  | FK            | Nulo | Restricciones                            |
| -------------- | ------- | --- | ------------- | ---- | ---------------------------------------- |
| id             | uuid    | ✓   | –             | no   | default `gen_random_uuid()`              |
| unidad_id      | uuid    | –   | → UNIDADES.id | no   | on delete cascade                        |
| orden          | integer | –   | –             | no   | CHECK: `orden > 0`; UNIQUE con unidad_id |
| titulo         | text    | –   | –             | no   | –                                        |
| explicacion    | text    | –   | –             | no   | teoría de la lección                     |
| ejemplo_codigo | text    | –   | –             | sí   | opcional (fragmento de código)           |

### PREGUNTAS

| Campo      | Tipo    | PK  | FK             | Nulo | Restricciones                             |
| ---------- | ------- | --- | -------------- | ---- | ----------------------------------------- |
| id         | uuid    | ✓   | –              | no   | default `gen_random_uuid()`               |
| leccion_id | uuid    | –   | → LECCIONES.id | no   | on delete cascade                         |
| orden      | integer | –   | –              | no   | CHECK: `orden > 0`; UNIQUE con leccion_id |
| enunciado  | text    | –   | –              | no   | –                                         |
| codigo     | text    | –   | –              | sí   | fragmento opcional junto al enunciado     |

### OPCIONES

| Campo       | Tipo    | PK  | FK             | Nulo | Restricciones                              |
| ----------- | ------- | --- | -------------- | ---- | ------------------------------------------ |
| id          | uuid    | ✓   | –              | no   | default `gen_random_uuid()`                |
| pregunta_id | uuid    | –   | → PREGUNTAS.id | no   | on delete cascade                          |
| orden       | integer | –   | –              | no   | CHECK: `orden > 0`; UNIQUE con pregunta_id |
| texto       | text    | –   | –              | no   | –                                          |

Las opciones **no** almacenan cuál es la correcta: eso vive en `soluciones`,
fuera del alcance público.

### SOLUCIONES (privada)

| Campo              | Tipo | PK  | FK             | Nulo | Restricciones                    |
| ------------------ | ---- | --- | -------------- | ---- | -------------------------------- |
| pregunta_id        | uuid | ✓   | → PREGUNTAS.id | no   | 1 a 1 con la pregunta; cascade   |
| opcion_correcta_id | uuid | –   | → OPCIONES.id  | no   | on delete cascade                |
| explicacion        | text | –   | –              | no   | por qué la respuesta es correcta |

Protegida por RLS (sin política de lectura) y con los permisos `SELECT`
revocados: sus filas **no** se pueden consultar vía API. Solo se entrega la
solución a través de la función `check_answer()`.

## Políticas de acceso (RLS) y función de comprobación

Implementadas en `supabase/migrations/0003_rls.sql`:

- **Lectura (anon/authenticated)**: `cursos` solo `estado = 'disponible'`;
  `unidades` todas (su `disponible` es visible); `lecciones`, `preguntas` y
  `opciones` solo si pertenecen a una unidad `disponible`.
- **Escritura**: no hay políticas de INSERT/UPDATE/DELETE y además se revocan
  esos permisos para `anon`/`authenticated`. La carga se hace desde las
  herramientas de administración de Supabase.
- **Soluciones**: `enable row level security` + `revoke all` → sin lectura vía
  API.

```sql
create function public.check_answer(p_pregunta uuid, p_opcion uuid)
returns table (correcto boolean, explicacion text, opcion_correcta_id uuid)
language plpgsql security definer set search_path = public
```

`SECURITY DEFINER`; el servidor: (1) verifica que la pregunta exista y su unidad
esté disponible, (2) verifica que la opción pertenezca a esa pregunta y
(3) compara contra `soluciones`. Devuelve `correcto`, `explicacion` y el id de la
opción correcta. Errores de negocio: `PR_QUESTION_NOT_PUBLISHED` y
`PR_OPTION_NOT_IN_QUESTION`.

## Fuente de verdad (scripts)

| Artefacto                          | Archivo                                 |
| ---------------------------------- | --------------------------------------- |
| Creación de tablas y restricciones | `supabase/migrations/0001_schema.sql`   |
| Carga inicial (datos)              | `supabase/migrations/0002_seed.sql`     |
| Políticas RLS y `check_answer`     | `supabase/migrations/0003_rls.sql`      |
| Perfiles y progreso (etapa 4)      | `supabase/migrations/0004_auth.sql`     |
| Intentos y respuestas (etapa 5)    | `supabase/migrations/0005_intentos.sql` |
| Competencia de expo (etapa 6)      | `supabase/migrations/0006_desafios.sql` |
| Datos de la expo (etapa 6)         | `supabase/migrations/0007_seed_desafios.sql` |
| Script combinado                   | `supabase/setup.sql`                    |
| Registro del proyecto y uso        | `supabase/README.md`                    |

No se incluyen contraseñas ni claves secretas: los scripts solo contienen
estructura y contenido de ejemplo.

## Progreso del participante (etapas 4 y 5)

El avance individual vive en la base compartida, atado al identificador de
Supabase Auth (`auth.uid()`), y el dispositivo conserva una copia local de
trabajo (`useProgress.js`, clave `doulingo-progress`):

| Tabla lógica           | Implementación                                                             |
| ---------------------- | -------------------------------------------------------------------------- |
| INTENTO_DE_LECCION     | `public.intentos` (inicio, fin, total, aciertos, errores, aprobación)      |
| RESPUESTA_DE_ACTIVIDAD | `public.intentos_respuestas` (una por actividad e intento)                 |
| PROGRESO_POR_LECCION   | `public.participant_progress` (resumen: estado, intentos, mejor resultado) |

Conceptos: **completada** (se terminó el intento), **aprobada** (≥ 60 % de
aciertos) y **reprobada** (completada por debajo del umbral). Solo las lecciones
aprobadas habilitan la siguiente. El detalle está en `docs/13-intentos.md`.

## Competencia de expo (etapa 6)

La competencia es un **mundo de datos separado de la práctica**. Usa su propio
banco de preguntas y nunca pasa por `check_answer()`:

| Tabla                 | Contenido                                                              |
| --------------------- | ---------------------------------------------------------------------- |
| `eventos`             | Evento de expo (`borrador`/`publicado`/`cerrado`, fechas y `es_prueba`) |
| `desafios`            | Dificultad, duración, puntos por acierto, intentos y tolerancia        |
| `desafio_preguntas`   | Preguntas del banco del desafío (independientes de `preguntas`)        |
| `desafio_opciones`    | Opciones visibles del desafío (sin marca de solución)                  |
| `desafio_soluciones`  | Opción correcta y explicación (**privada**, sin lectura por API)       |
| `partidas`            | Intento del participante: foto de reglas, tiempos y resultado          |
| `partida_preguntas`   | Preguntas fijadas para esa partida                                     |
| `partida_respuestas`  | Una respuesta por partida/pregunta (corrección y puntos del servidor)  |

Reglas clave:

- El **servidor** crea la partida (`iniciar_partida`), fija las preguntas y las
  reglas del intento, y calcula puntos y tiempos. El cliente solo envía IDs de
  partida, pregunta y opción.
- Una **respuesta por partida y pregunta** (`UNIQUE`): la primera queda firme;
  un envío repetido devuelve la existente sin volver a sumar.
- El ranking usa el **mejor intento válido** (`estado = 'finalizada'`) por
  participante y desafío; `incompleta` y `vencida` no compiten.
- El cliente no puede insertar, modificar ni borrar puntajes oficiales por
  REST: solo leer sus propias partidas.
- Los eventos y desafíos con `es_prueba = true` son internos: la interfaz los
  oculta, pero la API los lee para las pruebas automáticas sin `service_role`.

El diseño completo está en `docs/14-desafios.md`.
