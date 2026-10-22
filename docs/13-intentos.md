# 13 · Intentos, respuestas y progreso (etapa 5)

Este documento describe cómo se guardan los **intentos**, las **respuestas** y
el **progreso por participante**, con la corrección y el resultado calculados
en el servidor. El SQL vive en `supabase/migrations/0005_intentos.sql`.

## Modelo

```
auth.users (id)
   │
   ├── perfiles              (alias#sufijo, es_invitado)          [etapa 4]
   ├── participant_progress  (resumen por lección)                [etapa 4]
   ├── intentos              (un intento de una lección)
   │      └── intentos_respuestas  (una respuesta por actividad)
```

### `intentos`

| Campo              | Tipo        | Nulo | Restricciones                                       |
| ------------------ | ----------- | ---- | --------------------------------------------------- |
| id                 | uuid        | no   | PK, default `gen_random_uuid()`                     |
| participante_id    | uuid        | no   | FK `auth.users(id)` on delete cascade               |
| leccion_id         | uuid        | no   | FK `lecciones(id)` on delete cascade                |
| clave_idempotencia | text        | no   | UNIQUE con `participante_id`                        |
| estado             | text        | no   | CHECK: `en_curso` \| `finalizado`                   |
| total_actividades  | integer     | no   | CHECK ≥ 0                                           |
| aciertos           | integer     | no   | CHECK ≥ 0; `aciertos + errores ≤ total_actividades` |
| errores            | integer     | no   | CHECK ≥ 0                                           |
| aprobada           | boolean     | no   | default `false`                                     |
| iniciado_en        | timestamptz | no   | default `now()`                                     |
| finalizado_en      | timestamptz | sí   | obligatorio si `estado = 'finalizado'`              |

### `intentos_respuestas`

| Campo         | Tipo        | Nulo | Restricciones                        |
| ------------- | ----------- | ---- | ------------------------------------ |
| id            | uuid        | no   | PK, default `gen_random_uuid()`      |
| intento_id    | uuid        | no   | FK `intentos(id)` on delete cascade  |
| actividad_id  | uuid        | no   | FK `preguntas(id)` on delete cascade |
| opcion_id     | uuid        | no   | FK `opciones(id)` on delete cascade  |
| correcto      | boolean     | no   | calculado por el servidor            |
| respondido_en | timestamptz | no   | default `now()`                      |

`UNIQUE (intento_id, actividad_id)`: **una sola respuesta por actividad e
intento**. Si llega otra, se conserva la primera.

## Funciones (RPC)

Todas son `SECURITY DEFINER` y trabajan sobre `auth.uid()`. El dispositivo nunca
envía aciertos ni porcentajes: solo la opción elegida.

| Función                                                | Devuelve                                                                                                            |
| ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------- |
| `iniciar_intento(p_leccion, p_clave)`                  | `intento, leccion, total_actividades, estado, iniciado_en, reutilizado`                                             |
| `registrar_respuesta(p_intento, p_pregunta, p_opcion)` | `correcto, explicacion, opcion_correcta_id, opcion_elegida_id, repetida`                                            |
| `finalizar_intento(p_intento)`                         | `intento, leccion, total_actividades, aciertos, errores, aprobada, estado, iniciado_en, finalizado_en, reutilizado` |

### Idempotencia y antiduplicados

- **`iniciar_intento`** es idempotente por `(participante_id, clave)`: repetir la
  petición (reintento de red, doble toque, reapertura) devuelve el mismo intento
  con `reutilizado = true`. Una clave nueva crea otro intento.
- **`registrar_respuesta`** guarda solo la primera respuesta de cada actividad.
  Un segundo envío devuelve `repetida = true` con la respuesta ya guardada y no
  cambia el resultado.
- **`finalizar_intento`** es idempotente: si el intento ya está finalizado,
  devuelve el mismo resultado con `reutilizado = true`. Exige que todas las
  actividades estén respondidas (`PR_ATTEMPT_INCOMPLETE`).

### Cálculo en el servidor

