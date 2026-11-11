-- Corrección incremental para instalaciones que ya aplicaron 0008.
grant select on public.soluciones, public.desafio_soluciones to authenticated;

create or replace function public.validar_contenido_admin()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_table_name in ('opciones', 'desafio_opciones') then
    if exists (select 1 from public.opciones o where tg_table_name = 'opciones' and o.pregunta_id = new.pregunta_id
      and lower(trim(o.texto)) = lower(trim(new.texto)) and o.id <> new.id) then
      raise exception 'PR_OPCIONES_DUPLICADAS';
    end if;
    if exists (select 1 from public.desafio_opciones o where tg_table_name = 'desafio_opciones' and o.pregunta_id = new.pregunta_id
      and lower(trim(o.texto)) = lower(trim(new.texto)) and o.id <> new.id) then
      raise exception 'PR_OPCIONES_DUPLICADAS';
    end if;
  elsif tg_table_name in ('soluciones', 'desafio_soluciones') then
    if not exists (select 1 from public.opciones o where o.id = new.opcion_correcta_id
      and o.pregunta_id = new.pregunta_id)
      and tg_table_name = 'soluciones'
      or not exists (select 1 from public.desafio_opciones o where o.id = new.opcion_correcta_id
      and o.pregunta_id = new.pregunta_id) and tg_table_name = 'desafio_soluciones' then
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
drop trigger if exists validar_opcion_desafio_admin on public.desafio_opciones;
create trigger validar_opcion_desafio_admin before insert or update on public.desafio_opciones
  for each row execute function public.validar_contenido_admin();
drop trigger if exists validar_solucion_desafio_admin on public.desafio_soluciones;
create trigger validar_solucion_desafio_admin before insert or update on public.desafio_soluciones
  for each row execute function public.validar_contenido_admin();
