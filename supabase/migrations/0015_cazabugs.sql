-- =============================================================
-- CodeLingua · 0015_cazabugs.sql
-- Minijuego "Cazabugs" (reemplaza a "Ruta del robot").
--
--   - Se desbloquea igual que antes: al terminar el Gran desafío.
--   - Aparecen bichos en un tablero de 3 x 4. Hay que tocarlos antes de que se
--     escondan, sin tocar a los amigos (Usagi). Hay bichos rápidos, grandes
--     (2 toques) y dorados, y una racha que multiplica los puntos.
--   - Cada ronda dura 45 segundos. El servidor entrega una SEMILLA y de ella
--     salen todos los bichos; la persona manda sus toques (momento y casilla)
--     y el servidor REPITE la partida para calcular el puntaje oficial.
--   - Cada puntaje de 40 vale 1 punto de ranking (máximo 100). Cuenta la mejor
--     ronda de cada persona y se suma al ranking del Gran desafío y al ranking
--     público de la expo.
--
-- Ejecutable varias veces. Elimina las tablas y funciones de "Ruta del robot".
-- =============================================================

-- -------------------------------------------------------------
-- Tablas
-- -------------------------------------------------------------
create table if not exists public.cazabugs_rondas (
  id              uuid primary key default gen_random_uuid(),
  participante_id uuid not null references auth.users (id) on delete cascade,
  semilla         integer not null check (semilla > 0),
  iniciada_en     timestamptz not null default now(),
  estado          text not null default 'en_curso'
                  check (estado in ('en_curso', 'enviada', 'invalida')),
  puntaje         integer check (puntaje is null or puntaje >= 0),
  aciertos        integer,
  fallos          integer,
  amigos          integer,
  mejor_racha     integer,
  enviada_en      timestamptz
);

create index if not exists cazabugs_rondas_por_persona
  on public.cazabugs_rondas (participante_id, iniciada_en desc);

create table if not exists public.cazabugs_mejores (
  participante_id uuid primary key references auth.users (id) on delete cascade,
  puntaje         integer not null check (puntaje >= 0),
  puntos          integer not null check (puntos >= 0),
  aciertos        integer not null,
  mejor_racha     integer not null,
  rondas          integer not null default 1,
  actualizado_en  timestamptz not null default now()
);

alter table public.cazabugs_rondas enable row level security;
alter table public.cazabugs_mejores enable row level security;

drop policy if exists "cazabugs_mejores_propios" on public.cazabugs_mejores;
create policy "cazabugs_mejores_propios" on public.cazabugs_mejores
  for select to authenticated using (participante_id = auth.uid());

revoke all on public.cazabugs_rondas, public.cazabugs_mejores from anon, authenticated;
grant select on public.cazabugs_mejores to authenticated;

