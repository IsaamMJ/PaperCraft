// domain/usecases/sign_in_with_google.dart
import '../repositories/auth_repository.dart';
import '../entities/user_entity.dart';
import '../entities/auth_session_entity.dart';

class SignInWithGoogle {
  final AuthRepository repository;

  SignInWithGoogle(this.repository);

  Future<(UserEntity, AuthSessionEntity)> call() {
    return repository.signInWithGoogle();
  }
}
