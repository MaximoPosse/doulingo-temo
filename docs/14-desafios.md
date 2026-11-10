# 14 · Competencia de expo: evento, desafíos y partidas (etapa 6)

Este documento describe la **competencia de la expo**: eventos, desafíos,
partidas, preguntas asignadas, respuestas, puntajes y ranking, con todas las
reglas calculadas y validadas en el servidor. El SQL vive en
`supabase/migrations/0006_desafios.sql` y los datos iniciales en
`supabase/migrations/0007_seed_desafios.sql`.

La competencia es un mundo **separado de la práctica**:

- La práctica (etapas 4 y 5) usa `preguntas` / `opciones` / `soluciones` y su
  corrección pública `check_answer()`.
- La competencia usa un **banco propio**: `desafio_preguntas`,
  `desafio_opciones` y `desafio_soluciones`. `check_answer()` **nunca** consulta
  este banco, así que corregir una práctica no permite descubrir las soluciones
  de un desafío activo.

## Modelo

```
auth.users (id)
   │
   ├── perfiles                       (alias#sufijo)                 [etapa 4]
   │
   ├── eventos                        (expo: borrador/publicado/cerrado)
   │      └── desafios                (dificultad, duración, puntos, intentos)
   │             ├── desafio_preguntas        (banco del desafío)
   │             │      ├── desafio_opciones
   │             │      └── desafio_soluciones  (privada)
   │             └── partidas         (un intento del participante)
   │                    ├── partida_preguntas   (foto de las preguntas)
   │                    └── partida_respuestas  (una por partida/pregunta)
   │
   └── ranking_desafio()              (mejor intento válido por participante)
```

### `eventos`

| Campo       | Tipo        | Nulo | Restricciones                                  |
| ----------- | ----------- | ---- | ---------------------------------------------- |
| id          | uuid        | no   | PK, default `gen_random_uuid()`                |
| slug        | text        | no   | UNIQUE (identificador url-safe)                |
| titulo      | text        | no   | –                                              |
| descripcion | text        | no   | –                                              |
| inicia_en   | timestamptz | no   | –                                              |
| termina_en  | timestamptz | no   | CHECK: `termina_en > inicia_en`                |
| estado      | text        | no   | CHECK: `borrador` \| `publicado` \| `cerrado`  |
| es_prueba   | boolean     | no   | default `false` (evento interno de pruebas)    |
| creado_en   | timestamptz | no   | default `now()`                                |

### `desafios`

| Campo               | Tipo    | Nulo | Restricciones                                     |
| ------------------- | ------- | ---- | ------------------------------------------------- |
| id                  | uuid    | no   | PK, default `gen_random_uuid()`                   |
| evento_id           | uuid    | no   | FK `eventos(id)` on delete cascade                |
| slug                | text    | no   | UNIQUE con `evento_id`                            |
| titulo              | text    | no   | –                                                 |
| descripcion         | text    | no   | –                                                 |
| dificultad          | text    | no   | CHECK: `facil` \| `intermedio` \| `dificil`       |
| duracion_segundos   | integer | no   | CHECK > 0                                         |
| puntos_por_acierto  | integer | no   | CHECK > 0                                         |
| intentos_permitidos | integer | no   | CHECK > 0                                         |
| tolerancia_segundos | integer | no   | CHECK ≥ 0; default 30 (plazo de reconexión)       |
| es_prueba           | boolean | no   | default `false` (desafío interno de pruebas)      |
| estado              | text    | no   | CHECK: `borrador` \| `publicado` \| `cerrado`     |
| orden               | integer | no   | CHECK > 0                                         |
| creado_en           | timestamptz | no | default `now()`                                   |

`es_prueba` oculta el evento o el desafío en la interfaz de la expo, pero la
API los sigue leyendo: así las pruebas automáticas usan sus propios datos sin
necesitar la clave `service_role`.

### Banco del desafío

| Tabla                | Contenido                                              | Acceso                            |
| -------------------- | ------------------------------------------------------ | --------------------------------- |
| `desafio_preguntas`  | Enunciado, código opcional, dificultad y orden         | Lectura pública si el desafío está visible |
| `desafio_opciones`   | Opciones visibles (**sin** marca de solución)          | Lectura pública si el desafío está visible |
| `desafio_soluciones` | Opción correcta + explicación (**privada**)            | Sin lectura: solo funciones del servidor |

