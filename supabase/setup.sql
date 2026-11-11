-- =============================================================
-- Doulingo · setup.sql
-- Script combinado: creación del esquema, carga inicial,
-- políticas RLS y las etapas de autenticación, intentos y competencia.
--
-- Ejecutar en el SQL Editor de Supabase en este orden:
--   0001_schema.sql         (tablas, PK, FK y restricciones)
--   0002_seed.sql           (datos iniciales)
--   0003_rls.sql            (RLS + función check_answer)
--   0004_auth.sql           (perfiles, progreso del participante y RLS ampliada)
--   0005_intentos.sql       (intentos, respuestas y resultado en el servidor)
--   0006_desafios.sql       (competencia de expo: evento, desafíos y partidas)
--   0007_seed_desafios.sql  (datos iniciales de la expo y desafíos de prueba)
-- Los archivos son idempotentes: se pueden volver a ejecutar.
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

-- =============================================================
-- Doulingo · 0006_desafios.sql
-- Etapa 6: competencia de expo (evento, desafíos, partidas).
--
-- Separación práctica / competencia:
--   - La práctica usa `preguntas` / `opciones` / `soluciones` y su
--     corrección pública `check_answer()`.
--   - La competencia usa un BANCO PROPIO: `desafio_preguntas`,
--     `desafio_opciones` y `desafio_soluciones`. `check_answer()` nunca
--     lee este banco, así que la corrección de práctica no permite
--     consultar las soluciones de un desafío.
--
-- Reglas del modelo:
--   - El servidor crea la partida (`iniciar_partida`), registra a su
--     dueño, fija las preguntas asignadas y las reglas que aplican a ese
--     intento (puntos por acierto, duración y tolerancia) como una foto
--     del desafío en ese momento.
--   - `responder_partida` valida identidad, pertenencia, vigencia,
--     opción válida y ausencia de respuesta previa. Una sola respuesta
--     por (partida, pregunta): un envío repetido devuelve el resultado
--     existente y no vuelve a sumar puntos.
--   - Los puntos los calcula y guarda el servidor. El cliente no puede
--     insertar, modificar ni borrar partidas, respuestas ni puntajes por
--     REST.
--   - `finalizar_partida` deja el resultado en un estado consistente y
--     es idempotente.
--   - El tiempo se mide en el servidor: `iniciado_en`, `expira_en` y
--     `finalizado_en` usan now(). `duracion_ms` (desempate) se calcula
--     con la hora del servidor de la última respuesta, no con el reloj
--     del celular.
--   - Plazo de reconexión: después de `expira_en` no se aceptan
--     respuestas nuevas, pero se puede finalizar durante
--     `tolerancia_segundos` para guardar lo ya respondido.
--
-- Ranking:
--   - Mejor intento VÁLIDO por participante y desafío. Válido =
--     `estado = 'finalizada'` (todas las preguntas respondidas y
--     finalizada dentro del plazo). `incompleta` y `vencida` se
--     muestran en el historial, pero no compiten.
--   - Desempate: más puntos, luego menor `duracion_ms` (medida en el
--     servidor) y luego finalización más temprana.
--   - Repetir un desafío NO suma puntos: solo el mejor intento cuenta.
--     Cada inicio consume un intento; el límite lo controla el servidor.
-- =============================================================

-- -------------------------------------------------------------
-- EVENTO DE EXPO
-- -------------------------------------------------------------
create table if not exists public.eventos (
  id          uuid primary key default gen_random_uuid(),
  slug        text not null unique,
  titulo      text not null,
  descripcion text not null,
  inicia_en   timestamptz not null,
  termina_en  timestamptz not null,
  estado      text not null default 'borrador'
              check (estado in ('borrador', 'publicado', 'cerrado')),
  es_prueba   boolean not null default false,
  creado_en   timestamptz not null default now(),
  constraint eventos_fechas_coherentes check (termina_en > inicia_en)
);

comment on table public.eventos is
  'Evento de expo que agrupa desafíos. estado = borrador | publicado | cerrado. '
  'es_prueba marca eventos internos usados por las pruebas automáticas.';

comment on column public.eventos.es_prueba is
  'true: evento interno de pruebas. La interfaz de la expo lo oculta, pero la '
  'API lo puede leer para poder probar las funciones sin datos de producción.';

-- -------------------------------------------------------------
-- DESAFÍOS
-- -------------------------------------------------------------
create table if not exists public.desafios (
  id                  uuid primary key default gen_random_uuid(),
  evento_id           uuid not null references public.eventos (id) on delete cascade,
  slug                text not null,
  titulo              text not null,
  descripcion         text not null,
  dificultad          text not null
                      check (dificultad in ('facil', 'intermedio', 'dificil')),
  duracion_segundos   integer not null check (duracion_segundos > 0),
  puntos_por_acierto  integer not null check (puntos_por_acierto > 0),
  intentos_permitidos integer not null check (intentos_permitidos > 0),
  tolerancia_segundos integer not null default 30
                      check (tolerancia_segundos >= 0),
  es_prueba           boolean not null default false,
  estado              text not null default 'borrador'
                      check (estado in ('borrador', 'publicado', 'cerrado')),
  orden               integer not null check (orden > 0),
  creado_en           timestamptz not null default now(),
  unique (evento_id, slug)
);

comment on table public.desafios is
  'Definición de un desafío: dificultad, duración, puntos por acierto, '
  'intentos permitidos y tolerancia de reconexión. es_prueba marca desafíos '
  'internos usados por las pruebas automáticas.';

