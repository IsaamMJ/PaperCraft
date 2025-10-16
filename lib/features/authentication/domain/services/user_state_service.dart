// features/authentication/domain/services/user_state_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../entities/user_entity.dart';
import '../entities/user_role.dart';
import '../entities/tenant_entity.dart';
import '../usecases/auth_usecase.dart';
import '../usecases/get_tenant_usecase.dart';

/// Enhanced user state service with tenant management
class UserStateService extends ChangeNotifier {
  final ILogger _logger;
  UserEntity? _currentUser;
  TenantEntity? _currentTenant;


  /// Calculate current academic year based on current date
  /// Academic year starts in July
  String get currentAcademicYear {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;

    // Academic year starts in July (month 7)
    // If current month is July or later, academic year is current year to next year
    // Otherwise, academic year is previous year to current year
    if (month >= 7) {
      return '$year-${year + 1}';
    } else {
      return '${year - 1}-$year';
    }
  }

  // SECURITY FIX: Periodic permission refresh
  Timer? _permissionRefreshTimer;
  final Duration _permissionRefreshInterval = const Duration(minutes: 45);

  // Tenant loading state
  bool _isTenantLoading = false;
  String? _tenantLoadError;

  UserStateService(this._logger) {
    _logger.debug('UserStateService initialized', category: LogCategory.auth, context: {
      'serviceType': 'domain_service',
      'responsibilities': ['user_state', 'permissions', 'tenant_management'],
    });
    _startPermissionRefreshTimer();
  }

  bool _isRefreshing = false;

  // =============== USER STATE GETTERS ===============

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

  // =============== TENANT STATE GETTERS ===============

  /// Current tenant information
  TenantEntity? get currentTenant => _currentTenant;

  /// School/Tenant name for display purposes
  String get currentTenantName => _currentTenant?.displayName ?? 'School';

  /// School/Tenant name for PDF generation (fallback-safe)
  String get schoolName => _currentTenant?.displayName ?? 'School';

  /// Short school name for compact displays
  String get shortSchoolName => _currentTenant?.shortName ?? 'School';

  /// Check if tenant data is available
  bool get hasTenantData => _currentTenant != null;

  /// Check if tenant is currently being loaded
  bool get isTenantLoading => _isTenantLoading;

  /// Get tenant loading error (if any)
  String? get tenantLoadError => _tenantLoadError;

  // =============== USER STATE MANAGEMENT ===============

  /// Update user state and load tenant data
  void updateUser(UserEntity? user) async {
    if (_currentUser != user) {
      final previousUserId = _currentUser?.id;
      final previousTenantId = _currentUser?.tenantId;

      _currentUser = user;

      _logger.debug('User state updated', category: LogCategory.auth, context: {
        'previousUserId': previousUserId,
        'newUserId': user?.id,
        'newUserRole': user?.role.value,
        'newTenantId': user?.tenantId,
        'isAuthenticated': isAuthenticated,
        'operation': 'update_user_state',
      });

      // Load tenant data if user has a tenant ID and it changed
      if (user?.tenantId != null && user!.tenantId != previousTenantId) {
        await _loadTenantData(user.tenantId!);
      } else if (user?.tenantId == null) {
        // Clear tenant data if user has no tenant ID
        _clearTenantData();
      }

      notifyListeners();
    }
  }

  /// Clear user state and tenant data
  void clearUser() {
    if (_currentUser != null) {
      final clearedUserId = _currentUser!.id;
      final clearedUserName = _currentUser!.fullName;

      _currentUser = null;
      _clearTenantData();

      _logger.debug('User state cleared', category: LogCategory.auth, context: {
        'clearedUserId': clearedUserId,
        'clearedUserName': clearedUserName,
        'isAuthenticated': false,
        'operation': 'clear_user_state',
      });

      notifyListeners();
    }
  }

  // =============== TENANT DATA MANAGEMENT ===============

  /// Load tenant data by ID
  Future<void> _loadTenantData(String tenantId) async {
    if (_isTenantLoading) return; // Prevent concurrent loads

    _isTenantLoading = true;
    _tenantLoadError = null;
    notifyListeners();

    try {
      _logger.debug('Loading tenant data', category: LogCategory.auth, context: {
        'tenantId': tenantId,
        'userId': currentUserId,
        'operation': 'load_tenant',
      });

      final getTenantUseCase = sl<GetTenantUseCase>();
      final result = await getTenantUseCase(tenantId);

      result.fold(
            (failure) {
          _tenantLoadError = failure.message;
          _logger.warning('Failed to load tenant data', category: LogCategory.auth, context: {
            'tenantId': tenantId,
            'error': failure.message,
            'fallback': 'using_default_name',
          });
        },
            (tenant) {
          _currentTenant = tenant;

          if (tenant != null) {
            _logger.debug('Tenant data loaded successfully', category: LogCategory.auth, context: {
              'tenantId': tenantId,
              'tenantName': tenant.displayName,
              'isActive': tenant.isActive,
            });
          } else {
            _logger.warning('Tenant not found', category: LogCategory.auth, context: {
              'tenantId': tenantId,
              'reason': 'tenant_not_found',
            });
            _tenantLoadError = 'Tenant not found';
          }
        },
      );
    } catch (e, stackTrace) {
      _tenantLoadError = 'Failed to load tenant: ${e.toString()}';
      _logger.error('Exception loading tenant data',
        category: LogCategory.auth,
        error: e,
        stackTrace: stackTrace,
        context: {'tenantId': tenantId},
      );
    } finally {
      _isTenantLoading = false;
      notifyListeners();
    }
  }

