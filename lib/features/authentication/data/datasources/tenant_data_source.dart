// features/authentication/data/datasources/tenant_data_source.dart
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../../core/infrastructure/network/api_client.dart';
import '../models/tenant_model.dart';

abstract class TenantDataSource {
  Future<TenantModel?> getTenantById(String id);
  Future<TenantModel> updateTenant(TenantModel tenant);
  Future<List<TenantModel>> getActiveTenants();
  Future<bool> isTenantActive(String tenantId);

  Future<void> markAsInitialized(String tenantId);
}

class TenantDataSourceImpl implements TenantDataSource {
  final ApiClient _apiClient;
  final ILogger _logger;
  static const String _tableName = 'tenants';

  TenantDataSourceImpl(this._apiClient, this._logger);

  // In TenantDataSourceImpl class:

  @override
  Future<void> markAsInitialized(String tenantId) async {
    try {
      _logger.info('Marking tenant as initialized in database', category: LogCategory.auth, context: {
        'tenantId': tenantId,
      });

      final response = await _apiClient.update<Map<String, dynamic>>(
        table: _tableName,
        data: {'is_initialized': true},
        filters: {'id': tenantId},
        fromJson: (json) => json,
      );

      if (!response.isSuccess) {
        _logger.error('Failed to mark tenant as initialized',
          category: LogCategory.auth,
          error: Exception('API Error: ${response.message}'),
          context: {
            'tenantId': tenantId,
            'apiErrorType': response.errorType?.toString(),
            'apiMessage': response.message,
          },
        );
        throw Exception(response.message ?? 'Failed to mark tenant as initialized');
      }

      _logger.info('Tenant marked as initialized in database', category: LogCategory.auth, context: {
        'tenantId': tenantId,
      });
    } catch (e, stackTrace) {
      _logger.error('Failed to mark tenant as initialized',
        category: LogCategory.auth,
        error: e,
        stackTrace: stackTrace,
        context: {'tenantId': tenantId},
      );
      rethrow;
    }
  }

  @override
  Future<TenantModel?> getTenantById(String id) async {
    try {
      _logger.debug('Fetching tenant by ID', category: LogCategory.auth, context: {
        'tenantId': id,
        'operation': 'get_tenant_by_id',
      });

      final response = await _apiClient.selectSingle<TenantModel>(
        table: _tableName,
        fromJson: (json) => TenantModel.fromJson(json),
        filters: {'id': id},
      );

      if (response.isSuccess) {
        if (response.data != null) {
          _logger.debug('Tenant found', category: LogCategory.auth, context: {
            'tenantId': id,
            'tenantName': response.data!.name,
            'operation': 'get_tenant_by_id',
          });
        } else {
          _logger.debug('Tenant not found', category: LogCategory.auth, context: {
            'tenantId': id,
            'operation': 'get_tenant_by_id',
          });
        }
        return response.data;
      } else {
        _logger.error('Failed to fetch tenant',
          category: LogCategory.auth,
          error: Exception('API Error: ${response.message}'),
          context: {
            'tenantId': id,
            'apiErrorType': response.errorType?.toString(),
            'apiMessage': response.message,
            'operation': 'get_tenant_by_id',
          },
        );
        throw Exception(response.message ?? 'Failed to get tenant');
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch tenant by ID',
        category: LogCategory.auth,
        error: e,
        stackTrace: stackTrace,
        context: {
          'tenantId': id,
          'errorType': e.runtimeType.toString(),
          'operation': 'get_tenant_by_id',
        },
      );
      rethrow;
    }
  }

  @override
  Future<TenantModel> updateTenant(TenantModel tenant) async {
    try {
      _logger.info('Updating tenant', category: LogCategory.auth, context: {
        'tenantId': tenant.id,
        'tenantName': tenant.name,
        'operation': 'update_tenant',
      });

      final response = await _apiClient.update<TenantModel>(
        table: _tableName,
        data: tenant.toJson(),
        filters: {'id': tenant.id},
        fromJson: (json) => TenantModel.fromJson(json),
      );

      if (response.isSuccess) {
        _logger.info('Tenant updated successfully', category: LogCategory.auth, context: {
          'tenantId': tenant.id,
          'tenantName': tenant.name,
          'operation': 'update_tenant',
        });
        return response.data!;
      } else {
        _logger.error('Failed to update tenant',
          category: LogCategory.auth,
          error: Exception('API Error: ${response.message}'),
          context: {
            'tenantId': tenant.id,
            'apiErrorType': response.errorType?.toString(),
            'apiMessage': response.message,
            'operation': 'update_tenant',
          },
        );
        throw Exception(response.message ?? 'Failed to update tenant');
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to update tenant',
        category: LogCategory.auth,
        error: e,
        stackTrace: stackTrace,
        context: {
          'tenantId': tenant.id,
          'errorType': e.runtimeType.toString(),
          'operation': 'update_tenant',
        },
      );
      rethrow;
    }
  }

  @override
  Future<List<TenantModel>> getActiveTenants() async {
    try {
      _logger.debug('Fetching active tenants', category: LogCategory.auth, context: {
        'operation': 'get_active_tenants',
      });

      final response = await _apiClient.select<TenantModel>(
        table: _tableName,
        fromJson: (json) => TenantModel.fromJson(json),
        filters: {'is_active': true},
        orderBy: 'name',
        ascending: true,
      );

      if (response.isSuccess) {
        _logger.debug('Active tenants fetched', category: LogCategory.auth, context: {
          'count': response.data!.length,
          'operation': 'get_active_tenants',
        });
        return response.data!;
      } else {
        _logger.error('Failed to fetch active tenants',
          category: LogCategory.auth,
          error: Exception('API Error: ${response.message}'),
          context: {
            'apiErrorType': response.errorType?.toString(),
            'apiMessage': response.message,
            'operation': 'get_active_tenants',
          },
        );
        throw Exception(response.message ?? 'Failed to get active tenants');
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch active tenants',
        category: LogCategory.auth,
        error: e,
        stackTrace: stackTrace,
        context: {
          'errorType': e.runtimeType.toString(),
          'operation': 'get_active_tenants',
        },
      );
      rethrow;
    }
  }

  @override
  Future<bool> isTenantActive(String tenantId) async {
    try {
      _logger.debug('Checking tenant active status', category: LogCategory.auth, context: {
        'tenantId': tenantId,
        'operation': 'is_tenant_active',
      });

      final response = await _apiClient.selectSingle<Map<String, dynamic>>(
        table: _tableName,
        fromJson: (json) => json,
        filters: {'id': tenantId},
      );

      if (response.isSuccess && response.data != null) {
        final isActive = response.data!['is_active'] as bool? ?? false;
        _logger.debug('Tenant active status checked', category: LogCategory.auth, context: {
          'tenantId': tenantId,
          'isActive': isActive,
          'operation': 'is_tenant_active',
        });
        return isActive;
      } else {
        _logger.debug('Tenant not found when checking status', category: LogCategory.auth, context: {
          'tenantId': tenantId,
          'operation': 'is_tenant_active',
        });
        return false;
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to check tenant active status',
        category: LogCategory.auth,
        error: e,
        stackTrace: stackTrace,
        context: {
          'tenantId': tenantId,
          'errorType': e.runtimeType.toString(),
          'operation': 'is_tenant_active',
        },
      );
      rethrow;
    }
  }
}