-- -------------------------------------------------------------
-- BANCO PROPIO DEL DESAFÍO (preguntas, opciones y soluciones)
-- -------------------------------------------------------------
create table if not exists public.desafio_preguntas (
  id          uuid primary key default gen_random_uuid(),
  desafio_id  uuid not null references public.desafios (id) on delete cascade,
  orden       integer not null check (orden > 0),
  enunciado   text not null,
  codigo      text,
  dificultad  text not null
              check (dificultad in ('facil', 'intermedio', 'dificil')),
  unique (desafio_id, orden)
);

comment on table public.desafio_preguntas is
  'Preguntas del banco del desafío. Son independientes de las preguntas de '
  'práctica: check_answer() no las consulta.';

create table if not exists public.desafio_opciones (
  id          uuid primary key default gen_random_uuid(),
  pregunta_id uuid not null references public.desafio_preguntas (id) on delete cascade,
  orden       integer not null check (orden > 0),
  texto       text not null,
  unique (pregunta_id, orden)
);

comment on table public.desafio_opciones is
  'Opciones visibles de una pregunta de desafío (sin marca de solución).';

create table if not exists public.desafio_soluciones (
  pregunta_id        uuid primary key
                     references public.desafio_preguntas (id) on delete cascade,
  opcion_correcta_id uuid not null
                     references public.desafio_opciones (id) on delete cascade,
  explicacion        text not null
);

comment on table public.desafio_soluciones is
  'Solución privada de cada pregunta de desafío. Sin política de lectura: '
  'solo la usan las funciones del servidor.';

-- -------------------------------------------------------------
-- PARTIDAS
-- -------------------------------------------------------------
create table if not exists public.partidas (
  id                  uuid primary key default gen_random_uuid(),
  participante_id     uuid not null references auth.users (id) on delete cascade,
  desafio_id          uuid not null references public.desafios (id) on delete cascade,
  clave_idempotencia  text not null,
  estado              text not null default 'en_curso'
                      check (estado in ('en_curso', 'finalizada', 'incompleta', 'vencida')),
  total_preguntas     integer not null default 0 check (total_preguntas >= 0),
  puntos              integer not null default 0 check (puntos >= 0),
  aciertos            integer not null default 0 check (aciertos >= 0),
  errores             integer not null default 0 check (errores >= 0),
  puntos_por_acierto  integer not null check (puntos_por_acierto > 0),
  duracion_segundos   integer not null check (duracion_segundos > 0),
  tolerancia_segundos integer not null default 0 check (tolerancia_segundos >= 0),
  iniciado_en         timestamptz not null default now(),
  expira_en           timestamptz not null,
  finalizado_en       timestamptz,
  duracion_ms         bigint check (duracion_ms is null or duracion_ms >= 0),
  constraint partidas_clave_unica unique (participante_id, clave_idempotencia),
  constraint partidas_totales_caben check (aciertos + errores <= total_preguntas),
  constraint partidas_finalizada_con_fecha check (
    (estado = 'en_curso' and finalizado_en is null) or
    (estado <> 'en_curso' and finalizado_en is not null)
  )
);

comment on table public.partidas is
  'Partida de un participante en un desafío. Guarda la foto de las reglas '
  '(puntos por acierto, duración y tolerancia), el inicio/cierre medidos en '
  'el servidor y el resultado. La clave de idempotencia evita duplicados.';

create index if not exists partidas_por_participante
  on public.partidas (participante_id, desafio_id, iniciado_en desc);

create index if not exists partidas_por_desafio
  on public.partidas (desafio_id, estado, puntos desc);

-- Preguntas asignadas a una partida (foto del banco al comenzar).
create table if not exists public.partida_preguntas (
  partida_id          uuid not null references public.partidas (id) on delete cascade,
  desafio_pregunta_id uuid not null
                      references public.desafio_preguntas (id) on delete cascade,
  orden               integer not null check (orden > 0),
  primary key (partida_id, desafio_pregunta_id),
  unique (partida_id, orden)
);

comment on table public.partida_preguntas is
  'Preguntas que aplican a una partida concreta. Se fijan al crearla y no '
  'cambian aunque después se edite el banco del desafío.';

create table if not exists public.partida_respuestas (
  id                  uuid primary key default gen_random_uuid(),
  partida_id          uuid not null references public.partidas (id) on delete cascade,
  desafio_pregunta_id uuid not null,
  desafio_opcion_id   uuid not null
                      references public.desafio_opciones (id) on delete cascade,
  correcto            boolean not null,
  puntos_obtenidos    integer not null check (puntos_obtenidos >= 0),
  respondido_en       timestamptz not null default now(),
  tiempo_ms           bigint not null check (tiempo_ms >= 0),
  constraint partida_respuestas_una_por_pregunta
    unique (partida_id, desafio_pregunta_id),
  constraint partida_respuestas_pregunta_asignada
    foreign key (partida_id, desafio_pregunta_id)
    references public.partida_preguntas (partida_id, desafio_pregunta_id)
    on delete cascade
);

comment on table public.partida_respuestas is
  'Una sola respuesta por partida y pregunta. La primera queda firme: un '
  'envío repetido devuelve el resultado existente sin volver a sumar.';

create index if not exists partida_respuestas_por_partida
  on public.partida_respuestas (partida_id);