  /// Clear tenant data
  void _clearTenantData() {
    if (_currentTenant != null) {
      final clearedTenantId = _currentTenant!.id;
      _currentTenant = null;
      _tenantLoadError = null;

      _logger.debug('Tenant data cleared', category: LogCategory.auth, context: {
        'clearedTenantId': clearedTenantId,
        'operation': 'clear_tenant_data',
      });
    }
  }

  /// Force reload tenant data
  Future<void> reloadTenantData() async {
    if (currentTenantId != null) {
      _currentTenant = null; // Clear existing data
      await _loadTenantData(currentTenantId!);
    }
  }

  // =============== PERIODIC REFRESH LOGIC ===============

  void _startPermissionRefreshTimer() {
    _permissionRefreshTimer?.cancel();
    _permissionRefreshTimer = Timer.periodic(_permissionRefreshInterval, (_) {
      if (isAuthenticated) {
        _refreshUserPermissions();
      }
    });
  }

  Future<void> _refreshUserPermissions() async {
    if (!isAuthenticated || currentUserId == null || _isRefreshing) return;

    _isRefreshing = true;

    try {
      _logger.debug('Refreshing user permissions', category: LogCategory.auth, context: {
        'userId': currentUserId,
        'currentRole': currentRole.value,
      });

      final authUseCase = sl<AuthUseCase>();
      final result = await authUseCase.getCurrentUser();

      result.fold(
            (failure) {
          _logger.warning('Permission refresh failed', category: LogCategory.auth, context: {
            'userId': currentUserId,
            'error': failure.message,
          });
        },
            (freshUser) {
          if (freshUser != null && freshUser.id == currentUserId) {
            final oldRole = currentRole;
            final newRole = freshUser.role;
            final oldTenantId = currentTenantId;
            final newTenantId = freshUser.tenantId;

            if (oldRole != newRole) {
              _logger.warning('User role changed, updating permissions', category: LogCategory.auth, context: {
                'userId': currentUserId,
                'oldRole': oldRole.value,
                'newRole': newRole.value,
                'securityUpdate': true,
              });
            }

            // Check if tenant changed
            if (oldTenantId != newTenantId) {
              _logger.info('User tenant changed', category: LogCategory.auth, context: {
                'userId': currentUserId,
                'oldTenantId': oldTenantId,
                'newTenantId': newTenantId,
                'requiresTenantReload': true,
              });
            }

            updateUser(freshUser);

            if (_currentUser!.isActive && !freshUser.isActive) {
              _logger.warning('User was deactivated, clearing state', category: LogCategory.auth, context: {
                'userId': currentUserId,
                'securityAction': 'account_deactivated',
              });
              clearUser();
            }
          } else if (freshUser == null) {
            _logger.warning('User no longer exists, clearing state', category: LogCategory.auth, context: {
              'userId': currentUserId,
              'securityAction': 'user_deleted',
            });
            clearUser();
          }
        },
      );
    } catch (e) {
      _logger.warning('Permission refresh exception', category: LogCategory.auth, context: {
        'userId': currentUserId,
        'error': e.toString(),
      });
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> forcePermissionRefresh() async {
    await _refreshUserPermissions();
  }

  // =============== PERMISSION METHODS (unchanged) ===============

  bool canCreatePapers() {
    if (!isAuthenticated) return false;
    return currentRole == UserRole.teacher || currentRole == UserRole.admin;
  }

  bool canApprovePapers() {
    if (!isAuthenticated) return false;
    return currentRole == UserRole.admin;
  }

  bool canEditPaper(String paperOwnerId) {
    if (!isAuthenticated || currentUserId == null) return false;
    return paperOwnerId == currentUserId || currentRole == UserRole.admin;
  }

  bool canDeletePaper(String paperOwnerId) {
    if (!isAuthenticated || currentUserId == null) return false;
    return paperOwnerId == currentUserId || currentRole == UserRole.admin;
  }

  bool canViewAllPapers() {
    if (!isAuthenticated) return false;
    return currentRole == UserRole.admin;
  }

  bool canManageUsers() {
    if (!isAuthenticated) return false;
    return currentRole == UserRole.admin;
  }

  bool canViewPapersForReview() {
    if (!isAuthenticated) return false;
    return currentRole == UserRole.admin;
  }

  bool canPullForEditing(String paperOwnerId) {
    if (!isAuthenticated || currentUserId == null) return false;
    return paperOwnerId == currentUserId || currentRole == UserRole.admin;
  }

  bool canAccessAdminDashboard() {
    if (!isAuthenticated) return false;
    return currentRole == UserRole.admin;
  }

  bool canAccessTeacherDashboard() {
    if (!isAuthenticated) return false;
    return currentRole == UserRole.teacher || currentRole == UserRole.admin;
  }

  // =============== VALIDATION METHODS (unchanged) ===============

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
      'tenant_info': {
        'has_tenant_data': hasTenantData,
        'tenant_name': currentTenantName,
        'is_tenant_loading': isTenantLoading,
        'tenant_load_error': tenantLoadError,
      },
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

  void debugUserInfo() {
    final info = getUserInfo();
    _logger.debug('UserStateService debug info', category: LogCategory.auth, context: info);
  }

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

  @override
  void dispose() {
    _permissionRefreshTimer?.cancel();
    super.dispose();
  }
}

// =============== DOMAIN VALUE OBJECTS (unchanged) ===============

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

  Map<String, dynamic> toJson() => {
    'isGranted': isGranted,
    'message': message,
  };
}