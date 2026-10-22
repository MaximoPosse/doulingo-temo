-- =============================================================
-- Doulingo · setup.sql
-- Script combinado: creación del esquema, carga inicial,
-- políticas RLS y la etapa de autenticación.
--
-- Ejecutar en el SQL Editor de Supabase en este orden:
--   0001_schema.sql  (tablas, PK, FK y restricciones)
--   0002_seed.sql    (datos iniciales)
--   0003_rls.sql     (RLS + función check_answer)
--   0004_auth.sql    (perfiles, progreso del participante y RLS ampliada)
-- Los cuatro archivos son idempotentes: se pueden volver a ejecutar.
-- =============================================================

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

-- =============================================================
-- Doulingo · 0004_auth.sql
-- Identidad de los participantes: perfiles, progreso por participante
-- y ampliación de las políticas RLS de la etapa 3.
--
-- Decisiones del modelo:
--   - El identificador del participante es el id de Supabase Auth
--     (auth.users.id). No hay una tabla de "usuarios" propia: la
--     contraseña vive únicamente en Supabase Auth.
--   - `perfiles` guarda solo lo que se muestra (alias + sufijo) y lo
--     mínimo para saber si la cuenta es de invitado.
--   - `alias` es elegido por la persona (3-20 caracteres, minúsculas,
--     dígitos y guion bajo). Para distinguir participantes con alias
--     similares se muestra además `alias_sufijo`: 4 caracteres derivados
--     del id de Auth. El nombre público es "alias#sufijo".
--   - `participant_progress` guarda el avance por lección. Cada fila
--     pertenece a un único participante (id = auth.uid()).
--
-- Roles de Supabase Auth:
--   - anon        = visitante sin sesión (público).
--   - authenticated = con sesión. Incluye a los invitados anónimos
--     (is_anonymous = true) y a las cuentas con correo y contraseña.
-- =============================================================

-- -------------------------------------------------------------
-- PERFILES (vinculados al identificador de Auth)
-- -------------------------------------------------------------
create table if not exists public.perfiles (
  id             uuid primary key references auth.users (id) on delete cascade,
  alias          text not null,
  alias_sufijo   text not null,
  es_invitado    boolean not null default true,
  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  constraint perfiles_alias_largo check (char_length(alias) between 3 and 20),
  constraint perfiles_alias_formato check (alias ~ '^[a-z0-9_]{3,20}$'),
  constraint perfiles_alias_sufijo_formato check (alias_sufijo ~ '^[0-9a-f]{4}$'),
  constraint perfiles_alias_unico unique (alias, alias_sufijo)
);

comment on table public.perfiles is
  'Perfil visible de cada participante. Muestra públicamente alias + sufijo '
  '(alias#sufijo) para distinguir participantes con nombres similares. '
  'No contiene contraseñas ni datos sensibles: el correo y las credenciales '
  'viven solo en Supabase Auth.';

comment on column public.perfiles.alias_sufijo is
  'Sufijo de 4 caracteres hexadecimales derivado del id de Auth. '
  'Permite que dos participantes con el mismo alias se distingan.';

comment on column public.perfiles.es_invitado is
  'true mientras la sesión sea anónima (invitado sin cuenta permanente).';

-- -------------------------------------------------------------
-- PROGRESO POR PARTICIPANTE
-- -------------------------------------------------------------
create table if not exists public.participant_progress (
  id                uuid not null references auth.users (id) on delete cascade,
  leccion_id        uuid not null references public.lecciones (id) on delete cascade,
  estado            text not null check (estado in ('intentada', 'aprobada')),
  intentos          integer not null default 1 check (intentos > 0),
  mejor_aciertos    integer not null default 0 check (mejor_aciertos >= 0),
  total_actividades integer not null default 0 check (total_actividades >= 0),
  actualizado_en    timestamptz not null default now(),
  primary key (id, leccion_id)
);

comment on table public.participant_progress is
  'Avance de cada participante por lección. Solo el dueño de la fila puede '
  'consultarla o modificarla (políticas RLS con auth.uid()).';

-- -------------------------------------------------------------
-- NORMALIZACIÓN DEL ALIAS
-- -------------------------------------------------------------
create or replace function public.normalizar_alias(p_alias text)
returns text
language plpgsql
immutable
as $$
declare
  v text;
begin
  v := trim(coalesce(p_alias, ''));
  v := lower(v);
  v := regexp_replace(v, '[^a-z0-9_]+', '_', 'g');
  v := trim(both '_' from v);
  if char_length(v) < 3 then
    v := 'invitado';
  elsif char_length(v) > 20 then
    v := substr(v, 1, 20);
  end if;
  return v;
end;
$$;

comment on function public.normalizar_alias(text) is
  'Limpia el alias elegido: minúsculas, solo letras/dígitos/guion bajo, '
  'entre 3 y 20 caracteres. Si queda vacío se usa "invitado".';

-- -------------------------------------------------------------
-- ALTA AUTOMÁTICA DEL PERFIL AL CREAR EL USUARIO EN AUTH
-- -------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_alias    text;
  v_hex      text;
  v_sufijo   text;
  v_invitado boolean;
  v_offset   integer := 1;
  v_creado   boolean := false;
