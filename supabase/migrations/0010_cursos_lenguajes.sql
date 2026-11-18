-- =============================================================
-- CodeLingua · 0010_cursos_lenguajes.sql
-- Cinco cursos nuevos además de JavaScript: Python, PHP, Java, C# y C++.
--   - Cada curso tiene 5 unidades; la unidad 1 está disponible con
--     2 lecciones x 3 preguntas (4 opciones cada una y su solución).
--   - La opción correcta varía entre A, B, C y D (no es siempre la primera).
--
-- Ejecutable varias veces: usa ON CONFLICT DO NOTHING.
-- =============================================================

-- -------------------------------------------------------------
-- PYTHON DESDE CERO
-- -------------------------------------------------------------
insert into public.cursos (id, slug, titulo, descripcion, nivel, estado, color, icono, orden) values
  ('00000000-0000-0000-0000-000000000002', 'python', 'Python desde cero', 'Aprende el lenguaje más amigable para empezar: automatización, datos e inteligencia artificial. Esta entrega incluye la unidad 1 con dos lecciones completas.', 'Principiante', 'disponible', '#3776ab', 'terminal', 2)
on conflict (id) do nothing;

insert into public.unidades (id, curso_id, orden, titulo, descripcion, icono, disponible) values
  ('10000002-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 1, 'Fundamentos de Python', 'Qué es Python, cómo mostrar mensajes y cómo guardar información en variables.', 'code', true),
  ('10000002-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', 2, 'Condicionales', 'Tomar decisiones con if, elif y else. Pendiente de publicación.', 'call_split', false),
  ('10000002-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000002', 3, 'Bucles y repetición', 'Repetir acciones con for y while. Pendiente de publicación.', 'loop', false),
  ('10000002-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000002', 4, 'Funciones', 'Código reutilizable con def, parámetros y return. Pendiente de publicación.', 'functions', false),
  ('10000002-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000002', 5, 'Listas y diccionarios', 'Guardar colecciones de datos. Pendiente de publicación.', 'data_object', false)
on conflict (id) do nothing;

insert into public.lecciones (id, unidad_id, orden, titulo, explicacion, ejemplo_codigo) values
  ('20000002-0000-0000-0000-000000000001', '10000002-0000-0000-0000-000000000001', 1, '¿Qué es Python?', 'Python es un lenguaje de propósito general con una sintaxis clara y fácil de leer. Se usa en automatización, ciencia de datos, desarrollo web e inteligencia artificial. Es interpretado: el intérprete ejecuta el programa línea por línea. La función print() muestra un mensaje en pantalla y todo lo que empieza con # es un comentario que el intérprete ignora.', 'print(''Hola, mundo'')

# Esto es un comentario: no se ejecuta'),
  ('20000002-0000-0000-0000-000000000002', '10000002-0000-0000-0000-000000000001', 2, 'Variables y tipos de datos', 'En Python una variable se crea al asignarle un valor con el signo =; no hay que declarar el tipo. Los tipos básicos son int (enteros), float (decimales), str (texto) y bool (True o False). La función type() devuelve el tipo de un valor. Los nombres distinguen mayúsculas de minúsculas: edad y Edad son variables distintas.', 'nombre = ''Usagi''
puntos = 5
puntos = puntos + 3
print(nombre, puntos)  # Usagi 8')
on conflict (id) do nothing;

insert into public.preguntas (id, leccion_id, orden, enunciado, codigo) values
  ('30000002-0000-0000-0000-000000000101', '20000002-0000-0000-0000-000000000001', 1, '¿Qué función muestra un mensaje en pantalla en Python?', null),
  ('30000002-0000-0000-0000-000000000102', '20000002-0000-0000-0000-000000000001', 2, '¿Con qué símbolo empieza un comentario de una línea en Python?', null),
  ('30000002-0000-0000-0000-000000000103', '20000002-0000-0000-0000-000000000001', 3, 'Usando la función de la lección: ¿qué muestra este código?', 'print(''Hola'' + ''!'')'),
  ('30000002-0000-0000-0000-000000000201', '20000002-0000-0000-0000-000000000002', 1, '¿Cómo se crea en Python una variable llamada edad con el valor 15?', null),
  ('30000002-0000-0000-0000-000000000202', '20000002-0000-0000-0000-000000000002', 2, '¿Qué tipo de dato es el valor 3.14 en Python?', null),
  ('30000002-0000-0000-0000-000000000203', '20000002-0000-0000-0000-000000000002', 3, 'Usando el ejemplo de la lección: ¿cuánto vale x al final?', 'x = 4
x = x * 2')
on conflict (id) do nothing;

insert into public.opciones (id, pregunta_id, orden, texto) values
  ('40000002-0000-0000-0000-000000010101', '30000002-0000-0000-0000-000000000101', 1, 'console.log()'),
  ('40000002-0000-0000-0000-000000010102', '30000002-0000-0000-0000-000000000101', 2, 'print()'),
  ('40000002-0000-0000-0000-000000010103', '30000002-0000-0000-0000-000000000101', 3, 'echo'),
  ('40000002-0000-0000-0000-000000010104', '30000002-0000-0000-0000-000000000101', 4, 'System.out.println()'),
  ('40000002-0000-0000-0000-000000010201', '30000002-0000-0000-0000-000000000102', 1, '//'),
  ('40000002-0000-0000-0000-000000010202', '30000002-0000-0000-0000-000000000102', 2, '--'),
  ('40000002-0000-0000-0000-000000010203', '30000002-0000-0000-0000-000000000102', 3, '#'),
  ('40000002-0000-0000-0000-000000010204', '30000002-0000-0000-0000-000000000102', 4, '/*'),
  ('40000002-0000-0000-0000-000000010301', '30000002-0000-0000-0000-000000000103', 1, 'Hola!'),
  ('40000002-0000-0000-0000-000000010302', '30000002-0000-0000-0000-000000000103', 2, '''Hola'' + ''!'''),
  ('40000002-0000-0000-0000-000000010303', '30000002-0000-0000-0000-000000000103', 3, 'Un error'),
  ('40000002-0000-0000-0000-000000010304', '30000002-0000-0000-0000-000000000103', 4, 'Hola !'),
  ('40000002-0000-0000-0000-000000020101', '30000002-0000-0000-0000-000000000201', 1, 'int edad = 15'),
  ('40000002-0000-0000-0000-000000020102', '30000002-0000-0000-0000-000000000201', 2, 'var edad = 15;'),
  ('40000002-0000-0000-0000-000000020103', '30000002-0000-0000-0000-000000000201', 3, 'let edad := 15'),
  ('40000002-0000-0000-0000-000000020104', '30000002-0000-0000-0000-000000000201', 4, 'edad = 15'),
  ('40000002-0000-0000-0000-000000020201', '30000002-0000-0000-0000-000000000202', 1, 'int'),
  ('40000002-0000-0000-0000-000000020202', '30000002-0000-0000-0000-000000000202', 2, 'float'),
  ('40000002-0000-0000-0000-000000020203', '30000002-0000-0000-0000-000000000202', 3, 'str'),
  ('40000002-0000-0000-0000-000000020204', '30000002-0000-0000-0000-000000000202', 4, 'bool'),
  ('40000002-0000-0000-0000-000000020301', '30000002-0000-0000-0000-000000000203', 1, '4'),
  ('40000002-0000-0000-0000-000000020302', '30000002-0000-0000-0000-000000000203', 2, '6'),
  ('40000002-0000-0000-0000-000000020303', '30000002-0000-0000-0000-000000000203', 3, '8'),
  ('40000002-0000-0000-0000-000000020304', '30000002-0000-0000-0000-000000000203', 4, '42')
on conflict (id) do nothing;

insert into public.soluciones (pregunta_id, opcion_correcta_id, explicacion) values
  ('30000002-0000-0000-0000-000000000101', '40000002-0000-0000-0000-000000010102', 'print() escribe el mensaje en pantalla. console.log() es de JavaScript, echo de PHP y System.out.println() de Java.'),
  ('30000002-0000-0000-0000-000000000102', '40000002-0000-0000-0000-000000010203', 'En Python los comentarios de una línea empiezan con #. Las barras // se usan en otros lenguajes.'),
  ('30000002-0000-0000-0000-000000000103', '40000002-0000-0000-0000-000000010301', 'El operador + une (concatena) los dos textos y print() los muestra juntos: Hola!'),
  ('30000002-0000-0000-0000-000000000201', '40000002-0000-0000-0000-000000020104', 'En Python alcanza con asignar: edad = 15. No se escribe el tipo ni hace falta el punto y coma.'),
  ('30000002-0000-0000-0000-000000000202', '40000002-0000-0000-0000-000000020202', 'Los números con parte decimal son float. Los int son enteros, los str son texto y los bool son True o False.'),
  ('30000002-0000-0000-0000-000000000203', '40000002-0000-0000-0000-000000020303', 'x * 2 toma el valor actual (4) y lo multiplica por 2: el nuevo valor es 8, que queda guardado en x.')
on conflict (pregunta_id) do nothing;

-- -------------------------------------------------------------
-- PHP DESDE CERO
-- -------------------------------------------------------------
insert into public.cursos (id, slug, titulo, descripcion, nivel, estado, color, icono, orden) values
  ('00000000-0000-0000-0000-000000000003', 'php', 'PHP desde cero', 'Descubre el lenguaje que hay detrás de gran parte de la web: páginas dinámicas y sitios con base de datos. Esta entrega incluye la unidad 1 con dos lecciones completas.', 'Principiante', 'disponible', '#777bb4', 'language', 3)
on conflict (id) do nothing;

insert into public.unidades (id, curso_id, orden, titulo, descripcion, icono, disponible) values
  ('10000003-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', 1, 'Fundamentos de PHP', 'Qué es PHP, cómo se escribe y cómo guardar información en variables.', 'code', true),
  ('10000003-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003', 2, 'Condicionales', 'Tomar decisiones con if, elseif y else. Pendiente de publicación.', 'call_split', false),
  ('10000003-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000003', 3, 'Bucles y repetición', 'Repetir acciones con for, while y foreach. Pendiente de publicación.', 'loop', false),
  ('10000003-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000003', 4, 'Funciones', 'Código reutilizable con function y return. Pendiente de publicación.', 'functions', false),
  ('10000003-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000003', 5, 'Arreglos y formularios', 'Colecciones de datos y recepción de formularios. Pendiente de publicación.', 'data_object', false)
on conflict (id) do nothing;

insert into public.lecciones (id, unidad_id, orden, titulo, explicacion, ejemplo_codigo) values
  ('20000003-0000-0000-0000-000000000001', '10000003-0000-0000-0000-000000000001', 1, '¿Qué es PHP?', 'PHP es un lenguaje que se ejecuta en el servidor: genera la página (HTML) antes de enviarla al navegador del visitante. El código PHP va dentro de un bloque que empieza con <?php. Cada instrucción termina con punto y coma (;) y la instrucción echo muestra texto en la página.', '<?php
echo ''Hola, mundo'';
// El servidor ejecuta esto y envía solo el resultado'),
  ('20000003-0000-0000-0000-000000000002', '10000003-0000-0000-0000-000000000001', 2, 'Variables en PHP', 'En PHP el nombre de toda variable empieza con el signo $. No se declara el tipo: se asigna el valor con =. Los tipos básicos son int, float, string y bool. Para unir textos se usa el operador punto (.), no el signo +.', '<?php
$nombre = ''Usagi'';
$puntos = 5;
$puntos = $puntos + 3;
echo $nombre . '' '' . $puntos; // Usagi 8')
on conflict (id) do nothing;

insert into public.preguntas (id, leccion_id, orden, enunciado, codigo) values
  ('30000003-0000-0000-0000-000000000101', '20000003-0000-0000-0000-000000000001', 1, '¿Dónde se ejecuta el código PHP?', null),
  ('30000003-0000-0000-0000-000000000102', '20000003-0000-0000-0000-000000000001', 2, '¿Qué instrucción muestra un texto en PHP?', null),
  ('30000003-0000-0000-0000-000000000103', '20000003-0000-0000-0000-000000000001', 3, '¿Con qué etiqueta empieza un bloque de código PHP?', null),
  ('30000003-0000-0000-0000-000000000201', '20000003-0000-0000-0000-000000000002', 1, '¿Qué símbolo lleva al principio el nombre de toda variable en PHP?', null),
  ('30000003-0000-0000-0000-000000000202', '20000003-0000-0000-0000-000000000002', 2, '¿Qué operador une (concatena) dos textos en PHP?', null),
  ('30000003-0000-0000-0000-000000000203', '20000003-0000-0000-0000-000000000002', 3, 'Usando el ejemplo de la lección: ¿cuánto vale $a?', '$a = 2;
$a = $a + 5;')
on conflict (id) do nothing;

insert into public.opciones (id, pregunta_id, orden, texto) values
  ('40000003-0000-0000-0000-000000010101', '30000003-0000-0000-0000-000000000101', 1, 'En el navegador del usuario'),
  ('40000003-0000-0000-0000-000000010102', '30000003-0000-0000-0000-000000000101', 2, 'En la hoja de estilos'),
  ('40000003-0000-0000-0000-000000010103', '30000003-0000-0000-0000-000000000101', 3, 'En el servidor web'),
  ('40000003-0000-0000-0000-000000010104', '30000003-0000-0000-0000-000000000101', 4, 'En el teclado'),
  ('40000003-0000-0000-0000-000000010201', '30000003-0000-0000-0000-000000000102', 1, 'echo'),
  ('40000003-0000-0000-0000-000000010202', '30000003-0000-0000-0000-000000000102', 2, 'alert()'),
  ('40000003-0000-0000-0000-000000010203', '30000003-0000-0000-0000-000000000102', 3, 'console.log()'),
  ('40000003-0000-0000-0000-000000010204', '30000003-0000-0000-0000-000000000102', 4, 'display()'),
  ('40000003-0000-0000-0000-000000010301', '30000003-0000-0000-0000-000000000103', 1, '<script>'),
  ('40000003-0000-0000-0000-000000010302', '30000003-0000-0000-0000-000000000103', 2, '<?code'),
  ('40000003-0000-0000-0000-000000010303', '30000003-0000-0000-0000-000000000103', 3, '<%'),
  ('40000003-0000-0000-0000-000000010304', '30000003-0000-0000-0000-000000000103', 4, '<?php'),
  ('40000003-0000-0000-0000-000000020101', '30000003-0000-0000-0000-000000000201', 1, '@'),
  ('40000003-0000-0000-0000-000000020102', '30000003-0000-0000-0000-000000000201', 2, '$'),
  ('40000003-0000-0000-0000-000000020103', '30000003-0000-0000-0000-000000000201', 3, '#'),
  ('40000003-0000-0000-0000-000000020104', '30000003-0000-0000-0000-000000000201', 4, '&'),
  ('40000003-0000-0000-0000-000000020201', '30000003-0000-0000-0000-000000000202', 1, '+'),
  ('40000003-0000-0000-0000-000000020202', '30000003-0000-0000-0000-000000000202', 2, '&&'),
  ('40000003-0000-0000-0000-000000020203', '30000003-0000-0000-0000-000000000202', 3, '&'),
  ('40000003-0000-0000-0000-000000020204', '30000003-0000-0000-0000-000000000202', 4, '.'),
  ('40000003-0000-0000-0000-000000020301', '30000003-0000-0000-0000-000000000203', 1, '7'),
  ('40000003-0000-0000-0000-000000020302', '30000003-0000-0000-0000-000000000203', 2, '25'),
  ('40000003-0000-0000-0000-000000020303', '30000003-0000-0000-0000-000000000203', 3, '3'),
  ('40000003-0000-0000-0000-000000020304', '30000003-0000-0000-0000-000000000203', 4, '2')
on conflict (id) do nothing;

insert into public.soluciones (pregunta_id, opcion_correcta_id, explicacion) values
  ('30000003-0000-0000-0000-000000000101', '40000003-0000-0000-0000-000000010103', 'PHP corre en el servidor. El navegador solo recibe el resultado (HTML), nunca el código PHP.'),
  ('30000003-0000-0000-0000-000000000102', '40000003-0000-0000-0000-000000010201', 'echo escribe texto en la salida de la página. alert() y console.log() son de JavaScript.'),
  ('30000003-0000-0000-0000-000000000103', '40000003-0000-0000-0000-000000010304', 'Los bloques de PHP se abren con <?php. <script> se usa para JavaScript.'),
  ('30000003-0000-0000-0000-000000000201', '40000003-0000-0000-0000-000000020102', 'Las variables de PHP empiezan con $, por ejemplo $nombre.'),
  ('30000003-0000-0000-0000-000000000202', '40000003-0000-0000-0000-000000020204', 'En PHP el operador de concatenación es el punto (.). El signo + es solo para sumar números.'),
  ('30000003-0000-0000-0000-000000000203', '40000003-0000-0000-0000-000000020301', '$a + 5 toma el valor actual (2) y le suma 5: el nuevo valor es 7.')
on conflict (pregunta_id) do nothing;

-- -------------------------------------------------------------
-- JAVA DESDE CERO
-- -------------------------------------------------------------
insert into public.cursos (id, slug, titulo, descripcion, nivel, estado, color, icono, orden) values
  ('00000000-0000-0000-0000-000000000004', 'java', 'Java desde cero', 'Aprende un lenguaje clásico para aplicaciones, sistemas empresariales y Android. Esta entrega incluye la unidad 1 con dos lecciones completas.', 'Principiante', 'disponible', '#f89820', 'coffee', 4)
on conflict (id) do nothing;

insert into public.unidades (id, curso_id, orden, titulo, descripcion, icono, disponible) values
  ('10000004-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000004', 1, 'Fundamentos de Java', 'Qué es Java, cómo se estructura un programa y cómo declarar variables.', 'code', true),
  ('10000004-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000004', 2, 'Condicionales', 'Tomar decisiones con if, else y switch. Pendiente de publicación.', 'call_split', false),
  ('10000004-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000004', 3, 'Bucles y repetición', 'Repetir acciones con for y while. Pendiente de publicación.', 'loop', false),
  ('10000004-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000004', 4, 'Métodos', 'Código reutilizable con parámetros y return. Pendiente de publicación.', 'functions', false),
  ('10000004-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000004', 5, 'Clases y objetos', 'Los pilares de la programación orientada a objetos. Pendiente de publicación.', 'data_object', false)
on conflict (id) do nothing;

insert into public.lecciones (id, unidad_id, orden, titulo, explicacion, ejemplo_codigo) values
  ('20000004-0000-0000-0000-000000000001', '10000004-0000-0000-0000-000000000001', 1, '¿Qué es Java?', 'Java es un lenguaje orientado a objetos y de tipado estático. El compilador convierte el código en bytecode, que ejecuta la JVM (Máquina Virtual de Java); por eso el mismo programa corre en distintos sistemas. Todo el código vive dentro de una clase y el programa arranca en el método main. Para imprimir una línea se usa System.out.println().', 'public class Hola {
  public static void main(String[] args) {
    System.out.println("Hola, mundo");
  }
}'),
  ('20000004-0000-0000-0000-000000000002', '10000004-0000-0000-0000-000000000001', 2, 'Variables y tipos', 'En Java hay que declarar el tipo de cada variable. Los más usados son int (enteros), double (decimales), boolean (true o false) y String (texto entre comillas dobles). Cada instrucción termina con punto y coma (;).', 'String nombre = "Usagi";
int puntos = 5;
puntos = puntos + 3;
System.out.println(nombre + " " + puntos); // Usagi 8')
on conflict (id) do nothing;

insert into public.preguntas (id, leccion_id, orden, enunciado, codigo) values
  ('30000004-0000-0000-0000-000000000101', '20000004-0000-0000-0000-000000000001', 1, '¿Qué programa ejecuta el bytecode de Java?', null),
  ('30000004-0000-0000-0000-000000000102', '20000004-0000-0000-0000-000000000001', 2, '¿Qué instrucción imprime una línea en la consola de Java?', null),
  ('30000004-0000-0000-0000-000000000103', '20000004-0000-0000-0000-000000000001', 3, '¿Cuál es el método donde arranca un programa Java?', null),
  ('30000004-0000-0000-0000-000000000201', '20000004-0000-0000-0000-000000000002', 1, '¿Qué tipo se usa para guardar el número entero 10?', null),
  ('30000004-0000-0000-0000-000000000202', '20000004-0000-0000-0000-000000000002', 2, '¿Cuál es la forma correcta de declarar un texto en Java?', null),
  ('30000004-0000-0000-0000-000000000203', '20000004-0000-0000-0000-000000000002', 3, 'Usando la lección: ¿cuánto vale x al final?', 'int x = 7;
x = x - 2;')
on conflict (id) do nothing;

insert into public.opciones (id, pregunta_id, orden, texto) values
  ('40000004-0000-0000-0000-000000010101', '30000004-0000-0000-0000-000000000101', 1, 'El navegador'),
  ('40000004-0000-0000-0000-000000010102', '30000004-0000-0000-0000-000000000101', 2, 'El compilador de C'),
  ('40000004-0000-0000-0000-000000010103', '30000004-0000-0000-0000-000000000101', 3, 'El sistema de archivos'),
  ('40000004-0000-0000-0000-000000010104', '30000004-0000-0000-0000-000000000101', 4, 'La JVM (Máquina Virtual de Java)'),
  ('40000004-0000-0000-0000-000000010201', '30000004-0000-0000-0000-000000000102', 1, 'print()'),
  ('40000004-0000-0000-0000-000000010202', '30000004-0000-0000-0000-000000000102', 2, 'System.out.println()'),
  ('40000004-0000-0000-0000-000000010203', '30000004-0000-0000-0000-000000000102', 3, 'console.log()'),
  ('40000004-0000-0000-0000-000000010204', '30000004-0000-0000-0000-000000000102', 4, 'echo'),
  ('40000004-0000-0000-0000-000000010301', '30000004-0000-0000-0000-000000000103', 1, 'start()'),
  ('40000004-0000-0000-0000-000000010302', '30000004-0000-0000-0000-000000000103', 2, 'run()'),
  ('40000004-0000-0000-0000-000000010303', '30000004-0000-0000-0000-000000000103', 3, 'main()'),
  ('40000004-0000-0000-0000-000000010304', '30000004-0000-0000-0000-000000000103', 4, 'init()'),
  ('40000004-0000-0000-0000-000000020101', '30000004-0000-0000-0000-000000000201', 1, 'int'),
  ('40000004-0000-0000-0000-000000020102', '30000004-0000-0000-0000-000000000201', 2, 'String'),
  ('40000004-0000-0000-0000-000000020103', '30000004-0000-0000-0000-000000000201', 3, 'boolean'),
  ('40000004-0000-0000-0000-000000020104', '30000004-0000-0000-0000-000000000201', 4, 'double'),
  ('40000004-0000-0000-0000-000000020201', '30000004-0000-0000-0000-000000000202', 1, 'string t = ''hola'';'),
  ('40000004-0000-0000-0000-000000020202', '30000004-0000-0000-0000-000000000202', 2, 'text t = "hola";'),
  ('40000004-0000-0000-0000-000000020203', '30000004-0000-0000-0000-000000000202', 3, 'String t = "hola";'),
  ('40000004-0000-0000-0000-000000020204', '30000004-0000-0000-0000-000000000202', 4, 'var t = hola;'),
  ('40000004-0000-0000-0000-000000020301', '30000004-0000-0000-0000-000000000203', 1, '9'),
  ('40000004-0000-0000-0000-000000020302', '30000004-0000-0000-0000-000000000203', 2, '5'),
  ('40000004-0000-0000-0000-000000020303', '30000004-0000-0000-0000-000000000203', 3, '2'),
  ('40000004-0000-0000-0000-000000020304', '30000004-0000-0000-0000-000000000203', 4, '7')
on conflict (id) do nothing;

insert into public.soluciones (pregunta_id, opcion_correcta_id, explicacion) values
  ('30000004-0000-0000-0000-000000000101', '40000004-0000-0000-0000-000000010104', 'La JVM interpreta el bytecode y lo ejecuta en cada sistema operativo.'),
  ('30000004-0000-0000-0000-000000000102', '40000004-0000-0000-0000-000000010202', 'System.out.println() imprime el texto y salta a la línea siguiente.'),
  ('30000004-0000-0000-0000-000000000103', '40000004-0000-0000-0000-000000010303', 'La JVM empieza a ejecutar el programa por el método main.'),
  ('30000004-0000-0000-0000-000000000201', '40000004-0000-0000-0000-000000020101', 'int guarda números enteros. double es para decimales y String para texto.'),
  ('30000004-0000-0000-0000-000000000202', '40000004-0000-0000-0000-000000020203', 'El tipo se escribe String (con S mayúscula) y el texto va entre comillas dobles.'),
  ('30000004-0000-0000-0000-000000000203', '40000004-0000-0000-0000-000000020302', 'x - 2 toma el valor actual (7) y le resta 2: el nuevo valor es 5.')
on conflict (pregunta_id) do nothing;

-- -------------------------------------------------------------
-- C# DESDE CERO
-- -------------------------------------------------------------
insert into public.cursos (id, slug, titulo, descripcion, nivel, estado, color, icono, orden) values
  ('00000000-0000-0000-0000-000000000005', 'csharp', 'C# desde cero', 'Conoce el lenguaje de Microsoft para aplicaciones, servicios web y videojuegos con Unity. Esta entrega incluye la unidad 1 con dos lecciones completas.', 'Principiante', 'disponible', '#9b4f96', 'tag', 5)
on conflict (id) do nothing;

insert into public.unidades (id, curso_id, orden, titulo, descripcion, icono, disponible) values
  ('10000005-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000005', 1, 'Fundamentos de C#', 'Qué es C#, cómo mostrar mensajes y cómo declarar variables.', 'code', true),
  ('10000005-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000005', 2, 'Condicionales', 'Tomar decisiones con if, else y switch. Pendiente de publicación.', 'call_split', false),
  ('10000005-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000005', 3, 'Bucles y repetición', 'Repetir acciones con for, while y foreach. Pendiente de publicación.', 'loop', false),
  ('10000005-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000005', 4, 'Métodos', 'Código reutilizable con parámetros y return. Pendiente de publicación.', 'functions', false),
  ('10000005-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000005', 5, 'Clases y objetos', 'Programación orientada a objetos en C#. Pendiente de publicación.', 'data_object', false)
on conflict (id) do nothing;

insert into public.lecciones (id, unidad_id, orden, titulo, explicacion, ejemplo_codigo) values
  ('20000005-0000-0000-0000-000000000001', '10000005-0000-0000-0000-000000000001', 1, '¿Qué es C#?', 'C# (se lee "C sharp") es un lenguaje orientado a objetos creado por Microsoft. Corre sobre la plataforma .NET y se usa para aplicaciones de escritorio, servicios web y videojuegos hechos con Unity. Para mostrar una línea en la consola se usa Console.WriteLine().', 'Console.WriteLine("Hola, mundo");

// Console es una clase de .NET
// WriteLine es el método que imprime'),
  ('20000005-0000-0000-0000-000000000002', '10000005-0000-0000-0000-000000000001', 2, 'Variables y tipos', 'En C# se declara el tipo de cada variable: int (enteros), double (decimales), bool (true o false) y string (texto entre comillas dobles, con s minúscula). La palabra var permite que el compilador deduzca el tipo a partir del valor. Cada instrucción termina con punto y coma (;).', 'string nombre = "Usagi";
int puntos = 5;
puntos = puntos + 3;
Console.WriteLine(nombre + " " + puntos); // Usagi 8')
on conflict (id) do nothing;

insert into public.preguntas (id, leccion_id, orden, enunciado, codigo) values
  ('30000005-0000-0000-0000-000000000101', '20000005-0000-0000-0000-000000000001', 1, '¿Qué empresa creó el lenguaje C#?', null),
  ('30000005-0000-0000-0000-000000000102', '20000005-0000-0000-0000-000000000001', 2, '¿Qué instrucción escribe una línea en la consola en C#?', null),
  ('30000005-0000-0000-0000-000000000103', '20000005-0000-0000-0000-000000000001', 3, '¿Sobre qué plataforma corre C#?', null),
  ('30000005-0000-0000-0000-000000000201', '20000005-0000-0000-0000-000000000002', 1, '¿Qué tipo guarda un texto en C#?', null),
  ('30000005-0000-0000-0000-000000000202', '20000005-0000-0000-0000-000000000002', 2, '¿Qué palabra clave deja que el compilador deduzca el tipo de la variable?', null),
  ('30000005-0000-0000-0000-000000000203', '20000005-0000-0000-0000-000000000002', 3, 'Usando la lección: ¿cuánto vale n al final?', 'int n = 3;
n = n * 3;')
on conflict (id) do nothing;

insert into public.opciones (id, pregunta_id, orden, texto) values
  ('40000005-0000-0000-0000-000000010101', '30000005-0000-0000-0000-000000000101', 1, 'Microsoft'),
  ('40000005-0000-0000-0000-000000010102', '30000005-0000-0000-0000-000000000101', 2, 'Google'),
  ('40000005-0000-0000-0000-000000010103', '30000005-0000-0000-0000-000000000101', 3, 'Apple'),
  ('40000005-0000-0000-0000-000000010104', '30000005-0000-0000-0000-000000000101', 4, 'Oracle'),
  ('40000005-0000-0000-0000-000000010201', '30000005-0000-0000-0000-000000000102', 1, 'console.log()'),
  ('40000005-0000-0000-0000-000000010202', '30000005-0000-0000-0000-000000000102', 2, 'System.out.println()'),
  ('40000005-0000-0000-0000-000000010203', '30000005-0000-0000-0000-000000000102', 3, 'echo'),
  ('40000005-0000-0000-0000-000000010204', '30000005-0000-0000-0000-000000000102', 4, 'Console.WriteLine()'),
  ('40000005-0000-0000-0000-000000010301', '30000005-0000-0000-0000-000000000103', 1, 'JVM'),
  ('40000005-0000-0000-0000-000000010302', '30000005-0000-0000-0000-000000000103', 2, '.NET'),
  ('40000005-0000-0000-0000-000000010303', '30000005-0000-0000-0000-000000000103', 3, 'Node.js'),
  ('40000005-0000-0000-0000-000000010304', '30000005-0000-0000-0000-000000000103', 4, 'Django'),
  ('40000005-0000-0000-0000-000000020101', '30000005-0000-0000-0000-000000000201', 1, 'text'),
  ('40000005-0000-0000-0000-000000020102', '30000005-0000-0000-0000-000000000201', 2, 'char'),
  ('40000005-0000-0000-0000-000000020103', '30000005-0000-0000-0000-000000000201', 3, 'string'),
  ('40000005-0000-0000-0000-000000020104', '30000005-0000-0000-0000-000000000201', 4, 'str'),
  ('40000005-0000-0000-0000-000000020201', '30000005-0000-0000-0000-000000000202', 1, 'var'),
  ('40000005-0000-0000-0000-000000020202', '30000005-0000-0000-0000-000000000202', 2, 'dim'),
  ('40000005-0000-0000-0000-000000020203', '30000005-0000-0000-0000-000000000202', 3, 'auto'),
  ('40000005-0000-0000-0000-000000020204', '30000005-0000-0000-0000-000000000202', 4, 'let'),
  ('40000005-0000-0000-0000-000000020301', '30000005-0000-0000-0000-000000000203', 1, '6'),
  ('40000005-0000-0000-0000-000000020302', '30000005-0000-0000-0000-000000000203', 2, '33'),
  ('40000005-0000-0000-0000-000000020303', '30000005-0000-0000-0000-000000000203', 3, '12'),
  ('40000005-0000-0000-0000-000000020304', '30000005-0000-0000-0000-000000000203', 4, '9')
on conflict (id) do nothing;

insert into public.soluciones (pregunta_id, opcion_correcta_id, explicacion) values
  ('30000005-0000-0000-0000-000000000101', '40000005-0000-0000-0000-000000010101', 'C# fue creado por Microsoft como parte de la plataforma .NET.'),
  ('30000005-0000-0000-0000-000000000102', '40000005-0000-0000-0000-000000010204', 'Console.WriteLine() imprime el texto en la consola y salta de línea.'),
  ('30000005-0000-0000-0000-000000000103', '40000005-0000-0000-0000-000000010302', 'C# se ejecuta sobre .NET. La JVM es la de Java, Node.js es la de JavaScript y Django es de Python.'),
  ('30000005-0000-0000-0000-000000000201', '40000005-0000-0000-0000-000000020103', 'El tipo para texto es string, escrito en minúsculas.'),
  ('30000005-0000-0000-0000-000000000202', '40000005-0000-0000-0000-000000020201', 'Con var el compilador infiere el tipo desde el valor asignado: var edad = 15; crea un int.'),
  ('30000005-0000-0000-0000-000000000203', '40000005-0000-0000-0000-000000020304', 'n * 3 toma el valor actual (3) y lo multiplica por 3: el nuevo valor es 9.')
on conflict (pregunta_id) do nothing;

-- -------------------------------------------------------------
-- C++ DESDE CERO
-- -------------------------------------------------------------
insert into public.cursos (id, slug, titulo, descripcion, nivel, estado, color, icono, orden) values
  ('00000000-0000-0000-0000-000000000006', 'cpp', 'C++ desde cero', 'Aprende el lenguaje de alto rendimiento detrás de videojuegos, sistemas y software de precisión. Esta entrega incluye la unidad 1 con dos lecciones completas.', 'Principiante', 'disponible', '#00599c', 'memory', 6)
on conflict (id) do nothing;

insert into public.unidades (id, curso_id, orden, titulo, descripcion, icono, disponible) values
  ('10000006-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000006', 1, 'Fundamentos de C++', 'Qué es C++, cómo se estructura un programa y cómo declarar variables.', 'code', true),
  ('10000006-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000006', 2, 'Condicionales', 'Tomar decisiones con if, else y switch. Pendiente de publicación.', 'call_split', false),
  ('10000006-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000006', 3, 'Bucles y repetición', 'Repetir acciones con for y while. Pendiente de publicación.', 'loop', false),
  ('10000006-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000006', 4, 'Funciones', 'Código reutilizable con parámetros y return. Pendiente de publicación.', 'functions', false),
  ('10000006-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000006', 5, 'Arreglos y punteros', 'Memoria, arreglos y punteros. Pendiente de publicación.', 'data_object', false)
on conflict (id) do nothing;

insert into public.lecciones (id, unidad_id, orden, titulo, explicacion, ejemplo_codigo) values
  ('20000006-0000-0000-0000-000000000001', '10000006-0000-0000-0000-000000000001', 1, '¿Qué es C++?', 'C++ es un lenguaje compilado de alto rendimiento, muy usado en videojuegos, sistemas operativos y software que necesita velocidad. El programa arranca en la función main(). Para mostrar texto se incluye la biblioteca con #include <iostream> y se envía el mensaje a std::cout con el operador <<.', '#include <iostream>

int main() {
  std::cout << "Hola, mundo" << std::endl;
  return 0;
}'),
  ('20000006-0000-0000-0000-000000000002', '10000006-0000-0000-0000-000000000001', 2, 'Variables y tipos', 'En C++ se declara el tipo de cada variable: int (enteros), double (decimales), bool (verdadero o falso), char (un carácter) y std::string (texto). Cada instrucción termina con punto y coma (;). Si la declaración empieza con const, el valor no puede cambiar después.', 'const int vidas = 3;
int puntos = 5;
puntos = puntos + 3;
std::cout << puntos; // 8')
on conflict (id) do nothing;

insert into public.preguntas (id, leccion_id, orden, enunciado, codigo) values
  ('30000006-0000-0000-0000-000000000101', '20000006-0000-0000-0000-000000000001', 1, '¿Qué función es el punto de entrada de un programa C++?', null),
  ('30000006-0000-0000-0000-000000000102', '20000006-0000-0000-0000-000000000001', 2, '¿Qué objeto se usa para mostrar texto en la consola?', null),
  ('30000006-0000-0000-0000-000000000103', '20000006-0000-0000-0000-000000000001', 3, '¿Qué línea incluye la biblioteca de entrada y salida?', null),
  ('30000006-0000-0000-0000-000000000201', '20000006-0000-0000-0000-000000000002', 1, '¿Qué palabra clave impide que una variable cambie de valor?', null),
  ('30000006-0000-0000-0000-000000000202', '20000006-0000-0000-0000-000000000002', 2, '¿Qué tipo se usa para números con decimales?', null),
  ('30000006-0000-0000-0000-000000000203', '20000006-0000-0000-0000-000000000002', 3, 'Usando la lección: ¿cuánto vale a al final?', 'int a = 10;
a = a / 2;')
on conflict (id) do nothing;

insert into public.opciones (id, pregunta_id, orden, texto) values
  ('40000006-0000-0000-0000-000000010101', '30000006-0000-0000-0000-000000000101', 1, 'start()'),
  ('40000006-0000-0000-0000-000000010102', '30000006-0000-0000-0000-000000000101', 2, 'begin()'),
  ('40000006-0000-0000-0000-000000010103', '30000006-0000-0000-0000-000000000101', 3, 'main()'),
  ('40000006-0000-0000-0000-000000010104', '30000006-0000-0000-0000-000000000101', 4, 'init()'),
  ('40000006-0000-0000-0000-000000010201', '30000006-0000-0000-0000-000000000102', 1, 'print'),
  ('40000006-0000-0000-0000-000000010202', '30000006-0000-0000-0000-000000000102', 2, 'std::cout'),
  ('40000006-0000-0000-0000-000000010203', '30000006-0000-0000-0000-000000000102', 3, 'console.log'),
  ('40000006-0000-0000-0000-000000010204', '30000006-0000-0000-0000-000000000102', 4, 'System.out'),
  ('40000006-0000-0000-0000-000000010301', '30000006-0000-0000-0000-000000000103', 1, 'import io'),
  ('40000006-0000-0000-0000-000000010302', '30000006-0000-0000-0000-000000000103', 2, 'using io;'),
  ('40000006-0000-0000-0000-000000010303', '30000006-0000-0000-0000-000000000103', 3, 'require(iostream)'),
  ('40000006-0000-0000-0000-000000010304', '30000006-0000-0000-0000-000000000103', 4, '#include <iostream>'),
  ('40000006-0000-0000-0000-000000020101', '30000006-0000-0000-0000-000000000201', 1, 'const'),
  ('40000006-0000-0000-0000-000000020102', '30000006-0000-0000-0000-000000000201', 2, 'static'),
  ('40000006-0000-0000-0000-000000020103', '30000006-0000-0000-0000-000000000201', 3, 'var'),
  ('40000006-0000-0000-0000-000000020104', '30000006-0000-0000-0000-000000000201', 4, 'let'),
  ('40000006-0000-0000-0000-000000020201', '30000006-0000-0000-0000-000000000202', 1, 'int'),
  ('40000006-0000-0000-0000-000000020202', '30000006-0000-0000-0000-000000000202', 2, 'bool'),
  ('40000006-0000-0000-0000-000000020203', '30000006-0000-0000-0000-000000000202', 3, 'double'),
  ('40000006-0000-0000-0000-000000020204', '30000006-0000-0000-0000-000000000202', 4, 'char'),
  ('40000006-0000-0000-0000-000000020301', '30000006-0000-0000-0000-000000000203', 1, '2'),
  ('40000006-0000-0000-0000-000000020302', '30000006-0000-0000-0000-000000000203', 2, '10'),
  ('40000006-0000-0000-0000-000000020303', '30000006-0000-0000-0000-000000000203', 3, '20'),
  ('40000006-0000-0000-0000-000000020304', '30000006-0000-0000-0000-000000000203', 4, '5')
on conflict (id) do nothing;

insert into public.soluciones (pregunta_id, opcion_correcta_id, explicacion) values
  ('30000006-0000-0000-0000-000000000101', '40000006-0000-0000-0000-000000010103', 'La ejecución de todo programa C++ comienza en la función main().'),
  ('30000006-0000-0000-0000-000000000102', '40000006-0000-0000-0000-000000010202', 'std::cout representa la salida de la consola y se usa con el operador <<.'),
  ('30000006-0000-0000-0000-000000000103', '40000006-0000-0000-0000-000000010304', '#include <iostream> trae las herramientas de entrada y salida, como std::cout.'),
  ('30000006-0000-0000-0000-000000000201', '40000006-0000-0000-0000-000000020101', 'const declara un valor constante: no se puede reasignar después de inicializarlo.'),
  ('30000006-0000-0000-0000-000000000202', '40000006-0000-0000-0000-000000020203', 'double guarda números con parte decimal. int es solo para enteros.'),
  ('30000006-0000-0000-0000-000000000203', '40000006-0000-0000-0000-000000020304', 'a / 2 divide el valor actual (10) por 2: el nuevo valor es 5.')
on conflict (pregunta_id) do nothing;
