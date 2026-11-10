-- =============================================================
-- Doulingo · 0007_seed_desafios.sql
-- Datos iniciales de la etapa 6: evento de expo, desafíos y su banco.
--
-- Ejecutable varias veces: usa ON CONFLICT DO UPDATE con UUIDs fijos.
-- Los desafíos `es_prueba = true` pertenecen a un evento interno que la
-- interfaz de la expo oculta; existen para que las pruebas automáticas
-- puedan jugar, vencer y agotar intentos sin tocar los datos de la expo.
--
-- Dificultad, duración, puntos, intentos y tolerancia de cada desafío:
--   facil      · 90 s  · 10 pts/acierto · 2 intentos · tolerancia 20 s
--   intermedio · 120 s · 15 pts/acierto · 1 intento  · tolerancia 30 s
--   dificil    · 150 s · 20 pts/acierto · 1 intento  · tolerancia 30 s
-- =============================================================

-- -------------------------------------------------------------
-- EVENTOS
-- -------------------------------------------------------------
insert into public.eventos (
  id, slug, titulo, descripcion, inicia_en, termina_en, estado, es_prueba
) values
  (
    '40000000-0000-0000-0000-000000000001',
    'expo-doulingo-2026',
    'Expo Doulingo 2026',
    'Competencia de programación para visitantes de la expo. Elegí un desafío, respondé contra el reloj y compará tu mejor intento en el ranking.',
    '2026-11-01T00:00:00Z',
    '2027-12-31T23:59:59Z',
    'publicado',
    false
  ),
  (
    '40000000-0000-0000-0000-000000000002',
    'evento-interno-pruebas',
    'Evento interno de pruebas',
    'Datos reservados para las pruebas automáticas de la competencia. La interfaz de la expo no muestra este evento.',
    '2026-01-01T00:00:00Z',
    '2030-12-31T23:59:59Z',
    'publicado',
    true
  )
on conflict (id) do update set
  slug        = excluded.slug,
  titulo      = excluded.titulo,
  descripcion = excluded.descripcion,
  inicia_en   = excluded.inicia_en,
  termina_en  = excluded.termina_en,
  estado      = excluded.estado,
  es_prueba   = excluded.es_prueba;

-- -------------------------------------------------------------
-- DESAFÍOS PÚBLICOS DE LA EXPO
-- -------------------------------------------------------------
insert into public.desafios (
  id, evento_id, slug, titulo, descripcion, dificultad,
  duracion_segundos, puntos_por_acierto, intentos_permitidos,
  tolerancia_segundos, es_prueba, estado, orden
) values
  (
    '50000000-0000-0000-0000-000000000001',
    '40000000-0000-0000-0000-000000000001',
    'fundamentos-expres',
    'Fundamentos exprés',
    'Variables, tipos y estructuras básicas. Ideal para empezar la expo.',
    'facil', 90, 10, 2, 20, false, 'publicado', 1
  ),
  (
    '50000000-0000-0000-0000-000000000002',
    '40000000-0000-0000-0000-000000000001',
    'logica-intermedia',
    'Lógica intermedia',
    'Arreglos, métodos y funciones. Un paso más de dificultad.',
    'intermedio', 120, 15, 1, 30, false, 'publicado', 2
  ),
  (
    '50000000-0000-0000-0000-000000000003',
    '40000000-0000-0000-0000-000000000001',
    'cierre-dificil',
    'Cierre difícil',
    'Closures, async y evaluación de expresiones. Para cerrar la expo.',
    'dificil', 150, 20, 1, 30, false, 'publicado', 3
  ),
  -- Desafíos internos de prueba.
  (
    '50000000-0000-0000-0000-000000000101',
    '40000000-0000-0000-0000-000000000002',
    'prueba-normal',
    'Prueba normal',
    'Cuatro preguntas con la primera opción correcta. Se usa para probar el flujo completo y el ranking.',
    'facil', 300, 10, 2, 10, true, 'publicado', 1
  ),
  (
    '50000000-0000-0000-0000-000000000102',
    '40000000-0000-0000-0000-000000000002',
    'prueba-vencida',
    'Prueba vencida',
    'Duración de un segundo y sin tolerancia. Se usa para probar partidas vencidas.',
    'facil', 1, 10, 2, 0, true, 'publicado', 2
  ),
  (
    '50000000-0000-0000-0000-000000000103',
    '40000000-0000-0000-0000-000000000002',
    'prueba-un-intento',
    'Prueba de un intento',
    'Un solo intento permitido. Se usa para probar el agotamiento de intentos.',
    'facil', 300, 10, 1, 0, true, 'publicado', 3
  )
