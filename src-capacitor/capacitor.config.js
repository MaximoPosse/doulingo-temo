const { defineCapacitorConfig } = require('@quasar/app-vite/capacitor');

module.exports = defineCapacitorConfig({
  appId: 'com.doulingo.app',
  appName: 'CodeLingua',
  // Fondo negro desde el arranque (evita el destello blanco al abrir la app).
  backgroundColor: '#000000',
  plugins: {
    // Barras del sistema (hora, batería y botones de navegación) con iconos
    // claros sobre el fondo negro; la app se dibuja hasta los bordes y usa los
    // márgenes seguros (safe-area) para no quedar debajo de ellas.
    SystemBars: {
      style: 'DARK',
      insetsHandling: 'css',
      initialViewportFitValueHint: 'cover'
    }
  },
  android: {
    // La app publicada no se puede inspeccionar con las herramientas de depuración.
    webContentsDebuggingEnabled: false
  },
  server: {
    // El WebView nativo sirve la app en https://localhost (origen seguro),
    // necesario para que Supabase Auth (PKCE) funcione dentro del APK.
    androidScheme: 'https'
  }
});
