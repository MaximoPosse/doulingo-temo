-- =============================================================
-- CodeLingua · 0014_minijuego.sql
-- Minijuego "Ruta del robot" para sumar puntos al ranking de la expo.
--
--   - Se desbloquea cuando la persona terminó el Gran desafío (ya no le
--     quedan intentos).
--   - 6 niveles con tablero, obstáculos y estrellas. Se programa al robot con
--     bloques: avanzar, girar y repetir (bucle).
--   - El SERVIDOR simula el recorrido (enviar_ruta): la persona manda su
--     programa y el servidor decide si llegó a la meta y cuántos puntos
--     vale. Por nivel queda el mejor resultado.
--   - Puntos de un nivel: 5 por llegar + 3 por estrella + hasta 7 de
--     bonificación por usar pocos bloques (par del nivel).
--   - Los puntos del minijuego se suman al ranking del Gran desafío y al
--     ranking público del evento.
--
-- Ejecutable varias veces.
-- =============================================================

alter table public.desafios add column if not exists minijuego boolean not null default false;
update public.desafios set minijuego = true where id = '50000000-0000-0000-0000-000000000010';

-- -------------------------------------------------------------
-- NIVELES (datos públicos: no hay nada secreto en un tablero)
-- -------------------------------------------------------------
create table if not exists public.minijuego_niveles (
  id        uuid primary key default gen_random_uuid(),
  orden     integer not null unique check (orden > 0),
  nombre    text not null,
  consejo   text not null,
  n         integer not null check (n between 4 and 8),
  inicio    integer not null,
  rumbo     integer not null check (rumbo between 0 and 3),
  meta      integer not null,
  muros     integer[] not null default '{}',
  estrellas integer[] not null default '{}',
  par       integer not null check (par > 0)
);

insert into public.minijuego_niveles
  (id, orden, nombre, consejo, n, inicio, rumbo, meta, muros, estrellas, par) values
  ('a0000000-0000-0000-0000-000000000001', 1, 'Primer paso', 'Avanzá en línea recta. ¿Probaste el bucle "Repetir"?', 5, 22, 0, 2, array[6, 8, 16, 18], array[12], 4),
  ('a0000000-0000-0000-0000-000000000002', 2, 'La esquina', 'Girá en la esquina y repetí los avances.', 5, 20, 0, 4, array[6, 7, 8, 16, 17, 18], array[9, 21], 10),
  ('a0000000-0000-0000-0000-000000000003', 3, 'El laberinto', 'Con más espacio hay más caminos: buscá el más corto.', 6, 30, 0, 5, array[1, 7, 9, 10, 13, 19, 20, 21, 23, 29, 32, 33, 34, 35], array[11, 24], 14),
  ('a0000000-0000-0000-0000-000000000004', 4, 'Escalera', 'Un patrón que se repite: avanzar, girar, avanzar, girar.', 5, 20, 0, 4, array[6, 7, 12, 16], array[8, 11, 23], 21),
  ('a0000000-0000-0000-0000-000000000005', 5, 'Doble vuelta', 'Recogé las estrellas antes de llegar a la meta.', 6, 30, 1, 5, array[3, 7, 9, 11, 13, 19, 20, 21, 22, 32], array[0, 14, 25], 24),
  ('a0000000-0000-0000-0000-000000000006', 6, 'Gran final', 'El nivel más largo: pensá en bucles dentro de bucles.', 6, 30, 0, 5, array[3, 7, 9, 13, 17, 19, 20, 21, 22, 32, 35], array[4, 14, 26], 27)
on conflict (id) do update set
  orden = excluded.orden, nombre = excluded.nombre, consejo = excluded.consejo,
  n = excluded.n, inicio = excluded.inicio, rumbo = excluded.rumbo,
  meta = excluded.meta, muros = excluded.muros, estrellas = excluded.estrellas,
  par = excluded.par;

-- -------------------------------------------------------------
-- RESULTADOS (mejor intento por persona y nivel)
-- -------------------------------------------------------------
create table if not exists public.minijuego_resultados (
  participante_id uuid not null references auth.users (id) on delete cascade,
  nivel_id        uuid not null references public.minijuego_niveles (id) on delete cascade,
  puntos          integer not null check (puntos >= 0),
  bloques         integer not null check (bloques > 0),
  pasos           integer not null check (pasos >= 0),
  estrellas       integer not null check (estrellas >= 0),
  programa        jsonb not null,
  actualizado_en  timestamptz not null default now(),
  primary key (participante_id, nivel_id)
);

