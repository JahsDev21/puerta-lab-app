/// Fila de puertalab_eventos (bitácora de accesos).
class Evento {
  /// Valores permitidos por los CHECK de la tabla.
  static const metodos = ['Huella', 'Rostro', 'Tarjeta', 'Otro'];
  static const resultados = ['Permitido', 'Rechazado'];

  static const columnas =
      'id, fecha, persona_id, persona, metodo, resultado, sentido, origen';

  final int id;
  final DateTime fecha; // hora local del teléfono
  final int? personaId; // null = persona no registrada o eliminada
  final String persona;
  final String metodo;
  final String resultado;
  final String sentido; // Entrada | Salida | Sin especificar
  final String origen; // manual | dispositivo

  const Evento({
    required this.id,
    required this.fecha,
    required this.personaId,
    required this.persona,
    required this.metodo,
    required this.resultado,
    required this.sentido,
    required this.origen,
  });

  factory Evento.fromMap(Map<String, dynamic> m) => Evento(
        id: m['id'] as int,
        fecha: DateTime.parse(m['fecha'] as String).toLocal(),
        personaId: m['persona_id'] as int?,
        persona: m['persona'] as String,
        metodo: m['metodo'] as String,
        resultado: m['resultado'] as String,
        sentido: m['sentido'] as String,
        origen: m['origen'] as String,
      );

  bool get permitido => resultado == 'Permitido';
  bool get esEntrada => sentido != 'Salida';
  bool get esManual => origen == 'manual';
}
