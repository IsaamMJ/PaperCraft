// core/utils/platform_utils.dart
import 'package:flutter/foundation.dart';

/// Safe platform detection utilities
class PlatformUtils {
  PlatformUtils._();

  /// Get platform information safely without conditional imports
  static String get platformName {
    if (kIsWeb) return 'web';

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  /// Check if running on mobile platform
  static bool get isMobile {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Check if running on desktop platform
  static bool get isDesktop {
    return defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  /// Get platform context for logging
  static Map<String, dynamic> get platformContext {
    return {
      'platform': platformName,
      'isWeb': kIsWeb,
      'isMobile': isMobile,
      'isDesktop': isDesktop,
      'isDebugMode': kDebugMode,
      'isProfileMode': kProfileMode,
      'isReleaseMode': kReleaseMode,
    };
  }
}