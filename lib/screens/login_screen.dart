import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/puertalab_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _correoCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _cargando = false;
  bool _verPass = false;
  String? _error;

  Future<void> _iniciarSesion() async {
    final correo = _correoCtrl.text.trim();
    if (correo.isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Escribe tu correo y contraseña');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final usuario =
          await PuertaLabService.instancia.iniciarSesion(correo, _passCtrl.text);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(usuario: usuario)),
      );
    } on AuthException catch (e) {
      final s = e.message.toLowerCase();
      setState(() => _error = s.contains('invalid')
          ? 'Correo o contraseña incorrectos'
          : s.contains('not confirmed')
              ? 'Tu correo aún no está confirmado'
              : e.message);
    } on CuentaNoValida catch (e) {
      setState(() => _error = e.mensaje);
    } catch (_) {
      setState(() => _error = 'No se pudo conectar con el servidor');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    _correoCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fingerprint, size: 80, color: colores.primary),
                  const SizedBox(height: 16),
                  Text('PuertaLab',
                      style: Theme.of(context).textTheme.headlineMedium),
                  Text('Control de acceso del laboratorio',
                      style: TextStyle(color: colores.outline)),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _correoCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passCtrl,
                    obscureText: !_verPass,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _iniciarSesion(),
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_verPass ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _verPass = !_verPass),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colores.error)),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _cargando ? null : _iniciarSesion,
                      child: _cargando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Iniciar sesión'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
