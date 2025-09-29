// features/authentication/domain/repositories/tenant_repository.dart
import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/tenant_entity.dart';

abstract class TenantRepository {
  /// Get tenant by ID
  Future<Either<Failure, TenantEntity?>> getTenantById(String id);

  /// Update tenant (admin only)
  Future<Either<Failure, TenantEntity>> updateTenant(TenantEntity tenant);

  /// Get all active tenants (admin only)
  Future<Either<Failure, List<TenantEntity>>> getActiveTenants();

  /// Check if tenant exists and is active
  Future<Either<Failure, bool>> isTenantActive(String tenantId);
}