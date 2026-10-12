-- =============================================================
-- Doulingo · 0001_schema.sql
-- Esquema de la base de datos relacional del curso JavaScript.
--
-- Niveles de contenido (jerarquía):
--   cursos -> unidades -> lecciones -> preguntas -> opciones
--   soluciones      (oculta por RLS, solo consultada por la función
--                    check_answer())
--
-- Convenciones:
--   - PK/IDs: uuid con default gen_random_uuid().
--   - `orden` (integer > 0) en todo nivel que requiere secuencia:
--     unidades, lecciones y preguntas. Nunca se depende del orden de
--     inserción.
--   - Las columnas son NOT NULL salvo los campos opcionales (código de
--     ejemplo, código del enunciado).
-- =============================================================

create extension if not exists pgcrypto;

-- -------------------------------------------------------------
-- CURSOS
-- -------------------------------------------------------------
create table if not exists public.cursos (
  id          uuid primary key default gen_random_uuid(),
  slug        text not null unique,
  titulo      text not null,
  descripcion text not null,
  nivel       text not null,
  estado      text not null check (estado in ('disponible', 'proximamente')),
  color       text not null check (color ~ '^#[0-9a-fA-F]{6}$'),
  icono       text not null,
  orden       integer not null check (orden > 0)
);

comment on table public.cursos is
  'Catálogo de cursos. estado = disponible | proximamente.';

-- -------------------------------------------------------------
-- UNIDADES
-- -------------------------------------------------------------
create table if not exists public.unidades (
  id          uuid primary key default gen_random_uuid(),
  curso_id    uuid not null references public.cursos (id) on delete cascade,
  orden       integer not null check (orden > 0),
  titulo      text not null,
  descripcion text not null,
  icono       text not null,
  disponible  boolean not null default false,
  unique (curso_id, orden)
);

comment on table public.unidades is
  'Unidad de un curso. `disponible` marca si el contenido está completo y
   puede ser cursado; las unidades en preparación quedan identificadas como
   no disponibles.';

-- -------------------------------------------------------------
-- LECCIONES
-- -------------------------------------------------------------
create table if not exists public.lecciones (
  id              uuid primary key default gen_random_uuid(),
  unidad_id       uuid not null references public.unidades (id) on delete cascade,
  orden           integer not null check (orden > 0),
  titulo          text not null,
  explicacion     text not null,
  ejemplo_codigo  text,
  unique (unidad_id, orden)
);

comment on table public.lecciones is
  'Lección de una unidad: teoría (explicacion) y ejemplo de código opcional.';

-- -------------------------------------------------------------
-- PREGUNTAS
-- -------------------------------------------------------------
create table if not exists public.preguntas (
  id         uuid primary key default gen_random_uuid(),
  leccion_id uuid not null references public.lecciones (id) on delete cascade,
  orden      integer not null check (orden > 0),
  enunciado  text not null,
  codigo     text,
  unique (leccion_id, orden)
);

comment on table public.preguntas is
  'Pregunta de opción múltiple de una lección. `codigo` es un fragmento
   opcional que se muestra junto al enunciado.';

-- -------------------------------------------------------------
-- OPCIONES (sin marca de solución)
-- -------------------------------------------------------------
create table if not exists public.opciones (
  id          uuid primary key default gen_random_uuid(),
  pregunta_id uuid not null references public.preguntas (id) on delete cascade,
  orden       integer not null check (orden > 0),
  texto       text not null,
  unique (pregunta_id, orden)
);

comment on table public.opciones is
  'Opciones visibles de una pregunta. NO almacenan cuál es la correcta:
   eso vive en `soluciones`, fuera del alcance público.';

-- -------------------------------------------------------------
-- SOLUCIONES (privadas)
-- -------------------------------------------------------------
create table if not exists public.soluciones (
  pregunta_id        uuid primary key references public.preguntas (id) on delete cascade,
  opcion_correcta_id uuid not null references public.opciones (id) on delete cascade,
  explicacion        text not null
);

comment on table public.soluciones is
  'Solución de cada pregunta: opción correcta y explicación. Está protegida
   por RLS (sin política de lectura) y solo se accede a través de la función
   check_answer() del servidor.';

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

-- =============================================================
-- Doulingo · 0003_rls.sql
-- Row Level Security + función de comprobación de respuestas.
--
-- Reglas:
--   - Los visitantes (anon) SOLO leen contenido publicado/disponible.
--   - Nadie (anon/authenticated) puede insertar, modificar ni borrar
--     desde la API: la escritura queda reservada a herramientas de
--     administración de Supabase (las cuales no aplican las políticas).
--   - `soluciones` NO tiene política de lectura: sus filas no pueden
--     consultarse vía API. Las soluciones solo se entregan a través de
--     check_answer().
--   - check_answer() es SECURITY DEFINER: valida en el servidor que la
--     pregunta exista y esté publicada, que la opción pertenezca a la
--     pregunta, y recién entonces compara contra la solución.
-- =============================================================

