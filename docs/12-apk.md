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
- `appName`: `CodeLingua`
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
./gradlew assembleRelease   # release firmado si están configuradas las variables DOULINGO_*
```

`assembleRelease` se firma desde Gradle con variables de entorno y un keystore
propio fuera del repositorio. La sección 7 incluye el procedimiento actualizado.

## 4. Requisitos para compilar

- **JDK 21** (ya está en la máquina: Temurin 21.0.12).
- **SDK de Android** con _platform-tools_, _platforms;android-36_ y
  _build-tools;36.0.0_. En esta máquina está instalado en
  `C:\Users\corre\AppData\Local\Android\Sdk`.

  ```powershell
  # Descargar y extraer en <sdk>\cmdline-tools\latest; después:
  sdkmanager.bat --sdk_root=<sdk> --licenses
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
sdk.dir=C:/Users/corre/AppData/Local/Android/Sdk
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
aapt2 dump badging src-capacitor\android\app\build\outputs\apk\debug\app-debug.apk

# El intent-filter del esquema propio dentro del APK
aapt2 dump xmltree src-capacitor\android\app\build\outputs\apk\debug\app-debug.apk --file AndroidManifest.xml

# Firma
apksigner verify --print-certs src-capacitor\android\app\build\outputs\apk\debug\app-debug.apk
```

Resultado obtenido el 12 de octubre de 2026:

- `package: name='com.doulingo.app' versionCode='1' versionName='1.0'`,
  `application-label:'CodeLingua'`, `minSdkVersion:'24'`, `targetSdkVersion:'36'`.
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

## 7. Procedimiento reproducible desde terminal (Windows)

### 7.1 Versiones y compatibilidad comprobadas

Registro del equipo de compilación al **15 de noviembre de 2026**:

| Componente                     | Versión comprobada        | Nota                                               |
| ------------------------------ | ------------------------- | -------------------------------------------------- |
| Node.js                        | 24.16.0                   | Cumple `engines` del proyecto                      |
| Quasar                         | 2.32.0                    | CLI `@quasar/app-vite` 3.8.3                       |
| Capacitor                      | 8.5.3                     | `@capacitor/android` y CLI 8.5.3; plugin App 8.1.2 |
| JDK                            | Eclipse Temurin 21.0.12+8 | Build ejecutado con Java 21                        |
| Android Gradle Plugin          | 8.13.0                    | Declarado en Gradle                                |
| Gradle Wrapper                 | 8.14.3                    | Incluido en `src-capacitor/android`                |
| Android SDK Command-line Tools | 22.0                      | Instalado en `cmdline-tools/latest`                |
| Android Platform-Tools         | 37.0.0                    | Incluye `adb`                                      |
| Android Platform               | API 36                    | `compileSdk`/`targetSdk` 36; `minSdk` 24           |
| Android Build-Tools            | 36.0.0                    | Usado para inspeccionar y verificar el APK         |

JDK 21, Gradle 8.14.3 y AGP 8.13.0 compilaron juntos correctamente. Android
Studio no es necesario. El SDK está fuera del repositorio en
`C:\Users\corre\AppData\Local\Android\Sdk`; adaptar esa ruta en otra máquina.

Para una instalación nueva, descargar Command-line Tools desde
[Android Developers](https://developer.android.com/studio#command-line-tools-only)
y extraerlas como `<SDK>\cmdline-tools\latest`. Luego, en PowerShell:

```powershell
$env:JAVA_HOME = 'C:\ruta\al\jdk-21'
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:Path = "$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:ANDROID_HOME\cmdline-tools\latest\bin;$env:Path"

sdkmanager --licenses
sdkmanager --install "platform-tools" "platforms;android-36" "build-tools;36.0.0"
```

En este equipo las licencias quedaron aceptadas y platform-tools, API 36 y
build-tools 36.0.0 ya estaban instalados; se añadió Command-line Tools 22.0.
El archivo `src-capacitor/android/local.properties`, ignorado por Git, apunta
al SDK de esta computadora y usa barras `/`.

### 7.2 Generar APK debug (sin Android Studio)

Desde la raíz, en Windows/PowerShell:

```powershell
$env:JAVA_HOME = 'C:\Program Files\Eclipse Adoptium\jdk-21.0.12.8-hotspot'
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME

# Compila la SPA para Capacitor y sincroniza los archivos con Android.
npx quasar build -m capacitor -T android --skip-pkg

