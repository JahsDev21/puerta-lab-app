import 'package:flutter/material.dart';

import '../models/evento.dart';
import '../utils/formato.dart';

class EventoTile extends StatelessWidget {
  final Evento evento;
  final bool mostrarFecha;

  const EventoTile({super.key, required this.evento, this.mostrarFecha = false});

  static IconData iconoMetodo(String metodo) => switch (metodo) {
        'Huella' => Icons.fingerprint,
        'Rostro' => Icons.face,
        'Tarjeta' => Icons.credit_card,
        _ => Icons.more_horiz,
      };

  @override
  Widget build(BuildContext context) {
    final ok = evento.permitido;
    final color = ok ? Colors.green : Colors.red;
    final partes = [
      evento.metodo,
      if (evento.sentido != 'Sin especificar') evento.sentido,
      mostrarFecha ? '${diaCorto(evento.fecha)} ${hora(evento.fecha)}' : hora(evento.fecha),
    ];

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(ok ? Icons.check : Icons.close, color: color),
        ),
        title: Text(evento.persona),
        subtitle: Text(partes.join(' · ')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (evento.esManual)
              Tooltip(
                message: 'Registrado manualmente',
                child: Icon(Icons.edit_note,
                    color: Theme.of(context).colorScheme.outline),
              ),
            Icon(iconoMetodo(evento.metodo)),
          ],
        ),
      ),
    );
  }
}
