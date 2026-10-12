-- =============================================================
-- Doulingo · 0002_seed.sql
-- Datos iniciales: curso JavaScript desde cero.
--   - 1 curso disponible con 5 unidades.
--   - Unidad 1 (Fundamentos) disponible: 2 lecciones x 3 preguntas,
--     cada pregunta con 4 opciones y su solución.
--   - Unidades 2-5 en preparación (disponible = false, sin lecciones).
--
-- Ejecutable varias veces: usa ON CONFLICT DO NOTHING.
-- Se usan UUIDs fijos para que las referencias sean estables.
-- =============================================================

-- -------------------------------------------------------------
-- CURSOS
-- -------------------------------------------------------------
insert into public.cursos (id, slug, titulo, descripcion, nivel, estado, color, icono, orden) values
  (
    '00000000-0000-0000-0000-000000000001',
    'javascript',
    'JavaScript desde cero',
    'Aprende el lenguaje que da vida a la web. Esta entrega incluye la unidad 1 con dos lecciones completas.',
    'Principiante',
    'disponible',
    '#f7df1e',
    'code',
    1
  )
on conflict (id) do nothing;

-- -------------------------------------------------------------
-- UNIDADES
-- -------------------------------------------------------------
insert into public.unidades (id, curso_id, orden, titulo, descripcion, icono, disponible) values
  (
    '10000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    1,
    'Fundamentos de JavaScript',
    'Qué es JavaScript, cómo se ejecuta y cómo guardar información en variables.',
    'code',
    true
  ),
  (
    '10000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000001',
    2,
    'Variables y tipos de datos',
    'Amplía el manejo de let, const y los tipos de datos. Pendiente de publicación.',
    'data_object',
    false
  ),
  (
    '10000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000001',
    3,
    'Condicionales',
    'Tomar decisiones con if, else if y else. Pendiente de publicación.',
    'call_split',
    false
  ),
  (
    '10000000-0000-0000-0000-000000000004',
    '00000000-0000-0000-0000-000000000001',
    4,
    'Bucles y repetición',
    'Repetir acciones con for y while. Pendiente de publicación.',
    'loop',
    false
  ),
  (
    '10000000-0000-0000-0000-000000000005',
    '00000000-0000-0000-0000-000000000001',
    5,
    'Funciones',
    'Código reutilizable con parámetros y return. Pendiente de publicación.',
    'functions',
    false
  )
on conflict (id) do nothing;

-- -------------------------------------------------------------
-- LECCIONES DEL MÓDULO 1 (Fundamentos)
-- -------------------------------------------------------------
insert into public.lecciones (id, unidad_id, orden, titulo, explicacion, ejemplo_codigo) values
  (
    '20000000-0000-0000-0000-200000000001',
    '10000000-0000-0000-0000-000000000001',
    1,
    '¿Qué es JavaScript?',
    'JavaScript es el lenguaje que agrega lógica e interactividad a las páginas web: responde clics, valida formularios y actualiza contenido en vivo. Se ejecuta directamente en el navegador del usuario (y también en el servidor mediante Node.js). Para comprobar qué hace tu código, la función console.log() imprime un mensaje en la consola del desarrollador.',
    'console.log(''Hola, mundo'');\n\n// Llamamos a la función con su nombre\n// seguido de paréntesis: console.log()'
  ),
  (
    '20000000-0000-0000-0000-200000000002',
    '10000000-0000-0000-0000-000000000001',
    2,
    'Variables: guardar información',
    'Una variable guarda un valor para reutilizarlo. Con let declaras una variable cuyo valor puede cambiar; con const declaras una constante que no puede cambiar. En JavaScript hay valores numéricos (42), textos o strings ("Hola") y booleanos (true, false). Para usar una variable la declaras y luego la nombras en el resto del código.',
    'const nombre = ''Usagi''; // constante: no cambia\nlet puntos = 5; // variable: puede cambiar\n\npuntos = puntos + 3; // suma 3 al valor actual\nconsole.log(nombre, puntos); // Usagi 8'
  )
on conflict (id) do nothing;

-- -------------------------------------------------------------
-- PREGUNTAS
-- -------------------------------------------------------------
insert into public.preguntas (id, leccion_id, orden, enunciado, codigo) values
  (
    '30000000-0000-0000-0000-310100000000',
    '20000000-0000-0000-0000-200000000001',
    1,
    'Según la lección, ¿para qué se usa principalmente JavaScript?',
    null
  ),
  (
    '30000000-0000-0000-0000-310200000000',
    '20000000-0000-0000-0000-200000000001',
    2,
    '¿Qué función imprime un mensaje en la consola del navegador?',
    null
  ),
  (
    '30000000-0000-0000-0000-310300000000',
    '20000000-0000-0000-0000-200000000001',
    3,
    'Usando la función de la lección: ¿qué muestra este código?',
    'console.log(''Hola'');'
  ),
  (
    '30000000-0000-0000-0000-320100000000',
    '20000000-0000-0000-0000-200000000002',
    1,
    '¿Con qué palabra clave declaras una variable que NO puede cambiar su valor?',
    null
  ),
  (
    '30000000-0000-0000-0000-320200000000',
    '20000000-0000-0000-0000-200000000002',
    2,
    '¿Qué tipo de dato es el valor "Hola"?',
    null
  ),
  (
    '30000000-0000-0000-0000-320300000000',
    '20000000-0000-0000-0000-200000000002',
    3,
    'Usando el ejemplo de la lección: ¿cuánto vale la variable puntos?',
    'let puntos = 5;\npuntos = puntos + 3;'
  )