-- -------------------------------------------------------------
-- Cronograma: todo lo que aparece en una ronda, a partir de la semilla.
--   estado' = (estado * 1103515245 + 12345) mod 2^31
--   azar(n) = (estado' / 65536) mod n
-- Por paso (cada 300 ms) se sacan siempre 3 números: si aparece algo, en qué
-- casilla y de qué tipo. Tiene que dar lo mismo que src/lib/cazabugs.js.
-- -------------------------------------------------------------
create or replace function public.cazabugs_cronograma(p_semilla integer)
returns table (i integer, t integer, celda integer, tipo text, vida integer)
language plpgsql
immutable
as $$
declare
  v_estado bigint := p_semilla;
  v_libre  integer[] := array_fill(0, array[12]);
  v_k      integer;
  v_t      integer;
  v_aparece integer;
  v_celda  integer;
  v_tipo   integer;
  v_prob   integer;
  v_base   integer;
  v_vida   integer;
  v_nombre text;
  v_n      integer := 0;
begin
  for v_k in 0..149 loop
    v_t := v_k * 300;
    v_estado := (v_estado * 1103515245 + 12345) % 2147483648;
    v_aparece := ((v_estado / 65536) % 100)::integer;
    v_estado := (v_estado * 1103515245 + 12345) % 2147483648;
    v_celda := ((v_estado / 65536) % 12)::integer;
    v_estado := (v_estado * 1103515245 + 12345) % 2147483648;
    v_tipo := ((v_estado / 65536) % 100)::integer;

    v_prob := 55 + (least(v_k, 100) * 30) / 100;
    if v_aparece < v_prob and v_libre[v_celda + 1] <= v_t then
      v_base := greatest(800, 1500 - v_k * 6);
      if v_tipo < 58 then
        v_nombre := 'bug';    v_vida := v_base;
      elsif v_tipo < 76 then
        v_nombre := 'rapido'; v_vida := (v_base * 60) / 100;
      elsif v_tipo < 86 then
        v_nombre := 'grande'; v_vida := (v_base * 13) / 10;
      elsif v_tipo < 92 then
        v_nombre := 'dorado'; v_vida := (v_base * 50) / 100;
      else
        v_nombre := 'amigo';  v_vida := v_base;
      end if;
      i := v_n; t := v_t; celda := v_celda; tipo := v_nombre; vida := v_vida;
      v_n := v_n + 1;
      v_libre[v_celda + 1] := v_t + v_vida + 100;
      return next;
    end if;
  end loop;
end;
$$;

-- -------------------------------------------------------------
-- Repetir la partida: devuelve el resultado a partir de la semilla y de los
-- toques [[t, celda], ...]. Rechaza toques imposibles.
-- -------------------------------------------------------------
create or replace function public.cazabugs_reproducir(p_semilla integer, p_toques jsonb)
returns table (puntaje integer, aciertos integer, fallos integer, amigos integer, mejor_racha integer)
language plpgsql
as $$
declare
  v_lista    jsonb;
  v_toque    jsonb;
  v_t        integer;
  v_celda    integer;
  v_anterior integer := null;
  v_i        integer;
  v_bicho    record;
  v_puntaje  integer := 0;
  v_racha    integer := 0;
  v_mejor    integer := 0;
  v_ac       integer := 0;
  v_fa       integer := 0;
  v_am       integer := 0;
  v_base     integer;
  v_mult     integer;
  v_resueltos integer[] := '{}';
  v_golpes   integer[] := '{}';
  v_hay      boolean;
begin
  if jsonb_typeof(p_toques) is distinct from 'array' then
    raise exception 'PR_TOQUES_INVALIDOS' using hint = 'Los toques deben ser una lista.';
  end if;
  if jsonb_array_length(p_toques) > 500 then
    raise exception 'PR_TOQUES_INVALIDOS' using hint = 'Demasiados toques.';
  end if;

  create temporary table if not exists _cb_crono (
    i integer, t integer, celda integer, tipo text, vida integer
  ) on commit drop;
  truncate _cb_crono;
  insert into _cb_crono select * from public.cazabugs_cronograma(p_semilla);

  for v_toque in select * from jsonb_array_elements(p_toques) loop
    if jsonb_typeof(v_toque) <> 'array' or jsonb_array_length(v_toque) <> 2
       or jsonb_typeof(v_toque -> 0) <> 'number' or jsonb_typeof(v_toque -> 1) <> 'number'
       or (v_toque ->> 0) !~ '^[0-9]+$' or (v_toque ->> 1) !~ '^[0-9]+$' then
      raise exception 'PR_TOQUES_INVALIDOS' using hint = 'Toque no válido.';
    end if;
    v_t := (v_toque ->> 0)::integer;
    v_celda := (v_toque ->> 1)::integer;
    if v_t >= 45000 or v_celda >= 12 then
      raise exception 'PR_TOQUES_INVALIDOS' using hint = 'Toque fuera de rango.';
    end if;
    if v_anterior is not null and v_t - v_anterior < 60 then
      raise exception 'PR_TOQUES_INVALIDOS' using hint = 'Toques demasiado seguidos.';
    end if;
    v_anterior := v_t;

    select c.* into v_bicho
    from _cb_crono c
    where c.celda = v_celda and c.t <= v_t and v_t < c.t + c.vida
      and not (c.i = any (v_resueltos))
    limit 1;
    v_hay := found;

    if not v_hay then
      v_fa := v_fa + 1;
      v_racha := 0;
    elsif v_bicho.tipo = 'amigo' then
      v_resueltos := v_resueltos || v_bicho.i;
      v_am := v_am + 1;
      v_racha := 0;
      v_puntaje := greatest(0, v_puntaje - 25);
    else
      if v_bicho.tipo = 'grande' and not (v_bicho.i = any (v_golpes)) then
        v_golpes := v_golpes || v_bicho.i;   -- primer golpe: no puntúa
        continue;
      end if;
      v_resueltos := v_resueltos || v_bicho.i;
      v_ac := v_ac + 1;
      v_racha := v_racha + 1;
      v_mejor := greatest(v_mejor, v_racha);
      v_mult := 1 + least((v_racha - 1) / 4, 3);
      v_base := case v_bicho.tipo
                  when 'bug' then 10 when 'rapido' then 20
                  when 'grande' then 30 else 60 end;
      v_puntaje := v_puntaje + v_base * v_mult;
    end if;
  end loop;

  puntaje := v_puntaje; aciertos := v_ac; fallos := v_fa; amigos := v_am; mejor_racha := v_mejor;
  return next;
end;
$$;

-- -------------------------------------------------------------
-- iniciar_ronda: entrega la semilla (solo si el minijuego está desbloqueado)
-- -------------------------------------------------------------
create or replace function public.cazabugs_iniciar()
returns table (ronda uuid, semilla integer, duracion_ms integer, iniciada_en timestamptz)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_id  uuid;
  v_sem integer;
  v_ini timestamptz;
begin
  if v_uid is null then
    raise exception 'PR_AUTH_REQUIRED' using hint = 'Se necesita una sesión.';
  end if;
  if not public.minijuego_desbloqueado() then
    raise exception 'PR_MINIJUEGO_BLOQUEADO'
      using hint = 'El minijuego se desbloquea al terminar el Gran desafío.';
  end if;

  -- Las rondas viejas que nunca se enviaron se descartan.
  update public.cazabugs_rondas r set estado = 'invalida'
  where r.participante_id = v_uid and r.estado = 'en_curso'
    and r.iniciada_en < now() - interval '2 minutes';

  v_sem := (floor(random() * 2147483646) + 1)::integer;
  insert into public.cazabugs_rondas (participante_id, semilla)
  values (v_uid, v_sem)
  returning cazabugs_rondas.id, cazabugs_rondas.iniciada_en into v_id, v_ini;

  return query select v_id, v_sem, 45000, v_ini;
end;
$$;

-- -------------------------------------------------------------
-- enviar_ronda: repite la partida con los toques y calcula el puntaje oficial
-- -------------------------------------------------------------
create or replace function public.cazabugs_enviar(p_ronda uuid, p_toques jsonb)
returns table (
  puntaje        integer,
  puntos         integer,
  aciertos       integer,
  fallos         integer,
  amigos         integer,
  mejor_racha    integer,
  mejor_puntaje  integer,
  mejor_puntos   integer,
  mejoro         boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid     uuid := auth.uid();
  v_ronda   public.cazabugs_rondas;
  v_res     record;
  v_puntos  integer;
  v_prev    public.cazabugs_mejores;
  v_mejoro  boolean := false;
  v_mp      integer;
  v_mpts    integer;
  v_evento  uuid;
  v_alias   text;
  v_sufijo  text;
begin
  if v_uid is null then
    raise exception 'PR_AUTH_REQUIRED' using hint = 'Se necesita una sesión.';
  end if;
  if not public.minijuego_desbloqueado() then
    raise exception 'PR_MINIJUEGO_BLOQUEADO'
      using hint = 'El minijuego se desbloquea al terminar el Gran desafío.';
  end if;

  select * into v_ronda from public.cazabugs_rondas
  where id = p_ronda and participante_id = v_uid
  for update;
  if not found then
    raise exception 'PR_RONDA_NO_EXISTE' using hint = 'La ronda no existe.';
  end if;
  if v_ronda.estado <> 'en_curso' then
    raise exception 'PR_RONDA_CERRADA' using hint = 'Esa ronda ya se envió.';
  end if;
  -- La ronda dura 45 s: no se puede enviar antes de que pase casi todo el
  -- tiempo ni mucho después.
  if now() < v_ronda.iniciada_en + interval '40 seconds'
     or now() > v_ronda.iniciada_en + interval '120 seconds' then
    update public.cazabugs_rondas set estado = 'invalida' where id = p_ronda;
    raise exception 'PR_RONDA_FUERA_DE_TIEMPO' using hint = 'La ronda se envió fuera de tiempo.';
  end if;

  select * into v_res from public.cazabugs_reproducir(v_ronda.semilla, p_toques);
  v_puntos := least(100, v_res.puntaje / 40);

  update public.cazabugs_rondas
     set estado = 'enviada', puntaje = v_res.puntaje, aciertos = v_res.aciertos,
         fallos = v_res.fallos, amigos = v_res.amigos, mejor_racha = v_res.mejor_racha,
         enviada_en = now()
   where id = p_ronda;

  select * into v_prev from public.cazabugs_mejores where participante_id = v_uid;
  if not found then
    insert into public.cazabugs_mejores (participante_id, puntaje, puntos, aciertos, mejor_racha)
    values (v_uid, v_res.puntaje, v_puntos, v_res.aciertos, v_res.mejor_racha);
    v_mejoro := true;
  elsif v_res.puntaje > v_prev.puntaje then
    update public.cazabugs_mejores
       set puntaje = v_res.puntaje, puntos = v_puntos, aciertos = v_res.aciertos,
           mejor_racha = v_res.mejor_racha, rondas = rondas + 1, actualizado_en = now()
     where participante_id = v_uid;
    v_mejoro := true;
  else
    update public.cazabugs_mejores set rondas = rondas + 1 where participante_id = v_uid;
  end if;

  select m.puntaje, m.puntos into v_mp, v_mpts
  from public.cazabugs_mejores m where m.participante_id = v_uid;

  -- Ranking público: una fila "Cazabugs" por persona con sus puntos.
  if v_mejoro then
    select d.evento_id into v_evento from public.desafios d where d.id = '50000000-0000-0000-0000-000000000010';
    select p.alias, p.alias_sufijo into v_alias, v_sufijo
    from public.perfiles p where p.id = v_uid;
    if v_evento is not null and v_alias is not null then
      delete from public.resultados_publicos
      where evento_id = v_evento and desafio = 'Cazabugs'
        and alias = v_alias || '#' || v_sufijo;
      insert into public.resultados_publicos
        (evento_id, desafio, alias, puntos, duracion_ms, finalizado_en)
      values (v_evento, 'Cazabugs', v_alias || '#' || v_sufijo, v_mpts, null, now());
    end if;
  end if;

  return query
    select v_res.puntaje, v_puntos, v_res.aciertos, v_res.fallos, v_res.amigos,
           v_res.mejor_racha, v_mp, v_mpts, v_mejoro;
end;
$$;

revoke all on function public.cazabugs_iniciar() from public;
revoke all on function public.cazabugs_enviar(uuid, jsonb) from public;
revoke all on function public.cazabugs_reproducir(integer, jsonb) from public;
revoke all on function public.cazabugs_cronograma(integer) from public;
grant execute on function public.cazabugs_iniciar() to authenticated;
grant execute on function public.cazabugs_enviar(uuid, jsonb) to authenticated;

-- -------------------------------------------------------------
-- Ranking del desafío: el bono sale de los puntos de Cazabugs
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
      -- Los puntos del minijuego "Cazabugs" suman al desafío que lo tiene.
      case when exists (select 1 from public.desafios d
                        where d.id = p_desafio and d.minijuego)
           then coalesce((select r.puntos from public.cazabugs_mejores r
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
-- Se elimina "Ruta del robot"
-- -------------------------------------------------------------
delete from public.resultados_publicos where desafio = 'Ruta del robot';
drop function if exists public.enviar_ruta(uuid, jsonb);
drop function if exists public.minijuego_expandir(jsonb, integer);
drop function if exists public.minijuego_bloques(jsonb);
drop table if exists public.minijuego_resultados;
drop table if exists public.minijuego_niveles;
