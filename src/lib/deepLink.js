// Enlaces profundos (deep links) del APK.
//
// Dentro del APK los enlaces de Supabase Auth (confirmación de correo y
// recuperación de contraseña) abren la app con el esquema propio:
//   doulingo://auth/callback?code=...
// Ese query no lo ve el WebView, así que se intercepta el evento
// 'appUrlOpen' del plugin @capacitor/app y se completa el intercambio PKCE
// a mano.
//
// En la web no hay nada que hacer: el mismo enlace llega en la URL de la
// página y lo resuelve detectSessionInUrl del cliente de Supabase.

import { Capacitor } from '@capacitor/core'

// ¿La app está corriendo dentro del APK (Capacitor) y no en un navegador?
export function isNativeApp() {
  return Capacitor.isNativePlatform()
}

// Saca el código de autorización del enlace (viene en el query o, en los
// flujos con hash, dentro del fragmento).
export function extractAuthCode(url) {
  if (!url) return null
  try {
    const parsed = new URL(url)
    const fromQuery = parsed.searchParams.get('code')
    if (fromQuery) return fromQuery
    const hash = parsed.hash ?? ''
    const params = new URLSearchParams(
      hash.startsWith('#') ? hash.slice(1) : hash
    )
    return params.get('code')
  } catch {
    return null
  }
}

// Registra el escucha del deep link y llama a onCode con el código de
// autorización cuando la app se abre con el enlace. Devuelve una función
// para dar de baja el listener (o null si la app no es nativa).
export async function registerDeepLinkHandler(onCode) {
  if (!isNativeApp()) return null

  const { App } = await import('@capacitor/app')
  const listener = await App.addListener('appUrlOpen', async ({ url }) => {
    const code = extractAuthCode(url)
    if (code) await onCode(code)
  })

  return () => listener.remove()
}
