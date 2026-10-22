// Verificación puntual: ¿están habilitados los invitados anónimos?
import { SUPABASE_KEY, SUPABASE_URL } from './helpers.mjs'

const response = await fetch(`${SUPABASE_URL}/auth/v1/signup`, {
  method: 'POST',
  headers: { apikey: SUPABASE_KEY, 'content-type': 'application/json' },
  body: '{}'
})
const text = await response.text()
let body
try {
  body = JSON.parse(text)
} catch {
  body = text
}
console.log('HTTP', response.status)
console.log('respuesta:', JSON.stringify(body).slice(0, 400))
if (response.status === 200) {
  const user = body.user ?? body
  console.log('id:', user.id)
  console.log('is_anonymous:', user.is_anonymous)
  console.log('rol:', user.role)
  console.log(
    'session:',
    body.access_token ? 'emitida' : 'sin sesión (solo usuario)'
  )
}
