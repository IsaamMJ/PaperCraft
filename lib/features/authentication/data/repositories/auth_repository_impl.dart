import 'package:dartz/dartz.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/auth_result_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/failures/auth_failures.dart';
import '../datasources/auth_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthDataSource _dataSource;
  final ILogger _logger;

  AuthRepositoryImpl(this._dataSource, this._logger) {
    _logger.info('AuthRepository initialized', category: LogCategory.auth, context: {
      'hasDataSource': true,
      'timestamp': DateTime.now().toIso8601String(),
      'repositoryLayer': true,
    });
  }

  @override
  Future<Either<AuthFailure, UserEntity?>> getUserById(String userId) async {
    try {
      _logger.debug('Repository: Getting user by ID', category: LogCategory.auth, context: {
        'targetUserId': userId,
      });

      final result = await _dataSource.getUserProfileById(userId);

      return result.fold(
            (failure) => Left(failure),
            (userModel) => Right(userModel?.toEntity()),
      );
    } catch (e, stackTrace) {
      _logger.error('Repository: Exception getting user by ID',
        category: LogCategory.auth,
        error: e,
        stackTrace: stackTrace,
        context: {'targetUserId': userId},
      );
      return Left(AuthFailure('Repository error getting user by ID: ${e.toString()}'));
    }
  }

  @override
  Future<Either<AuthFailure, UserEntity?>> initialize() async {
    _logger.info('App initialization started', category: LogCategory.auth, context: {
      'operation': 'app_startup',
      'repositoryLayer': true,
    });

    final result = await _dataSource.initialize();

    return result.fold(
          (failure) {
        _logger.authError('App initialization failed', failure, context: {
          'operation': 'app_startup',
          'repositoryLayer': true,
          'failureType': failure.runtimeType.toString(),
        });
        return Left(failure);
      },
          (userModel) {
        if (userModel != null) {
          final userEntity = userModel.toEntity();
          _logger.authEvent('app_initialization_success', userEntity.id, context: {
            'fullName': userEntity.fullName,
            'role': userEntity.role.value,
            'tenantId': userEntity.tenantId,
            'email': userEntity.email,
            'isActive': userEntity.isActive,
            'repositoryLayer': true,
          });
          return Right(userEntity);
        } else {
          _logger.authEvent('app_initialization_no_user', 'system', context: {
            'hasExistingSession': false,
            'repositoryLayer': true,
          });
          return const Right(null);
        }
      },
    );
  }

  @override
  Future<Either<AuthFailure, AuthResultEntity>> signInWithGoogle() async {
    final operationId = DateTime.now().millisecondsSinceEpoch.toString();

    _logger.authEvent('google_signin_repository_started', 'pending', context: {
      'operationId': operationId,
      'repositoryLayer': true,
    });

    final result = await _dataSource.signInWithGoogle();

    return result.fold(
          (failure) {
        _logger.authError('Google sign-in repository failed', failure, context: {
          'operationId': operationId,
          'repositoryLayer': true,
          'failureType': failure.runtimeType.toString(),
        });
        return Left(failure);
      },
          (userModel) {
        final isFirstLogin = userModel.lastLoginAt == null ||
            DateTime.now().difference(userModel.createdAt).inMinutes < 5;

        final userEntity = userModel.toEntity();
        final authResult = AuthResultEntity(
          user: userEntity,
          isFirstLogin: isFirstLogin,
        );

        _logger.authEvent('google_signin_repository_success', userEntity.id, context: {
          'operationId': operationId,
          'fullName': userEntity.fullName,
          'role': userEntity.role.value,
          'isFirstLogin': isFirstLogin,
          'repositoryLayer': true,
        });

        return Right(authResult);
      },
    );
  }

  @override
  Future<Either<AuthFailure, UserEntity?>> getCurrentUser() async {
    final result = await _dataSource.getCurrentUser();

    return result.fold(
          (failure) => Left(failure),
          (userModel) => Right(userModel?.toEntity()),
    );
  }

  @override
  Future<Either<AuthFailure, void>> signOut() async {
    return await _dataSource.signOut();
  }

  @override
  bool get isAuthenticated => _dataSource.isAuthenticated;
}