begin
  v_alias := public.normalizar_alias(new.raw_user_meta_data ->> 'alias');
  v_hex := replace(new.id::text, '-', '');
  -- `is_anonymous` solo existe si el proyecto tiene habilitados los
  -- invitados anónimos: se lee de forma tolerante a esa ausencia.
  v_invitado := coalesce((to_jsonb(new) ->> 'is_anonymous')::boolean, true);

  -- El sufijo son 4 caracteres del identificador de Auth. Si esa combinación
  -- (alias + sufijo) ya está tomada, se prueban las ventanas siguientes del
  -- identificador: dos participantes con el mismo alias siempre quedan
  -- distinguibles y el alta nunca falla por un choque de sufijo.
  while v_offset <= 29 and not v_creado loop
    v_sufijo := substr(v_hex, v_offset, 4);
    begin
      insert into public.perfiles (id, alias, alias_sufijo, es_invitado)
      values (new.id, v_alias, v_sufijo, v_invitado)
      on conflict (id) do nothing;
      v_creado := true;
    exception
      when unique_violation then
        v_offset := v_offset + 1;
    end;
  end loop;

  return new;
end;
$$;

comment on function public.handle_new_user() is
  'Crea el perfil de cada usuario nuevo de Supabase Auth (invitado o '
  'registrado) con el alias indicado en los metadatos.';

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- -------------------------------------------------------------
-- RLS · PERFILES
--   - Lectura pública: el alias y el sufijo son la identidad visible.
--   - Cada participante solo puede crear y modificar SU perfil.
--   - No hay política de borrado: los perfiles se eliminan junto con el
--     usuario de Auth (borrado en cascada) desde las herramientas
--     administrativas.
-- -------------------------------------------------------------
alter table public.perfiles enable row level security;

drop policy if exists "perfiles_lectura_publica" on public.perfiles;
create policy "perfiles_lectura_publica"
  on public.perfiles
  for select
  to anon, authenticated
  using (true);

drop policy if exists "perfiles_insercion_propia" on public.perfiles;
create policy "perfiles_insercion_propia"
  on public.perfiles
  for insert
  to authenticated
  with check (id = auth.uid());

drop policy if exists "perfiles_actualizacion_propia" on public.perfiles;
create policy "perfiles_actualizacion_propia"
  on public.perfiles
  for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

revoke all on public.perfiles from anon;
revoke delete on public.perfiles from anon, authenticated;
grant select on public.perfiles to anon, authenticated;
grant insert on public.perfiles to authenticated;
-- Solo se pueden cambiar el alias (elegido por la persona) y la fecha de
-- actualización: `es_invitado` lo cambia la función de conversión.
grant update (alias, actualizado_en) on public.perfiles to authenticated;

-- -------------------------------------------------------------
-- RLS · PROGRESO POR PARTICIPANTE
--   Cada participante consulta y modifica únicamente sus propias filas.
-- -------------------------------------------------------------
alter table public.participant_progress enable row level security;

drop policy if exists "progreso_lectura_propia" on public.participant_progress;
create policy "progreso_lectura_propia"
  on public.participant_progress
  for select
  to authenticated
  using (id = auth.uid());

drop policy if exists "progreso_insercion_propia" on public.participant_progress;
create policy "progreso_insercion_propia"
  on public.participant_progress
  for insert
  to authenticated
  with check (id = auth.uid());

drop policy if exists "progreso_actualizacion_propia" on public.participant_progress;
create policy "progreso_actualizacion_propia"
  on public.participant_progress
  for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

drop policy if exists "progreso_borrado_propio" on public.participant_progress;
create policy "progreso_borrado_propio"
  on public.participant_progress
  for delete
  to authenticated
  using (id = auth.uid());

revoke all on public.participant_progress from anon;
grant select, insert, update, delete on public.participant_progress to authenticated;

-- -------------------------------------------------------------
-- CONVERSIÓN DE INVITADO A CUENTA PERMANENTE
--   El cliente no puede escribir `es_invitado` directamente (el permiso
--   de actualización de perfiles es solo sobre `alias`). Esta función
--   marca la cuenta como permanente sobre la fila del propio usuario.
-- -------------------------------------------------------------
create or replace function public.marcar_cuenta_permanente()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.perfiles
     set es_invitado = false,
         actualizado_en = now()
   where id = auth.uid();
end;
$$;

comment on function public.marcar_cuenta_permanente() is
  'Marca el perfil del usuario actual como cuenta permanente (fin de la '
  'etapa de invitado). Solo afecta a la fila de auth.uid().';

revoke all on function public.marcar_cuenta_permanente() from public;
grant execute on function public.marcar_cuenta_permanente() to authenticated;

-- -------------------------------------------------------------
-- RLS · CONTENIDO: los visitantes sin sesión y los participantes con
-- sesión (incluidos los invitados anónimos) leen lo mismo: únicamente
-- el contenido publicado. Las políticas de la etapa 3 ya incluían a
-- `authenticated`, por lo que no hace falta modificarlas: se mantienen
-- como están para no duplicar definiciones.
-- -------------------------------------------------------------
grant usage on schema public to anon, authenticated;
