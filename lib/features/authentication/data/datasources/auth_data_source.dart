// Fixed auth_data_source.dart - Simplified and working version
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../../core/infrastructure/config/auth_config.dart';
import '../../../../core/infrastructure/config/environment.dart';
import '../../../../core/infrastructure/config/environment_config.dart';
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

      // SECURITY FIX: Validate email domain after OAuth
      final email = session!.user.email;
      if (email == null || !_isAllowedDomain(email)) {
        _logger.authError('Unauthorized domain attempted signin', null, context: {
          'email': email,
          'operationId': operationId,
          'securityViolation': true,
        });

        // Sign out the unauthorized user
        await _signOut();
        return Left(UnauthorizedDomainFailure(_extractDomain(email ?? 'unknown')));
      }

      return await _processSuccessfulOAuth(session, operationId);

    } catch (e, stackTrace) {
      _logger.authError('Unexpected sign-in error', e, context: {
        'operationId': operationId,
        'errorType': e.runtimeType.toString(),
      });
      return Left(AuthFailure('Sign-in failed: ${e.toString()}'));
    }
  }

  bool _isAllowedDomain(String email) {
    final allowedDomains = _getAllowedDomains();
    final domain = _extractDomain(email);
    return allowedDomains.contains(domain.toLowerCase());
  }

  // Add this method to your AuthDataSource class
// features/authentication/data/datasources/auth_data_source.dart

