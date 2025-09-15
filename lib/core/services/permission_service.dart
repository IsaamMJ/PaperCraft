// core/services/permission_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

enum UserRole {
  admin,
  teacher,
  student,
  user,
  blocked;

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'teacher':
        return UserRole.teacher;
      case 'student':
        return UserRole.student;
      case 'user':
        return UserRole.user;
      case 'blocked':
        return UserRole.blocked;
      default:
        return UserRole.blocked;
    }
  }

  String get value {
    switch (this) {
      case UserRole.admin:
        return 'admin';
      case UserRole.teacher:
        return 'teacher';
      case UserRole.student:
        return 'student';
      case UserRole.user:
        return 'user';
      case UserRole.blocked:
        return 'blocked';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.teacher:
        return 'Teacher';
      case UserRole.student:
        return 'Student';
      case UserRole.user:
        return 'User';
      case UserRole.blocked:
        return 'Blocked';
    }
  }
}

class PermissionService {
  // SharedPreferences keys - consistent with authentication module
  static const String _userRoleKey = 'user_role';
  static const String _userIdKey = 'user_id';
  static const String _tenantIdKey = 'tenant_id';
  static const String _fullNameKey = 'full_name';
  static const String _emailKey = 'email';
  static const String _isActiveKey = 'is_active';

  // =============== CORE PERMISSION LOGIC (ROLE-BASED) ===============

  /// Can create question papers
  static bool canCreatePapers(UserRole role) => role == UserRole.teacher || role == UserRole.admin;

  /// Can approve/reject question papers
  static bool canApprovePapers(UserRole role) => role == UserRole.admin;

  /// Can edit a specific paper (owner or admin)
  static bool canEditPaper(String paperOwnerId, String currentUserId, UserRole role) {
    return paperOwnerId == currentUserId || role == UserRole.admin;
  }

  /// Can delete a specific paper (owner or admin)
  static bool canDeletePaper(String paperOwnerId, String currentUserId, UserRole role) {
    return paperOwnerId == currentUserId || role == UserRole.admin;
  }

  /// Can view all papers in tenant (admin only)
  static bool canViewAllPapers(UserRole role) => role == UserRole.admin;

  /// Can manage users and system settings
  static bool canManageUsers(UserRole role) => role == UserRole.admin;

  /// Can view submitted papers for review
  static bool canViewPapersForReview(UserRole role) => role == UserRole.admin;

  /// Can pull rejected papers back to edit
  static bool canPullForEditing(String paperOwnerId, String currentUserId, UserRole role) {
    return paperOwnerId == currentUserId || role == UserRole.admin;
  }

  /// Can access admin dashboard
  static bool canAccessAdminDashboard(UserRole role) => role == UserRole.admin;

  /// Can access teacher dashboard
  static bool canAccessTeacherDashboard(UserRole role) =>
      role == UserRole.teacher || role == UserRole.admin;

  // =============== SHAREDPREFERENCES GETTERS ===============