on conflict (id) do update set
  evento_id           = excluded.evento_id,
  slug                = excluded.slug,
  titulo              = excluded.titulo,
  descripcion         = excluded.descripcion,
  dificultad          = excluded.dificultad,
  duracion_segundos   = excluded.duracion_segundos,
  puntos_por_acierto  = excluded.puntos_por_acierto,
  intentos_permitidos = excluded.intentos_permitidos,
  tolerancia_segundos = excluded.tolerancia_segundos,
  es_prueba           = excluded.es_prueba,
  estado              = excluded.estado,
  orden               = excluded.orden;

-- -------------------------------------------------------------
-- PREGUNTAS · FUNDAMENTOS EXPRÉS
-- -------------------------------------------------------------
insert into public.desafio_preguntas (
  id, desafio_id, orden, enunciado, codigo, dificultad
) values
  ('60000000-0000-0000-0000-000000010101', '50000000-0000-0000-0000-000000000001', 1,
   '¿Qué palabra clave declara una constante en JavaScript?', null, 'facil'),
  ('60000000-0000-0000-0000-000000010102', '50000000-0000-0000-0000-000000000001', 2,
   '¿Qué devuelve typeof 42?', 'typeof 42', 'facil'),
  ('60000000-0000-0000-0000-000000010103', '50000000-0000-0000-0000-000000000001', 3,
   '¿Qué operador compara valor y tipo a la vez?', null, 'facil'),
  ('60000000-0000-0000-0000-000000010104', '50000000-0000-0000-0000-000000000001', 4,
   '¿Cuál de estos valores es un arreglo?', null, 'facil'),
  ('60000000-0000-0000-0000-000000010105', '50000000-0000-0000-0000-000000000001', 5,
   '¿Qué estructura repite mientras se cumpla una condición?', null, 'facil')
on conflict (id) do update set
  desafio_id = excluded.desafio_id,
  orden      = excluded.orden,
  enunciado  = excluded.enunciado,
  codigo     = excluded.codigo,
  dificultad = excluded.dificultad;

insert into public.desafio_opciones (id, pregunta_id, orden, texto) values
  ('70000000-0000-0000-0000-000000010101', '60000000-0000-0000-0000-000000010101', 1, 'let'),
  ('70000000-0000-0000-0000-000000010102', '60000000-0000-0000-0000-000000010101', 2, 'const'),
  ('70000000-0000-0000-0000-000000010103', '60000000-0000-0000-0000-000000010101', 3, 'var'),
  ('70000000-0000-0000-0000-000000010104', '60000000-0000-0000-0000-000000010101', 4, 'function'),
  ('70000000-0000-0000-0000-000000010201', '60000000-0000-0000-0000-000000010102', 1, 'integer'),
  ('70000000-0000-0000-0000-000000010202', '60000000-0000-0000-0000-000000010102', 2, 'number'),
  ('70000000-0000-0000-0000-000000010203', '60000000-0000-0000-0000-000000010102', 3, 'string'),
  ('70000000-0000-0000-0000-000000010204', '60000000-0000-0000-0000-000000010102', 4, 'NaN'),
  ('70000000-0000-0000-0000-000000010301', '60000000-0000-0000-0000-000000010103', 1, '=='),
  ('70000000-0000-0000-0000-000000010302', '60000000-0000-0000-0000-000000010103', 2, '='),
  ('70000000-0000-0000-0000-000000010303', '60000000-0000-0000-0000-000000010103', 3, '==='),
  ('70000000-0000-0000-0000-000000010304', '60000000-0000-0000-0000-000000010103', 4, '!='),
  ('70000000-0000-0000-0000-000000010401', '60000000-0000-0000-0000-000000010104', 1, '{ a: 1 }'),
  ('70000000-0000-0000-0000-000000010402', '60000000-0000-0000-0000-000000010104', 2, "['a', 'b']"),
  ('70000000-0000-0000-0000-000000010403', '60000000-0000-0000-0000-000000010104', 3, "'a, b'"),
  ('70000000-0000-0000-0000-000000010404', '60000000-0000-0000-0000-000000010104', 4, 'true'),
  ('70000000-0000-0000-0000-000000010501', '60000000-0000-0000-0000-000000010105', 1, 'if'),
  ('70000000-0000-0000-0000-000000010502', '60000000-0000-0000-0000-000000010105', 2, 'while'),
  ('70000000-0000-0000-0000-000000010503', '60000000-0000-0000-0000-000000010105', 3, 'switch'),
  ('70000000-0000-0000-0000-000000010504', '60000000-0000-0000-0000-000000010105', 4, 'return')
