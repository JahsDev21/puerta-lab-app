/// Fila de puertalab_grupos (grupo creado por un maestro desde la app).
class Grupo {
  /// Incluye el conteo de alumnos con una sola consulta.
  static const columnas = 'id, nombre, docente_id, creado_en, puertalab_grupo_miembros(count)';

  final int id;
  final String nombre;
  final int docenteId;
  final DateTime creadoEn;
  final int totalAlumnos;

  const Grupo({
    required this.id,
    required this.nombre,
    required this.docenteId,
    required this.creadoEn,
    required this.totalAlumnos,
  });

  factory Grupo.fromMap(Map<String, dynamic> m) {
    final conteo = m['puertalab_grupo_miembros'];
    return Grupo(
      id: m['id'] as int,
      nombre: m['nombre'] as String,
      docenteId: m['docente_id'] as int,
      creadoEn: DateTime.parse(m['creado_en'] as String).toLocal(),
      totalAlumnos: conteo is List && conteo.isNotEmpty
          ? (conteo.first['count'] as int? ?? 0)
          : 0,
    );
  }
}
