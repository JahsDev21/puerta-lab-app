import 'package:flutter/material.dart';

import '../models/asistencia.dart';
import '../models/evento.dart';
import '../models/horario.dart';
import '../services/puertalab_service.dart';
import '../utils/formato.dart';
import '../widgets/estado_vacio.dart';

/// Asistencia de una persona: resumen, horario y registros por bloque.
class AsistenciaView extends StatefulWidget {
  final int personaId;
  const AsistenciaView({super.key, required this.personaId});

  @override
  State<AsistenciaView> createState() => _AsistenciaViewState();
}

class _AsistenciaViewState extends State<AsistenciaView> {
  final _api = PuertaLabService.instancia;

  int _dias = 30;
  List<Horario> _horarios = [];
  List<RegistroAsistencia>? _registros;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final ahora = DateTime.now();
      final inicio = soloDia(ahora).subtract(Duration(days: _dias - 1));
      final resultados = await Future.wait([
        _api.horarios(personaId: widget.personaId),
        _api.eventos(
          personaId: widget.personaId,
          resultado: 'Permitido',
          inicio: inicio,
          cantidad: 1000,
        ),
      ]);
      final horarios = resultados[0] as List<Horario>;
      final registros = calcularAsistencia(
        eventos: resultados[1] as List<Evento>,
        horarios: horarios,
        inicio: inicio,
        ahora: ahora,
      );
      if (!mounted) return;
      setState(() {
        _horarios = horarios;
        _registros = registros;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return EstadoVacio.error(texto: mensajeError(_error!), onAccion: _cargar);
    }
    final registros = _registros;
    if (registros == null) {
      return const Center(child: CircularProgressIndicator());
    }

    int contar(EstadoAsistencia e) => registros.where((r) => r.estado == e).length;

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 7, label: Text('7 días')),
              ButtonSegment(value: 30, label: Text('30 días')),
              ButtonSegment(value: 90, label: Text('90 días')),
            ],
            selected: {_dias},
            onSelectionChanged: (s) {
              setState(() {
                _dias = s.first;
                _registros = null;
              });
              _cargar();
            },
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Contador(EstadoAsistencia.aTiempo, contar(EstadoAsistencia.aTiempo)),
                  _Contador(EstadoAsistencia.retardo, contar(EstadoAsistencia.retardo)),
                  _Contador(EstadoAsistencia.falta, contar(EstadoAsistencia.falta)),
                  _Contador(EstadoAsistencia.fueraDeHorario,
                      contar(EstadoAsistencia.fueraDeHorario)),
                ],
              ),
            ),
          ),
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Horario'),
              subtitle: Text(_horarios.isEmpty
                  ? 'Sin horario asignado'
                  : '${_horarios.length} bloques por semana'),
              shape: const Border(),
              children: [
                for (final h in _horarios)
                  ListTile(
                    dense: true,
                    title: Text(h.diaTexto),
                    trailing: Text(h.rangoTexto),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
            child: Text(
              'Llegar hasta ${ReglasAsistencia.toleranciaMin} min después del inicio cuenta como a tiempo.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (registros.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: EstadoVacio(
                  icono: Icons.fact_check, texto: 'Sin registros en este periodo'),
            ),
          for (final r in registros) _RegistroTile(r),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- estilos

({String texto, Color color, IconData icono}) _estilo(EstadoAsistencia e) =>
    switch (e) {
      EstadoAsistencia.aTiempo =>
        (texto: 'A tiempo', color: Colors.green, icono: Icons.check_circle),
      EstadoAsistencia.retardo =>
        (texto: 'Retardo', color: Colors.orange, icono: Icons.watch_later),
      EstadoAsistencia.falta =>
        (texto: 'Falta', color: Colors.red, icono: Icons.cancel),
      EstadoAsistencia.fueraDeHorario =>
        (texto: 'Fuera de horario', color: Colors.blueGrey, icono: Icons.event_busy),
      EstadoAsistencia.sinHorario =>
        (texto: 'Registro', color: Colors.blueGrey, icono: Icons.login),
    };

class _Contador extends StatelessWidget {
  final EstadoAsistencia estado;
  final int valor;
  const _Contador(this.estado, this.valor);

  @override
  Widget build(BuildContext context) {
    final s = _estilo(estado);
    return Column(
      children: [
        Text('$valor',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: s.color, fontWeight: FontWeight.bold)),
        Text(s.texto, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _RegistroTile extends StatelessWidget {
  final RegistroAsistencia r;
  const _RegistroTile(this.r);

  @override
  Widget build(BuildContext context) {
    final s = _estilo(r.estado);
    final detalle = [
      if (r.bloque != null) 'Clase ${r.bloque!.rangoTexto}',
      if (r.entrada != null) 'Entrada ${hora(r.entrada!)}',
    ].join(' · ');

    return Card(
      child: ListTile(
        leading: Icon(s.icono, color: s.color),
        title: Text(diaLargo(r.dia)),
        subtitle: Text(detalle),
        trailing: Text(s.texto,
            style: TextStyle(color: s.color, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
