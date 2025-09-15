import '../entities/user_entity.dart';
import '../entities/auth_result_entity.dart';

abstract class AuthRepository {
  Future<UserEntity?> initialize();
  Future<AuthResultEntity> signInWithGoogle();
  Future<UserEntity?> getCurrentUser();
  Future<void> signOut();
  bool get isAuthenticated;
}