on conflict (id) do update set
  pregunta_id = excluded.pregunta_id,
  orden       = excluded.orden,
  texto       = excluded.texto;

insert into public.desafio_soluciones (pregunta_id, opcion_correcta_id, explicacion) values
  ('60000000-0000-0000-0000-000000010101', '70000000-0000-0000-0000-000000010102',
   'const declara una constante: el enlace no se puede reasignar.'),
  ('60000000-0000-0000-0000-000000010102', '70000000-0000-0000-0000-000000010202',
   'typeof 42 devuelve "number": en JavaScript no existe el tipo integer.'),
  ('60000000-0000-0000-0000-000000010103', '70000000-0000-0000-0000-000000010303',
   '=== compara valor y tipo; == solo compara valor después de convertir.'),
  ('60000000-0000-0000-0000-000000010104', '70000000-0000-0000-0000-000000010402',
   'Los corchetes delimitan un arreglo; las llaves, un objeto.'),
  ('60000000-0000-0000-0000-000000010105', '70000000-0000-0000-0000-000000010502',
   'while repite el bloque mientras la condición sea verdadera.')
on conflict (pregunta_id) do update set
  opcion_correcta_id = excluded.opcion_correcta_id,
  explicacion        = excluded.explicacion;

-- -------------------------------------------------------------
-- PREGUNTAS · LÓGICA INTERMEDIA
-- -------------------------------------------------------------
insert into public.desafio_preguntas (
  id, desafio_id, orden, enunciado, codigo, dificultad
) values
  ('60000000-0000-0000-0000-000000020101', '50000000-0000-0000-0000-000000000002', 1,
   '¿Qué método agrega un elemento al final de un arreglo?', null, 'intermedio'),
  ('60000000-0000-0000-0000-000000020102', '50000000-0000-0000-0000-000000000002', 2,
   '¿Qué devuelve [1, 2, 3].map(n => n * 2)?', '[1, 2, 3].map(n => n * 2)', 'intermedio'),
  ('60000000-0000-0000-0000-000000020103', '50000000-0000-0000-0000-000000000002', 3,
   '¿Qué hace el método filter?', null, 'intermedio'),
  ('60000000-0000-0000-0000-000000020104', '50000000-0000-0000-0000-000000000002', 4,
   '¿Qué es una función flecha?', null, 'intermedio'),
  ('60000000-0000-0000-0000-000000020105', '50000000-0000-0000-0000-000000000002', 5,
   '¿Qué devuelve "5" + 2?', '"5" + 2', 'intermedio')
on conflict (id) do update set
  desafio_id = excluded.desafio_id,
  orden      = excluded.orden,
  enunciado  = excluded.enunciado,
  codigo     = excluded.codigo,
  dificultad = excluded.dificultad;

