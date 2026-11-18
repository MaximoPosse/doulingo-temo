import fs from 'node:fs'
import path from 'node:path'
import { execFileSync } from 'node:child_process'
import { pathToFileURL } from 'node:url'

const [, , dir, out, scale = '1.5'] = process.argv
fs.mkdirSync(out, { recursive: true })
const edge = 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'
for (const f of fs
  .readdirSync(dir)
  .filter(f => f.endsWith('.svg') || f.endsWith('.html'))) {
  let html, w, h, png
  if (f.endsWith('.svg')) {
    const s = fs.readFileSync(path.join(dir, f), 'utf8')
    const m = s.match(/viewBox="0 0 (\d+) (\d+)"/)
    w = +m[1]
    h = +m[2]
    html = path.resolve(out, f.replace('.svg', '.tmp.html'))
    fs.writeFileSync(html, `<html><body style="margin:0">${s}</body></html>`)
    png = path.resolve(out, f.replace('.svg', '.png'))
  } else {
    const s = fs.readFileSync(path.join(dir, f), 'utf8')
    const m = s.match(/<!--size:(\d+),(\d+)-->/)
    w = +m[1]
    h = +m[2]
    html = path.resolve(dir, f)
    png = path.resolve(out, f.replace('.html', '.png'))
  }
  execFileSync(
    edge,
    [
      '--headless=new',
      '--disable-gpu',
      '--hide-scrollbars',
      `--window-size=${w},${h}`,
      `--force-device-scale-factor=${scale}`,
      `--screenshot=${png}`,
      pathToFileURL(html).href
    ],
    { stdio: 'ignore' }
  )
  if (f.endsWith('.svg')) fs.unlinkSync(html)
}
