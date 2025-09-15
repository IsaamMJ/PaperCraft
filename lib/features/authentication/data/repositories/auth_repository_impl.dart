import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/auth_result_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthDataSource _dataSource;
  final String _redirectTo;

  AuthRepositoryImpl(this._dataSource, this._redirectTo) {
    AppLogger.info('AuthRepository: Initialized with redirect URL: $_redirectTo');
  }

  @override
  Future<UserEntity?> initialize() async {
    AppLogger.info('AuthRepository: Starting app initialization');

    try {
      final userModel = await _dataSource.initialize();

      if (userModel != null) {
        final userEntity = userModel.toEntity();
        AppLogger.info('AuthRepository: Initialization successful - User: ${userEntity.fullName} (${userEntity.role}, ID: ${userEntity.id})');
        return userEntity;
      } else {
        AppLogger.info('AuthRepository: Initialization completed - No authenticated user found');
        return null;
      }
    } catch (e) {
      AppLogger.error('AuthRepository: Initialize failed', e);
      return null;
    }
  }

  @override
  Future<AuthResultEntity> signInWithGoogle() async {
    AppLogger.info('AuthRepository: Starting Google sign-in process');

    try {
      final userModel = await _dataSource.signInWithGoogle(redirectTo: _redirectTo);

      // Check if it's first login (last_login_at is null or very recent)
      final isFirstLogin = userModel.lastLoginAt == null ||
          DateTime.now().difference(userModel.createdAt).inMinutes < 5;

      final userEntity = userModel.toEntity();

      AppLogger.info('AuthRepository: Google sign-in successful');
      AppLogger.info('AuthRepository: User authenticated - ${userEntity.fullName} (${userEntity.role})');
      AppLogger.info('AuthRepository: First login: $isFirstLogin');
      AppLogger.info('AuthRepository: Tenant: ${userEntity.tenantId ?? "None"}');

      final authResult = AuthResultEntity(
        user: userEntity,
        isFirstLogin: isFirstLogin,
      );

      return authResult;
    } catch (e) {
      AppLogger.error('AuthRepository: Google sign-in failed', e);
      rethrow;
    }
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    AppLogger.info('AuthRepository: Getting current user');

    try {
      final userModel = await _dataSource.getCurrentUser();

      if (userModel != null) {
        final userEntity = userModel.toEntity();
        AppLogger.info('AuthRepository: Current user retrieved - ${userEntity.fullName} (${userEntity.role})');
        return userEntity;
      } else {
        AppLogger.info('AuthRepository: No current user found');
        return null;
      }
    } catch (e) {
      AppLogger.error('AuthRepository: Error getting current user', e);
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    AppLogger.info('AuthRepository: Starting sign out process');

    try {
      await _dataSource.signOut();
      AppLogger.info('AuthRepository: Sign out completed successfully');
    } catch (e) {
      AppLogger.error('AuthRepository: Sign out failed', e);
      rethrow;
    }
  }

  @override
  bool get isAuthenticated {
    final authenticated = _dataSource.isAuthenticated;
    AppLogger.info('AuthRepository: Authentication status check - Authenticated: $authenticated');
    return authenticated;
  }
}