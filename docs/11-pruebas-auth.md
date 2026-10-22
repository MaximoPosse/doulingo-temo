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
  - `alias.mjs` → alias público, sufijo y aislamiento del perfil.
  - `buttons.mjs`, `dbtest.mjs`, `case7.mjs`, `case3.mjs` → etapas anteriores.
- Preparación: `npm install`, `npm run build`, `node tests/e2e/serve.mjs` (sirve
  la build en el puerto 9100) y después la suite que se quiera correr.

## 2. Configuración del proyecto (verificada)

| Comprobación                  | Resultado verificado                                                                      | Impacto en las pruebas                                    |
| ----------------------------- | ----------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| Invitados anónimos            | **Habilitados** (`signInAnonymously` → 200, `is_anonymous: true`)                         | Los flujos de invitado, conversión y RLS se pueden probar |
| SQL de la etapa 4             | **Aplicado**: `perfiles` y `participant_progress` existen; el trigger crea el perfil solo | Todo el modelo de datos funciona                          |
| Confirmación de correo        | **Exigible** (el alta devuelve 200 con usuario y sin sesión)                              | No hay sesión hasta confirmar el correo                   |
| SMTP incluido                 | Solo entrega a **miembros del equipo** y con **2 correos por hora**                       | Los casos que envían correo fallan hasta reponer el cupo  |
| Restricción de altas anónimas | 30 por hora y por IP                                                                      | La app reutiliza la sesión guardada en el dispositivo     |

Pendiente en el panel: **Authentication → URL Configuration** (Site URL y
Redirect URLs de la app y del esquema del APK) y el correo de confirmación
(agregar un miembro del equipo o configurar un SMTP propio).

### El límite de 2 correos por hora

Supabase restringe a **2 correos por hora por proyecto** cuando se usa el
servicio de correo incluido (documentación oficial de Supabase). Ese es el
motivo de los casos fallidos: no es un defecto de la aplicación, es el límite
del servicio de correo de demostración. Se resuelve con un SMTP propio
(30 correos por hora, ajustable en **Authentication → Rate Limits**) o
esperando a que se reponga el cupo.

## 3. Fase A · API de Supabase Auth (`auth.mjs`)

| Caso | Descripción                                             | Resultado  | Observación                                                            |
| ---- | ------------------------------------------------------- | ---------- | ---------------------------------------------------------------------- |
| A1   | El invitado anónimo puede crear su sesión               | PASA       | `is_anonymous: true` y sesión emitida                                  |
| A2   | Dos invitados tienen identificadores distintos          | PASA       | `1549dc4b` vs `b4945a10`                                               |
| A3   | Cada alta anónima crea una identidad nueva              | PASA       | No hay cuenta compartida entre dispositivos                            |
| A4   | Registro: la cuenta se crea                             | PASA/OMITE | `429 over_email_send_rate_limit` cuando el cupo está agotado           |
| A4   | Registro: con confirmación activa no hay sesión todavía | PASA       | Se verifica que con confirmación activa no hay sesión                  |
| A4   | Registro: correo ya utilizado → aviso claro             | PASA/OMITE | Con el ofuscado de correo de Supabase responde `email_address_invalid` |
| A5   | Login: contraseña inválida → aviso claro                | PASA       | `400 invalid_credentials` mapeado a mensaje en español                 |
| A6   | Recuperación: la solicitud se acepta                    | PASA       | `HTTP 200` sin enumerar si el correo existe                            |
| A7   | El invitado guarda y lee su propio progreso             | PASA       | Su fila en `participant_progress`                                      |
| A7   | RLS: no lee el progreso de otro                         | PASA       | Devuelve 0 filas                                                       |
| A7   | RLS: no escribe en el progreso de otro                  | PASA       | `new row violates row-level security policy`                           |
| A7   | RLS: no modifica el progreso de otro                    | PASA       | 0 filas afectadas; la fila ajena queda intacta                         |
| A7   | El perfil propio existe con alias y sufijo              | PASA       | `alias: invitado`, `alias_sufijo: 2fe6`                                |
| A7   | RLS: no puede cambiar el alias de otro                  | PASA       | 0 filas afectadas                                                      |
| A7   | El alias de otro es visible (es público)                | PASA       | Lectura pública de `perfiles`                                          |
| A8   | Conversión: la cuenta invitada se convierte             | PASA/OMITE | `email rate limit exceeded` (necesita enviar un correo)                |
| A8   | Conversión: conserva el mismo identificador             | PASA/OMITE | No se puede ejecutar sin completar la conversión                       |
| A8   | Conversión: deja de ser anonymous                       | PASA/OMITE | Ídem anterior                                                          |
| A8   | Conversión: conserva el historial                       | PASA       | La fila de progreso sigue ahí                                          |

