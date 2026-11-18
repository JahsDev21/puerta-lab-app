# PuertaLab · App móvil

App en Flutter del **sistema de control de acceso y asistencia biométrica** del laboratorio (Propuesta 2, TecNM La Laguna). Usa **Supabase** como backend: autenticación, base de datos con RLS y, más adelante, Realtime y Storage.

## Qué hace hoy

La pantalla que ve cada usuario depende del `alcance` de su cuenta en `puertalab_cuentas_movil`:

| Pantalla | Quién | Qué hace |
|---|---|---|
| **Login** | Todos | Correo y contraseña de Supabase Auth. La sesión se queda guardada. Rechaza cuentas sin vincular, deshabilitadas o de personas inactivas |
| **Puerta** | Equipo | Estado del dispositivo según la tabla `sensores`, últimos accesos y actualización cada 30 s. El botón "Abrir puerta" está desactivado hasta que exista la tabla de comandos |
| **Bitácora** | Equipo: todos los accesos / Alumno: solo los suyos | Accesos agrupados por día, filtros por fecha, resultado y método, carga por páginas |
| **Personas** | Equipo | Buscador, credenciales registradas, y asistencia y accesos de cada persona |
| **Grupos** | Equipo (maestro) | Crear grupos, agregar o quitar alumnos y ver la asistencia del grupo. ⚠️ Requiere la sección 9 de `supabase/propuesta_cambios.sql` |
| **Mi asistencia** | Alumno | A tiempo, retardo, falta y fuera de horario en 7, 30 o 90 días, y su horario |
| **Ajustes** | Todos | Perfil y cerrar sesión |

La asistencia se calcula **en la app** a partir de `eventos` y `horarios` ([lib/models/asistencia.dart](lib/models/asistencia.dart)):
- se puede entrar hasta 15 min antes del inicio de la clase;
- hasta 10 min después del inicio cuenta como a tiempo;
- más tarde cuenta como retardo;
- un bloque de horario sin entrada cuenta como falta.

## Cómo correrla

Requisitos: Flutter 3.x y un emulador de Android o un teléfono con depuración USB.

1. Clona el repo y en la carpeta del proyecto corre:
   ```
   flutter pub get
   ```
2. Copia `supabase.example.json` como **`supabase.json`** y pon la URL del proyecto y la clave `sb_publishable_...`. Pídelas al equipo: este archivo **no se sube a Git**.
   ```json
   {
     "SUPABASE_URL": "https://<proyecto>.supabase.co",
     "SUPABASE_ANON_KEY": "sb_publishable_..."
   }
   ```
   > Solo va la clave *publishable* (anon). La `sb_secret_...` (service_role) **nunca** va en la app.
3. Ejecuta la app:
   - **VS Code:** F5 con la configuración **PuertaLab** (ya incluida en `.vscode/launch.json`).
   - **Terminal:** `flutter run --dart-define-from-file=supabase.json`
4. Para generar un APK que se pueda instalar en cualquier Android:
   ```
   flutter build apk --release --dart-define-from-file=supabase.json
   ```
   Queda en `build/app/outputs/flutter-apk/app-release.apk`.

### Cuentas para probar

Una cuenta necesita dos cosas para entrar: existir en **Authentication → Users** y tener su fila en `puertalab_cuentas_movil`.

[supabase/datos_prueba.sql](supabase/datos_prueba.sql) crea las personas, vincula las cuentas `alumno.prueba@puertalab.test` y `docente.prueba@puertalab.test` (hay que crearlas primero en Auth) y carga horarios y accesos de ejemplo. Al final del archivo está el bloque para borrar todo.

## Estructura

```
lib/
  main.dart                 arranque, tema, restaurar sesión
  config.dart               lee SUPABASE_URL / SUPABASE_ANON_KEY (dart-define)
  services/
    puertalab_service.dart  todas las consultas a Supabase
  models/                   usuario, persona, evento, horario, sensor, grupo, asistencia
  screens/                  login, home (pestañas), puerta, personas, grupos
  views/                    bitácora y asistencia (se reutilizan en varias pantallas)
  widgets/                  tarjetas de evento, estados vacío y error
supabase/
  propuesta_cambios.sql     cambios propuestos a la BD (NO aplicados todos)
  datos_prueba.sql          datos de prueba (solo inserta filas)
schema.json.txt             export del esquema actual de la BD
test/                       pruebas del cálculo de asistencia (flutter test)
```

## Base de datos

Proyecto Supabase **PuertaLab**. Las tablas llevan el prefijo `puertalab_` y todas tienen RLS:
- una cuenta con alcance `personal` ve solo sus datos;
- una cuenta con alcance `equipo` ve todo el laboratorio.

Además de la política RLS, el rol `authenticated` necesita **GRANT SELECT** en las tablas que lee la app: `cuentas_movil`, `personas`, `eventos`, `horarios` y `sensores`. Si falta, la app muestra *"Tu cuenta no tiene permiso…"*.

### Cambios propuestos (pendientes de revisar)

Están en [supabase/propuesta_cambios.sql](supabase/propuesta_cambios.sql), separados por secciones:

1. Política de lectura en `roles` y columna `puede_abrir_remoto`
2. Tabla `comandos` para **abrir la puerta desde la app**
3. Columnas nuevas en `eventos`: motivo del rechazo, foto y apertura remota
4. Tabla `alertas`: intentos fallidos, puerta forzada, etc.
5. Tokens de notificaciones push (FCM)
6. Vista `asistencias` calculada en la BD
7. Bucket de Storage para las fotos de la ESP32-CAM
8. Publicar tablas en Realtime
9. **Grupos del maestro**: tablas `grupos` y `grupo_miembros`, con políticas para que cada maestro gestione solo los suyos

## Pendiente

- [ ] Aplicar y revisar los cambios de `propuesta_cambios.sql`, sobre todo la sección 9 para que funcione Grupos
- [ ] Apertura remota de la puerta (requiere la sección 2 y el firmware del ESP32)
- [ ] Alertas con foto y notificaciones push
- [ ] Bitácora y estado en tiempo real (Realtime)
- [ ] Configurar el Wi-Fi del ESP32 por BLE
- [ ] Pantalla "Mis grupos" para el alumno
- [ ] Integración con el ESP32: escribirá en `eventos` y `sensores` (por MQTT con un puente, o por HTTPS directo)