insert into public.desafio_opciones (id, pregunta_id, orden, texto) values
  ('70000000-0000-0000-0000-000000020101', '60000000-0000-0000-0000-000000020101', 1, 'pop'),
  ('70000000-0000-0000-0000-000000020102', '60000000-0000-0000-0000-000000020101', 2, 'push'),
  ('70000000-0000-0000-0000-000000020103', '60000000-0000-0000-0000-000000020101', 3, 'shift'),
  ('70000000-0000-0000-0000-000000020104', '60000000-0000-0000-0000-000000020101', 4, 'slice'),
  ('70000000-0000-0000-0000-000000020201', '60000000-0000-0000-0000-000000020102', 1, '[1, 2, 3]'),
  ('70000000-0000-0000-0000-000000020202', '60000000-0000-0000-0000-000000020102', 2, '[2, 4, 6]'),
  ('70000000-0000-0000-0000-000000020203', '60000000-0000-0000-0000-000000020102', 3, '6'),
  ('70000000-0000-0000-0000-000000020204', '60000000-0000-0000-0000-000000020102', 4, 'undefined'),
  ('70000000-0000-0000-0000-000000020301', '60000000-0000-0000-0000-000000020103', 1, 'Devuelve un arreglo con los elementos que cumplen la condición'),
  ('70000000-0000-0000-0000-000000020302', '60000000-0000-0000-0000-000000020103', 2, 'Modifica cada elemento'),
  ('70000000-0000-0000-0000-000000020303', '60000000-0000-0000-0000-000000020103', 3, 'Ordena los elementos'),
  ('70000000-0000-0000-0000-000000020304', '60000000-0000-0000-0000-000000020103', 4, 'Suma los elementos'),
  ('70000000-0000-0000-0000-000000020401', '60000000-0000-0000-0000-000000020104', 1, 'Un tipo de objeto'),
  ('70000000-0000-0000-0000-000000020402', '60000000-0000-0000-0000-000000020104', 2, 'Una forma corta de escribir funciones'),
  ('70000000-0000-0000-0000-000000020403', '60000000-0000-0000-0000-000000020104', 3, 'Una clase'),
  ('70000000-0000-0000-0000-000000020404', '60000000-0000-0000-0000-000000020104', 4, 'Un bucle'),
  ('70000000-0000-0000-0000-000000020501', '60000000-0000-0000-0000-000000020105', 1, '7'),
  ('70000000-0000-0000-0000-000000020502', '60000000-0000-0000-0000-000000020105', 2, '"52"'),
  ('70000000-0000-0000-0000-000000020503', '60000000-0000-0000-0000-000000020105', 3, 'NaN'),
  ('70000000-0000-0000-0000-000000020504', '60000000-0000-0000-0000-000000020105', 4, 'Error')
on conflict (id) do update set
  pregunta_id = excluded.pregunta_id,
  orden       = excluded.orden,
  texto       = excluded.texto;

insert into public.desafio_soluciones (pregunta_id, opcion_correcta_id, explicacion) values
  ('60000000-0000-0000-0000-000000020101', '70000000-0000-0000-0000-000000020102',
   'push agrega al final; pop y shift quitan elementos.'),
  ('60000000-0000-0000-0000-000000020102', '70000000-0000-0000-0000-000000020202',
   'map transforma cada elemento y devuelve un arreglo nuevo.'),
  ('60000000-0000-0000-0000-000000020103', '70000000-0000-0000-0000-000000020301',
   'filter conserva los elementos para los que la función devuelve true.'),
  ('60000000-0000-0000-0000-000000020104', '70000000-0000-0000-0000-000000020402',
   'La sintaxis (parámetros) => expresión es una función flecha.'),
  ('60000000-0000-0000-0000-000000020105', '70000000-0000-0000-0000-000000020502',
   'El operador + concatena si uno de los dos es un string: "5" + 2 = "52".')
on conflict (pregunta_id) do update set
  opcion_correcta_id = excluded.opcion_correcta_id,
  explicacion        = excluded.explicacion;

-- -------------------------------------------------------------
-- PREGUNTAS · CIERRE DIFÍCIL
-- -------------------------------------------------------------
insert into public.desafio_preguntas (
  id, desafio_id, orden, enunciado, codigo, dificultad
) values
  ('60000000-0000-0000-0000-000000030101', '50000000-0000-0000-0000-000000000003', 1,
   '¿Qué imprime [10, 20, 30].reduce((a, b) => a + b, 0)?', '[10, 20, 30].reduce((a, b) => a + b, 0)', 'dificil'),
  ('60000000-0000-0000-0000-000000030102', '50000000-0000-0000-0000-000000000003', 2,
   '¿Qué es un closure?', null, 'dificil'),
  ('60000000-0000-0000-0000-000000030103', '50000000-0000-0000-0000-000000000003', 3,
   '¿Qué implica marcar una función con async?', null, 'dificil'),
  ('60000000-0000-0000-0000-000000030104', '50000000-0000-0000-0000-000000000003', 4,
   '¿Cuál es el resultado de 2 ** 3 ** 2?', '2 ** 3 ** 2', 'dificil')
