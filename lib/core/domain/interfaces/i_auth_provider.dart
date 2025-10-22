import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

/// Abstraction for authentication provider (e.g., Supabase, Firebase, etc.)
/// This allows us to swap authentication backends and makes testing easier
abstract class IAuthProvider {
  /// Sign in with Google OAuth
  /// Returns true if OAuth flow was launched successfully
  Future<bool> signInWithOAuth({
    required OAuthProvider provider,
    required String redirectUrl,
    LaunchMode? authScreenLaunchMode,
    Map<String, String>? queryParams,
  });

  /// Sign out the current user
  Future<void> signOut({SignOutScope scope});

  /// Get the current session
  Session? get currentSession;

  /// Get the current user
  User? get currentUser;

  /// Stream of authentication state changes
  Stream<AuthStateChangeEvent> get onAuthStateChange;

  /// Check if a user is currently authenticated
  bool get isAuthenticated;
}

/// Event emitted when auth state changes
class AuthStateChangeEvent {
  final AuthChangeEvent event;
  final Session? session;

  AuthStateChangeEvent({
    required this.event,
    this.session,
  });
}
