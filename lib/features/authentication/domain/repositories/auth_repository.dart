import '../entities/auth_session_entity.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  /// Sign in with Google via Supabase
  /// Returns a tuple containing the user entity and auth session
  /// Throws [AuthException] if sign-in fails
  Future<(UserEntity, AuthSessionEntity)> signInWithGoogle();

  /// Get the currently logged-in user from the session
  /// Returns null if no user is currently signed in
  /// Throws [AuthException] for authentication errors
  Future<UserEntity?> getCurrentUser();

  /// Sign out the current user from Supabase
  /// Throws [AuthException] if sign-out fails
  Future<void> signOut();
}