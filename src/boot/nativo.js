// Ajustes que solo hacen falta dentro del APK (Capacitor).
//
// Botón "atrás" del celular: vuelve a la pantalla anterior de la app; desde el
// inicio (o desde el acceso, sin pantalla anterior) cierra la app en lugar de
// quedarse sin hacer nada o saltar a una pantalla vacía.

import { App } from '@capacitor/app'

import { isNativeApp } from '@/lib/deepLink'

export default ({ router }) => {
  if (!isNativeApp()) return

  App.addListener('backButton', () => {
    const ruta = router.currentRoute.value
    const anterior = router.options.history.state?.back ?? null
    if (ruta.name === 'inicio' || (ruta.name === 'acceso' && !anterior)) {
      App.exitApp()
    } else if (anterior) {
      router.back()
    } else {
      router.replace({ name: 'inicio' })
    }
  })
}
