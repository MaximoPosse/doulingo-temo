# 11 · Pruebas de la etapa de autenticación

Registro de las pruebas de acceso, sesión, alias y RLS ampliada. Complementa
[`docs/09-pruebas-supabase.md`](09-pruebas-supabase.md) (etapa de base de
datos) y [`docs/07-pruebas.md`](07-pruebas.md) (etapa de la interfaz).

## 1. Entorno y herramientas

- Proyecto Supabase real: `https://apgmzypxbzuvprbedbzi.supabase.co`.
- Pruebas de interfaz con **Puppeteer + Edge headless** sobre la build de
  producción servida de forma estática (`dist/spa` en `http://localhost:9100`)
  y sobre el servidor de desarrollo (`http://localhost:9000`).
- Las suites viven **en el repositorio**, en `tests/e2e/` (con `puppeteer-core`
  como dependencia de desarrollo). Ver `tests/e2e/README.md`.
  - `auth.mjs` → fase A (API de Supabase Auth) y fase B (recorrido de UI).
  - `auth_ui.mjs` → comprobaciones de UI que **no dependen de la configuración
    del proyecto** (ruta protegida, mensajes de error, reglas del alias).
  - `buttons.mjs`, `dbtest.mjs`, `case7.mjs`, `case3.mjs` → etapas anteriores.
- Preparación: `npm install`, `npm run build`, `node tests/e2e/serve.mjs` (sirve
  la build en el puerto 9100) y después la suite que se quiera correr.

## 2. Configuración del proyecto detectada (y su impacto)

| Comprobación                    | Resultado observed                                           | Impacto en las pruebas                                       |
| ------------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| Confirmación de correo          | **Exigible** (el alta devuelve 200 con usuario y sin sesión) | No hay sesión hasta confirmar el correo                      |
| Invitados anónimos              | **Deshabilitados** (`Anonymous sign-ins are disabled`)       | Los flujos de invitado y conversión no pueden ejecutarse     |
| SMTP incluido                   | Solo entrega a **miembros del equipo**, con cupo de envíos   | El correo de confirmación no llega a buzones externos        |
| Alta duplicada en menos de 60 s | `429 over_email_send_rate_limit`                             | Las pruebas de registro deben espaciarse o sortear el límite |

Configuración pendiente en el panel (Authentication → Providers → Anonymous
Sign Ins y Authentication → URL Configuration) y aplicación de
`supabase/migrations/0004_auth.sql`.

## 3. Fase A · API de Supabase Auth (`auth.mjs`)

| Caso | Descripción                                          | Resultado | Observación                                                               |
| ---- | ---------------------------------------------------- | --------- | ------------------------------------------------------------------------- |
| A1   | El invitado anónimo puede crear su sesión            | **FALLA** | `Anonymous sign-ins are disabled` (configuración del panel)               |
| A2   | Dos invitados tienen identificadores distintos       | **FALLA** | Depende de A1                                                             |
| A3   | El registro crea la cuenta sin sesión (confirmación) | PASA      | Se verifica que con confirmación activa no hay sesión todavía             |
| A4   | Registro con correo ya utilizado → aviso claro       | **FALLA** | El proyecto limitó el envío de correos (`429 over_email_send_rate_limit`) |
| A5   | Login con contraseña inválida → aviso claro          | PASA      | `400 invalid_credentials` mapeado a mensaje en español                    |
| A6   | La recuperación de acceso se acepta                  | PASA      | `HTTP 200` sin enumerar si el correo existe                               |
| A7   | RLS: cada participante solo ve sus datos             | **FALLA** | Requiere las sesiones de invitado de A1                                   |
| A8   | La conversión conserva el identificador              | **FALLA** | Requiere A1                                                               |

**Resumen: 3/8 OK.** Los cinco casos fallidos no son defectos de la
implementación: dependen de habilitar los invitados anónimos y de que el
cupo de correos del proyecto lo permita.

## 4. Fase B · Recorrido de interfaz (`auth_ui.mjs`)

| Caso | Descripción                                                  | Resultado | Observación                                                            |
| ---- | ------------------------------------------------------------ | --------- | ---------------------------------------------------------------------- |
| B1   | `/perfil` sin sesión redirige a `/acceso`                    | PASA      | Redirección a `#/acceso?next=/perfil`                                  |
| B2   | El botón de invitado informa cómo habilitarlo                | PASA      | Mensaje: “El acceso como invitado no está habilitado en el proyecto…”  |
| B3   | Credenciales inválidas → mensaje claro, sin datos crudos     | PASA      | “Correo o contraseña incorrectos” (sin `AuthApiError` ni códigos HTTP) |
| B4   | El registro explica las reglas del alias (3 a 20 caracteres) | PASA      | Texto de ayuda visible en el formulario                                |
| B5   | Sin errores de JavaScript en la página                       | PASA      | Consola limpia                                                         |

