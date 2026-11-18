// Genera HTML (para PDF) y DOCX del informe y de los manuales.
// Uso: node build.mjs <carpeta-salida> [all|informe|manuales]  (requiere `npm i docx@9`, Microsoft Edge y pdftotext)
import fs from 'node:fs'
import path from 'node:path'
import { execFileSync } from 'node:child_process'
import { pathToFileURL } from 'node:url'
import { PDFDocument } from 'pdf-lib'
import {
  Document,
  Packer,
  Paragraph,
  TextRun,
  ImageRun,
  Table,
  TableRow,
  TableCell,
  WidthType,
  ShadingType,
  AlignmentType,
  HeadingLevel,
  Header,
  Footer,
  PageNumber,
  PageOrientation,
  BorderStyle,
  LevelFormat,
  TableOfContents,
  HorizontalPositionRelativeFrom,
  HorizontalPositionAlign,
  VerticalPositionRelativeFrom,
  VerticalPositionAlign,
  SectionType
} from 'docx'
import { informe, manualParticipantes, manualAdmins } from './content.mjs'

const GEN = path.dirname(new URL(import.meta.url).pathname.replace(/^\//, ''))
const PNG = path.join(GEN, '..', 'diagramas')
const SVG = PNG
const OUT = path.resolve(process.argv[2])
const EDGE = 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'
fs.mkdirSync(OUT, { recursive: true })

const esc = s =>
  s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
const inline = s => {
  // Los fragmentos de código se separan primero para que sus asteriscos no se lean como cursiva.
  const codes = []
  const withoutCode = esc(s).replace(/`([^`]+)`/g, (_, c) => {
    codes.push(c)
    return `\u0000${codes.length - 1}\u0000`
  })
  return withoutCode
    .replace(/\*\*([^*]+)\*\*/g, '<b>$1</b>')
    .replace(/\*([^*]+)\*/g, '<i>$1</i>')
    .replace(/\u0000(\d+)\u0000/g, (_, i) => `<code>${codes[i]}</code>`)
}
const pngSize = f => {
  const b = fs.readFileSync(f)
  return [b.readUInt32BE(16), b.readUInt32BE(20)]
}

/* ===================== HTML / PDF ===================== */
function toHtml(blocks, { title, cover, toc, pages }) {
  const out = []
  const heads = []
  let n = 0
  for (const b of blocks) {
    if (b.t === 'h1') {
      const id = `s${++n}`
      heads.push([b.x, id])
      out.push(
        `<h1 id="${id}"${n === 1 && !cover ? ' class="first"' : ''}>${inline(b.x)}</h1>`
      )
    } else if (b.t === 'h2') out.push(`<h2>${inline(b.x)}</h2>`)
    else if (b.t === 'p') out.push(`<p>${inline(b.x)}</p>`)
    else if (b.t === 'ul')
      out.push(
        '<ul>' + b.items.map(i => `<li>${inline(i)}</li>`).join('') + '</ul>'
      )
    else if (b.t === 'ol')
      out.push(
        '<ol>' + b.items.map(i => `<li>${inline(i)}</li>`).join('') + '</ol>'
      )
    else if (b.t === 'code') out.push(`<pre>${esc(b.x)}</pre>`)
    else if (b.t === 'img') {
      const svg = fs
        .readFileSync(path.join(SVG, b.src + '.svg'), 'utf8')
        .replace(/ width="\d+" height="\d+"/, ' width="100%"')
      out.push(
        `<figure class="${b.landscape ? 'land' : ''}">${svg}<figcaption>${esc(b.cap)}</figcaption></figure>`
      )
    } else if (b.t === 'table') {
      const w = b.widths
      out.push(
        '<table><thead><tr>' +
          b.head
            .map((h, i) => `<th style="width:${w[i]}%">${inline(h)}</th>`)
            .join('') +
          '</tr></thead><tbody>' +
          b.rows
            .map(
              r =>
                '<tr>' + r.map(c => `<td>${inline(c)}</td>`).join('') + '</tr>'
            )
            .join('') +
          '</tbody></table>'
      )
    }
  }
  const tocHtml = toc
    ? `<section class="toc"><h1 class="toc-title">Índice</h1>` +
      heads
        .map(
          ([t, id]) =>
            `<div class="toc-row"><a href="#${id}">${esc(t)}</a><span class="dots"></span><span>${pages?.[t] ?? ''}</span></div>`
        )
        .join('') +
      '</section>'
    : ''
  const coverImg = cover
    ? `<section class="cover"><img src="${pathToFileURL(path.join(PNG, 'portada.png')).href}"></section>`
    : ''
  return `<!doctype html><html lang="es"><head><meta charset="utf-8"><title>${esc(title)}</title><style>
@page { size: A4; margin: 20mm 18mm 20mm 18mm;
  @top-center { content: "${title}"; font: 600 9pt Arial; color: #444; }
  @bottom-center { content: "Documentación del proyecto | Página " counter(page); font: 9pt Arial; color: #555; } }
@page cover { margin: 0; @top-center{content:none} @bottom-center{content:none} }
@page land { size: A4 landscape; margin: 12mm 10mm; }
body { margin: 0; font-family: Arial, Helvetica, sans-serif; font-size: 10.5pt; line-height: 1.45; color: #1d1d1d; }
section.cover { page: cover; page-break-after: always; width: 210mm; height: 297mm; margin: 0; overflow: hidden }
section.cover img { width: 210mm; height: 297mm; display: block }
section.toc { page-break-after: always; }
.band { font-weight: bold; text-align: center; color: #58a700; font-size: 13pt; margin-bottom: 12pt; }
h1 { font-size: 20pt; color: #1f4e79; margin: 22pt 0 8pt; page-break-after: avoid; }
h1.toc-title { margin-top: 0 }
h1:not(.first):not(.toc-title) { }
h2 { font-size: 13pt; color: #2e5aa0; margin: 14pt 0 5pt; page-break-after: avoid; }
p { margin: 5pt 0 7pt; text-align: justify; }
ul, ol { margin: 4pt 0 8pt 0; padding-left: 20pt } li { margin: 2.5pt 0 }
code { font-family: Consolas, monospace; font-size: 9pt; background: #eef3f8; padding: 0 2pt; border-radius: 2px }
pre { font-family: Consolas, monospace; font-size: 8.4pt; background: #f4f7fa; border: 1px solid #d5dde6; border-left: 4px solid #9db6dd; padding: 7pt 9pt; white-space: pre-wrap; page-break-inside: avoid }
table { width: 100%; border-collapse: collapse; margin: 6pt 0 10pt; font-size: 9pt; table-layout: fixed }
th { background: #1f4e79; color: #fff; text-align: left; padding: 4pt 5pt; border: 1px solid #1f4e79 }
td { padding: 3.5pt 5pt; border: 1px solid #c9d3de; vertical-align: top; word-wrap: break-word }
tr { page-break-inside: avoid } tbody tr:nth-child(even) td { background: #f3f7fc }
figure { margin: 10pt 0; text-align: center; page-break-inside: avoid } figure svg { max-width: 100%; height: auto }
figure.land { page: land; page-break-before: always; page-break-after: always; margin: 0 }
figure.land svg { max-height: 172mm; width: auto; max-width: 100% }
figcaption { font-size: 9pt; font-style: italic; color: #555; margin-top: 4pt }
.toc-row { display: flex; align-items: baseline; font-size: 10.5pt; margin: 4pt 0 } .toc-row a { color: #1d1d1d; text-decoration: none }
.dots { flex: 1; border-bottom: 1px dotted #888; margin: 0 5pt }
</style></head><body>${coverImg}${tocHtml}${out.join('\n')}</body></html>`
}

// Estampa la marca de agua (PNG transparente) centrada en cada página menos la portada.
async function stampWatermark(pdfPath, skipFirst) {
  const doc = await PDFDocument.load(fs.readFileSync(pdfPath))
  const img = await doc.embedPng(
    fs.readFileSync(path.join(PNG, 'marca-de-agua.png'))
  )
  const pages = doc.getPages()
  pages.forEach((page, i) => {
    if (skipFirst && i === 0) return
    const { width, height } = page.getSize()
    const w = Math.min(width, height) * 0.72
    const h = (w * img.height) / img.width
    page.drawImage(img, {
      x: (width - w) / 2,
      y: (height - h) / 2,
      width: w,
      height: h,
      opacity: 0.5
    })
  })
  fs.writeFileSync(pdfPath, await doc.save())
}

function printPdf(htmlPath, pdfPath) {
  execFileSync(
    EDGE,
    [
      '--headless=new',
      '--disable-gpu',
      '--no-pdf-header-footer',
      `--print-to-pdf=${pdfPath}`,
      pathToFileURL(htmlPath).href
    ],
    { stdio: 'ignore' }
  )
}
function pageTexts(pdf) {
  // devuelve texto por página usando pdftotext
  const txt = execFileSync('pdftotext', ['-enc', 'UTF-8', pdf, '-'], {
    encoding: 'utf8',
    maxBuffer: 1 << 26
  })
  return txt.split('\f')
}

async function buildPdf(name, blocks, opts) {
  const html = path.join(OUT, name + '.html')
  fs.writeFileSync(html, toHtml(blocks, opts))
  const pdf = path.join(OUT, name + '.pdf')
  printPdf(html, pdf)
  if (opts.toc) {
    // segunda pasada con números de página
    const pages = {}
    const texts = pageTexts(pdf)
    const heads = blocks.filter(b => b.t === 'h1').map(b => b.x)
    for (const h of heads) {
      const re = h.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
      for (let i = 2; i < texts.length; i++) {
        if (
          new RegExp('^\\s*' + re.replace(/`/g, '') + '\\s*$', 'm').test(
            texts[i]
          )
        ) {
          pages[h] = i + 1
          break
        }
      }
    }
    fs.writeFileSync(html, toHtml(blocks, { ...opts, pages }))
    printPdf(html, pdf)
  }
  fs.unlinkSync(html)
  await stampWatermark(pdf, !!opts.cover)
  return pdf
}

/* ===================== DOCX ===================== */
const FONT = 'Arial'
function runs(s, base = {}) {
  const parts = []
  const re = /(`[^`]+`|\*\*[^*]+\*\*|\*[^*]+\*)/g
  let last = 0,
    m
  while ((m = re.exec(s))) {
    if (m.index > last)
      parts.push(
        new TextRun({ text: s.slice(last, m.index), font: FONT, ...base })
      )
    const tk = m[0]
    if (tk.startsWith('`'))
      parts.push(
        new TextRun({
          text: tk.slice(1, -1),
          font: 'Consolas',
          ...base,
          shading: { type: ShadingType.CLEAR, fill: 'EEF3F8' }
        })
      )
    else if (tk.startsWith('**'))
      parts.push(
        new TextRun({ text: tk.slice(2, -2), bold: true, font: FONT, ...base })
      )
    else
      parts.push(
        new TextRun({
          text: tk.slice(1, -1),
          italics: true,
          font: FONT,
          ...base
        })
      )
    last = m.index + tk.length
  }
  if (last < s.length)
    parts.push(new TextRun({ text: s.slice(last), font: FONT, ...base }))
  return parts
}
const border = { style: BorderStyle.SINGLE, size: 4, color: 'C9D3DE' }
const borders = { top: border, bottom: border, left: border, right: border }

function toDocx(blocks, { title, cover, toc }) {
  const CW = 9638 // ancho útil vertical (dxa)
  const body = []
  let cur = body
  const sections = []
  const flush = kind => {
    sections.push({ kind, children: cur })
  }
  let curKind = 'portrait'
  const switchTo = kind => {
    if (kind === curKind) return
    flush(curKind)
    cur = []
    curKind = kind
  }
  for (const b of blocks) {
    if (b.t !== 'img' || !b.landscape) switchTo('portrait')
    if (b.t === 'h1')
      cur.push(
        new Paragraph({
          heading: HeadingLevel.HEADING_1,
          children: [new TextRun({ text: b.x, font: FONT })],
          spacing: { before: 280, after: 120 }
        })
      )
    else if (b.t === 'h2')
      cur.push(
        new Paragraph({
          heading: HeadingLevel.HEADING_2,
          children: [new TextRun({ text: b.x, font: FONT })],
          spacing: { before: 200, after: 80 }
        })
      )
    else if (b.t === 'p')
      cur.push(
        new Paragraph({
          children: runs(b.x, { size: 21 }),
          spacing: { after: 110, line: 300 },
          alignment: AlignmentType.JUSTIFIED
        })
      )
    else if (b.t === 'ul')
      b.items.forEach(i =>
        cur.push(
          new Paragraph({
            numbering: { reference: 'bul', level: 0 },
            children: runs(i, { size: 21 }),
            spacing: { after: 50 }
          })
        )
      )
    else if (b.t === 'ol') {
      const ref = 'num' + Math.random().toString(36).slice(2, 7)
      olRefs.push(ref)
      b.items.forEach(i =>
        cur.push(
          new Paragraph({
            numbering: { reference: ref, level: 0 },
            children: runs(i, { size: 21 }),
            spacing: { after: 50 }
          })
        )
      )
    } else if (b.t === 'code') {
      b.x.split('\n').forEach(ln =>
        cur.push(
          new Paragraph({
            children: [
              new TextRun({ text: ln || ' ', font: 'Consolas', size: 17 })
            ],
            shading: { type: ShadingType.CLEAR, fill: 'F4F7FA' },
            spacing: { after: 0 },
            indent: { left: 120 },
            border: {
              left: {
                style: BorderStyle.SINGLE,
                size: 18,
                color: '9DB6DD',
                space: 6
              }
            }
          })
        )
      )
      cur.push(new Paragraph({ children: [], spacing: { after: 80 } }))
    } else if (b.t === 'img') {
      if (b.landscape) switchTo('landscape')
      const f = path.join(PNG, b.src + '.png')
      const [w, h] = pngSize(f)
      const maxW = b.landscape ? 960 : 640,
        maxH = b.landscape ? 560 : 780
      const k = Math.min(maxW / w, maxH / h)
      cur.push(
        new Paragraph({
          alignment: AlignmentType.CENTER,
          children: [
            new ImageRun({
              type: 'png',
              data: fs.readFileSync(f),
              transformation: {
                width: Math.round(w * k),
                height: Math.round(h * k)
              },
              altText: { title: b.cap, description: b.cap, name: b.src }
            })
          ],
          spacing: { before: 120, after: 40 },
          keepNext: true
        })
      )
      cur.push(
        new Paragraph({
          alignment: AlignmentType.CENTER,
          children: [
            new TextRun({
              text: b.cap,
              italics: true,
              size: 18,
              color: '555555',
              font: FONT
            })
          ],
          spacing: { after: 160 }
        })
      )
    } else if (b.t === 'table') {
      const W = b.widths.map(w => Math.round((CW * w) / 100))
      const cell = (txt, i, head, shade) =>
        new TableCell({
          width: { size: W[i], type: WidthType.DXA },
          borders,
          margins: { top: 50, bottom: 50, left: 90, right: 90 },
          shading: {
            type: ShadingType.CLEAR,
            fill: head ? '1F4E79' : shade ? 'F3F7FC' : 'FFFFFF'
          },
          children: [
            new Paragraph({
              children: runs(txt, {
                size: 17,
                ...(head ? { bold: true, color: 'FFFFFF' } : {})
              })
            })
          ]
        })
      cur.push(
        new Table({
          width: { size: CW, type: WidthType.DXA },
          columnWidths: W,
          rows: [
            new TableRow({
              tableHeader: true,
              children: b.head.map((h, i) => cell(h, i, true))
            }),
            ...b.rows.map(
              (r, ri) =>
                new TableRow({
                  cantSplit: true,
                  children: r.map((c, i) => cell(c, i, false, ri % 2))
                })
            )
          ]
        })
      )
      cur.push(new Paragraph({ children: [], spacing: { after: 100 } }))
    }
  }
  flush(curKind)

  const header = new Header({
    children: [
      new Paragraph({
        alignment: AlignmentType.CENTER,
        children: [
          new ImageRun({
            type: 'png',
            data: fs.readFileSync(path.join(PNG, 'marca-de-agua.png')),
            transformation: { width: 520, height: 456 },
            floating: {
              horizontalPosition: {
                relative: HorizontalPositionRelativeFrom.PAGE,
                align: HorizontalPositionAlign.CENTER
              },
              verticalPosition: {
                relative: VerticalPositionRelativeFrom.PAGE,
                align: VerticalPositionAlign.CENTER
              },
              behindDocument: true
            },
            altText: {
              title: 'Marca de agua',
              description: 'Marca de agua',
              name: 'marca-de-agua'
            }
          }),
          new TextRun({
            text: title,
            bold: true,
            size: 18,
            color: '444444',
            font: FONT
          })
        ]
      })
    ]
  })
  const footer = new Footer({
    children: [
      new Paragraph({
        alignment: AlignmentType.CENTER,
        children: [
          new TextRun({
            text: 'Documentación del proyecto | Página ',
            size: 18,
            color: '555555',
            font: FONT
          }),
          new TextRun({
            children: [PageNumber.CURRENT],
            size: 18,
            color: '555555',
            font: FONT
          })
        ]
      })
    ]
  })
  const portrait = {
    page: {
      size: { width: 11906, height: 16838 },
      margin: { top: 1134, bottom: 1134, left: 1134, right: 1134 }
    }
  }
  const landscape = {
    page: {
      size: {
        width: 11906,
        height: 16838,
        orientation: PageOrientation.LANDSCAPE
      },
      margin: { top: 800, bottom: 800, left: 800, right: 800 }
    }
  }

  const secs = []
  if (cover) {
    const f = path.join(PNG, 'portada.png')
    secs.push({
      properties: {
        page: {
          size: { width: 11906, height: 16838 },
          margin: { top: 0, bottom: 0, left: 0, right: 0 }
        }
      },
      children: [
        new Paragraph({
          children: [
            new ImageRun({
              type: 'png',
              data: fs.readFileSync(f),
              transformation: { width: 794, height: 1122 },
              floating: {
                horizontalPosition: { offset: 0 },
                verticalPosition: { offset: 0 },
                behindDocument: true
              },
              altText: {
                title: 'Portada',
                description: 'Portada CodeLingua',
                name: 'portada'
              }
            })
          ]
        })
      ]
    })
  }
  if (toc)
    secs.push({
      properties: { type: SectionType.NEXT_PAGE, ...portrait },
      headers: { default: header },
      footers: { default: footer },
      children: [
        new Paragraph({
          heading: HeadingLevel.HEADING_1,
          children: [new TextRun({ text: 'Índice', font: FONT })]
        }),
        new TableOfContents('Índice', {
          hyperlink: true,
          headingStyleRange: '1-1'
        })
      ]
    })
  sections.forEach(s =>
    secs.push({
      properties: {
        type: SectionType.NEXT_PAGE,
        ...(s.kind === 'landscape' ? landscape : portrait)
      },
      headers: { default: header },
      footers: { default: footer },
      children: s.children
    })
  )

  const mkNum = ref => ({
    reference: ref,
    levels: [
      {
        level: 0,
        format: LevelFormat.DECIMAL,
        text: '%1.',
        alignment: AlignmentType.LEFT,
        style: { paragraph: { indent: { left: 540, hanging: 300 } } }
      }
    ]
  })
  return new Document({
    creator: 'Máximo Posse',
    title,
    features: { updateFields: true },
    styles: {
      default: { document: { run: { font: FONT, size: 21 } } },
      paragraphStyles: [
        {
          id: 'Heading1',
          name: 'Heading 1',
          basedOn: 'Normal',
          next: 'Normal',
          quickFormat: true,
          run: { size: 40, bold: true, color: '1F4E79', font: FONT },
          paragraph: {
            spacing: { before: 280, after: 120 },
            outlineLevel: 0
          }
        },
        {
          id: 'Heading2',
          name: 'Heading 2',
          basedOn: 'Normal',
          next: 'Normal',
          quickFormat: true,
          run: { size: 26, bold: true, color: '2E5AA0', font: FONT },
          paragraph: { spacing: { before: 200, after: 80 }, outlineLevel: 1 }
        }
      ]
    },
    numbering: {
      config: [
        {
          reference: 'bul',
          levels: [
            {
              level: 0,
              format: LevelFormat.BULLET,
              text: '•',
              alignment: AlignmentType.LEFT,
              style: { paragraph: { indent: { left: 540, hanging: 270 } } }
            }
          ]
        },
        ...olRefs.map(mkNum)
      ]
    },
    sections: secs
  })
}
let olRefs = []
async function buildDocx(name, blocks, opts) {
  olRefs = []
  // primera pasada para recolectar referencias de listas numeradas
  toDocx(blocks, opts)
  const doc = toDocx(blocks, opts)
  const f = path.join(OUT, name + '.docx')
  fs.writeFileSync(f, await Packer.toBuffer(doc))
  return f
}

/* ===================== ejecución ===================== */
const which = process.argv[3] || 'all'
if (which === 'all' || which === 'informe') {
  const o = { title: 'CodeLingua', cover: true, toc: true }
  console.log(await buildPdf('Etapa_Final_Informe', informe, o))
  console.log(await buildDocx('Etapa_Final_Informe', informe, o))
}
if (which === 'all' || which === 'manuales') {
  console.log(
    await buildPdf('Manual_Participantes', manualParticipantes, {
      title: 'CodeLingua · Manual para participantes',
      cover: false,
      toc: false
    })
  )
  console.log(
    await buildPdf('Manual_Administradores', manualAdmins, {
      title: 'CodeLingua · Manual para administradores',
      cover: false,
      toc: false
    })
  )
}
