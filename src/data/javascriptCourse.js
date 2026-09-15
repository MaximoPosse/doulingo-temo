// Contenido pedagógico del curso "JavaScript desde cero".
//
// Estructura:
//   curso.units[] -> unidad { id, title, description, icon, lessons[] }
//   unidad.lessons[] -> lección { id, title, exercises[] }
//   leccion.exercises[] -> ejercicio {
//     id, type: 'choice' | 'truefalse',
//     prompt,            // enunciado
//     code?,             // fragmento de código opcional mostrado al estudiante
//     options,           // opciones de respuesta (choice: string[], truefalse: ['Verdadero','Falso'])
//     answer,            // índice de la opción correcta en `options`
//     explanation        // retroalimentación mostrada tras responder
//   }

export const javascriptCourse = {
  id: 'javascript',
  slug: 'javascript',
  title: 'JavaScript desde cero',
  description:
    'Aprende el lenguaje que da vida a la web. Cinco unidades con lecciones breves, actividades y retroalimentación inmediata.',
  color: '#f7df1e',
  icon: 'code',
  units: [
    {
      id: 'fundamentos',
      order: 1,
      title: 'Fundamentos de JavaScript',
      description:
        'Qué es JavaScript, cómo se ejecuta en el navegador y tu primer código.',
      icon: 'code',
      lessons: [
        {
          id: 'fundamentos-1',
          title: '¿Qué es JavaScript?',
          exercises: [
            {
              id: 'f1-e1',
              type: 'choice',
              prompt: '¿Para qué se usa principalmente JavaScript?',
              options: [
                'Estilizar páginas web',
                'Dar lógica e interactividad a la web',
                'Administrar bases de datos',
                'Diseñar íconos'
              ],
              answer: 1,
              explanation:
                'JavaScript se encarga de la lógica e interactividad: responden clics, validan formularios y actualizan contenido en vivo.'
            },
            {
              id: 'f1-e2',
              type: 'truefalse',
              prompt:
                'JavaScript se ejecuta, en general, directamente en el navegador del usuario.',
              options: ['Verdadero', 'Falso'],
              answer: 0,
              explanation:
                'Es correcto: el navegador interpreta JavaScript sin necesidad de compilarlo antes.'
            },
            {
              id: 'f1-e3',
              type: 'choice',
              prompt: '¿Dónde puede ejecutarse JavaScript fuera del navegador?',
              options: [
                'En Node.js',
                'No puede ejecutarse fuera',
                'Solo en sistemas operativos Apple',
                'Solamente en servidores de pago'
              ],
              answer: 0,
              explanation:
                'Node.js permite ejecutar JavaScript en el servidor o en tu computadora, no solo en el navegador.'
            }
          ]
        },
        {
          id: 'fundamentos-2',
          title: 'Código y consola',
          exercises: [
            {
              id: 'f2-e1',
              type: 'choice',
              prompt:
                '¿Qué función imprime un mensaje en la consola del navegador?',
              options: ['console.log()', 'alert()', 'print()', 'write()'],
              answer: 0,
              explanation:
                'console.log() escribe el mensaje en la consola del desarrollador, muy útil para depurar.'
            },
            {
              id: 'f2-e2',
              type: 'choice',
              prompt: '¿Qué muestra este código?',
              code: "console.log('Hola');",
              options: ['Hola', "'Hola'", 'Nada', 'Un error'],
              answer: 0,
              explanation:
                'La consola muestra el contenido del valor: Hola, sin las comillas.'
            },
            {
              id: 'f2-e3',
              type: 'truefalse',
              prompt: 'Los comentarios en el código no se ejecutan.',
              options: ['Verdadero', 'Falso'],
              answer: 0,
              explanation:
                'Los comentarios son solo notas para las personas; el motor de JavaScript los ignora.'
            }
          ]
        },
        {
          id: 'fundamentos-3',
          title: 'Tu primer programa',
          exercises: [
            {
              id: 'f3-e1',
              type: 'choice',
              prompt:
                '¿Cuál es la forma correcta de escribir un comentario de una sola línea en JavaScript?',
              options: [
                '// comentario',
                '# comentario',
                '<!-- comentario -->',
                '<!-- comentario'
              ],
              answer: 0,
              explanation:
                'Con // comienza un comentario de una línea. El signo # se usa en Python.'
            },
            {
              id: 'f3-e2',
              type: 'choice',
              prompt: '¿Qué hace la instrucción siguiente?',
              code: "alert('Hola');",
              options: [
                'Muestra una ventana de diálogo con el texto Hola',
                'Abre el chat de la página',
                'Imprime el texto en la consola',
                'No hace nada'
              ],
              answer: 0,
              explanation:
                'alert() muestra una ventana emergente con el mensaje indicado.'
            },
            {
              id: 'f3-e3',
              type: 'truefalse',
              prompt:
                'En un mismo archivo .js puedes escribir varias instrucciones, una después de otra.',
              options: ['Verdadero', 'Falso'],
              answer: 0,
              explanation:
                'Correcto. JavaScript se lee línea por línea y puedes tener tantas instrucciones como necesites.'
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
        'Guardar información en memoria con let y const: números, textos y booleanos.',
      icon: 'data_object',
      lessons: [
        {
          id: 'variables-1',
          title: 'Declarar variables',
          exercises: [
            {
              id: 'v1-e1',
              type: 'choice',
              prompt:
                '¿Qué palabra clave crea una variable cuyo valor se puede reasignar?',
              options: ['let', 'const', 'fixed', 'valor'],
              answer: 0,
              explanation:
                'let declara una variable mutable: puedes cambiar su valor más adelante.'
            },
            {
              id: 'v1-e2',
              type: 'choice',
              prompt:
                '¿Con qué palabra clave declaras una constante que no puede cambiar?',
              options: ['var', 'const', 'static', 'import'],
              answer: 1,
              explanation:
                'const crea una constante: una vez asignado su valor, no puede cambiarse.'
            },
            {
              id: 'v1-e3',
              type: 'truefalse',
              prompt:
                'Una variable declarada con const puede cambiar de valor después.',
              options: ['Verdadero', 'Falso'],
              answer: 1,
              explanation:
                'Falso. const prohíbe reasignar el valor; por eso se usa cuando el valor no debe cambiar.'
            }
          ]
        },
        {
          id: 'variables-2',
          title: 'Tipos de datos básicos',
          exercises: [
            {
              id: 'v2-e1',
              type: 'choice',
              prompt: '¿Qué tipo de dato es el valor 42?',
              options: ['string', 'number', 'boolean', 'object'],
              answer: 1,
              explanation:
                '42 es un number (número). Los números no llevan comillas.'
            },
            {
              id: 'v2-e2',
              type: 'choice',
              prompt: '¿Qué tipo de dato es el valor "Hola"?',
              options: ['number', 'string', 'boolean', 'caracter'],
              answer: 1,
              explanation:
                'Es un string (cadena de texto): se identifica por estar entre comillas.'
            },
            {
              id: 'v2-e3',
              type: 'choice',
              prompt: '¿Cómo se escribe el valor booleano "verdadero"?',
              options: ['true', 'True', 'verdad', 'Verdadero'],
              answer: 0,
              explanation:
                'En JavaScript los booleanos se escriben en minúsculas: true y false.'
            }
          ]
        },
        {
          id: 'variables-3',
          title: 'Usar variables',
          exercises: [
            {
              id: 'v3-e1',
              type: 'choice',
              prompt: '¿Qué imprime este código?',
              code: 'let a = 5;\nlet b = 3;\nconsole.log(a + b);',
              options: ['8', '53', '35', '15'],
              answer: 0,
              explanation:
                'Con números el operador + realiza la suma: 5 + 3 = 8.'
            },
            {
              id: 'v3-e2',
              type: 'truefalse',
              prompt:
                'Las variables permiten reutilizar un mismo valor en varias partes del código.',
              options: ['Verdadero', 'Falso'],
              answer: 0,
              explanation:
                'Ese es el objetivo principal: guardar un valor y usarlo las veces que necesites.'
            },
            {
              id: 'v3-e3',
              type: 'choice',
              prompt: '¿Qué produce la expresión siguiente?',
              code: "'El ' + 'Perro'",
              options: [
                'El Perro',
                'ElPerro',
                'un error porque no se pueden sumar textos',
                'Perro El'
              ],
              answer: 0,
              explanation:
                'Con textos (strings), el operador + concatena: une ambos valores con un espacio si está incluido.'
            }
          ]
        }
      ]
    },
    {
      id: 'condicionales',
      order: 3,
      title: 'Condicionales',
      description: 'Tomar decisiones en el código con if, else if y else.',
      icon: 'call_split',
      lessons: [
        {
          id: 'condicionales-1',
          title: 'if y else',
          exercises: [
            {
              id: 'c1-e1',
              type: 'choice',
              prompt:
                '¿Qué estructura ejecuta un bloque de código solo si una condición es verdadera?',
              options: ['if', 'for', 'function', 'const'],
              answer: 0,
              explanation:
                'if evalúa una condición y, si es true, ejecuta el bloque entre llaves.'
            },
            {
              id: 'c1-e2',
              type: 'choice',
              prompt:
                '¿Qué palabra clave ejecuta código cuando la condición del if es falsa?',
              options: ['else', 'but', 'unless', 'instead'],
              answer: 0,
              explanation:
                'else complementa al if: su bloque corre cuando la condición no se cumple.'
            },
            {
              id: 'c1-e3',
              type: 'truefalse',
              prompt: 'Un bloque if puede existir sin un bloque else.',
              options: ['Verdadero', 'Falso'],
              answer: 0,
              explanation:
                'Sí, else es opcional. Solo se agrega cuando quieres hacer algo en caso contrario.'
            }
          ]
        },
        {
          id: 'condicionales-2',
          title: 'Comparaciones y lógica',
          exercises: [
            {
              id: 'c2-e1',
              type: 'choice',
              prompt:
                '¿Qué operador compara si dos valores son iguales en valor Y en tipo?',
              options: ['===', '=', '==', '<>'],
              answer: 0,
              explanation:
                '=== revisa valor y tipo. Por ejemplo, 1 === "1" es false.'
            },
            {
              id: 'c2-e2',
              type: 'choice',
              prompt: '¿Cuál es el resultado de la expresión 5 > 3?',
              options: ['true', 'false', '5', 'Un error'],
              answer: 0,
              explanation:
                '5 mayor que 3 es una comparación verdadera, es decir, el booleano true.'
            },
            {
              id: 'c2-e3',
              type: 'truefalse',
              prompt:
                'El operador lógico && devuelve true solo si ambas condiciones son verdaderas.',
              options: ['Verdadero', 'Falso'],
              answer: 0,
              explanation:
                '&& (AND) exige que todas las condiciones sean true para dar true.'
            }
          ]
        },
        {
          id: 'condicionales-3',
          title: 'Decidir en código',
          exercises: [
            {
              id: 'c3-e1',
              type: 'choice',
              prompt: '¿Qué imprime este programa?',
              code: 'let edad = 17;\nif (edad >= 18) {\n  console.log("Mayor");\n} else {\n  console.log("Menor");\n}',
              options: ['Menor', 'Mayor', 'Un error', 'Nada'],
              answer: 0,
              explanation:
                '17 no es mayor o igual a 18, así que se ejecuta el bloque else: imprime Menor.'
            },
            {
              id: 'c3-e2',
              type: 'choice',
              prompt:
                'Si necesitas evaluar una condición adicional cuando el if es falso, ¿qué usas?',
              options: ['else if', 'if doble', 'for', 'repeat'],
              answer: 0,
              explanation:
                'else if encadena condiciones: prueba la siguiente solo si la anterior fue falsa.'
            },
            {
              id: 'c3-e3',
              type: 'truefalse',
              prompt:
                'Un mismo número puede pasar la comparación (n >= 0) y también (n <= 10) al mismo tiempo.',
              options: ['Verdadero', 'Falso'],
              answer: 0,
              explanation:
                'Verdadero: un valor como 5 cumple ambas, por eso a veces se combinan con &&.'
            }
          ]
        }
      ]
    },
    {
      id: 'bucles',
      order: 4,
      title: 'Bucles y repetición',
      description:
        'Repetir acciones sin escribir el mismo código una y otra vez con for y while.',
      icon: 'loop',
      lessons: [
        {
          id: 'bucles-1',
          title: 'El bucle for',
          exercises: [
            {
              id: 'b1-e1',
              type: 'choice',
              prompt:
                '¿Qué bucle es ideal cuando conoces de antemano cuántas veces repetir?',
              options: ['for', 'if', 'else', 'console'],
              answer: 0,
              explanation:
                'for define inicio, condición y avance, ideal para un número conocido de repeticiones.'
            },
            {
              id: 'b1-e2',
              type: 'choice',
              prompt: '¿Qué imprime este bucle?',
              code: 'for (let i = 0; i < 3; i++) {\n  console.log(i);\n}',
              options: ['0 1 2', '1 2 3', '0 1 2 3', '3'],
              answer: 0,
              explanation:
                'i comienza en 0 y se repite mientras i < 3, así que imprime 0, 1 y 2.'
            },
            {
              id: 'b1-e3',
              type: 'truefalse',
              prompt:
                'El bucle while se detiene cuando su condición deja de ser verdadera.',
              options: ['Verdadero', 'Falso'],
              answer: 0,
              explanation:
                'Correcto: while repite mientras la condición sea true y termina cuando se vuelve false.'
            }
          ]
        },
        {
          id: 'bucles-2',
          title: 'El bucle while',
          exercises: [
            {
              id: 'b2-e1',
              type: 'choice',
              prompt:
                '¿Qué bucle se repite mientras una condición siga siendo verdadera?',
              options: ['while', 'const', 'if', 'return'],
              answer: 0,
              explanation:
                'while evalúa la condición antes de cada repetición y continúa mientras sea true.'
            },
            {
              id: 'b2-e2',
              type: 'choice',
              prompt:
                '¿Cuál de estas líneas incrementa correctamente el valor de una variable i en 1?',
              options: ['i = i + 1', 'i + 1', 'i = 1', 'más(i)'],
              answer: 0,
              explanation:
                'i = i + 1 suma 1 al valor actual y lo guarda de vuelta en i. (También funciona i++).'
            },
            {
              id: 'b2-e3',
              type: 'choice',
              prompt: '¿Cuántas veces se imprime "hola" en este código?',
              code: 'let n = 0;\nwhile (n < 2) {\n  console.log("hola");\n  n++;\n}',
              options: ['2', '1', '3', 'Infinitas veces'],
              answer: 0,
              explanation:
                'n va de 0 a 1 y se detiene al llegar a 2, así que el bloque corre exactamente 2 veces.'
            }
          ]
        },
        {
          id: 'bucles-3',
          title: 'Evitar bucles infinitos',
          exercises: [
            {
              id: 'b3-e1',
              type: 'truefalse',
              prompt:
                'Un bucle sin una condición de salida puede hacer que tu página deje de responder.',
              options: ['Verdadero', 'Falso'],
              answer: 0,
              explanation:
                'Sí: un bucle infinito consume toda la CPU y congela el navegador. Siempre asegúrate de que la condición pueda llegar a ser falsa.'
            },
            {
              id: 'b3-e2',
              type: 'choice',
              prompt: '¿Qué imprime este programa?',
              code: 'let total = 0;\nfor (let i = 1; i <= 3; i++) {\n  total = total + i;\n}\nconsole.log(total);',
              options: ['6', '3', '10', '15'],
              answer: 0,
              explanation:
                'Suma 1 + 2 + 3 = 6. La variable total acumula el valor de cada vuelta.'
            }
          ]
        }
      ]
    },
    {
      id: 'funciones',
      order: 5,
      title: 'Funciones',
      description:
        'Envolver código reutilizable, recibir parámetros y devolver resultados con return.',
      icon: 'functions',
      lessons: [
        {
          id: 'funciones-1',
          title: 'Crear y llamar funciones',
          exercises: [
            {
              id: 'fn1-e1',
              type: 'choice',
              prompt:
                '¿Qué palabra clave se usa para definir una función en JavaScript?',
              options: ['function', 'loop', 'let', 'if'],
              answer: 0,
              explanation:
                'function define una función, seguida de su nombre entre paréntesis (sin parámetros o con ellos).'
            },
            {
              id: 'fn1-e2',
              type: 'choice',
              prompt: '¿Qué imprime este código?',
              code: 'function saludar() {\n  console.log("Hola");\n}\nsaludar();',
              options: ['Hola', 'saludar', 'Nada', 'Un error'],
              answer: 0,
              explanation:
                'Definir la función no la ejecuta; la llamada saludar() hace que se imprima Hola.'
            },
            {
              id: 'fn1-e3',
              type: 'truefalse',
              prompt: 'Una función solo se ejecuta cuando es llamada.',
              options: ['Verdadero', 'Falso'],
              answer: 0,
              explanation:
                'Exacto: declararla solo la prepara; debes invocarla con sus paréntesis para que corra.'
            }
          ]
        },
        {
          id: 'funciones-2',
          title: 'Parámetros y return',
          exercises: [
            {
              id: 'fn2-e1',
              type: 'choice',
              prompt: '¿Qué palabra clave devuelve un valor desde una función?',
              options: ['return', 'send', 'output', 'print'],
              answer: 0,
              explanation:
                'return entrega el resultado al lugar que llamó a la función y también la detiene.'
            },
            {
              id: 'fn2-e2',
              type: 'choice',
              prompt: '¿Qué imprime este programa?',
              code: 'function sumar(a, b) {\n  return a + b;\n}\nconsole.log(sumar(2, 3));',
              options: ['5', '23', '6', 'undefined'],
              answer: 0,
              explanation:
                'sumar recibe 2 y 3 como parámetros, devuelve la suma 5, y console.log la muestra.'
            },
            {
              id: 'fn2-e3',
              type: 'truefalse',
              prompt:
                'Los parámetros son los valores que recibe una función al ser llamada.',
              options: ['Verdadero', 'Falso'],
              answer: 0,
              explanation:
                'Correcto: los parámetros actúan como variables internas con los valores aportados en la llamada.'
            }
          ]
        },
        {
          id: 'funciones-3',
          title: 'Funciones en acción',
          exercises: [
            {
              id: 'fn3-e1',
              type: 'choice',
              prompt: '¿Qué imprime este programa?',
              code: 'function esPar(n) {\n  return n % 2 === 0;\n}\nconsole.log(esPar(4));',
              options: ['true', 'false', '4', 'Un error'],
              answer: 0,
              explanation:
                '4 dividido entre 2 deja resto 0, así que esPar(4) devuelve true.'
            },
            {
              id: 'fn3-e2',
              type: 'choice',
              prompt: '¿Para qué sirven principalmente las funciones?',
              options: [
                'Reutilizar código y organizarlo mejor',
                'Decorar la página',
                'Comprimir archivos',
                'Almacenar textos largos'
              ],
              answer: 0,
              explanation:
                'Las funciones agrupan lógica reutilizable: se escriben una vez y se usan muchas.'
            },
            {
              id: 'fn3-e3',
              type: 'truefalse',
              prompt:
                'Dos funciones iguales en un mismo archivo pueden llamarse con el mismo nombre.',
              options: ['Verdadero', 'Falso'],
              answer: 1,
              explanation:
                'Falso: redefinir una función con el mismo nombre reemplaza la anterior; cada nombre debe ser único.'
            }
          ]
        }
      ]
    }
  ]
}
