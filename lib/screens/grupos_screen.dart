import 'package:flutter/material.dart';

import '../models/asistencia.dart';
import '../models/evento.dart';
import '../models/grupo.dart';
import '../models/horario.dart';
import '../models/persona.dart';
import '../models/usuario.dart';
import '../services/puertalab_service.dart';
import '../utils/formato.dart';
import '../widgets/estado_vacio.dart';
import 'personas_screen.dart';

final _api = PuertaLabService.instancia;

void _avisar(BuildContext context, String texto) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));

/// Pide un nombre de grupo. Devuelve null si se cancela.
Future<String?> _pedirNombre(BuildContext context,
    {String titulo = 'Nuevo grupo', String inicial = ''}) {
  final ctrl = TextEditingController(text: inicial);
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      void aceptar() {
        final v = ctrl.text.trim();
        if (v.isNotEmpty) Navigator.pop(ctx, v);
      }

      return AlertDialog(
        title: Text(titulo),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 60,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            hintText: 'Ej. Redes 7A',
          ),
          onSubmitted: (_) => aceptar(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: aceptar, child: const Text('Guardar')),
        ],
      );
    },
  );
}

// =================================================================== lista

/// Grupos del maestro con sesión iniciada.
class GruposScreen extends StatefulWidget {
  final Usuario usuario;
  const GruposScreen({super.key, required this.usuario});

  @override
  State<GruposScreen> createState() => _GruposScreenState();
}

class _GruposScreenState extends State<GruposScreen> {
  List<Grupo>? _grupos;
  Object? _error;

  @override
  void initState() {
    super.initState();
    if (widget.usuario.personaId != null) _cargar();
  }

  Future<void> _cargar() async {
    try {
      final g = await _api.grupos();
      if (!mounted) return;
      setState(() {
        _grupos = g;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _crear() async {
    final nombre = await _pedirNombre(context);
    if (nombre == null || !mounted) return;
    try {
      await _api.crearGrupo(nombre);
      await _cargar();
    } catch (e) {
      if (mounted) _avisar(context, mensajeError(e));
    }
  }

  Future<void> _abrir(Grupo g) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GrupoDetalleScreen(grupo: g, usuario: widget.usuario),
      ),
    );
    _cargar(); // por si cambió el nombre, los alumnos o se eliminó
  }

  @override
  Widget build(BuildContext context) {
    if (widget.usuario.personaId == null) {
      return const EstadoVacio(
        icono: Icons.group_off,
        texto: 'Tu cuenta no está vinculada a una persona del laboratorio, '
            'así que no puede crear grupos.\nPide al administrador que la vincule.',
      );
    }

    final grupos = _grupos;
    final Widget cuerpo;
    if (_error != null && grupos == null) {
      cuerpo = EstadoVacio.error(texto: mensajeError(_error!), onAccion: _cargar);
    } else if (grupos == null) {
      cuerpo = const Center(child: CircularProgressIndicator());
    } else {
      cuerpo = RefreshIndicator(
        onRefresh: _cargar,
        child: grupos.isEmpty
            ? ListView(children: const [
                SizedBox(height: 120),
                EstadoVacio(
                  icono: Icons.groups,
                  texto: 'Todavía no tienes grupos.\nCrea uno con el botón +',
                ),
              ])
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                itemCount: grupos.length,
                itemBuilder: (_, i) {
                  final g = grupos[i];
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.groups)),
                      title: Text(g.nombre),
                      subtitle: Text(g.totalAlumnos == 1
                          ? '1 alumno'
                          : '${g.totalAlumnos} alumnos'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _abrir(g),
                    ),
                  );
                },
              ),
      );
    }

    return Scaffold(
      body: cuerpo,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crear,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo grupo'),
      ),
    );
  }
}

// ================================================================= detalle

class GrupoDetalleScreen extends StatefulWidget {
  final Grupo grupo;
  final Usuario usuario;
  const GrupoDetalleScreen({super.key, required this.grupo, required this.usuario});

  @override
  State<GrupoDetalleScreen> createState() => _GrupoDetalleScreenState();
}

