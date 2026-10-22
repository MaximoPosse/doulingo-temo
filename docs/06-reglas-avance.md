# 06 · Reglas de avance del participante

## Diferencia entre "completar" y "aprobar"

| Concepto       | Definición                                                                                                         | ¿Habilita la siguiente? |
| -------------- | ------------------------------------------------------------------------------------------------------------------ | ----------------------- |
| **Completada** | Se finalizó un intento: se llegó a la pantalla de resultados (las 3 actividades fueron respondidas y verificadas). | No                      |
| **Aprobada**   | En ese intento, los aciertos alcanzaron el **umbral mínimo (60%)**.                                                | Sí                      |
| **Reprobada**  | Completada pero por debajo del umbral.                                                                             | No                      |

Una lección "completada" queda registrada como intentada; solo "aprobada"
cuenta para desbloquear y para el progreso de la unidad.

## Umbral de aprobación

`aciertos >= ceil(totalActividades * 0.6)`

| Total de actividades | Aciertos necesarios |
| -------------------- | ------------------- |
| 3                    | 2                   |
| 4                    | 3                   |
| 5                    | 3                   |

## Estados de una lección

| Estado       | Condición                                                   |
| ------------ | ----------------------------------------------------------- |
| `pendiente`  | La unidad no está publicada (`published: false`).           |
| `bloqueada`  | Unidad publicada y la lección anterior **no fue aprobada**. |
| `disponible` | Está habilitada y aún no se registró un intento.            |
| `aprobada`   | Tiene un intento que alcanzó el umbral.                     |
| `reprobada`  | Tiene un intento que no alcanzó el umbral.                  |

- La primera lección de una unidad publicada siempre está `disponible`.
- `aprobada` y `reprobada` permiten **repetir** (reintentar) la lección.

## Estados de una unidad

| Estado       | Condición                                                                          |
| ------------ | ---------------------------------------------------------------------------------- |
| `pendiente`  | `published: false` (en preparación).                                               |
| `bloqueada`  | Unidad publicada y la anterior no está completada (todas sus lecciones aprobadas). |
| `disponible` | Habilitada y aún no todas sus lecciones aprobadas.                                 |
| `completada` | **Todas** sus lecciones publicadas y aprobadas.                                    |

La primera unidad del curso siempre está habilitada.

## Comportamiento de "Intentar nuevamente"

1. Reinicia el estado del intento local: contador de actividades, selección,
   verificaciones y aciertos vuelven a cero.
2. Lleva de nuevo a la introducción de la lección (teoría).
3. Los resultados del intento anterior NO se suman al nuevo: cada intento se
   guarda aparte y el progreso de la lección conserva el mejor resultado (nunca
   baja uno ya aprobado) y la cantidad de intentos finalizados.
4. Una respuesta se contabiliza una sola vez: el botón "CONFIRMAR" se
   deshabilita tras pulsarlo (reemplazado por "CONTINUAR"/"VER RESULTADOS") y,
   pese a múltiples pulsaciones simultáneas, el guardado solo se ejecuta con el
   primer envío.

## Desbloqueo en cadena

```
Lección 1 aprobada ──► Lección 2 disponible
Lección 2 aprobada ──► ... todas aprobadas ──► Unidad completada
Unidad completada  ──► Unidad siguiente disponible (si está publicada)
```

## Persistencia

- Con sesión (invitado o cuenta permanente) el avance se guarda en la base
  compartida, atado a `auth.uid()`:
  - `intentos` e `intentos_respuestas` (detalle de cada intento);
  - `participant_progress` (resumen por lección; lo escribe **solo**
    `finalizar_intento()`).
- El dispositivo mantiene una **copia local** de trabajo en `localStorage`:
  clave `doulingo-progress` sin sesión y `doulingo-progress:<uid>` con sesión,
  con la estructura
  `{ attemptedLessons: [leccionId], approvedLessons: [leccionId] }`.
- El resultado se muestra solo cuando el servidor confirma el guardado. Si
  falla, la app avisa y ofrece **Reintentar guardado** sin dar el intento por
  finalizado.
- Un intento que se abandona (salida, cierre de la app o pérdida de conexión)
  queda `en_curso`: no cuenta como lección completada hasta que se finaliza.
- El detalle del modelo y las decisiones están en `docs/13-intentos.md`.

## Diferenciación publicación vs avance

- La **publicación** (unidad `published`, curso `status`) es propiedad del
  contenido y la controla el equipo que edita los datos.
- El **avance** depende exclusivamente de los intentos del usuario y nunca
  modifica el contenido.
- Cambiar la publicación (publicar unidad 2) no altera el progreso ya
  registrado de las unidades anteriores.
