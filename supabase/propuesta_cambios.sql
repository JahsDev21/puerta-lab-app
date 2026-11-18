-- =====================================================================
-- PuertaLab · Propuesta de cambios para que la app móvil cumpla el PDF
-- (Propuesta 2: control de acceso y asistencia)
--
-- NO está aplicado. Revisarlo con quien diseñó la BD antes de correrlo.
-- Se corre completo en el SQL Editor de Supabase (es una transacción).
-- =====================================================================
begin;

-- ---------------------------------------------------------------------
-- 1. Roles legibles desde la app
--    Hoy puertalab_roles tiene RLS activo pero NINGUNA política, así que
--    un usuario autenticado no puede leerla (ni la función
--    puertalab_permiso funciona desde la app).
-- ---------------------------------------------------------------------
create policy puertalab_movil_roles on public.puertalab_roles
    for select to authenticated using (true);

-- Qué roles pueden abrir la puerta desde la app (docente y administrador según el PDF)
alter table public.puertalab_roles
    add column puede_abrir_remoto boolean not null default false;
-- AJUSTAR a los nombres reales de la tabla puertalab_roles:
-- update public.puertalab_roles set puede_abrir_remoto = true
--  where nombre in ('Docente', 'Administrador');


-- ---------------------------------------------------------------------
-- 2. Comandos (apertura remota desde la app)
--    La app inserta un comando 'pendiente'; el ESP32 (o el puente MQTT)
--    lo ejecuta y lo marca como 'ejecutado' o 'fallido'.
-- ---------------------------------------------------------------------
create table public.puertalab_comandos (
    id             bigint generated always as identity primary key,
    tipo           text not null default 'abrir' check (tipo in ('abrir')),
    solicitado_por uuid default auth.uid() references auth.users(id) on delete set null,
    creado_en      timestamptz not null default now(),
    estado         text not null default 'pendiente'
                   check (estado in ('pendiente', 'ejecutado', 'fallido', 'expirado')),
    atendido_en    timestamptz,
    detalle        text
);
alter table public.puertalab_comandos enable row level security;

-- Solo cuentas habilitadas cuyo rol puede abrir; solo pueden crear comandos 'pendiente' a su nombre
create policy puertalab_movil_comandos_insert on public.puertalab_comandos
    for insert to authenticated
    with check (
        solicitado_por = (select auth.uid())
        and estado = 'pendiente'
        and exists (
            select 1
              from public.puertalab_cuentas_movil c
              join public.puertalab_personas p on p.id = c.persona_id
              join public.puertalab_roles r    on r.nombre = p.rol
             where c.usuario_id = (select auth.uid())
               and c.habilitada and p.activo and r.puede_abrir_remoto
        )
    );

create policy puertalab_movil_comandos_select on public.puertalab_comandos
    for select to authenticated
    using (
        solicitado_por = (select auth.uid())
        or exists (select 1 from public.puertalab_cuentas_movil c
                    where c.usuario_id = (select auth.uid())
                      and c.habilitada and c.alcance = 'equipo')
    );


-- ---------------------------------------------------------------------
-- 3. Eventos: motivo del rechazo, foto de evidencia, apertura remota
-- ---------------------------------------------------------------------
alter table public.puertalab_eventos
    add column motivo     text,   -- p. ej. el 'motivo' que devuelve puertalab_permiso
    add column foto_path  text,   -- ruta en el bucket puertalab-evidencias
    add column comando_id bigint references public.puertalab_comandos(id) on delete set null;

alter table public.puertalab_eventos
    drop constraint puertalab_eventos_metodo_check,
    add  constraint puertalab_eventos_metodo_check
         check (metodo in ('Huella', 'Rostro', 'Tarjeta', 'Huella+Tarjeta', 'Remoto', 'Otro'));


-- ---------------------------------------------------------------------
-- 4. Alertas (3 intentos fallidos, puerta forzada, puerta abierta)
-- ---------------------------------------------------------------------
create table public.puertalab_alertas (
    id         bigint generated always as identity primary key,
    fecha      timestamptz not null default now(),
    tipo       text not null check (tipo in ('intentos_fallidos', 'puerta_forzada',
                                             'puerta_abierta', 'dispositivo_sin_conexion')),
    evento_id  int references public.puertalab_eventos(id) on delete set null,
    foto_path  text,
    atendida   boolean not null default false
);
alter table public.puertalab_alertas enable row level security;

