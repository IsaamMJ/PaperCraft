// features/authentication/data/datasources/auth_data_source.dart
import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/error/auth_error_mapper.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/user_model.dart';

class AuthDataSource {
  final SupabaseClient _supabase;

  AuthDataSource(this._supabase);

  Future<UserModel?> initialize() async {
    AppLogger.info('AuthDataSource: Starting initialization');

    try {
      final session = _supabase.auth.currentSession;
      if (session?.user == null) {
        AppLogger.info('AuthDataSource: No current session found');
        await _clearAllAuthData();
        return null;
      }

      AppLogger.info('AuthDataSource: Current session found for user: ${session!.user.id}');
      final userModel = await _getUserProfile(session.user.id);

      if (userModel != null && userModel.isActive) {
        AppLogger.info('AuthDataSource: Active user profile found - ${userModel.fullName} (${userModel.role})');
        await _updateLastLogin(userModel.id);
        await _saveAuthData(userModel);
        AppLogger.info('AuthDataSource: Initialization completed successfully');
        return userModel;
      }

      if (userModel != null && !userModel.isActive) {
        AppLogger.error('AuthDataSource: User profile found but inactive - ${userModel.fullName} (${userModel.role})');
      } else {
        AppLogger.error('AuthDataSource: No user profile found for session user');
      }

      await _clearAllAuthData();
      return null;
    } catch (e) {
      AppLogger.error('AuthDataSource: Initialize failed', e);
      await _clearAllAuthData();
      return null;
    }
  }