-- -------------------------------------------------------------
-- RLS · CONTENIDO DEL DESAFÍO
--   - Eventos y desafíos publicados o cerrados: lectura pública.
--   - Banco de preguntas/opciones: lectura pública del desafío visible.
--   - Soluciones: sin lectura (solo funciones del servidor).
--   - es_prueba NO se filtra en la base: la interfaz de la expo lo
--     oculta. Así las pruebas automáticas pueden leer sus propios datos
--     sin usar service_role.
-- -------------------------------------------------------------
alter table public.eventos            enable row level security;
alter table public.desafios           enable row level security;
alter table public.desafio_preguntas  enable row level security;
alter table public.desafio_opciones   enable row level security;
alter table public.desafio_soluciones enable row level security;

drop policy if exists "eventos_lectura_publica" on public.eventos;
create policy "eventos_lectura_publica"
  on public.eventos
  for select
  to anon, authenticated
  using (estado in ('publicado', 'cerrado'));

drop policy if exists "desafios_lectura_publica" on public.desafios;
create policy "desafios_lectura_publica"
  on public.desafios
  for select
  to anon, authenticated
  using (
    estado in ('publicado', 'cerrado')
    and exists (
      select 1 from public.eventos e
      where e.id = desafios.evento_id
        and e.estado in ('publicado', 'cerrado')
    )
  );

drop policy if exists "desafio_preguntas_lectura_publica" on public.desafio_preguntas;
create policy "desafio_preguntas_lectura_publica"
  on public.desafio_preguntas
  for select
  to anon, authenticated
  using (
    exists (
      select 1
      from public.desafios d
      join public.eventos e on e.id = d.evento_id
      where d.id = desafio_preguntas.desafio_id
        and d.estado in ('publicado', 'cerrado')
        and e.estado in ('publicado', 'cerrado')
    )
  );

drop policy if exists "desafio_opciones_lectura_publica" on public.desafio_opciones;
create policy "desafio_opciones_lectura_publica"
  on public.desafio_opciones
  for select
  to anon, authenticated
  using (
    exists (
      select 1
      from public.desafio_preguntas dp
      join public.desafios d on d.id = dp.desafio_id
      join public.eventos e on e.id = d.evento_id
      where dp.id = desafio_opciones.pregunta_id
        and d.estado in ('publicado', 'cerrado')
        and e.estado in ('publicado', 'cerrado')
    )
  );

revoke all on public.desafio_soluciones from anon, authenticated;

-- -------------------------------------------------------------
-- RLS · PARTIDAS
--   - Cada participante lee solo sus partidas, preguntas asignadas y
--     respuestas.
--   - La escritura oficial es exclusiva de las funciones de abajo.
--   - NO se permite borrar partidas: borrarlas reiniciaría el límite de
--     intentos y permitiría borrar resultados malos antes del ranking.
-- -------------------------------------------------------------
alter table public.partidas           enable row level security;
alter table public.partida_preguntas  enable row level security;
alter table public.partida_respuestas enable row level security;

drop policy if exists "partidas_lectura_propia" on public.partidas;
create policy "partidas_lectura_propia"
  on public.partidas
  for select
  to authenticated
  using (participante_id = auth.uid());

drop policy if exists "partidas_borrado_propio" on public.partidas;

drop policy if exists "partida_preguntas_lectura_propia" on public.partida_preguntas;
create policy "partida_preguntas_lectura_propia"
  on public.partida_preguntas
  for select
  to authenticated
  using (
    exists (
      select 1 from public.partidas p
      where p.id = partida_preguntas.partida_id
        and p.participante_id = auth.uid()
    )
  );

drop policy if exists "partida_respuestas_lectura_propia" on public.partida_respuestas;
create policy "partida_respuestas_lectura_propia"
  on public.partida_respuestas
  for select
  to authenticated
  using (
    exists (
      select 1 from public.partidas p
      where p.id = partida_respuestas.partida_id
        and p.participante_id = auth.uid()
    )
  );

revoke all on public.eventos from anon, authenticated;
revoke all on public.desafios from anon, authenticated;
revoke all on public.desafio_preguntas from anon, authenticated;
revoke all on public.desafio_opciones from anon, authenticated;
revoke all on public.partidas from anon, authenticated;
revoke all on public.partida_preguntas from anon, authenticated;
revoke all on public.partida_respuestas from anon, authenticated;

grant select on public.eventos to anon, authenticated;
grant select on public.desafios to anon, authenticated;
grant select on public.desafio_preguntas to anon, authenticated;
grant select on public.desafio_opciones to anon, authenticated;
grant select on public.partidas to authenticated;
grant select on public.partida_preguntas to authenticated;
grant select on public.partida_respuestas to authenticated;

-- -------------------------------------------------------------
-- FUNCIÓN: iniciar_partida(desafio, clave)
--   Crea la partida, fija las preguntas y las reglas del intento.
--   Idempotente por (participante, clave). Consume un intento.
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
  insert into public.partida_preguntas (partida_id, desafio_pregunta_id, orden)
  select v_partida.id, dp.id, dp.orden
  from public.desafio_preguntas dp
  where dp.desafio_id = p_desafio
  order by dp.orden;

  return query
    select v_partida.id, v_partida.desafio_id, v_partida.estado,
           v_partida.total_preguntas, v_partida.puntos_por_acierto,
           v_partida.duracion_segundos, v_partida.tolerancia_segundos,
           v_partida.iniciado_en, v_partida.expira_en,
           v_usados + 1, v_desafio.intentos_permitidos, false;
end;
$$;

