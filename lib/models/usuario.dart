/// `personal`: solo ve sus propios datos. `equipo`: ve todo (docentes/admin).
/// Lo define la columna `alcance` de puertalab_cuentas_movil.
enum Alcance { personal, equipo }

/// Usuario con sesión iniciada en la app.
class Usuario {
  final String authId;
  final String correo;
  final int? personaId; // puede ser null en cuentas de alcance 'equipo'
  final String nombre;
  final String? rol;
  final String? grupo;
  final Alcance alcance;

  const Usuario({
    required this.authId,
    required this.correo,
    required this.personaId,
    required this.nombre,
    required this.rol,
    required this.grupo,
    required this.alcance,
  });

  bool get esEquipo => alcance == Alcance.equipo;

  String get rolTexto => rol ?? (esEquipo ? 'Equipo' : 'Sin rol');
}