on conflict (id) do update set
  desafio_id = excluded.desafio_id,
  orden      = excluded.orden,
  enunciado  = excluded.enunciado,
  codigo     = excluded.codigo,
  dificultad = excluded.dificultad;

insert into public.desafio_opciones (id, pregunta_id, orden, texto) values
  ('70000000-0000-0000-0000-000000030101', '60000000-0000-0000-0000-000000030101', 1, '30'),
  ('70000000-0000-0000-0000-000000030102', '60000000-0000-0000-0000-000000030101', 2, '60'),
  ('70000000-0000-0000-0000-000000030103', '60000000-0000-0000-0000-000000030101', 3, '102030'),
  ('70000000-0000-0000-0000-000000030104', '60000000-0000-0000-0000-000000030101', 4, 'undefined'),
  ('70000000-0000-0000-0000-000000030201', '60000000-0000-0000-0000-000000030102', 1, 'Un bucle infinito'),
  ('70000000-0000-0000-0000-000000030202', '60000000-0000-0000-0000-000000030102', 2, 'Una función que recuerda el ámbito donde se creó'),
  ('70000000-0000-0000-0000-000000030203', '60000000-0000-0000-0000-000000030102', 3, 'Un objeto JSON'),
  ('70000000-0000-0000-0000-000000030204', '60000000-0000-0000-0000-000000030102', 4, 'Una promesa'),
  ('70000000-0000-0000-0000-000000030301', '60000000-0000-0000-0000-000000030103', 1, 'La vuelve síncrona'),
  ('70000000-0000-0000-0000-000000030302', '60000000-0000-0000-0000-000000030103', 2, 'Siempre devuelve una promesa'),
  ('70000000-0000-0000-0000-000000030303', '60000000-0000-0000-0000-000000030103', 3, 'La ejecuta dos veces'),
  ('70000000-0000-0000-0000-000000030304', '60000000-0000-0000-0000-000000030103', 4, 'La convierte en clase'),
  ('70000000-0000-0000-0000-000000030401', '60000000-0000-0000-0000-000000030104', 1, '64'),
  ('70000000-0000-0000-0000-000000030402', '60000000-0000-0000-0000-000000030104', 2, '512'),
  ('70000000-0000-0000-0000-000000030403', '60000000-0000-0000-0000-000000030104', 3, '12'),
  ('70000000-0000-0000-0000-000000030404', '60000000-0000-0000-0000-000000030104', 4, 'Error')
on conflict (id) do update set
  pregunta_id = excluded.pregunta_id,
  orden       = excluded.orden,
  texto       = excluded.texto;

insert into public.desafio_soluciones (pregunta_id, opcion_correcta_id, explicacion) values
  ('60000000-0000-0000-0000-000000030101', '70000000-0000-0000-0000-000000030102',
   'reduce suma los elementos: 10 + 20 + 30 = 60.'),
  ('60000000-0000-0000-0000-000000030102', '70000000-0000-0000-0000-000000030202',
   'Un closure conserva el acceso a las variables del ámbito donde se creó.'),
  ('60000000-0000-0000-0000-000000030103', '70000000-0000-0000-0000-000000030302',
   'Una función async siempre devuelve una promesa.'),
  ('60000000-0000-0000-0000-000000030104', '70000000-0000-0000-0000-000000030402',
   'La exponenciación es asociativa a la derecha: 2 ** (3 ** 2) = 2 ** 9 = 512.')
on conflict (pregunta_id) do update set
  opcion_correcta_id = excluded.opcion_correcta_id,
  explicacion        = excluded.explicacion;

-- -------------------------------------------------------------
-- PREGUNTAS · PRUEBA NORMAL (la opción 1 es la correcta)
-- -------------------------------------------------------------
insert into public.desafio_preguntas (
  id, desafio_id, orden, enunciado, codigo, dificultad
) values
  ('60000000-0000-0000-0000-000000910101', '50000000-0000-0000-0000-000000000101', 1,
   'Prueba: ¿cuánto es 2 + 2?', null, 'facil'),
  ('60000000-0000-0000-0000-000000910102', '50000000-0000-0000-0000-000000000101', 2,
   'Prueba: ¿cuánto es 3 * 3?', null, 'facil'),
  ('60000000-0000-0000-0000-000000910103', '50000000-0000-0000-0000-000000000101', 3,
   'Prueba: ¿cuál de estos valores es un string?', null, 'facil'),
  ('60000000-0000-0000-0000-000000910104', '50000000-0000-0000-0000-000000000101', 4,
   'Prueba: ¿qué devuelve !false?', '!false', 'facil')
