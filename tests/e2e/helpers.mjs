// Utilidades compartidas por las pruebas end-to-end.
//
// Las pruebas usan el navegador de forma automática (puppeteer-core + Edge
// instalado en el sistema) y leen la configuración del proyecto Supabase del
// archivo `.env` de la raíz (nunca de un archivo versionado).

import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const here = path.dirname(fileURLToPath(import.meta.url))
const repoRoot = path.resolve(here, '../..')

// Lee el `.env` de la raíz (formato KEY=VALUE) sin depender de dotenv.
function readEnvFile(file) {
  try {
    const raw = fs.readFileSync(file, 'utf8')
    const values = {}
    for (const line of raw.split(/\r?\n/)) {
      const trimmed = line.trim()
      if (!trimmed || trimmed.startsWith('#')) continue
      const idx = trimmed.indexOf('=')
      if (idx === -1) continue
      const key = trimmed.slice(0, idx).trim()
      let value = trimmed.slice(idx + 1).trim()
      if (
        (value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))
      ) {
        value = value.slice(1, -1)
      }
      values[key] = value
    }
    return values
  } catch {
    return {}
  }
}

const fileEnv = readEnvFile(path.join(repoRoot, '.env'))

export function env(name, fallback = null) {
  return process.env[name] ?? fileEnv[name] ?? fallback
}

// URL y clave pública del proyecto Supabase.
export const SUPABASE_URL = env(
  'VITE_SUPABASE_URL',
  'https://apgmzypxbzuvprbedbzi.supabase.co'
)
export const SUPABASE_KEY =
  env('VITE_SUPABASE_PUBLISHABLE_KEY') ?? env('VITE_SUPABASE_ANON_KEY') ?? ''

// Origen donde se prueba la app (build de producción servida estáticamente).
export const BASE_URL = env('E2E_BASE_URL', 'http://localhost:9100')

// Busca el navegador: variable de entorno, rutas habituales de Edge/Chrome.
const BROWSER_CANDIDATES = [
  'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
  'C:/Program Files/Microsoft/Edge/Application/msedge.exe',
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe'
]

export function browserPath() {
  const configured = env('E2E_BROWSER')
  if (configured) return configured
  const found = BROWSER_CANDIDATES.find(candidate => fs.existsSync(candidate))
  if (!found)
    throw new Error(
      'No se encontró un navegador. Definí E2E_BROWSER con la ruta a Edge o Chrome.'
    )
  return found
}

// Cliente de Supabase para las pruebas de API (sin sesión persistente).
export function createSupabaseClient(authOptions = {}) {
  return import('@supabase/supabase-js').then(({ createClient }) =>
    createClient(SUPABASE_URL, SUPABASE_KEY, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
        ...authOptions
      }
    })
  )
}

// Cliente REST simple (para comprobar RLS sin la librería).
export function restHeaders() {
  return { apikey: SUPABASE_KEY, Authorization: `Bearer ${SUPABASE_KEY}` }
}

export async function rest(tablePath, options = {}) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${tablePath}`, {
    ...options,
    headers: { ...restHeaders(), ...options.headers }
  })
  const text = await response.text()
  let body = text
  try {
    body = JSON.parse(text)
  } catch {
    /* la respuesta no es JSON */
  }
  return { status: response.status, body }
}

export async function rpc(functionName, args) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${functionName}`, {
    method: 'POST',
    headers: { ...restHeaders(), 'content-type': 'application/json' },
    body: JSON.stringify(args)
  })
  const text = await response.text()
  let body = text
  try {
    body = JSON.parse(text)
  } catch {
    /* la respuesta no es JSON */
  }
  return { status: response.status, body }
}

// Lanzador del navegador (Puppeteer con el navegador del sistema).
export async function launchBrowser(options = {}) {
  const { default: puppeteer } = await import('puppeteer-core')
  return puppeteer.launch({
    executablePath: browserPath(),
    headless: 'new',
    args: ['--no-sandbox'],
    ...options
  })
}

// Acumulador de resultados con salida formateada.
export function createRunner(title) {
  const results = []
  console.log(title)
  return {
    check(name, condition, extra = '') {
      const ok = !!condition
      results.push([name, ok])
      console.log(
        `${ok ? 'PASS' : 'FAIL'}  ${name}${extra ? ' :: ' + extra : ''}`
      )
      return ok
    },
    summary(label) {
      const failed = results.filter(result => !result[1])
      console.log(
        `\nRESUMEN ${label}: ${results.length - failed.length}/${results.length} OK`
      )
      return failed.length
    }
  }
}

export const sleep = ms => new Promise(resolve => setTimeout(resolve, ms))
