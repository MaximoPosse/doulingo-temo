// Genera los diagramas SVG de CodeLingua con el mismo estilo que ColegioGest.
import fs from 'node:fs'
import path from 'node:path'

const OUT = process.argv[2]
fs.mkdirSync(OUT, { recursive: true })

const esc = s =>
  String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
const svgWrap = (w, h, body) =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" font-family="Arial, Helvetica, sans-serif">
<rect width="${w}" height="${h}" fill="#ffffff"/>
<defs><marker id="ah" markerUnits="userSpaceOnUse" markerWidth="16" markerHeight="16" refX="13" refY="8" orient="auto"><path d="M0,0 L16,8 L0,16 z" fill="#1f4e79"/></marker></defs>
${body}</svg>`
const save = (name, w, h, body) =>
  fs.writeFileSync(path.join(OUT, name + '.svg'), svgWrap(w, h, body))

/* ---------- bloques estilo ColegioGest ---------- */
const box = (x, y, w, h, title, sub, fill = '#cfe2f7', stroke = '#2b3a55') =>
  `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${fill}" stroke="${stroke}" stroke-width="2"/>
<text x="${x + w / 2}" y="${y + (sub ? h / 2 - 4 : h / 2 + 6)}" text-anchor="middle" font-size="19" font-weight="bold" fill="#000">${esc(title)}</text>` +
  (sub
    ? sub
        .split('\n')
        .map(
          (s, i) =>
            `<text x="${x + w / 2}" y="${y + h / 2 + 17 + i * 17}" text-anchor="middle" font-size="14" fill="#222">${esc(s)}</text>`
        )
        .join('')
    : '')
const zone = (x, y, w, h, title, color, fill) =>
  `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="10" fill="${fill}" stroke="${color}" stroke-width="3" stroke-dasharray="7,5"/>