`desafio_opciones` no guarda cuál es la correcta: eso vive en
`desafio_soluciones`, con `revoke all` y sin política de lectura.

### `partidas`

| Campo               | Tipo        | Nulo | Restricciones                                        |
| ------------------- | ----------- | ---- | ---------------------------------------------------- |
| id                  | uuid        | no   | PK, default `gen_random_uuid()`                      |
| participante_id     | uuid        | no   | FK `auth.users(id)` on delete cascade                |
| desafio_id          | uuid        | no   | FK `desafios(id)` on delete cascade                  |
| clave_idempotencia  | text        | no   | UNIQUE con `participante_id`                         |
| estado              | text        | no   | CHECK: `en_curso` \| `finalizada` \| `incompleta` \| `vencida` |
| total_preguntas     | integer     | no   | CHECK ≥ 0                                            |
| puntos              | integer     | no   | CHECK ≥ 0                                            |
| aciertos            | integer     | no   | CHECK ≥ 0; `aciertos + errores ≤ total_preguntas`    |
| errores             | integer     | no   | CHECK ≥ 0                                            |
| puntos_por_acierto  | integer     | no   | CHECK > 0 (foto de la regla al iniciar)              |
| duracion_segundos   | integer     | no   | CHECK > 0 (foto de la regla al iniciar)              |
| tolerancia_segundos | integer     | no   | CHECK ≥ 0 (foto de la regla al iniciar)              |
| iniciado_en         | timestamptz | no   | default `now()` (hora del servidor)                  |
| expira_en           | timestamptz | no   | `iniciado_en + duracion_segundos`                    |
| finalizado_en       | timestamptz | sí   | obligatorio si `estado <> 'en_curso'`                |
| duracion_ms         | bigint      | sí   | CHECK ≥ 0; medida en el servidor                     |

`partidas` guarda una **foto de las reglas** del desafío en el momento de
iniciar. Si el equipo edita la duración o los puntos después, las partidas ya
iniciadas conservan las reglas con las que se jugaron.

### `partida_preguntas`

| Campo               | Tipo    | Nulo | Restricciones                                   |
| ------------------- | ------- | ---- | ----------------------------------------------- |
| partida_id          | uuid    | no   | FK `partidas(id)` on delete cascade             |
| desafio_pregunta_id | uuid    | no   | FK `desafio_preguntas(id)` on delete cascade    |
| orden               | integer | no   | CHECK > 0; PK `(partida_id, desafio_pregunta_id)` |

Fija qué preguntas aplican a esa partida. Aunque después se edite el banco del
desafío, la partida conserva sus preguntas.

### `partida_respuestas`

| Campo               | Tipo        | Nulo | Restricciones                                   |
| ------------------- | ----------- | ---- | ----------------------------------------------- |
| id                  | uuid        | no   | PK, default `gen_random_uuid()`                 |
| partida_id          | uuid        | no   | FK `partidas(id)` on delete cascade             |
| desafio_pregunta_id | uuid        | no   | FK compuesta a `partida_preguntas`              |
| desafio_opcion_id   | uuid        | no   | FK `desafio_opciones(id)` on delete cascade     |
| correcto            | boolean     | no   | calculado por el servidor                       |
| puntos_obtenidos    | integer     | no   | CHECK ≥ 0; calculado por el servidor            |
| respondido_en       | timestamptz | no   | default `now()`                                 |
| tiempo_ms           | bigint      | no   | CHECK ≥ 0; medido desde `iniciado_en`           |

`UNIQUE (partida_id, desafio_pregunta_id)`: **una sola respuesta por partida y
pregunta**. La primera queda firme; un envío repetido devuelve la existente sin
volver a sumar.

## Funciones (RPC)

Todas son `SECURITY DEFINER`, trabajan sobre `auth.uid()` y validan en el
servidor. El cliente solo envía identificadores (partida, pregunta, opción).