**Resumen: 22/22 OK (7 omitidos).** Los casos omitidos dependen **solo** del
envío de correo (cupo de 2 por hora agotado): la suite los marca como
`SKIP` con el motivo y no los cuenta como error, de modo que un resultado
verde significa “todo lo verificable pasó”. La conversión exige
`updateUser({ email, password })`: con un SMTP propio o al reponerse el cupo,
el mismo código los resuelve sin cambios.

### Fase A' · Alias y sufijo (`alias.mjs`)

| Caso | Descripción                                                         | Resultado | Observación                                        |
| ---- | ------------------------------------------------------------------- | --------- | -------------------------------------------------- |
| A1   | El invitado tiene perfil con alias y sufijo                         | PASA      | `invitado` + 4 hexadecimales                       |
| A2   | El alias cumple las reglas (3-20, minúsculas y guion bajo)          | PASA      | —                                                  |
| A3   | El invitado arranca marcado como invitado                           | PASA      | `es_invitado: true`                                |
| A4   | Tres invitados se distinguen (`alias#sufijo` distintos)             | PASA      | `invitado#f07a`, `invitado#9790`, `invitado#4545`  |
| A5   | Cada invitado tiene su propio identificador                         | PASA      | —                                                  |
| A6   | El alias de otra persona es visible (es público)                    | PASA      | Lectura pública de `perfiles`                      |
| A7   | Nadie puede cambiar el alias de otra persona (RLS)                  | PASA      | 0 filas afectadas                                  |
| A8   | Insertar de nuevo el propio perfil choca por el identificador       | PASA      | `23505 … "perfiles_pkey"`                          |
| A9   | El error dice que es la clave primaria                              | PASA      | Permite distinguir “ya existe” de “alias ocupado”  |
| A10  | No se puede insertar un perfil con el identificador de otra persona | PASA      | `42501 new row violates row-level security policy` |
| A11  | El sufijo coincide con los 4 primeros del identificador             | PASA      | `f07a` = `f07a89b3…`                               |

**Resumen: 11/11 OK.**

> La unicidad de la combinación `alias + alias_sufijo` solo puede dispararla el
> trigger `handle_new_user` (nadie más inserta perfiles), y para eso hace falta
> un identificador cuyo prefijo de 4 hexadecimales choque con el de otro
> participante. Como el identificador lo genera Supabase, esa colisión no se
> puede provocar desde las pruebas; por eso el trigger y el cliente la evitan
> probando ventanas successive del identificador (ver `docs/10-auth.md`).

Comprobación adicional (`verify_auth_setup.mjs`): la conversión con
`updateUser({ password })` **sin correo** es rechazada por Supabase
(_“Updating password of an anonymous user without an email or phone is not
allowed”_), por lo que la conversión exige correo + contraseña.

## 4. Fase B · Recorrido de interfaz (`auth_ui.mjs`)

| Caso | Descripción                                                  | Resultado | Observación                                                            |
| ---- | ------------------------------------------------------------ | --------- | ---------------------------------------------------------------------- |
| B1   | `/perfil` sin sesión redirige a `/acceso`                    | PASA      | Redirección a `#/acceso?next=/perfil`                                  |
| B2   | El acceso como invitado obtiene sesión propia                | PASA      | “Sesión activa como invitado#6e89 (invitado)”                          |
| B3   | Credenciales inválidas → mensaje claro, sin datos crudos     | PASA      | “Correo o contraseña incorrectos” (sin `AuthApiError` ni códigos HTTP) |
| B4   | El registro explica las reglas del alias (3 a 20 caracteres) | PASA      | Texto de ayuda visible en el formulario                                |
| B5   | Sin errores de JavaScript en la página                       | PASA      | Consola limpia                                                         |

