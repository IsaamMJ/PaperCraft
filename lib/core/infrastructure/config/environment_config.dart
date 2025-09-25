import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'environment.dart';

class EnvironmentConfig {
  static late final Environment _current;
  static late final String _supabaseUrl;
  static late final String _supabaseAnonKey;

  // Public getters
  static Environment get current => _current;
  static String get supabaseUrl => _supabaseUrl;
  static String get supabaseAnonKey => _supabaseAnonKey;

  // Auth redirect URLs by environment
  static const String _authRedirectUrlDev = 'http://localhost:3000/auth/callback';
  static const String _authRedirectUrlStaging = 'https://staging-papercraft.your-domain2.com/auth/callback';
  static const String _authRedirectUrlProd = 'https://papercraft.your-domain2.com/auth/callback';

  // Helper to get auth redirect URL based on current environment
  // Helper to get auth redirect URL based on current environment
  static String get authRedirectUrl {
    switch (_current) {
      case Environment.dev:
        return kIsWeb
            ? 'http://localhost:3000/auth/callback'
            : 'com.pearl.papercraft.dev://login-callback/';
      case Environment.staging:
        return kIsWeb
            ? 'https://staging.papercraft.app/auth/callback'
            : 'com.pearl.papercraft.staging://login-callback/';
      case Environment.prod:
        return kIsWeb
            ? 'https://papercraft.app/auth/callback'
            : 'com.pearl.papercraft://login-callback/';
    }
  }

  /// Initialize environment configuration
  /// Dev: .env file → Production/Staging: dart-define only
  static Future<void> load() async {
    _loadEnvironment();
    await _loadConfiguration();
    _validateConfig();
    _logConfig();
  }

  /// Load and validate environment first
  static void _loadEnvironment() {
    final envString = const String.fromEnvironment('ENV', defaultValue: 'dev');
    _current = EnvironmentX.fromString(envString);
  }

  /// Load configuration based on environment
  static Future<void> _loadConfiguration() async {
    if (_current == Environment.dev) {
      await _loadDevConfiguration();
    } else {
      _loadProductionConfiguration();
    }
  }

  /// Load development configuration from .env file
  static Future<void> _loadDevConfiguration() async {
    bool envLoaded = false;

    // Only try to load .env on non-web platforms
    if (!kIsWeb) {
      try {
        await dotenv.load(fileName: ".env");
        envLoaded = true;
        if (kDebugMode) {
          debugPrint("✅ .env file loaded for development");
        }
      } catch (_) {
        if (kDebugMode) {
          debugPrint("⚠️ No .env file found - using dart-define values");
        }
      }
    } else {
      if (kDebugMode) {
        debugPrint("ℹ️ Web platform: Skipping .env file, using dart-define values");
      }
    }

    // In dev, try .env first (if loaded), then dart-define, allow empty for offline dev
    _supabaseUrl = (envLoaded ? dotenv.maybeGet('SUPABASE_URL') : null) ??
        const String.fromEnvironment('SUPABASE_URL', defaultValue: '');

    _supabaseAnonKey = (envLoaded ? dotenv.maybeGet('SUPABASE_KEY') : null) ??
        const String.fromEnvironment('SUPABASE_KEY', defaultValue: '');
  }

  /// Load production/staging configuration from dart-define only
  static void _loadProductionConfiguration() {
    _supabaseUrl = const String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    _supabaseAnonKey = const String.fromEnvironment('SUPABASE_KEY', defaultValue: '');
  }

  /// Validate required configuration
  static void _validateConfig() {
    final errors = <String>[];

    // FIXED: Always validate if any Supabase operations will be attempted
    final willUseSupabase = _supabaseUrl.isNotEmpty || _supabaseAnonKey.isNotEmpty;

    if (_current != Environment.dev && willUseSupabase) {
      // Production/staging must have valid config
      if (_supabaseUrl.isEmpty || !_isValidUrl(_supabaseUrl)) {
        errors.add('SUPABASE_URL is required and must be valid for ${_current.name}');
      }
      if (_supabaseAnonKey.isEmpty || _supabaseAnonKey.length < 20) {
        errors.add('SUPABASE_KEY is required and must be valid for ${_current.name}');
      }
    }

    // FIXED: In dev, warn but don't fail if config is missing
    if (_current == Environment.dev && !willUseSupabase) {
      debugPrint('⚠️ WARNING: Supabase config missing in dev mode. App will run in offline mode.');
      return; // Allow offline development
    }

    if (errors.isNotEmpty) {
      final errorMessage = 'Environment configuration validation failed:\n'
          '${errors.map((e) => '• $e').join('\n')}\n\n'
          'Environment: ${_current.name}\n'
          '${_getFixInstructions()}';
      throw StateError(errorMessage);
    }
  }

  /// Get environment-specific fix instructions
  static String _getFixInstructions() {
    if (_current == Environment.dev) {
      return 'For development:\n'
          '1. Create a .env file in your project root, or\n'
          '2. Use dart-define flags when running';
    } else {
      return 'For ${_current.name}:\n'
          'Use dart-define flags in your build command:\n'
          '--dart-define=SUPABASE_URL=your_url --dart-define=SUPABASE_KEY=your_key';
    }
  }

  /// Validate URL format
  static bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && uri.hasAuthority;
    } catch (_) {
      return false;
    }
  }

  /// Log configuration in debug mode
  static void _logConfig() {
    if (kDebugMode) {
      debugPrint('=== Environment Configuration ===');
      debugPrint('Environment: ${_current.name}');
      debugPrint('Config Source: ${_getConfigSource()}');
      debugPrint('Supabase URL: ${_maskUrl(_supabaseUrl)}');
      debugPrint('Supabase Key: ${_maskKey(_supabaseAnonKey)}');
      debugPrint('Auth Redirect: $authRedirectUrl');
      debugPrint('==================================');
    }
  }

  /// Get configuration source description
  static String _getConfigSource() {
    if (_current == Environment.dev) {
      return 'Local (.env file or dart-define)';
    } else {
      return 'Build-time (dart-define)';
    }
  }

  /// Mask URL for secure logging
  static String _maskUrl(String url) {
    if (url.isEmpty) return '[EMPTY]';
    if (url.length <= 20) return url;
    return '${url.substring(0, 20)}...';
  }

  /// Mask key for secure logging
  static String _maskKey(String key) {
    if (key.isEmpty) return '[EMPTY]';
    if (key.length <= 8) return '****';
    return '${key.substring(0, 8)}...****';
  }
}
