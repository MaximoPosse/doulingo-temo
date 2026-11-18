// Alertas (notificaciones emergentes) de la app.
//
// Se muestran arriba de la pantalla cada vez que pasa algo importante con la
// sesión: se entró como invitado, se creó la cuenta, se inició o cerró sesión,
// se cambió el alias o la contraseña, o falló algo. Se suman a los avisos
// que cada pantalla muestra dentro de su contenido.

import { Notify } from 'quasar'

const TIPOS = {
  ok: { icon: 'check_circle', color: 'primary', textColor: 'dark' },
  error: { icon: 'error', color: 'negative', textColor: 'white' },
  aviso: { icon: 'info', color: 'warning', textColor: 'dark' }
}

export function alerta(tipo, mensaje) {
  if (!mensaje) return
  const estilo = TIPOS[tipo] ?? TIPOS.aviso
  Notify.create({
    message: mensaje,
    icon: estilo.icon,
    color: estilo.color,
    textColor: estilo.textColor,
    position: 'top',
    timeout: 4500,
    multiLine: true,
    actions: [
      { icon: 'close', color: estilo.textColor, round: true, dense: true }
    ]
  })
}
