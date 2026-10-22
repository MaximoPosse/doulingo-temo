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


-- =============================================================
-- Doulingo · 0005_intentos.sql
-- Intentos, respuestas y progreso calculado en el servidor.
--
-- Decisiones del modelo:
--   - Cada intento pertenece a UN participante (auth.uid()) y a UNA
--     lección: `intentos.participante_id` + `intentos.leccion_id`.
--   - `clave_idempotencia` la genera el cliente al comenzar. Si la
--     petición se repite (reintento de red, doble toque, etc.), el
--     servidor devuelve el MISMO intento y no crea otro.
--   - `intentos_respuestas` guarda una sola respuesta por actividad e
--     intento (unique). Si llega otra respuesta para la misma actividad,
--     se conserva la primera: no se puede "reintentar" dentro del mismo
--     intento para subir el resultado.
--   - La corrección (correcto/incorrecto) la calcula el servidor con
--     `soluciones`; el celular nunca envía aciertos ni porcentajes.
--   - `finalizar_intento()` calcula total, aciertos, errores, resultado y
--     estado de finalización, y actualiza `participant_progress`. Es
--     idempotente: finalizar dos veces devuelve el mismo resultado y no
--     duplica el historial.
--   - Los intentos en curso (la persona salió, cerró la app o perdió la
--     conexión) quedan con estado 'en_curso': no cuentan como intento
--     completado y no cambian el progreso hasta que se finalicen.
--   - RLS: cada participante lee sus propios intentos y respuestas, y
--     puede borrar sus intentos (cascada a las respuestas). La escritura
--     solo ocurre a través de las funciones de abajo.
-- =============================================================

-- -------------------------------------------------------------
-- INTENTOS
-- -------------------------------------------------------------
create table if not exists public.intentos (
  id                  uuid primary key default gen_random_uuid(),
  participante_id     uuid not null references auth.users (id) on delete cascade,
  leccion_id          uuid not null references public.lecciones (id) on delete cascade,
  clave_idempotencia  text not null,
  estado              text not null default 'en_curso'
                      check (estado in ('en_curso', 'finalizado')),
  total_actividades   integer not null default 0 check (total_actividades >= 0),
  aciertos            integer not null default 0 check (aciertos >= 0),
  errores             integer not null default 0 check (errores >= 0),
  aprobada            boolean not null default false,
  iniciado_en         timestamptz not null default now(),
  finalizado_en       timestamptz,
  constraint intentos_clave_unica unique (participante_id, clave_idempotencia),
  constraint intentos_aciertos_caben check (aciertos + errores <= total_actividades),
  constraint intentos_finalizado_con_fecha check (
    (estado = 'en_curso' and finalizado_en is null) or
    (estado = 'finalizado' and finalizado_en is not null)
  )
);

comment on table public.intentos is
  'Un intento de una lección por participante. Guarda la fecha de inicio y '
  'fin, el total de actividades, aciertos, errores y resultado. La clave de '
  'idempotencia evita duplicados si el cliente repite la petición.';

comment on column public.intentos.clave_idempotencia is
  'Identificador generado por el cliente al comenzar el intento. Repetir la '
  'petición con la misma clave devuelve el mismo intento.';

comment on column public.intentos.estado is
  'en_curso: la persona todavía no llegó a resultados (o perdió la conexión). '
  'finalizado: el servidor calculó y guardó el resultado.';

create index if not exists intentos_por_participante
  on public.intentos (participante_id, leccion_id, iniciado_en desc);

-- -------------------------------------------------------------
-- RESPUESTAS DE CADA INTENTO
-- -------------------------------------------------------------
create table if not exists public.intentos_respuestas (
  id            uuid primary key default gen_random_uuid(),
  intento_id    uuid not null references public.intentos (id) on delete cascade,
  actividad_id  uuid not null references public.preguntas (id) on delete cascade,
  opcion_id     uuid not null references public.opciones (id) on delete cascade,
  correcto      boolean not null,
  respondido_en timestamptz not null default now(),
  constraint intentos_respuestas_una_por_actividad unique (intento_id, actividad_id)
);

comment on table public.intentos_respuestas is
  'Respuesta elegida por el participante en cada actividad de un intento. '
  'Una sola fila por actividad e intento: la primera respuesta queda firme.';

