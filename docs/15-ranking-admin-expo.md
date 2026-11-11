# Ranking público y administración

## Pantalla de expo

La ruta `/ranking/<EVENTO_UUID>` es una pantalla de solo lectura. También puede
usarse `/ranking/` si se define `VITE_EXPO_EVENT_ID` en el entorno de la
computadora de la expo. El UUID debe ser el mismo evento de Supabase, no una
clave privada.

La pantalla llama a `ranking_evento()` para la carga inicial y después de cada
evento Realtime. Se suscribe exclusivamente a `resultados_publicos`, nunca a
una vista SQL ni a `partidas`. Una consulta periódica de 30 segundos, el botón
Actualizar y la reapertura de conexión sirven como respaldo. Muestra la última
actualización y un aviso cuando pierde conexión. Los datos públicos son solo
posición, alias, puntaje y desafío; no se envían correos, contraseñas,
respuestas, partidas ni UUID de participantes.

Aplicar `0008_ranking_admin.sql` en el mismo proyecto. Supabase Realtime debe
mostrar `resultados_publicos` en la publicación `supabase_realtime`; la
migración lo intenta habilitar y debe verificarse en Database → Publications.
La tabla tiene RLS de lectura únicamente para eventos publicados/cerrados.

Reglas: una partida es elegible solo si `estado = finalizada`; se conserva el
mejor resultado por participante y desafío; desempate por mayor puntaje, menor
duración medida por servidor y finalización más temprana. La proyección pública
no conserva identificadores privados. El alias anunciado es `alias#sufijo`, y
debe acordarse con participantes antes de la expo.

## Administración

El rol vive en `admin_roles` y se consulta mediante `es_admin()` SECURITY
DEFINER. La asignación se hace desde el SQL Editor o un procedimiento de
servidor; no se toma de `perfiles`, metadata ni campos editables por el
cliente. La ruta `/admin` solo mejora la experiencia: RLS también bloquea a
una cuenta común aunque fuerce la URL o cambie el navegador.

La despublicación cambia el estado y conserva historial. No borrar contenido
con relaciones activas. Antes de publicar una lección, ejecutar
`validar_leccion(id)`: exige preguntas y una solución que apunte a una opción
de su propia pregunta. Las restricciones de claves foráneas y órdenes evitan
relaciones inválidas. Para desafíos activos se conserva la foto de preguntas y
reglas en `partidas`; no se deben editar reglas mientras haya partidas.

## Pruebas de aceptación

1. Crear tres participantes en tres dispositivos y abrir `/ranking/<id>` en un
   cuarto navegador.
2. Finalizar partidas con puntajes distintos y empatados; comprobar la misma
   posición/puntaje en los cuatro clientes, recarga y actualización automática.
3. Cerrar o perder red en la pantalla, comprobar el aviso, reconectar y usar
   Actualizar. Comprobar que una partida incompleta/vencida no aparece.
4. Probar lectura con anon, edición con una cuenta común y con un admin.
   Anon debe leer solo la proyección mínima; la cuenta común debe recibir
   `PR_ADMIN_REQUIRED`/RLS al escribir.
5. Comparar alias visibles con la lista anunciada a participantes y confirmar
   que no aparece correo, contraseña, respuesta ni identificador privado.

## Respaldo y recuperación

Conservar en control de versiones `supabase/migrations/*.sql` y una exportación
de contenido sin secretos (`supabase db dump --data-only --schema public`, o
exportación equivalente). Guardar el respaldo fuera del repositorio. Nunca
incluir `service_role`, `sb_secret`, contraseñas ni tokens.

Para recuperar: crear un proyecto vacío, aplicar migraciones en orden, cargar
contenido validado, reasignar `admin_roles` manualmente y verificar RLS,
Realtime y el UUID del evento. Luego ejecutar las pruebas de aceptación antes
de abrir la pantalla de la expo.
