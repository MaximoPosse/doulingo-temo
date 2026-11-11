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

-- Las opciones no pueden repetirse dentro de una pregunta y una solución debe
-- apuntar a una opción de esa misma pregunta (no solo cumplir el FK global).
create or replace function public.validar_contenido_admin()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_table_name = 'opciones' then
    if exists (select 1 from public.opciones o where o.pregunta_id = new.pregunta_id
      and lower(trim(o.texto)) = lower(trim(new.texto)) and o.id <> new.id) then
      raise exception 'PR_OPCIONES_DUPLICADAS';
    end if;
  elsif tg_table_name = 'soluciones' then
    if not exists (select 1 from public.opciones o where o.id = new.opcion_correcta_id
      and o.pregunta_id = new.pregunta_id) then
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
