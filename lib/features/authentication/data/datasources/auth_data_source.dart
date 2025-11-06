import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:dartz/dartz.dart';
import '../../../../core/domain/interfaces/i_auth_provider.dart';
import '../../../../core/domain/interfaces/i_clock.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../../core/domain/services/tenant_initialization_service.dart';
import '../../../../core/infrastructure/config/auth_config.dart';
import '../../../../core/infrastructure/network/api_client.dart';
import '../../../../core/infrastructure/utils/platform_utils.dart';
import '../../domain/failures/auth_failures.dart';
import '../models/user_model.dart';

class AuthDataSource {
  final ApiClient _apiClient;
  final ILogger _logger;
  final IAuthProvider _authProvider;
  final IClock _clock;
  final TenantInitializationService _tenantInitializationService;

  AuthDataSource(
    this._apiClient,
    this._logger,
    this._authProvider,
    this._clock,
    this._tenantInitializationService,
  );

  Future<Either<AuthFailure, UserModel?>> initialize() async {
    _logger.authEvent('initialize_started', 'system', context: {
      'method': 'session_check',
      'timestamp': _clock.now().toIso8601String(),
    });

    try {
      final session = _authProvider.currentSession;
      if (session?.user == null) {
        _logger.authEvent('initialize_no_session', 'system', context: {
          'hasSession': false,
        });
        return const Right(null);
      }

      _logger.authEvent('initialize_session_found', session!.user.id, context: {
        'hasSession': true,
        'userEmail': session.user.email,
      });

      final userResult = await _getUserProfile(session.user.id);

      return userResult.fold(
            (failure) {
          _logger.authError('User profile fetch failed', failure, context: {
            'userId': session.user.id,
          });
          return Left(failure);
        },
            (userModel) {
          if (userModel != null && userModel.isActive) {
            _logger.authEvent('initialize_success', userModel.id, context: {
              'fullName': userModel.fullName,
              'role': userModel.role,
            });
            return Right(userModel);
          } else if (userModel != null && !userModel.isActive) {
            return const Left(DeactivatedAccountFailure());
          } else {
            return const Left(AuthFailure('User profile not found'));
          }
        },
      );
    } catch (e) {
      _logger.authError('Initialize failed with exception', e, context: {
        'errorType': e.runtimeType.toString(),
      });
      return Left(AuthFailure('Initialization failed: ${e.toString()}'));
    }
  }

  Future<Either<AuthFailure, UserModel>> signInWithGoogle() async {
    final operationId = _clock.now().millisecondsSinceEpoch.toString();



    _logger.authEvent('google_signin_started', 'pending', context: {
      'redirectTo': AuthConfig.googleOAuthRedirectUrl,
      'operationId': operationId,
      'platform': PlatformUtils.platformName,
      'isWeb': kIsWeb,
    });

    try {
      final bool launched = await _authProvider.signInWithOAuth(
        provider: OAuthProvider.google,
        redirectUrl: AuthConfig.googleOAuthRedirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
        queryParams: {
          'prompt': 'select_account',
          'access_type': 'offline',
        },
      );

      if (!launched) {
        _logger.authError('OAuth launch failed', null, context: {
          'operationId': operationId,
        });
        return const Left(AuthFailure('Failed to start OAuth flow'));
      }

      if (kIsWeb) {
        return const Left(AuthFailure('OAuth redirect in progress'));
      }

      final session = await _waitForSession();

      if (session?.user == null) {
        return const Left(AuthFailure('Authentication was cancelled or failed'));
      }

      return await _processSuccessfulOAuth(session!, operationId);

    } catch (e) {
      _logger.authError('Unexpected sign-in error', e, context: {
        'operationId': operationId,
        'errorType': e.runtimeType.toString(),
      });
      return Left(AuthFailure('Sign-in failed: ${e.toString()}'));
    }
  }