class _GrupoDetalleScreenState extends State<GrupoDetalleScreen> {
  late String _nombre = widget.grupo.nombre;
  List<Persona>? _miembros;
  Object? _error;

  int get _grupoId => widget.grupo.id;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final m = await _api.miembros(_grupoId);
      if (!mounted) return;
      setState(() {
        _miembros = m;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _renombrar() async {
    final nombre = await _pedirNombre(context, titulo: 'Renombrar grupo', inicial: _nombre);
    if (nombre == null || nombre == _nombre || !mounted) return;
    try {
      await _api.renombrarGrupo(_grupoId, nombre);
      if (mounted) setState(() => _nombre = nombre);
    } catch (e) {
      if (mounted) _avisar(context, mensajeError(e));
    }
  }

  Future<void> _eliminar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar grupo'),
        content: Text('Se eliminará "$_nombre". Los alumnos y sus registros '
            'de acceso no se borran.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _api.eliminarGrupo(_grupoId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _avisar(context, mensajeError(e));
    }
  }

  Future<void> _agregar() async {
    final agregados = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AgregarAlumnosScreen(
          grupoId: _grupoId,
          excluir: {
            ...?_miembros?.map((p) => p.id),
            if (widget.usuario.personaId != null) widget.usuario.personaId!,
          },
        ),
      ),
    );
    if (agregados == true) _cargar();
  }

  Future<void> _quitar(Persona p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar del grupo'),
        content: Text('¿Quitar a ${p.nombre} de "$_nombre"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Quitar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _api.quitarMiembro(_grupoId, p.id);
      if (mounted) setState(() => _miembros!.removeWhere((m) => m.id == p.id));
    } catch (e) {
      if (mounted) _avisar(context, mensajeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final miembros = _miembros;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_nombre),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) => v == 'renombrar' ? _renombrar() : _eliminar(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'renombrar', child: Text('Renombrar')),
                PopupMenuItem(value: 'eliminar', child: Text('Eliminar grupo')),
              ],
            ),
          ],
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.people), text: 'Alumnos'),
            Tab(icon: Icon(Icons.fact_check), text: 'Asistencia'),
          ]),
        ),
        floatingActionButton: miembros == null
            ? null
            : FloatingActionButton.extended(
                onPressed: _agregar,
                icon: const Icon(Icons.person_add),
                label: const Text('Agregar alumnos'),
              ),
        body: _error != null && miembros == null
            ? EstadoVacio.error(texto: mensajeError(_error!), onAccion: _cargar)
            : miembros == null
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(children: [
                    _ListaMiembros(miembros: miembros, onQuitar: _quitar, onRecargar: _cargar),
                    _AsistenciaGrupo(
                      // Al cambiar los alumnos se vuelve a calcular.
                      key: ValueKey(miembros.map((p) => p.id).join(',')),
                      miembros: miembros,
                    ),
                  ]),
      ),
    );
  }
}

