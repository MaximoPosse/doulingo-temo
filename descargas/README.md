# Descargas

`CodeLingua.apk` es la versión **release firmada** de la app para Android
(`com.doulingo.app`, versión 1.6, versionCode 7). El código QR de `docs/qr/` apunta a:

https://github.com/MaximoPosse/doulingo-temo/raw/master/descargas/CodeLingua.apk

Para actualizar el APK: recompilar con `gradlew assembleRelease`, copiar
`app-release.apk` aquí con el nombre `CodeLingua.apk` y hacer commit. El QR no
cambia mientras el enlace sea el mismo. La clave de firma no se versiona.

## Instalar en el celular

1. Escanear el código QR (`docs/qr/`): descarga `CodeLingua.apk`.
2. Abrir el archivo descargado. Si Android lo pide, permitir **instalar apps
   desde esta fuente** (una sola vez) y tocar **Instalar**.
3. Si ya estaba instalada una versión anterior, esta la **actualiza** sin perder
   la sesión (misma firma). La versión 1.6 incluye el tema oscuro, las 3 vidas,
   el minijuego Cazabugs (una sola ronda con puntos; los bichos que se escapan restan) y está probada en un Android 16 (emulador): barras del sistema, botón atrás, teclado y juego táctil.
