import '../config/app_config.dart';

class AppLogger {
  static void info(String message) {
    if (AppConfig.isDebug) print('📱 $message');
  }

  static void error(String message, [Object? error]) {
    if (AppConfig.isDebug) {
      print('❌ $message');
      if (error != null) print('   Error: $error');
    }
  }
}
