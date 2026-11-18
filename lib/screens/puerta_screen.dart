import 'dart:async';

import 'package:flutter/material.dart';

import '../models/evento.dart';
import '../models/sensor.dart';
import '../services/puertalab_service.dart';
import '../utils/formato.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/evento_tile.dart';

/// Estado del dispositivo (tabla puertalab_sensores) y últimos accesos.
/// Se actualiza sola cada 30 s porque la BD aún no publica cambios en Realtime.
class PuertaScreen extends StatefulWidget {
  const PuertaScreen({super.key});

  /// Si la última lectura es más vieja que esto, el dispositivo se considera sin conexión.
  static const limiteEnLinea = Duration(minutes: 5);

  @override
  State<PuertaScreen> createState() => _PuertaScreenState();
}

class _PuertaScreenState extends State<PuertaScreen> {
  final _api = PuertaLabService.instancia;
  Timer? _timer;

  List<Sensor>? _sensores;
  List<Evento> _recientes = [];
  Object? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _cargar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final r = await Future.wait([
        _api.sensores(),
        _api.eventos(cantidad: 5),
      ]);
      if (!mounted) return;
      setState(() {
        _sensores = r[0] as List<Sensor>;
        _recientes = r[1] as List<Evento>;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sensores = _sensores;
    if (sensores == null) {
      return _error != null
          ? EstadoVacio.error(texto: mensajeError(_error!), onAccion: _cargar)
          : const Center(child: CircularProgressIndicator());
    }

    final ultima = sensores.isEmpty
        ? null
        : sensores.map((s) => s.fecha).reduce((a, b) => a.isAfter(b) ? a : b);
    final enLinea = ultima != null &&
        DateTime.now().difference(ultima) < PuertaScreen.limiteEnLinea;

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: const ListTile(
                leading: Icon(Icons.cloud_off),
                title: Text('No se pudo actualizar; mostrando los últimos datos'),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.circle,
                          size: 12, color: enLinea ? Colors.green : Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          enLinea ? 'Dispositivo en línea' : 'Dispositivo sin conexión',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ultima == null
                        ? 'El dispositivo todavía no ha enviado lecturas.'
                        : 'Última lectura ${haceTiempo(ultima)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (sensores.isNotEmpty) const Divider(height: 24),
                  for (final s in sensores)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(_iconoSensor(s.nombre)),
                      title: Text(s.nombre),
                      subtitle: Text(haceTiempo(s.fecha)),
                      trailing: Text(s.valor,
                          style: Theme.of(context).textTheme.titleSmall),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.meeting_room),
                      label: const Text('Abrir puerta'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('La apertura remota aún no está disponible.',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Accesos recientes', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          if (_recientes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: EstadoVacio(icono: Icons.list_alt, texto: 'Sin accesos registrados'),
            ),
          for (final e in _recientes) EventoTile(evento: e, mostrarFecha: true),
        ],
      ),
    );
  }

  IconData _iconoSensor(String nombre) {
    final n = nombre.toLowerCase();
    if (n.contains('puerta') || n.contains('magn')) return Icons.sensor_door;
    if (n.contains('pir') || n.contains('presencia')) return Icons.directions_walk;
    if (n.contains('huella')) return Icons.fingerprint;
    if (n.contains('rfid') || n.contains('tarjeta')) return Icons.credit_card;
    if (n.contains('cam')) return Icons.photo_camera;
    if (n.contains('temp')) return Icons.thermostat;
    return Icons.sensors;
  }
}