  Future<UserModel> signInWithGoogle({required String redirectTo}) async {
    AppLogger.info('AuthDataSource: Starting Google OAuth sign-in');

    try {
      // Force logout first to clear any existing sessions
      await _forceGoogleLogout();

      AppLogger.info('AuthDataSource: Initiating OAuth flow with redirect: $redirectTo');

      final bool launched = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo,
        authScreenLaunchMode: LaunchMode.externalApplication,
        queryParams: {
          // Force Google to show account selection
          'prompt': 'select_account',
          // Clear any cached login hints
          'login_hint': '',
        },
      );

      if (!launched) {
        AppLogger.error('AuthDataSource: Failed to launch OAuth flow');
        throw AuthException('Failed to start OAuth flow');
      }

      AppLogger.info('AuthDataSource: OAuth flow launched, waiting for session...');

      // Wait for session with improved error handling
      final session = await _waitForSessionWithRetry();

      if (session?.user == null) {
        AppLogger.error('AuthDataSource: No session received after OAuth flow');
        throw AuthException('Authentication failed. Please try again or contact your administrator.');
      }

      AppLogger.info('AuthDataSource: OAuth session received for user: ${session!.user.id}');
      AppLogger.info('AuthDataSource: User email: ${session.user.email}');

      try {
        // Create or get user profile using our database function
        final userModel = await _createOrGetUserProfile(session.user);

        // Check user status and provide specific error messages
        if (!userModel.isActive) {
          AppLogger.error('AuthDataSource: User account is inactive - ${userModel.fullName} (${userModel.role}, tenant: ${userModel.tenantId})');
          await signOut(); // Use our comprehensive sign out

          if (userModel.role == 'blocked' && userModel.tenantId == null) {
            AppLogger.error('AuthDataSource: Organization not authorized');
            throw AuthException('Your organization (${_extractDomain(session.user.email)}) is not authorized to use this application. Please contact your school administrator.');
          } else if (userModel.role == 'blocked') {
            AppLogger.error('AuthDataSource: Account blocked');
            throw AuthException('Your account has been deactivated. Please contact your school administrator.');
          } else {
            AppLogger.error('AuthDataSource: Account inactive');
            throw AuthException('Your account is inactive. Please contact your school administrator.');
          }
        }

        AppLogger.info('AuthDataSource: User authenticated successfully - ${userModel.fullName} (${userModel.role})');
        await _updateLastLogin(userModel.id);
        await _saveAuthData(userModel);

        AppLogger.info('AuthDataSource: Google sign-in completed successfully');
        return userModel;
      } catch (e) {
        AppLogger.error('AuthDataSource: Error during profile handling', e);
        await signOut(); // Use our comprehensive sign out

        if (e is AuthException) {
          rethrow;
        }

        if (e.toString().contains('Profile creation failed')) {
          AppLogger.error('AuthDataSource: Profile creation failed - likely unauthorized domain');
          final domain = _extractDomain(session.user.email);
          throw AuthException('Your organization ($domain) is not authorized to use this application. Please contact your school administrator to add your domain.');
        }

        throw AuthException('Authentication failed. Please try again or contact your administrator.');
      }
    } on AuthException catch (e) {
      AppLogger.error('AuthDataSource: Authentication exception: ${e.message}');
      rethrow;
    } catch (e) {
      AppLogger.error('AuthDataSource: Unexpected error during Google sign-in', e);
      throw AuthException('Sign-in failed. Please try again.');
    }
  }

  // Comprehensive sign out that clears Google OAuth session
  Future<void> signOut() async {
    AppLogger.info('AuthDataSource: Starting comprehensive sign out');

    try {
      // Step 1: Clear local data first
      await _clearAllAuthData();
      AppLogger.info('AuthDataSource: Local auth data cleared');

      // Step 2: Sign out from Supabase with global scope
      await _supabase.auth.signOut(scope: SignOutScope.global);
      AppLogger.info('AuthDataSource: Supabase global sign out completed');

      // Step 3: Force Google logout
      await _forceGoogleLogout();
      AppLogger.info('AuthDataSource: Google logout completed');

      // Step 4: Verify sign out was successful
      if (_supabase.auth.currentUser != null) {
        AppLogger.error('AuthDataSource: User still present after sign out attempt');
        // Force clear the session
        await _supabase.auth.signOut(scope: SignOutScope.local);
      }

      AppLogger.info('AuthDataSource: Complete sign out successful');
    } catch (e) {
      AppLogger.error('AuthDataSource: Error during sign out', e);

      // Even if sign out fails, ensure local data is cleared
      try {
        await _clearAllAuthData();
      } catch (clearError) {
        AppLogger.error('AuthDataSource: Failed to clear local data during error recovery', clearError);
      }

      // Don't rethrow - we want logout to appear successful to user
      AppLogger.info('AuthDataSource: Sign out completed with errors (local data cleared)');
    }
  }

  // Force logout from Google OAuth
  Future<void> _forceGoogleLogout() async {
    try {
      AppLogger.info('AuthDataSource: Attempting to force Google logout');

      // Clear Google OAuth cookies by visiting logout URL
      final googleLogoutUrl = Uri.parse('https://accounts.google.com/logout');

      if (Platform.isAndroid || Platform.isIOS) {
        // On mobile, we can try to launch the logout URL
        if (await canLaunchUrl(googleLogoutUrl)) {
          await launchUrl(
            googleLogoutUrl,
            mode: LaunchMode.externalApplication,
          );
          // Give it a moment to process
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      AppLogger.info('AuthDataSource: Google logout attempt completed');
    } catch (e) {
      AppLogger.error('AuthDataSource: Could not force Google logout', e);
      // Don't rethrow - this is a best-effort operation
    }
  }

  Future<UserModel?> getCurrentUser() async {
    AppLogger.info('AuthDataSource: Getting current user');

    final user = _supabase.auth.currentUser;
    if (user == null) {
      AppLogger.info('AuthDataSource: No current user in Supabase auth');
      return null;
    }

    AppLogger.info('AuthDataSource: Current user found: ${user.id}');
    return await _getUserProfile(user.id);
  }

  bool get isAuthenticated => _supabase.auth.currentUser != null;

  // Enhanced session waiting with retry logic
  Future<Session?> _waitForSessionWithRetry() async {
    AppLogger.info('AuthDataSource: Waiting for OAuth session with retry logic');

    for (int attempt = 1; attempt <= 3; attempt++) {
      AppLogger.info('AuthDataSource: Session wait attempt $attempt/3');

      try {
        final session = await _waitForSingleSession();
        if (session != null) {
          AppLogger.info('AuthDataSource: Session received on attempt $attempt');
          return session;
        }
      } catch (e) {
        AppLogger.error('AuthDataSource: Session wait attempt $attempt failed', e);
        if (attempt == 3) rethrow;
      }

      if (attempt < 3) {
        AppLogger.info('AuthDataSource: Retrying session wait in 2 seconds...');
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    AppLogger.error('AuthDataSource: All session wait attempts failed');
    return null;
  }

  Future<Session?> _waitForSingleSession() async {
    final completer = Completer<Session?>();
    late StreamSubscription subscription;
    int eventCount = 0;

    subscription = _supabase.auth.onAuthStateChange.listen((data) {
      eventCount++;
      AppLogger.info('AuthDataSource: Auth state change #$eventCount - Event: ${data.event}');

      if (data.session?.user != null && !completer.isCompleted) {
        AppLogger.info('AuthDataSource: Valid session received');
        completer.complete(data.session);
        subscription.cancel();
      } else if (data.event == AuthChangeEvent.signedOut && !completer.isCompleted) {
        AppLogger.info('AuthDataSource: User signed out during OAuth flow');
        completer.complete(null);
        subscription.cancel();
      }
    });

    // Check current session first
    final currentSession = _supabase.auth.currentSession;
    if (currentSession?.user != null && !completer.isCompleted) {
      AppLogger.info('AuthDataSource: Using existing valid session');
      completer.complete(currentSession);
      subscription.cancel();
    }

    // 30 second timeout for single attempt
    Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        AppLogger.info('AuthDataSource: Session wait timed out after 30 seconds');
        subscription.cancel();
        completer.complete(null);
      }
    });

    return await completer.future;
  }

  // Enhanced profile creation with better error handling
  Future<UserModel> _createOrGetUserProfile(User user) async {
    AppLogger.info('AuthDataSource: Getting profile for user: ${user.id}');

    try {
      // Wait a moment for the trigger to complete
      await Future.delayed(const Duration(milliseconds: 500));

      final profile = await _getUserProfile(user.id);
      if (profile != null) {
        AppLogger.info('AuthDataSource: Profile found - ${profile.fullName} (${profile.role})');
        return profile;
      }

      // If no profile exists (shouldn't happen with trigger), throw error
      throw AuthException('Profile creation failed. Please contact your administrator.');
    } catch (e) {
      AppLogger.error('AuthDataSource: Error getting profile', e);
      rethrow;
    }
  }

  String _extractDomain(String? email) {
    if (email == null || !email.contains('@')) {
      return 'unknown domain';
    }
    return email.split('@')[1];
  }

  Future<UserModel?> _getUserProfile(String userId) async {
    AppLogger.info('AuthDataSource: Fetching user profile for: $userId');

    try {
      final data = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .maybeSingle();

      if (data == null) {
        AppLogger.info('AuthDataSource: No profile data found for user: $userId');
        return null;
      }

      final userModel = UserModel.fromDatabase(data);
      AppLogger.info('AuthDataSource: Profile fetched successfully - ${userModel.fullName} (${userModel.role})');
      return userModel;
    } catch (e) {
      AppLogger.error('AuthDataSource: Error fetching user profile for: $userId', e);
      return null;
    }
  }

  Future<void> _updateLastLogin(String userId) async {
    AppLogger.info('AuthDataSource: Updating last login timestamp for: $userId');

    try {
      await _supabase
          .from('profiles')
          .update({'last_login_at': DateTime.now().toIso8601String()})
          .eq('id', userId);
      AppLogger.info('AuthDataSource: Last login timestamp updated successfully');
    } catch (e) {
      AppLogger.error('AuthDataSource: Non-critical error updating last login', e);
    }
  }

  Future<void> _saveAuthData(UserModel user) async {
    AppLogger.info('AuthDataSource: Saving auth data to SharedPreferences for: ${user.fullName}');

    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setString('user_id', user.id),
        prefs.setString('tenant_id', user.tenantId ?? ''),
        prefs.setString('user_role', user.role),
        prefs.setString('full_name', user.fullName),
        prefs.setBool('can_create_papers', user.isActive && (user.role == 'admin' || user.role == 'teacher')),
      ]);
      AppLogger.info('AuthDataSource: Auth data saved to SharedPreferences successfully');
    } catch (e) {
      AppLogger.error('AuthDataSource: Non-critical error saving auth data', e);
    }
  }

  // Enhanced clear method that removes ALL auth-related data
  Future<void> _clearAllAuthData() async {
    AppLogger.info('AuthDataSource: Clearing all authentication data');

    try {
      final prefs = await SharedPreferences.getInstance();

      // Get all keys and find auth-related ones
      final keys = prefs.getKeys();
      final authKeys = keys.where((key) =>
      key.startsWith('user_') ||
          key.startsWith('auth_') ||
          key.startsWith('supabase_') ||
          key.startsWith('sb-') ||  // Supabase session keys
          key.contains('token') ||
          key.contains('session') ||
          key.contains('oauth') ||
          key == 'tenant_id' ||
          key == 'full_name' ||
          key == 'can_create_papers'
      ).toList();

      // Remove all auth-related keys
      for (final key in authKeys) {
        await prefs.remove(key);
        AppLogger.info('AuthDataSource: Cleared key: $key');
      }

      AppLogger.info('AuthDataSource: All authentication data cleared (${authKeys.length} keys)');
    } catch (e) {
      AppLogger.error('AuthDataSource: Error clearing auth data', e);
    }
  }

  // Legacy method for backward compatibility
  Future<void> _clearAuthData() async {
    await _clearAllAuthData();
  }
}