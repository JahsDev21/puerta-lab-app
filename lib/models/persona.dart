/// Fila de puertalab_personas.
class Persona {
  final int id;
  final String nombre;
  final String rol;
  final String? grupo;
  final bool activo;
  final bool tieneHuella;
  final bool tieneRostro;
  final bool tieneTarjeta;

  const Persona({
    required this.id,
    required this.nombre,
    required this.rol,
    required this.grupo,
    required this.activo,
    required this.tieneHuella,
    required this.tieneRostro,
    required this.tieneTarjeta,
  });

  static const columnas = 'id, nombre, rol, grupo, activo, huella, rostro, tarjeta';

  factory Persona.fromMap(Map<String, dynamic> m) => Persona(
        id: m['id'] as int,
        nombre: m['nombre'] as String,
        rol: m['rol'] as String,
        grupo: m['grupo'] as String?,
        activo: m['activo'] as bool,
        tieneHuella: m['huella'] != null,
        tieneRostro: m['rostro'] != null,
        tieneTarjeta: m['tarjeta'] != null,
      );
}
