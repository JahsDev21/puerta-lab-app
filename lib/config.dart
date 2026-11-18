/// Credenciales del proyecto Supabase.
///
/// No se escriben en el código: se pasan al compilar con
///   flutter run --dart-define-from-file=supabase.json
/// (ver supabase.example.json). Solo va la anon key, nunca la service_role.
class Config {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get completa =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