| Función                                     | Devuelve                                                                                                                          |
| ------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `iniciar_partida(p_desafio, p_clave)`       | `partida, desafio, estado, total_preguntas, puntos_por_acierto, duracion_segundos, tolerancia_segundos, iniciado_en, expira_en, intentos_usados, intentos_permitidos, reutilizado` |
| `responder_partida(p_partida, p_pregunta, p_opcion)` | `correcto, puntos_obtenidos, puntos_totales, respondidas, total_preguntas, repetida, expira_en`                    |
| `finalizar_partida(p_partida)`              | `partida, desafio, estado, total_preguntas, respondidas, aciertos, errores, puntos, duracion_ms, iniciado_en, expira_en, finalizado_en, reutilizado` |
| `resultado_partida(p_partida)`              | Detalle por pregunta: enunciado, opción elegida, correcta, explicación, puntos, respondida, tiempo y `revelado`                    |
| `ranking_desafio(p_desafio, p_limite)`      | `posicion, alias, alias_sufijo, puntos, aciertos, total_preguntas, duracion_ms, finalizado_en, es_yo, partida`                    |
| `hora_servidor()`                           | `hora` (timestamptz del servidor)                                                                                                 |

### Inicio de partida

- **Exige sesión** (`PR_AUTH_REQUIRED`): vale tanto un invitado anónimo como
  una cuenta registrada.
- **Idempotente** por `(participante_id, clave)`: repetir la misma clave
  devuelve la MISMA partida con `reutilizado = true`, aunque el desafío ya haya
  cerrado (es un reintento de red o un doble toque, no un intento nuevo).
- **Consume un intento**: una clave nueva crea otra partida. Si se alcanzó
  `intentos_permitidos` → `PR_INTENTOS_AGOTADOS`.
- `pg_advisory_xact_lock` serializa los inicios del mismo participante en el
  mismo desafío: dos peticiones simultáneas no superan el límite de intentos.
- El servidor fija las **preguntas asignadas** y la **foto de las reglas**
  (puntos, duración y tolerancia).
- Valida que el desafío y su evento estén `publicado`, dentro de
  `inicia_en..termina_en`, con preguntas (`PR_DESAFIO_SIN_PREGUNTAS`) y con
  solución válida para cada pregunta (`PR_DESAFIO_INCOMPLETO`).

### Respuesta

`responder_partida` valida, en este orden:

1. sesión (`PR_AUTH_REQUIRED`);
2. partida propia, con bloqueo de fila (`PR_PARTIDA_NOT_FOUND`);
3. pregunta asignada a esa partida (`PR_PREGUNTA_NO_ASIGNADA`);
4. opción perteneciente a esa pregunta (`PR_OPCION_INVALIDA`);
5. respuesta previa: si existe, **devuelve la guardada** con `repetida = true`
   y no vuelve a sumar (ni siquiera si la partida ya cerró);
6. partida `en_curso` (`PR_PARTIDA_CERRADA`);
7. vigencia: `now() <= expira_en` (`PR_PARTIDA_EXPIRADA`);
8. solución cargada (`PR_SOLUCION_NO_DISPONIBLE`).

Luego inserta con `ON CONFLICT DO NOTHING` y recalcula los totales de la
partida desde las respuestas guardadas. Dos envíos simultáneos de la misma
pregunta: solo uno inserta y suma.

### Cierre

`finalizar_partida` bloquea la partida y clasifica:

| Estado       | Condición                                                                 |
| ------------ | ------------------------------------------------------------------------- |
| `finalizada` | Todas las preguntas respondidas y cierre dentro de `expira_en + tolerancia`. |
| `incompleta` | Se cerró antes, con preguntas sin responder.                              |
| `vencida`    | El cierre ocurrió después de `expira_en + tolerancia_segundos`.           |

Es **idempotente**: si la partida ya no está `en_curso`, devuelve el mismo
resultado con `reutilizado = true`. Calcula aciertos, errores, puntos y
`duracion_ms` (hasta la última respuesta) desde las respuestas guardadas.

### Detalle y ranking

- `resultado_partida` solo funciona con la partida **cerrada**
  (`PR_PARTIDA_EN_CURSO` si sigue abierta). Mientras el desafío o el evento
  sigan abiertos, devuelve `revelado = false` y **no** entrega la opción
  correcta ni la explicación: revelarlas permitiría mejorar un segundo intento
  o pasarle las respuestas a otra persona. Al cerrar el desafío o el evento, el
  detalle se revela.
