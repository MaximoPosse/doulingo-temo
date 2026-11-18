# 16 · Manuales breves y preparación del cierre

Este documento agrega una guía operativa breve para participantes y
administradores y reúne las referencias de la entrega. No reemplaza las
entregas aprobadas ni vuelve a redactar su fundamentación.

## Manual para participantes

### Instalar e ingresar

1. Instalar `app-debug.apk` para pruebas (o la versión release firmada para
   distribución) y abrir **CodeLingua**. En Android, autorizar la instalación si
   se comparte el APK directamente.
2. En **Expo**, elegir un desafío. Se puede jugar como **invitado** o registrar
   una cuenta con correo y contraseña. El invitado puede participar y ver el
   puntaje; para conservar una identidad permanente, registrarse.
3. Para confirmar registro o recuperar contraseña, abrir el correo recibido y
   tocar el enlace en el mismo celular donde se inició el pedido. Debe abrir
   CodeLingua mediante `doulingo://auth/callback`. Si Android pregunta con qué app
   abrirlo, elegir CodeLingua.

### Jugar y consultar resultados

1. Leer cantidad de preguntas, duración, puntos por acierto e intentos.
2. Iniciar y responder antes de que venza el reloj. El tiempo oficial lo mide
   el servidor; no cerrar la app para detenerlo.
3. Confirmar cada respuesta. Al terminar, usar **Finalizar partida** y esperar
   el mensaje **Resultado guardado en el servidor** antes de salir.
4. Consultar puntos, respuestas, historial del perfil y ranking del desafío.
   El ranking toma el mejor intento válido de cada participante; incompletas y
   vencidas no compiten. La pantalla de ranking se actualiza al tocar **Actualizar**
   y también automáticamente cada 30 segundos.
5. Si se corta la red, volver a conectarse y continuar la partida si sigue
   vigente. Las respuestas y los puntajes oficiales requieren conexión.
6. Para salir, usar **Volver a la expo** o el botón Atrás de Android. La partida
   no se borra: si queda en curso, consume un intento y puede reanudarse dentro
   del plazo. Una partida vencida o incompleta permanece en el historial.

## Manual para administradores

1. Ingresar con una cuenta autorizada como administradora y abrir
   `/#/admin`. El panel verifica `es_admin()` en la base de datos; ocultar una
   ruta no reemplaza los permisos de PostgreSQL/RLS.
2. Usar las pestañas **Eventos**, **Desafíos**, **Preguntas de desafíos**,
   **Opciones de desafíos** y **Soluciones de desafíos** para preparar el
   contenido. Revisar el orden, las fechas, el puntaje, duración, intentos,
   tolerancia y solución correcta antes de publicar.
3. Mantener el evento/desafío en **Borrador** mientras se prepara. Cambiarlo a
   **Publicado** habilita el acceso público según las fechas. Al cerrar la
   competencia, cambiar el estado del evento a **Cerrado**; a partir de ese
   momento se revelan soluciones y explicaciones en los detalles.
4. Antes de la expo, verificar el evento desde un navegador sin sesión, hacer
   una partida de ensayo con datos de prueba y confirmar que el ranking público
   se actualice. No borrar partidas para corregir ensayos: el historial es
   deliberado y las partidas consumen intentos.
5. Si una cuenta no debe seguir ingresando, usar el flujo administrativo de
   baja lógica que corresponda. No borrar datos directamente ni compartir
   contraseñas, claves Supabase o keystores.

## Ensayo de defensa y demostración

Preparar dos celulares físicos con la misma build y dos participantes
independientes (por ejemplo, un invitado y una cuenta registrada):

1. Desde cada celular ingresar al mismo desafío y completar una partida. Mostrar
   en ambos la confirmación de guardado y puntajes obtenidos del servidor.
2. Dejar abierto el ranking público en un tercer equipo/pantalla o en uno de los
   celulares. Confirmar que la suscripción Realtime lo actualice; si no, tocar
   **Actualizar** o esperar el refresco de 30 segundos.
