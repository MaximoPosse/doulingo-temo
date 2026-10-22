# 10 · Acceso, identidad y sesión (Supabase Auth)

Diseño de la etapa de autenticación: acceso como invitado, registro con correo,
inicio y cierre de sesión, alias visible, conversión de invitado a cuenta
permanente, rutas protegidas y ampliación de las políticas RLS.

## 1. Tres situaciones, una sola identidad

| Situación              | Sesión              | Identificador         | Qué puede hacer                            |
| ---------------------- | ------------------- | --------------------- | ------------------------------------------ |
| **Visitante** (`anon`) | sin sesión          | ninguno               | leer el contenido publicado y practicar    |
| **Invitado**           | sesión anónima      | id de Auth propio     | practicar, guardar su historial en la base |
| **Cuenta permanente**  | correo + contraseña | id de Auth (el mismo) | todo lo anterior + recuperar el acceso     |

El invitado **no comparte cuenta con nadie**: cada dispositivo crea su propia
sesión anónima (`signInAnonymously`), con su propio `auth.users.id`. Ese
identificador es la clave de su historial.

## 2. Modelo de datos de la identidad

Dos tablas nuevas (`supabase/migrations/0004_auth.sql`):

```
auth.users (Supabase Auth)
   │  1 : 1  (FK, on delete cascade)
   ▼
public.perfiles ──── id (uuid, PK, FK auth.users.id)
                    alias        text   3-20 chars, [a-z0-9_]
                    alias_sufijo text   4 hex, derivado del id
                    es_invitado  bool
                    creado_en / actualizado_en

public.participant_progress ── id        (uuid, FK auth.users.id)  ─┐
                            ├── leccion_id (uuid, FK lecciones.id)   ├─ PK compuesta
                            ├── estado      ('intentada'|'aprobada')
                            ├── intentos / mejor_aciertos / total_actividades
                            └── actualizado_en
```

Decisiones:

- **No hay tabla de usuarios propia.** Las contraseñas viven únicamente en
  Supabase Auth; en el proyecto no se guarda ninguna contraseña ni hash.
- **Sin duplicación de datos:** el progreso no copia títulos ni contenido, solo
  referencias (`leccion_id`). El contenido sigue en sus tablas.
- **El alias no es único por sí solo.** La pareja `alias#alias_sufijo` sí lo es:
  el sufijo son 4 caracteres hexadecimales del id de Auth, de modo que dos
  personas con el mismo alias se distinguen (`usagi#3f1a`).
- **Un choque de sufijo nunca bloquea un alta.** Como la pareja es única en la
  base, si el sufijo propuesto ya estuviera tomado el alta fallaría. Por eso el
  trigger `handle_new_user` y el cliente (`ensureProfile`) prueban ventanas
  sucesivas del identificador (`3f1a`, `3f1a…`, `3f1a…`) hasta encontrar una
  pareja libre.
- **Alias permitido:** 3 a 20 caracteres, minúsculas, dígitos y guion bajo. Se
  normaliza en el cliente (`normalizar_alias`) y en el servidor
  (`normalizar_alias(text)`); si queda vacío se usa `invitado`.

### RLS ampliada (rol público vs. autenticado)

| Tabla                   | `anon` (sin sesión)     | `authenticated` (invitado o cuenta)                   |
| ----------------------- | ----------------------- | ----------------------------------------------------- |
| Contenido (`cursos`, …) | lectura de lo publicado | lectura de lo publicado (igual que `anon`)            |
| `soluciones`            | sin lectura             | sin lectura (solo vía `check_answer`)                 |
| `perfiles`              | lectura (alias público) | lectura + insertar/editar **solo el propio**          |
| `participant_progress`  | sin acceso              | **solo sus propias filas** (leer/crear/editar/borrar) |

Cada política usa `auth.uid()`, así que un participante no puede leer ni
escribir datos de otro. La tabla `perfiles` solo permite actualizar la columna
`alias` de la fila propia.

## 3. Qué se guarda y qué se muestra públicamente

| Dato                  | Dónde                                   | ¿Público?                                        |
| --------------------- | --------------------------------------- | ------------------------------------------------ |
| Alias + sufijo        | `perfiles`                              | **Sí**, es la identidad visible del participante |
| Correo electrónico    | Supabase Auth                           | No                                               |
| Identificador de Auth | `auth.users.id`                         | No                                               |
| Contraseña            | Supabase Auth (nunca en la base propia) | No                                               |
| Token de sesión       | almacenamiento del navegador            | No                                               |
| Historial por lección | `participant_progress`                  | No (en esta etapa)                               |