**Resumen: 5/5 OK.**

Y en la suite completa (`auth.mjs ui`), la fase B de la aplicación:

| Caso | Descripción                                        | Resultado | Observación                         |
| ---- | -------------------------------------------------- | --------- | ----------------------------------- |
| B1   | Ruta protegida sin sesión → `/acceso`              | PASA      | `#/acceso?next=/perfil`             |
| B2   | El invitado obtiene sesión en la app               | PASA      | `invitado#fdd7`                     |
| B3   | El perfil muestra el nombre público `alias#sufijo` | PASA      | Coincide con el patrón `alias#4hex` |
| B4   | Al reabrir la app se restaura la sesión            | PASA      | Mismo alias antes y después         |
| B5   | Cerrar sesión vuelve al acceso                     | PASA      | `#/acceso`                          |
| B6   | Sin errores de página en el flujo de acceso        | PASA      | Consola limpia                      |

**Resumen fase B: 6/6 OK.**

Pruebas de interfaz de las etapas anteriores que siguen en verde con los
cambios de autenticación:

| Suite                     | Resultado | Qué cubre                                             |
| ------------------------- | --------- | ----------------------------------------------------- |
| `buttons.mjs` (prod 9100) | **26/26** | Navegación completa, sin errores de consola           |
| `buttons.mjs` (dev 9000)  | **26/26** | Lo mismo en desarrollo                                |
| `dbtest.mjs`              | **25/25** | Contenido remoto, RLS y RPC `check_answer`            |
| `case7.mjs`               | **5/5**   | Fallo de red: no marca incorrecto y permite reintento |

## 5. Defectos detectados y corregidos en esta etapa

| #   | Defecto                                                                                            | Causa                                                                     | Corrección                                                                                                            |
| --- | -------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| 1   | La página de acceso mostraba “Sesión activa” **sin** tener sesión                                  | `hasSession` se calculaba con `publicName`, que nunca es vacío            | `hasSession` ahora se calcula con `session` (`src/pages/AuthPage.vue`)                                                |
| 2   | La barra superior mostraba “Participante” a los visitantes                                         | `publicName` como etiqueta por defecto                                    | La etiqueta es el alias con sesión y “Acceder” sin ella (`src/layouts/MainLayout.vue`)                                |
| 3   | Un contexto limpio guardaba la clave `doulingo-progress` aunque no hubiera avance                  | Al reiniciar el progreso sin sesión se escribía la clave heredada         | Sin sesión y sin avance no se escribe nada (`src/composables/useProgress.js`)                                         |
| 4   | El avance hecho sin sesión se perdía al iniciar sesión si el participante ya tenía copia propia    | Solo se adoptaba la clave heredada cuando no había copia del participante | Ahora se **une** con la copia del participante (`src/composables/useProgress.js`)                                     |
| 5   | “Borrar historial” solo borraba la copia local                                                     | El botón llamaba a `resetProgress()`                                      | Ahora borra también las filas propias en la base (`clearHistory()`)                                                   |
| 6   | La prueba de RLS daba un falso negativo al actualizar una fila ajena                               | Sin `.select()` PostgREST devuelve `data: null` (no un array vacío)       | La comprobación usa `.select()` y acepta lista vacía (`tests/e2e/auth.mjs`)                                           |
| 7   | La prueba de UI fallaba aunque el invitado funcionara                                              | Se leía el texto antes de que terminara la llamada a Supabase             | La prueba espera a que aparezca el texto (`waitForText`)                                                              |
| 8   | La prueba de UI usaba una sesión de invitado para comprobar el formulario de ingreso               | El contexto del navegador se reutilizaba entre comprobaciones             | Cada comprobación usa un contexto nuevo (`tests/e2e/auth_ui.mjs`)                                                     |
| 9   | Un choque de `alias + alias_sufijo` abortaba el alta del usuario (el trigger fallaba)              | El sufijo era siempre los 4 primeros hexadecimales del identificador      | El trigger y el cliente prueban ventanas successive del identificador (`0004_auth.sql`, `src/data/authRepository.js`) |
| 10  | Registrar un correo ya usado mostraba un error crudo en inglés                                     | Supabase activa el ofuscado de correo: responde `email_address_invalid`   | `authErrorMessage()` traduce ese error a un aviso en español (`src/data/authRepository.js`)                           |
| 11  | Un perfil creado por el cliente quedaba marcado como invitado aunque la cuenta ya fuera permanente | `ensureProfile` fijaba `es_invitado: true` a ciegas                       | `ensureProfile` recibe el estado real de la sesión (`src/composables/useAuth.js`)                                     |

