import '../utils/formato.dart';
import 'evento.dart';
import 'horario.dart';

enum EstadoAsistencia { aTiempo, retardo, falta, fueraDeHorario, sinHorario }

class RegistroAsistencia {
  final DateTime dia;
  final EstadoAsistencia estado;
  final Horario? bloque; // bloque de horario al que corresponde
  final DateTime? entrada; // null en faltas

  const RegistroAsistencia({
    required this.dia,
    required this.estado,
    this.bloque,
    this.entrada,
  });

  /// Momento para ordenar: la entrada o, si es falta, el inicio del bloque.
  DateTime get momento =>
      entrada ?? dia.add(Duration(minutes: bloque?.desdeMin ?? 0));
}

/// Reglas de asistencia (mismos valores que la vista propuesta para la BD).
class ReglasAsistencia {
  /// Se acepta la entrada hasta 15 min antes del inicio del bloque.
  static const anticipacionMin = 15;

  /// Después de 10 min del inicio cuenta como retardo.
  static const toleranciaMin = 10;
}

/// Calcula la asistencia de UNA persona a partir de sus eventos y horarios.
///
/// - Cuenta la primera entrada permitida dentro de cada bloque de horario.
/// - Entradas fuera de cualquier bloque: "fuera de horario" (una por día).
/// - Bloques ya terminados sin entrada: "falta".
/// La BD actual no tiene tabla de asistencias, por eso se calcula aquí.
List<RegistroAsistencia> calcularAsistencia({
  required List<Evento> eventos,
  required List<Horario> horarios,
  required DateTime inicio,
  required DateTime ahora,
}) {
  final registros = <RegistroAsistencia>[];
  final bloquesCubiertos = <String>{};
  final diasFuera = <DateTime>{};
  String clave(DateTime dia, Horario h) => '${dia.toIso8601String()}|${h.diaIso}|${h.desdeMin}';

  final entradas = eventos
      .where((e) =>
          e.permitido &&
          e.esEntrada &&
          !e.fecha.isBefore(inicio) &&
          !e.fecha.isAfter(ahora))
      .toList()
    ..sort((a, b) => a.fecha.compareTo(b.fecha));

  for (final e in entradas) {
    final dia = soloDia(e.fecha);
    final min = e.fecha.hour * 60 + e.fecha.minute;
    final candidatos = horarios
        .where((h) =>
            h.diaIso == e.fecha.weekday &&
            min >= h.desdeMin - ReglasAsistencia.anticipacionMin &&
            min < h.hastaMin)
        .toList()
      ..sort((a, b) => a.desdeMin.compareTo(b.desdeMin));

    if (candidatos.isEmpty) {
      if (!diasFuera.add(dia)) continue;
      registros.add(RegistroAsistencia(
        dia: dia,
        estado: horarios.isEmpty
            ? EstadoAsistencia.sinHorario
            : EstadoAsistencia.fueraDeHorario,
        entrada: e.fecha,
      ));
      continue;
    }

    final bloque = candidatos.first;
    if (!bloquesCubiertos.add(clave(dia, bloque))) continue;
    registros.add(RegistroAsistencia(
      dia: dia,
      estado: min <= bloque.desdeMin + ReglasAsistencia.toleranciaMin
          ? EstadoAsistencia.aTiempo
          : EstadoAsistencia.retardo,
      bloque: bloque,
      entrada: e.fecha,
    ));
  }

  // Faltas: bloques que ya terminaron y no tienen entrada.
  final ultimoDia = soloDia(ahora);
  for (var d = soloDia(inicio);
      !d.isAfter(ultimoDia);
      d = DateTime(d.year, d.month, d.day + 1)) {
    for (final h in horarios.where((h) => h.diaIso == d.weekday)) {
      final finBloque = d.add(Duration(minutes: h.hastaMin));
      if (finBloque.isAfter(ahora)) continue;
      if (bloquesCubiertos.contains(clave(d, h))) continue;
      registros.add(RegistroAsistencia(
          dia: d, estado: EstadoAsistencia.falta, bloque: h));
    }
  }

  registros.sort((a, b) => b.momento.compareTo(a.momento));
  return registros;
}
