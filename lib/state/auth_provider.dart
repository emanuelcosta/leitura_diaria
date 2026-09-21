import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';

/// Exposes Supabase's email/password auth to the UI. Sign-in triggering a
/// remote pull/merge of reading progress is handled by ReadingPlanProvider
/// itself (it listens to the same Supabase auth stream), so this provider
/// only owns session state and the sign-in/up/out actions.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  StreamSubscription<AuthState>? _sub;

  AuthProvider({AuthService? authService}) : _authService = authService ?? AuthService() {
    _sub = _authService.onAuthStateChange.listen((_) => notifyListeners());
  }

  User? get user => _authService.currentUser;
  bool get isSignedIn => user != null;

  bool _busy = false;
  bool get busy => _busy;

  String? errorMessage;

  Future<bool> signIn({required String email, required String password}) {
    return _run(() => _authService.signIn(email: email, password: password));
  }

  Future<bool> signUp({required String email, required String password}) {
    return _run(() => _authService.signUp(email: email, password: password));
  }

  Future<void> signOut() async {
    await _authService.signOut();
    notifyListeners();
  }

  Future<bool> _run(Future<void> Function() action) async {
    _busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on AuthException catch (e) {
      errorMessage = e.message;
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