## 4. Flujos

### 4.1 Invitado

1. La persona pulsa **“Continuar como invitado”** en `/acceso`.
2. `signInAnonymously()` crea una sesión anónima **propia**.
3. Se crea (o recupera) su perfil en `perfiles` y se asocia el historial.
4. Si el proyecto tiene deshabilitados los invitados anónimos, la app lo
   explica con el mensaje: _“El acceso como invitado no está habilitado en el
   proyecto. Activalo en Supabase → Authentication → Providers → Anonymous
   Sign Ins.”_

### 4.2 Registro con correo y contraseña

1. Alias, correo y contraseña en `/acceso → Crear cuenta`.
2. `signUp({ email, password, data: { alias } })`.
3. Según la configuración del proyecto:
   - **sin confirmación**: hay sesión y se entra directo;
   - **con confirmación** (configuración actual del proyecto): se informa
     _“Te enviamos un correo para confirmar la cuenta”_ y hay un botón para
     reenviarlo. La cuenta existe, pero no hay sesión hasta confirmar.
4. El alta del perfil la hace el trigger `on_auth_user_created`, que normaliza
   el alias y calcula el sufijo.
5. **Correo ya utilizado:** Supabase tiene activo el ofuscado de correo, así que
   un alta repetida responde `email_address_invalid` (igual que un correo
   inválido) y no `email_exists`. La app traduce ese error a _“Ese correo no es
   válido o ya tiene una cuenta. Si ya te registraste, iniciá sesión o recuperá
   tu acceso.”_.

### 4.3 Inicio de sesión

`signInWithPassword`. Errores mapeados a mensajes claros: _“Correo o
contraseña incorrectos”_, _“Ese correo ya tiene una cuenta…”_, _“Confirmá tu
correo antes de iniciar sesión”_.

### 4.4 Recuperación de acceso

`resetPasswordForEmail(correo, { redirectTo })`. Supabase responde `200` tanto
si el correo existe como si no (no se enumeran cuentas): la app siempre
muestra _“Si el correo está registrado, te enviamos un enlace…”_. Al volver del
enlace, el evento `PASSWORD_RECOVERY` habilita el formulario de nueva
contraseña en `/acceso`.

### 4.5 Cierre de sesión

`signOut()`. Se limpia la sesión del dispositivo y el progreso en pantalla
pasa a estar vacío; la copia del historial de invitado queda guardada en la
base (con su identificador) y en el almacenamiento local de ese identificador.

### 4.6 Convertir al invitado en cuenta permanente

Se **completa la misma sesión** con `updateUser({ email, password })`:

- el `id` de Auth **no cambia** → se conservan alias, historial e identidad;
- **no se crea otra cuenta** ni se copian resultados desde el cliente;
- el perfil se marca como cuenta permanente con la función
  `marcar_cuenta_permanente()` (permiso de actualización restringido a la fila
  propia).

### 4.7 Entrar a una cuenta ya existente desde un dispositivo invitado

La cuenta existente se inicia con su correo y contraseña. El identificador de
la sesión cambia, por lo que **el historial del invitado NO se fusiona**: el
avance anterior sigue atado al identificador del invitado. La app lo avisa con
un banner: _“Entraste con una cuenta distinta a la que se usaba en este
dispositivo. Los historiales no se fusionan de forma automática.”_

### 4.8 Pérdida de historial (invitado)

Un invitado **puede perder el acceso a su historial** si:

- cierra sesión y no vuelve a entrar con el mismo identificador;
- borra los datos del navegador (se borra la copia local);
- cambia de dispositivo (la copia local no viaja).

Por eso la app recomienda convertir la cuenta, y avisa de ello tanto en
`/acceso` como en `/perfil`.

## 5. Sesión y rutas protegidas

- La sesión se persiste en el dispositivo (`persistSession: true`) y al abrir la
  app se restaura (`initAuth()` en `App.vue` + `onAuthStateChange`).
- `flowType: 'pkce'` y `detectSessionInUrl: true`: es el flujo recomendado para
  la app móvil y permite procesar los enlaces de retorno de confirmación y
  recuperación.
- **Ruta protegida**: `/perfil` (perfil, historial, conversión, cierre de
  sesión). Sin sesión, el guard de `src/router/index.js` redirige a
  `/acceso?next=/perfil` y, tras entrar, devuelve al destino original.
