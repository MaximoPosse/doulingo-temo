# Pruebas end-to-end

Suites de comprobación automática (Puppeteer + el navegador del sistema) que
verifican la aplicación contra el proyecto real de Supabase.

## Preparación

```bash
npm install                      # instala puppeteer-core (dependencia de desarrollo)
npm run build                    # genera dist/spa
node tests/e2e/serve.mjs         # sirve la build en http://localhost:9100
```

La configuración del proyecto Supabase se lee del `.env` de la raíz
(`VITE_SUPABASE_URL` y `VITE_SUPABASE_PUBLISHABLE_KEY`).

Variables opcionales:

| Variable       | Para qué sirve                     | Por defecto              |
| -------------- | ---------------------------------- | ------------------------ |
| `E2E_BASE_URL` | Origen de la app probada           | `http://localhost:9100`  |
| `E2E_BROWSER`  | Ruta del navegador (Edge o Chrome) | se busca automáticamente |
| `E2E_PORT`     | Puerto del servidor estático       | `9100`                   |

## Suites

| Comando                          | Qué comprueba                                                                                                                               |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `node tests/e2e/buttons.mjs`     | Recorrido de la interfaz: botones, navegación, estados de la lección (26 casos).                                                            |
| `node tests/e2e/dbtest.mjs`      | Contenido publicado, RLS, RPC `check_answer` y contexto limpio (25 casos).                                                                  |
| `node tests/e2e/case7.mjs`       | Fallo de red al comprobar una respuesta: avisa, no marca mal y permite reintentar (5 casos).                                                |
| `node tests/e2e/case3.mjs`       | Cambio de un título desde el panel de Supabase y su reflejo en la app.                                                                      |
| `node tests/e2e/auth.mjs`        | API de Supabase Auth: invitado, registro, login, recuperación, RLS y conversión (8 casos).                                                  |
| `node tests/e2e/auth.mjs ui`     | Lo anterior más el recorrido de la pantalla de acceso en el navegador.                                                                      |
| `node tests/e2e/auth_ui.mjs`     | Pantalla de acceso sin depender de la configuración del proyecto (5 casos).                                                                 |
| `node tests/e2e/alias.mjs`       | Alias público, sufijo y aislamiento del perfil entre participantes (11 casos).                                                              |
| `node tests/e2e/attempts.mjs`    | Intentos, respuestas, idempotencia, progreso calculado en el servidor y aislamiento (35 casos).                                             |
| `node tests/e2e/attempts_ui.mjs` | Guardado confirmado, perfil (último intento + historial + respuestas), aislamiento entre dispositivos y fallo de red al guardar (14 casos). |

`auth.mjs` y `auth.mjs ui` necesitan que el proyecto tenga **habilitados los
invitados anónimos** y aplicado `supabase/migrations/0004_auth.sql`; si no, los
casos dependientes fallan y lo indican en el mensaje.

`attempts.mjs`, `attempts_ui.mjs` y el guardado real de resultados necesitan
además `supabase/migrations/0005_intentos.sql` aplicada: sin ella la app avisa
"No se pudo comenzar el intento" y no permite responder.

Los casos que necesitan **enviar correo** se marcan `SKIP` cuando el proyecto
agotó su cupo de 2 correos por hora: el resumen los separa de los fallos
reales y el proceso termina con éxito.

Los resultados de la última ejecución están en
[`docs/11-pruebas-auth.md`](../../docs/11-pruebas-auth.md) y
[`docs/09-pruebas-supabase.md`](../../docs/09-pruebas-supabase.md).