alter table public.cursos      enable row level security;
alter table public.unidades    enable row level security;
alter table public.lecciones   enable row level security;
alter table public.preguntas   enable row level security;
alter table public.opciones    enable row level security;
alter table public.soluciones  enable row level security;

-- -------------------------------------------------------------
-- CURSOS: lectura solo de cursos disponibles
-- -------------------------------------------------------------
drop policy if exists "cursos_lectura_publica" on public.cursos;
create policy "cursos_lectura_publica"
  on public.cursos
  for select
  to anon, authenticated
  using (estado = 'disponible');

-- -------------------------------------------------------------
-- UNIDADES: se listan todas (son metadatos del catálogo). Su disponibilidad
-- la muestra la propia columna `disponible`. El CONTENIDO de una unidad no
-- publicada queda oculto: sus lecciones/preguntas/opciones solo se leen si
-- la unidad es `disponible`.
-- -------------------------------------------------------------
drop policy if exists "unidades_lectura_publica" on public.unidades;
create policy "unidades_lectura_publica"
  on public.unidades
  for select
  to anon, authenticated
  using (true);

-- -------------------------------------------------------------
-- LECCIONES: lectura solo si su unidad está disponible
-- -------------------------------------------------------------
drop policy if exists "lecciones_lectura_publica" on public.lecciones;
create policy "lecciones_lectura_publica"
  on public.lecciones
  for select
  to anon, authenticated
  using (
    exists (
      select 1
      from public.unidades u
      where u.id = lecciones.unidad_id
        and u.disponible = true
    )
  );

-- -------------------------------------------------------------
-- PREGUNTAS: lectura solo si la cadena completo está publicada
-- -------------------------------------------------------------
drop policy if exists "preguntas_lectura_publica" on public.preguntas;
create policy "preguntas_lectura_publica"
  on public.preguntas
  for select
  to anon, authenticated
  using (
    exists (
      select 1
      from public.lecciones l
      join public.unidades u on u.id = l.unidad_id
      where l.id = preguntas.leccion_id
        and u.disponible = true
    )
  );

-- -------------------------------------------------------------
-- OPCIONES: lectura solo de preguntas publicadas
-- -------------------------------------------------------------
drop policy if exists "opciones_lectura_publica" on public.opciones;
create policy "opciones_lectura_publica"
  on public.opciones
  for select
  to anon, authenticated
  using (
    exists (
      select 1
      from public.preguntas p
      join public.lecciones l on l.id = p.leccion_id
      join public.unidades u on u.id = l.unidad_id
      where p.id = opciones.pregunta_id
        and u.disponible = true
    )
  );

-- -------------------------------------------------------------
-- SOLUCIONES: sin políticas -> no hay lectura vía API.
-- Blindaje adicional: revocar permisos de SELECT.
-- -------------------------------------------------------------
revoke all on public.soluciones from anon, authenticated;

-- -------------------------------------------------------------
-- FUNCIÓN: check_answer(pregunta, opcion)
--   Devuelve: correcto (bool), explicacion (text), opcion_correcta_id.
--   Solo para preguntas publicadas y opciones de esa pregunta.
-- -------------------------------------------------------------
create or replace function public.check_answer(
  p_pregunta uuid,
  p_opcion   uuid
)
returns table (
  correcto           boolean,
  explicacion        text,
  opcion_correcta_id uuid
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pregunta_presente boolean;
  v_opcion_valida     boolean;
begin
  -- 1) La pregunta debe existir y pertenecer a una unidad disponible.
  select exists (
    select 1
    from public.preguntas p
    join public.lecciones l  on l.id = p.leccion_id
    join public.unidades  u  on u.id = l.unidad_id
    where p.id = p_pregunta
      and u.disponible = true
  ) into v_pregunta_presente;

  if not v_pregunta_presente then
    raise exception 'PR_QUESTION_NOT_PUBLISHED'
      using hint = 'La pregunta no existe o no está publicada.';
  end if;

  -- 2) La opción debe pertenecer a esa pregunta.
  select exists (
    select 1
    from public.opciones o
    where o.id = p_opcion
      and o.pregunta_id = p_pregunta
  ) into v_opcion_valida;

  if not v_opcion_valida then
    raise exception 'PR_OPTION_NOT_IN_QUESTION'
      using hint = 'La opción no pertenece a la pregunta indicada.';
  end if;

  -- 3) Comparar contra la solución y devolver el resultado.
  return query
    select
      (s.opcion_correcta_id = p_opcion) as correcto,
      s.explicacion,
      s.opcion_correcta_id
    from public.soluciones s
    where s.pregunta_id = p_pregunta;
end;
$$;

-- Sólo anon/authenticated ejecutan la función (nadie más).
revoke all on function public.check_answer(uuid, uuid) from public;
grant execute on function public.check_answer(uuid, uuid) to anon, authenticated;

-- El cliente anónimo no debe poder escribir en ningún contenido.
revoke insert, update, delete on public.cursos,
                     public.unidades,
                     public.lecciones,
                     public.preguntas,
                     public.opciones
  from anon, authenticated;