comment on function public.iniciar_partida(uuid, text) is
  'Crea la partida del usuario actual, fija sus preguntas y reglas y consume '
  'un intento. Repetir la misma clave devuelve la MISMA partida.';

-- -------------------------------------------------------------
-- FUNCIÓN: responder_partida(partida, pregunta, opción)
--   Valida y guarda la primera respuesta. Calcula los puntos en el
--   servidor. Un envío repetido devuelve el resultado existente.
-- -------------------------------------------------------------
create or replace function public.responder_partida(
  p_partida  uuid,
  p_pregunta uuid,
  p_opcion   uuid
)
returns table (
  correcto        boolean,
  puntos_obtenidos integer,
  puntos_totales  integer,
  respondidas     integer,
  total_preguntas integer,
  repetida        boolean,
  expira_en       timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid         uuid := auth.uid();
  v_partida     public.partidas;
  v_solucion    public.desafio_soluciones;
  v_respuesta   public.partida_respuestas;
  v_insertadas  integer;
  v_respondidas integer;
begin
  if v_uid is null then
    raise exception 'PR_AUTH_REQUIRED'
      using hint = 'Se necesita una sesión para responder un desafío.';
  end if;

  select * into v_partida
  from public.partidas
  where id = p_partida
    and participante_id = v_uid
  for update;

  if not found then
    raise exception 'PR_PARTIDA_NOT_FOUND'
      using hint = 'La partida no existe o no pertenece a este participante.';
  end if;

  if not exists (
    select 1 from public.partida_preguntas pp
    where pp.partida_id = p_partida
      and pp.desafio_pregunta_id = p_pregunta
  ) then
    raise exception 'PR_PREGUNTA_NO_ASIGNADA'
      using hint = 'La pregunta no pertenece a esta partida.';
  end if;

  if not exists (
    select 1 from public.desafio_opciones o
    where o.id = p_opcion
      and o.pregunta_id = p_pregunta
  ) then
    raise exception 'PR_OPCION_INVALIDA'
      using hint = 'La opción no pertenece a la pregunta indicada.';
  end if;

  -- Si ya hay respuesta, se devuelve tal cual (no vuelve a sumar), incluso
  -- si la partida ya se cerró o venció: es un reintento de la misma
  -- petición, no una respuesta nueva.
  select * into v_respuesta
  from public.partida_respuestas
  where partida_id = p_partida
    and desafio_pregunta_id = p_pregunta;

  if found then
    select count(*) into v_respondidas
    from public.partida_respuestas
    where partida_id = p_partida;

    return query
      select v_respuesta.correcto, v_respuesta.puntos_obtenidos,
             v_partida.puntos, v_respondidas, v_partida.total_preguntas,
             true, v_partida.expira_en;
    return;
  end if;

  if v_partida.estado <> 'en_curso' then
    raise exception 'PR_PARTIDA_CERRADA'
      using hint = 'La partida ya está cerrada.';
  end if;

  if now() > v_partida.expira_en then
    raise exception 'PR_PARTIDA_EXPIRADA'
      using hint = 'El tiempo de la partida terminó.';
  end if;

  select * into v_solucion
  from public.desafio_soluciones
  where pregunta_id = p_pregunta;

  if not found then
    raise exception 'PR_SOLUCION_NO_DISPONIBLE'
      using hint = 'La pregunta no tiene una solución cargada.';
  end if;

  insert into public.partida_respuestas (
    partida_id, desafio_pregunta_id, desafio_opcion_id, correcto,
    puntos_obtenidos, tiempo_ms
  )
  values (
    p_partida, p_pregunta, p_opcion,
    (v_solucion.opcion_correcta_id = p_opcion),
    case when v_solucion.opcion_correcta_id = p_opcion
         then v_partida.puntos_por_acierto else 0 end,
    greatest(
      0,
      (extract(epoch from (now() - v_partida.iniciado_en)) * 1000)::bigint
    )
  )
  on conflict (partida_id, desafio_pregunta_id) do nothing
  returning * into v_respuesta;

  get diagnostics v_insertadas = row_count;

  if v_insertadas = 0 then
    -- Otra petición simultánea ganó: se devuelve la respuesta existente.
    select * into v_respuesta
    from public.partida_respuestas
    where partida_id = p_partida
      and desafio_pregunta_id = p_pregunta;
  end if;

  -- Los totales de la partida siempre reflejan las respuestas guardadas.
  update public.partidas p
     set aciertos = (
           select count(*) from public.partida_respuestas r
           where r.partida_id = p_partida and r.correcto
         ),
         errores = (
           select count(*) from public.partida_respuestas r
           where r.partida_id = p_partida and not r.correcto
         ),
         puntos = (
           select coalesce(sum(r.puntos_obtenidos), 0)
           from public.partida_respuestas r
           where r.partida_id = p_partida
         )
   where p.id = p_partida
   returning * into v_partida;

  select count(*) into v_respondidas
  from public.partida_respuestas
  where partida_id = p_partida;

  return query
    select v_respuesta.correcto, v_respuesta.puntos_obtenidos,
           v_partida.puntos, v_respondidas, v_partida.total_preguntas,
           (v_insertadas = 0), v_partida.expira_en;
end;
$$;

comment on function public.responder_partida(uuid, uuid, uuid) is
  'Valida y guarda la primera respuesta de una pregunta de la partida. '
  'Calcula los puntos en el servidor; repetir devuelve el resultado existente.';

-- -------------------------------------------------------------
-- FUNCIÓN: finalizar_partida(partida)
--   Cierra la partida de forma consistente e idempotente.
--   - finalizada: todas respondidas y cierre dentro del plazo.
--   - incompleta: se finalizó antes del cierre con preguntas sin responder.
--   - vencida: pasó el plazo de reconexión sin finalizar.
-- -------------------------------------------------------------
create or replace function public.finalizar_partida(
  p_partida uuid
)
returns table (
  partida         uuid,
  desafio         uuid,
  estado          text,
  total_preguntas integer,
  respondidas     integer,
  aciertos        integer,
  errores         integer,
  puntos          integer,
  duracion_ms     bigint,
  iniciado_en     timestamptz,
  expira_en       timestamptz,
  finalizado_en   timestamptz,
  reutilizado     boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid         uuid := auth.uid();
  v_partida     public.partidas;
  v_respondidas integer;
  v_aciertos    integer;
  v_errores     integer;
  v_puntos      integer;
  v_ultima      timestamptz;
  v_estado      text;
  v_duracion    bigint;
begin
  if v_uid is null then
    raise exception 'PR_AUTH_REQUIRED'
      using hint = 'Se necesita una sesión para finalizar una partida.';
  end if;

  select * into v_partida
  from public.partidas
  where id = p_partida
    and participante_id = v_uid
  for update;

  if not found then
    raise exception 'PR_PARTIDA_NOT_FOUND'
      using hint = 'La partida no existe o no pertenece a este participante.';
  end if;

  if v_partida.estado <> 'en_curso' then
    select count(*) into v_respondidas
    from public.partida_respuestas
    where partida_id = p_partida;
    return query
      select v_partida.id, v_partida.desafio_id, v_partida.estado,
             v_partida.total_preguntas, v_respondidas, v_partida.aciertos,
             v_partida.errores, v_partida.puntos, v_partida.duracion_ms,
             v_partida.iniciado_en, v_partida.expira_en,
             v_partida.finalizado_en, true;
    return;
  end if;

  select count(*),
         count(*) filter (where correcto),
         count(*) filter (where not correcto),
         coalesce(sum(puntos_obtenidos), 0),
         max(respondido_en)
    into v_respondidas, v_aciertos, v_errores, v_puntos, v_ultima
  from public.partida_respuestas
  where partida_id = p_partida;

  if now() > v_partida.expira_en
     + make_interval(secs => v_partida.tolerancia_segundos) then
    v_estado := 'vencida';
  elsif v_respondidas < v_partida.total_preguntas then
    v_estado := 'incompleta';
  else
    v_estado := 'finalizada';
  end if;

  -- Desempate medido en el servidor: tiempo hasta la última respuesta.
  v_duracion := greatest(
    0,
    (extract(epoch from (
      coalesce(v_ultima, now()) - v_partida.iniciado_en
    )) * 1000)::bigint
  );

  update public.partidas p
     set estado = v_estado,
         aciertos = v_aciertos,
         errores = v_errores,
         puntos = v_puntos,
         finalizado_en = now(),
         duracion_ms = v_duracion
   where p.id = p_partida
   returning * into v_partida;

  return query
    select v_partida.id, v_partida.desafio_id, v_partida.estado,
           v_partida.total_preguntas, v_respondidas, v_partida.aciertos,
           v_partida.errores, v_partida.puntos, v_partida.duracion_ms,
           v_partida.iniciado_en, v_partida.expira_en,
           v_partida.finalizado_en, false;
end;
$$;

comment on function public.finalizar_partida(uuid) is
  'Cierra la partida: calcula el resultado con las respuestas guardadas, '
  'marca finalizada/incompleta/vencida y es idempotente.';

-- -------------------------------------------------------------
-- FUNCIÓN: resultado_partida(partida)
--   Detalle con la opción elegida y el resultado. La solución y la
--   explicación solo se revelan cuando el desafío o el evento cerraron:
--   mientras el desafío está activo, revelarlas permitiría mejorar un
--   segundo intento (o soplarle a otra persona).
-- -------------------------------------------------------------
create or replace function public.resultado_partida(
  p_partida uuid
)
returns table (
  orden                 integer,
  enunciado             text,
  codigo                text,
  dificultad            text,
  opcion_elegida_id     uuid,
  opcion_elegida_texto  text,
  opcion_correcta_id    uuid,
  opcion_correcta_texto text,
  correcto              boolean,
  explicacion           text,
  puntos_obtenidos      integer,
  respondida            boolean,
  tiempo_ms             bigint,
  revelado              boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid            uuid := auth.uid();
  v_partida        public.partidas;
  v_desafio_estado text;
  v_evento_estado  text;
  v_termina_en     timestamptz;
  v_revelar        boolean;
begin
  if v_uid is null then
    raise exception 'PR_AUTH_REQUIRED'
      using hint = 'Se necesita una sesión para ver el resultado.';
  end if;

  select * into v_partida
  from public.partidas
  where id = p_partida
    and participante_id = v_uid;

  if not found then
    raise exception 'PR_PARTIDA_NOT_FOUND'
      using hint = 'La partida no existe o no pertenece a este participante.';
  end if;

  if v_partida.estado = 'en_curso' then
    raise exception 'PR_PARTIDA_EN_CURSO'
      using hint = 'La partida todavía está en curso.';
  end if;

  select d.estado, e.estado, e.termina_en
    into v_desafio_estado, v_evento_estado, v_termina_en
  from public.desafios d
  join public.eventos e on e.id = d.evento_id
  where d.id = v_partida.desafio_id;

  v_revelar := v_desafio_estado = 'cerrado'
               or v_evento_estado = 'cerrado'
               or now() > v_termina_en;

  return query
    select dp.orden, dp.enunciado, dp.codigo, dp.dificultad,
           r.desafio_opcion_id, oe.texto,
           case when v_revelar then s.opcion_correcta_id end,
           case when v_revelar then oc.texto end,
           coalesce(r.correcto, false),
           case when v_revelar then s.explicacion end,
           coalesce(r.puntos_obtenidos, 0),
           (r.id is not null),
           coalesce(r.tiempo_ms, 0),
           v_revelar
    from public.partida_preguntas pp
    join public.desafio_preguntas dp
      on dp.id = pp.desafio_pregunta_id
    join public.desafio_soluciones s
      on s.pregunta_id = dp.id
    join public.desafio_opciones oc
      on oc.id = s.opcion_correcta_id
    left join public.partida_respuestas r
      on r.partida_id = pp.partida_id
     and r.desafio_pregunta_id = pp.desafio_pregunta_id
    left join public.desafio_opciones oe
      on oe.id = r.desafio_opcion_id
    where pp.partida_id = p_partida
    order by dp.orden;
end;
$$;

comment on function public.resultado_partida(uuid) is
  'Detalle de una partida cerrada. Mientras el desafío siga activo no revela '
  'la opción correcta ni la explicación; solo lo hace al cerrar.';

-- -------------------------------------------------------------
-- FUNCIÓN: hora_servidor()
--   Hora oficial del servidor. El cliente la usa solo para mostrar el
--   reloj y los plazos; las validaciones reales siempre usan now() en
--   las funciones de arriba.
-- -------------------------------------------------------------
create or replace function public.hora_servidor()
returns table (hora timestamptz)
language sql
stable
security definer
set search_path = public
as $$
  select now() as hora;
$$;

comment on function public.hora_servidor() is
  'Hora oficial del servidor para mostrar el temporizador sin depender del '
  'reloj del celular. Las reglas se validan igual con now() en cada función.';

-- -------------------------------------------------------------
-- FUNCIÓN: ranking_desafio(desafio, límite)
--   Mejor intento válido por participante. Desempate: puntos, menor
--   duración medida en el servidor y finalización más temprana.
-- -------------------------------------------------------------
create or replace function public.ranking_desafio(
  p_desafio uuid,
  p_limite  integer default 50
)
returns table (
  posicion        bigint,
  alias           text,
  alias_sufijo    text,
  puntos          integer,
  aciertos        integer,
  total_preguntas integer,
  duracion_ms     bigint,
  finalizado_en   timestamptz,
  es_yo           boolean,
  partida         uuid
)
language sql
security definer
set search_path = public
as $$
  with mejores as (
    select distinct on (pa.participante_id)
      pa.id,
      pa.participante_id,
      pa.puntos,
      pa.aciertos,
      pa.total_preguntas,
      pa.duracion_ms,
      pa.finalizado_en,
      pa.iniciado_en
    from public.partidas pa
    where pa.desafio_id = p_desafio
      and pa.estado = 'finalizada'
    order by pa.participante_id,
             pa.puntos desc,
             pa.duracion_ms asc nulls last,
             pa.finalizado_en asc,
             pa.iniciado_en asc
  )
  select
    row_number() over (
      order by m.puntos desc,
               m.duracion_ms asc nulls last,
               m.finalizado_en asc,
               m.iniciado_en asc
    ) as posicion,
    pf.alias,
    pf.alias_sufijo,
    m.puntos,
    m.aciertos,
    m.total_preguntas,
    m.duracion_ms,
    m.finalizado_en,
    (m.participante_id = auth.uid()) as es_yo,
    m.id as partida
  from mejores m
  join public.perfiles pf on pf.id = m.participante_id
  order by posicion
  limit greatest(1, least(coalesce(p_limite, 50), 200));
$$;

comment on function public.ranking_desafio(uuid, integer) is
  'Ranking del desafío: mejor intento válido por participante, ordenado por '
  'puntos, menor duración del servidor y finalización más temprana.';

-- -------------------------------------------------------------
-- PERMISOS DE LAS FUNCIONES
--   - Jugar exige sesión (invitado o cuenta).
--   - El ranking es público: un visitante puede verlo sin sesión.
-- -------------------------------------------------------------
revoke all on function public.iniciar_partida(uuid, text) from public;
revoke all on function public.responder_partida(uuid, uuid, uuid) from public;
revoke all on function public.finalizar_partida(uuid) from public;
revoke all on function public.resultado_partida(uuid) from public;
revoke all on function public.ranking_desafio(uuid, integer) from public;
revoke all on function public.hora_servidor() from public;

grant execute on function public.iniciar_partida(uuid, text) to authenticated;
grant execute on function public.responder_partida(uuid, uuid, uuid) to authenticated;
grant execute on function public.finalizar_partida(uuid) to authenticated;
grant execute on function public.resultado_partida(uuid) to authenticated;
grant execute on function public.ranking_desafio(uuid, integer) to anon, authenticated;
grant execute on function public.hora_servidor() to anon, authenticated;

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
  ('70000000-0000-0000-0000-000000010402', '60000000-0000-0000-0000-000000010104', 2, '[''a'', ''b'']'),
  ('70000000-0000-0000-0000-000000010403', '60000000-0000-0000-0000-000000010104', 3, '''a, b'''),
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
  ('70000000-0000-0000-0000-000000910301', '60000000-0000-0000-0000-000000910103', 1, '''hola'''),
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


-- =============================================================
-- Doulingo � 0008_ranking_admin.sql
-- =============================================================
-- Doulingo · 0008_ranking_admin.sql
-- Proyección pública para la pantalla de expo y permisos administrativos.
-- No contiene correos, contraseñas, respuestas ni UUID de participantes.

create table if not exists public.resultados_publicos (
  id uuid primary key default gen_random_uuid(),
  evento_id uuid not null references public.eventos(id) on delete cascade,
  desafio text not null,
  alias text not null,
  puntos integer not null check (puntos >= 0),
  duracion_ms bigint check (duracion_ms is null or duracion_ms >= 0),
  finalizado_en timestamptz not null default now(),
  publicado_en timestamptz not null default now()
);

create index if not exists resultados_publicos_evento_orden
  on public.resultados_publicos (evento_id, puntos desc, duracion_ms, finalizado_en);

alter table public.resultados_publicos enable row level security;
drop policy if exists "resultados_publicos_lectura" on public.resultados_publicos;
create policy "resultados_publicos_lectura" on public.resultados_publicos
  for select to anon, authenticated using (
    exists (select 1 from public.eventos e
            where e.id = resultados_publicos.evento_id
              and e.estado in ('publicado', 'cerrado'))
  );
revoke all on public.resultados_publicos from anon, authenticated;
grant select on public.resultados_publicos to anon, authenticated;

create or replace function public.publicar_resultado()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_evento uuid; v_titulo text; v_alias text; v_sufijo text;
begin
  if new.estado = 'finalizada' and (tg_op = 'INSERT' or old.estado is distinct from new.estado) then
    select d.evento_id, d.titulo into v_evento, v_titulo
      from public.desafios d where d.id = new.desafio_id;
    select p.alias, p.alias_sufijo into v_alias, v_sufijo
      from public.perfiles p where p.id = new.participante_id;
    if v_evento is not null and v_alias is not null then
      insert into public.resultados_publicos
        (evento_id, desafio, alias, puntos, duracion_ms, finalizado_en)
      values (v_evento, v_titulo, v_alias || '#' || v_sufijo,
              new.puntos, new.duracion_ms, coalesce(new.finalizado_en, now()));
    end if;
  end if;
  return new;
end $$;

drop trigger if exists partidas_publicar_resultado on public.partidas;
create trigger partidas_publicar_resultado after insert or update of estado on public.partidas
  for each row execute function public.publicar_resultado();

-- Carga inicial: publica resultados ya finalizados al instalar esta migración.
insert into public.resultados_publicos
  (evento_id, desafio, alias, puntos, duracion_ms, finalizado_en)
select d.evento_id, d.titulo, p.alias || '#' || p.alias_sufijo,
       pa.puntos, pa.duracion_ms, pa.finalizado_en
from public.partidas pa
join public.desafios d on d.id = pa.desafio_id
join public.perfiles p on p.id = pa.participante_id
where pa.estado = 'finalizada'
  and not exists (
    select 1 from public.resultados_publicos r
    where r.evento_id = d.evento_id and r.desafio = d.titulo
      and r.alias = p.alias || '#' || p.alias_sufijo
      and r.puntos = pa.puntos and r.finalizado_en = pa.finalizado_en
  );

-- Ranking público de una exposición. La elegibilidad y desempate son los de etapa 6:
-- solo finalizada; por alias y desafío queda el mejor resultado; puntos, menor tiempo,
-- finalización más temprana. La respuesta contiene únicamente posición, alias, puntaje
-- y desafío (no se devuelve ningún identificador privado).
create or replace function public.ranking_evento(p_evento uuid, p_limite integer default 100)
returns table (posicion bigint, alias text, puntaje integer, desafio text)
language sql security definer set search_path = public as $$
  with elegibles as (
    select distinct on (r.alias, r.desafio)
      r.alias, r.puntos, r.desafio, r.duracion_ms, r.finalizado_en
    from public.resultados_publicos r
    where r.evento_id = p_evento
    order by r.alias, r.desafio, r.puntos desc, r.duracion_ms asc nulls last,
             r.finalizado_en asc
  ), puestos as (
    select row_number() over (order by e.puntos desc, e.duracion_ms asc nulls last,
                              e.finalizado_en asc, e.alias asc) as posicion,
           e.alias, e.puntos as puntaje, e.desafio
    from elegibles e
  )
  select * from puestos order by posicion
  limit greatest(1, least(coalesce(p_limite, 100), 200));
$$;
revoke all on function public.ranking_evento(uuid, integer) from public;
grant execute on function public.ranking_evento(uuid, integer) to anon, authenticated;

-- Realtime solo notifica la proyección pública, nunca partidas privadas.
do $$ begin
  alter publication supabase_realtime add table public.resultados_publicos;
exception when duplicate_object then null; end $$;

-- Roles administrados por servidor: no se deriva el rol de perfiles ni de metadata
-- editable por el cliente. Solo el propietario del proyecto/SQL puede asignarlos.
create table if not exists public.admin_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  rol text not null check (rol in ('admin', 'editor')),
  asignado_en timestamptz not null default now()
);
alter table public.admin_roles enable row level security;
revoke all on public.admin_roles from anon, authenticated;

create or replace function public.es_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admin_roles where user_id = auth.uid() and rol = 'admin');
$$;
revoke all on function public.es_admin() from public;
grant execute on function public.es_admin() to authenticated;

-- CRUD de contenido y eventos: la interfaz no es la barrera de seguridad.
do $policies$
declare t text;
begin
  foreach t in array array['cursos','unidades','lecciones','preguntas','opciones','soluciones','eventos','desafios','desafio_preguntas','desafio_opciones','desafio_soluciones'] loop
    execute format('drop policy if exists %I on public.%I', 'admin_all_' || t, t);
    execute format('create policy %I on public.%I for all to authenticated using (public.es_admin()) with check (public.es_admin())', 'admin_all_' || t, t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
  end loop;
end $policies$;

create or replace function public.validar_leccion(p_leccion uuid)
returns void language plpgsql security definer set search_path = public as $$
declare n integer; correctas integer;
begin
  if not public.es_admin() then raise exception 'PR_ADMIN_REQUIRED'; end if;
  select count(*) into n from preguntas where leccion_id = p_leccion;
  if n = 0 then raise exception 'PR_LECCION_INCOMPLETA'; end if;
  select count(*) into correctas from preguntas p
    where p.leccion_id = p_leccion and exists (
      select 1 from soluciones s join opciones o on o.id=s.opcion_correcta_id
      where s.pregunta_id=p.id and o.pregunta_id=p.id);
  if correctas <> n then raise exception 'PR_LECCION_INCOMPLETA'; end if;
end $$;
revoke all on function public.validar_leccion(uuid) from public;
grant execute on function public.validar_leccion(uuid) to authenticated;

create or replace function public.validar_unidad_publicable()
returns trigger language plpgsql security definer set search_path = public as $$
declare l record;
begin
  if new.disponible then
    for l in select id from public.lecciones where unidad_id = new.id loop
      perform public.validar_leccion(l.id);
    end loop;
  end if;
  return new;
end $$;
drop trigger if exists validar_unidad_antes_publicar on public.unidades;
create trigger validar_unidad_antes_publicar before insert or update of disponible on public.unidades
  for each row when (new.disponible = true) execute function public.validar_unidad_publicable();

create or replace function public.validar_desafio_publicable()
returns trigger language plpgsql security definer set search_path = public as $$
declare n integer; v integer;
begin
  if new.estado = 'publicado' then
    select count(*) into n from public.desafio_preguntas where desafio_id = new.id;
    select count(*) into v from public.desafio_preguntas p where p.desafio_id = new.id and exists (
      select 1 from public.desafio_soluciones s join public.desafio_opciones o on o.id=s.opcion_correcta_id
      where s.pregunta_id=p.id and o.pregunta_id=p.id);
    if n = 0 or v <> n then raise exception 'PR_DESAFIO_INCOMPLETO'; end if;
  end if;
  return new;
end $$;
drop trigger if exists validar_desafio_antes_publicar on public.desafios;
create trigger validar_desafio_antes_publicar before insert or update of estado on public.desafios
  for each row when (new.estado = 'publicado') execute function public.validar_desafio_publicable();

comment on table public.resultados_publicos is 'Proyección mínima para Realtime: solo alias, puntaje, desafío y orden temporal.';
comment on table public.admin_roles is 'Asignación de permisos controlada por servidor; nunca editable desde perfiles.';


-- =============================================================
-- Doulingo � 0009_admin_content_guards.sql
-- =============================================================
-- Corrección incremental para instalaciones que ya aplicaron 0008.
grant select on public.soluciones, public.desafio_soluciones to authenticated;

create or replace function public.validar_contenido_admin()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_table_name in ('opciones', 'desafio_opciones') then
    if exists (select 1 from public.opciones o where tg_table_name = 'opciones' and o.pregunta_id = new.pregunta_id
      and lower(trim(o.texto)) = lower(trim(new.texto)) and o.id <> new.id) then
      raise exception 'PR_OPCIONES_DUPLICADAS';
    end if;
    if exists (select 1 from public.desafio_opciones o where tg_table_name = 'desafio_opciones' and o.pregunta_id = new.pregunta_id
      and lower(trim(o.texto)) = lower(trim(new.texto)) and o.id <> new.id) then
      raise exception 'PR_OPCIONES_DUPLICADAS';
    end if;
  elsif tg_table_name in ('soluciones', 'desafio_soluciones') then
    if not exists (select 1 from public.opciones o where o.id = new.opcion_correcta_id
      and o.pregunta_id = new.pregunta_id)
      and tg_table_name = 'soluciones'
      or not exists (select 1 from public.desafio_opciones o where o.id = new.opcion_correcta_id
      and o.pregunta_id = new.pregunta_id) and tg_table_name = 'desafio_soluciones' then
      raise exception 'PR_SOLUCION_OPCION_INVALIDA';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists validar_opcion_admin on public.opciones;
create trigger validar_opcion_admin before insert or update on public.opciones
  for each row execute function public.validar_contenido_admin();
drop trigger if exists validar_solucion_admin on public.soluciones;
create trigger validar_solucion_admin before insert or update on public.soluciones
  for each row execute function public.validar_contenido_admin();
drop trigger if exists validar_opcion_desafio_admin on public.desafio_opciones;
create trigger validar_opcion_desafio_admin before insert or update on public.desafio_opciones
  for each row execute function public.validar_contenido_admin();
drop trigger if exists validar_solucion_desafio_admin on public.desafio_soluciones;
create trigger validar_solucion_desafio_admin before insert or update on public.desafio_soluciones
  for each row execute function public.validar_contenido_admin();
