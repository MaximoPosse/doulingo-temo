// Cliente centralizado de Supabase.
//
// Las credenciales provienen de variables de entorno Vite (archivo .env):
//   VITE_SUPABASE_URL
//   VITE_SUPABASE_PUBLISHABLE_KEY   (clave nueva: sb_publishable_...)
//     └─ o, en proyectos antiguos, VITE_SUPABASE_ANON_KEY
//
// Ambas claves son PÚBLICAS por diseño (solo lectura de contenido publicado +
// llamada a la RPC check_answer). La claves secretas (service_role /
// sb_secret_...) y las contraseñas NUNCA deben usarse en el frontend.

import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL ?? ''
const publicKey =
  import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY ??
  import.meta.env.VITE_SUPABASE_ANON_KEY ??
  ''

// Se considera configurado cuando hay URL y key reales (no placeholders).
const IS_CONFIGURED =
  url.trim() !== '' &&
  publicKey.trim() !== '' &&
  !/REEMPLAZA/i.test(url) &&
  !/REEMPLAZA/i.test(publicKey)

let client = null

export function isSupabaseConfigured() {
  return IS_CONFIGURED
}

export function supabaseNotConfiguredError() {
  return new Error(
    'La aplicación no está conectada a la base de datos todavía. ' +
      'Configurá VITE_SUPABASE_URL y VITE_SUPABASE_PUBLISHABLE_KEY en el ' +
      'archivo .env con los datos de tu proyecto Supabase.'
  )
}

export function getSupabaseClient() {
  if (!IS_CONFIGURED) {
    throw supabaseNotConfiguredError()
  }
  if (!client) {
    client = createClient(url, publicKey)
  }
  return client
}