on conflict (id) do update set
  desafio_id = excluded.desafio_id,
  orden      = excluded.orden,
  enunciado  = excluded.enunciado,
  codigo     = excluded.codigo,
  dificultad = excluded.dificultad;

insert into public.desafio_opciones (id, pregunta_id, orden, texto) values
  ('70000000-0000-0000-0000-000000910101', '60000000-0000-0000-0000-000000910101', 1, '4'),
  ('70000000-0000-0000-0000-000000910102', '60000000-0000-0000-0000-000000910101', 2, '3'),
  ('70000000-0000-0000-0000-000000910103', '60000000-0000-0000-0000-000000910101', 3, '5'),
  ('70000000-0000-0000-0000-000000910104', '60000000-0000-0000-0000-000000910101', 4, '22'),
  ('70000000-0000-0000-0000-000000910201', '60000000-0000-0000-0000-000000910102', 1, '9'),
  ('70000000-0000-0000-0000-000000910202', '60000000-0000-0000-0000-000000910102', 2, '6'),
  ('70000000-0000-0000-0000-000000910203', '60000000-0000-0000-0000-000000910102', 3, '12'),
  ('70000000-0000-0000-0000-000000910204', '60000000-0000-0000-0000-000000910102', 4, '33'),
  ('70000000-0000-0000-0000-000000910301', '60000000-0000-0000-0000-000000910103', 1, "'hola'"),
  ('70000000-0000-0000-0000-000000910302', '60000000-0000-0000-0000-000000910103', 2, '42'),
  ('70000000-0000-0000-0000-000000910303', '60000000-0000-0000-0000-000000910103', 3, 'true'),
  ('70000000-0000-0000-0000-000000910304', '60000000-0000-0000-0000-000000910103', 4, '[1]'),
  ('70000000-0000-0000-0000-000000910401', '60000000-0000-0000-0000-000000910104', 1, 'true'),
  ('70000000-0000-0000-0000-000000910402', '60000000-0000-0000-0000-000000910104', 2, 'false'),
  ('70000000-0000-0000-0000-000000910403', '60000000-0000-0000-0000-000000910104', 3, '0'),
  ('70000000-0000-0000-0000-000000910404', '60000000-0000-0000-0000-000000910104', 4, 'undefined')
on conflict (id) do update set
  pregunta_id = excluded.pregunta_id,
  orden       = excluded.orden,
  texto       = excluded.texto;

insert into public.desafio_soluciones (pregunta_id, opcion_correcta_id, explicacion) values
  ('60000000-0000-0000-0000-000000910101', '70000000-0000-0000-0000-000000910101', '2 + 2 = 4.'),
  ('60000000-0000-0000-0000-000000910102', '70000000-0000-0000-0000-000000910201', '3 * 3 = 9.'),
  ('60000000-0000-0000-0000-000000910103', '70000000-0000-0000-0000-000000910301', 'Los textos entre comillas son strings.'),
  ('60000000-0000-0000-0000-000000910104', '70000000-0000-0000-0000-000000910401', 'La negación de false es true.')
on conflict (pregunta_id) do update set
  opcion_correcta_id = excluded.opcion_correcta_id,
  explicacion        = excluded.explicacion;

-- -------------------------------------------------------------
-- PREGUNTAS · PRUEBA VENCIDA (la opción 1 es la correcta)
-- -------------------------------------------------------------
insert into public.desafio_preguntas (
  id, desafio_id, orden, enunciado, codigo, dificultad
) values
  ('60000000-0000-0000-0000-000000920101', '50000000-0000-0000-0000-000000000102', 1,
   'Vencida: ¿cuánto es 1 + 1?', null, 'facil'),
  ('60000000-0000-0000-0000-000000920102', '50000000-0000-0000-0000-000000000102', 2,
   'Vencida: ¿cuánto es 5 - 2?', null, 'facil')
on conflict (id) do update set
  desafio_id = excluded.desafio_id,
  orden      = excluded.orden,
  enunciado  = excluded.enunciado,
  codigo     = excluded.codigo,
  dificultad = excluded.dificultad;