  /// Get current user role from SharedPreferences
  static Future<UserRole> getCurrentUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString(_userRoleKey);
      if (role == null || role.isEmpty) {
        debugPrint('Warning: User role not found in SharedPreferences');
        return UserRole.blocked; // Safe default
      }
      return UserRole.fromString(role);
    } catch (e) {
      debugPrint('Error getting user role: $e');
      return UserRole.blocked; // Safe default
    }
  }

  /// Get current user ID from SharedPreferences
  static Future<String?> getCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(_userIdKey);
      if (userId == null || userId.isEmpty) {
        debugPrint('Warning: User ID not found in SharedPreferences');
      }
      return userId;
    } catch (e) {
      debugPrint('Error getting user ID: $e');
      return null;
    }
  }

  /// Get current tenant ID from SharedPreferences
  static Future<String?> getCurrentTenantId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tenantId = prefs.getString(_tenantIdKey);
      if (tenantId == null || tenantId.isEmpty) {
        debugPrint('Warning: Tenant ID not found in SharedPreferences');
      }
      return tenantId;
    } catch (e) {
      debugPrint('Error getting tenant ID: $e');
      return null;
    }
  }

  /// Get current user name from SharedPreferences
  static Future<String?> getCurrentUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_fullNameKey);
    } catch (e) {
      debugPrint('Error getting user name: $e');
      return null;
    }
  }

  /// Get current user email from SharedPreferences
  static Future<String?> getCurrentUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_emailKey);
    } catch (e) {
      debugPrint('Error getting user email: $e');
      return null;
    }
  }

  /// Check if user is active
  static Future<bool> isCurrentUserActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_isActiveKey) ?? false;
    } catch (e) {
      debugPrint('Error checking user active status: $e');
      return false;
    }
  }

  // =============== CONVENIENCE METHODS ===============

  /// Check if current user can create papers
  static Future<bool> currentUserCanCreatePapers() async {
    final role = await getCurrentUserRole();
    return canCreatePapers(role);
  }

  /// Check if current user can approve papers
  static Future<bool> currentUserCanApprovePapers() async {
    final role = await getCurrentUserRole();
    return canApprovePapers(role);
  }

  /// Check if current user can edit a specific paper
  static Future<bool> currentUserCanEditPaper(String paperOwnerId) async {
    final role = await getCurrentUserRole();
    final currentUserId = await getCurrentUserId();
    if (currentUserId == null) return false;
    return canEditPaper(paperOwnerId, currentUserId, role);
  }

  /// Check if current user can delete a specific paper
  static Future<bool> currentUserCanDeletePaper(String paperOwnerId) async {
    final role = await getCurrentUserRole();
    final currentUserId = await getCurrentUserId();
    if (currentUserId == null) return false;
    return canDeletePaper(paperOwnerId, currentUserId, role);
  }

  /// Check if current user can pull paper for editing
  static Future<bool> currentUserCanPullForEditing(String paperOwnerId) async {
    final role = await getCurrentUserRole();
    final currentUserId = await getCurrentUserId();
    if (currentUserId == null) return false;
    return canPullForEditing(paperOwnerId, currentUserId, role);
  }

  /// Check if current user can access admin features
  static Future<bool> currentUserIsAdmin() async {
    final role = await getCurrentUserRole();
    return role == UserRole.admin;
  }

  /// Check if current user can access teacher features
  static Future<bool> currentUserIsTeacherOrAdmin() async {
    final role = await getCurrentUserRole();
    return role == UserRole.teacher || role == UserRole.admin;
  }

  // =============== AUTHENTICATION VALIDATION ===============

  /// Check if user is properly authenticated
  static Future<bool> isAuthenticated() async {
    try {
      final userId = await getCurrentUserId();
      final tenantId = await getCurrentTenantId();
      final role = await getCurrentUserRole();

      // Fixed: Don't require is_active if it's not set by auth module
      // Focus on the essential fields that indicate proper authentication
      return userId != null &&
          userId.isNotEmpty &&
          tenantId != null &&
          tenantId.isNotEmpty &&
          role != UserRole.blocked;

    } catch (e) {
      debugPrint('Error checking authentication: $e');
      return false;
    }
  }

  /// Get complete user information
  static Future<Map<String, dynamic>> getCurrentUserInfo() async {
    try {
      final role = await getCurrentUserRole();

      return {
        'user_id': await getCurrentUserId(),
        'tenant_id': await getCurrentTenantId(),
        'user_role': role.value,
        'role_display_name': role.displayName,
        'full_name': await getCurrentUserName(),
        'email': await getCurrentUserEmail(),
        'is_active': await isCurrentUserActive(),
        'is_authenticated': await isAuthenticated(),
        'permissions': {
          'can_create_papers': canCreatePapers(role),
          'can_approve_papers': canApprovePapers(role),
          'can_view_all_papers': canViewAllPapers(role),
          'can_manage_users': canManageUsers(role),
          'can_access_admin_dashboard': canAccessAdminDashboard(role),
          'can_access_teacher_dashboard': canAccessTeacherDashboard(role),
        }
      };
    } catch (e) {
      debugPrint('Error getting user info: $e');
      return {
        'error': 'Failed to load user information',
        'is_authenticated': false,
      };
    }
  }

  // =============== UTILITY METHODS ===============

  /// Clear all user data from SharedPreferences (logout)
  static Future<void> clearUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userIdKey);
      await prefs.remove(_tenantIdKey);
      await prefs.remove(_userRoleKey);
      await prefs.remove(_fullNameKey);
      await prefs.remove(_emailKey);
      await prefs.remove(_isActiveKey);
      debugPrint('User data cleared from SharedPreferences');
    } catch (e) {
      debugPrint('Error clearing user data: $e');
    }
  }

  /// Debug method to print all user data
  static Future<void> debugUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userInfo = await getCurrentUserInfo();

      debugPrint('=== PermissionService Debug ===');
      debugPrint('SharedPreferences keys: ${prefs.getKeys()}');
      debugPrint('user_id: ${prefs.getString(_userIdKey)}');
      debugPrint('tenant_id: ${prefs.getString(_tenantIdKey)}');
      debugPrint('user_role: ${prefs.getString(_userRoleKey)}');
      debugPrint('full_name: ${prefs.getString(_fullNameKey)}');
      debugPrint('email: ${prefs.getString(_emailKey)}');
      debugPrint('is_active: ${prefs.getBool(_isActiveKey)}');
      debugPrint('User info: $userInfo');
      debugPrint('Is authenticated: ${await isAuthenticated()}');
      debugPrint('==============================');
    } catch (e) {
      debugPrint('Error in debugUserData: $e');
    }
  }

  /// Validate user permissions for a specific action
  static Future<PermissionResult> validatePermission(PermissionType type, {
    String? targetUserId,
    String? paperOwnerId,
  }) async {
    try {
      if (!await isAuthenticated()) {
        return PermissionResult.denied('User not authenticated');
      }

      final role = await getCurrentUserRole();
      final currentUserId = await getCurrentUserId();

      switch (type) {
        case PermissionType.createPaper:
          return canCreatePapers(role)
              ? PermissionResult.granted()
              : PermissionResult.denied('Only teachers and admins can create papers');

        case PermissionType.approvePaper:
          return canApprovePapers(role)
              ? PermissionResult.granted()
              : PermissionResult.denied('Only admins can approve papers');

        case PermissionType.editPaper:
          if (paperOwnerId == null || currentUserId == null) {
            return PermissionResult.denied('Missing required information');
          }
          return canEditPaper(paperOwnerId, currentUserId, role)
              ? PermissionResult.granted()
              : PermissionResult.denied('You can only edit your own papers');

        case PermissionType.deletePaper:
          if (paperOwnerId == null || currentUserId == null) {
            return PermissionResult.denied('Missing required information');
          }
          return canDeletePaper(paperOwnerId, currentUserId, role)
              ? PermissionResult.granted()
              : PermissionResult.denied('You can only delete your own papers');

        case PermissionType.viewAllPapers:
          return canViewAllPapers(role)
              ? PermissionResult.granted()
              : PermissionResult.denied('Admin access required');

        case PermissionType.manageUsers:
          return canManageUsers(role)
              ? PermissionResult.granted()
              : PermissionResult.denied('Admin access required');
      }
    } catch (e) {
      debugPrint('Error validating permission: $e');
      return PermissionResult.denied('Permission check failed');
    }
  }
}

// =============== SUPPORTING CLASSES ===============

enum PermissionType {
  createPaper,
  approvePaper,
  editPaper,
  deletePaper,
  viewAllPapers,
  manageUsers,
}

class PermissionResult {
  final bool isGranted;
  final String? message;

  const PermissionResult._(this.isGranted, this.message);

  factory PermissionResult.granted() => const PermissionResult._(true, null);
  factory PermissionResult.denied(String message) => PermissionResult._(false, message);

  bool get isDenied => !isGranted;
}