- `ranking_desafio` es **público** (se consulta sin sesión) y devuelve el
  **mejor intento válido por participante**:
  - solo `estado = 'finalizada'` (`incompleta` y `vencida` no compiten);
  - `distinct on (participante_id)` elige el mejor intento;
  - desempate: más puntos, menor `duracion_ms` (medida en el servidor) y
    finalización más temprana;
  - `es_yo` se calcula para cada participante y `p_limite` se acota a 1..200.

## Tiempo y reconexión

- El inicio (`iniciado_en`) y el vencimiento (`expira_en`) los fija el
  servidor con `now()`. El cliente **no envía tiempos**.
- El temporizador de la interfaz usa `hora_servidor()` para no depender del
  reloj del celular. Aun si el reloj local está mal, las validaciones reales
  usan `now()` en cada función.
- Después de `expira_en` **no se aceptan respuestas nuevas**
  (`PR_PARTIDA_EXPIRADA`), pero se puede finalizar durante
  `tolerancia_segundos` para guardar lo ya respondido (plazo de reconexión).
- Pasado ese plazo, la partida se cierra como `vencida`.

## Puntajes oficiales

- Los puntos por acierto, los aciertos, los errores y el tiempo los calcula y
  guarda **solo el servidor**.
- El cliente **no puede insertar, modificar ni borrar** `partidas`,
  `partida_preguntas` ni `partida_respuestas` por REST: solo puede leer sus
  propias filas.
- **No se permite borrar partidas** (no hay política de `DELETE`): borrarlas
  reiniciaría el límite de intentos y permitiría ocultar resultados malos antes
  del ranking.
- Repetir un desafío **no suma puntos sin límite**: cada inicio consume un
  intento y solo el mejor intento válido cuenta para el ranking.

## Estados y casos de uso

| Situación                                          | Efecto                                                                  |
| -------------------------------------------------- | ----------------------------------------------------------------------- |
| Se corta la conexión o se cierra la app            | La partida queda `en_curso`; se puede retomar dentro del plazo.         |
| Se reabre el desafío con la misma clave            | Se devuelve la misma partida (`reutilizado = true`).                    |
| Se responde dos veces la misma pregunta            | Se conserva la primera respuesta; el segundo envío no suma.             |
| Se responde desde otra cuenta                      | `PR_PARTIDA_NOT_FOUND`: la partida no pertenece al participante.        |
| Se intenta responder una pregunta de otro desafío  | `PR_PREGUNTA_NO_ASIGNADA`.                                              |
| Se envía una opción de otra pregunta               | `PR_OPCION_INVALIDA`.                                                   |
| Se responde después del plazo                      | `PR_PARTIDA_EXPIRADA`.                                                  |
| Se finaliza dos veces                              | El segundo cierre devuelve el mismo resultado (`reutilizado = true`).   |
| Se agotan los intentos                             | `PR_INTENTOS_AGOTADOS`; la misma clave sigue devolviendo su partida.    |
| El desafío o el evento cierran                     | El detalle revela la opción correcta y la explicación.                  |

## Códigos de error

| Código                       | Cuándo aparece                                              |
| ---------------------------- | ----------------------------------------------------------- |
| `PR_AUTH_REQUIRED`           | No hay sesión.                                              |
| `PR_INVALID_KEY`             | La clave de idempotencia no mide entre 8 y 100 caracteres.  |
| `PR_DESAFIO_NOT_FOUND`       | El desafío no existe.                                       |
| `PR_DESAFIO_CERRADO`         | El desafío o su evento no están publicados o están fuera de fecha. |
| `PR_DESAFIO_SIN_PREGUNTAS`   | El desafío no tiene preguntas.                              |
| `PR_DESAFIO_INCOMPLETO`      | Alguna pregunta no tiene solución válida.                   |
| `PR_INTENTOS_AGOTADOS`       | Se alcanzó `intentos_permitidos`.                           |
| `PR_PARTIDA_NOT_FOUND`       | La partida no existe o no es del participante.              |
| `PR_PREGUNTA_NO_ASIGNADA`    | La pregunta no pertenece a la partida.                      |
| `PR_OPCION_INVALIDA`         | La opción no pertenece a la pregunta.                       |
| `PR_PARTIDA_CERRADA`         | La partida ya no está `en_curso`.                           |
| `PR_PARTIDA_EXPIRADA`        | Pasó `expira_en` y no hay respuesta previa.                 |
| `PR_SOLUCION_NO_DISPONIBLE`  | La pregunta no tiene solución cargada.                      |
| `PR_PARTIDA_EN_CURSO`        | Se pidió el resultado de una partida abierta.               |

