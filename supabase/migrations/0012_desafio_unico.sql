-- =============================================================
-- CodeLingua · 0012_desafio_unico.sql
-- Un solo desafío en la expo, con dificultad creciente y preguntas rotativas.
--
--   - Nuevo desafío "Gran desafío CodeLingua": 20 preguntas por partida,
--     4 fáciles, 8 intermedias y 8 difíciles, siempre en ese orden.
--   - El banco tiene 38 preguntas (10 fáciles, 14 intermedias y 14 difíciles):
--     las 14 de los tres desafíos anteriores más 24 nuevas.
--   - En cada intento se sortean preguntas distintas: se prefieren las que
--     el participante todavía no vio en intentos anteriores.
--   - Los tres desafíos anteriores quedan cerrados (sus partidas y su ranking
--     se conservan).
--
-- Los cupos por dificultad son columnas nuevas de `desafios`
-- (cupo_facil, cupo_intermedio, cupo_dificil). Si un desafío no define cupos
-- se usan todas sus preguntas, como antes (así funcionan los desafíos de
-- prueba). Ejecutable varias veces.
-- =============================================================

alter table public.desafios add column if not exists cupo_facil integer
  check (cupo_facil is null or cupo_facil >= 0);
alter table public.desafios add column if not exists cupo_intermedio integer
  check (cupo_intermedio is null or cupo_intermedio >= 0);
alter table public.desafios add column if not exists cupo_dificil integer
  check (cupo_dificil is null or cupo_dificil >= 0);

comment on column public.desafios.cupo_facil is
  'Preguntas fáciles que se sortean por partida (null = no se sortea).';

-- Dificultad "progresivo": el desafío mezcla los tres niveles.
alter table public.desafios drop constraint if exists desafios_dificultad_check;
alter table public.desafios add constraint desafios_dificultad_check
  check (dificultad in ('facil', 'intermedio', 'dificil', 'progresivo'));

-- -------------------------------------------------------------
-- DESAFÍO ÚNICO (se crea en borrador y se publica al final)
-- -------------------------------------------------------------
insert into public.desafios (
  id, evento_id, slug, titulo, descripcion, dificultad,
  duracion_segundos, puntos_por_acierto, intentos_permitidos,
  tolerancia_segundos, es_prueba, estado, orden,
  cupo_facil, cupo_intermedio, cupo_dificil
) values (
  '50000000-0000-0000-0000-000000000010',
  '40000000-0000-0000-0000-000000000001',
  'gran-desafio',
  'Gran desafío CodeLingua',
  'Veinte preguntas que van subiendo de dificultad: 4 fáciles, 8 intermedias y 8 difíciles. En cada intento te tocan preguntas distintas del banco.',
  'progresivo', 600, 10, 3, 30, false, 'borrador', 1,
  4, 8, 8
)
on conflict (id) do nothing;

