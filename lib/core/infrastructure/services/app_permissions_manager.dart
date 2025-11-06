import 'notification_permission_service.dart';
import '../logging/app_logger.dart';
import '../../domain/interfaces/i_logger.dart';

/// Manages all app-level permissions
class AppPermissionsManager {
  final ILogger _logger;
  final NotificationPermissionService _notificationService;

  AppPermissionsManager(
    this._logger,
    this._notificationService,
  );

  /// Initialize all permissions on app startup
  Future<void> initializePermissions() async {
    _logger.info('Initializing app permissions', category: LogCategory.system);

    try {
      // Request notification permission
      await _requestNotificationPermission();
    } catch (e) {
      _logger.error('Error during permissions initialization',
          category: LogCategory.system,
          error: e);
    }
  }

  /// Request notification permission from user
  Future<void> _requestNotificationPermission() async {
    try {
      final isGranted = await _notificationService.ensureNotificationPermission();

      if (isGranted) {
        _logger.info('Notification permission acquired',
            category: LogCategory.system);
      } else {
        _logger.warning('Notification permission denied by user',
            category: LogCategory.system);
      }
    } catch (e) {
      _logger.error('Failed to request notification permission',
          category: LogCategory.system,
          error: e);
    }
  }
}
