// Fixed auth_data_source.dart - Simplified and working version
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../../core/infrastructure/config/auth_config.dart';
import '../../../../core/infrastructure/network/api_client.dart';
import '../../../../core/infrastructure/utils/platform_utils.dart';
import '../../domain/failures/auth_failures.dart';
import '../models/user_model.dart';

class AuthDataSource {
  final ApiClient _apiClient;
  final ILogger _logger;
  final SupabaseClient _supabase;

  AuthDataSource(this._apiClient, this._logger, this._supabase);

  Future<Either<AuthFailure, UserModel?>> initialize() async {
    _logger.authEvent('initialize_started', 'system', context: {
      'method': 'session_check',
      'timestamp': DateTime.now().toIso8601String(),
    });

    try {
      final session = _supabase.auth.currentSession;
      if (session?.user == null) {
        _logger.authEvent('initialize_no_session', 'system', context: {
          'hasSession': false,
          'reason': 'no_current_session',
        });
        return const Right(null);
      }

      _logger.authEvent('initialize_session_found', session!.user.id, context: {
        'hasSession': true,
        'userEmail': session.user.email,
      });

      // Simple profile fetch - no complex retry logic
      final userResult = await _getUserProfile(session.user.id);

      return userResult.fold(
            (failure) {
          _logger.authError('User profile fetch failed', failure, context: {
            'userId': session.user.id,
            'failure': failure.message,
          });
          return Left(failure);
        },
            (userModel) {
          if (userModel != null && userModel.isActive) {
            _logger.authEvent('initialize_success', userModel.id, context: {
              'fullName': userModel.fullName,
              'role': userModel.role,
              'isActive': userModel.isActive,
            });
            return Right(userModel);
          } else if (userModel != null && !userModel.isActive) {
            return const Left(DeactivatedAccountFailure());
          } else {
            return const Left(AuthFailure('User profile not found'));
          }
        },
      );
    } catch (e, stackTrace) {
      _logger.authError('Initialize failed with exception', e, context: {
        'errorType': e.runtimeType.toString(),
        'operation': 'initialize',
      });
      return Left(AuthFailure('Initialization failed: ${e.toString()}'));
    }
  }

