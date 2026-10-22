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
