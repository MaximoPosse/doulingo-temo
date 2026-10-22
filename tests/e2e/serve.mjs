// Servidor estático de la build de producción (dist/spa) para las pruebas.
//
//   node tests/e2e/serve.mjs [puerto]
//
// Sirve la carpeta que genera `npm run build` con el mismo modo hash que usa
// la aplicación.

import fs from 'node:fs'
import http from 'node:http'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const here = path.dirname(fileURLToPath(import.meta.url))
const dist = path.resolve(here, '../../dist/spa')
const port = Number(process.argv[2] ?? process.env.E2E_PORT ?? 9100)

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
  '.woff2': 'font/woff2'
}

if (!fs.existsSync(dist)) {
  console.error(`No existe ${dist}. Ejecutá "npm run build" primero.`)
  process.exit(1)
}

const server = http.createServer((request, response) => {
  const url = new URL(request.url, `http://${request.headers.host}`)
  let filePath = path.join(dist, decodeURIComponent(url.pathname))
  if (!filePath.startsWith(dist)) {
    response.writeHead(403).end('Prohibido')
    return
  }
  if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
    filePath = path.join(dist, 'index.html')
  }
  const body = fs.readFileSync(filePath)
  response.writeHead(200, {
    'Content-Type': MIME[path.extname(filePath)] ?? 'application/octet-stream',
    'Cache-Control': 'no-store'
  })
  response.end(body)
})

server.listen(port, () => {
  console.log(`Build de producción servida en http://localhost:${port}`)
})