  Future<Either<AuthFailure, UserModel>> signInWithGoogle() async {
    final operationId = DateTime.now().millisecondsSinceEpoch.toString();

    _logger.authEvent('google_signin_started', 'pending', context: {
      'redirectTo': AuthConfig.redirectUrl,
      'operationId': operationId,
      'platform': PlatformUtils.platformName,
      'isWeb': kIsWeb,
    });

    print('🚀 DEBUG: About to call OAuth with redirectTo: ${AuthConfig.redirectUrl}');

    try {
      // Start the OAuth flow
      final bool launched = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: AuthConfig.redirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
        queryParams: {
          'prompt': 'select_account',
          'access_type': 'offline',
        },
      );

      if (!launched) {
        _logger.authError('OAuth launch failed', null, context: {
          'operationId': operationId,
          'reason': 'failed_to_launch',
          'platform': PlatformUtils.platformName,
        });
        return const Left(AuthFailure('Failed to start OAuth flow'));
      }

      _logger.debug('OAuth flow launched successfully', category: LogCategory.auth, context: {
        'operationId': operationId,
        'isWeb': kIsWeb,
        'note': kIsWeb ? 'Web redirect initiated' : 'Waiting for mobile callback',
      });

      // On web, this method triggers a page redirect, so execution stops here
      if (kIsWeb) {
        return const Left(AuthFailure('OAuth redirect in progress'));
      }

      // For mobile platforms, wait for the session
      final session = await _waitForSession();

      if (session?.user == null) {
        _logger.authError('OAuth session not received', null, context: {
          'operationId': operationId,
          'reason': 'no_session_after_oauth',
          'platform': 'mobile',
        });
        return const Left(AuthFailure('Authentication was cancelled or failed'));
      }

      return await _processSuccessfulOAuth(session!, operationId);

    } catch (e, stackTrace) {
      _logger.authError('Unexpected sign-in error', e, context: {
        'operationId': operationId,
        'errorType': e.runtimeType.toString(),
        'operation': 'google_signin',
        'platform': PlatformUtils.platformName,
      });
      return Left(AuthFailure('Sign-in failed: ${e.toString()}'));
    }
  }

  Future<Either<AuthFailure, UserModel>> _processSuccessfulOAuth(Session session, String operationId) async {
    _logger.authEvent('oauth_session_received', session.user.id, context: {
      'operationId': operationId,
      'userEmail': session.user.email,
      'provider': 'google',
      'platform': PlatformUtils.platformName,
    });

    // Wait longer for profile creation/sync - increased to 2 seconds
    await Future.delayed(const Duration(milliseconds: 2000));

    // Get user profile after successful OAuth
    final userResult = await _createOrGetUserProfile(session.user);

    return userResult.fold(
          (failure) {
        _signOut(); // Cleanup on failure
        return Left(failure);
      },
          (userModel) {
        if (!userModel.isActive) {
          _signOut(); // Cleanup on inactive user
          return const Left(DeactivatedAccountFailure());
        }

        _logger.authEvent('google_signin_success', userModel.id, context: {
          'operationId': operationId,
          'fullName': userModel.fullName,
          'role': userModel.role,
          'userEmail': userModel.email,
          'completedAt': DateTime.now().toIso8601String(),
          'platform': PlatformUtils.platformName,
        });

        return Right(userModel);
      },
    );
  }

  Future<Either<AuthFailure, UserModel?>> getCurrentUser() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return const Right(null);
      }

      return await _getUserProfile(user.id);
    } catch (e, stackTrace) {
      _logger.authError('Error getting current user', e, context: {
        'errorType': e.runtimeType.toString(),
        'operation': 'get_current_user',
      });
      return Left(AuthFailure('Failed to get current user: ${e.toString()}'));
    }
  }

  Future<Either<AuthFailure, void>> signOut() async {
    final currentUserId = _supabase.auth.currentUser?.id ?? 'unknown';

    _logger.authEvent('signout_started', currentUserId, context: {
      'hasCurrentUser': _supabase.auth.currentUser != null,
      'timestamp': DateTime.now().toIso8601String(),
    });

    try {
      await _signOut();

      _logger.authEvent('signout_success', currentUserId, context: {
        'completedAt': DateTime.now().toIso8601String(),
      });

      return const Right(null);
    } catch (e, stackTrace) {
      _logger.authError('Sign out error', e, context: {
        'userId': currentUserId,
        'operation': 'signout',
      });
      // Always return success to user even if there was an error
      return const Right(null);
    }
  }

  bool get isAuthenticated => _supabase.auth.currentUser != null;

  // =============== PRIVATE METHODS ===============

  Future<Either<AuthFailure, UserModel?>> _getUserProfile(String userId) async {
    try {
      final response = await _apiClient.selectSingle<UserModel>(
        table: 'profiles',
        fromJson: UserModel.fromJson,
        filters: {'id': userId},
      );

      if (response.isSuccess) {
        final userModel = response.data;
        if (userModel == null) {
          return const Right(null);
        }
        return Right(userModel);
      } else {
        return Left(AuthFailure(response.message ?? 'Failed to fetch user profile'));
      }
    } catch (e, stackTrace) {
      _logger.authError('Exception fetching user profile', e, context: {
        'userId': userId,
        'operation': 'api_profile_fetch',
      });
      return Left(AuthFailure('Failed to fetch user profile: ${e.toString()}'));
    }
  }

  Future<Either<AuthFailure, UserModel>> _createOrGetUserProfile(User user) async {
    try {
      // Wait briefly for any database triggers to complete
      await Future.delayed(const Duration(milliseconds: 500));

      final profileResult = await _getUserProfile(user.id);

      return profileResult.fold(
            (failure) => Left(failure),
            (profile) {
          if (profile != null) {
            return Right(profile);
          }
          return const Left(AuthFailure('Profile creation failed'));
        },
      );
    } catch (e, stackTrace) {
      _logger.authError('Error in profile lookup', e, context: {
        'userId': user.id,
        'userEmail': user.email,
      });
      return Left(AuthFailure('Profile lookup failed: ${e.toString()}'));
    }
  }

  Future<Session?> _waitForSession() async {
    final completer = Completer<Session?>();
    late StreamSubscription subscription;

    print('🚀 DEBUG: Starting to wait for session');

    // Check if we already have a session
    final currentSession = _supabase.auth.currentSession;
    if (currentSession?.user != null) {
      print('🚀 DEBUG: Session already available');
      return currentSession;
    }

    // Listen for auth state changes
    subscription = _supabase.auth.onAuthStateChange.listen((data) {
      print('🚀 DEBUG: Auth state change: ${data.event.name}, hasSession: ${data.session != null}');

      if (data.session?.user != null && !completer.isCompleted) {
        print('🚀 DEBUG: Session received via auth state change');
        completer.complete(data.session);
        subscription.cancel();
      } else if (data.event == AuthChangeEvent.signedOut && !completer.isCompleted) {
        print('🚀 DEBUG: SignedOut event received');
        completer.complete(null);
        subscription.cancel();
      }
    });

    // Set timeout - increased to 45 seconds
    Timer(const Duration(seconds: 45), () {
      print('🚀 DEBUG: Session wait timed out after 45 seconds');
      if (!completer.isCompleted) {
        subscription.cancel();
        completer.complete(null);
      }
    });

    return await completer.future;
  }

  Future<void> _signOut() async {
    try {
      // Add shorter timeout to prevent hanging
      await _supabase.auth.signOut(scope: SignOutScope.global)
          .timeout(const Duration(seconds: 5)); // Reduced from 10 to 5 seconds

      _logger.debug('Global signout completed', category: LogCategory.auth);
    } catch (e) {
      _logger.warning('Global signout failed, trying local', category: LogCategory.auth, context: {
        'error': e.toString(),
        'fallback': 'local_signout',
      });

      try {
        // Try local signout with shorter timeout as fallback
        await _supabase.auth.signOut(scope: SignOutScope.local)
            .timeout(const Duration(seconds: 3)); // Reduced from 5 to 3 seconds

        _logger.debug('Local signout completed', category: LogCategory.auth);
      } catch (localError) {
        _logger.warning('Local signout also failed', category: LogCategory.auth, context: {
          'error': localError.toString(),
          'action': 'continuing_anyway',
        });
        // Continue anyway - we'll clear local state
      }
    }
  }
}