Correcciones de robustez aplicadas durante la implementación:

- el manejador de `onAuthStateChange` se ejecuta diferido (`setTimeout`) para
  evitar el bloqueo de `supabase-js` al inicializar;
- los errores de Supabase se traducen a mensajes en español y nunca se
  muestra el objeto crudo (`AuthApiError`, códigos HTTP) al usuario;
- el formulario de registro valida alias (3-20, `[a-z0-9_]`), correo y
  contraseña antes de llamar a la API;
- el límite de correos del proyecto tiene su propio mensaje: _“El proyecto
  alcanzó el límite de correos por hora que puede enviar”_.

## 6. Casos que faltan por configuración del proyecto

Estos casos están implementados y listos, pero **no pueden ejecutarse** hasta
completar la configuración:

1. **Registro con confirmación de correo**: alta → correo → enlace → sesión
   iniciada. Requiere un correo que reciba el SMTP del proyecto (miembro del
   equipo) o un SMTP propio, y cupo disponible.
2. **Conversión**: invitado → cuenta permanente conservando `auth.uid()`,
   alias e historial. Requiere un correo nuevo (y por lo tanto cupo).
3. **Recuperación de contraseña**: alta → “olvidé mi contraseña” → enlace →
   contraseña nueva → inicio de sesión con la nueva. Requiere el correo.
4. **Prueba dentro del APK**: abrir los enlaces con esquema propio y comprobar
   que la sesión queda iniciada al volver a la app. El proyecto de Capacitor ya
   está en el repositorio y el APK se genera con `npx quasar build -m capacitor
-T android` (ver [`docs/12-apk.md`](12-apk.md)); lo que no se puede verificar
   sin un dispositivo es el toque real del enlace.

Lo que **ya quedó verificado** con la configuración actual: alta de invitado
anónimo, alias propio con sufijo, aislamiento de RLS (lectura, escritura y
modificación de filas ajenas), lectura pública del alias, progreso propio
guardado en la base, restauración de sesión al reabrir la app, ruta protegida
y cierre de sesión.

### Verificaciones del APK (12 de octubre de 2026)

| Verificación                                          | Resultado                                                        |
| ----------------------------------------------------- | ---------------------------------------------------------------- |
| Build nativo (`quasar build -m capacitor -T android`) | BUILD SUCCESSFUL                                                 |
| `assembleDebug` (APK firmado e instalable)            | `app-debug.apk` — 4,7 MB                                         |
| Paquete y versión (`aapt2 dump badging`)              | `com.doulingo.app` · label “Doulingo” · minSdk 24 · targetSdk 36 |
| `intent-filter` del esquema dentro del APK            | `scheme=doulingo`, `host=auth`, `pathPrefix=/callback`           |
| Firma (`apksigner verify`)                            | firmante “Android Debug” (instalable; para producción, keystore) |
| Código del deep link dentro de los assets del APK     | presente (`appUrlOpen`)                                          |
| Regresión en la web (bundle con Capacitor)            | botones 26/26 · UI auth 5/5 · base de datos 25/25                |

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
npm run test:e2e:alias      # alias público, sufijo y aislamiento (11 casos)

node tests/e2e/case3.mjs    # cambio de datos desde el panel (requiere edición manual)
```

Los casos que necesitan enviar correo se marcan `SKIP` cuando el proyecto
agotó su cupo de 2 correos por hora: no son un error del código y el resumen
los separa de los fallos reales.