class _ListaMiembros extends StatelessWidget {
  final List<Persona> miembros;
  final ValueChanged<Persona> onQuitar;
  final Future<void> Function() onRecargar;
  const _ListaMiembros(
      {required this.miembros, required this.onQuitar, required this.onRecargar});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRecargar,
      child: miembros.isEmpty
          ? ListView(children: const [
              SizedBox(height: 120),
              EstadoVacio(
                icono: Icons.person_add,
                texto: 'El grupo no tiene alumnos.\nAgrégalos con el botón de abajo.',
              ),
            ])
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: miembros.length,
              itemBuilder: (_, i) {
                final p = miembros[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text(p.nombre.characters.first.toUpperCase())),
                    title: Text(p.nombre),
                    subtitle: Text([p.rol, if (!p.activo) 'Inactivo'].join(' · ')),
                    trailing: IconButton(
                      tooltip: 'Quitar del grupo',
                      icon: const Icon(Icons.person_remove),
                      onPressed: () => onQuitar(p),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PersonaDetalleScreen(persona: p)),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ============================================================ asistencia

/// Resumen de asistencia de cada alumno del grupo en el periodo elegido.
class _AsistenciaGrupo extends StatefulWidget {
  final List<Persona> miembros;
  const _AsistenciaGrupo({super.key, required this.miembros});

  @override
  State<_AsistenciaGrupo> createState() => _AsistenciaGrupoState();
}

class _AsistenciaGrupoState extends State<_AsistenciaGrupo> {
  int _dias = 30;
  Map<int, List<RegistroAsistencia>>? _porPersona;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  /// Supabase devuelve como máximo 1000 filas por consulta: se pide por páginas.
  Future<List<Evento>> _todosLosEventos(List<int> ids, DateTime inicio) async {
    const pagina = 1000;
    final todos = <Evento>[];
    while (true) {
      final lote = await _api.eventos(
        personaIds: ids,
        resultado: 'Permitido',
        inicio: inicio,
        desde: todos.length,
        cantidad: pagina,
      );
      todos.addAll(lote);
      if (lote.length < pagina) return todos;
    }
  }

  Future<void> _cargar() async {
    final ids = [for (final p in widget.miembros) p.id];
    if (ids.isEmpty) {
      setState(() => _porPersona = {});
      return;
    }
    setState(() => _error = null);
    try {
      final ahora = DateTime.now();
      final inicio = soloDia(ahora).subtract(Duration(days: _dias - 1));
      final resultados = await Future.wait([
        _api.horarios(personaIds: ids),
        _todosLosEventos(ids, inicio),
      ]);
      final horarios = resultados[0] as List<Horario>;
      final eventos = resultados[1] as List<Evento>;
      final porPersona = {
        for (final id in ids)
          id: calcularAsistencia(
            eventos: eventos.where((e) => e.personaId == id).toList(),
            horarios: horarios.where((h) => h.personaId == id).toList(),
            inicio: inicio,
            ahora: ahora,
          ),
      };
      if (mounted) setState(() => _porPersona = porPersona);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return EstadoVacio.error(texto: mensajeError(_error!), onAccion: _cargar);
    }
    final porPersona = _porPersona;
    if (porPersona == null) return const Center(child: CircularProgressIndicator());
    if (widget.miembros.isEmpty) {
      return const EstadoVacio(icono: Icons.fact_check, texto: 'El grupo no tiene alumnos.');
    }

    int total(EstadoAsistencia e) => porPersona.values
        .fold(0, (s, regs) => s + regs.where((r) => r.estado == e).length);

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
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
                _porPersona = null;
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
                  _Numero('A tiempo', total(EstadoAsistencia.aTiempo), Colors.green),
                  _Numero('Retardos', total(EstadoAsistencia.retardo), Colors.orange),
                  _Numero('Faltas', total(EstadoAsistencia.falta), Colors.red),
                ],
              ),
            ),
          ),
          for (final p in widget.miembros) _AlumnoResumen(p, porPersona[p.id] ?? const []),
        ],
      ),
    );
  }
}

class _Numero extends StatelessWidget {
  final String texto;
  final int valor;
  final Color color;
  const _Numero(this.texto, this.valor, this.color);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(children: [
      Text('$valor',
          style: t.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.bold)),
      Text(texto, style: t.bodySmall),
    ]);
  }
}

class _AlumnoResumen extends StatelessWidget {
  final Persona p;
  final List<RegistroAsistencia> registros;
  const _AlumnoResumen(this.p, this.registros);

  @override
  Widget build(BuildContext context) {
    int contar(EstadoAsistencia e) => registros.where((r) => r.estado == e).length;
    final aTiempo = contar(EstadoAsistencia.aTiempo);
    final retardos = contar(EstadoAsistencia.retardo);
    final faltas = contar(EstadoAsistencia.falta);
    final clases = aTiempo + retardos + faltas;
    final porcentaje = clases == 0 ? null : ((aTiempo + retardos) * 100 / clases).round();

    final color = porcentaje == null
        ? Theme.of(context).colorScheme.outline
        : porcentaje >= 80
            ? Colors.green
            : porcentaje >= 60
                ? Colors.orange
                : Colors.red;

    return Card(
      child: ListTile(
        title: Text(p.nombre),
        subtitle: Text(clases == 0
            ? 'Sin clases en el periodo (¿tiene horario?)'
            : '$aTiempo a tiempo · $retardos retardos · $faltas faltas'),
        trailing: Text(
          porcentaje == null ? '—' : '$porcentaje %',
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PersonaDetalleScreen(persona: p)),
        ),
      ),
    );
  }
}

