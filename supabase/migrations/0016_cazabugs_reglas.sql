-- =============================================================
-- CodeLingua · 0016_cazabugs_reglas.sql
-- Nuevas reglas de Cazabugs:
--
--   - UNA sola ronda con puntos por persona. Una vez que se inicia la ronda
--     oficial no se puede iniciar otra (la práctica sigue siendo libre).
--   - Los bichos que se te escapan (se esconden sin que los toques) restan
--     5 puntos y cortan la racha. Los amigos (Usagi) no cuentan.
--   - Todo aparece y desaparece un poco más rápido: un bicho nuevo cada
--     250 ms (antes 300) y duran de 1250 a 650 ms (antes de 1500 a 800).
--
-- El servidor sigue repitiendo la partida a partir de la semilla y los toques;
-- el cliente (src/lib/cazabugs.js) usa exactamente las mismas reglas.
-- Ejecutable varias veces.
-- =============================================================

-- -------------------------------------------------------------
-- Cronograma (a partir de la semilla): 180 pasos de 250 ms
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
  for v_k in 0..179 loop
    v_t := v_k * 250;
    v_estado := (v_estado * 1103515245 + 12345) % 2147483648;
    v_aparece := ((v_estado / 65536) % 100)::integer;
    v_estado := (v_estado * 1103515245 + 12345) % 2147483648;
    v_celda := ((v_estado / 65536) % 12)::integer;
    v_estado := (v_estado * 1103515245 + 12345) % 2147483648;
    v_tipo := ((v_estado / 65536) % 100)::integer;

    v_prob := 60 + (least(v_k, 120) * 30) / 120;
    if v_aparece < v_prob and v_libre[v_celda + 1] <= v_t then
      v_base := greatest(650, 1250 - v_k * 5);
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
-- Repetir la partida. Los toques y las salidas de los bichos se resuelven por
-- el momento en que ocurren: antes de cada toque en t se cuentan los bichos
-- que se escondieron hasta t (inclusive); al final, los que se escondieron
-- antes de los 45 s.
-- -------------------------------------------------------------
drop function if exists public.cazabugs_reproducir(integer, jsonb);
create function public.cazabugs_reproducir(p_semilla integer, p_toques jsonb)
returns table (
  puntaje integer, aciertos integer, fallos integer, amigos integer,
  escapados integer, mejor_racha integer
)
language plpgsql
as $$
declare
  v_toque    jsonb;
  v_t        integer;
  v_celda    integer;
  v_anterior integer := null;
  v_e        record;
  v_puntaje  integer := 0;
  v_racha    integer := 0;
  v_mejor    integer := 0;
  v_ac       integer := 0;
  v_fa       integer := 0;
  v_am       integer := 0;
  v_es       integer := 0;
  v_mult     integer;
  v_base     integer;