-- Preguntas nuevas del banco
insert into public.desafio_preguntas (id, desafio_id, orden, enunciado, codigo, dificultad) values
  ('60000000-0000-0000-0000-000000004101', '50000000-0000-0000-0000-000000000010', 6, '¿Cómo se escribe un comentario de una línea en JavaScript?', null, 'facil'),
  ('60000000-0000-0000-0000-000000004102', '50000000-0000-0000-0000-000000000010', 7, '¿Qué muestra este código?', 'console.log(2 + 3);', 'facil'),
  ('60000000-0000-0000-0000-000000004103', '50000000-0000-0000-0000-000000000010', 8, '¿Cuál de estos valores es de tipo booleano?', null, 'facil'),
  ('60000000-0000-0000-0000-000000004104', '50000000-0000-0000-0000-000000000010', 9, '¿Cuál es un nombre de variable válido en JavaScript?', null, 'facil'),
  ('60000000-0000-0000-0000-000000004105', '50000000-0000-0000-0000-000000000010', 10, '¿Cuántos elementos tiene este arreglo?', 'const letras = [''a'', ''b'', ''c''];
letras.length', 'facil'),
  ('60000000-0000-0000-0000-000000004201', '50000000-0000-0000-0000-000000000010', 16, '¿Qué devuelve esta expresión?', '''hola''.toUpperCase()', 'intermedio'),
  ('60000000-0000-0000-0000-000000004202', '50000000-0000-0000-0000-000000000010', 17, '¿Cuál es el índice del primer elemento de un arreglo?', null, 'intermedio'),
  ('60000000-0000-0000-0000-000000004203', '50000000-0000-0000-0000-000000000010', 18, '¿Qué imprime este código?', 'let n = 0;
for (let i = 1; i <= 3; i++) {
  n += i;
}
console.log(n);', 'intermedio'),
  ('60000000-0000-0000-0000-000000004204', '50000000-0000-0000-0000-000000000010', 19, '¿Qué hace JSON.stringify(obj)?', null, 'intermedio'),
  ('60000000-0000-0000-0000-000000004205', '50000000-0000-0000-0000-000000000010', 20, '¿Qué devuelve typeof null?', 'typeof null', 'intermedio'),
  ('60000000-0000-0000-0000-000000004206', '50000000-0000-0000-0000-000000000010', 21, '¿Qué imprime este código?', 'const a = [1, 2, 3];
const b = a.slice(1);
console.log(b);', 'intermedio'),
  ('60000000-0000-0000-0000-000000004207', '50000000-0000-0000-0000-000000000010', 22, '¿Cuánto vale 10 % 3?', '10 % 3', 'intermedio'),
  ('60000000-0000-0000-0000-000000004208', '50000000-0000-0000-0000-000000000010', 23, '¿Qué evento se dispara al hacer clic sobre un elemento?', null, 'intermedio'),
  ('60000000-0000-0000-0000-000000004209', '50000000-0000-0000-0000-000000000010', 24, '¿Qué imprime este código?', 'const x = 5;
if (x > 3 && x < 5) {
  console.log(''A'');
} else {
  console.log(''B'');
}', 'intermedio'),
  ('60000000-0000-0000-0000-000000004301', '50000000-0000-0000-0000-000000000010', 29, '¿Qué imprime este código?', 'console.log(typeof NaN);', 'dificil'),
  ('60000000-0000-0000-0000-000000004302', '50000000-0000-0000-0000-000000000010', 30, '¿Qué imprime este código?', 'console.log(0.1 + 0.2 === 0.3);', 'dificil'),
  ('60000000-0000-0000-0000-000000004303', '50000000-0000-0000-0000-000000000010', 31, '¿Qué imprime este código?', 'let x = 1;
{
  let x = 2;
}
console.log(x);', 'dificil'),
  ('60000000-0000-0000-0000-000000004304', '50000000-0000-0000-0000-000000000010', 32, '¿Qué resultado da este código?', 'console.log([] + []);', 'dificil'),
  ('60000000-0000-0000-0000-000000004305', '50000000-0000-0000-0000-000000000010', 33, '¿Qué muestra este código?', 'console.log([1, 2, 3].indexOf(4));', 'dificil'),
  ('60000000-0000-0000-0000-000000004306', '50000000-0000-0000-0000-000000000010', 34, '¿En qué orden se imprimen las letras?', 'console.log(''A'');
setTimeout(() => console.log(''B''), 0);
console.log(''C'');', 'dificil'),
  ('60000000-0000-0000-0000-000000004307', '50000000-0000-0000-0000-000000000010', 35, '¿Qué imprime este código?', 'console.log(Boolean(''false''));', 'dificil'),
  ('60000000-0000-0000-0000-000000004308', '50000000-0000-0000-0000-000000000010', 36, '¿Qué imprime este código?', 'const o = { a: 1 };
const p = o;
p.a = 9;
console.log(o.a);', 'dificil'),
  ('60000000-0000-0000-0000-000000004309', '50000000-0000-0000-0000-000000000010', 37, '¿Qué complejidad tiene buscar un valor recorriendo de a uno un arreglo desordenado?', null, 'dificil'),
  ('60000000-0000-0000-0000-000000004310', '50000000-0000-0000-0000-000000000010', 38, '¿Qué imprime este código?', 'console.log(1 < 2 < 3, 3 > 2 > 1);', 'dificil')
on conflict (id) do nothing;

insert into public.desafio_opciones (id, pregunta_id, orden, texto) values
  ('70000000-0000-0000-0000-000000510101', '60000000-0000-0000-0000-000000004101', 1, '# comentario'),
  ('70000000-0000-0000-0000-000000510102', '60000000-0000-0000-0000-000000004101', 2, '// comentario'),
  ('70000000-0000-0000-0000-000000510103', '60000000-0000-0000-0000-000000004101', 3, '-- comentario'),
  ('70000000-0000-0000-0000-000000510104', '60000000-0000-0000-0000-000000004101', 4, '<!-- comentario -->'),
  ('70000000-0000-0000-0000-000000510201', '60000000-0000-0000-0000-000000004102', 1, '23'),
  ('70000000-0000-0000-0000-000000510202', '60000000-0000-0000-0000-000000004102', 2, '2 + 3'),
  ('70000000-0000-0000-0000-000000510203', '60000000-0000-0000-0000-000000004102', 3, 'Error'),
  ('70000000-0000-0000-0000-000000510204', '60000000-0000-0000-0000-000000004102', 4, '5'),
  ('70000000-0000-0000-0000-000000510301', '60000000-0000-0000-0000-000000004103', 1, 'true'),
  ('70000000-0000-0000-0000-000000510302', '60000000-0000-0000-0000-000000004103', 2, '"true"'),
  ('70000000-0000-0000-0000-000000510303', '60000000-0000-0000-0000-000000004103', 3, '1'),
  ('70000000-0000-0000-0000-000000510304', '60000000-0000-0000-0000-000000004103', 4, '"sí"'),
  ('70000000-0000-0000-0000-000000510401', '60000000-0000-0000-0000-000000004104', 1, '2nombre'),
  ('70000000-0000-0000-0000-000000510402', '60000000-0000-0000-0000-000000004104', 2, 'mi-nombre'),
  ('70000000-0000-0000-0000-000000510403', '60000000-0000-0000-0000-000000004104', 3, 'miNombre'),
  ('70000000-0000-0000-0000-000000510404', '60000000-0000-0000-0000-000000004104', 4, 'mi nombre'),
  ('70000000-0000-0000-0000-000000510501', '60000000-0000-0000-0000-000000004105', 1, '2'),
  ('70000000-0000-0000-0000-000000510502', '60000000-0000-0000-0000-000000004105', 2, '4'),
  ('70000000-0000-0000-0000-000000510503', '60000000-0000-0000-0000-000000004105', 3, '3'),
  ('70000000-0000-0000-0000-000000510504', '60000000-0000-0000-0000-000000004105', 4, 'undefined'),
  ('70000000-0000-0000-0000-000000520101', '60000000-0000-0000-0000-000000004201', 1, 'HOLA'),
  ('70000000-0000-0000-0000-000000520102', '60000000-0000-0000-0000-000000004201', 2, '"hola"'),
  ('70000000-0000-0000-0000-000000520103', '60000000-0000-0000-0000-000000004201', 3, 'undefined'),
  ('70000000-0000-0000-0000-000000520104', '60000000-0000-0000-0000-000000004201', 4, 'Error'),
  ('70000000-0000-0000-0000-000000520201', '60000000-0000-0000-0000-000000004202', 1, '1'),
  ('70000000-0000-0000-0000-000000520202', '60000000-0000-0000-0000-000000004202', 2, '-1'),
  ('70000000-0000-0000-0000-000000520203', '60000000-0000-0000-0000-000000004202', 3, 'Depende del tipo'),
  ('70000000-0000-0000-0000-000000520204', '60000000-0000-0000-0000-000000004202', 4, '0'),
  ('70000000-0000-0000-0000-000000520301', '60000000-0000-0000-0000-000000004203', 1, '3'),
  ('70000000-0000-0000-0000-000000520302', '60000000-0000-0000-0000-000000004203', 2, '6'),
  ('70000000-0000-0000-0000-000000520303', '60000000-0000-0000-0000-000000004203', 3, '5'),
  ('70000000-0000-0000-0000-000000520304', '60000000-0000-0000-0000-000000004203', 4, '10'),
  ('70000000-0000-0000-0000-000000520401', '60000000-0000-0000-0000-000000004204', 1, 'Convierte texto JSON en un objeto'),
  ('70000000-0000-0000-0000-000000520402', '60000000-0000-0000-0000-000000004204', 2, 'Convierte un objeto en texto JSON'),
  ('70000000-0000-0000-0000-000000520403', '60000000-0000-0000-0000-000000004204', 3, 'Ordena las claves del objeto'),
  ('70000000-0000-0000-0000-000000520404', '60000000-0000-0000-0000-000000004204', 4, 'Borra el objeto'),
  ('70000000-0000-0000-0000-000000520501', '60000000-0000-0000-0000-000000004205', 1, '"null"'),
  ('70000000-0000-0000-0000-000000520502', '60000000-0000-0000-0000-000000004205', 2, '"undefined"'),
  ('70000000-0000-0000-0000-000000520503', '60000000-0000-0000-0000-000000004205', 3, '"object"'),
  ('70000000-0000-0000-0000-000000520504', '60000000-0000-0000-0000-000000004205', 4, '"number"'),
  ('70000000-0000-0000-0000-000000520601', '60000000-0000-0000-0000-000000004206', 1, '[2, 3]'),
  ('70000000-0000-0000-0000-000000520602', '60000000-0000-0000-0000-000000004206', 2, '[1]'),
  ('70000000-0000-0000-0000-000000520603', '60000000-0000-0000-0000-000000004206', 3, '[1, 2]'),
  ('70000000-0000-0000-0000-000000520604', '60000000-0000-0000-0000-000000004206', 4, '[3]'),
  ('70000000-0000-0000-0000-000000520701', '60000000-0000-0000-0000-000000004207', 1, '3'),
  ('70000000-0000-0000-0000-000000520702', '60000000-0000-0000-0000-000000004207', 2, '0'),
  ('70000000-0000-0000-0000-000000520703', '60000000-0000-0000-0000-000000004207', 3, '3.33'),
  ('70000000-0000-0000-0000-000000520704', '60000000-0000-0000-0000-000000004207', 4, '1'),
  ('70000000-0000-0000-0000-000000520801', '60000000-0000-0000-0000-000000004208', 1, 'hover'),
  ('70000000-0000-0000-0000-000000520802', '60000000-0000-0000-0000-000000004208', 2, 'click'),
  ('70000000-0000-0000-0000-000000520803', '60000000-0000-0000-0000-000000004208', 3, 'press'),
  ('70000000-0000-0000-0000-000000520804', '60000000-0000-0000-0000-000000004208', 4, 'touchmove'),
  ('70000000-0000-0000-0000-000000520901', '60000000-0000-0000-0000-000000004209', 1, 'A'),
  ('70000000-0000-0000-0000-000000520902', '60000000-0000-0000-0000-000000004209', 2, 'A y B'),
  ('70000000-0000-0000-0000-000000520903', '60000000-0000-0000-0000-000000004209', 3, 'Nada'),
  ('70000000-0000-0000-0000-000000520904', '60000000-0000-0000-0000-000000004209', 4, 'B'),
  ('70000000-0000-0000-0000-000000530101', '60000000-0000-0000-0000-000000004301', 1, '"number"'),
  ('70000000-0000-0000-0000-000000530102', '60000000-0000-0000-0000-000000004301', 2, '"NaN"'),
  ('70000000-0000-0000-0000-000000530103', '60000000-0000-0000-0000-000000004301', 3, '"undefined"'),
  ('70000000-0000-0000-0000-000000530104', '60000000-0000-0000-0000-000000004301', 4, '"object"'),
  ('70000000-0000-0000-0000-000000530201', '60000000-0000-0000-0000-000000004302', 1, 'true'),
  ('70000000-0000-0000-0000-000000530202', '60000000-0000-0000-0000-000000004302', 2, 'undefined'),
  ('70000000-0000-0000-0000-000000530203', '60000000-0000-0000-0000-000000004302', 3, 'false'),
  ('70000000-0000-0000-0000-000000530204', '60000000-0000-0000-0000-000000004302', 4, 'Error'),
  ('70000000-0000-0000-0000-000000530301', '60000000-0000-0000-0000-000000004303', 1, '2'),
  ('70000000-0000-0000-0000-000000530302', '60000000-0000-0000-0000-000000004303', 2, 'undefined'),
  ('70000000-0000-0000-0000-000000530303', '60000000-0000-0000-0000-000000004303', 3, '1'),
  ('70000000-0000-0000-0000-000000530304', '60000000-0000-0000-0000-000000004303', 4, 'Error'),
  ('70000000-0000-0000-0000-000000530401', '60000000-0000-0000-0000-000000004304', 1, 'Un texto vacío'),
  ('70000000-0000-0000-0000-000000530402', '60000000-0000-0000-0000-000000004304', 2, '[]'),
  ('70000000-0000-0000-0000-000000530403', '60000000-0000-0000-0000-000000004304', 3, '0'),
  ('70000000-0000-0000-0000-000000530404', '60000000-0000-0000-0000-000000004304', 4, 'undefined'),
  ('70000000-0000-0000-0000-000000530501', '60000000-0000-0000-0000-000000004305', 1, '0'),
  ('70000000-0000-0000-0000-000000530502', '60000000-0000-0000-0000-000000004305', 2, 'undefined'),
  ('70000000-0000-0000-0000-000000530503', '60000000-0000-0000-0000-000000004305', 3, 'null'),
  ('70000000-0000-0000-0000-000000530504', '60000000-0000-0000-0000-000000004305', 4, '-1'),
  ('70000000-0000-0000-0000-000000530601', '60000000-0000-0000-0000-000000004306', 1, 'A, B, C'),
  ('70000000-0000-0000-0000-000000530602', '60000000-0000-0000-0000-000000004306', 2, 'A, C, B'),
  ('70000000-0000-0000-0000-000000530603', '60000000-0000-0000-0000-000000004306', 3, 'B, A, C'),
  ('70000000-0000-0000-0000-000000530604', '60000000-0000-0000-0000-000000004306', 4, 'C, A, B'),
  ('70000000-0000-0000-0000-000000530701', '60000000-0000-0000-0000-000000004307', 1, 'false'),
  ('70000000-0000-0000-0000-000000530702', '60000000-0000-0000-0000-000000004307', 2, 'true'),
  ('70000000-0000-0000-0000-000000530703', '60000000-0000-0000-0000-000000004307', 3, 'Error'),
  ('70000000-0000-0000-0000-000000530704', '60000000-0000-0000-0000-000000004307', 4, 'undefined'),
  ('70000000-0000-0000-0000-000000530801', '60000000-0000-0000-0000-000000004308', 1, '1'),
  ('70000000-0000-0000-0000-000000530802', '60000000-0000-0000-0000-000000004308', 2, 'undefined'),
  ('70000000-0000-0000-0000-000000530803', '60000000-0000-0000-0000-000000004308', 3, '9'),
  ('70000000-0000-0000-0000-000000530804', '60000000-0000-0000-0000-000000004308', 4, 'Error'),
  ('70000000-0000-0000-0000-000000530901', '60000000-0000-0000-0000-000000004309', 1, 'O(n)'),
  ('70000000-0000-0000-0000-000000530902', '60000000-0000-0000-0000-000000004309', 2, 'O(1)'),
  ('70000000-0000-0000-0000-000000530903', '60000000-0000-0000-0000-000000004309', 3, 'O(log n)'),
  ('70000000-0000-0000-0000-000000530904', '60000000-0000-0000-0000-000000004309', 4, 'O(n²)'),
  ('70000000-0000-0000-0000-000000531001', '60000000-0000-0000-0000-000000004310', 1, 'true true'),
  ('70000000-0000-0000-0000-000000531002', '60000000-0000-0000-0000-000000004310', 2, 'false true'),
  ('70000000-0000-0000-0000-000000531003', '60000000-0000-0000-0000-000000004310', 3, 'false false'),
  ('70000000-0000-0000-0000-000000531004', '60000000-0000-0000-0000-000000004310', 4, 'true false')
on conflict (id) do nothing;

insert into public.desafio_soluciones (pregunta_id, opcion_correcta_id, explicacion) values
  ('60000000-0000-0000-0000-000000004101', '70000000-0000-0000-0000-000000510102', 'En JavaScript los comentarios de una línea empiezan con //.'),
  ('60000000-0000-0000-0000-000000004102', '70000000-0000-0000-0000-000000510204', 'Con números el operador + suma: 2 + 3 = 5.'),
  ('60000000-0000-0000-0000-000000004103', '70000000-0000-0000-0000-000000510301', 'true (sin comillas) es un booleano. Entre comillas sería un string.'),
  ('60000000-0000-0000-0000-000000004104', '70000000-0000-0000-0000-000000510403', 'Los nombres no pueden empezar con número ni llevar guiones o espacios.'),
  ('60000000-0000-0000-0000-000000004105', '70000000-0000-0000-0000-000000510503', 'length devuelve la cantidad de elementos: tres.'),
  ('60000000-0000-0000-0000-000000004201', '70000000-0000-0000-0000-000000520101', 'toUpperCase() devuelve el texto en mayúsculas.'),
  ('60000000-0000-0000-0000-000000004202', '70000000-0000-0000-0000-000000520204', 'Los índices de los arreglos empiezan en 0.'),
  ('60000000-0000-0000-0000-000000004203', '70000000-0000-0000-0000-000000520302', 'Suma 1 + 2 + 3 = 6.'),
  ('60000000-0000-0000-0000-000000004204', '70000000-0000-0000-0000-000000520402', 'stringify serializa el objeto como texto; JSON.parse hace lo inverso.'),
  ('60000000-0000-0000-0000-000000004205', '70000000-0000-0000-0000-000000520503', 'Es una rareza histórica del lenguaje: typeof null devuelve "object".'),
  ('60000000-0000-0000-0000-000000004206', '70000000-0000-0000-0000-000000520601', 'slice(1) copia desde el índice 1 hasta el final.'),
  ('60000000-0000-0000-0000-000000004207', '70000000-0000-0000-0000-000000520704', 'El operador % devuelve el resto de la división: 10 = 3 · 3 + 1.'),
  ('60000000-0000-0000-0000-000000004208', '70000000-0000-0000-0000-000000520802', 'El evento click se dispara al hacer clic o tocar el elemento.'),
  ('60000000-0000-0000-0000-000000004209', '70000000-0000-0000-0000-000000520904', 'x < 5 es falso, por lo que && es falso y se ejecuta el else.'),
  ('60000000-0000-0000-0000-000000004301', '70000000-0000-0000-0000-000000530101', 'NaN significa "no es un número", pero su tipo es number.'),
  ('60000000-0000-0000-0000-000000004302', '70000000-0000-0000-0000-000000530203', 'Los decimales se guardan en binario y 0.1 + 0.2 da 0.30000000000000004.'),
  ('60000000-0000-0000-0000-000000004303', '70000000-0000-0000-0000-000000530303', 'let tiene alcance de bloque: la x de adentro es otra variable.'),
  ('60000000-0000-0000-0000-000000004304', '70000000-0000-0000-0000-000000530401', 'Cada arreglo vacío se convierte en "" y "" + "" es un texto vacío.'),
  ('60000000-0000-0000-0000-000000004305', '70000000-0000-0000-0000-000000530504', 'indexOf devuelve -1 cuando el elemento no está en el arreglo.'),
  ('60000000-0000-0000-0000-000000004306', '70000000-0000-0000-0000-000000530602', 'setTimeout deja la función en la cola: se ejecuta después del código síncrono.'),
  ('60000000-0000-0000-0000-000000004307', '70000000-0000-0000-0000-000000530702', 'Cualquier texto no vacío es verdadero, incluso "false".'),
  ('60000000-0000-0000-0000-000000004308', '70000000-0000-0000-0000-000000530803', 'p y o apuntan al mismo objeto: cambiar uno cambia el otro.'),
  ('60000000-0000-0000-0000-000000004309', '70000000-0000-0000-0000-000000530901', 'En el peor caso hay que revisar los n elementos: crece de forma lineal.'),
  ('60000000-0000-0000-0000-000000004310', '70000000-0000-0000-0000-000000531004', '1 < 2 < 3 = true < 3 = true; 3 > 2 > 1 = true > 1 = false.')
on conflict (pregunta_id) do nothing;

-- Las 14 preguntas de los desafíos anteriores pasan al banco único.
-- Las partidas viejas conservan sus preguntas (se referencian por id).
update public.desafio_preguntas set desafio_id = '50000000-0000-0000-0000-000000000010', orden = 1 where id = '60000000-0000-0000-0000-000000010101';
update public.desafio_preguntas set desafio_id = '50000000-0000-0000-0000-000000000010', orden = 2 where id = '60000000-0000-0000-0000-000000010102';
update public.desafio_preguntas set desafio_id = '50000000-0000-0000-0000-000000000010', orden = 3 where id = '60000000-0000-0000-0000-000000010103';
update public.desafio_preguntas set desafio_id = '50000000-0000-0000-0000-000000000010', orden = 4 where id = '60000000-0000-0000-0000-000000010104';
update public.desafio_preguntas set desafio_id = '50000000-0000-0000-0000-000000000010', orden = 5 where id = '60000000-0000-0000-0000-000000010105';
update public.desafio_preguntas set desafio_id = '50000000-0000-0000-0000-000000000010', orden = 11 where id = '60000000-0000-0000-0000-000000020101';
update public.desafio_preguntas set desafio_id = '50000000-0000-0000-0000-000000000010', orden = 12 where id = '60000000-0000-0000-0000-000000020102';
update public.desafio_preguntas set desafio_id = '50000000-0000-0000-0000-000000000010', orden = 13 where id = '60000000-0000-0000-0000-000000020103';
update public.desafio_preguntas set desafio_id = '50000000-0000-0000-0000-000000000010', orden = 14 where id = '60000000-0000-0000-0000-000000020104';
update public.desafio_preguntas set desafio_id = '50000000-0000-0000-0000-000000000010', orden = 15 where id = '60000000-0000-0000-0000-000000020105';
update public.desafio_preguntas set desafio_id = '50000000-0000-0000-0000-000000000010', orden = 25 where id = '60000000-0000-0000-0000-000000030101';
update public.desafio_preguntas set desafio_id = '50000000-0000-0000-0000-000000000010', orden = 26 where id = '60000000-0000-0000-0000-000000030102';
update public.desafio_preguntas set desafio_id = '50000000-0000-0000-0000-000000000010', orden = 27 where id = '60000000-0000-0000-0000-000000030103';
update public.desafio_preguntas set desafio_id = '50000000-0000-0000-0000-000000000010', orden = 28 where id = '60000000-0000-0000-0000-000000030104';

-- Publicación: el desafío anterior queda cerrado y el nuevo se publica.
update public.desafios set estado = 'cerrado'
where id in (
  '50000000-0000-0000-0000-000000000001',
  '50000000-0000-0000-0000-000000000002',
  '50000000-0000-0000-0000-000000000003'
);
update public.desafios set estado = 'publicado' where id = '50000000-0000-0000-0000-000000000010';

-- Nombre actual del evento.
update public.eventos set titulo = 'Expo CodeLingua 2026'
where id = '40000000-0000-0000-0000-000000000001' and titulo <> 'Expo CodeLingua 2026';

-- -------------------------------------------------------------
-- iniciar_partida: sorteo por dificultad con rotación entre intentos
-- -------------------------------------------------------------
create or replace function public.iniciar_partida(
  p_desafio uuid,
  p_clave   text
)
returns table (
  partida             uuid,
  desafio             uuid,
  estado              text,
  total_preguntas     integer,
  puntos_por_acierto  integer,
  duracion_segundos   integer,
  tolerancia_segundos integer,
  iniciado_en         timestamptz,
  expira_en           timestamptz,
  intentos_usados     integer,
  intentos_permitidos integer,
  reutilizado         boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid        uuid := auth.uid();
  v_desafio    public.desafios;
  v_existente  public.partidas;
  v_partida    public.partidas;
  v_total      integer;
  v_usados     integer;
  v_limite     integer;
  v_muestreo   boolean;
begin
  if v_uid is null then
    raise exception 'PR_AUTH_REQUIRED'
      using hint = 'Se necesita una sesión para jugar un desafío.';
  end if;

  if p_clave is null or char_length(p_clave) < 8 or char_length(p_clave) > 100 then
    raise exception 'PR_INVALID_KEY'
      using hint = 'La clave de idempotencia no es válida.';
  end if;

  -- Serializa los inicios del mismo participante en el mismo desafío para
  -- que dos peticiones simultáneas no superen el límite de intentos.
  perform pg_advisory_xact_lock(
    hashtext(v_uid::text),
    hashtext(p_desafio::text)
  );

  select * into v_desafio
  from public.desafios
  where id = p_desafio;

  if not found then
    raise exception 'PR_DESAFIO_NOT_FOUND'
      using hint = 'El desafío no existe.';
  end if;

  -- La misma clave devuelve la MISMA partida, aunque el desafío ya haya
  -- cerrado: es un reintento de red o un doble toque, no un intento nuevo.
  select * into v_existente
  from public.partidas
  where participante_id = v_uid
    and clave_idempotencia = p_clave;

  if found then
    select count(*) into v_usados
    from public.partidas
    where participante_id = v_uid
      and desafio_id = v_existente.desafio_id;

    select d.intentos_permitidos into v_limite
    from public.desafios d
    where d.id = v_existente.desafio_id;

    return query
      select v_existente.id, v_existente.desafio_id, v_existente.estado,
             v_existente.total_preguntas, v_existente.puntos_por_acierto,
             v_existente.duracion_segundos, v_existente.tolerancia_segundos,
             v_existente.iniciado_en, v_existente.expira_en,
             v_usados, v_limite, true;
    return;
  end if;

  if v_desafio.estado <> 'publicado' or not exists (
    select 1 from public.eventos e
    where e.id = v_desafio.evento_id
      and e.estado = 'publicado'
      and now() between e.inicia_en and e.termina_en
  ) then
    raise exception 'PR_DESAFIO_CERRADO'
      using hint = 'El desafío no está abierto en este momento.';
  end if;

  select count(*) into v_total
  from public.desafio_preguntas
  where desafio_id = p_desafio;

  if v_total = 0 then
    raise exception 'PR_DESAFIO_SIN_PREGUNTAS'
      using hint = 'El desafío no tiene preguntas cargadas.';
  end if;

  -- Todas las preguntas deben tener una solución que apunte a una de sus
  -- propias opciones; si no, la partida no se puede corregir.
  if exists (
    select 1
    from public.desafio_preguntas dp
    where dp.desafio_id = p_desafio
      and not exists (
        select 1
        from public.desafio_soluciones s
        join public.desafio_opciones o on o.id = s.opcion_correcta_id
        where s.pregunta_id = dp.id
          and o.pregunta_id = dp.id
      )
  ) then
    raise exception 'PR_DESAFIO_INCOMPLETO'
      using hint = 'El desafío tiene preguntas sin solución válida.';
  end if;

  -- Desafíos con cupos por dificultad: en cada partida se sortea un
  -- subconjunto del banco (ver más abajo). Sin cupos se usan todas.
  v_muestreo := v_desafio.cupo_facil is not null
             or v_desafio.cupo_intermedio is not null
             or v_desafio.cupo_dificil is not null;

  if v_muestreo then
    select coalesce(sum(least(q.n, q.cupo)), 0) into v_total
    from (
      select dp.dificultad,
             count(*) as n,
             case dp.dificultad
               when 'facil' then coalesce(v_desafio.cupo_facil, 0)
               when 'intermedio' then coalesce(v_desafio.cupo_intermedio, 0)
               else coalesce(v_desafio.cupo_dificil, 0)
             end as cupo
      from public.desafio_preguntas dp
      where dp.desafio_id = p_desafio
      group by dp.dificultad
    ) q;
  end if;

  select count(*) into v_usados
  from public.partidas
  where participante_id = v_uid
    and desafio_id = p_desafio;

  if v_usados >= v_desafio.intentos_permitidos then
    raise exception 'PR_INTENTOS_AGOTADOS'
      using hint = 'Ya usaste todos los intentos permitidos en este desafío.';
  end if;

  begin
    insert into public.partidas (
      participante_id, desafio_id, clave_idempotencia, total_preguntas,
      puntos_por_acierto, duracion_segundos, tolerancia_segundos, expira_en
    )
    values (
      v_uid, p_desafio, p_clave, v_total,
      v_desafio.puntos_por_acierto, v_desafio.duracion_segundos,
      v_desafio.tolerancia_segundos,
      now() + make_interval(secs => v_desafio.duracion_segundos)
    )
    returning * into v_partida;
  exception
    when unique_violation then
      -- Otra petición con la misma clave ganó la carrera: se devuelve esa.
      select * into v_partida
      from public.partidas
      where participante_id = v_uid
        and clave_idempotencia = p_clave;

      select count(*) into v_usados
      from public.partidas
      where participante_id = v_uid
        and desafio_id = v_partida.desafio_id;

      select d.intentos_permitidos into v_limite
      from public.desafios d
      where d.id = v_partida.desafio_id;

      return query
        select v_partida.id, v_partida.desafio_id, v_partida.estado,
               v_partida.total_preguntas, v_partida.puntos_por_acierto,
               v_partida.duracion_segundos, v_partida.tolerancia_segundos,
               v_partida.iniciado_en, v_partida.expira_en,
               v_usados, v_limite, true;
      return;
  end;

  -- Foto de las preguntas asignadas a esta partida.
  if v_muestreo then
    -- Sorteo con dificultad creciente: primero las fáciles, después las
    -- intermedias y al final las difíciles. Dentro de cada nivel se prefieren
    -- las preguntas que este participante todavía no vio en intentos
    -- anteriores, así cada intento rota las preguntas.
    insert into public.partida_preguntas (partida_id, desafio_pregunta_id, orden)
    select v_partida.id, e.id, row_number() over (order by e.nivel, e.azar)
    from (
      select c.id, c.nivel, random() as azar
      from (
        select dp.id,
               dp.dificultad,
               case dp.dificultad when 'facil' then 1 when 'intermedio' then 2 else 3 end as nivel,
               row_number() over (
                 partition by dp.dificultad
                 order by exists (
                            select 1
                            from public.partida_preguntas pp
                            join public.partidas pa on pa.id = pp.partida_id
                            where pa.participante_id = v_uid
                              and pa.desafio_id = p_desafio
                              and pp.desafio_pregunta_id = dp.id
                          ),
                          random()
               ) as rn
        from public.desafio_preguntas dp
        where dp.desafio_id = p_desafio
      ) c
      where c.rn <= case c.dificultad
              when 'facil' then coalesce(v_desafio.cupo_facil, 0)
              when 'intermedio' then coalesce(v_desafio.cupo_intermedio, 0)
              else coalesce(v_desafio.cupo_dificil, 0)
            end
    ) e;
  else
    insert into public.partida_preguntas (partida_id, desafio_pregunta_id, orden)
    select v_partida.id, dp.id, dp.orden
    from public.desafio_preguntas dp
    where dp.desafio_id = p_desafio
    order by dp.orden;
  end if;

  return query
    select v_partida.id, v_partida.desafio_id, v_partida.estado,
           v_partida.total_preguntas, v_partida.puntos_por_acierto,
           v_partida.duracion_segundos, v_partida.tolerancia_segundos,
           v_partida.iniciado_en, v_partida.expira_en,
           v_usados + 1, v_desafio.intentos_permitidos, false;
end;
$$;
