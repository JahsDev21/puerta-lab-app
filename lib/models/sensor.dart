/// Fila de puertalab_sensores: último valor reportado de cada sensor.
class Sensor {
  final String nombre;
  final String valor;
  final DateTime fecha;

  const Sensor({required this.nombre, required this.valor, required this.fecha});

  factory Sensor.fromMap(Map<String, dynamic> m) => Sensor(
        nombre: m['nombre'] as String,
        valor: m['valor'] as String,
        fecha: DateTime.parse(m['fecha'] as String).toLocal(),
      );
}
