import '../entities/auth_result_entity.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class AuthUseCase {
  final AuthRepository _repository;

  AuthUseCase(this._repository);

  Future<UserEntity?> initialize() => _repository.initialize();

  Future<AuthResultEntity> signInWithGoogle() => _repository.signInWithGoogle();

  Future<UserEntity?> getCurrentUser() => _repository.getCurrentUser();

  Future<void> signOut() => _repository.signOut();

  bool get isAuthenticated => _repository.isAuthenticated;
}