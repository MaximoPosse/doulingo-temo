const { defineCapacitorConfig } = require('@quasar/app-vite/capacitor');

module.exports = defineCapacitorConfig({
  appId: 'com.doulingo.app',
  appName: 'CodeLingua',
  // Fondo negro desde el arranque (evita el destello blanco al abrir la app).
  backgroundColor: '#000000',
  server: {
    // El WebView nativo sirve la app en https://localhost (origen seguro),
    // necesario para que Supabase Auth (PKCE) funcione dentro del APK.
    androidScheme: 'https'
  }
});
