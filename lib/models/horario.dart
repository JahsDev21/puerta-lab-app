import '../utils/formato.dart';

/// Fila de puertalab_horarios. Las horas se guardan en minutos desde 00:00.
class Horario {
  static const dias = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
  ];

  final int personaId;
  final int diaIso; // 1 = lunes ... 7 = domingo (igual que DateTime.weekday)
  final int desdeMin;
  final int hastaMin;

  const Horario({
    required this.personaId,
    required this.diaIso,
    required this.desdeMin,
    required this.hastaMin,
  });

  factory Horario.fromMap(Map<String, dynamic> m) => Horario(
        personaId: m['persona_id'] as int,
        diaIso: m['dia_iso'] as int,
        desdeMin: _minutos(m['desde'] as String),
        hastaMin: _minutos(m['hasta'] as String),
      );

  /// "07:30:00" -> 450
  static int _minutos(String t) {
    final p = t.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  String get diaTexto => dias[diaIso - 1];
  String get rangoTexto => '${minutosATexto(desdeMin)} – ${minutosATexto(hastaMin)}';
}