create policy puertalab_movil_alertas on public.puertalab_alertas
    for select to authenticated
    using (exists (select 1 from public.puertalab_cuentas_movil c
                    where c.usuario_id = (select auth.uid())
                      and c.habilitada and c.alcance = 'equipo'));


-- ---------------------------------------------------------------------
-- 5. Tokens de notificaciones push (FCM), uno por teléfono
-- ---------------------------------------------------------------------
create table public.puertalab_tokens_push (
    token          text primary key,
    usuario_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
    actualizado_en timestamptz not null default now()
);
alter table public.puertalab_tokens_push enable row level security;

create policy puertalab_movil_tokens on public.puertalab_tokens_push
    for all to authenticated
    using (usuario_id = (select auth.uid()))
    with check (usuario_id = (select auth.uid()));


-- ---------------------------------------------------------------------
-- 6. Asistencia calculada (a tiempo / retardo / fuera de horario)
--    Primera entrada permitida de cada persona en cada bloque de horario.
--    Tolerancia: puede llegar 15 min antes; después de 10 min es retardo.
--    security_invoker = las políticas RLS de eventos y horarios se respetan,
--    así un alumno solo ve su propia asistencia.
-- ---------------------------------------------------------------------
create view public.puertalab_asistencias with (security_invoker = true) as
with entradas as (
    select e.id as evento_id, e.persona_id, e.fecha,
           (e.fecha at time zone 'America/Mexico_City') as local
      from public.puertalab_eventos e
     where e.resultado = 'Permitido'
       and e.persona_id is not null
       and e.sentido <> 'Salida'
), con_bloque as (
    select en.*, h.desde, h.hasta
      from entradas en
      left join public.puertalab_horarios h
        on h.persona_id = en.persona_id
       and h.dia_iso    = extract(isodow from en.local)
       and en.local::time >= h.desde - interval '15 minutes'
       and en.local::time <  h.hasta
)
select distinct on (persona_id, local::date, desde)
       persona_id,
       local::date  as dia,
       fecha        as hora_entrada,
       evento_id,
       desde,
       hasta,
       case when desde is null                                then 'fuera_de_horario'
            when local::time <= desde + interval '10 minutes' then 'a_tiempo'
            else 'retardo' end as estado
  from con_bloque
 order by persona_id, local::date, desde, local;


-- ---------------------------------------------------------------------
-- 7. Bucket privado para las fotos de la ESP32-CAM
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('puertalab-evidencias', 'puertalab-evidencias', false)
on conflict (id) do nothing;

create policy "puertalab evidencias equipo" on storage.objects
    for select to authenticated
    using (bucket_id = 'puertalab-evidencias'
           and exists (select 1 from public.puertalab_cuentas_movil c
                        where c.usuario_id = (select auth.uid())
                          and c.habilitada and c.alcance = 'equipo'));


-- ---------------------------------------------------------------------
-- 8. Tiempo real para la app (hoy no hay ninguna tabla publicada)
-- ---------------------------------------------------------------------
alter publication supabase_realtime add table
    public.puertalab_eventos,
    public.puertalab_sensores,
    public.puertalab_alertas,
    public.puertalab_comandos;


-- ---------------------------------------------------------------------
-- 9. Grupos creados por el maestro desde la app
--    - Cada grupo tiene un dueño (docente_id = su fila en puertalab_personas).
--    - El maestro crea, renombra y borra SOLO sus grupos, y agrega o quita
--      alumnos solo en ellos.
--    - Un alumno puede estar en varios grupos y ve únicamente los suyos.
--    - La columna puertalab_personas.grupo (texto) NO se toca.
--    Se puede correr esta sección sola (desde aquí hasta el commit).
-- ---------------------------------------------------------------------

-- Persona vinculada a la cuenta con sesión iniciada (null si no hay).
-- security definer: se usa dentro de las políticas sin depender de RLS
-- y evita recursión entre las políticas de grupos y miembros.
create or replace function public.puertalab_mi_persona()
returns int
language sql stable security definer
set search_path to ''
as $$
    select c.persona_id
      from public.puertalab_cuentas_movil c
      join public.puertalab_personas p on p.id = c.persona_id
     where c.usuario_id = (select auth.uid())
       and c.habilitada and p.activo
$$;

