# 03 · Wireframes de las pantallas principales

Distribución aproximada de títulos, botones, tarjetas, menús e imágenes.
Los bocetos son de baja fidelidad (wireframe) y se ordenan según el flujo de
navegación.

---

## 1. Página de inicio (`/`)

```
┌───────────────────────────────────────────────────────────────────────┐
│ [Usagi] Doulingo        Inicio   Cursos                [ EMPEZAR ]   │  ← header fijo
├───────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  La forma gratuita, divertida y                        ┌────────┐     │
│  efectiva de aprender a programar.                    │ (Usagi)│     │
│                                                       │  ¡Hola!│     │
│  Unidades y lecciones breves, actividades y           └────────┘     │
│  retroalimentación inmediata...                                         │
│                                                                       │
│  [ EMPIEZA GRATIS ]   [ VER CURSOS ]                                 │
│                                                                       │
├───────────────────────────────────────────────────────────────────────┤
│            Gratis para siempre · Cero conocimientos · A tu ritmo      │
├───────────────────────────────────────────────────────────────────────┤
│                       ¿Por qué Doulingo?                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │ ⚡        │  │ ✓        │  │ ☝        │  │ 🏆        │              │
│  │ Lecciones │  │ Retro-   │  │ Progreso │  │ Gamifi-  │              │
│  │ breves    │  │ feedback │  │ visible  │  │ cación   │              │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘              │
├───────────────────────────────────────────────────────────────────────┤
│                        Así funciona                                   │
│  (Usagi)  ● ● ●(●)● 🔒   +  texto: de cero a dominar un lenguaje      │
├───────────────────────────────────────────────────────────────────────┤
│                         [Doulingo]  © 2026                            │
└───────────────────────────────────────────────────────────────────────┘
```

---

## 2. Cursos (`/cursos`)

```
┌───────────────────────────────────────────────────────────────────────┐
│ [Usagi] Doulingo        Inicio   Cursos                [ EMPEZAR ]   │
├───────────────────────────────────────────────────────────────────────┤
│  Elige tu curso                                    (Usagi, 120px)    │
│  Todos empiezan desde cero...                                        │
│                                                                       │
│  ┌─────────────────────────┐  ┌─────────────────────────┐             │
│  │ ▢ [icono JS]  ✔ Disponible│  │ ▢ [icono Py] 🕒 Próximo │             │
│  │ JavaScript desde cero     │  │ Python: primeros pasos │             │
│  │ El lenguaje que da vida   │  │ Un lenguaje claro...   │             │
│  │  ──────────────────       │  │  ──────────────────    │             │
│  │  5 unidades            >  │  │  5 unidades         🔒 │             │
│  └─────────────────────────┘  └─────────────────────────┘             │
│  ┌─────────────────────────┐                                          │
│  │ [icono] 🕒 Próximamente    │                                          │
│  │ HTML y CSS                │                                          │
│  │ La estructura y estilo…   │                                          │
│  │  4 unidades            🔒 │                                          │
│  └─────────────────────────┘                                          │
└───────────────────────────────────────────────────────────────────────┘
```

---

## 3. Detalle del curso (`/cursos/javascript`)

```
┌───────────────────────────────────────────────────────────────────────┐
│ [Usagi] Doulingo        Inicio   Cursos                [ EMPEZAR ]   │
├───────────────────────────────────────────────────────────────────────┤
│ ‹ VOLVER A CURSOS                                                      │
│ ┌───────────────────────────────────────────────────────────────┐     │
│ │ [icono] JS   ✔ Disponible · Principiante                     │     │
│ │             JavaScript desde cero                             │     │
│ │             Aprende el lenguaje que da vida a la web...       │     │
│ │             ▓▓▓▓░░░░  3/15 lecciones completadas (20%)        │     │
│ └───────────────────────────────────────────────────────────────┘     │
│                                                                       │
│  Unidades del curso                                                   │
│                                                                       │
│  (●)│ ┌───────────────────────────────────────────┐                   │
│  1  │ │ UNIDAD 1      [✔ Completada]              │                   │
│     │ │ Fundamentos de JavaScript                   │                   │
│     │ │ ▓▓▓░░ 2/3 lecciones                       > │                   │
│     │ └───────────────────────────────────────────┘                   │
│     │                                                                │
│  (●)│ ┌───────────────────────────────────────────┐                   │
│  2  │ │ UNIDAD 2      [▶ Disponible] *pulso*       │                   │
│     │ │ Variables y tipos de datos                  │                   │
│     │ │ ░░░░░ 0/3 lecciones                        > │                   │
│     │ └───────────────────────────────────────────┘                   │
│     │                                                                │
│  🔒│ ┌───────────────────────────────────────────┐                   │
│  3  │ │ UNIDAD 3      [🔒 Bloqueada]              │                   │
│     │ │ Condicionales                              │                   │
│     │ │ —                                         │                   │
│     │ └───────────────────────────────────────────┘                   │
└───────────────────────────────────────────────────────────────────────┘
```

---

## 4. Lección / Actividad (route de lección)

```
┌───────────────────────────────────────────────────────────────────────┐
│ [Usagi] Doulingo        Inicio   Cursos                [ EMPEZAR ]   │
├───────────────────────────────────────────────────────────────────────┤
│ ✕ ▓▓▓▓▓░░░░░░░░   (barra de progreso del ejercicio)                  │
│                                                                       │
│ UNIDAD 1 / ¿Qué es JavaScript?          Ejercicio 2 de 3            │
│                                                                       │
│   (💬)┌─────────────────────────────┐                               │
│       │ ¿Qué muestra este código?   │                               │
│       └─────────────────────────────┘                               │
│                                                                       │
│ ┌─────────────────────────────┐                                     │
│ │  console.log('Hola');       │  ← bloque de código (oscuro, mono) │
│ └─────────────────────────────┘                                     │
│                                                                       │
│  ┌───────────────────────────────┐                                   │
│  │ A   Hola                     │                                   │
│  ├───────────────────────────────┤                                   │
│  │ B   'Hola'                   │                                   │
│  ├───────────────────────────────┤                                   │
│  │ C   Nada                     │                                   │
│  ├───────────────────────────────┤                                   │
│  │ D   Un error                 │                                   │
│  └───────────────────────────────┘                                   │
│                                                                       │
│  (tras responder con A)                                               │
│  ┌────────────────────────────────────────┐                           │
│  │ ✔ ¡Correcto!                           │                           │
│  │ La consola muestra el contenido...      │                           │
│  └────────────────────────────────────────┘                           │
│                                                              [CONTINUAR]│
└───────────────────────────────────────────────────────────────────────┘
```

---

## 5. Pantalla de resultado (fin de lección)

```
┌───────────────────────────────────────────────────────────────────────┐
│                                                                       │
│                       ┌─────────────────────────┐                     │
│                       │        (Usagi)          │                     │
│                       │  [✔ Lección completada] │                     │
│                       │                         │                     │
│                       │  ¡Perfecto!             │                     │
│                       │  Acertaste 3 de 3       │                     │
│                       │  Sigue así...           │                     │
│                       │                         │                     │
│                       │ [REPETIR] [VOLVER AL CURSO]│                  │
│                       └─────────────────────────┘                     │
└───────────────────────────────────────────────────────────────────────┘
```

---

## 6. Página 404

```
┌───────────────────────────────────────────────────────────────────────┐
│                              (Usagi)                                  │
│                     ¡Ups! Página no encontrada                        │
│              Parece que Usagi se perdió...                            │
│                                                                       │
│                        [ VOLVER AL INICIO ]                           │
└───────────────────────────────────────────────────────────────────────┘
```