  Future<Either<AuthFailure, UserModel>> _processSuccessfulOAuth(
      Session session,
      String operationId,
      ) async {
    _logger.authEvent('oauth_session_received', session.user.id, context: {
      'operationId': operationId,
      'userEmail': session.user.email,
      'platform': PlatformUtils.platformName,
    });

    // Retry profile fetch with exponential backoff
    final userResult = await _waitForProfileCreation(session.user.id);

    return userResult.fold(
          (failure) {
        _signOut(); // Cleanup on failure
        return Left(failure);
      },
          (userModel) {
        if (userModel == null) {
          _signOut();
          return const Left(AuthFailure('Profile creation failed - please contact administrator'));
        }

        if (!userModel.isActive) {
          _signOut();
          return const Left(DeactivatedAccountFailure());
        }

        // Note: last_login_at is NOT updated here to keep isFirstLogin true during onboarding
        // It will be updated after the user completes their onboarding flow

        _logger.authEvent('google_signin_success', userModel.id, context: {
          'operationId': operationId,
          'fullName': userModel.fullName,
          'role': userModel.role,
          'userEmail': userModel.email,
          'platform': PlatformUtils.platformName,
        });

        return Right(userModel);
      },
    );
  }

  /// Wait for database trigger to create profile with retry logic
  Future<Either<AuthFailure, UserModel?>> _waitForProfileCreation(String userId) async {
    const maxAttempts = 6;
    const baseDelay = Duration(milliseconds: 500);

    _logger.debug('Waiting for profile creation', category: LogCategory.auth, context: {
      'userId': userId,
      'maxAttempts': maxAttempts,
    });

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      // Exponential backoff: 500ms, 1s, 2s, 4s, 8s, 16s
      final delay = baseDelay * (1 << (attempt - 1));

      _logger.debug('Profile fetch attempt', category: LogCategory.auth, context: {
        'userId': userId,
        'attempt': attempt,
        'delayMs': delay.inMilliseconds,
      });

      await _clock.delay(delay);

      final result = await _getUserProfile(userId);

      // Check if we got a result
      final hasProfile = result.fold(
            (failure) => false,
            (profile) => profile != null,
      );

      if (hasProfile) {
        _logger.debug('Profile found', category: LogCategory.auth, context: {
          'userId': userId,
          'attempt': attempt,
          'totalWaitMs': _calculateTotalWait(attempt, baseDelay),
        });
        return result;
      }

      // Log retry
      _logger.debug('Profile not found, retrying', category: LogCategory.auth, context: {
        'userId': userId,
        'attempt': attempt,
        'remainingAttempts': maxAttempts - attempt,
      });
    }

    // All retries exhausted
    _logger.error('Profile creation timeout',
      category: LogCategory.auth,
      error: Exception('Profile not created after $maxAttempts attempts'),
      context: {
        'userId': userId,
        'totalWaitMs': _calculateTotalWait(maxAttempts, baseDelay),
      },
    );

