-- =============================================================
-- CodeLingua · 0011_variar_respuestas.sql
-- Hasta ahora la opción correcta de cada pregunta de JavaScript (lecciones
-- y desafíos públicos de la expo) era siempre la primera (A). Esta migración
-- mueve la opción correcta a una posición A, B, C o D siguiendo un patrón
-- fijo, sin tocar los identificadores ni las soluciones.
--
--   - Solo cambia la columna `orden` de las opciones.
--   - No toca los desafíos de prueba (es_prueba = true): las pruebas
--     automáticas dependen de que su opción 1 sea la correcta.
--   - Es idempotente: si se ejecuta de nuevo, cada opción correcta ya está
--     en su posición y no se mueve nada.
-- =============================================================

do $$
declare
  patron constant integer[] := array[2, 4, 1, 3, 3, 1, 4, 2];
  r         record;
  n         integer := 0;
  destino   integer;
begin
  -- Lecciones del curso JavaScript (las de los cursos nuevos ya vienen
  -- con la respuesta repartida desde 0010).
  for r in
    select p.id as pregunta_id, s.opcion_correcta_id as correcta
    from public.preguntas p
    join public.soluciones s on s.pregunta_id = p.id
    join public.lecciones l on l.id = p.leccion_id
    join public.unidades u on u.id = l.unidad_id
    where u.curso_id = '00000000-0000-0000-0000-000000000001'
    order by u.orden, l.orden, p.orden
  loop
    n := n + 1;
    destino := patron[((n - 1) % 8) + 1];

    update public.opciones set orden = orden + 100 where pregunta_id = r.pregunta_id;
    with otros as (
      select id, row_number() over (order by orden) as rn
      from public.opciones
      where pregunta_id = r.pregunta_id and id <> r.correcta
    ),
    nuevo as (
      select id, rn + case when rn >= destino then 1 else 0 end as pos from otros
      union all
      select r.correcta, destino
    )
    update public.opciones o set orden = nuevo.pos
    from nuevo where o.id = nuevo.id;
  end loop;

  -- Desafíos públicos de la expo (se empieza el patrón en otro punto para
  -- que no coincida con el de las lecciones).
  n := 3;
  for r in
    select p.id as pregunta_id, s.opcion_correcta_id as correcta
    from public.desafio_preguntas p
    join public.desafio_soluciones s on s.pregunta_id = p.id
    join public.desafios d on d.id = p.desafio_id
    where d.es_prueba = false
    order by d.orden, p.orden
  loop
    n := n + 1;
    destino := patron[((n - 1) % 8) + 1];

    update public.desafio_opciones set orden = orden + 100 where pregunta_id = r.pregunta_id;
    with otros as (
      select id, row_number() over (order by orden) as rn
      from public.desafio_opciones
      where pregunta_id = r.pregunta_id and id <> r.correcta
    ),
    nuevo as (
      select id, rn + case when rn >= destino then 1 else 0 end as pos from otros
      union all
      select r.correcta, destino
    )
    update public.desafio_opciones o set orden = nuevo.pos
    from nuevo where o.id = nuevo.id;
  end loop;
end $$;

-- -------------------------------------------------------------
-- Saltos de línea de los fragmentos de código
-- 0002 y 0007 guardaron "\n" como dos caracteres (barra y n) en lugar de un
-- salto de línea, y la app mostraba el código en una sola línea con "\n"
-- a la vista. Se reemplazan por saltos de línea reales (idempotente).
-- -------------------------------------------------------------
update public.lecciones
set ejemplo_codigo = replace(ejemplo_codigo, E'\\n', E'\n')
where position(E'\\n' in ejemplo_codigo) > 0;

update public.preguntas
set codigo = replace(codigo, E'\\n', E'\n')
where position(E'\\n' in codigo) > 0;

update public.desafio_preguntas
set codigo = replace(codigo, E'\\n', E'\n')
where position(E'\\n' in codigo) > 0;
