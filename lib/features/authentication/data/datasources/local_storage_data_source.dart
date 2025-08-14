import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/logger.dart';

abstract class LocalStorageDataSource {
  Future<void> saveUserData({
    required String tenantId,
    required String userId,
    String? fullName,
    String? role,
  });

  Future<void> clearUserData();
  Future<String?> getTenantId();
  Future<String?> getUserId();
  Future<String?> getFullName();
  Future<String?> getUserRole();
  Future<bool> hasUserData();
}

class LocalStorageDataSourceImpl implements LocalStorageDataSource {
  static const String _tenantIdKey = 'tenant_id';
  static const String _userIdKey = 'user_id';
  static const String _fullNameKey = 'full_name';
  static const String _userRoleKey = 'user_role';

  @override
  Future<void> saveUserData({
    required String tenantId,
    required String userId,
    String? fullName,
    String? role,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(_tenantIdKey, tenantId);
      await prefs.setString(_userIdKey, userId);

      if (fullName != null) {
        await prefs.setString(_fullNameKey, fullName);
      }

      if (role != null) {
        await prefs.setString(_userRoleKey, role);
      }

      LoggingService.debug('Saved user data to local storage - tenant_id: $tenantId, user_id: $userId');
    } catch (e) {
      LoggingService.error('Error saving user data to local storage: $e');
      rethrow;
    }
  }

  @override
  Future<void> clearUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await Future.wait([
        prefs.remove(_tenantIdKey),
        prefs.remove(_userIdKey),
        prefs.remove(_fullNameKey),
        prefs.remove(_userRoleKey),
      ]);

      LoggingService.debug('Cleared user data from local storage');
    } catch (e) {
      LoggingService.error('Error clearing local storage: $e');
      rethrow;
    }
  }

  @override
  Future<String?> getTenantId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tenantIdKey);
    } catch (e) {
      LoggingService.error('Error getting tenant ID from local storage: $e');
      return null;
    }
  }

  @override
  Future<String?> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userIdKey);
    } catch (e) {
      LoggingService.error('Error getting user ID from local storage: $e');
      return null;
    }
  }

  @override
  Future<String?> getFullName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_fullNameKey);
    } catch (e) {
      LoggingService.error('Error getting full name from local storage: $e');
      return null;
    }
  }

  @override
  Future<String?> getUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userRoleKey);
    } catch (e) {
      LoggingService.error('Error getting user role from local storage: $e');
      return null;
    }
  }

  @override
  Future<bool> hasUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_tenantIdKey) && prefs.containsKey(_userIdKey);
    } catch (e) {
      LoggingService.error('Error checking user data existence: $e');
      return false;
    }
  }
}