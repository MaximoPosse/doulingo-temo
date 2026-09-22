# 07 · Registro de pruebas

## Entorno de prueba

| Ítem           | Valor                                                                     |
| -------------- | ------------------------------------------------------------------------- |
| Fecha          | 22/09/2026                                                                |
| Aplicación     | dev server Quasar (Vite) sobre http://localhost:9100                      |
| Navegador      | Microsoft Edge (Chromium) en modo headless                                |
| Automatización | puppeteer-core + CDP, perfil de navegador nuevo por corrida               |
| Datos          | `javascriptCourse.js` (unidad `fundamentos`, 2 lecciones × 3 actividades) |
| Progreso       | `localStorage` (perfil limpio al iniciar)                                 |

Las pruebas recargan cada ruta como lo haría una persona que abre la URL y
hacen clic en los controles reales (opciones, CONFIRMAR, CONTINUAR/VER
RESULTADOS, Intentar nuevamente, Volver a la unidad, navegación del header).

## Casos obligatorios (consigna del proyecto)

### Caso 1 — CONFIRMAR sin haber seleccionado una opción

- Pasos: abrir lección → Comenzar → no elegir opción.
- Esperado: botón CONFIRMAR deshabilitado; no se puede avanzar.
- Obtenido: **OK** (`disabled=true`, no cambio de pantalla).

### Caso 2 — Responder correctamente

- Pasos: elegir opción correcta (A) → CONFIRMAR.
- Esperado: CONFIRMAR se habilita al elegir; devolución "¡Correcto!" + explicación.
- Obtenido: **OK**.

### Caso 3 — Responder incorrectamente

- Pasos: elegir opción incorrecta (B) → CONFIRMAR.
- Esperado: devolución "Respuesta incorrecta" indicando cuál era la correcta.
- Obtenido: **OK** (incluye la explicación y el texto de la opción correcta).

### Caso 4 — Presionar CONFIRMAR varias veces

- Pasos: elegir respuesta y disparar 3 clics síncronos sobre CONFIRMAR.
- Esperado: la respuesta se cuenta una sola vez.
- Obtenido: **OK** (2 aciertos reales de 3 → 67%; no se duplicó el conteo; el
  guardado interno queda bloqueado tras el primer envío).

### Caso 5 — Completar la última actividad

- Pasos: responder las 3 actividades hasta el botón VER RESULTADOS.
- Esperado: al confirmar la última, aparece la pantalla de resultados
  (actividades, correctas, incorrectas, porcentaje, estado aprobada/reprobada).
- Obtenido: **OK** (2/3, 67%, "Lección aprobada").

### Caso 6 — Repetir la lección

- Pasos: en resultados → Intentar nuevamente → repetir el flujo.
- Esperado: se reinician respuestas y resultados; el contador vuelve a
  "Actividad 1 de 3"; el nuevo intento no hereda el anterior.
- Obtenido: **OK** (2.º intento con 3 incorrectas → 0%; 3.º intento 3/3 → 100%).

### Caso 7 — Volver a la unidad

- Pasos: desde la introducción de la lección → "Volver a la unidad".
- Esperado: regresa a la página de la unidad (lista de lecciones con estados).
- Obtenido: **OK**.

### Caso 8 — URL de lección inexistente

- Pasos: abrir `#/cursos/javascript/unidad/fundamentos/leccion/no-existe`.
- Esperado: aviso "Lección no encontrada" con botón para volver.
- Obtenido: **OK** (también verificados unidad y curso inexistentes).

### Caso 9 — Pantalla en móvil

- Pasos: viewport 375×667 en cursos y lección con ejemplo de código.
- Esperado: sin desborde horizontal, botones operables, 4 opciones visibles.
- Obtenido: **OK** (overflow 0 px en ambas pantallas; 4 opciones visibles).

## Casos complementarios verificados

| Caso | Prueba                                                  | Resultado |
| ---- | ------------------------------------------------------- | --------- |
| 10   | Aprobar lección 1 desbloquea lección 2 (`Disponible`)   | **OK**    |
| 11   | Aprobar todas las lecciones → unidad `Completada` (2/2) | **OK**    |
| 12   | Progreso global del curso (2/2, 100%) en detalle        | **OK**    |
| 13   | Lección bloqueada muestra aviso (no ejecutable)         | **OK**    |
| 14   | Unidad en preparación (pendiente) no navegable          | **OK**    |

## Resultado final

**26/26 casos OK** en la corrida automatizada completa. Progreso final en
`localStorage`: `approvedLessons = ["fundamentos-1","fundamentos-2"]`.

## Errores encontrados y corregidos durante las pruebas

1. **Curso disponible mostrado como "próximamente"**: `getCourseBySlug()` del
   repositorio devuelve el contenido educativo (sin campo `status`), y la
   pantalla de detalle usaba ese campo para decidir disponibilidad. Corregido
   en `CourseDetailPage.vue`: la disponibilidad se resuelve desde el catálogo
   (`courses.js`), el contenido solo aporta unidades/lecciones.
2. **Etiquetas en pantalla**: el texto de las tarjetas aparece en mayúsculas
   por estilos globales (`text-transform`); es intencional del diseño.
3. **Navegación entre hashes en el harness**: recargar la URL con solo cambiar
   el hash no re-renderizaba en la automatización (comportamiento del
   navegador); las pruebas recargan la ruta completa como un usuario real.

## Cómo re-ejecutar las pruebas

```bash
# 1) Levantar el proyecto en el puerto 9100
npm run dev -- --port 9100

# 2) Desde un directorio temporal con puppeteer-core instalado:
node edgetest.mjs   # 26/26 en http://localhost:9100
```