create index if not exists intentos_respuestas_por_intento
  on public.intentos_respuestas (intento_id);

-- -------------------------------------------------------------
-- RLS · INTENTOS Y RESPUESTAS
--   - Lectura: solo las filas propias.
--   - Escritura: solo mediante las funciones de esta migración.
--   - Borrado: el participante puede borrar sus intentos (las respuestas
--     caen en cascada). Es lo que usa "Borrar mi historial".
-- -------------------------------------------------------------
alter table public.intentos enable row level security;
alter table public.intentos_respuestas enable row level security;

drop policy if exists "intentos_lectura_propia" on public.intentos;
create policy "intentos_lectura_propia"
  on public.intentos
  for select
  to authenticated
  using (participante_id = auth.uid());

drop policy if exists "intentos_borrado_propio" on public.intentos;
create policy "intentos_borrado_propio"
  on public.intentos
  for delete
  to authenticated
  using (participante_id = auth.uid());

drop policy if exists "respuestas_lectura_propia" on public.intentos_respuestas;
create policy "respuestas_lectura_propia"
  on public.intentos_respuestas
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.intentos i
      where i.id = intentos_respuestas.intento_id
        and i.participante_id = auth.uid()
    )
  );

revoke all on public.intentos from anon, authenticated;
revoke all on public.intentos_respuestas from anon, authenticated;
grant select, delete on public.intentos to authenticated;
grant select on public.intentos_respuestas to authenticated;

-- El progreso por lección lo escribe únicamente finalizar_intento(): el
-- cliente ya no puede insertar ni modificar aciertos/estado por su cuenta.
revoke insert, update on public.participant_progress from authenticated;
grant select, delete on public.participant_progress to authenticated;

