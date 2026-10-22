# 12. El APK (Android) y el esquema de URL propio

La app es una SPA de Quasar que además se puede empaquetar como aplicación
Android con **Capacitor**. Esta nota explica:

1. cómo quedó configurado el proyecto nativo;
2. cómo se declara el **esquema de URL** (`doulingo://`) para que los enlaces
   de Supabase Auth abran la app;
3. cómo se genera el `.apk`;
4. qué falta verificar en el panel de Supabase.

## 1. Qué hay en el repositorio

| Ruta                                | Contenido                                              |
| ----------------------------------- | ------------------------------------------------------ |
| `src-capacitor/capacitor.config.js` | Identidad de la app y esquema del WebView nativo       |
| `src-capacitor/package.json`        | Dependencias nativas (`@capacitor/core`, `cli`, `app`) |
| `src-capacitor/android/`            | Proyecto Android (Activity, Manifest, Gradle)          |
| `src/lib/deepLink.js`               | Lectura del deep link e intercambio del código PKCE    |

`src-capacitor/www` y `src-capacitor/node_modules` no se versionan (están en
`.gitignore`): se regeneran con los comandos de esta nota.

Datos de la app nativa:

- `appId`: `com.doulingo.app`
- `appName`: `Doulingo`
- `server.androidScheme`: `https` → dentro del APK el WebView sirve la app en
  `https://localhost` (origen seguro, necesario para Supabase Auth con PKCE).

## 2. El esquema de URL propio

El esquema es el prefijo que hace que Android abra **esta** app al tocar un
enlace. En este proyecto es `doulingo://auth/callback`.

### 2.1 En Android (intent-filter)

`src-capacitor/android/app/src/main/AndroidManifest.xml`, dentro de
`<activity>`:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="doulingo" android:host="auth" android:pathPrefix="/callback" />
</intent-filter>
```

### 2.2 En la app (variable de entorno)

`.env` (local, no se versiona):

```
VITE_SUPABASE_NATIVE_REDIRECT_URL=doulingo://auth/callback
```

`src/data/authRepository.js` la usa en `authRedirectUrl()` **solo cuando la
app corre dentro del APK**; en la web se usa `VITE_SUPABASE_REDIRECT_URL` o el
origen desde el que se abrió la app. Así, la misma clave de variables sirve
para las dos versiones.

### 2.3 En Supabase (Redirect URLs)

**Authentication → URL Configuration → Redirect URLs** tiene que incluir:

```
doulingo://auth/callback
http://localhost:9000/
http://localhost:9100/
```

El _Site URL_ puede quedar en `http://localhost:9000/` (es el destino por
omisión cuando la app no envía un `redirectTo`).

### 2.4 Qué pasa cuando el usuario toca el enlace

1. Supabase redirige a `doulingo://auth/callback?code=...`.
2. Android abre la app (por el `intent-filter`) y el plugin `@capacitor/app`
   dispara el evento `appUrlOpen` con esa URL.
3. `src/lib/deepLink.js` extrae el código y llama a
   `completeDeepLink()` (en `src/composables/useAuth.js`).
4. `exchangeCodeForSession()` canjea el código por la sesión; si el enlace era
   de recuperación, Supabase dispara `PASSWORD_RECOVERY` y la app muestra el
   formulario de contraseña nueva.

En la web el mismo enlace llega en la URL de la página y lo resuelve
`detectSessionInUrl`: no interviene el deep link.

## 3. Comandos

```bash
# Desarrollo web (no toca el APK)
npm run dev

# Build nativo: arma la web en src-capacitor/www, sincroniza el proyecto
# Android y compila el APK (necesita ANDROID_HOME y JDK 21)
npx quasar build -m capacitor -T android

# Igual, pero con la variante de depuración (APK firmado con la clave de debug,
# instalable sin configurar firma): deja el archivo en
# src-capacitor/android/app/build/outputs/apk/debug/app-debug.apk
npx quasar build -m capacitor -T android --debug

# Copia la web al proyecto Android y actualiza los plugins
npx cap sync android        # (desde la carpeta src-capacitor)

# Abrir el proyecto en Android Studio
npx cap open android

# Builds puntuales desde Gradle
cd src-capacitor/android
./gradlew assembleDebug     # APK firmado (instalable): app/build/outputs/apk/debug/app-debug.apk
./gradlew assembleRelease   # APK SIN firmar: app/build/outputs/apk/release/app-release-unsigned.apk
```

Un APK firmado para distribuirlo se genera desde Android Studio:
**Build → Build Bundle(s)/APK(s) → Generate Signed Bundle / APK**. Con
Gradle, `assembleRelease` queda **sin firmar** porque el `build.gradle` del
proyecto no define un `signingConfig` de release: el que sale firmado (con el
keystore de debug) es `assembleDebug`, y es el que sirve para instalar en un
dispositivo o emulador.

## 4. Requisitos para compilar

- **JDK 21** (ya está en la máquina: Temurin 21.0.12).
- **SDK de Android** con _platform-tools_, _platforms;android-36_ y
  _build-tools;36.0.0_. En esta máquina quedó instalado en
  `C:\Users\corre\AppData\Local\Temp\opencode\android-sdk` con los
  _command-line tools_ de Google:

  ```powershell
  # 1. Descargar y descomprimir los command-line tools en <sdk>\cmdline-tools\latest
  # 2. Aceptar las licencias (responder "y" a todas)
  cmd /c "sdkmanager.bat --sdk_root=<sdk> --licenses < yes.txt"
  # 3. Instalar los paquetes
  sdkmanager.bat --sdk_root=<sdk> --install "platform-tools" "platforms;android-36" "build-tools;36.0.0"
  ```