3. Mostrar historial y mejor intento, luego cerrar el evento desde la sesión
   administrativa y comprobar el estado cerrado. No usar cuentas de prueba con
   información personal en la exposición.
4. Completar la lista de compatibilidad (pantallas, teclado, Atrás, cierre y
   reapertura, red desconectada/restaurada) en los dispositivos usados y anotar
   modelo, versión Android, fecha y resultado.

En la ejecución técnica local del 15/11/2026 no había dispositivos conectados a
ADB. Por eso la instalación del APK nuevo y la demostración concurrente en dos
celulares **no están certificadas aún**. No marcar esos pasos como aprobados
hasta hacerlos físicamente.

## Índice del informe final

Conservar las entregas ya aprobadas y actualizarlas solo donde la expo y el APK
añadieron alcance:

| Tema del informe                    | Fuente existente                                                                                       |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Fundamentación y alcance            | `docs/01-objetivo.md`                                                                                  |
| Estructura y arquitectura de la app | `docs/02-estructura.md`, `README.md`                                                                   |
| Historias/recorridos y pantallas    | `docs/03-wireframes.md`, `docs/07-pruebas.md`                                                          |
| Identidad visual                    | `docs/04-identidad-visual.md`                                                                          |
| DER/diccionario de datos            | `docs/05-modelo-datos.md`, `supabase/README.md`                                                        |
| Reglas de negocio y avance          | `docs/06-reglas-avance.md`, `docs/13-intentos.md`, `docs/14-desafios.md`                               |
| Seguridad, Auth y RLS               | `docs/09-pruebas-supabase.md`, `docs/10-auth.md`                                                       |
| Pruebas, aportes y cambios          | `docs/07-pruebas.md`, `docs/08-aportes.md`, `docs/11-pruebas-auth.md`, `docs/15-ranking-admin-expo.md` |
| Paquete Android y versiones         | `docs/12-apk.md`                                                                                       |
| Manuales y demostración             | este archivo                                                                                           |

Las ampliaciones principales son el banco de competencia separado de práctica,
la partida y puntaje calculados por el servidor, el ranking por mejor intento,
la administración del contenido de expo, el deep link nativo para Auth y el
APK Capacitor. Revisar el DER/diccionario y el alcance del informe para reflejar
estos agregados sin rehacer las secciones aprobadas.

## Estado al 17/11/2026

- Informe final y manuales PDF generados (ver `docs/17-informe-final.md`).
- APK debug y **release firmado** generados desde terminal; clave fuera del
  repositorio (`%USERPROFILE%\.android\doulingo-release.jks`).
- El proyecto Supabase estaba pausado (DNS sin resolver); se reactivó y las
  suites e2e se re-ejecutaron: 222 casos OK, 7 omitidos por cupo de correos.

## Pendientes antes de la entrega pública

- Ejecutar manualmente en Supabase las migraciones de competencia aún
  pendientes y verificar el host/proyecto correcto; este repositorio no aplica
  SQL remoto.
- Probar registro, recuperación, invitado, práctica, competencia, historial y
  ranking contra el proyecto activo.
- Instalar la build debug actual en **al menos dos celulares físicos** y
  completar el ensayo de la sección anterior.
- Generar la clave release en almacenamiento seguro fuera de Git, custodiar un
  respaldo y producir/verificar el APK release siguiendo `docs/12-apk.md`.
- Repetir el checklist al cerrar la expo: cierre del evento, acceso de solo
  lectura a resultados, publicación de soluciones y respaldo de resultados.

La indicación “Cerrada la expo, revisar” se interpreta como revisar el estado
general del proyecto antes de la entrega. Esta actualización cubre la
configuración y compilación Android, los recursos empacados, el deep link, la
firma y la documentación; las comprobaciones presenciales pendientes están
señaladas arriba.
