// features/authentication/data/repositories/user_repository_impl.dart
import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/user_data_source.dart';

class UserRepositoryImpl implements UserRepository {
  final UserDataSource _dataSource;
  final ILogger _logger;

  UserRepositoryImpl(this._dataSource, this._logger);

  @override
  Future<Either<Failure, List<UserEntity>>> getTenantUsers(String tenantId) async {
    try {
      final users = await _dataSource.getTenantUsers(tenantId);
      return Right(users);
    } catch (e, stackTrace) {
      _logger.error('Failed to get tenant users',
          category: LogCategory.auth,
          error: e,
          stackTrace: stackTrace);
      return Left(ServerFailure('Failed to load users: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> getUserById(String userId) async {
    try {
      final user = await _dataSource.getUserById(userId);
      return Right(user);
    } catch (e, stackTrace) {
      _logger.error('Failed to get user by ID',
          category: LogCategory.auth,
          error: e,
          stackTrace: stackTrace);
      return Left(ServerFailure('Failed to load user: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> updateUserRole(String userId, UserRole role) async {
    try {
      await _dataSource.updateUserRole(userId, role);
      return const Right(null);
    } catch (e, stackTrace) {
      _logger.error('Failed to update user role',
          category: LogCategory.auth,
          error: e,
          stackTrace: stackTrace);
      return Left(ServerFailure('Failed to update user role: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> updateUserStatus(String userId, bool isActive) async {
    try {
      await _dataSource.updateUserStatus(userId, isActive);
      return const Right(null);
    } catch (e, stackTrace) {
      _logger.error('Failed to update user status',
          category: LogCategory.auth,
          error: e,
          stackTrace: stackTrace);
      return Left(ServerFailure('Failed to update user status: ${e.toString()}'));
    }
  }
}