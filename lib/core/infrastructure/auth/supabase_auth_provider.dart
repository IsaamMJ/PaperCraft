import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../domain/interfaces/i_auth_provider.dart';

/// Supabase implementation of IAuthProvider
/// Wraps Supabase authentication to allow for testing and swapping providers
class SupabaseAuthProvider implements IAuthProvider {
  final SupabaseClient _client;

  SupabaseAuthProvider(this._client);

  @override
  Future<bool> signInWithOAuth({
    required OAuthProvider provider,
    required String redirectUrl,
    LaunchMode? authScreenLaunchMode,
    Map<String, String>? queryParams,
  }) async {
    return await _client.auth.signInWithOAuth(
      provider,
      redirectTo: redirectUrl,
      authScreenLaunchMode: authScreenLaunchMode ?? LaunchMode.platformDefault,
      queryParams: queryParams,
    );
  }

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.global}) async {
    await _client.auth.signOut(scope: scope);
  }

  @override
  Session? get currentSession => _client.auth.currentSession;

  @override
  User? get currentUser => _client.auth.currentUser;

  @override
  Stream<AuthStateChangeEvent> get onAuthStateChange {
    return _client.auth.onAuthStateChange.map((data) {
      return AuthStateChangeEvent(
        event: data.event,
        session: data.session,
      );
    });
  }

  @override
  bool get isAuthenticated => _client.auth.currentUser != null;
}