// ======================================================= agregar alumnos

/// Selección múltiple de personas activas para inscribir en el grupo.
class AgregarAlumnosScreen extends StatefulWidget {
  final int grupoId;

  /// Ya inscritos y el propio maestro.
  final Set<int> excluir;

  const AgregarAlumnosScreen({super.key, required this.grupoId, required this.excluir});

  @override
  State<AgregarAlumnosScreen> createState() => _AgregarAlumnosScreenState();
}

class _AgregarAlumnosScreenState extends State<AgregarAlumnosScreen> {
  List<Persona>? _candidatos;
  Object? _error;
  String _busqueda = '';
  bool _soloAlumnos = true;
  bool _guardando = false;
  final _elegidos = <int>{};

  static bool _esAlumno(Persona p) {
    final r = p.rol.toLowerCase();
    return r.contains('alumn') || r.contains('estudiante');
  }

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final todas = await _api.personas();
      if (!mounted) return;
      final candidatos =
          todas.where((p) => p.activo && !widget.excluir.contains(p.id)).toList();
      setState(() {
        _candidatos = candidatos;
        // Si los roles no se llaman "Alumno", no ocultar a nadie.
        if (!candidatos.any(_esAlumno)) _soloAlumnos = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await _api.agregarMiembros(widget.grupoId, _elegidos.toList());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _avisar(context, mensajeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidatos = _candidatos;
    final q = _busqueda.toLowerCase();
    final lista = candidatos
        ?.where((p) =>
            (!_soloAlumnos || _esAlumno(p)) &&
            (q.isEmpty ||
                p.nombre.toLowerCase().contains(q) ||
                (p.grupo?.toLowerCase().contains(q) ?? false)))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Agregar alumnos')),
      body: _error != null && candidatos == null
          ? EstadoVacio.error(texto: mensajeError(_error!), onAccion: _cargar)
          : lista == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: SearchBar(
                        hintText: 'Buscar por nombre o grupo',
                        leading: const Icon(Icons.search),
                        onChanged: (v) => setState(() => _busqueda = v),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          FilterChip(
                            label: const Text('Solo alumnos'),
                            selected: _soloAlumnos,
                            onSelected: (v) => setState(() => _soloAlumnos = v),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: lista.isEmpty
                                ? null
                                : () => setState(() {
                                      final ids = lista.map((p) => p.id);
                                      if (ids.every(_elegidos.contains)) {
                                        _elegidos.removeAll(ids);
                                      } else {
                                        _elegidos.addAll(ids);
                                      }
                                    }),
                            child: const Text('Todos / ninguno'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: lista.isEmpty
                          ? const EstadoVacio(
                              icono: Icons.person_search,
                              texto: 'No hay personas disponibles para agregar.',
                            )
                          : ListView.builder(
                              itemCount: lista.length,
                              itemBuilder: (_, i) {
                                final p = lista[i];
                                return CheckboxListTile(
                                  value: _elegidos.contains(p.id),
                                  onChanged: (v) => setState(() =>
                                      v == true ? _elegidos.add(p.id) : _elegidos.remove(p.id)),
                                  title: Text(p.nombre),
                                  subtitle: Text(
                                      [p.rol, if (p.grupo != null) p.grupo!].join(' · ')),
                                );
                              },
                            ),
                    ),
                  ],
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: _elegidos.isEmpty || _guardando ? null : _guardar,
            icon: _guardando
                ? const SizedBox.square(
                    dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: Text(_elegidos.isEmpty
                ? 'Elige alumnos'
                : 'Agregar ${_elegidos.length} al grupo'),
          ),
        ),
      ),
    );
  }
}
