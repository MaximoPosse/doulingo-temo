-- =============================================================
-- CodeLingua · 0013_vidas.sql
-- Vidas en el Gran desafío: en lugar de poder repetirlo, la partida es una
-- sola y se juega con 3 vidas.
--
--   - Cada respuesta incorrecta resta una vida.
--   - Con 0 vidas la partida termina y queda como finalizada, con los puntos
--     que se lograron hasta ahí (cuenta para el ranking).
--   - Un solo intento por persona (ya no se puede jugar otra vez).
--
-- Las vidas son una columna nueva de `desafios` (null = sin límite, como
-- los desafíos de prueba). Cada partida guarda una copia de las vidas con
-- las que empezó. El servidor es quien descuenta y corta la partida.
-- Ejecutable varias veces.
-- =============================================================

alter table public.desafios add column if not exists vidas integer
  check (vidas is null or vidas > 0);
alter table public.partidas add column if not exists vidas integer
  check (vidas is null or vidas > 0);

comment on column public.desafios.vidas is
  'Errores que se toleran por partida (null = sin límite). Al llegar a cero la partida termina.';

update public.desafios
set vidas = 3,
    intentos_permitidos = 1,
    descripcion = 'Veinte preguntas que van subiendo de dificultad: 4 fáciles, 8 intermedias y 8 difíciles. Tenés 3 vidas: cada respuesta incorrecta te resta una y con 0 vidas la partida termina. Se juega una sola vez.'
where id = '50000000-0000-0000-0000-000000000010';

-- -------------------------------------------------------------
-- iniciar_partida: guarda las vidas en la partida
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
  v_muestreo   boolean;
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

  -- Desafíos con cupos por dificultad: en cada partida se sortea un
  -- subconjunto del banco (ver más abajo). Sin cupos se usan todas.
  v_muestreo := v_desafio.cupo_facil is not null
             or v_desafio.cupo_intermedio is not null
             or v_desafio.cupo_dificil is not null;

  if v_muestreo then
    select coalesce(sum(least(q.n, q.cupo)), 0) into v_total
    from (
      select dp.dificultad,
             count(*) as n,
             case dp.dificultad
               when 'facil' then coalesce(v_desafio.cupo_facil, 0)
               when 'intermedio' then coalesce(v_desafio.cupo_intermedio, 0)
               else coalesce(v_desafio.cupo_dificil, 0)
             end as cupo
      from public.desafio_preguntas dp
      where dp.desafio_id = p_desafio
      group by dp.dificultad
    ) q;
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
      puntos_por_acierto, duracion_segundos, tolerancia_segundos, expira_en,
      vidas
    )
    values (
      v_uid, p_desafio, p_clave, v_total,
      v_desafio.puntos_por_acierto, v_desafio.duracion_segundos,
      v_desafio.tolerancia_segundos,
      now() + make_interval(secs => v_desafio.duracion_segundos),
      v_desafio.vidas
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
  if v_muestreo then
    -- Sorteo con dificultad creciente: primero las fáciles, después las
    -- intermedias y al final las difíciles. Dentro de cada nivel se prefieren
    -- las preguntas que este participante todavía no vio en intentos
    -- anteriores, así cada intento rota las preguntas.
    insert into public.partida_preguntas (partida_id, desafio_pregunta_id, orden)
    select v_partida.id, e.id, row_number() over (order by e.nivel, e.azar)
    from (
      select c.id, c.nivel, random() as azar
      from (
        select dp.id,
               dp.dificultad,
               case dp.dificultad when 'facil' then 1 when 'intermedio' then 2 else 3 end as nivel,
               row_number() over (
                 partition by dp.dificultad
                 order by exists (
                            select 1
                            from public.partida_preguntas pp
                            join public.partidas pa on pa.id = pp.partida_id
                            where pa.participante_id = v_uid
                              and pa.desafio_id = p_desafio
                              and pp.desafio_pregunta_id = dp.id
                          ),
                          random()
               ) as rn
        from public.desafio_preguntas dp
        where dp.desafio_id = p_desafio
      ) c
      where c.rn <= case c.dificultad
              when 'facil' then coalesce(v_desafio.cupo_facil, 0)
              when 'intermedio' then coalesce(v_desafio.cupo_intermedio, 0)
              else coalesce(v_desafio.cupo_dificil, 0)
            end
    ) e;
  else
    insert into public.partida_preguntas (partida_id, desafio_pregunta_id, orden)
    select v_partida.id, dp.id, dp.orden
    from public.desafio_preguntas dp
    where dp.desafio_id = p_desafio
    order by dp.orden;
  end if;

  return query
    select v_partida.id, v_partida.desafio_id, v_partida.estado,
           v_partida.total_preguntas, v_partida.puntos_por_acierto,
           v_partida.duracion_segundos, v_partida.tolerancia_segundos,
           v_partida.iniciado_en, v_partida.expira_en,
           v_usados + 1, v_desafio.intentos_permitidos, false;
end;
$$;

-- -------------------------------------------------------------
-- responder_partida: devuelve las vidas que quedan y rechaza respuestas
-- cuando no queda ninguna. Cambia el resultado de la función, por eso se
-- elimina y se vuelve a crear.
-- -------------------------------------------------------------
drop function if exists public.responder_partida(uuid, uuid, uuid);

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
  expira_en       timestamptz,
  vidas_restantes integer
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
  v_errores     integer;
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

    select count(*) into v_errores
    from public.partida_respuestas r
    where r.partida_id = p_partida and not r.correcto;

    return query
      select v_respuesta.correcto, v_respuesta.puntos_obtenidos,
             v_partida.puntos, v_respondidas, v_partida.total_preguntas,
             true, v_partida.expira_en,
             case when v_partida.vidas is null then null
                  else greatest(v_partida.vidas - v_errores, 0) end;
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

  -- Sin vidas no se aceptan más respuestas: la partida terminó.
  if v_partida.vidas is not null and (
    select count(*) from public.partida_respuestas r
    where r.partida_id = p_partida and not r.correcto
  ) >= v_partida.vidas then
    raise exception 'PR_SIN_VIDAS'
      using hint = 'Te quedaste sin vidas: la partida terminó.';
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
           (v_insertadas = 0), v_partida.expira_en,
           case when v_partida.vidas is null then null
                else greatest(v_partida.vidas - v_partida.errores, 0) end;
end;
$$;

revoke all on function public.responder_partida(uuid, uuid, uuid) from public;
grant execute on function public.responder_partida(uuid, uuid, uuid) to authenticated;

-- -------------------------------------------------------------
-- finalizar_partida: sin vidas la partida cuenta como finalizada
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
  elsif v_partida.vidas is not null and v_errores >= v_partida.vidas then
    -- Se acabaron las vidas: la partida terminó y cuenta con lo logrado.
    v_estado := 'finalizada';
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
