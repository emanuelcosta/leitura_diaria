import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:leitura_diaria/services/auth_service.dart';

void main() {
  final session = Session(
    accessToken: 'token',
    tokenType: 'bearer',
    user: const User(
      id: 'user-1',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
    ),
  );

  test('startsSession on a fresh sign-in', () {
    expect(AuthService.startsSession(AuthState(AuthChangeEvent.signedIn, session)), isTrue);
  });

  test('startsSession on app start with a saved session (initialSession + session)', () {
    expect(AuthService.startsSession(AuthState(AuthChangeEvent.initialSession, session)), isTrue);
  });

  test('not on app start while logged out (initialSession without session)', () {
    expect(AuthService.startsSession(AuthState(AuthChangeEvent.initialSession, null)), isFalse);
  });

  test('not on token refresh or sign-out', () {
    expect(AuthService.startsSession(AuthState(AuthChangeEvent.tokenRefreshed, session)), isFalse);
    expect(AuthService.startsSession(AuthState(AuthChangeEvent.signedOut, null)), isFalse);
  });
}
