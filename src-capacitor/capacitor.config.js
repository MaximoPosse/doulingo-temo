const { defineCapacitorConfig } = require('@quasar/app-vite/capacitor');

module.exports = defineCapacitorConfig({
  appId: 'com.doulingo.app',
  appName: 'Doulingo',
  server: {
    // El WebView nativo sirve la app en https://localhost (origen seguro),
    // necesario para que Supabase Auth (PKCE) funcione dentro del APK.
    androidScheme: 'https'
  }
});
