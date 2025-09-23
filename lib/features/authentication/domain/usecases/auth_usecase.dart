import 'package:dartz/dartz.dart';
import '../entities/auth_result_entity.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';
import '../failures/auth_failures.dart';

class AuthUseCase {
  final AuthRepository _repository;

  AuthUseCase(this._repository);

  Future<Either<AuthFailure, UserEntity?>> initialize() => _repository.initialize();

  Future<Either<AuthFailure, AuthResultEntity>> signInWithGoogle() => _repository.signInWithGoogle();

  Future<Either<AuthFailure, UserEntity?>> getCurrentUser() => _repository.getCurrentUser();

  Future<Either<AuthFailure, void>> signOut() => _repository.signOut();


  bool get isAuthenticated => _repository.isAuthenticated;
}