- `finalizar_intento` cuenta aciertos/errores desde `intentos_respuestas` y
  aplica el umbral de aprobación (`aciertos ≥ ceil(total × 0.6)`).
- Actualiza `participant_progress` con el estado (`aprobada`/`intentada`), la
  cantidad de intentos finalizados y el mejor resultado. **Nunca baja un
  progreso ya aprobado**.
- El cliente ya **no puede** insertar ni modificar `participant_progress` por
  REST: ese permiso está revocado.

## Estados y casos de uso

| Situación                                      | Efecto                                                             |
| ---------------------------------------------- | ------------------------------------------------------------------ |
| Se sale / cierra la app / se corta la conexión | El intento queda `en_curso`: no cuenta como lección completada.    |
| Se repite la petición de inicio o de fin       | No se crea ni se duplica: se devuelve el mismo intento/resultado.  |
| Se recarga o se reabre la lección              | Se consulta el historial; el progreso se sincroniza desde la base. |
| Otro dispositivo con la misma cuenta           | Ve el historial y el progreso guardados en el servidor.            |
| Petición repetida de una respuesta             | Se conserva la primera respuesta de la actividad.                  |

## RLS

- `intentos` y `intentos_respuestas`: `SELECT` solo de las filas propias.
- Borrado propio de `intentos` (cascada a las respuestas): es lo que usa
  "Borrar mi historial".
- Sin políticas de INSERT/UPDATE y con `revoke`: la escritura solo ocurre a
  través de las funciones anteriores.
- Cada participante ve únicamente sus datos: dos participantes con la misma
  lección tienen intentos, respuestas y progreso independientes.

## Cliente

- `src/data/attemptRepository.js`: envuelve las tres RPC y las lecturas del
  historial (`intentos` con el título de la lección y `intentos_respuestas` con
  el enunciado y la opción elegida), además del borrado.
- `src/pages/LessonPage.vue`: al comenzar la lección crea (o reutiliza) el
  intento; cada respuesta se corrige y guarda en el servidor; al terminar,
  **espera la confirmación del guardado** antes de dar el resultado por firme.
  Si el guardado falla, muestra "No se pudo guardar el resultado" y permite
  **Reintentar guardado** (mismo intento, misma clave).
- `src/composables/useProgress.js`: `completeAttempt` solo actualiza la copia
  local con el resultado que ya confirmó el servidor.
- `src/pages/ProfilePage.vue`: muestra lecciones aprobadas, pendientes, intentos
  guardados, intentos sin terminar, el **último intento** y el **historial de
  intentos** con el detalle de respuestas.

## Pruebas

- `node tests/e2e/attempts.mjs` (35 casos) comprueba contra el proyecto real:
  idempotencia de inicio y fin, corrección en el servidor, respuestas
  bloqueadas, progreso que no baja, intento sin terminar, aislamiento entre
  participantes y escritura directa por REST denegada.
- `node tests/e2e/attempts_ui.mjs` (14 casos) recorre la interfaz: el resultado
  se guarda y se confirma, el perfil muestra el último intento y el historial
  con "Ver respuestas", otro dispositivo (otro invitado) no ve el historial, y
  si falla el guardado aparece el aviso con REINTENTAR GUARDADO.
- `node tests/e2e/case7.mjs` (5 casos, fallo de red al comprobar) verifica que
  la respuesta no se marca mal, que se puede reintentar y que el resultado se
  muestra solo cuando el servidor confirma el guardado.

### Resultado de la última ejecución (etapa 5)

| Suite             | Resultado                                |
| ----------------- | ---------------------------------------- |
| `attempts.mjs`    | 35/35 OK                                 |
| `attempts_ui.mjs` | 14/14 OK                                 |
| `case7.mjs`       | 5/5 OK                                   |
| `dbtest.mjs`      | 25/25 OK                                 |
| `buttons.mjs`     | 26/26 OK                                 |
| `alias.mjs`       | 11/11 OK                                 |
| `auth_ui.mjs`     | 5/5 OK                                   |
| `auth.mjs`        | 16/16 OK (7 omitidos por cupo de correo) |
