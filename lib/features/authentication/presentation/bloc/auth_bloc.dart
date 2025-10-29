import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../../../core/domain/interfaces/i_auth_provider.dart';
import '../../../../core/domain/interfaces/i_clock.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../../core/infrastructure/logging/app_logger.dart';
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
        print('🔐 [AUTH LISTENER] === Auth state change ===');
        print('🔐 [AUTH LISTENER] Event: ${event.event}');
        print('🔐 [AUTH LISTENER] Has user: ${event.session?.user != null}');
        print('🔐 [AUTH LISTENER] User ID: ${event.session?.user?.id}');
        print('🔐 [AUTH LISTENER] Current bloc state: ${state.runtimeType}');
        print('🔐 [AUTH LISTENER] isClosed: $isClosed');

        try {
          AppLogger.authEvent('auth_state_changed', event.session?.user.id ?? 'unknown', context: {
            'event': event.event.name,
            'hasSession': event.session != null,
            'timestamp': _clock.now().toIso8601String(),
          });

          // ✅ Handle OAuth response for web
          if (event.event == AuthChangeEvent.signedIn && event.session?.user != null) {
            print('✅ [AUTH LISTENER] OAuth completed - user signed in');
            print('✅ [AUTH LISTENER] User ID: ${event.session!.user.id}');
            print('✅ [AUTH LISTENER] Current state before check: ${state.runtimeType}');

            // ✅ Always trigger AuthCheckStatus when OAuth completes
            // This handles both web and native platforms
            print('✅ [AUTH LISTENER] Will trigger AuthCheckStatus');

            // Use Future.microtask to ensure the BLoC is ready
            Future.microtask(() {
              if (!isClosed) {
                print('✅ [AUTH LISTENER] Adding AuthCheckStatus event');
                try {
                  add(const AuthCheckStatus());
                  print('✅ [AUTH LISTENER] AuthCheckStatus event added successfully');
                } catch (e) {
                  print('❌ [AUTH LISTENER] Error adding event: $e');
                }
              } else {
                print('❌ [AUTH LISTENER] BLoC is closed, cannot add event');
              }
            });
          }

          // Handle session expiry
          if (event.event == AuthChangeEvent.signedOut && state is AuthAuthenticated) {
            print('⚠️ [AUTH LISTENER] Session expired');
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
          print('❌ [AUTH LISTENER] Exception in listener: $e');
          print('📍 [AUTH LISTENER] Stack: $stackTrace');
          AppLogger.error(
            'Exception in auth listener',
            error: e,
            stackTrace: stackTrace,
            category: LogCategory.auth,
          );
        }
      },
      onError: (error, stackTrace) {
        print('❌ [AUTH LISTENER] Stream error: $error');
        print('📍 [AUTH LISTENER] Stack: $stackTrace');
        AppLogger.authError('Auth stream error', error, context: {
          'errorType': error.runtimeType.toString(),
          'stackTrace': stackTrace.toString(),
        });
      },
    );

    print('✅ [AUTH LISTENER] Auth state listener registered');
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
      print('🔥 DEBUG: AuthBloc already initialized, skipping');
      return;
    }

    print('🔥 DEBUG: _onInitialize method called');

    AppLogger.blocEvent('AuthBloc', 'initialize_started', context: {
      'previousState': state.runtimeType.toString(),
    });

    print('🔥 DEBUG: About to emit AuthLoading');
    emit(const AuthLoading());

    try {
      print('🔥 DEBUG: About to call _authUseCase.initialize()');
      final result = await _authUseCase.initialize();
      print('🔥 DEBUG: _authUseCase.initialize() completed');

      result.fold(
            (failure) {
          print('🔥 DEBUG: Initialize failed with: ${failure.runtimeType} - ${failure.message}');
          _userStateService.clearUser();
          AppLogger.authError('Initialize failed', failure, context: {
            'failureType': failure.runtimeType.toString(),
            'fallbackAction': 'redirect_to_login',
          });
          emit(const AuthUnauthenticated());
        },
            (user) {
          print('🔥 DEBUG: Initialize success, user: ${user?.id ?? 'null'}');
          if (user != null) {
            _userStateService.updateUser(user);
            AppLogger.authEvent('initialize_success', user.id, context: {
              'hasUser': true,
              'userName': user.fullName,
              'userEmail': user.email,
            });
            emit(AuthAuthenticated(user));
          } else {
            _userStateService.clearUser();
            AppLogger.authEvent('initialize_success', 'none', context: {
              'hasUser': false,
              'reason': 'no_session',
            });
            emit(const AuthUnauthenticated());
          }
        },
      );

      _isInitialized = true;
      print('🔥 DEBUG: _onInitialize method completed');
    } catch (e) {
      print('🔥 DEBUG: Initialize exception: $e');
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
    print('🔍 [SIGNIN] Starting Google Sign-In');
    print('🔍 [SIGNIN] Current state: ${state.runtimeType}');

    try {
      print('🔍 [SIGNIN] Emitting AuthLoading');
      emit(const AuthLoading());
      print('✅ [SIGNIN] AuthLoading emitted');

      AppLogger.authEvent('google_signin_started', 'pending', context: {
        'method': 'google_oauth',
        'initiatedAt': DateTime.now().toIso8601String(),
      });

      print('🔍 [SIGNIN] Calling signInWithGoogle()');
      final result = await _authUseCase.signInWithGoogle();
      print('🔍 [SIGNIN] signInWithGoogle() returned');

      result.fold(
            (failure) {
          print('🔍 [SIGNIN] Got failure: ${failure.message}');
          print('🔍 [SIGNIN] Failure type: ${failure.runtimeType}');

          // ✅ CRITICAL: Handle web OAuth redirect
          if (failure.message.contains('OAuth redirect in progress')) {
            print('✅ [SIGNIN] Web OAuth detected - STAYING IN AuthLoading');
            print('✅ [SIGNIN] The auth listener will trigger AuthCheckStatus when OAuth completes');

            AppLogger.info('Web OAuth redirect initiated', category: LogCategory.auth);

            // IMPORTANT: Do NOT emit anything else - stay in AuthLoading
            // The _listenToAuthChanges will handle the next step
            return;
          }

          // Handle other failures
          print('❌ [SIGNIN] Non-OAuth failure: ${failure.message}');
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

          print('❌ [SIGNIN] Emitting AuthError');
          emit(AuthError(failure.message));
        },
            (authResult) {
          // This path is for native platforms only
          // Web platforms will use the auth listener instead
          print('✅ [SIGNIN] OAuth successful (native path), user: ${authResult.user.id}');
          _userStateService.updateUser(authResult.user);

          AppLogger.authEvent('google_signin_success', authResult.user.id, context: {
            'isFirstLogin': authResult.isFirstLogin,
            'userName': authResult.user.fullName,
            'userEmail': authResult.user.email,
            'signInMethod': 'google',
            'completedAt': DateTime.now().toIso8601String(),
          });

          print('✅ [SIGNIN] Emitting AuthAuthenticated');
          emit(AuthAuthenticated(authResult.user, isFirstLogin: authResult.isFirstLogin));
        },
      );
    } catch (e) {
      print('❌ [SIGNIN] Exception: $e');
      AppLogger.authError('Unexpected sign-in error', e, context: {
        'operation': 'google_signin',
        'errorType': e.runtimeType.toString(),
      });
      _userStateService.clearUser();
      print('❌ [SIGNIN] Emitting AuthError');
      emit(AuthError('Sign-in failed: ${e.toString()}'));
    } finally {
      print('🔍 [SIGNIN] Finally block - resetting _isOAuthInProgress');
      _isOAuthInProgress = false;
    }
  }


  Future<void> _onSignOut(AuthSignOut event, Emitter<AuthState> emit) async {
    print('🔥 DEBUG: SignOut started');

    final currentUserId = state is AuthAuthenticated
        ? (state as AuthAuthenticated).user.id
        : 'unknown';

    AppLogger.authEvent('signout_started', currentUserId, context: {
      'signOutType': 'manual',
      'initiatedAt': DateTime.now().toIso8601String(),
    });

    emit(const AuthLoading());
    print('🔥 DEBUG: AuthLoading emitted');

    try {
      print('🔥 DEBUG: About to call _authUseCase.signOut()');
      final result = await _authUseCase.signOut();
      print('🔥 DEBUG: _authUseCase.signOut() completed with result: $result');

      // ALWAYS clear user state, regardless of result
      _userStateService.clearUser();
      print('🔥 DEBUG: UserStateService.clearUser() completed');

      result.fold(
            (failure) {
          print('🔥 DEBUG: SignOut failed: ${failure.message}');
          AppLogger.authError('Sign out failed', failure, context: {
            'userId': currentUserId,
            'operation': 'signout',
            'failureType': failure.runtimeType.toString(),
          });
          emit(const AuthUnauthenticated());
          print('🔥 DEBUG: AuthUnauthenticated emitted after failure');
        },
            (_) {
          print('🔥 DEBUG: SignOut success');
          AppLogger.authEvent('signout_success', currentUserId, context: {
            'completedAt': DateTime.now().toIso8601String(),
          });
          emit(const AuthUnauthenticated());
          print('🔥 DEBUG: AuthUnauthenticated emitted after success');
        },
      );
    } catch (e, stackTrace) {
      print('🔥 DEBUG: Unhandled exception in signOut: $e');
      print('🔥 DEBUG: StackTrace: $stackTrace');

      // CRITICAL FIX: Always clear user state even on exception
      _userStateService.clearUser();

      AppLogger.authError('Unhandled sign out error', e, context: {
        'userId': currentUserId,
        'operation': 'signout',
        'errorType': e.runtimeType.toString(),
      });

      emit(const AuthUnauthenticated());
      print('🔥 DEBUG: AuthUnauthenticated emitted after exception');
    }

    print('🔥 DEBUG: _onSignOut method completed');
  }

  Future<void> _onCheckStatus(AuthCheckStatus event, Emitter<AuthState> emit) async {
    print('🔐 [CHECK STATUS] === STARTED ===');
    print('🔐 [CHECK STATUS] Current state: ${state.runtimeType}');

    AppLogger.blocEvent('AuthBloc', 'check_status_started', context: {
      'currentState': state.runtimeType.toString(),
      'triggeredAt': DateTime.now().toIso8601String(),
    });

    try {
      print('🔐 [CHECK STATUS] Calling getCurrentUser()...');
      final result = await _authUseCase.getCurrentUser();

      print('🔐 [CHECK STATUS] getCurrentUser() returned');
      print('🔐 [CHECK STATUS] Result type: ${result.runtimeType}');

      result.fold(
            (failure) {
          print('❌ [CHECK STATUS] FAILURE: ${failure.runtimeType}');
          print('❌ [CHECK STATUS] Message: ${failure.message}');

          _userStateService.clearUser();

          AppLogger.authError('Status check failed', failure, context: {
            'failureType': failure.runtimeType.toString(),
            'fallbackAction': 'clear_state_redirect_login',
          });

          print('❌ [CHECK STATUS] Emitting AuthUnauthenticated');
          emit(const AuthUnauthenticated());
        },
            (user) {
          print('✅ [CHECK STATUS] SUCCESS: User returned');
          print('✅ [CHECK STATUS] User is null: ${user == null}');

          if (user != null) {
            print('✅ [CHECK STATUS] User is valid');
            print('✅ [CHECK STATUS] User ID: ${user.id}');
            print('✅ [CHECK STATUS] User Email: ${user.email}');
            print('✅ [CHECK STATUS] User Name: ${user.fullName}');

            _userStateService.updateUser(user);

            AppLogger.authEvent('status_check_success', user.id, context: {
              'hasUser': true,
              'userName': user.fullName,
              'sessionValid': true,
            });

            print('✅ [CHECK STATUS] Emitting AuthAuthenticated');
            print('✅ [CHECK STATUS] User: ${user.id}');
            emit(AuthAuthenticated(user));
            print('✅ [CHECK STATUS] AuthAuthenticated emitted successfully');
          } else {
            print('❌ [CHECK STATUS] User is null - no current session');
            _userStateService.clearUser();

            AppLogger.authEvent('status_check_success', 'none', context: {
              'hasUser': false,
              'sessionValid': false,
              'reason': 'no_current_session',
            });

            print('❌ [CHECK STATUS] Emitting AuthUnauthenticated');
            emit(const AuthUnauthenticated());
          }
        },
      );

      print('✅ [CHECK STATUS] === COMPLETED ===');
    } catch (e, stackTrace) {
      print('❌ [CHECK STATUS] EXCEPTION: $e');
      print('❌ [CHECK STATUS] Stack: $stackTrace');

      AppLogger.authError('Status check exception', e, context: {
        'operation': 'check_status',
        'errorType': e.runtimeType.toString(),
      });

      _userStateService.clearUser();
      print('❌ [CHECK STATUS] Emitting AuthUnauthenticated after exception');
      emit(const AuthUnauthenticated());
    }
  }
}