-- -------------------------------------------------------------
-- FUNCIÓN: iniciar_intento(leccion, clave)
--   Crea el intento (o devuelve el existente si la clave se repite).
-- -------------------------------------------------------------
create or replace function public.iniciar_intento(
  p_leccion uuid,
  p_clave   text
)
returns table (
  intento            uuid,
  leccion            uuid,
  total_actividades  integer,
  estado             text,
  iniciado_en        timestamptz,
  reutilizado        boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid       uuid := auth.uid();
  v_total     integer;
  v_intento   public.intentos;
begin
  if v_uid is null then
    raise exception 'PR_AUTH_REQUIRED'
      using hint = 'Se necesita una sesión para registrar intentos.';
  end if;

  if p_clave is null or char_length(p_clave) < 8 or char_length(p_clave) > 100 then
    raise exception 'PR_INVALID_KEY'
      using hint = 'La clave de idempotencia no es válida.';
  end if;

  if not exists (
    select 1
    from public.lecciones l
    join public.unidades u on u.id = l.unidad_id
    where l.id = p_leccion
      and u.disponible = true
  ) then
    raise exception 'PR_LESSON_NOT_PUBLISHED'
      using hint = 'La lección no existe o no está publicada.';
  end if;

  select count(*) into v_total
  from public.preguntas
  where leccion_id = p_leccion;

  if v_total = 0 then
    raise exception 'PR_LESSON_EMPTY'
      using hint = 'La lección no tiene actividades.';
  end if;

  -- ¿Ya se creó con esta misma clave? Se devuelve tal cual.
  select * into v_intento
  from public.intentos
  where participante_id = v_uid
    and clave_idempotencia = p_clave;

  if found then
    return query
      select v_intento.id, v_intento.leccion_id, v_intento.total_actividades,
             v_intento.estado, v_intento.iniciado_en, true;
    return;
  end if;

  begin
    insert into public.intentos (
      participante_id, leccion_id, clave_idempotencia, total_actividades
    )
    values (v_uid, p_leccion, p_clave, v_total)
    returning * into v_intento;
  exception
    when unique_violation then
      -- Otra petición con la misma clave ganó la carrera: se devuelve esa.
      select * into v_intento
      from public.intentos
      where participante_id = v_uid
        and clave_idempotencia = p_clave;
      return query
        select v_intento.id, v_intento.leccion_id, v_intento.total_actividades,
               v_intento.estado, v_intento.iniciado_en, true;
      return;
  end;

  return query
    select v_intento.id, v_intento.leccion_id, v_intento.total_actividades,
           v_intento.estado, v_intento.iniciado_en, false;
end;
$$;

comment on function public.iniciar_intento(uuid, text) is
  'Crea un intento para la lección indicada (del usuario actual). Si la '
  'clave de idempotencia ya existe, devuelve el mismo intento.';

-- -------------------------------------------------------------
-- FUNCIÓN: registrar_respuesta(intento, pregunta, opción)
--   Corrige en el servidor y guarda la PRIMERA respuesta de la actividad.
-- -------------------------------------------------------------
create or replace function public.registrar_respuesta(
  p_intento  uuid,
  p_pregunta uuid,
  p_opcion   uuid
)
returns table (
  correcto            boolean,
  explicacion         text,
  opcion_correcta_id  uuid,
  opcion_elegida_id   uuid,
  repetida            boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid         uuid := auth.uid();
  v_intento     public.intentos;
  v_solucion    public.soluciones;
  v_respuesta   public.intentos_respuestas;
  v_insertadas  integer;
begin
  if v_uid is null then
    raise exception 'PR_AUTH_REQUIRED'
      using hint = 'Se necesita una sesión para registrar respuestas.';
  end if;

  select * into v_intento
  from public.intentos
  where id = p_intento
    and participante_id = v_uid
  for update;

  if not found then
    raise exception 'PR_ATTEMPT_NOT_FOUND'
      using hint = 'El intento no existe o no pertenece a este participante.';
  end if;

  if v_intento.estado <> 'en_curso' then
    raise exception 'PR_ATTEMPT_CLOSED'
      using hint = 'El intento ya está finalizado.';
  end if;

  if not exists (
    select 1
    from public.preguntas p
    join public.lecciones l on l.id = p.leccion_id
    join public.unidades u  on u.id = l.unidad_id
    where p.id = p_pregunta
      and p.leccion_id = v_intento.leccion_id
      and u.disponible = true
  ) then
    raise exception 'PR_QUESTION_NOT_IN_ATTEMPT'
      using hint = 'La actividad no pertenece a la lección del intento.';
  end if;

  if not exists (
    select 1
    from public.opciones o
    where o.id = p_opcion
      and o.pregunta_id = p_pregunta
  ) then
    raise exception 'PR_OPTION_NOT_IN_QUESTION'
      using hint = 'La opción no pertenece a la actividad indicada.';
  end if;

  select * into v_solucion
  from public.soluciones
  where pregunta_id = p_pregunta;

  if not found then
    raise exception 'PR_SOLUTION_NOT_FOUND'
      using hint = 'La actividad no tiene una solución cargada.';
  end if;

  -- La primera respuesta de cada actividad es la que queda.
  insert into public.intentos_respuestas (
    intento_id, actividad_id, opcion_id, correcto
  )
  values (p_intento, p_pregunta, p_opcion, v_solucion.opcion_correcta_id = p_opcion)
  on conflict (intento_id, actividad_id) do nothing;

  get diagnostics v_insertadas = row_count;

  -- Los contadores del intento siempre reflejan las respuestas guardadas.
  update public.intentos i
     set aciertos = (
           select count(*) from public.intentos_respuestas r
           where r.intento_id = p_intento and r.correcto
         ),
         errores = (
           select count(*) from public.intentos_respuestas r
           where r.intento_id = p_intento and not r.correcto
         )
   where i.id = p_intento;

  select * into v_respuesta
  from public.intentos_respuestas
  where intento_id = p_intento
    and actividad_id = p_pregunta;

  return query
    select v_respuesta.correcto,
           v_solucion.explicacion,
           v_solucion.opcion_correcta_id,
           v_respuesta.opcion_id,
           (v_insertadas = 0);
end;
$$;

comment on function public.registrar_respuesta(uuid, uuid, uuid) is
  'Corrige una respuesta contra soluciones y la guarda en el intento. Si la '
  'actividad ya tenía respuesta, devuelve la guardada (repetida = true).';

-- -------------------------------------------------------------
-- FUNCIÓN: finalizar_intento(intento)
--   Calcula el resultado con las respuestas guardadas, lo guarda y
--   actualiza el progreso por lección. Idempotente.
-- -------------------------------------------------------------
create or replace function public.finalizar_intento(
  p_intento uuid
)
returns table (
  intento            uuid,
  leccion            uuid,
  total_actividades  integer,
  aciertos           integer,
  errores            integer,
  aprobada           boolean,
  estado             text,
  iniciado_en        timestamptz,
  finalizado_en      timestamptz,
  reutilizado        boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid           uuid := auth.uid();
  v_intento       public.intentos;
  v_respondidas   integer;
  v_aciertos      integer;
  v_aprobada      boolean;
  v_intentos      integer;
  v_mejor         integer;
begin
  if v_uid is null then
    raise exception 'PR_AUTH_REQUIRED'
      using hint = 'Se necesita una sesión para finalizar intentos.';
  end if;

  select * into v_intento
  from public.intentos
  where id = p_intento
    and participante_id = v_uid
  for update;

  if not found then
    raise exception 'PR_ATTEMPT_NOT_FOUND'
      using hint = 'El intento no existe o no pertenece a este participante.';
  end if;

  -- Repetir la petición de finalización devuelve el mismo resultado.
  if v_intento.estado = 'finalizado' then
    return query
      select v_intento.id, v_intento.leccion_id, v_intento.total_actividades,
             v_intento.aciertos, v_intento.errores, v_intento.aprobada,
             v_intento.estado, v_intento.iniciado_en, v_intento.finalizado_en,
             true;
    return;
  end if;

  select count(*) filter (where r.correcto), count(*)
    into v_aciertos, v_respondidas
  from public.intentos_respuestas r
  where r.intento_id = p_intento;

  if v_respondidas < v_intento.total_actividades then
    raise exception 'PR_ATTEMPT_INCOMPLETE'
      using hint = 'Todavía quedan actividades sin responder en este intento.';
  end if;

  v_aprobada := v_aciertos >= ceil(v_intento.total_actividades * 0.6);

  update public.intentos i
     set estado = 'finalizado',
         finalizado_en = now(),
         aciertos = v_aciertos,
         errores = v_respondidas - v_aciertos,
         aprobada = v_aprobada
   where i.id = p_intento
   returning * into v_intento;

  select count(*), max(i.aciertos)
    into v_intentos, v_mejor
  from public.intentos i
  where i.participante_id = v_uid
    and i.leccion_id = v_intento.leccion_id
    and i.estado = 'finalizado';

  insert into public.participant_progress (
    id, leccion_id, estado, intentos, mejor_aciertos, total_actividades,
    actualizado_en
  )
  values (
    v_uid, v_intento.leccion_id,
    case when v_aprobada then 'aprobada' else 'intentada' end,
    v_intentos, v_mejor, v_intento.total_actividades, now()
  )
  on conflict (id, leccion_id) do update
     set estado = case
           when participant_progress.estado = 'aprobada'
             or excluded.estado = 'aprobada' then 'aprobada'
           else 'intentada'
         end,
         intentos = excluded.intentos,
         mejor_aciertos = greatest(
           participant_progress.mejor_aciertos,
           excluded.mejor_aciertos
         ),
         total_actividades = excluded.total_actividades,
         actualizado_en = now();

  return query
    select v_intento.id, v_intento.leccion_id, v_intento.total_actividades,
           v_intento.aciertos, v_intento.errores, v_intento.aprobada,
           v_intento.estado, v_intento.iniciado_en, v_intento.finalizado_en,
           false;
end;
$$;

comment on function public.finalizar_intento(uuid) is
  'Calcula y guarda el resultado del intento con las respuestas registradas, '
  'actualiza participant_progress y es idempotente.';

revoke all on function public.iniciar_intento(uuid, text) from public;
revoke all on function public.registrar_respuesta(uuid, uuid, uuid) from public;
revoke all on function public.finalizar_intento(uuid) from public;
grant execute on function public.iniciar_intento(uuid, text) to authenticated;
grant execute on function public.registrar_respuesta(uuid, uuid, uuid) to authenticated;
grant execute on function public.finalizar_intento(uuid) to authenticated;
