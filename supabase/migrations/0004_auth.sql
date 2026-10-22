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
  v_alias   text;
  v_sufijo  text;
  v_invitado boolean;
begin
  v_alias := public.normalizar_alias(new.raw_user_meta_data ->> 'alias');
  v_sufijo := substr(replace(new.id::text, '-', ''), 1, 4);
  -- `is_anonymous` solo existe si el proyecto tiene habilitados los
  -- invitados anónimos: se lee de forma tolerante a esa ausencia.
  v_invitado := coalesce((to_jsonb(new) ->> 'is_anonymous')::boolean, true);

  insert into public.perfiles (id, alias, alias_sufijo, es_invitado)
  values (new.id, v_alias, v_sufijo, v_invitado)
  on conflict (id) do nothing;

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
grant update (alias) on public.perfiles to authenticated;

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
