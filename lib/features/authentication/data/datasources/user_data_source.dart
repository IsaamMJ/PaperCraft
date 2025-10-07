// features/authentication/data/datasources/user_data_source.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/user_role.dart';

abstract class UserDataSource {
  Future<List<UserEntity>> getTenantUsers(String tenantId);
  Future<UserEntity?> getUserById(String userId);
  Future<void> updateUserRole(String userId, UserRole role);
  Future<void> updateUserStatus(String userId, bool isActive);
}

class UserDataSourceImpl implements UserDataSource {
  final SupabaseClient _supabase;
  final ILogger _logger;

  UserDataSourceImpl(this._supabase, this._logger);

  @override
  Future<List<UserEntity>> getTenantUsers(String tenantId) async {
    try {
      _logger.debug('Fetching users for tenant',
          category: LogCategory.auth,
          context: {'tenantId': tenantId});

      final response = await _supabase
          .from('profiles')
          .select()
          .eq('tenant_id', tenantId)
          .eq('is_active', true)
          .order('full_name');

      _logger.info('Users fetched successfully',
          category: LogCategory.auth,
          context: {
            'tenantId': tenantId,
            'count': (response as List).length,
          });

      return (response as List)
          .map((json) => _parseUserEntity(json as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch tenant users',
          category: LogCategory.auth,
          error: e,
          stackTrace: stackTrace,
          context: {'tenantId': tenantId});
      rethrow;
    }
  }

  @override
  Future<UserEntity?> getUserById(String userId) async {
    try {
      _logger.debug('Fetching user by ID',
          category: LogCategory.auth,
          context: {'userId': userId});

      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        _logger.warning('User not found',
            category: LogCategory.auth,
            context: {'userId': userId});
        return null;
      }

      return _parseUserEntity(response as Map<String, dynamic>);
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch user by ID',
          category: LogCategory.auth,
          error: e,
          stackTrace: stackTrace,
          context: {'userId': userId});
      rethrow;
    }
  }

  @override
  Future<void> updateUserRole(String userId, UserRole role) async {
    try {
      _logger.info('Updating user role',
          category: LogCategory.auth,
          context: {
            'userId': userId,
            'newRole': role.value,
          });

      await _supabase
          .from('profiles')
          .update({'role': role.value})
          .eq('id', userId);

      _logger.info('User role updated successfully',
          category: LogCategory.auth,
          context: {'userId': userId});
    } catch (e, stackTrace) {
      _logger.error('Failed to update user role',
          category: LogCategory.auth,
          error: e,
          stackTrace: stackTrace,
          context: {'userId': userId});
      rethrow;
    }
  }

  @override
  Future<void> updateUserStatus(String userId, bool isActive) async {
    try {
      _logger.info('Updating user status',
          category: LogCategory.auth,
          context: {
            'userId': userId,
            'isActive': isActive,
          });

      await _supabase
          .from('profiles')
          .update({'is_active': isActive})
          .eq('id', userId);

      _logger.info('User status updated successfully',
          category: LogCategory.auth,
          context: {'userId': userId});
    } catch (e, stackTrace) {
      _logger.error('Failed to update user status',
          category: LogCategory.auth,
          error: e,
          stackTrace: stackTrace,
          context: {'userId': userId});
      rethrow;
    }
  }

  UserEntity _parseUserEntity(Map<String, dynamic> json) {
    return UserEntity(
      id: json['id'] as String,
      email: json['email'] as String? ?? '', // Add fallback for null email
      fullName: json['full_name'] as String,
      tenantId: json['tenant_id'] as String?,
      role: UserRole.fromString(json['role'] as String),
      isActive: json['is_active'] as bool? ?? true,
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.parse(json['last_login_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      // ✅ REMOVED updatedAt - not in UserEntity
    );
  }
}