insert into public.desafio_opciones (id, pregunta_id, orden, texto) values
  ('70000000-0000-0000-0000-000000920101', '60000000-0000-0000-0000-000000920101', 1, '2'),
  ('70000000-0000-0000-0000-000000920102', '60000000-0000-0000-0000-000000920101', 2, '1'),
  ('70000000-0000-0000-0000-000000920103', '60000000-0000-0000-0000-000000920101', 3, '3'),
  ('70000000-0000-0000-0000-000000920104', '60000000-0000-0000-0000-000000920101', 4, '11'),
  ('70000000-0000-0000-0000-000000920201', '60000000-0000-0000-0000-000000920102', 1, '3'),
  ('70000000-0000-0000-0000-000000920202', '60000000-0000-0000-0000-000000920102', 2, '2'),
  ('70000000-0000-0000-0000-000000920203', '60000000-0000-0000-0000-000000920102', 3, '7'),
  ('70000000-0000-0000-0000-000000920204', '60000000-0000-0000-0000-000000920102', 4, '52')
on conflict (id) do update set
  pregunta_id = excluded.pregunta_id,
  orden       = excluded.orden,
  texto       = excluded.texto;

insert into public.desafio_soluciones (pregunta_id, opcion_correcta_id, explicacion) values
  ('60000000-0000-0000-0000-000000920101', '70000000-0000-0000-0000-000000920101', '1 + 1 = 2.'),
  ('60000000-0000-0000-0000-000000920102', '70000000-0000-0000-0000-000000920201', '5 - 2 = 3.')
on conflict (pregunta_id) do update set
  opcion_correcta_id = excluded.opcion_correcta_id,
  explicacion        = excluded.explicacion;

-- -------------------------------------------------------------
-- PREGUNTAS · PRUEBA DE UN INTENTO (la opción 1 es la correcta)
-- -------------------------------------------------------------
insert into public.desafio_preguntas (
  id, desafio_id, orden, enunciado, codigo, dificultad
) values
  ('60000000-0000-0000-0000-000000930101', '50000000-0000-0000-0000-000000000103', 1,
   'Un intento: ¿cuánto es 4 + 4?', null, 'facil'),
  ('60000000-0000-0000-0000-000000930102', '50000000-0000-0000-0000-000000000103', 2,
   'Un intento: ¿cuánto es 10 / 2?', null, 'facil')
on conflict (id) do update set
  desafio_id = excluded.desafio_id,
  orden      = excluded.orden,
  enunciado  = excluded.enunciado,
  codigo     = excluded.codigo,
  dificultad = excluded.dificultad;

insert into public.desafio_opciones (id, pregunta_id, orden, texto) values
  ('70000000-0000-0000-0000-000000930101', '60000000-0000-0000-0000-000000930101', 1, '8'),
  ('70000000-0000-0000-0000-000000930102', '60000000-0000-0000-0000-000000930101', 2, '7'),
  ('70000000-0000-0000-0000-000000930103', '60000000-0000-0000-0000-000000930101', 3, '9'),
  ('70000000-0000-0000-0000-000000930104', '60000000-0000-0000-0000-000000930101', 4, '44'),
  ('70000000-0000-0000-0000-000000930201', '60000000-0000-0000-0000-000000930102', 1, '5'),
  ('70000000-0000-0000-0000-000000930202', '60000000-0000-0000-0000-000000930102', 2, '2'),
  ('70000000-0000-0000-0000-000000930203', '60000000-0000-0000-0000-000000930102', 3, '10'),
  ('70000000-0000-0000-0000-000000930204', '60000000-0000-0000-0000-000000930102', 4, '20')
on conflict (id) do update set
  pregunta_id = excluded.pregunta_id,
  orden       = excluded.orden,
  texto       = excluded.texto;

insert into public.desafio_soluciones (pregunta_id, opcion_correcta_id, explicacion) values
  ('60000000-0000-0000-0000-000000930101', '70000000-0000-0000-0000-000000930101', '4 + 4 = 8.'),
  ('60000000-0000-0000-0000-000000930102', '70000000-0000-0000-0000-000000930201', '10 / 2 = 5.')
on conflict (pregunta_id) do update set
  opcion_correcta_id = excluded.opcion_correcta_id,
  explicacion        = excluded.explicacion;
