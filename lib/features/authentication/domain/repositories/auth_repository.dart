import 'package:dartz/dartz.dart';
import '../entities/user_entity.dart';
import '../entities/auth_result_entity.dart';
import '../failures/auth_failures.dart';

abstract class AuthRepository {
  Future<Either<AuthFailure, UserEntity?>> initialize();
  Future<Either<AuthFailure, AuthResultEntity>> signInWithGoogle();
  Future<Either<AuthFailure, UserEntity?>> getCurrentUser();
  Future<Either<AuthFailure, void>> signOut();
  bool get isAuthenticated;
}