- Definir `ANDROID_HOME` y `ANDROID_SDK_ROOT` con la ruta del SDK antes de
  compilar.
- Android Studio, para la firma y el emulador (opcional: se puede compilar solo
  con el SDK y Gradle).

### Emulador sin Android Studio

Con los _command-line tools_ del SDK alcanza para probar el APK:

```powershell
# 1. Instalar el emulador y una imagen del sistema
sdkmanager.bat --sdk_root=<sdk> --install "emulator" "system-images;android-36;google_apis;x86_64"

# 2. Crear el dispositivo virtual (Pixel 6)
avdmanager.bat create avd -n doulingo -k "system-images;android-36;google_apis;x86_64" -d pixel_6

# 3. Arrancarlo (sin ventana) y esperar a que termine de bootear
emulator.exe -avd doulingo -no-window -no-audio -no-boot-anim -gpu swiftshader_indirect
adb wait-for-device
adb shell getprop sys.boot_completed   # 1 = listo

# 4. Instalar y abrir la app
adb install -r src-capacitor/android/app/build/outputs/apk/debug/app-debug.apk
adb shell am start -n com.doulingo.app/.MainActivity
```

El emulador necesita virtualización (WHPX en Windows). Para inspeccionar la
página del WebView: `adb shell pidof com.doulingo.app`, luego
`adb forward tcp:9222 localabstract:webview_devtools_remote_<pid>` y abrir
`http://localhost:9222/json` (se puede automatizar con el protocolo DevTools
por WebSocket, sin instalar nada más).

### Ojo con `local.properties`

El archivo `src-capacitor/android/local.properties` le dice a Gradle dónde está
el SDK:

```properties
sdk.dir=C:/Users/corre/AppData/Local/Temp/opencode/android-sdk
```

Tiene que llevar **barras normales**: en un archivo `.properties` la barra
invertida es un carácter de escape, así que `sdk.dir=C:\Users\...` se interpreta
mal y el build falla con:

```
Could not determine the dependencies of task ':capacitor-app:compileReleaseJavaWithJavac'.
> java.io.IOException: El nombre de archivo, el nombre de directorio o la sintaxis de la etiqueta del volumen no son correctos
```

El archivo está en el `.gitignore` del proyecto Android: cada máquina define el
suyo.

## 5. Verificación del APK generado

```powershell
# Paquete, versión y actividad principal
aapt2 dump badging dist\doulingo-0.0.1-debug.apk

# El intent-filter del esquema propio dentro del APK
aapt2 dump xmltree --file AndroidManifest.xml dist\doulingo-0.0.1-debug.apk

# Firma
apksigner verify --print-certs dist\doulingo-0.0.1-debug.apk
```

Resultado obtenido el 12 de octubre de 2026:

- `package: name='com.doulingo.app' versionCode='1' versionName='1.0'`,
  `application-label:'Doulingo'`, `minSdkVersion:'24'`, `targetSdkVersion:'36'`.
- `scheme="doulingo"`, `host="auth"`, `pathPrefix="/callback"` presentes en el
  manifiesto empaquetado.
- Firmado con el certificado “Android Debug” (instalable en cualquier
  dispositivo con depuración activada).
- Tamaño: 4,7 MB.

### 5.1 Verificación en un emulador (22 de octubre de 2026)

Probado en el AVD `doulingo` (Pixel 6, x86_64, Android 16 / SDK 36) con el APK
de depuración. El sistema resuelve el esquema con
`cmd package resolve-activity` → `com.doulingo.app/.MainActivity`. Dentro del
WebView la app se sirve en `https://localhost/#/` (origen seguro para PKCE).

| Verificación                    | Resultado                                                                       |
| ------------------------------- | ------------------------------------------------------------------------------- |
| Deep link con la app abierta    | `appUrlOpen` llega con `doulingo://auth/callback?...` y se procesa              |
| Deep link en arranque en frío   | la app arranca con el enlace y la sesión guardada se restaura antes de escuchar |
| Enlace falso (código inválido)  | aviso en español: “El enlace de acceso no sirve o ya venció…”                   |
| Mismo enlace repetido           | se ignora el duplicado (una sola lectura del `code-verifier`)                   |
| Alta como invitado desde el APK | sesión anónima creada y perfil visible (`invitado#2abd`)                        |
| Persistencia                    | tras `force-stop` y reabrir, la sesión sigue activa                             |

## 6. Pruebas del deep link

Con la app instalada en el dispositivo o emulador:

```bash
adb shell am start -a android.intent.action.VIEW -d "doulingo://auth/callback?code=prueba"
```

La app debe abrirse; con un código falso se informa “El enlace de acceso no
sirve o ya venció” (lo esperado: el código real lo genera Supabase y, además,
el cliente PKCE solo acepta el código si el pedido se hizo en el mismo
dispositivo).

Android puede notificar el mismo enlace más de una vez (por ejemplo al arrancar
en frío). `completeDeepLink()` ignora el mismo código repetido dentro de 10
segundos, para que un enlace de un solo uso no se intente canjear dos veces y
termine mostrando un error sobre una sesión ya iniciada.
