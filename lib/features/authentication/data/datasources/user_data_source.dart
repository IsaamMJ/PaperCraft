// features/authentication/data/datasources/user_data_source.dart
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../../core/infrastructure/network/api_client.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/user_role.dart';
import '../models/user_model.dart';

abstract class UserDataSource {
  Future<List<UserEntity>> getTenantUsers(String tenantId);
  Future<UserEntity?> getUserById(String userId);
  Future<void> updateUserRole(String userId, UserRole role);
  Future<void> updateUserStatus(String userId, bool isActive);
}

class UserDataSourceImpl implements UserDataSource {
  final ApiClient _apiClient;
  final ILogger _logger;
  static const String _tableName = 'profiles';

  UserDataSourceImpl(this._apiClient, this._logger);

  @override
  Future<List<UserEntity>> getTenantUsers(String tenantId) async {
    try {
      _logger.debug('Fetching users for tenant',
          category: LogCategory.auth,
          context: {'tenantId': tenantId});

      final response = await _apiClient.select<UserModel>(
        table: _tableName,
        fromJson: UserModel.fromJson,
        filters: {
          'tenant_id': tenantId,
        },
        orderBy: 'full_name',
      );

      if (!response.isSuccess) {
        throw Exception(response.message ?? 'Failed to fetch tenant users');
      }

      List<UserEntity> users = response.data?.map((model) => model.toEntity()).toList() ?? [];

      // Filter to only return teachers and admins (active or inactive)
      // This ensures all teachers in the tenant are visible for assignment management
      users = users.where((user) {
        return user.role.value == 'teacher' || user.role.value == 'admin';
      }).toList();

      _logger.info('Users fetched successfully',
          category: LogCategory.auth,
          context: {
            'tenantId': tenantId,
            'count': users.length,
          });

      return users;
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

      final response = await _apiClient.selectSingle<UserModel>(
        table: _tableName,
        fromJson: UserModel.fromJson,
        filters: {'id': userId},
      );

      if (!response.isSuccess || response.data == null) {
        _logger.warning('User not found',
            category: LogCategory.auth,
            context: {'userId': userId});
        return null;
      }

      return response.data!.toEntity();
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

      final response = await _apiClient.update(
        table: _tableName,
        data: {'role': role.value},
        filters: {'id': userId},
        fromJson: (json) => json,
      );

      if (!response.isSuccess) {
        throw Exception(response.message ?? 'Failed to update user role');
      }

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

      final response = await _apiClient.update(
        table: _tableName,
        data: {'is_active': isActive},
        filters: {'id': userId},
        fromJson: (json) => json,
      );

      if (!response.isSuccess) {
        throw Exception(response.message ?? 'Failed to update user status');
      }

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
}