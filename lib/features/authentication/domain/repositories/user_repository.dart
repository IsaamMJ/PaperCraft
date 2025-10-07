// features/authentication/domain/repositories/user_repository.dart
import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/user_entity.dart';
import '../entities/user_role.dart';

abstract class UserRepository {
  Future<Either<Failure, List<UserEntity>>> getTenantUsers(String tenantId);
  Future<Either<Failure, UserEntity?>> getUserById(String userId);
  Future<Either<Failure, void>> updateUserRole(String userId, UserRole role);
  Future<Either<Failure, void>> updateUserStatus(String userId, bool isActive);
}