**Resumen: 5/5 OK.**

Pruebas de interfaz de las etapas anteriores que siguen en verde con los
cambios de autenticación:

| Suite                     | Resultado | Qué cubre                                             |
| ------------------------- | --------- | ----------------------------------------------------- |
| `buttons.mjs` (prod 9100) | **26/26** | Navegación completa, sin errores de consola           |
| `buttons.mjs` (dev 9000)  | **26/26** | Lo mismo en desarrollo                                |
| `dbtest.mjs`              | **25/25** | Contenido remoto, RLS y RPC `check_answer`            |
| `case7.mjs`               | **5/5**   | Fallo de red: no marca incorrecto y permite reintento |

## 5. Defectos detectados y corregidos en esta etapa

| #   | Defecto                                                                                         | Causa                                                                     | Corrección                                                                             |
| --- | ----------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| 1   | La página de acceso mostraba “Sesión activa” **sin** tener sesión                               | `hasSession` se calculaba con `publicName`, que nunca es vacío            | `hasSession` ahora se calcula con `session` (`src/pages/AuthPage.vue`)                 |
| 2   | La barra superior mostraba “Participante” a los visitantes                                      | `publicName` como etiqueta por defecto                                    | La etiqueta es el alias con sesión y “Acceder” sin ella (`src/layouts/MainLayout.vue`) |
| 3   | Un contexto limpio guardaba la clave `doulingo-progress` aunque no hubiera avance               | Al reiniciar el progreso sin sesión se escribía la clave heredada         | Sin sesión y sin avance no se escribe nada (`src/composables/useProgress.js`)          |
| 4   | El avance hecho sin sesión se perdía al iniciar sesión si el participante ya tenía copia propia | Solo se adoptaba la clave heredada cuando no había copia del participante | Ahora se **une** con la copia del participante (`src/composables/useProgress.js`)      |
| 5   | “Borrar historial” solo borraba la copia local                                                  | El botón llamaba a `resetProgress()`                                      | Ahora borra también las filas propias en la base (`clearHistory()`)                    |

Correcciones de robustez aplicadas durante la implementación:

- el manejador de `onAuthStateChange` se ejecuta diferido (`setTimeout`) para
  evitar el bloqueo de `supabase-js` al inicializar;
- los errores de Supabase se traducen a mensajes en español y nunca se
  muestra el objeto crudo (`AuthApiError`, códigos HTTP) al usuario;
- el formulario de registro valida alias (3-20, `[a-z0-9_]`), correo y
  contraseña antes de llamar a la API.

## 6. Casos que faltan por configuración del proyecto

Estos casos están implementados y listos, pero **no pueden ejecutarse** hasta
completar la configuración:

1. **Invitado completo**: alta anónima → alias propio → practicar → historial
   en la base → recargar → el historial sigue ahí.
2. **Conversión**: invitado → cuenta permanente conservando `auth.uid()`,
   alias e historial.
3. **Aislamiento por RLS**: dos participantes con progreso propio; cada uno
   solo ve lo suyo (no ve ni puede escribir filas ajenas).
4. **Confirmación de correo**: alta → correo → enlace → sesión iniciada.
   Requiere un correo que reciba el SMTP del proyecto (miembro del equipo) o
   un SMTP propio.
5. **Recuperación de contraseña**: alta → “olvidé mi contraseña” → enlace →
   contraseña nueva → inicio de sesión con la nueva.
6. **Prueba dentro del APK**: abrir los enlaces con esquema propio y comprobar
   que la sesión queda iniciada al volver a la app. El repositorio todavía no
   incluye el proyecto de Capacitor, así que es una verificación manual sobre
   la app empaquetada.

## 7. Comandos de verificación

```bash
npm run lint:check          # formato + lint
npm run build               # build de producción
npm run serve:e2e           # sirve la build en http://localhost:9100

npm run test:e2e:buttons    # recorrido de interfaz (26 casos)
npm run test:e2e:db         # contenido, RLS y RPC (25 casos)
npm run test:e2e:network    # manejo de fallo de red (5 casos)
npm run test:e2e:auth-ui    # pantalla de acceso (5 casos)
npm run test:e2e:auth       # API de Supabase Auth (8 casos) + "ui" para la fase B

node tests/e2e/case3.mjs    # cambio de datos desde el panel (requiere edición manual)
```
