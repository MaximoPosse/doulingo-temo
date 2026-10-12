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