alter table public.minijuego_niveles enable row level security;
alter table public.minijuego_resultados enable row level security;

drop policy if exists "minijuego_niveles_lectura" on public.minijuego_niveles;
create policy "minijuego_niveles_lectura" on public.minijuego_niveles
  for select to anon, authenticated using (true);

drop policy if exists "minijuego_resultados_propios" on public.minijuego_resultados;
create policy "minijuego_resultados_propios" on public.minijuego_resultados
  for select to authenticated using (participante_id = auth.uid());

revoke all on public.minijuego_niveles, public.minijuego_resultados from anon, authenticated;
grant select on public.minijuego_niveles to anon, authenticated;
grant select on public.minijuego_resultados to authenticated;

-- -------------------------------------------------------------
-- Programa: se expande a la lista de pasos que se ejecutan.
--   ["A", "I", "D", {"r": 3, "p": ["A", "D"]}]
-- -------------------------------------------------------------
create or replace function public.minijuego_expandir(p_programa jsonb, p_prof integer default 0)
returns text[]
language plpgsql
immutable
as $$
declare
  v_pasos   text[] := '{}';
  v_bloque  jsonb;
  v_veces   integer;
  v_interno text[];
  v_i       integer;
begin
  if p_prof > 2 then
    raise exception 'PR_PROGRAMA_INVALIDO' using hint = 'Demasiados bucles anidados.';
  end if;
  if jsonb_typeof(p_programa) <> 'array' then
    raise exception 'PR_PROGRAMA_INVALIDO' using hint = 'El programa debe ser una lista.';
  end if;
  for v_bloque in select * from jsonb_array_elements(p_programa) loop
    if jsonb_typeof(v_bloque) = 'string' then
      if (v_bloque #>> '{}') not in ('A', 'I', 'D') then
        raise exception 'PR_PROGRAMA_INVALIDO' using hint = 'Instrucción no válida.';
      end if;
      v_pasos := v_pasos || (v_bloque #>> '{}');
    elsif jsonb_typeof(v_bloque) = 'object' then
      if jsonb_typeof(v_bloque -> 'r') <> 'number'
         or (v_bloque ->> 'r') !~ '^[0-9]+$' then
        raise exception 'PR_PROGRAMA_INVALIDO' using hint = 'Repeticiones no válidas.';
      end if;
      v_veces := (v_bloque ->> 'r')::integer;
      if v_veces < 1 or v_veces > 9 then
        raise exception 'PR_PROGRAMA_INVALIDO' using hint = 'Repeticiones no válidas.';
      end if;
      v_interno := public.minijuego_expandir(coalesce(v_bloque -> 'p', '[]'::jsonb), p_prof + 1);
      for v_i in 1..v_veces loop
        v_pasos := v_pasos || v_interno;
      end loop;
    else
      raise exception 'PR_PROGRAMA_INVALIDO' using hint = 'Bloque no válido.';
    end if;
    if coalesce(array_length(v_pasos, 1), 0) > 200 then
      raise exception 'PR_PROGRAMA_INVALIDO' using hint = 'El recorrido es demasiado largo.';
    end if;
  end loop;
  return v_pasos;
end;
$$;

-- Cantidad de bloques escritos: cada instrucción cuenta 1 y cada bucle cuenta
-- 1 más lo que tiene adentro.
create or replace function public.minijuego_bloques(p_programa jsonb)
returns integer
language plpgsql
immutable
as $$
declare
  v_total  integer := 0;
  v_bloque jsonb;
begin
  for v_bloque in select * from jsonb_array_elements(p_programa) loop
    v_total := v_total + 1;
    if jsonb_typeof(v_bloque) = 'object' then
      v_total := v_total + public.minijuego_bloques(coalesce(v_bloque -> 'p', '[]'::jsonb));
    end if;
  end loop;
  return v_total;
end;
$$;

-- ¿Puede jugar el minijuego? Sí cuando terminó el Gran desafío: tiene al
-- menos una partida cerrada y ya usó todos sus intentos.
create or replace function public.minijuego_desbloqueado(p_desafio uuid default '50000000-0000-0000-0000-000000000010')
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(auth.uid() is not null
    and exists (select 1 from public.desafios d where d.id = p_desafio and d.minijuego)
    and not exists (select 1 from public.partidas pa
                    where pa.participante_id = auth.uid()
                      and pa.desafio_id = p_desafio and pa.estado = 'en_curso')
    and (select count(*) from public.partidas pa
         where pa.participante_id = auth.uid() and pa.desafio_id = p_desafio)
        >= (select d.intentos_permitidos from public.desafios d where d.id = p_desafio), false);
$$;

-- -------------------------------------------------------------
-- enviar_ruta: el servidor simula el recorrido y calcula los puntos.
-- -------------------------------------------------------------
create or replace function public.enviar_ruta(p_nivel uuid, p_programa jsonb)
returns table (
  llego            boolean,
  choco            boolean,
  bloques          integer,
  pasos            integer,
  estrellas        integer,
  puntos           integer,
  mejor_puntos     integer,
  mejoro           boolean,
  total_minijuego  integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid       uuid := auth.uid();
  v_nivel     public.minijuego_niveles;
  v_lista     text[];
  v_bloques   integer;
  v_pos       integer;
  v_rumbo     integer;
  v_fila      integer;
  v_col       integer;
  v_sig       integer;
  v_recogidas integer[] := '{}';
  v_llego     boolean := false;
  v_choco     boolean := false;
  v_puntos    integer := 0;
  v_previo    public.minijuego_resultados;
  v_mejoro    boolean := false;
  v_mejor     integer := 0;
  v_total     integer;
  v_paso      text;
  v_evento    uuid;
  v_alias     text;
  v_sufijo    text;
begin
  if v_uid is null then
    raise exception 'PR_AUTH_REQUIRED' using hint = 'Se necesita una sesión.';
  end if;
  if not public.minijuego_desbloqueado() then
    raise exception 'PR_MINIJUEGO_BLOQUEADO'
      using hint = 'El minijuego se desbloquea al terminar el Gran desafío.';
  end if;

  select * into v_nivel from public.minijuego_niveles where id = p_nivel;
  if not found then
    raise exception 'PR_NIVEL_NO_EXISTE' using hint = 'El nivel no existe.';
  end if;

  if jsonb_typeof(p_programa) is distinct from 'array' then
    raise exception 'PR_PROGRAMA_INVALIDO' using hint = 'El programa debe ser una lista.';
  end if;

  v_bloques := public.minijuego_bloques(p_programa);
  if v_bloques < 1 or v_bloques > 40 then
    raise exception 'PR_PROGRAMA_INVALIDO' using hint = 'El programa debe tener entre 1 y 40 bloques.';
  end if;
  v_lista := public.minijuego_expandir(p_programa);

  v_pos := v_nivel.inicio;
  v_rumbo := v_nivel.rumbo;
  foreach v_paso in array v_lista loop
    if v_paso = 'I' then
      v_rumbo := (v_rumbo + 3) % 4;
    elsif v_paso = 'D' then
      v_rumbo := (v_rumbo + 1) % 4;
    else
      v_fila := (v_pos / v_nivel.n) + (array[-1, 0, 1, 0])[v_rumbo + 1];
      v_col  := (v_pos % v_nivel.n) + (array[0, 1, 0, -1])[v_rumbo + 1];
      v_sig  := v_fila * v_nivel.n + v_col;
      if v_fila < 0 or v_fila >= v_nivel.n or v_col < 0 or v_col >= v_nivel.n
         or v_sig = any (v_nivel.muros) then
        v_choco := true;
        exit;
      end if;
      v_pos := v_sig;
      if v_pos = any (v_nivel.estrellas) and not (v_pos = any (v_recogidas)) then
        v_recogidas := v_recogidas || v_pos;
      end if;
    end if;
    if v_pos = v_nivel.meta then
      v_llego := true;
      exit;
    end if;
  end loop;

  if v_llego then
    v_puntos := 5 + 3 * coalesce(array_length(v_recogidas, 1), 0)
              + greatest(0, 7 - greatest(v_bloques - v_nivel.par, 0));

    select * into v_previo from public.minijuego_resultados
    where participante_id = v_uid and nivel_id = p_nivel;

    if not found then
      v_mejoro := true;
    elsif v_puntos > v_previo.puntos then
      v_mejoro := true;
    end if;

    if not found
       or v_puntos > v_previo.puntos
       or (v_puntos = v_previo.puntos and v_bloques < v_previo.bloques) then
      insert into public.minijuego_resultados
        (participante_id, nivel_id, puntos, bloques, pasos, estrellas, programa)
      values (v_uid, p_nivel, v_puntos, v_bloques, coalesce(array_length(v_lista, 1), 0),
              coalesce(array_length(v_recogidas, 1), 0), p_programa)
      on conflict (participante_id, nivel_id) do update set
        puntos = excluded.puntos, bloques = excluded.bloques, pasos = excluded.pasos,
        estrellas = excluded.estrellas, programa = excluded.programa,
        actualizado_en = now();
    end if;
  end if;

  select coalesce(max(r.puntos), 0) into v_mejor
  from public.minijuego_resultados r
  where r.participante_id = v_uid and r.nivel_id = p_nivel;

  select coalesce(sum(r.puntos), 0)::integer into v_total
  from public.minijuego_resultados r where r.participante_id = v_uid;

  -- Ranking público: una fila "Ruta del robot" por persona con su total.
  if v_mejoro then
    select d.evento_id into v_evento from public.desafios d where d.id = '50000000-0000-0000-0000-000000000010';
    select p.alias, p.alias_sufijo into v_alias, v_sufijo
    from public.perfiles p where p.id = v_uid;
    if v_evento is not null and v_alias is not null then
      delete from public.resultados_publicos
      where evento_id = v_evento and desafio = 'Ruta del robot'
        and alias = v_alias || '#' || v_sufijo;
      insert into public.resultados_publicos
        (evento_id, desafio, alias, puntos, duracion_ms, finalizado_en)
      values (v_evento, 'Ruta del robot', v_alias || '#' || v_sufijo, v_total, null, now());
    end if;
  end if;

  return query
    select v_llego, v_choco, v_bloques, coalesce(array_length(v_lista, 1), 0),
           coalesce(array_length(v_recogidas, 1), 0), v_puntos, v_mejor, v_mejoro, v_total;
end;
$$;

revoke all on function public.enviar_ruta(uuid, jsonb) from public;
grant execute on function public.enviar_ruta(uuid, jsonb) to authenticated;
revoke all on function public.minijuego_desbloqueado(uuid) from public;
grant execute on function public.minijuego_desbloqueado(uuid) to authenticated;

-- -------------------------------------------------------------
-- Ranking del desafío: suma los puntos del minijuego
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
      -- Los puntos del minijuego "Ruta del robot" suman al desafío que lo tiene.
      case when exists (select 1 from public.desafios d
                        where d.id = p_desafio and d.minijuego)
           then coalesce((select sum(r.puntos) from public.minijuego_resultados r
                          where r.participante_id = pa.participante_id), 0)::integer
           else 0 end as bono,
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
      order by (m.puntos + m.bono) desc,
               m.duracion_ms asc nulls last,
               m.finalizado_en asc,
               m.iniciado_en asc
    ) as posicion,
    pf.alias,
    pf.alias_sufijo,
    (m.puntos + m.bono) as puntos,
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

-- -------------------------------------------------------------
-- Ranking público del evento: total por persona (mejor resultado de cada
-- desafío más el minijuego)
-- -------------------------------------------------------------
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
  ), totales as (
    select e.alias,
           sum(e.puntos)::integer as puntaje,
           string_agg(e.desafio, ' + ' order by e.desafio) as desafio,
           min(e.duracion_ms) as duracion_ms,
           min(e.finalizado_en) as finalizado_en
    from elegibles e
    group by e.alias
  ), puestos as (
    select row_number() over (order by t.puntaje desc, t.duracion_ms asc nulls last,
                              t.finalizado_en asc, t.alias asc) as posicion,
           t.alias, t.puntaje, t.desafio
    from totales t
  )
  select * from puestos order by posicion
  limit greatest(1, least(coalesce(p_limite, 100), 200));
$$;
revoke all on function public.ranking_evento(uuid, integer) from public;
grant execute on function public.ranking_evento(uuid, integer) to anon, authenticated;
