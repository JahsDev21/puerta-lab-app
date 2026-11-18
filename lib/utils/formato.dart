import 'package:intl/intl.dart';

final _hora = DateFormat('HH:mm');
final _diaLargo = DateFormat("EEEE d 'de' MMMM", 'es');
final _diaCorto = DateFormat('d MMM yyyy', 'es');

String hora(DateTime f) => _hora.format(f);

String diaCorto(DateTime f) => _diaCorto.format(f);

String diaLargo(DateTime f) {
  final hoy = soloDia(DateTime.now());
  final d = soloDia(f);
  if (d == hoy) return 'Hoy';
  if (d == hoy.subtract(const Duration(days: 1))) return 'Ayer';
  final s = _diaLargo.format(f);
  return s[0].toUpperCase() + s.substring(1);
}

String haceTiempo(DateTime f) {
  final d = DateTime.now().difference(f);
  if (d.inSeconds < 60) return 'hace unos segundos';
  if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
  if (d.inHours < 24) return 'hace ${d.inHours} h';
  return 'el ${diaCorto(f)} a las ${hora(f)}';
}

/// 450 -> "07:30"
String minutosATexto(int minutos) =>
    '${(minutos ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutos % 60).toString().padLeft(2, '0')}';

DateTime soloDia(DateTime f) => DateTime(f.year, f.month, f.day);