<text x="${x + 20}" y="${y + 34}" font-size="23" font-weight="bold" fill="${color}">${esc(title)}</text>`
const line = (x1, y1, x2, y2, arrow = false, w = 5) =>
  `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="#1f4e79" stroke-width="${w}" ${arrow ? 'marker-end="url(#ah)"' : ''}/>`
const label = (
  x,
  y,
  t,
  bold = false,
  size = 15,
  color = '#6b5b53',
  anchor = 'start'
) =>
  `<text x="${x}" y="${y}" font-size="${size}" ${bold ? 'font-weight="bold"' : ''} fill="${bold ? '#1f4e79' : color}" text-anchor="${anchor}">${esc(t)}</text>`

/* ---------- 1. Roles (organigrama) ---------- */
{
  const b = []
  b.push(`<rect x="470" y="30" width="360" height="150" fill="#5b8bcb"/>`)
  b.push(
    `<text x="650" y="78" text-anchor="middle" font-size="30" fill="#fff">Administrador</text>`
  )
  b.push(
    `<rect x="525" y="120" width="250" height="50" fill="#fff" stroke="#3f6fb5" stroke-width="4"/><text x="650" y="153" text-anchor="middle" font-size="22">Contenido y eventos</text>`
  )
  b.push(line(650, 190, 650, 270, false, 6))
  b.push(line(215, 270, 1085, 270, false, 6))
  b.push(line(215, 270, 215, 330, false, 6))
  b.push(line(650, 270, 650, 330, false, 6))
  b.push(line(1085, 270, 1085, 330, false, 6))
  const kids = [
    [60, '#3f6fb5', 'Participante', 'Cuenta con correo'],
    [495, '#6c97d2', 'Invitado', 'Sesión anónima'],
    [930, '#9db6dd', 'Visitante', 'Solo lectura']
  ]
  for (const [x, c, t, s] of kids) {
    b.push(`<rect x="${x}" y="330" width="310" height="150" fill="${c}"/>`)
    b.push(
      `<text x="${x + 155}" y="378" text-anchor="middle" font-size="28" fill="#fff">${t}</text>`
    )
    b.push(
      `<rect x="${x + 30}" y="422" width="250" height="50" fill="#fff" stroke="#3f6fb5" stroke-width="4"/><text x="${x + 155}" y="455" text-anchor="middle" font-size="21">${s}</text>`
    )
  }
  save('01-roles', 1300, 520, b.join(''))
}

/* ---------- 2. Arquitectura ---------- */
{
  const b = []
  b.push(
    zone(
      10,
      10,
      930,
      790,
      'Celular · APK Android (Capacitor) y navegador',
      '#2e5aa0',
      '#f3f7fc'
    )
  )
  b.push(
    box(
      40,
      60,
      400,
      120,
      'Quasar · Vue 3 + Vite',
      'SPA empaquetada (WebView https://localhost)\nrouter · layouts · pages'
    )
  )
  b.push(
    box(
      480,
      60,
      430,
      120,
      'Components',
      'CourseCard · UnitCard · LessonCard\nAppHeader · estados de carga y error'
    )
  )
  b.push(line(440, 120, 480, 120, false, 5))
  b.push(
    box(
      40,
      260,
      400,
      130,
      'Composables',
      'useAuth (sesión, alias)\nuseProgress · useRemoteData'
    )
  )
  b.push(
    box(
      480,
      260,
      430,
      130,
      'Repositories (src/data)',
      'course · auth · attempt\nchallenge · publicRanking'
    )
  )
  b.push(line(440, 325, 480, 325, false, 5))
  b.push(line(240, 180, 240, 260, false, 5))
  b.push(label(256, 226, 'usa'))
  b.push(line(695, 180, 695, 260, false, 5))
  b.push(label(711, 226, 'llama'))
  b.push(
    box(
      40,
      480,
      400,
      120,
      'lib/supabase.js',
      'cliente único · URL y publishable key\nde variables VITE_*',
      '#e6edf6'
    )
  )
  b.push(
    box(
      480,
      480,
      430,
      120,
      'lib/deepLink.js',
      '@capacitor/app · appUrlOpen\ndoulingo://auth/callback',
      '#e6edf6'
    )
  )
  b.push(line(695, 390, 695, 480, false, 5))
  b.push(line(240, 390, 240, 480, false, 5))
  b.push(
    box(
      40,
      650,
      870,
      100,
      'Android nativo',
      'MainActivity · intent-filter del esquema doulingo:// · assets/public',
      '#e6edf6'
    )
  )
  b.push(line(695, 600, 695, 650, false, 5))
  b.push(zone(1070, 10, 520, 790, 'Supabase', '#2e7d32', '#f0f8f1'))
  b.push(
    box(
      1100,
      60,
      460,
      120,
      'Auth',
      'invitado (anónimo) · correo y contraseña\nsesión JWT · recuperación',
      '#cde6d3'
    )
  )
  b.push(
    box(
      1100,
      220,
      460,
      370,
      'PostgreSQL',
      '\n20 tablas con PK/FK y CHECK\nRLS por rol: anon · authenticated · admin\nRPC SECURITY DEFINER: check_answer,\niniciar_intento, iniciar_partida,\nresponder_partida, finalizar_partida\nTriggers: publicar_resultado,\nvalidar_contenido_admin',
      '#cde6d3'
    )
  )
  b.push(
    box(
      1100,
      630,
      460,
      120,
      'Realtime',
      'tabla resultados_publicos\nactualiza la pantalla de ranking',
      '#cde6d3'
    )
  )
  b.push(line(910, 400, 1090, 400, true, 7))
  b.push(label(1000, 430, 'HTTPS', true, 17, '#000', 'middle'))
  b.push(label(1000, 452, 'clave anon', true, 14, '#000', 'middle'))
  b.push(label(1000, 472, '+ JWT', true, 14, '#000', 'middle'))
  save('02-arquitectura', 1600, 810, b.join(''))
}

/* ---------- 3. Pipeline APK ---------- */
{
  const b = []
  const steps = [
    ['Node 24 + Quasar', 'npm install\n.env con Supabase'],
    ['quasar build', '-m capacitor\n-T android --skip-pkg'],
    ['src-capacitor/www', 'recursos web\ncompilados'],
    ['cap sync android', 'copia a assets/public\nplugins nativos'],
    ['gradlew', 'assembleDebug\nassembleRelease'],
    ['APK', 'app-debug.apk\napp-release.apk']
  ]
  steps.forEach(([t, s], i) => {
    const x = 20 + i * 270
    const fill = i === 5 ? '#cde6d3' : i === 4 ? '#cfe2f7' : '#e6edf6'
    b.push(box(x, 70, 220, 110, t, s, fill))
    if (i < steps.length - 1) b.push(line(x + 220, 125, x + 270, 125, true, 5))
  })
  b.push(
    zone(
      10,
      230,
      1640,
      190,
      'Entorno de compilación (sin Android Studio)',
      '#2e5aa0',
      '#f3f7fc'
    )
  )
  b.push(
    box(
      40,
      285,
      370,
      100,
      'JDK 21 · JAVA_HOME',
      'Eclipse Temurin 21.0.12',
      '#e6edf6'
    )
  )
  b.push(
    box(
      450,
      285,
      370,
      100,
      'Android SDK · ANDROID_HOME',
      'platform-tools · API 36 · build-tools 36.0.0',
      '#e6edf6'
    )
  )
  b.push(
    box(
      860,
      285,
      370,
      100,
      'Gradle Wrapper 8.14.3',
      'AGP 8.13.0 · incluido en el proyecto',
      '#e6edf6'
    )
  )
  b.push(
    box(
      1270,
      285,
      350,
      100,
      'Firma release',
      'keystore fuera de Git · DOULINGO_*',
      '#fdecc8'
    )
  )
  b.push(label(20, 40, 'Del código fuente al APK instalable', true, 22))
  b.push(
    box(
      20,
      470,
      780,
      110,
      'Debug (ensayos)',
      'firmado con la clave Android Debug\nadb install -r app-debug.apk',
      '#cfe2f7'
    )
  )
  b.push(
    box(
      850,
      470,
      780,
      110,
      'Release (entrega pública)',
      'firmado con clave propia (apksigner verify)\napp/build/outputs/apk/release/app-release.apk',
      '#cde6d3'
    )
  )
  save('03-pipeline-apk', 1670, 620, b.join(''))
}

/* ---------- 4. Flujo de partida y ranking ---------- */
{
  const b = []
  b.push(
    zone(10, 10, 560, 560, 'Celulares participantes', '#2e5aa0', '#f3f7fc')
  )
  b.push(box(40, 60, 240, 100, 'Celular A', 'invitado', '#cfe2f7'))
  b.push(box(300, 60, 240, 100, 'Celular B', 'cuenta registrada', '#cfe2f7'))
  b.push(
    box(
      40,
      230,
      500,
      90,
      '1 · iniciar_partida',
      'el servidor fija preguntas, reglas y reloj',
      '#e6edf6'
    )
  )
  b.push(
    box(
      40,
      350,
      500,
      90,
      '2 · responder_partida',
      'una respuesta por pregunta · puntos del servidor',
      '#e6edf6'
    )
  )
  b.push(
    box(
      40,
      470,
      500,
      80,
      '3 · finalizar_partida',
      'estado finalizada / incompleta / vencida',
      '#e6edf6'
    )
  )
  b.push(line(160, 160, 160, 230, true, 4))
  b.push(line(420, 160, 420, 230, true, 4))
  b.push(line(290, 320, 290, 350, true, 4))
  b.push(line(290, 440, 290, 470, true, 4))
  b.push(zone(690, 10, 560, 560, 'Supabase', '#2e7d32', '#f0f8f1'))
  b.push(
    box(
      720,
      60,
      500,
      90,
      'partidas · partida_respuestas',
      'RLS: cada participante lee solo lo suyo',
      '#cde6d3'
    )
  )
  b.push(
    box(
      720,
      190,
      500,
      90,
      'trigger publicar_resultado',
      'solo mejor intento válido (finalizada)',
      '#cde6d3'
    )
  )
  b.push(
    box(
      720,
      320,
      500,
      90,
      'resultados_publicos',
      'alias · puntos · duración (sin datos privados)',
      '#cde6d3'
    )
  )
  b.push(
    box(
      720,
      450,
      500,
      90,
      'Realtime + ranking_evento()',
      'evento INSERT/UPDATE · respaldo cada 30 s',
      '#cde6d3'
    )
  )
  b.push(line(985, 150, 985, 190, true, 4))
  b.push(line(985, 280, 985, 320, true, 4))
  b.push(line(985, 410, 985, 450, true, 4))
  b.push(line(540, 275, 710, 105, true, 6))
  b.push(label(630, 215, 'RPC', true, 16, '#000', 'middle'))
  b.push(zone(1370, 10, 420, 560, 'Pantalla de expo', '#8a5a00', '#fff8e8'))
  b.push(
    box(
      1400,
      120,
      360,
      130,
      '/ranking/<evento>',
      'solo lectura · posición, alias,\npuntaje y desafío',
      '#fdecc8'
    )
  )
  b.push(
    box(
      1400,
      300,
      360,
      110,
      'Actualización',
      'al instante por Realtime\nbotón Actualizar · aviso sin red',
      '#fdecc8'
    )
  )
  b.push(line(1220, 495, 1400, 210, true, 6))
  b.push(label(1310, 380, 'Realtime', true, 16, '#000', 'middle'))
  save('04-partida-ranking', 1800, 590, b.join(''))
}

/* ---------- 5. Deep link de autenticación ---------- */
{
  const b = []
  const steps = [
    ['1 · Pedido', 'registro o recuperación\ndesde la app (PKCE)'],
    ['2 · Correo', 'Supabase envía el enlace\ncon redirect doulingo://'],
    ['3 · Android', 'intent-filter abre\nla app CodeLingua'],
    ['4 · appUrlOpen', 'deepLink.js lee el code\ny descarta duplicados'],
    ['5 · Sesión', 'exchangeCodeForSession\nregistro o PASSWORD_RECOVERY']
  ]
  steps.forEach(([t, s], i) => {
    const x = 20 + i * 330
    b.push(box(x, 60, 280, 120, t, s, i === 4 ? '#cde6d3' : '#cfe2f7'))
    if (i < 4) b.push(line(x + 280, 120, x + 330, 120, true, 5))
  })
  b.push(
    label(
      20,
      40,
      'Enlaces de confirmación y recuperación dentro del APK',
      true,
      22
    )
  )
  b.push(
    box(
      20,
      230,
      1580,
      70,
      'Si el code es falso o venció: aviso en español “El enlace de acceso no sirve o ya venció”',
      '',
      '#fdecc8'
    )
  )
  save('05-deep-link', 1650, 330, b.join(''))
}

/* ---------- 6. Cronograma ---------- */
{
  const b = []
  // días desde el 1/9/2026; barras = período entre hitos del historial de Git
  const rows = [
    ['Etapa 1 · Objetivo, landing y mascota (hito 10/09)', 0, 13, '#5b8bcb'],
    ['Etapa 2 · Unidad funcional y reglas (hito 22/09)', 13, 21, '#5b8bcb'],
    ['Etapa 3 · Base de datos Supabase y RLS (hito 12/10)', 21, 41, '#3f9e4d'],
    ['Etapa 4 · Autenticación y deep link (hito 22/10)', 41, 51, '#3f9e4d'],
    [
      'Etapa 5 · Intentos y progreso en servidor (hito 22/10)',
      41,
      51,
      '#3f9e4d'
    ],
    ['Etapa 6 · Competencia de expo (hito 09/11)', 51, 69, '#e0a020'],
    [
      'Etapa 7 · Ranking público y administración (hito 11/11)',
      69,
      71,
      '#e0a020'
    ],
    ['Etapa 8 · APK, release, manuales e informe (15–17/11)', 71, 77, '#c0504d']
  ]
  const x0 = 520,
    unit = 12.5
  b.push(
    label(20, 36, 'Cronograma real (septiembre – noviembre de 2026)', true, 22)
  )
  ;[
    ['Septiembre', 0, 30],
    ['Octubre', 30, 61],
    ['Noviembre', 61, 91]
  ].forEach(([m, a, z], i) => {
    b.push(
      `<rect x="${x0 + a * unit}" y="56" width="${(z - a) * unit}" height="30" fill="${i % 2 ? '#dfe8f5' : '#cfe2f7'}" stroke="#2b3a55"/>`
    )
    b.push(label(x0 + ((a + z) / 2) * unit, 77, m, true, 16, '#000', 'middle'))
  })
  rows.forEach(([t, a, z, c], i) => {
    const y = 100 + i * 46
    b.push(
      `<rect x="20" y="${y}" width="${x0 - 30}" height="36" fill="#f3f7fc" stroke="#9db6dd"/>`
    )
    b.push(label(30, y + 24, t, false, 14.5, '#000'))
    b.push(
      `<rect x="${x0}" y="${y}" width="${91 * unit}" height="36" fill="#fff" stroke="#e0e6ee"/>`
    )
    b.push(
      `<rect x="${x0 + a * unit}" y="${y + 6}" width="${Math.max(z - a, 2) * unit}" height="24" rx="4" fill="${c}"/>`
    )
  })
  b.push(
    label(
      20,
      482,
      'Las barras cubren el período entre un hito del historial de Git y el anterior.',
      false,
      13
    )
  )
  save('06-cronograma', 1680, 500, b.join(''))
}

/* ---------- Chen ER ---------- */
function chen(name, W, H, ents, rels) {
  const E = {}
  ents.forEach(e => (E[e.id] = e))
  const links = []
  const shapes = []
  for (const e of ents) {
    const w = e.w || 160,
      h = 46
    e.w = w
    e.h = h
    e.attrs.forEach(([t, ang, pk]) => {
      const rad = (ang * Math.PI) / 180
      const rx = e.rx || 150,
        ry = e.ry || 80
      const ax = e.x + rx * Math.cos(rad),
        ay = e.y + ry * Math.sin(rad)
      const aw = Math.max(76, t.length * 8.6 + 28)
      links.push(
        `<line x1="${e.x}" y1="${e.y}" x2="${ax}" y2="${ay}" stroke="#555" stroke-width="1.3"/>`
      )
      shapes.push(
        `<ellipse cx="${ax}" cy="${ay}" rx="${aw / 2}" ry="19" fill="#fff" stroke="#444" stroke-width="1.3"/><text x="${ax}" y="${ay + 5.5}" text-anchor="middle" font-size="15"${pk ? ' text-decoration="underline"' : ''}>${esc(t)}</text>`
      )
    })
    shapes.push(
      `<rect x="${e.x - w / 2}" y="${e.y - h / 2}" width="${w}" height="${h}" fill="${e.fill || '#b9b9b9'}" stroke="#444" stroke-width="1.5"/><text x="${e.x}" y="${e.y + 7}" text-anchor="middle" font-size="18" font-weight="bold">${esc(e.label)}</text>`
    )
  }
  for (const r of rels) {
    const rw = Math.max(120, r.label.length * 8.8 + 34)
    r.rw = rw
    for (const [id, card] of r.to) {
      const e = E[id]
      links.push(
        `<line x1="${e.x}" y1="${e.y}" x2="${r.x}" y2="${r.y}" stroke="#555" stroke-width="1.5"/>`
      )
      // etiqueta de cardinalidad cerca de la entidad
      const dx = r.x - e.x,
        dy = r.y - e.y
      const len = Math.hypot(dx, dy)
      const ux = dx / len,
        uy = dy / len
      // punto de salida del rectángulo
      const tx = Math.abs(ux) > 1e-6 ? e.w / 2 / Math.abs(ux) : Infinity
      const ty = Math.abs(uy) > 1e-6 ? e.h / 2 / Math.abs(uy) : Infinity
      const t = Math.min(tx, ty) + 20
      const lx = e.x + ux * t + (uy !== 0 && Math.abs(ux) < 0.4 ? 14 : 0),
        ly = e.y + uy * t + (Math.abs(ux) >= 0.4 ? -8 : 0)
      shapes.push(
        `<text x="${lx}" y="${ly + 6}" text-anchor="middle" font-size="18" font-weight="bold">${card}</text>`
      )
    }
    shapes.push(
      `<polygon points="${r.x},${r.y - 24} ${r.x + rw / 2},${r.y} ${r.x},${r.y + 24} ${r.x - rw / 2},${r.y}" fill="#fde9d6" stroke="#555" stroke-width="1.5"/><text x="${r.x}" y="${r.y + 5}" text-anchor="middle" font-size="14">${esc(r.label)}</text>`
    )
  }
  save(name, W, H, links.join('') + shapes.join(''))
}

// DER A · contenido, práctica y progreso
chen(
  '07-der-contenido',
  1800,
  1530,
  [
    {
      id: 'cursos',
      label: 'Cursos',
      x: 300,
      y: 130,
      attrs: [
        ['id', 250, 1],
        ['slug', 205],
        ['titulo', 295],
        ['nivel', 340],
        ['estado', 160]
      ]
    },
    {
      id: 'unidades',
      label: 'Unidades',
      x: 300,
      y: 460,
      attrs: [
        ['id', 205, 1],
        ['orden', 340],
        ['titulo', 20],
        ['disponible', 150]
      ]
    },
    {
      id: 'lecciones',
      label: 'Lecciones',
      x: 300,
      y: 790,
      attrs: [
        ['id', 205, 1],
        ['orden', 340],
        ['titulo', 20],
        ['explicacion', 150]
      ]
    },
    {
      id: 'preguntas',
      label: 'Preguntas',
      x: 300,
      y: 1120,
      attrs: [
        ['id', 205, 1],
        ['orden', 340],
        ['enunciado', 20],
        ['codigo', 150]
      ]
    },
    {
      id: 'opciones',
      label: 'Opciones',
      x: 780,
      y: 1430,
      attrs: [
        ['id', 190, 1],
        ['orden', 330],
        ['texto', 15]
      ]
    },
    {
      id: 'soluciones',
      label: 'Soluciones (privada)',
      x: 260,
      y: 1430,
      w: 200,
      attrs: [
        ['pregunta_id', 190, 1],
        ['explicacion', 345],
        ['opcion_correcta_id', 90, 0]
      ]
    },
    {
      id: 'perfiles',
      label: 'Perfiles',
      x: 1400,
      y: 130,
      attrs: [
        ['id', 245, 1],
        ['alias', 295],
        ['alias_sufijo', 345],
        ['es_invitado', 15],
        ['creado_en', 195]
      ]
    },
    {
      id: 'pp',
      label: 'Progreso_lección',
      x: 1000,
      y: 460,
      w: 190,
      attrs: [
        ['estado', 215],
        ['intentos', 255],
        ['mejor_aciertos', 15],
        ['total_actividades', 90, 0]
      ],
      rx: 200
    },
    {
      id: 'intentos',
      label: 'Intentos',
      x: 1400,
      y: 790,
      attrs: [
        ['id', 250, 1],
        ['estado', 295],
        ['aciertos', 345],
        ['errores', 15],
        ['aprobada', 50],
        ['iniciado_en', 135]
      ]
    },
    {
      id: 'resp',
      label: 'Intentos_respuestas',
      x: 1400,
      y: 1120,
      w: 210,
      attrs: [
        ['id', 195, 1],
        ['correcto', 240],
        ['respondido_en', 330],
        ['opcion_id', 30]
      ]
    }
  ],
  [
    {
      label: 'Tiene',
      x: 300,
      y: 295,
      to: [
        ['cursos', '1'],
        ['unidades', 'N']
      ]
    },
    {
      label: 'Tiene',
      x: 300,
      y: 625,
      to: [
        ['unidades', '1'],
        ['lecciones', 'N']
      ]
    },
    {
      label: 'Contiene',
      x: 300,
      y: 955,
      to: [
        ['lecciones', '1'],
        ['preguntas', 'N']
      ]
    },
    {
      label: 'Ofrece',
      x: 600,
      y: 1275,
      to: [
        ['preguntas', '1'],
        ['opciones', 'N']
      ]
    },
    {
      label: 'Se resuelve con',
      x: 260,
      y: 1275,
      to: [
        ['preguntas', '1'],
        ['soluciones', '1']
      ]
    },
    {
      label: 'Se intenta en',
      x: 850,
      y: 790,
      to: [
        ['lecciones', '1'],
        ['intentos', 'N']
      ]
    },
    {
      label: 'Realiza',
      x: 1400,
      y: 460,
      to: [
        ['perfiles', '1'],
        ['intentos', 'N']
      ]
    },
    {
      label: 'Registra',
      x: 1400,
      y: 955,
      to: [
        ['intentos', '1'],
        ['resp', 'N']
      ]
    },
    {
      label: 'Responde a',
      x: 850,
      y: 1120,
      to: [
        ['resp', 'N'],
        ['preguntas', '1']
      ]
    },
    {
      label: 'Acumula',
      x: 1200,
      y: 295,
      to: [
        ['perfiles', '1'],
        ['pp', 'N']
      ]
    },
    {
      label: 'Resume',
      x: 620,
      y: 620,
      to: [
        ['lecciones', '1'],
        ['pp', 'N']
      ]
    }
  ]
)

// DER B · competencia de expo
chen(
  '08-der-competencia',
  1950,
  1450,
  [
    {
      id: 'eventos',
      label: 'Eventos',
      x: 420,
      y: 140,
      attrs: [
        ['id', 245, 1],
        ['slug', 205],
        ['titulo', 295],
        ['estado', 340],
        ['inicia_en', 160],
        ['termina_en', 20]
      ]
    },
    {
      id: 'desafios',
      label: 'Desafíos',
      x: 420,
      y: 480,
      attrs: [
        ['id', 205, 1],
        ['titulo', 240],
        ['dificultad', 295],
        ['duracion_segundos', 320, 0],
        ['puntos_por_acierto', 155, 0],
        ['intentos_permitidos', 120, 0]
      ],
      rx: 170,
      ry: 95
    },
    {
      id: 'dp',
      label: 'Desafío_preguntas',
      x: 420,
      y: 810,
      w: 210,
      attrs: [
        ['id', 205, 1],
        ['enunciado', 245],
        ['orden', 300],
        ['dificultad', 160]
      ]
    },
    {
      id: 'sol',
      label: 'Desafío_soluciones',
      x: 220,
      y: 1190,
      w: 210,
      attrs: [
        ['pregunta_id', 160, 1],
        ['explicacion', 20],
        ['opcion_correcta_id', 90, 0]
      ],
      rx: 170
    },
    {
      id: 'do',
      label: 'Desafío_opciones',
      x: 700,
      y: 1190,
      w: 200,
      attrs: [
        ['id', 160, 1],
        ['orden', 220],
        ['texto', 90]
      ]
    },
    {
      id: 'perfiles',
      label: 'Perfiles',
      x: 1500,
      y: 140,
      attrs: [
        ['id', 245, 1],
        ['alias', 295],
        ['alias_sufijo', 345],
        ['es_invitado', 195]
      ]
    },
    {
      id: 'admin',
      label: 'Admin_roles',
      x: 1780,
      y: 400,
      w: 160,
      attrs: [
        ['user_id', 315, 1],
        ['rol', 120],
        ['asignado_en', 60, 0]
      ],
      rx: 110
    },
    {
      id: 'partidas',
      label: 'Partidas',
      x: 1150,
      y: 480,
      attrs: [
        ['id', 210, 1],
        ['estado', 245],
        ['puntos', 300],
        ['aciertos', 345],
        ['errores', 15],
        ['duracion_ms', 120, 0],
        ['expira_en', 160]
      ]
    },
    {
      id: 'pr',
      label: 'Partida_respuestas',
      x: 1150,
      y: 810,
      w: 210,
      attrs: [
        ['id', 200, 1],
        ['correcto', 235],
        ['puntos_obtenidos', 305, 0],
        ['tiempo_ms', 15]
      ],
      rx: 160
    },
    {
      id: 'res',
      label: 'Resultados_públicos',
      x: 1650,
      y: 810,
      w: 220,
      attrs: [
        ['id', 160, 1],
        ['alias', 270],
        ['puntos', 325],
        ['duracion_ms', 15],
        ['finalizado_en', 90, 0]
      ],
      rx: 175
    }
  ],
  [
    {
      label: 'Agrupa',
      x: 420,
      y: 310,
      to: [
        ['eventos', '1'],
        ['desafios', 'N']
      ]
    },
    {
      label: 'Tiene',
      x: 420,
      y: 645,
      to: [
        ['desafios', '1'],
        ['dp', 'N']
      ]
    },
    {
      label: 'Se resuelve con',
      x: 220,
      y: 1010,
      to: [
        ['dp', '1'],
        ['sol', '1']
      ]
    },
    {
      label: 'Ofrece',
      x: 700,
      y: 1010,
      to: [
        ['dp', '1'],
        ['do', 'N']
      ]
    },
    {
      label: 'Se juega en',
      x: 790,
      y: 480,
      to: [
        ['desafios', '1'],
        ['partidas', 'N']
      ]
    },
    {
      label: 'Juega',
      x: 1150,
      y: 300,
      to: [
        ['perfiles', '1'],
        ['partidas', 'N']
      ]
    },
    {
      label: 'Asigna (partida_preguntas)',
      x: 800,
      y: 700,
      to: [
        ['partidas', 'N'],
        ['dp', 'N']
      ]
    },
    {
      label: 'Registra',
      x: 1150,
      y: 645,
      to: [
        ['partidas', '1'],
        ['pr', 'N']
      ]
    },
    {
      label: 'Elige',
      x: 960,
      y: 1010,
      to: [
        ['pr', 'N'],
        ['do', '1']
      ]
    },
    {
      label: 'Publica',
      x: 1450,
      y: 645,
      to: [
        ['partidas', '1'],
        ['res', 'N']
      ]
    },
    {
      label: 'Es admin',
      x: 1700,
      y: 270,
      to: [
        ['perfiles', '1'],
        ['admin', '1']
      ]
    }
  ]
)

console.log('ok')
