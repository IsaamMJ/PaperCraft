import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../feature_flags/feature_flags.dart';
import 'environment.dart';
import 'environment_config.dart';

class AuthConfig {
  static Duration get sessionTimeout {
    switch (EnvironmentConfig.current) {
      case Environment.dev:
        return const Duration(hours: 24); // Extended for development
      case Environment.staging:
        return const Duration(hours: 8);
      case Environment.prod:
        return const Duration(hours: 4);
    }
  }

  static Duration get oauthTimeout {
    switch (EnvironmentConfig.current) {
      case Environment.dev:
        return const Duration(seconds: 60); // Extended for development
      case Environment.staging:
      case Environment.prod:
        return const Duration(seconds: 30);
    }
  }

  static bool get enableDebugAuth => FeatureFlags.enableDebugLogging;

  static bool get enableExtendedLogging => FeatureFlags.enableDebugLogging;

  // Add OAuth launch mode configuration
  static LaunchMode get authLaunchMode => LaunchMode.externalApplication;

  static String get redirectUrl {
    final url = kIsWeb
        ? '${EnvironmentConfig.supabaseUrl}/auth/v1/callback'
        : _getNativeRedirectUrl();

    if (kDebugMode) {
    }
    return url;
  }

  static String get googleOAuthRedirectUrl {
    if (kIsWeb) {
      // For web, use production URL when deployed
      switch (EnvironmentConfig.current) {
        case Environment.dev:
          return 'http://localhost:3000/';  // Local development port
        case Environment.staging:
          return 'https://staging-papercraftweb.netlify.app/'; // adjust if you have staging
        case Environment.prod:
          return 'https://papercraftweb.netlify.app/';
      }
    } else {
      return _getNativeRedirectUrl();
    }
  }

  /// Get platform-specific redirect URL for native platforms
  static String _getNativeRedirectUrl() {
    switch (EnvironmentConfig.current) {
      case Environment.dev:
        return 'com.pearl.papercraft.dev://login-callback/';
      case Environment.staging:
        return 'com.pearl.papercraft.staging://login-callback/';
      case Environment.prod:
        return 'com.pearl.papercraft://login-callback/';
    }
  }

  // OAuth query parameters for better authentication flow
  static Map<String, String> get oauthQueryParams {
    return {
      'prompt': 'select_account', // Force account selection
      'access_type': 'offline',   // Get refresh token
    };
  }
}