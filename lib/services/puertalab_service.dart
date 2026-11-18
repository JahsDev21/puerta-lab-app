import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/evento.dart';
import '../models/grupo.dart';
import '../models/horario.dart';
import '../models/persona.dart';
import '../models/sensor.dart';
import '../models/usuario.dart';

/// La cuenta existe en Supabase Auth pero no puede usar la app
/// (sin fila en puertalab_cuentas_movil, deshabilitada o persona inactiva).
class CuentaNoValida implements Exception {
  final String mensaje;
  const CuentaNoValida(this.mensaje);
  @override
  String toString() => mensaje;
}

/// Acceso a Supabase. RLS decide qué filas ve cada cuenta
/// (personal = lo suyo, equipo = todo). Lo único que se escribe son los
/// grupos del maestro (sección 9 de supabase/propuesta_cambios.sql).
class PuertaLabService {
  static final instancia = PuertaLabService._();
  PuertaLabService._();

  SupabaseClient get _db => Supabase.instance.client;

  // ---------------------------------------------------------------- sesión

  Future<Usuario> iniciarSesion(String correo, String contrasena) async {
    await _db.auth.signInWithPassword(email: correo, password: contrasena);
    try {
      return await _cargarUsuarioActual();
    } on CuentaNoValida {
      await _db.auth.signOut();
      rethrow;
    }
  }

  /// Usuario de la sesión guardada en el teléfono, o null si no hay sesión.
  Future<Usuario?> restaurarSesion() async {
    if (_db.auth.currentSession == null) return null;
    try {
      return await _cargarUsuarioActual();
    } on CuentaNoValida {
      await _db.auth.signOut();
      return null;
    }
  }

  Future<void> cerrarSesion() => _db.auth.signOut();

  Future<Usuario> _cargarUsuarioActual() async {
    final user = _db.auth.currentUser!;

    final cuenta = await _db
        .from('puertalab_cuentas_movil')
        .select('persona_id, alcance, habilitada')
        .eq('usuario_id', user.id)
        .maybeSingle();

    if (cuenta == null) {
      throw const CuentaNoValida(
          'Tu cuenta no está dada de alta en PuertaLab. Pide al administrador que la vincule.');
    }
    if (cuenta['habilitada'] != true) {
      throw const CuentaNoValida('Tu cuenta está deshabilitada.');
    }

    final personaId = cuenta['persona_id'] as int?;
    Map<String, dynamic>? persona;
    if (personaId != null) {
      persona = await _db
          .from('puertalab_personas')
          .select('nombre, rol, grupo, activo')
          .eq('id', personaId)
          .maybeSingle();
      if (persona != null && persona['activo'] == false) {
        throw const CuentaNoValida('Tu registro en el laboratorio está inactivo.');
      }
    }

    return Usuario(
      authId: user.id,
      correo: user.email ?? '',
      personaId: personaId,
      nombre: persona?['nombre'] as String? ?? user.email ?? 'Usuario',
      rol: persona?['rol'] as String?,
      grupo: persona?['grupo'] as String?,
      alcance: cuenta['alcance'] == 'equipo' ? Alcance.equipo : Alcance.personal,
    );
  }

  // ---------------------------------------------------------------- datos

  /// Bitácora más reciente primero. [fin] es inclusivo (todo ese día).
  Future<List<Evento>> eventos({
    int desde = 0,
    int cantidad = 30,
    int? personaId,
    List<int>? personaIds,
    String? resultado,
    String? metodo,
    DateTime? inicio,
    DateTime? fin,
  }) async {
    var q = _db.from('puertalab_eventos').select(Evento.columnas);
    if (personaId != null) q = q.eq('persona_id', personaId);
    if (personaIds != null) q = q.inFilter('persona_id', personaIds);
    if (resultado != null) q = q.eq('resultado', resultado);
    if (metodo != null) q = q.eq('metodo', metodo);
    if (inicio != null) q = q.gte('fecha', inicio.toUtc().toIso8601String());
    if (fin != null) {
      final finExclusivo = DateTime(fin.year, fin.month, fin.day + 1);
      q = q.lt('fecha', finExclusivo.toUtc().toIso8601String());
    }
    final filas = await q
        .order('fecha', ascending: false)
        .range(desde, desde + cantidad - 1);
    return filas.map(Evento.fromMap).toList();
  }

  Future<List<Horario>> horarios({int? personaId, List<int>? personaIds}) async {
    var q = _db.from('puertalab_horarios').select('persona_id, dia_iso, desde, hasta');
    if (personaId != null) q = q.eq('persona_id', personaId);
    if (personaIds != null) q = q.inFilter('persona_id', personaIds);
    final filas = await q.order('dia_iso').order('desde');
    return filas.map(Horario.fromMap).toList();
  }

  Future<List<Persona>> personas() async {
    final filas = await _db
        .from('puertalab_personas')
        .select(Persona.columnas)
        .order('nombre');
    return filas.map(Persona.fromMap).toList();
  }

  Future<List<Sensor>> sensores() async {
    final filas = await _db
        .from('puertalab_sensores')
        .select('nombre, valor, fecha')
        .order('nombre');
    return filas.map(Sensor.fromMap).toList();
  }

  // ---------------------------------------------------------------- grupos

  /// Grupos visibles: los propios (maestro) o en los que está inscrito (alumno).
  Future<List<Grupo>> grupos() async {
    final filas = await _db.from('puertalab_grupos').select(Grupo.columnas).order('nombre');
    return filas.map(Grupo.fromMap).toList();
  }

  /// docente_id lo pone la BD con la persona de la sesión.
  Future<void> crearGrupo(String nombre) =>
      _db.from('puertalab_grupos').insert({'nombre': nombre.trim()});

  Future<void> renombrarGrupo(int grupoId, String nombre) =>
      _db.from('puertalab_grupos').update({'nombre': nombre.trim()}).eq('id', grupoId);

  /// Borra el grupo y sus inscripciones (on delete cascade). No borra personas.
  Future<void> eliminarGrupo(int grupoId) =>
      _db.from('puertalab_grupos').delete().eq('id', grupoId);

  Future<List<Persona>> miembros(int grupoId) async {
    final filas = await _db
        .from('puertalab_grupo_miembros')
        .select('puertalab_personas(${Persona.columnas})')
        .eq('grupo_id', grupoId);
    final personas = [
      for (final f in filas)
        if (f['puertalab_personas'] != null)
          Persona.fromMap(f['puertalab_personas'] as Map<String, dynamic>),
    ]..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    return personas;
  }

  /// Ignora a los que ya estaban en el grupo.
  Future<void> agregarMiembros(int grupoId, List<int> personaIds) async {
    if (personaIds.isEmpty) return;
    await _db.from('puertalab_grupo_miembros').upsert(
      [for (final id in personaIds) {'grupo_id': grupoId, 'persona_id': id}],
      onConflict: 'grupo_id,persona_id',
      ignoreDuplicates: true,
    );
  }

  Future<void> quitarMiembro(int grupoId, int personaId) => _db
      .from('puertalab_grupo_miembros')
      .delete()
      .eq('grupo_id', grupoId)
      .eq('persona_id', personaId);
}