    return const Left(AuthFailure(
      'Profile creation timed out. The database trigger may have failed. Please contact support.',
    ));
  }

  /// Calculate total wait time for logging
  int _calculateTotalWait(int attempts, Duration baseDelay) {
    int total = 0;
    for (int i = 1; i <= attempts; i++) {
      total += (baseDelay * (1 << (i - 1))).inMilliseconds;
    }
    return total;
  }


  Future<Either<AuthFailure, UserModel?>> getCurrentUser() async {
    try {
      final user = _authProvider.currentUser;
      if (user == null) {
        return const Right(null);
      }

      return await _getUserProfile(user.id);
    } catch (e) {
      _logger.authError('Error getting current user', e, context: {
        'errorType': e.runtimeType.toString(),
      });
      return Left(AuthFailure('Failed to get current user: ${e.toString()}'));
    }
  }

  /// Get current user with initialization status
  /// This is used by AuthBloc to determine which screen to show
  Future<Either<AuthFailure, Map<String, dynamic>>> getCurrentUserWithInitStatus() async {
    try {
      final user = _authProvider.currentUser;
      if (user == null) {
        return const Right({});
      }

      final userResult = await _getUserProfile(user.id);

      if (userResult.isLeft()) {
        return userResult.fold(
          (failure) => Left(failure),
          (_) => const Right({}),
        );
      }

      final userModel = userResult.getOrElse(() => null);
      if (userModel == null) {
        return const Right({});
      }

      // Query tenant initialization status using the service
      bool tenantInitialized = false;
      if (userModel.tenantId != null) {
        tenantInitialized = await _tenantInitializationService.isTenantInitialized(
          userModel.tenantId!,
        );
      }

      return Right({
        'user': userModel,
        'tenantInitialized': tenantInitialized,
      });
    } catch (e) {
      _logger.authError('Error getting current user with init status', e, context: {
        'errorType': e.runtimeType.toString(),
      });
      return Left(AuthFailure('Failed to get current user: ${e.toString()}'));
    }
  }

  Future<Either<AuthFailure, UserModel?>> getUserProfileById(String userId) async {
    try {
      _logger.debug('Fetching user profile by ID', category: LogCategory.auth, context: {
        'targetUserId': userId,
      });

      return await _getUserProfile(userId);
    } catch (e, stackTrace) {
      _logger.error('Exception fetching user profile by ID',
        category: LogCategory.auth,
        error: e,
        stackTrace: stackTrace,
        context: {'targetUserId': userId},
      );
      return Left(AuthFailure('Failed to fetch user profile by ID: ${e.toString()}'));
    }
  }

  Future<Either<AuthFailure, void>> signOut() async {
    final currentUserId = _authProvider.currentUser?.id ?? 'unknown';

    _logger.authEvent('signout_started', currentUserId, context: {
      'hasCurrentUser': _authProvider.currentUser != null,
      'timestamp': _clock.now().toIso8601String(),
    });

    try {
      await _signOut();

      // Clear tenant initialization cache on logout
      _tenantInitializationService.clearCache();

      _logger.authEvent('signout_success', currentUserId, context: {
        'completedAt': _clock.now().toIso8601String(),
      });

      return const Right(null);
    } catch (e) {
      _logger.authError('Sign out error', e, context: {
        'userId': currentUserId,
      });

      // Still clear cache even if signout had an error
      _tenantInitializationService.clearCache();

      return const Right(null);
    }
  }

  bool get isAuthenticated => _authProvider.isAuthenticated;

  // =============== PRIVATE METHODS ===============

  Future<Either<AuthFailure, UserModel?>> _getUserProfile(String userId) async {
    try {
      // Get user profile
      final response = await _apiClient.selectSingle<UserModel>(
        table: 'profiles',
        fromJson: UserModel.fromJson,
        filters: {'id': userId},
      );

      if (!response.isSuccess) {
        return Left(AuthFailure(response.message ?? 'Failed to fetch user profile'));
      }

      final userModel = response.data;
      if (userModel == null) {
        return const Right(null);
      }

      return Right(userModel);
    } catch (e) {
      _logger.authError('Exception fetching user profile', e, context: {
        'userId': userId,
      });
      return Left(AuthFailure('Failed to fetch user profile: ${e.toString()}'));
    }
  }

  Future<Session?> _waitForSession() async {
    final completer = Completer<Session?>();
    late StreamSubscription subscription;

    final currentSession = _authProvider.currentSession;
    if (currentSession?.user != null) {
      return currentSession;
    }

    subscription = _authProvider.onAuthStateChange.listen((event) {
      if (event.session?.user != null && !completer.isCompleted) {
        completer.complete(event.session);
        subscription.cancel();
      } else if (event.event == AuthChangeEvent.signedOut && !completer.isCompleted) {
        completer.complete(null);
        subscription.cancel();
      }
    });

    _clock.timer(const Duration(seconds: 45), () {
      if (!completer.isCompleted) {
        subscription.cancel();
        completer.complete(null);
      }
    });

    return await completer.future;
  }

  Future<void> _signOut() async {
    try {
      await _authProvider.signOut(scope: SignOutScope.global)
          .timeout(const Duration(seconds: 5));

      _logger.debug('Global signout completed', category: LogCategory.auth);
    } catch (e) {
      _logger.warning('Global signout failed, trying local', category: LogCategory.auth);

      try {
        await _authProvider.signOut(scope: SignOutScope.local)
            .timeout(const Duration(seconds: 3));

        _logger.debug('Local signout completed', category: LogCategory.auth);
      } catch (localError) {
        _logger.warning('Local signout also failed', category: LogCategory.auth);
      }
    }
  }

  Future<void> _updateLastLoginAt(String userId) async {
    try {
      // Store local time (not UTC) so it displays correctly in user's timezone
      await _apiClient.update<void>(
        table: 'profiles',
        data: {'last_login_at': DateTime.now().toIso8601String()},
        filters: {'id': userId},
        fromJson: (_) => null,
      );
      _logger.debug('Last login updated', category: LogCategory.auth, context: {'userId': userId});
    } catch (e) {
      _logger.warning('Failed to update last login', category: LogCategory.auth, context: {
        'userId': userId,
        'error': e.toString(),
      });
    }
  }
}