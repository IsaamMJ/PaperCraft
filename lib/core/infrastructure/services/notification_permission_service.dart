import 'package:flutter/services.dart';
import '../logging/app_logger.dart';
import '../../domain/interfaces/i_logger.dart';

/// Service for managing notification permissions on Android
class NotificationPermissionService {
  static const platform = MethodChannel('com.pearl.papercraft/notifications');

  final ILogger _logger;

  NotificationPermissionService(this._logger);

  /// Check if notification permission is granted (Android 13+)
  ///
  /// Returns true if permission is granted, false otherwise
  Future<bool> isNotificationPermissionGranted() async {
    try {
      final bool isGranted = await platform.invokeMethod<bool>(
        'isNotificationPermissionGranted',
      ) ?? false;

      return isGranted;
    } catch (e) {
      _logger.debug('Failed to check notification permission',
          category: LogCategory.system);
      return false;
    }
  }

  /// Request notification permission from user (Android 13+)
  ///
  /// Returns true if permission was granted, false if denied
  Future<bool> requestNotificationPermission() async {
    try {
      _logger.info('Requesting notification permission', category: LogCategory.system);

      final bool isGranted = await platform.invokeMethod<bool>(
        'requestNotificationPermission',
      ) ?? false;

      if (isGranted) {
        _logger.info('Notification permission granted', category: LogCategory.system);
      } else {
        _logger.warning('Notification permission denied', category: LogCategory.system);
      }

      return isGranted;
    } catch (e) {
      _logger.error('Failed to request notification permission',
          category: LogCategory.system,
          error: e);
      return false;
    }
  }

  /// Check and request notification permission if needed
  ///
  /// Returns true if permission is already granted or was granted by user
  Future<bool> ensureNotificationPermission() async {
    try {
      final isGranted = await isNotificationPermissionGranted();

      if (!isGranted) {
        _logger.info('Notification permission not granted, requesting...',
            category: LogCategory.system);
        return await requestNotificationPermission();
      }

      return true;
    } catch (e) {
      _logger.error('Failed to ensure notification permission',
          category: LogCategory.system,
          error: e);
      return false;
    }
  }
}
