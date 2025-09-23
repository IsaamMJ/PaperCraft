// features/authentication/domain2/services/user_state_service.dart
import 'package:flutter/foundation.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../entities/user_entity.dart';
import '../entities/user_role.dart';

/// Fast, in-memory user state service for managing authenticated user state
/// This is a domain2 service that tracks current user and provides permission logic
class UserStateService extends ChangeNotifier {
  final ILogger _logger;
  UserEntity? _currentUser;

  UserStateService(this._logger) {
    _logger.debug('UserStateService initialized', category: LogCategory.auth, context: {
      'serviceType': 'domain_service',
      'responsibilities': ['user_state', 'permissions'],
    });
  }

  /// Current authenticated user (null if not authenticated)
  UserEntity? get currentUser => _currentUser;

  /// Quick authentication check
  bool get isAuthenticated => _currentUser != null && _currentUser!.isValid;

  /// Quick role access
  UserRole get currentRole => _currentUser?.role ?? UserRole.blocked;

  /// Quick user ID access
  String? get currentUserId => _currentUser?.id;

  /// Quick tenant ID access
  String? get currentTenantId => _currentUser?.tenantId;

  /// Quick admin check
  bool get isAdmin => currentRole == UserRole.admin;

  /// Quick teacher check
  bool get isTeacher => currentRole == UserRole.teacher;

  /// Update user state (called from AuthBloc)
  void updateUser(UserEntity? user) {
    if (_currentUser != user) {
      final previousUserId = _currentUser?.id;
      _currentUser = user;

      _logger.debug('User state updated', category: LogCategory.auth, context: {
        'previousUserId': previousUserId,
        'newUserId': user?.id,
        'newUserRole': user?.role.value,
        'isAuthenticated': isAuthenticated,
        'operation': 'update_user_state',
      });

      notifyListeners();
    }
  }

  /// Clear user state (called on logout)
  void clearUser() {
    if (_currentUser != null) {
      final clearedUserId = _currentUser!.id;
      final clearedUserName = _currentUser!.fullName;

      _currentUser = null;

      _logger.debug('User state cleared', category: LogCategory.auth, context: {
        'clearedUserId': clearedUserId,
        'clearedUserName': clearedUserName,
        'isAuthenticated': false,
        'operation': 'clear_user_state',
      });

      notifyListeners();
    }
  }

  // =============== PERMISSION METHODS (DOMAIN BUSINESS LOGIC) ===============

  /// Can create question papers
  bool canCreatePapers() {
    if (!isAuthenticated) return false;
    return currentRole == UserRole.teacher || currentRole == UserRole.admin;
  }

  /// Can approve/reject question papers
  bool canApprovePapers() {
    if (!isAuthenticated) return false;
    return currentRole == UserRole.admin;
  }

  /// Can edit a specific paper (owner or admin)
  bool canEditPaper(String paperOwnerId) {
    if (!isAuthenticated || currentUserId == null) return false;
    return paperOwnerId == currentUserId || currentRole == UserRole.admin;
  }

  /// Can delete a specific paper (owner or admin)
  bool canDeletePaper(String paperOwnerId) {
    if (!isAuthenticated || currentUserId == null) return false;
    return paperOwnerId == currentUserId || currentRole == UserRole.admin;
  }

  /// Can view all papers in tenant (admin only)
  bool canViewAllPapers() {
    if (!isAuthenticated) return false;
    return currentRole == UserRole.admin;
  }

  /// Can manage users and system settings
  bool canManageUsers() {
    if (!isAuthenticated) return false;
    return currentRole == UserRole.admin;
  }

  /// Can view submitted papers for review
  bool canViewPapersForReview() {
    if (!isAuthenticated) return false;
    return currentRole == UserRole.admin;
  }

  /// Can pull rejected papers back to edit
  bool canPullForEditing(String paperOwnerId) {
    if (!isAuthenticated || currentUserId == null) return false;
    return paperOwnerId == currentUserId || currentRole == UserRole.admin;
  }

  /// Can access admin dashboard
  bool canAccessAdminDashboard() {
    if (!isAuthenticated) return false;
    return currentRole == UserRole.admin;
  }

  /// Can access teacher dashboard
  bool canAccessTeacherDashboard() {
    if (!isAuthenticated) return false;
    return currentRole == UserRole.teacher || currentRole == UserRole.admin;
  }

  // =============== VALIDATION METHODS ===============

