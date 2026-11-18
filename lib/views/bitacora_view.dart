import 'package:flutter/material.dart';

import '../models/evento.dart';
import '../services/puertalab_service.dart';
import '../utils/formato.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/evento_tile.dart';

/// Bitácora de accesos con filtros y carga por páginas.
/// Si [personaId] es null muestra todo lo que RLS permita ver a la cuenta.
class BitacoraView extends StatefulWidget {
  final int? personaId;
  const BitacoraView({super.key, this.personaId});

  @override
  State<BitacoraView> createState() => _BitacoraViewState();
}

class _BitacoraViewState extends State<BitacoraView> {
  static const _porPagina = 30;

  final _api = PuertaLabService.instancia;
  final _scroll = ScrollController();

  final List<Evento> _eventos = [];
  bool _cargando = false;
  bool _hayMas = true;
  Object? _error;

  String? _resultado;
  String? _metodo;
  DateTimeRange? _rango;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        _cargarMas();
      }
    });
    _recargar();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _recargar() async {
    setState(() {
      _eventos.clear();
      _hayMas = true;
      _error = null;
    });
    await _cargarMas();
  }

  Future<void> _cargarMas() async {
    if (_cargando || !_hayMas) return;
    setState(() => _cargando = true);
    try {
      final nuevos = await _api.eventos(
        desde: _eventos.length,
        cantidad: _porPagina,
        personaId: widget.personaId,
        resultado: _resultado,
        metodo: _metodo,
        inicio: _rango?.start,
        fin: _rango?.end,
      );
      if (!mounted) return;
      setState(() {
        _eventos.addAll(nuevos);
        _hayMas = nuevos.length == _porPagina;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _elegirRango() async {
    final ahora = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(ahora.year - 2),
      lastDate: ahora,
      initialDateRange: _rango,
      locale: const Locale('es'),
    );
    if (r == null) return;
    _rango = r;
    _recargar();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _filtros(),
        Expanded(child: _lista()),
      ],
    );
  }

  Widget _filtros() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          FilterChip(
            avatar: const Icon(Icons.date_range, size: 18),
            label: Text(_rango == null
                ? 'Fechas'
                : '${diaCorto(_rango!.start)} – ${diaCorto(_rango!.end)}'),
            selected: _rango != null,
            showCheckmark: false,
            onSelected: (_) => _elegirRango(),
            onDeleted: _rango == null
                ? null
                : () {
                    _rango = null;
                    _recargar();
                  },
          ),
          const SizedBox(width: 8),
          for (final r in Evento.resultados) ...[
            FilterChip(
              label: Text(r),
              selected: _resultado == r,
              onSelected: (sel) {
                _resultado = sel ? r : null;
                _recargar();
              },
            ),
            const SizedBox(width: 8),
          ],
          PopupMenuButton<String?>(
            onSelected: (m) {
              _metodo = m;
              _recargar();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('Todos los métodos')),
              for (final m in Evento.metodos) PopupMenuItem(value: m, child: Text(m)),
            ],
            child: Chip(
              avatar: Icon(
                  _metodo == null ? Icons.tune : EventoTile.iconoMetodo(_metodo!),
                  size: 18),
              label: Text(_metodo ?? 'Método'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lista() {
    if (_error != null && _eventos.isEmpty) {
      return EstadoVacio.error(texto: mensajeError(_error!), onAccion: _recargar);
    }
    if (_eventos.isEmpty) {
      if (_cargando) return const Center(child: CircularProgressIndicator());
      return RefreshIndicator(
        onRefresh: _recargar,
        child: ListView(children: const [
          SizedBox(height: 120),
          EstadoVacio(icono: Icons.list_alt, texto: 'No hay accesos registrados'),
        ]),
      );
    }

    // Lista plana con encabezados por día.
    final items = <Object>[];
    DateTime? diaActual;
    for (final e in _eventos) {
      final d = soloDia(e.fecha);
      if (d != diaActual) {
        items.add(d);
        diaActual = d;
      }
      items.add(e);
    }

    return RefreshIndicator(
      onRefresh: _recargar,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        itemCount: items.length + 1,
        itemBuilder: (context, i) {
          if (i == items.length) {
            if (_cargando) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (_error != null) {
              return TextButton(onPressed: _cargarMas, child: const Text('Reintentar'));
            }
            return const SizedBox(height: 8);
          }
          final item = items[i];
          if (item is DateTime) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
              child: Text(diaLargo(item),
                  style: Theme.of(context).textTheme.titleSmall),
            );
          }
          return EventoTile(evento: item as Evento);
        },
      ),
    );
  }
}
