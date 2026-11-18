import 'package:flutter/material.dart';

/// Mensaje centrado para listas vacías o errores, con botón opcional.
class EstadoVacio extends StatelessWidget {
  final IconData icono;
  final String texto;
  final String? accion;
  final VoidCallback? onAccion;

  const EstadoVacio({
    super.key,
    required this.icono,
    required this.texto,
    this.accion,
    this.onAccion,
  });

  const EstadoVacio.error({super.key, required this.texto, this.onAccion})
      : icono = Icons.cloud_off,
        accion = 'Reintentar';

  @override
  Widget build(BuildContext context) {
    final gris = Theme.of(context).colorScheme.outline;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 56, color: gris),
            const SizedBox(height: 12),
            Text(texto, textAlign: TextAlign.center, style: TextStyle(color: gris)),
            if (accion != null && onAccion != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAccion, child: Text(accion!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Texto de error amigable para mostrar al usuario.
String mensajeError(Object e) {
  final s = e.toString();
  if (s.contains('SocketException') || s.contains('ClientException')) {
    return 'Sin conexión con el servidor. Revisa tu internet.';
  }
  if (s.contains('PGRST205') || s.contains('42P01')) {
    return 'Esta función necesita cambios en la base de datos que aún no se aplican.\n'
        '(supabase/propuesta_cambios.sql)';
  }
  if (s.contains('23505')) {
    return 'Ya existe un grupo con ese nombre.';
  }
  if (s.contains('42501')) {
    return 'Tu cuenta no tiene permiso para esta acción o información.\n'
        'Falta un permiso (GRANT o política) en la base de datos.';
  }
  return 'Ocurrió un error al cargar los datos.\n$s';
}
