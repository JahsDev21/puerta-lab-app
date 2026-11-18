-- =====================================================================
-- PuertaLab · Datos de prueba para la app móvil
-- Solo INSERTA filas; no cambia tablas ni políticas.
--
-- ANTES DE CORRERLO:
--  1. En Authentication > Users > Add user crea (con "Auto Confirm User"):
--       alumno.prueba@puertalab.test   y   docente.prueba@puertalab.test
--  2. Revisa los nombres de rol reales:  select * from puertalab_roles;
--     y reemplaza 'Alumno' / 'Docente' abajo si se llaman distinto.
--  3. Si los id de puertalab_personas o puertalab_eventos NO se generan solos,
--     agrega la columna id con números libres en esos INSERT.
--
-- Para borrar todo después: ver el bloque al final.
-- =====================================================================
begin;

with
alumno as (
    insert into public.puertalab_personas (nombre, rol, grupo)
    values ('Alumno Prueba', 'Alumno', 'Prueba')
    returning id
),
docente as (
    insert into public.puertalab_personas (nombre, rol)
    values ('Docente Prueba', 'Docente')
    returning id
),
cuentas as (
    insert into public.puertalab_cuentas_movil (usuario_id, persona_id, alcance)
    select u.id,
           case when u.email like 'alumno%' then (select id from alumno)
                else (select id from docente) end,
           case when u.email like 'alumno%' then 'personal' else 'equipo' end
      from auth.users u
     where u.email in ('alumno.prueba@puertalab.test', 'docente.prueba@puertalab.test')
    returning 1
),
horario as (
    -- Lunes, miércoles y viernes de 07:00 a 09:00
    insert into public.puertalab_horarios (persona_id, dia_iso, desde, hasta)
    select (select id from alumno), d, '07:00', '09:00'
      from unnest(array[1, 3, 5]) as d
    returning 1
)
-- Entradas del alumno en las últimas 3 semanas (algunas a tiempo, otras con retardo,
-- y algunos días sin entrada para que salgan faltas) + un intento rechazado.
insert into public.puertalab_eventos (fecha, persona_id, persona, metodo, resultado, sentido, origen)
select ((dia + time '07:00' + (random() * interval '25 minutes'))
           at time zone 'America/Mexico_City'),
       (select id from alumno), 'Alumno Prueba', 'Huella', 'Permitido', 'Entrada', 'manual'
  from generate_series((current_date - 21)::timestamp, (current_date - 1)::timestamp, interval '1 day') as dia
 where extract(isodow from dia) in (1, 3, 5)
   and random() < 0.8
union all
select now() - interval '2 hours', null, 'Desconocido', 'Huella', 'Rechazado', 'Entrada', 'manual'
union all
select now() - interval '1 hour', (select id from docente), 'Docente Prueba', 'Tarjeta', 'Permitido', 'Entrada', 'manual';

-- Lecturas simuladas del dispositivo (usa la función que ya existe)
select public.puertalab_guardar_lectura('Puerta', 'Cerrada');
select public.puertalab_guardar_lectura('Presencia (PIR)', 'Sin movimiento');

commit;

-- ---------------------------------------------------------------------
-- Para BORRAR los datos de prueba:
-- delete from public.puertalab_eventos   where persona in ('Alumno Prueba', 'Docente Prueba', 'Desconocido') and origen = 'manual';
-- delete from public.puertalab_personas  where nombre in ('Alumno Prueba', 'Docente Prueba');  -- borra en cascada horarios y cuentas
-- delete from public.puertalab_sensores  where nombre in ('Puerta', 'Presencia (PIR)');
-- ---------------------------------------------------------------------
