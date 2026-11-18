import 'package:flutter/material.dart';

import '../models/persona.dart';
import '../services/puertalab_service.dart';
import '../views/asistencia_view.dart';
import '../views/bitacora_view.dart';
import '../widgets/estado_vacio.dart';

/// Lista de personas registradas (solo cuentas de alcance 'equipo').
class PersonasScreen extends StatefulWidget {
  const PersonasScreen({super.key});

  @override
  State<PersonasScreen> createState() => _PersonasScreenState();
}

class _PersonasScreenState extends State<PersonasScreen> {
  List<Persona>? _personas;
  Object? _error;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final p = await PuertaLabService.instancia.personas();
      if (!mounted) return;
      setState(() {
        _personas = p;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _personas == null) {
      return EstadoVacio.error(texto: mensajeError(_error!), onAccion: _cargar);
    }
    final todas = _personas;
    if (todas == null) return const Center(child: CircularProgressIndicator());

    final q = _busqueda.toLowerCase();
    final lista = todas
        .where((p) =>
            q.isEmpty ||
            p.nombre.toLowerCase().contains(q) ||
            p.rol.toLowerCase().contains(q) ||
            (p.grupo?.toLowerCase().contains(q) ?? false))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SearchBar(
            hintText: 'Buscar por nombre, rol o grupo',
            leading: const Icon(Icons.search),
            onChanged: (v) => setState(() => _busqueda = v),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _cargar,
            child: lista.isEmpty
                ? ListView(children: const [
                    SizedBox(height: 120),
                    EstadoVacio(icono: Icons.people, texto: 'Sin personas'),
                  ])
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: lista.length,
                    itemBuilder: (_, i) => _PersonaTile(lista[i]),
                  ),
          ),
        ),
      ],
    );
  }
}

class _PersonaTile extends StatelessWidget {
  final Persona p;
  const _PersonaTile(this.p);

  @override
  Widget build(BuildContext context) {
    final gris = Theme.of(context).colorScheme.outline;
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(p.nombre.characters.first.toUpperCase())),
        title: Text(p.nombre,
            style: p.activo ? null : TextStyle(color: gris, decoration: TextDecoration.lineThrough)),
        subtitle: Text([p.rol, if (p.grupo != null) p.grupo!, if (!p.activo) 'Inactivo'].join(' · ')),
        trailing: _Credenciales(p),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PersonaDetalleScreen(persona: p)),
        ),
      ),
    );
  }
}

/// Íconos de las credenciales registradas (no se muestran los identificadores).
class _Credenciales extends StatelessWidget {
  final Persona p;
  const _Credenciales(this.p);

  @override
  Widget build(BuildContext context) {
    final off = Theme.of(context).colorScheme.outlineVariant;
    Widget icono(IconData i, bool tiene, String txt) => Tooltip(
          message: '$txt ${tiene ? 'registrada' : 'sin registrar'}',
          child: Icon(i, size: 20, color: tiene ? null : off),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icono(Icons.fingerprint, p.tieneHuella, 'Huella'),
        icono(Icons.credit_card, p.tieneTarjeta, 'Tarjeta'),
        icono(Icons.face, p.tieneRostro, 'Rostro'),
      ],
    );
  }
}

class PersonaDetalleScreen extends StatelessWidget {
  final Persona persona;
  const PersonaDetalleScreen({super.key, required this.persona});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(persona.nombre),
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.fact_check), text: 'Asistencia'),
            Tab(icon: Icon(Icons.history), text: 'Accesos'),
          ]),
        ),
        body: TabBarView(children: [
          AsistenciaView(personaId: persona.id),
          BitacoraView(personaId: persona.id),
        ]),
      ),
    );
  }
}
