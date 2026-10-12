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