  /// Validate user permissions for a specific action
  PermissionResult validatePermission(PermissionType type, {String? paperOwnerId}) {
    if (!isAuthenticated) {
      _logger.warning('Permission denied - user not authenticated', category: LogCategory.auth, context: {
        'permissionType': type.name,
        'reason': 'not_authenticated',
      });
      return PermissionResult.denied('User not authenticated');
    }

    switch (type) {
      case PermissionType.createPaper:
        final canCreate = canCreatePapers();
        if (!canCreate) {
          _logger.warning('Permission denied - cannot create papers', category: LogCategory.auth, context: {
            'userId': currentUserId,
            'userRole': currentRole.value,
            'permissionType': type.name,
          });
        }
        return canCreate
            ? PermissionResult.granted()
            : PermissionResult.denied('Only teachers and admins can create papers');

      case PermissionType.approvePaper:
        final canApprove = canApprovePapers();
        if (!canApprove) {
          _logger.warning('Permission denied - cannot approve papers', category: LogCategory.auth, context: {
            'userId': currentUserId,
            'userRole': currentRole.value,
            'permissionType': type.name,
          });
        }
        return canApprove
            ? PermissionResult.granted()
            : PermissionResult.denied('Only admins can approve papers');

      case PermissionType.editPaper:
        if (paperOwnerId == null) {
          return PermissionResult.denied('Missing paper owner information');
        }
        final canEdit = canEditPaper(paperOwnerId);
        if (!canEdit) {
          _logger.warning('Permission denied - cannot edit paper', category: LogCategory.auth, context: {
            'userId': currentUserId,
            'userRole': currentRole.value,
            'paperOwnerId': paperOwnerId,
            'permissionType': type.name,
          });
        }
        return canEdit
            ? PermissionResult.granted()
            : PermissionResult.denied('You can only edit your own papers');

      case PermissionType.deletePaper:
        if (paperOwnerId == null) {
          return PermissionResult.denied('Missing paper owner information');
        }
        final canDelete = canDeletePaper(paperOwnerId);
        if (!canDelete) {
          _logger.warning('Permission denied - cannot delete paper', category: LogCategory.auth, context: {
            'userId': currentUserId,
            'userRole': currentRole.value,
            'paperOwnerId': paperOwnerId,
            'permissionType': type.name,
          });
        }
        return canDelete
            ? PermissionResult.granted()
            : PermissionResult.denied('You can only delete your own papers');

      case PermissionType.viewAllPapers:
        final canViewAll = canViewAllPapers();
        if (!canViewAll) {
          _logger.warning('Permission denied - cannot view all papers', category: LogCategory.auth, context: {
            'userId': currentUserId,
            'userRole': currentRole.value,
            'permissionType': type.name,
          });
        }
        return canViewAll
            ? PermissionResult.granted()
            : PermissionResult.denied('Admin access required');

      case PermissionType.manageUsers:
        final canManage = canManageUsers();
        if (!canManage) {
          _logger.warning('Permission denied - cannot manage users', category: LogCategory.auth, context: {
            'userId': currentUserId,
            'userRole': currentRole.value,
            'permissionType': type.name,
          });
        }
        return canManage
            ? PermissionResult.granted()
            : PermissionResult.denied('Admin access required');
    }
  }

  // =============== UTILITY METHODS ===============

  /// Get complete user information for debugging (JSON-safe)
  Map<String, dynamic> getUserInfo() {
    if (!isAuthenticated) {
      return {
        'is_authenticated': false,
        'error': 'No user authenticated',
      };
    }

    final user = _currentUser!;
    return {
      'user_id': user.id,
      'tenant_id': user.tenantId,
      'user_role': user.role.value,
      'role_display_name': user.role.displayName,
      'full_name': user.fullName,
      'email': user.email,
      'is_active': user.isActive,
      'is_authenticated': true,
      'permissions': {
        'can_create_papers': canCreatePapers(),
        'can_approve_papers': canApprovePapers(),
        'can_view_all_papers': canViewAllPapers(),
        'can_manage_users': canManageUsers(),
        'can_access_admin_dashboard': canAccessAdminDashboard(),
        'can_access_teacher_dashboard': canAccessTeacherDashboard(),
      }
    };
  }

  /// Debug method to print user info (safe for logging)
  void debugUserInfo() {
    final info = getUserInfo();
    _logger.debug('UserStateService debug info', category: LogCategory.auth, context: info);
  }

  /// Get user info as JSON-safe string for logging
  String getUserInfoForLogging() {
    try {
      final info = getUserInfo();
      return info.toString();
    } catch (e) {
      _logger.warning('Failed to get user info for logging', category: LogCategory.auth, context: {
        'error': e.toString(),
      });
      return 'Failed to get user info: $e';
    }
  }
}

// =============== DOMAIN VALUE OBJECTS ===============

/// Permission types for authorization - domain2 concept
enum PermissionType {
  createPaper,
  approvePaper,
  editPaper,
  deletePaper,
  viewAllPapers,
  manageUsers,
}

/// Result of permission validation - domain2 value object
class PermissionResult {
  final bool isGranted;
  final String? message;

  const PermissionResult._(this.isGranted, this.message);

  factory PermissionResult.granted() => const PermissionResult._(true, null);
  factory PermissionResult.denied(String message) => PermissionResult._(false, message);

  bool get isDenied => !isGranted;

  Map<String, dynamic> toJson() => {
    'isGranted': isGranted,
    'message': message,
  };
}