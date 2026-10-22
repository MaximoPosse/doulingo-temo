// Comprobaciones de la pantalla de acceso que NO dependen de la configuración
// del proyecto (invitados anónimos habilitados, correos, etc.).
//
//   node tests/e2e/auth_ui.mjs
//
// Verifica la ruta protegida, los mensajes de error claros y las reglas del
// alias: son las parte de la etapa de autenticación que se pueden comprobar en
// cualquier momento.

import { BASE_URL, createRunner, launchBrowser, sleep } from './helpers.mjs'

const runner = createRunner(
  '=== Pantalla de acceso (sin configuración externa) ==='
)
const browser = await launchBrowser()
const page = await browser.newPage()
const pageErrors = []
page.on('pageerror', error => pageErrors.push(String(error)))

const text = () =>
  page.evaluate(() => document.body.innerText.replace(/\s+/g, ' '))

try {
  // 1. Ruta protegida sin sesión.
  await page.goto(`${BASE_URL}/#/perfil`, { waitUntil: 'networkidle0' })
  await sleep(1500)
  const hash = await page.evaluate(() => location.hash)
  runner.check(
    'Ruta protegida /perfil redirige a /acceso sin sesión',
    hash.includes('/acceso'),
    hash
  )

  // 2. Acceso como invitado: debe funcionar o explicar cómo habilitarlo.
  await page.goto(`${BASE_URL}/#/acceso`, { waitUntil: 'networkidle0' })
  await sleep(1000)
  await page.evaluate(() => {
    const button = [...document.querySelectorAll('button')].find(candidate =>
      candidate.innerText.includes('INVITADO')
    )
    button?.click()
  })
  await sleep(3000)
  const guestText = await text()
  runner.check(
    'El acceso como invitado explica cómo habilitarlo (o funciona)',
    /no está habilitado|Anonymous/i.test(guestText) ||
      /Mi cuenta|Sesión activa/i.test(guestText),
    guestText.slice(0, 180)
  )

  // 3. Credenciales inválidas -> mensaje claro.
  await page.goto(`${BASE_URL}/#/acceso`, { waitUntil: 'networkidle0' })
  await sleep(800)
  await page.evaluate(() => {
    const tab = [...document.querySelectorAll('.q-tab')].find(candidate =>
      candidate.innerText.includes('Ingresar')
    )
    tab?.click()
  })
  await sleep(700)
  await page.evaluate(() => {
    const inputs = [...document.querySelectorAll('input')]
    const mail = inputs.find(input => input.type === 'email')
    const pass = inputs.find(input => input.type === 'password')
    const setValue = (element, value) => {
      const setter = Object.getOwnPropertyDescriptor(
        window.HTMLInputElement.prototype,
        'value'
      ).set
      setter.call(element, value)
      element.dispatchEvent(new Event('input', { bubbles: true }))
    }
    if (mail) setValue(mail, 'alguien@example.com')
    if (pass) setValue(pass, 'clave-incorrecta')
  })
  await sleep(400)
  await page.evaluate(() => {
    const button = [...document.querySelectorAll('button')].find(
      candidate => candidate.innerText.trim() === 'ENTRAR'
    )
    button?.click()
  })
  await sleep(3000)
  const loginText = await text()
  runner.check(
    'Credenciales inválidas muestran mensaje claro (sin datos crudos)',
    /incorrecto|Correo o contraseña/i.test(loginText) &&
      !/AuthApiError|status: 400/i.test(loginText),
    loginText.slice(0, 200)
  )

  // 4. El registro explica las reglas del alias.
  await page.goto(`${BASE_URL}/#/acceso`, { waitUntil: 'networkidle0' })
  await sleep(700)
  await page.evaluate(() => {
    const tab = [...document.querySelectorAll('.q-tab')].find(candidate =>
      candidate.innerText.includes('Crear cuenta')
    )
    tab?.click()
  })
  await sleep(700)
  const registerText = await text()
  runner.check(
    'El registro explica las reglas del alias',
    /3 a 20 caracteres/.test(registerText),
    registerText.slice(0, 160)
  )

  runner.check(
    'Sin errores de página',
    pageErrors.length === 0,
    pageErrors.join(' | ')
  )
} catch (error) {
  runner.check('Recorrido sin excepciones', false, error.message)
}

await browser.close()
process.exit(runner.summary('UI AUTH') ? 1 : 0)