// Add this method to your existing AuthDataSource class:

  // Add this to AuthDataSource class
  Future<Either<AuthFailure, String>> _createPersonalTenant(String userEmail, String userName) async {
    try {
      _logger.debug('Creating personal tenant', category: LogCategory.auth, context: {
        'userEmail': userEmail,
        'userName': userName,
      });

      // Generate tenant name for personal workspace
      final tenantName = _generateTenantName(userName, userEmail);

      final response = await _apiClient.insert<Map<String, dynamic>>(
        table: 'tenants',
        data: {
          'name': tenantName,
          'domain': null, // Personal tenants don't have domains
          'is_active': true,
        },
        fromJson: (json) => json,
      );

      if (response.isSuccess && response.data != null) {
        final tenantId = response.data!['id'] as String;

        _logger.info('Personal tenant created successfully', category: LogCategory.auth, context: {
          'tenantId': tenantId,
          'tenantName': tenantName,
          'userEmail': userEmail,
        });

        return Right(tenantId);
      } else {
        return Left(AuthFailure(response.message ?? 'Failed to create personal tenant'));
      }
    } catch (e, stackTrace) {
      _logger.error('Exception creating personal tenant',
        category: LogCategory.auth,
        error: e,
        stackTrace: stackTrace,
        context: {'userEmail': userEmail},
      );
      return Left(AuthFailure('Failed to create personal tenant: ${e.toString()}'));
    }
  }

  String _generateTenantName(String userName, String userEmail) {
    // Clean up the user name for tenant naming
    final cleanName = userName.trim();
    if (cleanName.isNotEmpty) {
      return "$cleanName's Workspace";
    } else {
      // Fallback to email prefix if name is empty
      final emailPrefix = userEmail.split('@').first;
      return "${emailPrefix}'s Workspace";
    }
  }

  Future<Either<AuthFailure, String?>> _findSchoolTenant(String domain) async {
    try {
      _logger.debug('Looking for school tenant by domain', category: LogCategory.auth, context: {
        'domain': domain,
      });

      final response = await _apiClient.selectSingle<Map<String, dynamic>>(
        table: 'tenants',
        fromJson: (json) => json,
        filters: {'domain': domain, 'is_active': true},
      );

      if (response.isSuccess && response.data != null) {
        final tenantId = response.data!['id'] as String;
        final tenantName = response.data!['name'] as String;

        _logger.debug('School tenant found', category: LogCategory.auth, context: {
          'tenantId': tenantId,
          'tenantName': tenantName,
          'domain': domain,
        });

        return Right(tenantId);
      } else {
        _logger.warning('No school tenant found for domain', category: LogCategory.auth, context: {
          'domain': domain,
        });
        return const Right(null);
      }
    } catch (e, stackTrace) {
      _logger.error('Exception finding school tenant',
        category: LogCategory.auth,
        error: e,
        stackTrace: stackTrace,
        context: {'domain': domain},
      );
      return Left(AuthFailure('Failed to find school tenant: ${e.toString()}'));
    }
  }

  Future<Either<AuthFailure, void>> _assignUserToTenant(String userId, String tenantId) async {
    try {
      _logger.debug('Assigning user to tenant', category: LogCategory.auth, context: {
        'userId': userId,
        'tenantId': tenantId,
      });

      final response = await _apiClient.update<Map<String, dynamic>>(
        table: 'profiles',
        data: {'tenant_id': tenantId},
        filters: {'id': userId},
        fromJson: (json) => json,
      );

      if (response.isSuccess) {
        _logger.info('User assigned to tenant successfully', category: LogCategory.auth, context: {
          'userId': userId,
          'tenantId': tenantId,
        });
        return const Right(null);
      } else {
        return Left(AuthFailure(response.message ?? 'Failed to assign user to tenant'));
      }
    } catch (e, stackTrace) {
      _logger.error('Exception assigning user to tenant',
        category: LogCategory.auth,
        error: e,
        stackTrace: stackTrace,
        context: {'userId': userId, 'tenantId': tenantId},
      );
      return Left(AuthFailure('Failed to assign user to tenant: ${e.toString()}'));
    }
  }

  Future<Either<AuthFailure, UserModel?>> getUserProfileById(String userId) async {
    try {
      _logger.debug('Fetching user profile by ID from API', category: LogCategory.auth, context: {
        'targetUserId': userId,
      });

      final response = await _apiClient.selectSingle<UserModel>(
        table: 'profiles',
        fromJson: UserModel.fromJson,
        filters: {'id': userId},
      );

      if (response.isSuccess) {
        final userModel = response.data;

        if (userModel != null) {
          _logger.debug('User profile found by ID', category: LogCategory.auth, context: {
            'targetUserId': userId,
            'userFullName': userModel.fullName,
            'userEmail': userModel.email,
          });
        } else {
          _logger.debug('User profile not found by ID', category: LogCategory.auth, context: {
            'targetUserId': userId,
          });
        }

        return Right(userModel);
      } else {
        return Left(AuthFailure(response.message ?? 'Failed to fetch user profile by ID'));
      }
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

  List<String> _getAllowedDomains() {
    switch (EnvironmentConfig.current) {
      case Environment.dev:
        return ['pearlmatricschool.com', 'gmail.com']; // Both school and Gmail for development
      case Environment.staging:
      case Environment.prod:
        return ['pearlmatricschool.com', 'gmail.com']; // Allow both domains in production as requested
    }
  }

  String _extractDomain(String email) {
    final parts = email.split('@');
    return parts.length == 2 ? parts[1] : '';
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

      print('=== DEBUG: Raw API Response ===');
      print('Response success: ${response.isSuccess}');
      print('Response data: ${response.data}');
      print('==============================');

      if (response.isSuccess) {
        final userModel = response.data;
        if (userModel == null) {
          return const Right(null);
        }

        // ADD MORE DEBUG
        print('=== DEBUG: UserModel ===');
        print('UserModel tenantId: ${userModel.tenantId}');
        print('UserModel toEntity tenantId: ${userModel.toEntity().tenantId}');
        print('=======================');

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
      await Future.delayed(const Duration(milliseconds: 500));

      final profileResult = await _getUserProfile(user.id);

      return profileResult.fold(
            (failure) => Left(failure),
            (profile) async {
          if (profile != null) {
            // Check if user needs tenant assignment
            if (profile.tenantId == null) {
              _logger.info('User missing tenant assignment, creating/assigning tenant',
                  category: LogCategory.auth,
                  context: {
                    'userId': user.id,
                    'email': user.email,
                    'userFullName': profile.fullName,
                  });

              // Auto-assign tenant based on email domain
              final tenantAssignResult = await _autoAssignTenant(user, profile);

              return tenantAssignResult.fold(
                    (failure) => Left(failure),
                    (updatedProfile) => Right(updatedProfile),
              );
            }

            // User already has tenant assigned
            return Right(profile);
          }

          // Profile doesn't exist - this should be handled by database triggers
          _logger.warning('Profile not found after OAuth completion',
              category: LogCategory.auth,
              context: {
                'userId': user.id,
                'email': user.email,
                'expectedAutoCreation': true,
              });

          return const Left(AuthFailure('Profile creation failed - please contact administrator'));
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

  Future<Either<AuthFailure, UserModel>> _autoAssignTenant(User user, UserModel profile) async {
    try {
      final email = user.email!;
      final domain = _extractDomain(email);

      _logger.info('Auto-assigning tenant based on domain', category: LogCategory.auth, context: {
        'userId': user.id,
        'email': email,
        'domain': domain,
      });

      String? tenantId;

      if (domain == 'pearlmatricschool.com') {
        // School user - find existing school tenant
        final schoolTenantResult = await _findSchoolTenant(domain);

        final schoolTenantId = await schoolTenantResult.fold(
              (failure) => throw failure,
              (foundTenantId) => foundTenantId,
        );

        if (schoolTenantId != null) {
          tenantId = schoolTenantId;
          _logger.info('Assigning user to school tenant', category: LogCategory.auth, context: {
            'userId': user.id,
            'tenantId': tenantId,
            'tenantType': 'school',
          });
        } else {
          return const Left(AuthFailure('School tenant not found - please contact administrator'));
        }
      } else if (domain == 'gmail.com') {
        // Individual user - create personal tenant
        final personalTenantResult = await _createPersonalTenant(email, profile.fullName);

        tenantId = await personalTenantResult.fold(
              (failure) => throw failure,
              (createdTenantId) => createdTenantId,
        );

        _logger.info('Created personal tenant for user', category: LogCategory.auth, context: {
          'userId': user.id,
          'tenantId': tenantId,
          'tenantType': 'personal',
        });
      } else {
        return Left(AuthFailure('Unsupported email domain: $domain'));
      }
// Ensure tenantId is not null before assignment
      if (tenantId == null) {
        return const Left(AuthFailure('Failed to determine tenant ID'));
      }

// Assign user to the tenant
      final assignResult = await _assignUserToTenant(user.id, tenantId);

      await assignResult.fold(
            (failure) => throw failure,
            (_) => Future.value(),
      );

      // Fetch updated profile with tenant assignment
      final updatedProfileResult = await _getUserProfile(user.id);

      return updatedProfileResult.fold(
            (failure) => Left(failure),
            (updatedProfile) {
          if (updatedProfile != null) {
            _logger.info('Tenant auto-assignment completed successfully', category: LogCategory.auth, context: {
              'userId': user.id,
              'tenantId': tenantId,
              'finalCheck': 'success',
            });
            return Right(updatedProfile);
          } else {
            return const Left(AuthFailure('Failed to fetch updated profile after tenant assignment'));
          }
        },
      );

    } catch (e, stackTrace) {
      _logger.error('Exception during auto tenant assignment',
        category: LogCategory.auth,
        error: e,
        stackTrace: stackTrace,
        context: {'userId': user.id, 'userEmail': user.email},
      );
      return Left(AuthFailure('Auto tenant assignment failed: ${e.toString()}'));
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