## RLS

- `eventos`, `desafios`, `desafio_preguntas`, `desafio_opciones`: lectura
  pública solo si el evento y el desafío están `publicado` o `cerrado`.
- `desafio_soluciones`: `revoke all` y sin política de lectura.
- `partidas`, `partida_preguntas`, `partida_respuestas`: `SELECT` solo de las
  filas propias (`participante_id = auth.uid()`).
- Sin políticas de INSERT/UPDATE/DELETE sobre las tablas de partidas: la
  escritura ocurre únicamente por las funciones anteriores.
- `ranking_desafio` y `hora_servidor` se pueden ejecutar sin sesión; jugar
  (`iniciar_partida`, `responder_partida`, `finalizar_partida`,
  `resultado_partida`) exige `authenticated`.

## Cliente

- `src/data/challengeRepository.js`: envuelve las RPC y las lecturas del evento,
  desafíos, preguntas asignadas, respuestas, resultado, ranking, hora del
  servidor e historial completo del participante.
- `src/pages/ExpoPage.vue`: muestra el evento publicado, diferencia **práctica**
  y **competencia**, lista los desafíos y explica las reglas del ranking.
- `src/pages/ChallengePage.vue`: intro con reglas, inicio o reanudación,
  juego con temporizador de servidor, finalización, resultado con detalle y
  ranking. El resultado se muestra cuando el servidor confirma el guardado; si
  falla, ofrece **Reintentar guardado**.
- `src/pages/ProfilePage.vue`: sección "Desafíos de la expo" con el historial
  (válida, incompleta, vencida o sin terminar) y la métrica de desafíos válidos.

## Datos iniciales (semilla)

| Elemento              | ID                                     | Reglas                                        |
| --------------------- | -------------------------------------- | --------------------------------------------- |
| Evento público        | `40000000-…-000000000001`              | Expo Doulingo 2026, `publicado`               |
| Evento interno        | `40000000-…-000000000002`              | `es_prueba = true` (oculto en la UI)          |
| Fundamentos exprés    | `50000000-…-000000000001`              | fácil · 90 s · 10 pts · 2 intentos · tol. 20 s |
| Lógica intermedia     | `50000000-…-000000000002`              | intermedio · 120 s · 15 pts · 1 intento · tol. 30 s |
| Cierre difícil        | `50000000-…-000000000003`              | difícil · 150 s · 20 pts · 1 intento · tol. 30 s |
| Prueba normal         | `50000000-…-000000000101`              | 4 preguntas · 300 s · 2 intentos · tol. 10 s  |
| Prueba vencida        | `50000000-…-000000000102`              | 1 s · sin tolerancia                          |
| Prueba de un intento  | `50000000-…-000000000103`              | 1 intento                                     |

## Pruebas

- `node tests/e2e/challenges.mjs` comprueba contra el proyecto real:
  separación del banco y de `check_answer()`, creación e idempotencia de la
  partida, reglas fijadas por el servidor, validaciones de pertenencia,
  vigencia y opción, doble envío (incluso simultáneo), dos jugadores
  concurrentes, cierre idempotente, partida incompleta, vencida, ranking por
  mejor intento, aislamiento entre participantes, hora del servidor y escritura
  directa de puntajes denegada.
- `node tests/e2e/challenges_ui.mjs` recorre la interfaz: enlace y listado de
  la expo, diferenciación práctica/competencia, juego completo como invitado
  (puntaje 40), resultado y detalle sin revelar soluciones, ranking, historial
  en el perfil, partida vencida y reintento de guardado.

Requieren `0006_desafios.sql` y `0007_seed_desafios.sql` aplicadas y los
invitados anónimos habilitados. Los desafíos `es_prueba = true` permiten jugar,
vencer y agotar intentos sin tocar los datos de producción de la expo.