on conflict (id) do nothing;

-- -------------------------------------------------------------
-- OPCIONES (sin marca de solución)
-- -------------------------------------------------------------
insert into public.opciones (id, pregunta_id, orden, texto) values
  -- Preguntas de la lección 1 (¿Qué es JavaScript?)
  ('40000000-0000-0000-0000-411010000000', '30000000-0000-0000-0000-310100000000', 1, 'Dar lógica e interactividad a la web'),
  ('40000000-0000-0000-0000-411020000000', '30000000-0000-0000-0000-310100000000', 2, 'Estilizar páginas web'),
  ('40000000-0000-0000-0000-411030000000', '30000000-0000-0000-0000-310100000000', 3, 'Administrar bases de datos'),
  ('40000000-0000-0000-0000-411040000000', '30000000-0000-0000-0000-310100000000', 4, 'Diseñar íconos'),

  ('40000000-0000-0000-0000-412010000000', '30000000-0000-0000-0000-310200000000', 1, 'console.log()'),
  ('40000000-0000-0000-0000-412020000000', '30000000-0000-0000-0000-310200000000', 2, 'print()'),
  ('40000000-0000-0000-0000-412030000000', '30000000-0000-0000-0000-310200000000', 3, 'write()'),
  ('40000000-0000-0000-0000-412040000000', '30000000-0000-0000-0000-310200000000', 4, 'show()'),

  ('40000000-0000-0000-0000-413010000000', '30000000-0000-0000-0000-310300000000', 1, 'Hola'),
  ('40000000-0000-0000-0000-413020000000', '30000000-0000-0000-0000-310300000000', 2, '''Hola'''),
  ('40000000-0000-0000-0000-413030000000', '30000000-0000-0000-0000-310300000000', 3, 'Nada'),
  ('40000000-0000-0000-0000-413040000000', '30000000-0000-0000-0000-310300000000', 4, 'Un error'),

  -- Preguntas de la lección 2 (Variables)
  ('40000000-0000-0000-0000-421010000000', '30000000-0000-0000-0000-320100000000', 1, 'const'),
  ('40000000-0000-0000-0000-421020000000', '30000000-0000-0000-0000-320100000000', 2, 'let'),
  ('40000000-0000-0000-0000-421030000000', '30000000-0000-0000-0000-320100000000', 3, 'variable'),
  ('40000000-0000-0000-0000-421040000000', '30000000-0000-0000-0000-320100000000', 4, 'if'),

  ('40000000-0000-0000-0000-422010000000', '30000000-0000-0000-0000-320200000000', 1, 'string (texto)'),
  ('40000000-0000-0000-0000-422020000000', '30000000-0000-0000-0000-320200000000', 2, 'number (número)'),
  ('40000000-0000-0000-0000-422030000000', '30000000-0000-0000-0000-320200000000', 3, 'boolean'),
  ('40000000-0000-0000-0000-422040000000', '30000000-0000-0000-0000-320200000000', 4, 'código'),

  ('40000000-0000-0000-0000-423010000000', '30000000-0000-0000-0000-320300000000', 1, '8'),
  ('40000000-0000-0000-0000-423020000000', '30000000-0000-0000-0000-320300000000', 2, '5'),
  ('40000000-0000-0000-0000-423030000000', '30000000-0000-0000-0000-320300000000', 3, '3'),
  ('40000000-0000-0000-0000-423040000000', '30000000-0000-0000-0000-320300000000', 4, '53')
on conflict (id) do nothing;

-- -------------------------------------------------------------
-- SOLUCIONES (opción correcta + explicación) — privadas por RLS
-- -------------------------------------------------------------
insert into public.soluciones (pregunta_id, opcion_correcta_id, explicacion) values
  (
    '30000000-0000-0000-0000-310100000000',
    '40000000-0000-0000-0000-411010000000',
    'JavaScript se encarga de la lógica e interactividad. CSS estiliza; las bases de datos se consultan por otros medios.'
  ),
  (
    '30000000-0000-0000-0000-310200000000',
    '40000000-0000-0000-0000-412010000000',
    'console.log() es la función que escribe el mensaje en la consola del desarrollador, ideal para probar tu código.'
  ),
  (
    '30000000-0000-0000-0000-310300000000',
    '40000000-0000-0000-0000-413010000000',
    'La consola muestra el contenido del valor: Hola, sin las comillas que solo marcan que es texto.'
  ),
  (
    '30000000-0000-0000-0000-320100000000',
    '40000000-0000-0000-0000-421010000000',
    'const crea una constante: una vez asignado su valor, no puede reasignarse. let sí permite cambiar el valor.'
  ),
  (
    '30000000-0000-0000-0000-320200000000',
    '40000000-0000-0000-0000-422010000000',
    'Es un string: un texto entre comillas. Los números van sin comillas y los booleanos son true o false.'
  ),
  (
    '30000000-0000-0000-0000-320300000000',
    '40000000-0000-0000-0000-423010000000',
    'puntos + 3 toma el valor actual (5) y le suma 3: el nuevo valor es 8, que queda guardado en la variable.'
  )
on conflict (pregunta_id) do nothing;