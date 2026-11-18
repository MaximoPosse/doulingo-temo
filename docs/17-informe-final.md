# 17 · Informe final, manuales y diagramas (etapa 8)

| Entregable                        | Archivo                                                    |
| --------------------------------- | ---------------------------------------------------------- |
| Informe final (PDF, 22 páginas)   | [`Etapa_Final_Informe.pdf`](Etapa_Final_Informe.pdf)       |
| Informe final (Word, editable)    | [`Etapa_Final_Informe.docx`](Etapa_Final_Informe.docx)     |
| Manual para participantes         | [`Manual_Participantes.pdf`](Manual_Participantes.pdf)     |
| Manual para administradores       | [`Manual_Administradores.pdf`](Manual_Administradores.pdf) |
| Diagramas (SVG editable + PNG)    | [`diagramas/`](diagramas/)                                 |
| Generador (contenido y diagramas) | [`generador/`](generador/)                                 |

El informe sigue la estructura de ColegioGest (portada, índice, fundamentación,
alcance, objetivo, roles, stakeholders, arquitectura, DER, demostración,
código, dificultad técnica, resultados, defensa, entrega) y suma lo que pide la
etapa 8: historias de usuario, cronograma, reglas de negocio, seguridad,
versiones y procedimiento del APK, checklist en celulares, cierre de la expo y
registro de problemas.

## Verificado el 17/11/2026

| Verificación                                      | Resultado                                                          |
| ------------------------------------------------- | ------------------------------------------------------------------ |
| `oxlint`                                          | Sin errores                                                        |
| `oxfmt`                                           | 17 archivos reformateados; ahora sin diferencias                   |
| `npm run build`                                   | Correcto                                                           |
| `quasar build -m capacitor -T android --skip-pkg` | Correcto                                                           |
| `gradlew assembleDebug`                           | BUILD SUCCESSFUL, 6,3 MB                                           |
| `gradlew assembleRelease` (clave propia)          | BUILD SUCCESSFUL, 4,5 MB, firma válida                             |
| Pruebas e2e contra Supabase                       | 222 casos OK, 7 omitidos por cupo de correos (proyecto reactivado) |
| Instalación en celulares físicos                  | **Pendiente**: no había dispositivos por ADB                       |

## Qué falta (no se marca como aprobado)

1. Verificar que las migraciones 0008–0009 y Realtime estén aplicados en el
   proyecto activo (las suites automáticas cubren hasta la 0006).
2. Instalar la misma build en dos celulares y completar el checklist del informe
   (Atrás, teclado, pantalla pequeña, cierre/reapertura, sin conexión, enlaces
   de confirmación y recuperación).
3. Respaldar la clave release (`doulingo-release.jks`) en un segundo lugar
   seguro. Sin ella no se pueden publicar actualizaciones.
