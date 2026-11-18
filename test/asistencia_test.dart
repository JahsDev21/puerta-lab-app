import 'package:app_iot/models/asistencia.dart';
import 'package:app_iot/models/evento.dart';
import 'package:app_iot/models/horario.dart';
import 'package:flutter_test/flutter_test.dart';

// Lunes 9 de noviembre de 2026; clase de 07:00 a 09:00 los lunes y miércoles.
final lunes = DateTime(2026, 11, 9);
const clases = [
  Horario(personaId: 1, diaIso: 1, desdeMin: 7 * 60, hastaMin: 9 * 60),
  Horario(personaId: 1, diaIso: 3, desdeMin: 7 * 60, hastaMin: 9 * 60),
];

Evento entrada(DateTime f, {String resultado = 'Permitido', String sentido = 'Entrada'}) =>
    Evento(
      id: f.millisecondsSinceEpoch,
      fecha: f,
      personaId: 1,
      persona: 'Alumno',
      metodo: 'Huella',
      resultado: resultado,
      sentido: sentido,
      origen: 'manual',
    );

List<RegistroAsistencia> calcular(List<Evento> eventos,
        {List<Horario> horarios = clases, DateTime? ahora}) =>
    calcularAsistencia(
      eventos: eventos,
      horarios: horarios,
      inicio: lunes,
      ahora: ahora ?? DateTime(2026, 11, 9, 12),
    );

void main() {
  test('entrada dentro de la tolerancia cuenta como a tiempo', () {
    final r = calcular([entrada(DateTime(2026, 11, 9, 7, 10))]);
    expect(r.single.estado, EstadoAsistencia.aTiempo);
  });

  test('entrada hasta 15 min antes también cuenta', () {
    final r = calcular([entrada(DateTime(2026, 11, 9, 6, 45))]);
    expect(r.single.estado, EstadoAsistencia.aTiempo);
  });

  test('después de la tolerancia es retardo', () {
    final r = calcular([entrada(DateTime(2026, 11, 9, 7, 11))]);
    expect(r.single.estado, EstadoAsistencia.retardo);
  });

  test('solo cuenta la primera entrada del bloque', () {
    final r = calcular([
      entrada(DateTime(2026, 11, 9, 7, 30)),
      entrada(DateTime(2026, 11, 9, 7, 5)),
    ]);
    expect(r.single.estado, EstadoAsistencia.aTiempo);
  });

  test('bloque terminado sin entrada es falta', () {
    final r = calcular([]);
    expect(r.single.estado, EstadoAsistencia.falta);
  });

  test('bloque en curso todavía no es falta', () {
    final r = calcular([], ahora: DateTime(2026, 11, 9, 8));
    expect(r, isEmpty);
  });

  test('rechazos y salidas no cuentan como asistencia', () {
    final r = calcular([
      entrada(DateTime(2026, 11, 9, 7), resultado: 'Rechazado'),
      entrada(DateTime(2026, 11, 9, 7, 5), sentido: 'Salida'),
    ]);
    expect(r.single.estado, EstadoAsistencia.falta);
  });

  test('entrada sin clase ese momento es fuera de horario', () {
    final r = calcular([
      entrada(DateTime(2026, 11, 9, 7)),
      entrada(DateTime(2026, 11, 9, 11)),
    ]);
    expect(r.map((x) => x.estado),
        containsAll([EstadoAsistencia.aTiempo, EstadoAsistencia.fueraDeHorario]));
  });

  test('sin horario asignado se marca como registro simple', () {
    final r = calcular([entrada(DateTime(2026, 11, 9, 11))], horarios: []);
    expect(r.single.estado, EstadoAsistencia.sinHorario);
  });

  test('cuenta faltas de varios días', () {
    // Del lunes 9 al jueves 12: lunes y miércoles sin entrada.
    final r = calcular([], ahora: DateTime(2026, 11, 12, 12));
    expect(r.where((x) => x.estado == EstadoAsistencia.falta).length, 2);
  });
}
