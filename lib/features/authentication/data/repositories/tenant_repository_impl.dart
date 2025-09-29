// features/authentication/data/repositories/tenant_repository_impl.dart
import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../domain/entities/tenant_entity.dart';
import '../../domain/repositories/tenant_repository.dart';
import '../../domain/services/user_state_service.dart';
import '../datasources/tenant_data_source.dart';
import '../models/tenant_model.dart';

class TenantRepositoryImpl implements TenantRepository {
  final TenantDataSource _dataSource;
  final ILogger _logger;

  TenantRepositoryImpl(this._dataSource, this._logger);

  @override
  Future<Either<Failure, TenantEntity?>> getTenantById(String id) async {
    try {
      final model = await _dataSource.getTenantById(id);
      return Right(model?.toEntity());
    } catch (e, stackTrace) {
      _logger.error('Failed to get tenant', category: LogCategory.auth, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to get tenant: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, TenantEntity>> updateTenant(TenantEntity tenant) async {
    try {
      final userStateService = sl<UserStateService>();

      if (!userStateService.canManageUsers()) {
        return Left(PermissionFailure('Admin privileges required'));
      }

      final model = TenantModel.fromEntity(tenant);
      final updatedModel = await _dataSource.updateTenant(model);
      return Right(updatedModel.toEntity());
    } catch (e, stackTrace) {
      _logger.error('Failed to update tenant', category: LogCategory.auth, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to update tenant: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<TenantEntity>>> getActiveTenants() async {
    try {
      final models = await _dataSource.getActiveTenants();
      final entities = models.map((model) => model.toEntity()).toList();
      return Right(entities);
    } catch (e, stackTrace) {
      _logger.error('Failed to get active tenants', category: LogCategory.auth, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to get active tenants: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> isTenantActive(String tenantId) async {
    try {
      final isActive = await _dataSource.isTenantActive(tenantId);
      return Right(isActive);
    } catch (e, stackTrace) {
      _logger.error('Failed to check tenant status', category: LogCategory.auth, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to check tenant status: ${e.toString()}'));
    }
  }
}