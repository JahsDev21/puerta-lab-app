import 'package:flutter/material.dart';

import '../models/usuario.dart';
import '../services/puertalab_service.dart';
import '../views/asistencia_view.dart';
import '../views/bitacora_view.dart';
import 'grupos_screen.dart';
import 'login_screen.dart';
import 'personas_screen.dart';
import 'puerta_screen.dart';

class HomeScreen extends StatefulWidget {
  final Usuario usuario;
  const HomeScreen({super.key, required this.usuario});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _indice = 0;
  late final List<_Seccion> _secciones = _crearSecciones();

  List<_Seccion> _crearSecciones() {
    final u = widget.usuario;
    final ajustes = _Seccion('Ajustes', Icons.settings,
        _Ajustes(usuario: u, onCerrarSesion: _cerrarSesion));

    // Alcance 'equipo' (docentes / administración): ve todo el laboratorio.
    if (u.esEquipo) {
      return [
        const _Seccion('Puerta', Icons.meeting_room, PuertaScreen()),
        const _Seccion('Bitácora', Icons.list_alt, BitacoraView()),
        const _Seccion('Personas', Icons.people, PersonasScreen()),
        _Seccion('Grupos', Icons.groups, GruposScreen(usuario: u)),
        ajustes,
      ];
    }

    // Alcance 'personal': solo su asistencia y sus accesos (RLS lo garantiza).
    return [
      _Seccion('Mi asistencia', Icons.fact_check,
          AsistenciaView(personaId: u.personaId!)),
      const _Seccion('Mis accesos', Icons.history, BitacoraView()),
      ajustes,
    ];
  }

  Future<void> _cerrarSesion() async {
    await PuertaLabService.instancia.cerrarSesion();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_secciones[_indice].titulo)),
      // IndexedStack conserva el estado de cada pestaña al cambiar.
      body: IndexedStack(
        index: _indice,
        children: [for (final s in _secciones) s.pagina],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: [
          for (final s in _secciones)
            NavigationDestination(icon: Icon(s.icono), label: s.titulo),
        ],
      ),
    );
  }
}

class _Seccion {
  final String titulo;
  final IconData icono;
  final Widget pagina;
  const _Seccion(this.titulo, this.icono, this.pagina);
}

class _Ajustes extends StatelessWidget {
  final Usuario usuario;
  final VoidCallback onCerrarSesion;
  const _Ajustes({required this.usuario, required this.onCerrarSesion});

  @override
  Widget build(BuildContext context) {
    final detalles = [
      usuario.rolTexto,
      if (usuario.grupo != null) 'Grupo ${usuario.grupo}',
    ].join(' · ');

    return ListView(
      children: [
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(usuario.nombre),
          subtitle: Text('$detalles\n${usuario.correo}'),
          isThreeLine: true,
        ),
        const Divider(),
        if (usuario.esEquipo)
          const ListTile(
            leading: Icon(Icons.bluetooth),
            title: Text('Configurar Wi-Fi del dispositivo'),
            subtitle: Text('Disponible cuando el firmware del ESP32 lo soporte'),
            enabled: false,
          ),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
          onTap: onCerrarSesion,
        ),
      ],
    );
  }
}
