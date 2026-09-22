// Contenido del curso "JavaScript desde cero".
//
// Niveles de contenido:
//   curso  -> units[]  -> lessons[]  -> activities[]
//
// Reglas de identidad:
//   - Cada elemento tiene un `id` único dentro de su nivel.
//   - Cada elemento indica explícitamente su nivel padre:
//       * actividad.lessonId  -> id de su lección
//       * lección pertenece a un unit por ubicación en `unit.lessons`
//       * unidad pertenece al curso por ubicación en `course.units`
//
// Actividad (múltiple opción, una sola correcta):
//   {
//     id,              // identificador único de la actividad
//     lessonId,        // actividad.lessonId -> lección a la que pertenece
//     type: 'choice',
//     prompt,          // enunciado
//     options,         // [{ id, text }, ...] opciones con su identificador
//     answerOptionId,  // identificador de la opción correcta
//     explanation      // explicación de la solución (devolución textual)
//   }
//
// `published`: estado de publicación del contenido. La unidad funcional de
// esta entrega es "fundamentos"; las demás quedan identificadas pero sin
// publicar (pendientes). El avance individual NO es parte del contenido:
// se guarda aparte en useProgress.

export const javascriptCourse = {
  id: 'javascript',
  slug: 'javascript',
  title: 'JavaScript desde cero',
  description:
    'Aprende el lenguaje que da vida a la web. Esta entrega incluye la unidad 1 con dos lecciones completas.',
  color: '#f7df1e',
  icon: 'code',
  units: [
    {
      id: 'fundamentos',
      order: 1,
      title: 'Fundamentos de JavaScript',
      description:
        'Qué es JavaScript, cómo se ejecuta y cómo guardar información en variables.',
      icon: 'code',
      published: true,
      lessons: [
        {
          id: 'fundamentos-1',
          title: '¿Qué es JavaScript?',
          explanation:
            'JavaScript es el lenguaje que agrega lógica e interactividad a las páginas web: responde clics, valida formularios y actualiza contenido en vivo. Se ejecuta directamente en el navegador del usuario (y también en el servidor mediante Node.js). Para comprobar qué hace tu código, la función console.log() imprime un mensaje en la consola del desarrollador.',
          codeExample:
            "console.log('Hola, mundo');\n\n// Llamamos a la función con su nombre\n// seguido de paréntesis: console.log()",
          activities: [
            {
              id: 'f1-e1',
              lessonId: 'fundamentos-1',
              type: 'choice',
              prompt:
                'Según la lección, ¿para qué se usa principalmente JavaScript?',
              options: [
                { id: 'a', text: 'Dar lógica e interactividad a la web' },
                { id: 'b', text: 'Estilizar páginas web' },
                { id: 'c', text: 'Administrar bases de datos' },
                { id: 'd', text: 'Diseñar íconos' }
              ],
              answerOptionId: 'a',
              explanation:
                'JavaScript se encarga de la lógica e interactividad. CSS estiliza; las bases de datos se consultan por otros medios.'
            },
            {
              id: 'f1-e2',
              lessonId: 'fundamentos-1',
              type: 'choice',
              prompt:
                '¿Qué función imprime un mensaje en la consola del navegador?',
              options: [
                { id: 'a', text: 'console.log()' },
                { id: 'b', text: 'print()' },
                { id: 'c', text: 'write()' },
                { id: 'd', text: 'show()' }
              ],
              answerOptionId: 'a',
              explanation:
                'console.log() es la función que escribe el mensaje en la consola del desarrollador, ideal para probar tu código.'
            },
            {
              id: 'f1-e3',
              lessonId: 'fundamentos-1',
              type: 'choice',
              prompt:
                'Usando la función de la lección: ¿qué muestra este código?',
              code: "console.log('Hola');",
              options: [
                { id: 'a', text: 'Hola' },
                { id: 'b', text: "'Hola'" },
                { id: 'c', text: 'Nada' },
                { id: 'd', text: 'Un error' }
              ],
              answerOptionId: 'a',
              explanation:
                'La consola muestra el contenido del valor: Hola, sin las comillas que solo marcan que es texto.'
            }
          ]
        },
        {
          id: 'fundamentos-2',
          title: 'Variables: guardar información',
          explanation:
            'Una variable guarda un valor para reutilizarlo. Con let declaras una variable cuyo valor puede cambiar; con const declaras una constante que no puede cambiar. En JavaScript hay valores numéricos (42), textos o strings ("Hola") y booleanos (true, false). Para usar una variable la declaras y luego la nombras en el resto del código.',
          codeExample:
            "const nombre = 'Usagi'; // constante: no cambia\nlet puntos = 5; // variable: puede cambiar\n\npuntos = puntos + 3; // suma 3 al valor actual\nconsole.log(nombre, puntos); // Usagi 8",
          activities: [
            {
              id: 'f2-e1',
              lessonId: 'fundamentos-2',
              type: 'choice',
              prompt:
                '¿Con qué palabra clave declaras una variable que NO puede cambiar su valor?',
              options: [
                { id: 'a', text: 'const' },
                { id: 'b', text: 'let' },
                { id: 'c', text: 'variable' },
                { id: 'd', text: 'if' }
              ],
              answerOptionId: 'a',
              explanation:
                'const crea una constante: una vez asignado su valor, no puede reasignarse. let sí permite cambiar el valor.'
            },
            {
              id: 'f2-e2',
              lessonId: 'fundamentos-2',
              type: 'choice',
              prompt: '¿Qué tipo de dato es el valor "Hola"?',
              options: [
                { id: 'a', text: 'string (texto)' },
                { id: 'b', text: 'number (número)' },
                { id: 'c', text: 'boolean' },
                { id: 'd', text: 'código' }
              ],
              answerOptionId: 'a',
              explanation:
                'Es un string: un texto entre comillas. Los números van sin comillas y los booleanos son true o false.'
            },
            {
              id: 'f2-e3',
              lessonId: 'fundamentos-2',
              type: 'choice',
              prompt:
                'Usando el ejemplo de la lección: ¿cuánto vale la variable puntos?',
              code: 'let puntos = 5;\npuntos = puntos + 3;',
              options: [
                { id: 'a', text: '8' },
                { id: 'b', text: '5' },
                { id: 'c', text: '3' },
                { id: 'd', text: '53' }
              ],
              answerOptionId: 'a',
              explanation:
                'puntos + 3 toma el valor actual (5) y le suma 3: el nuevo valor es 8, que queda guardado en la variable.'
            }
          ]
        }
      ]
    },
    {
      id: 'variables',
      order: 2,
      title: 'Variables y tipos de datos',
      description:
        'Amplía el manejo de let, const y los tipos de datos. Pendiente de publicación.',
      icon: 'data_object',
      published: false,
      lessons: []
    },
    {
      id: 'condicionales',
      order: 3,
      title: 'Condicionales',
      description:
        'Tomar decisiones con if, else if y else. Pendiente de publicación.',
      icon: 'call_split',
      published: false,
      lessons: []
    },
    {
      id: 'bucles',
      order: 4,
      title: 'Bucles y repetición',
      description:
        'Repetir acciones con for y while. Pendiente de publicación.',
      icon: 'loop',
      published: false,
      lessons: []
    },
    {
      id: 'funciones',
      order: 5,
      title: 'Funciones',
      description:
        'Código reutilizable con parámetros y return. Pendiente de publicación.',
      icon: 'functions',
      published: false,
      lessons: []
    }
  ]
}
