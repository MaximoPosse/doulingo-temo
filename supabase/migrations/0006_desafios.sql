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
