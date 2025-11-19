import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../../../core/domain/interfaces/i_auth_provider.dart';
import '../../../../core/domain/interfaces/i_clock.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../../core/infrastructure/logging/app_logger.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/services/user_state_service.dart';
import '../../domain/failures/auth_failures.dart';
import '../../domain/usecases/auth_usecase.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthUseCase _authUseCase;
  final UserStateService _userStateService;
  final Stream<AuthStateChangeEvent> _authStateStream;
  final IClock _clock;
  late StreamSubscription _authSubscription;

  // FIXED: Prevent multiple OAuth attempts and resource leaks
  bool _isOAuthInProgress = false;
  bool _isInitialized = false;
  bool _isSigningOut = false; // Prevent duplicate sign-out events

  // SECURITY FIX: Auth state synchronization
  Timer? _syncTimer;

  AuthBloc(
    this._authUseCase,
    this._userStateService,
    this._authStateStream,
    this._clock,
  ) : super(const AuthInitial()) {
    on<AuthInitialize>(_onInitialize);
    on<AuthSignInGoogle>(_onSignInGoogle);
    on<AuthSignOut>(_onSignOut);
    on<AuthCheckStatus>(_onCheckStatus);

    AppLogger.blocEvent('AuthBloc', 'initialized');
    _listenToAuthChanges();

    // SECURITY FIX: Start auth state synchronization
    _startAuthStateSyncTimer();
  }

  void _listenToAuthChanges() {
    _authSubscription = _authStateStream.listen(
          (event) {

        try {
          AppLogger.authEvent('auth_state_changed', event.session?.user.id ?? 'unknown', context: {
            'event': event.event.name,
            'hasSession': event.session != null,
            'timestamp': _clock.now().toIso8601String(),
          });

          // ✅ Handle OAuth response for web ONLY
          // For native: _onSignInGoogle already handles authentication
          if (event.event == AuthChangeEvent.signedIn && event.session?.user != null && kIsWeb) {
            // Web platform received OAuth response
            Future.microtask(() {
              if (!isClosed) {
                try {
                  add(const AuthCheckStatus());
                } catch (e) {
                  // Event already processed or bloc closed
                }
              }
            });
          }

          // Handle session expiry (but NOT during explicit sign-out)
          if (event.event == AuthChangeEvent.signedOut && state is AuthAuthenticated && !_isSigningOut) {
            AppLogger.warning('Session expired, redirecting to login',
                category: LogCategory.auth,
                context: {
                  'previousUserId': (state as AuthAuthenticated).user.id,
                  'sessionEvent': event.event.name,
                }
            );
            _handleSessionExpiry();
          }
        } catch (e, stackTrace) {
          AppLogger.error(
            'Exception in auth listener',
            error: e,
            stackTrace: stackTrace,
            category: LogCategory.auth,
          );
        }
      },
      onError: (error, stackTrace) {
        AppLogger.authError('Auth stream error', error, context: {
          'errorType': error.runtimeType.toString(),
          'stackTrace': stackTrace.toString(),
        });
      },
    );

  }

  void _handleSessionExpiry() {
    final currentUserId = state is AuthAuthenticated
        ? (state as AuthAuthenticated).user.id
        : 'unknown';

    AppLogger.authEvent('session_expiry_handled', currentUserId, context: {
      'handlerType': 'automatic',
      'previousState': state.runtimeType.toString(),
    });

    add(const AuthSignOut());
  }

  // =============== SECURITY FIX: AUTH STATE SYNCHRONIZATION ===============

  /// Start periodic auth state synchronization timer
  void _startAuthStateSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = _clock.periodic(const Duration(minutes: 2), (_) {
      if (state is AuthAuthenticated) {
        _syncAuthState();
      }
    });
  }

  /// Synchronize auth state between AuthBloc and UserStateService
  Future<void> _syncAuthState() async {
    try {
      final currentUser = _userStateService.currentUser;
      final authUser = (state as AuthAuthenticated).user;

      // SECURITY FIX: Verify auth state consistency
      if (currentUser?.id != authUser.id) {
        AppLogger.warning('Auth state desync detected', category: LogCategory.auth, context: {
          'userStateServiceUser': currentUser?.id,
          'authBlocUser': authUser.id,
          'securityIssue': 'state_desync',
        });

        // Force status check to resync
        add(const AuthCheckStatus());
      }
    } catch (e) {
      AppLogger.warning('Auth state sync error', category: LogCategory.auth, context: {
        'error': e.toString(),
      });
    }
  }

  @override
  Future<void> close() {
    AppLogger.blocEvent('AuthBloc', 'closing', context: {
      'finalState': state.runtimeType.toString(),
    });
    _authSubscription.cancel();
    _syncTimer?.cancel();
    return super.close();
  }

  Future<void> _onInitialize(AuthInitialize event, Emitter<AuthState> emit) async {
    // FIXED: Prevent double initialization
    if (_isInitialized) {
      return;
    }

    AppLogger.blocEvent('AuthBloc', 'initialize_started', context: {
      'previousState': state.runtimeType.toString(),
    });

    emit(const AuthLoading());

    try {
      // Use the same method as _onCheckStatus to get user WITH initialization status
      // This ensures cold app starts query the database for tenant initialization
      final result = await _authUseCase.getCurrentUserWithInitStatus();

      result.fold(
            (failure) {
          _userStateService.clearUser();
          AppLogger.authError('Initialize failed', failure, context: {
            'failureType': failure.runtimeType.toString(),
            'fallbackAction': 'redirect_to_login',
          });
          emit(const AuthUnauthenticated());
        },
            (data) {
          if (data.isEmpty) {
            _userStateService.clearUser();
            AppLogger.authEvent('initialize_success', 'none', context: {
              'hasUser': false,
              'reason': 'no_session',
            });
            emit(const AuthUnauthenticated());
            return;
          }

          final user = data['user'] as UserEntity?;
          final tenantInitialized = data['tenantInitialized'] as bool? ?? true;

          if (user != null) {
            _userStateService.updateUser(user);
            AppLogger.authEvent('initialize_success', user.id, context: {
              'hasUser': true,
              'userName': user.fullName,
              'userEmail': user.email,
              'tenantInitialized': tenantInitialized,
              'userOnboarded': user.hasCompletedOnboarding,
            });
            emit(AuthAuthenticated(
              user,
              tenantInitialized: tenantInitialized, // FIXED: Query from database
              userOnboarded: user.hasCompletedOnboarding,
            ));
          } else {
            _userStateService.clearUser();
            AppLogger.authEvent('initialize_success', 'none', context: {
              'hasUser': false,
              'reason': 'user_null',
            });
            emit(const AuthUnauthenticated());
          }
        },
      );

      _isInitialized = true;
    } catch (e) {
      AppLogger.authError('Initialize exception', e, context: {
        'operation': 'initialize',
        'errorType': e.runtimeType.toString(),
      });
      _userStateService.clearUser();
      emit(const AuthUnauthenticated());
    }
  }

  // Replace the _onSignInGoogle method in auth_bloc.dart with this:

  // Replace the _onSignInGoogle method in auth_bloc.dart with this:

  Future<void> _onSignInGoogle(AuthSignInGoogle event, Emitter<AuthState> emit) async {
    if (_isOAuthInProgress) {
      AppLogger.warning('OAuth already in progress, ignoring duplicate request',
          category: LogCategory.auth,
          context: {
            'currentState': state.runtimeType.toString(),
            'duplicateAttempt': true,
          });
      return;
    }

    _isOAuthInProgress = true;

    try {
      emit(const AuthLoading());

      AppLogger.authEvent('google_signin_started', 'pending', context: {
        'method': 'google_oauth',
        'initiatedAt': DateTime.now().toIso8601String(),
      });

      final result = await _authUseCase.signInWithGoogle();

      result.fold(
            (failure) {

          // ✅ CRITICAL: Handle web OAuth redirect
          if (failure.message.contains('OAuth redirect in progress')) {

            AppLogger.info('Web OAuth redirect initiated', category: LogCategory.auth);

            // IMPORTANT: Do NOT emit anything else - stay in AuthLoading
            // The _listenToAuthChanges will handle the next step
            return;
          }

          // Handle other failures
          _userStateService.clearUser();

          String errorCategory = 'unknown';
          if (failure is UnauthorizedDomainFailure) {
            errorCategory = 'unauthorized_domain';
          } else if (failure is DeactivatedAccountFailure) {
            errorCategory = 'account_deactivated';
          } else if (failure is SessionExpiredFailure) {
            errorCategory = 'session_expired';
          } else if (failure.message.contains('network')) {
            errorCategory = 'network';
          }

          AppLogger.authError('Google sign-in failed', failure, context: {
            'failureType': failure.runtimeType.toString(),
            'errorCategory': errorCategory,
            'method': 'google_oauth',
          });

          emit(AuthError(failure.message));
        },
            (authResult) {
          // This path is for native platforms only
          // Web platforms will use the auth listener instead
          _userStateService.updateUser(authResult.user);

          AppLogger.authEvent('google_signin_success', authResult.user.id, context: {
            'isFirstLogin': authResult.isFirstLogin,
            'userName': authResult.user.fullName,
            'userEmail': authResult.user.email,
            'signInMethod': 'google',
            'completedAt': DateTime.now().toIso8601String(),
          });

          // For native platforms: emit authenticated state with user data
          // Tenant initialization status will be verified on app startup via router
          emit(AuthAuthenticated(
            authResult.user,
            isFirstLogin: authResult.isFirstLogin,
            tenantInitialized: false, // Router will verify this on next screen
            userOnboarded: authResult.user.hasCompletedOnboarding,
          ));
        },
      );
    } catch (e) {
      AppLogger.authError('Unexpected sign-in error', e, context: {
        'operation': 'google_signin',
        'errorType': e.runtimeType.toString(),
      });
      _userStateService.clearUser();
      emit(AuthError('Sign-in failed: ${e.toString()}'));
    } finally {
      _isOAuthInProgress = false;
    }
  }


  Future<void> _onSignOut(AuthSignOut event, Emitter<AuthState> emit) async {

    final currentUserId = state is AuthAuthenticated
        ? (state as AuthAuthenticated).user.id
        : 'unknown';

    AppLogger.authEvent('signout_started', currentUserId, context: {
      'signOutType': 'manual',
      'initiatedAt': DateTime.now().toIso8601String(),
    });

    _isSigningOut = true; // Prevent duplicate sign-out from auth listener

    try {
      emit(const AuthLoading());

      final result = await _authUseCase.signOut();

      // ALWAYS clear user state, regardless of result
      _userStateService.clearUser();

      result.fold(
            (failure) {
          AppLogger.authError('Sign out failed', failure, context: {
            'userId': currentUserId,
            'operation': 'signout',
            'failureType': failure.runtimeType.toString(),
          });
          emit(const AuthUnauthenticated());
        },
            (_) {
          AppLogger.authEvent('signout_success', currentUserId, context: {
            'completedAt': DateTime.now().toIso8601String(),
          });
          emit(const AuthUnauthenticated());
        },
      );
    } catch (e, stackTrace) {

      // CRITICAL FIX: Always clear user state even on exception
      _userStateService.clearUser();

      AppLogger.authError('Unhandled sign out error', e, context: {
        'userId': currentUserId,
        'operation': 'signout',
        'errorType': e.runtimeType.toString(),
      });

      emit(const AuthUnauthenticated());
    } finally {
      _isSigningOut = false; // Allow auth listener to process events again
    }

  }

  Future<void> _onCheckStatus(AuthCheckStatus event, Emitter<AuthState> emit) async {

    AppLogger.blocEvent('AuthBloc', 'check_status_started', context: {
      'currentState': state.runtimeType.toString(),
      'triggeredAt': DateTime.now().toIso8601String(),
    });

    try {
      // Use the new method to get user WITH initialization status
      final result = await _authUseCase.getCurrentUserWithInitStatus();

      result.fold(
            (failure) {

          _userStateService.clearUser();

          AppLogger.authError('Status check failed', failure, context: {
            'failureType': failure.runtimeType.toString(),
            'fallbackAction': 'clear_state_redirect_login',
          });

          emit(const AuthUnauthenticated());
        },
            (data) {

          if (data.isEmpty) {
            _userStateService.clearUser();

            AppLogger.authEvent('status_check_success', 'none', context: {
              'hasUser': false,
              'sessionValid': false,
              'reason': 'no_current_session',
            });

            emit(const AuthUnauthenticated());
            return;
          }

          final user = data['user'] as UserEntity?;
          final tenantInitialized = data['tenantInitialized'] as bool? ?? true;

          if (user != null) {

            _userStateService.updateUser(user);

            AppLogger.authEvent('status_check_success', user.id, context: {
              'hasUser': true,
              'userName': user.fullName,
              'sessionValid': true,
              'tenantInitialized': tenantInitialized,
              'userOnboarded': user.hasCompletedOnboarding,
            });

            emit(AuthAuthenticated(
              user,
              tenantInitialized: tenantInitialized,
              userOnboarded: user.hasCompletedOnboarding,
            ));
          } else {
            _userStateService.clearUser();

            AppLogger.authEvent('status_check_success', 'none', context: {
              'hasUser': false,
              'sessionValid': false,
              'reason': 'user_null',
            });

            emit(const AuthUnauthenticated());
          }
        },
      );

    } catch (e, stackTrace) {

      AppLogger.authError('Status check exception', e, context: {
        'operation': 'check_status',
        'errorType': e.runtimeType.toString(),
      });

      _userStateService.clearUser();
      emit(const AuthUnauthenticated());
    }
  }
}