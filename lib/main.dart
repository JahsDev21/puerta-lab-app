import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/puertalab_service.dart';
import 'widgets/estado_vacio.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  if (Config.completa) {
    await Supabase.initialize(
      url: Config.supabaseUrl,
      publishableKey: Config.supabaseAnonKey,
    );
  }
  runApp(const PuertaLabApp());
}

class PuertaLabApp extends StatelessWidget {
  const PuertaLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PuertaLab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Config.completa ? const InicioScreen() : const _SinConfiguracion(),
    );
  }
}

/// Revisa si hay una sesión guardada y manda a Home o a Login.
class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  Object? _error;

  @override
  void initState() {
    super.initState();
    _revisarSesion();
  }

  Future<void> _revisarSesion() async {
    setState(() => _error = null);
    try {
      final usuario = await PuertaLabService.instancia.restaurarSesion();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              usuario == null ? const LoginScreen() : HomeScreen(usuario: usuario),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _error == null
          ? const Center(child: CircularProgressIndicator())
          : EstadoVacio.error(texto: mensajeError(_error!), onAccion: _revisarSesion),
    );
  }
}

class _SinConfiguracion extends StatelessWidget {
  const _SinConfiguracion();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: EstadoVacio(
        icono: Icons.settings,
        texto: 'Falta configurar Supabase.\n\n'
            'Copia supabase.example.json como supabase.json, llena la URL y la '
            'anon key, y ejecuta:\nflutter run --dart-define-from-file=supabase.json',
      ),
    );
  }
}