begin
  if jsonb_typeof(p_toques) is distinct from 'array' then
    raise exception 'PR_TOQUES_INVALIDOS' using hint = 'Los toques deben ser una lista.';
  end if;
  if jsonb_array_length(p_toques) > 500 then
    raise exception 'PR_TOQUES_INVALIDOS' using hint = 'Demasiados toques.';
  end if;

  create temporary table if not exists _cb_crono (
    i integer, t integer, celda integer, tipo text, vida integer, fin integer,
    resuelto boolean, procesado boolean, golpes integer
  ) on commit drop;
  truncate _cb_crono;
  insert into _cb_crono
    select c.i, c.t, c.celda, c.tipo, c.vida, c.t + c.vida, false, false, 0
    from public.cazabugs_cronograma(p_semilla) c;

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

    -- Bichos que se escondieron hasta v_t sin que los cazaran.
    for v_e in
      select * from _cb_crono c where not c.procesado and c.fin <= v_t order by c.fin, c.i
    loop
      update _cb_crono c set procesado = true where c.i = v_e.i;
      if not v_e.resuelto and v_e.tipo <> 'amigo' then
        update _cb_crono c set resuelto = true where c.i = v_e.i;
        v_es := v_es + 1;
        v_racha := 0;
        v_puntaje := greatest(0, v_puntaje - 5);
      end if;
    end loop;

    select * into v_e
    from _cb_crono c
    where c.celda = v_celda and c.t <= v_t and v_t < c.fin and not c.resuelto
    limit 1;

    if not found then
      v_fa := v_fa + 1;
      v_racha := 0;
    elsif v_e.tipo = 'amigo' then
      update _cb_crono c set resuelto = true where c.i = v_e.i;
      v_am := v_am + 1;
      v_racha := 0;
      v_puntaje := greatest(0, v_puntaje - 25);
    else
      if v_e.tipo = 'grande' and v_e.golpes < 1 then
        update _cb_crono c set golpes = 1 where c.i = v_e.i;   -- primer golpe: no puntúa
        continue;
      end if;
      update _cb_crono c set resuelto = true where c.i = v_e.i;
      v_ac := v_ac + 1;
      v_racha := v_racha + 1;
      v_mejor := greatest(v_mejor, v_racha);
      v_mult := 1 + least((v_racha - 1) / 4, 3);
      v_base := case v_e.tipo
                  when 'bug' then 10 when 'rapido' then 20
                  when 'grande' then 30 else 60 end;
      v_puntaje := v_puntaje + v_base * v_mult;
    end if;
  end loop;

  -- Los que se escondieron antes de que terminara la ronda.
  for v_e in
    select * from _cb_crono c where not c.procesado and c.fin < 45000 order by c.fin, c.i
  loop
    update _cb_crono c set procesado = true where c.i = v_e.i;
    if not v_e.resuelto and v_e.tipo <> 'amigo' then
      update _cb_crono c set resuelto = true where c.i = v_e.i;
      v_es := v_es + 1;
      v_puntaje := greatest(0, v_puntaje - 5);
    end if;
  end loop;

  puntaje := v_puntaje; aciertos := v_ac; fallos := v_fa; amigos := v_am;
  escapados := v_es; mejor_racha := v_mejor;
  return next;
end;
$$;

-- -------------------------------------------------------------
-- Iniciar: una sola ronda con puntos por persona
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

  -- Evita que dos pedidos simultáneos de la misma persona creen dos rondas.
  perform pg_advisory_xact_lock(hashtext('cazabugs'), hashtext(v_uid::text));

  if exists (select 1 from public.cazabugs_rondas r where r.participante_id = v_uid) then
    raise exception 'PR_RONDA_YA_JUGADA'
      using hint = 'Ya usaste tu única ronda con puntos.';
  end if;

  v_sem := (floor(random() * 2147483646) + 1)::integer;
  insert into public.cazabugs_rondas (participante_id, semilla)
  values (v_uid, v_sem)
  returning cazabugs_rondas.id, cazabugs_rondas.iniciada_en into v_id, v_ini;

  return query select v_id, v_sem, 45000, v_ini;
end;
$$;

-- -------------------------------------------------------------
-- Enviar: repite la partida y calcula el puntaje oficial (ahora también
-- devuelve cuántos bichos se escaparon)
-- -------------------------------------------------------------
drop function if exists public.cazabugs_enviar(uuid, jsonb);
create function public.cazabugs_enviar(p_ronda uuid, p_toques jsonb)
returns table (
  puntaje        integer,
  puntos         integer,
  aciertos       integer,
  fallos         integer,
  amigos         integer,
  escapados      integer,
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
    select d.evento_id into v_evento from public.desafios d
    where d.id = '50000000-0000-0000-0000-000000000010';
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
           v_res.escapados, v_res.mejor_racha, v_mp, v_mpts, v_mejoro;
end;
$$;

revoke all on function public.cazabugs_iniciar() from public;
revoke all on function public.cazabugs_enviar(uuid, jsonb) from public;
revoke all on function public.cazabugs_reproducir(integer, jsonb) from public;
revoke all on function public.cazabugs_cronograma(integer) from public;
grant execute on function public.cazabugs_iniciar() to authenticated;
grant execute on function public.cazabugs_enviar(uuid, jsonb) to authenticated;
