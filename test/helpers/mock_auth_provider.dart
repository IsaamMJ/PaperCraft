import 'dart:async';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:papercraft/core/domain/interfaces/i_auth_provider.dart';

/// Mock implementation of IAuthProvider for testing
/// This makes testing auth flows much easier!
class MockAuthProvider extends Mock implements IAuthProvider {}

/// Fake implementation for testing - useful for integration tests
class FakeAuthProvider implements IAuthProvider {
  Session? _currentSession;
  final StreamController<AuthStateChangeEvent> _stateController =
      StreamController<AuthStateChangeEvent>.broadcast();

  bool _isAuthenticated = false;

  FakeAuthProvider({Session? initialSession}) : _currentSession = initialSession {
    _isAuthenticated = initialSession != null;
  }

  @override
  Future<bool> signInWithOAuth({
    required OAuthProvider provider,
    required String redirectUrl,
    LaunchMode? authScreenLaunchMode,
    Map<String, String>? queryParams,
  }) async {
    // Simulate successful OAuth launch
    return true;
  }

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.global}) async {
    _currentSession = null;
    _isAuthenticated = false;
    _stateController.add(AuthStateChangeEvent(
      event: AuthChangeEvent.signedOut,
      session: null,
    ));
  }

  @override
  Session? get currentSession => _currentSession;

  @override
  User? get currentUser => _currentSession?.user;

  @override
  Stream<AuthStateChangeEvent> get onAuthStateChange => _stateController.stream;

  @override
  bool get isAuthenticated => _isAuthenticated;

  // Test helpers
  void simulateSignIn(Session session) {
    _currentSession = session;
    _isAuthenticated = true;
    _stateController.add(AuthStateChangeEvent(
      event: AuthChangeEvent.signedIn,
      session: session,
    ));
  }

  void simulateSignOut() {
    _currentSession = null;
    _isAuthenticated = false;
    _stateController.add(AuthStateChangeEvent(
      event: AuthChangeEvent.signedOut,
      session: null,
    ));
  }

  void dispose() {
    _stateController.close();
  }
}