# Compila el APK usando el Gradle Wrapper incluido (no Gradle global).
cd src-capacitor\android
.\gradlew.bat assembleDebug --no-daemon
```

En Linux/macOS, con JDK 21 y `ANDROID_HOME` / `ANDROID_SDK_ROOT` definidos:

```bash
npx quasar build -m capacitor -T android --skip-pkg
cd src-capacitor/android
./gradlew assembleDebug
```

En ambos casos el APK queda en
`src-capacitor/android/app/build/outputs/apk/debug/app-debug.apk`. Los recursos
web se copian a `app/src/main/assets/public/`; el archivo Capacitor empacado no
declara URL de servidor de desarrollo. El APK sirve esos archivos localmente y
no depende de la computadora que lo compiló. `https://localhost` es el origen
local del WebView, no un servidor remoto.

### 7.3 Firma release desde terminal

La clave release es distinta de la clave debug. Generarla una sola vez en una
carpeta protegida **fuera del repositorio**, respaldarla de forma segura y no
perderla: futuras actualizaciones requieren la misma clave. En PowerShell:

```powershell
$key = "$env:USERPROFILE\.android\doulingo-release.jks"
New-Item -ItemType Directory -Force (Split-Path $key) | Out-Null
keytool -genkeypair -v -keystore $key -alias doulingo -keyalg RSA -keysize 4096 -validity 10000
$env:DOULINGO_KEYSTORE_FILE = $key
$env:DOULINGO_KEY_ALIAS = 'doulingo'
$env:DOULINGO_KEYSTORE_PASSWORD = Read-Host 'Contraseña del keystore' -AsSecureString | ConvertFrom-SecureString -AsPlainText
$env:DOULINGO_KEY_PASSWORD = Read-Host 'Contraseña de la clave' -AsSecureString | ConvertFrom-SecureString -AsPlainText
```

Las contraseñas quedan solo en las variables de la terminal actual. No ponerlas
en `.env`, `local.properties`, scripts ni Git. Para Linux/macOS se exportan las
mismas cuatro variables en una terminal protegida. Después:

```powershell
cd src-capacitor\android
.\gradlew.bat assembleRelease
```

```bash
cd src-capacitor/android
./gradlew assembleRelease
```

El archivo firmado queda en `app/build/outputs/apk/release/app-release.apk`.
Gradle falla si se intenta generar release sin las cuatro variables
`DOULINGO_KEYSTORE_FILE`, `DOULINGO_KEYSTORE_PASSWORD`, `DOULINGO_KEY_ALIAS` y
`DOULINGO_KEY_PASSWORD`. Los patrones `*.jks`, `*.keystore` y
`signing.properties` están ignorados por Git.

### 7.4 Registro de esta ejecución

El **15 de noviembre de 2026** se ejecutó la compilación desde terminal:

- Quasar generó los recursos Capacitor y `cap sync android` terminó correctamente.
- `gradlew.bat assembleDebug --no-daemon`: **BUILD SUCCESSFUL**.
- APK debug: `src-capacitor/android/app/build/outputs/apk/debug/app-debug.apk`.
- AAPT confirmó `com.doulingo.app`, `CodeLingua`, `versionCode=1`,
  `versionName=1.0`, `minSdk=24`, `targetSdk=36`.
- `apksigner verify --print-certs`: válido, certificado **Android Debug**.
- Icono adaptativo y heredado: mascota Usagi en el verde de la marca.
- La SPA quedó dentro de `assets/public` y el config empacado no tiene
  `server.url` de desarrollo.
- Se eliminó el warning de import dinámico del build web. Gradle conserva el
  warning no fatal `Using flatDir...` del wiring de Capacitor/Cordova.
- No había teléfonos físicos conectados por ADB. Las pruebas de flujo real en
  dos celulares quedan pendientes de hacer en la expo; ver el checklist de
  `docs/16-manuales-y-cierre.md`.

### 7.5 Registro de la ejecución del 17 de noviembre de 2026

- `gradlew.bat assembleDebug --no-daemon`: **BUILD SUCCESSFUL**
  (`app-debug.apk`, 6,3 MB).
- Clave release generada con `keytool` (RSA 4096, alias `doulingo`) en
  `%USERPROFILE%\.android\`, fuera del repositorio; las variables
  `DOULINGO_*` se cargaron en la terminal desde un archivo local.
- `gradlew.bat assembleRelease`: **BUILD SUCCESSFUL**
  (`app-release.apk`, 4,5 MB). `apksigner verify --print-certs` válido
  (`CN=CodeLingua`, SHA-256 `4fa56639…d171f0`); `aapt2`: `com.doulingo.app`,
  versionCode 1, versionName 1.0, minSdk 24, targetSdk 36.
- `assets/public/index.html` y `capacitor.config.json` (sin `server.url`)
  confirmados dentro del APK.
- `adb devices`: sin dispositivos. Pendiente la instalación en celulares reales.
