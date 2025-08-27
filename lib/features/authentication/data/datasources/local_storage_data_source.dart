import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/logger.dart';

abstract class LocalStorageDataSource {
  Future<void> saveUserData({
    required String tenantId,
    required String userId,
    String? fullName,
    required String role, // Now required
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
    required String role, // Now required
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save all required data
      await Future.wait([
        prefs.setString(_tenantIdKey, tenantId),
        prefs.setString(_userIdKey, userId),
        prefs.setString(_userRoleKey, role), // Always save role now
        if (fullName != null) prefs.setString(_fullNameKey, fullName),
      ]);

      // Verify the data was saved
      final savedRole = prefs.getString(_userRoleKey);
      final savedTenantId = prefs.getString(_tenantIdKey);

      LoggingService.debug('Saved user data to local storage:');
      LoggingService.debug('  - tenant_id: $tenantId (saved: $savedTenantId)');
      LoggingService.debug('  - user_id: $userId');
      LoggingService.debug('  - role: $role (saved: $savedRole)');
      LoggingService.debug('  - full_name: $fullName');

      // Double-check if role was actually saved
      if (savedRole != role) {
        LoggingService.error('WARNING: Role not properly saved! Expected: $role, Got: $savedRole');
      }
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
      final tenantId = prefs.getString(_tenantIdKey);
      LoggingService.debug('Retrieved tenant_id from storage: $tenantId');
      return tenantId;
    } catch (e) {
      LoggingService.error('Error getting tenant ID from local storage: $e');
      return null;
    }
  }

  @override
  Future<String?> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(_userIdKey);
      LoggingService.debug('Retrieved user_id from storage: $userId');
      return userId;
    } catch (e) {
      LoggingService.error('Error getting user ID from local storage: $e');
      return null;
    }
  }

  @override
  Future<String?> getFullName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fullName = prefs.getString(_fullNameKey);
      LoggingService.debug('Retrieved full_name from storage: $fullName');
      return fullName;
    } catch (e) {
      LoggingService.error('Error getting full name from local storage: $e');
      return null;
    }
  }

  @override
  Future<String?> getUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString(_userRoleKey);
      LoggingService.debug('Retrieved user_role from storage: $role');

      // Additional debug info
      final allKeys = prefs.getKeys();
      LoggingService.debug('All SharedPreferences keys: $allKeys');

      if (role == null) {
        LoggingService.error('WARNING: User role is null in SharedPreferences!');
        // Check if the key exists at all
        final hasKey = prefs.containsKey(_userRoleKey);
        LoggingService.debug('Role key exists: $hasKey');
      }

      return role;
    } catch (e) {
      LoggingService.error('Error getting user role from local storage: $e');
      return null;
    }
  }

  @override
  Future<bool> hasUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasTenant = prefs.containsKey(_tenantIdKey);
      final hasUser = prefs.containsKey(_userIdKey);
      final hasRole = prefs.containsKey(_userRoleKey);

      LoggingService.debug('SharedPreferences status:');
      LoggingService.debug('  - has tenant_id: $hasTenant');
      LoggingService.debug('  - has user_id: $hasUser');
      LoggingService.debug('  - has user_role: $hasRole');

      return hasTenant && hasUser && hasRole; // Now also check for role
    } catch (e) {
      LoggingService.error('Error checking user data existence: $e');
      return false;
    }
  }

  // Additional debug method
  Future<void> debugAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();

      LoggingService.debug('=== SharedPreferences Debug Info ===');
      LoggingService.debug('All keys: $allKeys');

      for (String key in allKeys) {
        final value = prefs.get(key);
        LoggingService.debug('  $key: $value (${value.runtimeType})');
      }
      LoggingService.debug('=====================================');
    } catch (e) {
      LoggingService.error('Error in debugAllData: $e');
    }
  }
}