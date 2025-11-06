import 'package:dartz/dartz.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../entities/auth_result_entity.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';
import '../failures/auth_failures.dart';

class AuthUseCase {
  final AuthRepository _repository;
  final ILogger _logger;

  AuthUseCase(this._repository, this._logger);

  Future<Either<AuthFailure, UserEntity?>> initialize() => _repository.initialize();

  Future<Either<AuthFailure, AuthResultEntity>> signInWithGoogle() => _repository.signInWithGoogle();

  Future<Either<AuthFailure, UserEntity?>> getCurrentUser() => _repository.getCurrentUser();

  Future<Either<AuthFailure, Map<String, dynamic>>> getCurrentUserWithInitStatus() =>
    _repository.getCurrentUserWithInitStatus();

  Future<Either<AuthFailure, void>> signOut() => _repository.signOut();

  // NEW METHOD: Get user by ID for UserInfoService
  Future<Either<AuthFailure, UserEntity?>> getUserById(String userId) async {
    try {
      _logger.debug('Fetching user by ID', category: LogCategory.auth, context: {
        'targetUserId': userId,
        'operation': 'get_user_by_id',
      });

      // Call the repository to get user by ID
      final result = await _repository.getUserById(userId);

      return result.fold(
            (failure) {
          _logger.warning('Failed to fetch user by ID', category: LogCategory.auth, context: {
            'targetUserId': userId,
            'error': failure.message,
          });
          return Left(failure);
        },
            (user) {
          if (user != null) {
            _logger.debug('User found by ID', category: LogCategory.auth, context: {
              'targetUserId': userId,
              'userFullName': user.fullName,
              'userRole': user.role.value,
            });
            return Right(user);
          } else {
            _logger.debug('User not found by ID', category: LogCategory.auth, context: {
              'targetUserId': userId,
            });
            return const Right(null);
          }
        },
      );
    } catch (e, stackTrace) {
      _logger.error('Exception in getUserById',
        category: LogCategory.auth,
        error: e,
        stackTrace: stackTrace,
        context: {'targetUserId': userId},
      );
      return Left(AuthFailure('Failed to get user by ID: ${e.toString()}'));
    }
  }

  bool get isAuthenticated => _repository.isAuthenticated;
}