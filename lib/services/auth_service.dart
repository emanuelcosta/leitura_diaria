import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper around the Supabase Auth client (email/password only).
///
/// Safe to use even when Supabase was never initialized (e.g. a build
/// without a bundled .env): every member then behaves as "signed out" /
/// throws a friendly [AuthException] instead of Supabase's own
/// "not initialized" assertion error.
class AuthService {
  /// Must match the scheme+host registered in AndroidManifest.xml
  /// (intent-filter) and Info.plist (CFBundleURLTypes), and must also be
  /// added to Supabase Dashboard > Authentication > URL Configuration >
  /// Redirect URLs, or Supabase silently falls back to the default Site URL.
  static const emailRedirectTo = 'com.emanuel.leituradiaria://login-callback';

  bool get _ready {
    try {
      // Throws if Supabase.initialize() was never called.
      Supabase.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  SupabaseClient get _client => Supabase.instance.client;

  static Future<void> init({required String url, required String publishableKey}) {
    return Supabase.initialize(url: url, publishableKey: publishableKey);
  }

  User? get currentUser => _ready ? _client.auth.currentUser : null;

  Stream<AuthState> get onAuthStateChange =>
      _ready ? _client.auth.onAuthStateChange : const Stream.empty();

  Future<void> signUp({required String email, required String password}) async {
    _requireReady();
    await _client.auth.signUp(email: email, password: password, emailRedirectTo: emailRedirectTo);
  }

  Future<void> signIn({required String email, required String password}) async {
    _requireReady();
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    if (!_ready) return;
    await _client.auth.signOut();
  }

  void _requireReady() {
    if (!_ready) {
      throw AuthException('Sincronização com a nuvem não está configurada neste build.');
    }
  }
}
