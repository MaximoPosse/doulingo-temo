# 09 · Pruebas de la etapa de base de datos (Supabase)

Registro de las pruebas de la integración con Supabase: consultas de contenido,
seguridad (RLS), comprobación de respuestas y estados de UI.

## Entorno

- Aplicación Vue 3 + Quasar servida en `http://localhost:9100` (`npm run dev`).
- Backend: proyecto Supabase `doulingo` con `supabase/migrations/*.sql`
  aplicados.
- Herramienta de navegador: Microsoft Edge en modo headless controlado con
  `puppeteer-core`.
- Nota: sin `.env` configurado la app **no** consulta datos; muestra los estados
  de error con botón Reintentar (ver casos 6 y 7, ejecutables sin backend).

## Preparación

1. Aplicar `0001_schema.sql`, `0002_seed.sql`, `0003_rls.sql` en el SQL Editor.
2. Completar `.env` con `VITE_SUPABASE_URL` y `VITE_SUPABASE_ANON_KEY`.
3. `npm run dev` y abrir `http://localhost:9100`.

## Casos

| #   | Caso                                     | Pasos                                                                         | Resultado esperado                                                                                                           | Estado                       |
| --- | ---------------------------------------- | ----------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- | ---------------------------- |
| 1   | Curso disponible y sus unidades          | Abrir `/cursos`; entrar a "JavaScript desde cero".                            | Aparece el curso disponible; al abrirlo se listan sus 5 unidades (1 disponible y 4 en preparación).                          | Pendiente (requiere backend) |
| 2   | Filtrado por relación (curso → unidades) | Abrir el curso y contar unidades.                                             | Solo se muestran unidades cuyo `curso_id` corresponde al curso abierto.                                                      | Pendiente (requiere backend) |
| 3   | Cambiar un título en la base             | Editar el `titulo` de una unidad en Supabase; recargar la app.                | El nuevo título aparece sin tocar código: la base es la fuente de verdad.                                                    | Pendiente (requiere backend) |
| 4   | Respeto del campo `orden`                | Insertar/editar filas con `orden` fuera de secuencia; recargar.               | Unidades, lecciones y preguntas se muestran ordenadas por `orden`, no por orden de inserción.                                | Pendiente (requiere backend) |
| 5   | Identificador inexistente                | Abrir `/cursos/no-existe`, una unidad y una lección inexistentes.             | Mensajes claros de "no encontrado"; la app no se rompe.                                                                      | Pendiente (requiere backend) |
| 6   | Sin conexión al consultar contenido      | Con backend inalcanzable/sin `.env`, abrir `/cursos` y `/cursos/:slug`.       | Estado de error con mensaje y botón **Reintentar**; al restablecer, Reintentar vuelve a cargar.                              | **OK** (headless)            |
| 7   | Sin conexión al comprobar una respuesta  | En una actividad, cortar la conexión y presionar CONFIRMAR.                   | No se marca como incorrecta: aparece "No se pudo comprobar tu respuesta" y se puede reintentar sin contabilizar.             | Pendiente (requiere backend) |
| 8   | Visitante no modifica (RLS)              | Con la anon key, intentar INSERT/UPDATE/DELETE sobre `cursos`/`unidades`/etc. | La operación es denegada; no se modifica ningún contenido.                                                                   | Pendiente (requiere backend) |
| 9   | Soluciones no consultables               | Con la anon key, hacer `SELECT` sobre `soluciones`.                           | No se obtienen filas. La respuesta solo se conoce vía `check_answer()` (RPC).                                                | Pendiente (requiere backend) |
| 10  | Completar una lección                    | Recorrer una lección, responder las 3 actividades y ver resultados.           | Se obtiene el resultado; con ≥ 2 correctas la lección queda aprobada y se habilita la siguiente; progreso en `localStorage`. | Pendiente (requiere backend) |
| 11  | Unidad sin lecciones publicadas          | Abrir directamente la URL de una unidad en preparación.                       | Mensaje "Esta unidad no tiene lecciones publicadas todavía".                                                                 | Pendiente (requiere backend) |
| 12  | Dos navegadores                          | Abrir la app en dos navegadores/perfiles distintos con la misma base.         | Ambos ven el mismo contenido publicado (compartido) y avances independientes.                                                | Pendiente (requiere backend) |

## Automatizado

- `npm run lint:check` (oxfmt + oxlint) y `npm run build` deben pasar sin errores.
- Prueba de humo headless (Edge + `puppeteer-core`) sobre `/cursos` con backend
  inalcanzable: se verifica el estado **Cargando → Error** y la presencia del
  botón **Reintentar** (caso 6). Script: ver `edgetest.mjs` (herramienta local).

## Resultados

_(Completar a medida que se ejecutan contra un proyecto Supabase real.)_

- Build y lint: **OK** (ver commit).
- Caso 6 (sin conexión / sin `.env`): **OK** en modo headless sobre la build de
  producción servida en `http://localhost:9100`. En `/cursos` y
  `/cursos/javascript` se muestra el estado de error
  ("No se pudieron cargar los cursos" / "No se pudo cargar el curso") con el
  botón **Reintentar** y sin errores de página (`pageerror` vacío).
- Casos que requieren backend (1-5, 7-12): **pendientes** de ejecutar contra el
  proyecto Supabase del equipo.