- El progreso se guarda por identificador
  (`doulingo-progress:<uid>`); al iniciar sesión por primera vez se adopta el
  progreso que venía del navegador de la etapa anterior para no perderlo.

## 6. Configuración del proyecto Supabase

Pasos pendientes en el panel del proyecto:

1. **Authentication → Providers → Anonymous Sign Ins → Enable**. Sin esto, el
   acceso como invitado no funciona (la app lo informa).
2. **Authentication → URL Configuration**:
   - _Site URL_: `http://localhost:9000/` (desarrollo) o el origen de la app.
   - _Redirect URLs_: `http://localhost:9000/`, `http://localhost:9100/`, la
     URL pública de la app y, para el APK, el esquema propio
     (`capacitor://localhost` o `doulingo://`).
3. **Correo**: el SMTP incluido en Supabase solo entrega a correos que sean
   miembros del equipo y tiene cupo de envíos por hora. Para pruebas reales de
   confirmación hay que agregar una dirección del equipo o configurar un SMTP
   propio.
4. Aplicar `supabase/migrations/0004_auth.sql` (o `supabase/setup.sql`).

### Enlaces de retorno dentro del APK

- El enlace de confirmación y el de recuperación abren la app (esquema propio)
  y vuelven con `?code=...`.
- En la web ese `code` lo procesa `detectSessionInUrl` del cliente de Supabase.
  En el APK el enlace entra como **deep link**
  (`doulingo://auth/callback?code=...`) y no pasa por la URL del WebView: lo
  intercepta `src/lib/deepLink.js` (evento `appUrlOpen` de
  `@capacitor/app`) y completa el intercambio PKCE con
  `exchangeCodeForSession`.
- Para que el esquema propio funcione hay que declararlo como _Redirect URL_
  en el panel, tener el `intent-filter` en el `AndroidManifest.xml` y definir
  `VITE_SUPABASE_NATIVE_REDIRECT_URL` (`doulingo://auth/callback`). Si no se
  define, dentro del APK se usa ese mismo valor por omisión; en la web se usa
  `VITE_SUPABASE_REDIRECT_URL` o, si está vacío, el origen desde el que se
  abrió la app.
- El flujo de recuperación sigue funcionando: al intercambiar el código,
  Supabase dispara el evento `PASSWORD_RECOVERY` y la app muestra el
  formulario de contraseña nueva.

El detalle completo (proyecto Android, generación del APK y pruebas) está en
[`docs/12-apk.md`](12-apk.md).

## 7. Límites de altas anónimas

Supabase limita las altas de sesión anónima (por omisión, **30 por hora y
dirección IP**). La app lo respeta:

- el invitado se crea **a pedido explícito** (botón “Continuar como invitado”),
  no en cada carga de la app;
- la sesión persistida se **reutiliza**: recargar no genera un alta nueva;
- si el alta es rechazada por el límite, el mensaje explica que hay que
  esperar.

## 8. Archivos de esta etapa

| Archivo                             | Contenido                                                                         |
| ----------------------------------- | --------------------------------------------------------------------------------- |
| `supabase/migrations/0004_auth.sql` | `perfiles`, `participant_progress`, RLS ampliada, trigger y función de conversión |
| `supabase/setup.sql`                | Script combinado de las cuatro etapas                                             |
| `src/lib/supabase.js`               | Cliente con opciones de sesión (persistencia, PKCE)                               |
| `src/data/authRepository.js`        | Operaciones de Auth, perfil y progreso (única puerta)                             |
| `src/composables/useAuth.js`        | Estado de sesión, restauración y mensajes                                         |
| `src/composables/useProgress.js`    | Progreso por identificador y sincronización con la base                           |
| `src/pages/AuthPage.vue`            | Acceso: invitado, registro, ingreso, recuperación, conversión                     |
| `src/pages/ProfilePage.vue`         | Ruta protegida: alias, historial, privacidad, acciones                            |
| `src/router/routes.js`, `index.js`  | Rutas `/acceso` y `/perfil` + guard de sesión                                     |
| `src/layouts/MainLayout.vue`        | Botón de cuenta y aviso de cambio de cuenta                                       |
| `src/lib/deepLink.js`               | Deep link del APK (`appUrlOpen`) e intercambio del código PKCE                    |

Las pruebas y sus resultados están en
[`docs/11-pruebas-auth.md`](11-pruebas-auth.md).
