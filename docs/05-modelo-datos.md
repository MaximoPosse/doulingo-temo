# 05 · Modelo de datos (diagrama entidad-relación)

## Consideración previa

Doulingo separa **dos mundos de datos** que conviene no confundir:

1. **Contenido educativo (publicación)**: lo que se enseña (cursos, unidades,
   lecciones, actividades, opciones). Es "el producto" y hoy vive en
   `src/data/` accedido a través de `courseRepository.js`.
2. **Avance del participante (progreso)**: si una persona completó o aprobó una
   lección y cuántos aciertos obtuvo en su intento. Es individual y hoy se
   guarda en `localStorage` a través de `useProgress.js`.

En una etapa siguiente, ambas partes pasarán a la base de datos compartida;
el repositorio `courseRepository` ya centraliza todas las lecturas para que
las pantallas no cambien.

## Diagrama entidad-relación (conceptual)

```
CURSO 1 ───── 1 N UNIDAD 1 ───── 1 N LECCION 1 ───── 1 N ACTIVIDAD 1 ───── 1 N OPCION
        contiene          contiene          contiene          contiene

USUARIO 1 ───── 1 N INTENTO_DE_LECCION N ───── 1 LECCION
              realiza                  de
```

## Especificación de tablas

### Contenido educativo (publicación)

**CURSOS**

| Campo        | Tipo     | PK  | FK  | Obligatorio | Restricciones                       |
| ------------ | -------- | --- | --- | ----------- | ----------------------------------- |
| id           | VARCHAR  | ✓   | –   | ✓           | identificador único                 |
| slug         | VARCHAR  | –   | –   | ✓           | UNIQUE, formato url-safe            |
| titulo       | VARCHAR  | –   | –   | ✓           | –                                   |
| descripcion  | TEXT     | –   | –   | ✓           | –                                   |
| nivel        | VARCHAR  | –   | –   | ✓           | ej. "Principiante"                  |
| estado       | VARCHAR  | –   | –   | ✓           | CHECK: 'disponible'\|'proximamente' |
| color        | VARCHAR  | –   | –   | ✓           | código hex (#f7df1e)                |
| icono        | VARCHAR  | –   | –   | ✓           | nombre de ícono Material            |
| unidades_tot | SMALLINT | –   | –   | ✓           | CHECK: > 0                          |

**UNIDADES**

| Campo       | Tipo     | PK  | FK          | Obligatorio | Restricciones                      |
| ----------- | -------- | --- | ----------- | ----------- | ---------------------------------- |
| id          | VARCHAR  | ✓   | –           | ✓           | identificador único                |
| curso_id    | VARCHAR  | –   | → CURSOS.id | ✓           | –                                  |
| orden       | SMALLINT | –   | –           | ✓           | CHECK: > 0; UNIQUE por curso       |
| titulo      | VARCHAR  | –   | –           | ✓           | –                                  |
| descripcion | TEXT     | –   | –           | ✓           | –                                  |
| icono       | VARCHAR  | –   | –           | ✓           | nombre de ícono Material           |
| publicada   | BOOLEAN  | –   | –           | ✓           | CHECK: 0/1 (estado de publicación) |

**LECCIONES**

| Campo          | Tipo     | PK  | FK          | Obligatorio | Restricciones                 |
| -------------- | -------- | --- | ----------- | ----------- | ----------------------------- |
| id             | VARCHAR  | ✓   | –           | ✓           | identificador único           |
| unidad_id      | VARCHAR  | –   | → UNIDAD.id | ✓           | –                             |
| orden          | SMALLINT | –   | –           | ✓           | CHECK: > 0; UNIQUE por unidad |
| titulo         | VARCHAR  | –   | –           | ✓           | –                             |
| explicacion    | TEXT     | –   | –           | ✓           | –                             |
| ejemplo_codigo | TEXT     | –   | –           | –           | opcional (puede ser NULL)     |

**ACTIVIDADES**

| Campo      | Tipo     | PK  | FK           | Obligatorio | Restricciones                  |
| ---------- | -------- | --- | ------------ | ----------- | ------------------------------ |
| id         | VARCHAR  | ✓   | –            | ✓           | identificador único            |
| leccion_id | VARCHAR  | –   | → LECCION.id | ✓           | –                              |
| puesto     | SMALLINT | –   | –            | ✓           | CHECK: > 0; UNIQUE por lección |
| tipo       | VARCHAR  | –   | –            | ✓           | CHECK: 'choice' (por ahora)    |
| enunciado  | TEXT     | –   | –            | ✓           | –                              |
| codigo_opc | TEXT     | –   | –            | –           | opcional (fragmento a evaluar) |

**OPCIONES**

| Campo        | Tipo    | PK  | FK             | Obligatorio | Restricciones                             |
| ------------ | ------- | --- | -------------- | ----------- | ----------------------------------------- |
| id           | VARCHAR | ✓   | –              | ✓           | identificador único                       |
| actividad_id | VARCHAR | –   | → ACTIVIDAD.id | ✓           | –                                         |
| texto        | TEXT    | –   | –              | ✓           | –                                         |
| es_correcta  | BOOLEAN | –   | –              | ✓           | CHECK: 0/1; exactamente UNA por actividad |

> Nota de implementación actual: el JSON de actividades define las opciones con
> `id` y marca la correcta con `answerOptionId`, equivalente lógico a un único
> `es_correcta = 1` por actividad.

### Avance del participante

**USUARIOS**

| Campo  | Tipo    | PK  | FK  | Obligatorio | Restricciones   |
| ------ | ------- | --- | --- | ----------- | --------------- |
| id     | INTEGER | ✓   | –   | ✓           | autoincremental |
| email  | VARCHAR | –   | –   | ✓           | UNIQUE          |
| nombre | VARCHAR | –   | –   | ✓           | –               |

**INTENTO_DE_LECCION**

| Campo        | Tipo      | PK  | FK            | Obligatorio | Restricciones                     |
| ------------ | --------- | --- | ------------- | ----------- | --------------------------------- |
| usuario_id   | INTEGER   | ✓   | → USUARIOS.id | ✓           | compone la PK                     |
| leccion_id   | VARCHAR   | ✓   | → LECCION.id  | ✓           | compone la PK                     |
| aciertos     | SMALLINT  | –   | –             | ✓           | CHECK: 0 ≤ aciertos ≤ total       |
| total        | SMALLINT  | –   | –             | ✓           | CHECK: > 0                        |
| aprobada     | BOOLEAN   | –   | –             | ✓           | derivado: aciertos ≥ umbral (60%) |
| fecha_ultimo | TIMESTAMP | –   | –             | ✓           | último intento                    |

> La tabla guarda el **resultado del último intento** (los intentos anteriores
> se descartan; "repetir" reinicia el conteo hasta que se llega a resultados).
> UNIQUE(usuario_id, leccion_id).

## Implementación actual en JavaScript

| Tabla lógica                                  | Archivo / estructura                                                          |
| --------------------------------------------- | ----------------------------------------------------------------------------- |
| CURSOS                                        | `src/data/courses.js` (catálogo) + `src/data/javascriptCourse.js` (contenido) |
| UNIDADES / LECCIONES / ACTIVIDADES / OPCIONES | `src/data/javascriptCourse.js` (objetos anidados)                             |
| Lecturas centralizadas                        | `src/data/courseRepository.js` (único punto de acceso)                        |
| INTENTO_DE_LECCION                            | `src/composables/useProgress.js` → `localStorage` clave `doulingo-progress`   |
