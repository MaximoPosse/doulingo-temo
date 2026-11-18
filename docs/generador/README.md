# Generador de documentación

Regenera los diagramas (SVG/PNG, estilo ColegioGest), el informe final
(`Etapa_Final_Informe.pdf` y `.docx`) y los manuales en PDF.

Requisitos: Node 20+, Microsoft Edge, `pdftotext` (poppler) y `npm i docx@9`
dentro de esta carpeta (no se versiona `node_modules`).

```bash
cd docs/generador
npm init -y && npm i docx@9
node diagrams.mjs ../diagramas                 # SVG de los diagramas
node render.mjs ../diagramas ../diagramas 1.5   # PNG de cada SVG y de portada.html
node build.mjs .. all                           # informe (PDF+DOCX) y manuales
```

El contenido del informe y de los manuales está en `content.mjs`.
El índice del PDF se calcula en dos pasadas; el del DOCX se actualiza al abrirlo
en Word (aceptar "actualizar campos").