-- ¿La cuenta actual puede crear grupos? (alcance 'equipo' con persona activa)
create or replace function public.puertalab_puedo_crear_grupos()
returns boolean
language sql stable security definer
set search_path to ''
as $$
    select exists (
        select 1
          from public.puertalab_cuentas_movil c
          join public.puertalab_personas p on p.id = c.persona_id
         where c.usuario_id = (select auth.uid())
           and c.habilitada and c.alcance = 'equipo' and p.activo
    )
$$;

create table public.puertalab_grupos (
    id         bigint generated always as identity primary key,
    nombre     text not null check (length(trim(nombre)) between 1 and 60),
    docente_id int  not null default public.puertalab_mi_persona()
               references public.puertalab_personas(id) on delete cascade,
    creado_en  timestamptz not null default now(),
    unique (docente_id, nombre)
);

create table public.puertalab_grupo_miembros (
    grupo_id    bigint not null references public.puertalab_grupos(id) on delete cascade,
    persona_id  int    not null references public.puertalab_personas(id) on delete cascade,
    agregado_en timestamptz not null default now(),
    primary key (grupo_id, persona_id)
);
create index puertalab_grupo_miembros_persona on public.puertalab_grupo_miembros (persona_id);

-- ¿El grupo es de la cuenta actual? / ¿la cuenta actual está inscrita?
create or replace function public.puertalab_soy_docente_de(p_grupo bigint)
returns boolean
language sql stable security definer
set search_path to ''
as $$
    select exists (select 1 from public.puertalab_grupos g
                    where g.id = p_grupo
                      and g.docente_id = public.puertalab_mi_persona())
$$;

create or replace function public.puertalab_soy_miembro_de(p_grupo bigint)
returns boolean
language sql stable security definer
set search_path to ''
as $$
    select exists (select 1 from public.puertalab_grupo_miembros m
                    where m.grupo_id = p_grupo
                      and m.persona_id = public.puertalab_mi_persona())
$$;

revoke execute on function public.puertalab_mi_persona(),
                           public.puertalab_puedo_crear_grupos(),
                           public.puertalab_soy_docente_de(bigint),
                           public.puertalab_soy_miembro_de(bigint)
    from public, anon;
grant execute on function public.puertalab_mi_persona(),
                          public.puertalab_puedo_crear_grupos(),
                          public.puertalab_soy_docente_de(bigint),
                          public.puertalab_soy_miembro_de(bigint)
    to authenticated;

alter table public.puertalab_grupos         enable row level security;
alter table public.puertalab_grupo_miembros enable row level security;

-- Grupos: el dueño hace todo; los alumnos inscritos solo los ven.
create policy puertalab_movil_grupos_select on public.puertalab_grupos
    for select to authenticated
    using (docente_id = (select public.puertalab_mi_persona())
           or public.puertalab_soy_miembro_de(id));

create policy puertalab_movil_grupos_insert on public.puertalab_grupos
    for insert to authenticated
    with check (docente_id = (select public.puertalab_mi_persona())
                and (select public.puertalab_puedo_crear_grupos()));

create policy puertalab_movil_grupos_update on public.puertalab_grupos
    for update to authenticated
    using      (docente_id = (select public.puertalab_mi_persona()))
    with check (docente_id = (select public.puertalab_mi_persona()));

create policy puertalab_movil_grupos_delete on public.puertalab_grupos
    for delete to authenticated
    using (docente_id = (select public.puertalab_mi_persona()));

-- Miembros: el dueño del grupo agrega y quita; cada alumno ve su inscripción.
create policy puertalab_movil_miembros_select on public.puertalab_grupo_miembros
    for select to authenticated
    using (public.puertalab_soy_docente_de(grupo_id)
           or persona_id = (select public.puertalab_mi_persona()));

create policy puertalab_movil_miembros_insert on public.puertalab_grupo_miembros
    for insert to authenticated
    with check (public.puertalab_soy_docente_de(grupo_id));

create policy puertalab_movil_miembros_delete on public.puertalab_grupo_miembros
    for delete to authenticated
    using (public.puertalab_soy_docente_de(grupo_id));

-- Permisos de tabla (RLS sigue decidiendo qué filas).
grant select, insert, update, delete on public.puertalab_grupos         to authenticated;
grant select, insert, delete         on public.puertalab_grupo_miembros to authenticated;
grant usage on sequence public.puertalab_grupos_id_seq to authenticated;

commit;
