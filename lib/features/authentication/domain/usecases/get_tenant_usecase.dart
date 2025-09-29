// features/authentication/domain/usecases/get_tenant_usecase.dart
import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/tenant_entity.dart';
import '../failures/auth_failures.dart' hide AuthFailure;
import '../repositories/tenant_repository.dart';

class GetTenantUseCase {
  final TenantRepository _repository;

  GetTenantUseCase(this._repository);

  /// Get tenant by ID with validation
  Future<Either<AuthFailure, TenantEntity?>> call(String tenantId) async {
    // Validate input
    if (tenantId.trim().isEmpty) {
      return const Left(AuthFailure('Tenant ID cannot be empty or whitespace'));
    }

    final result = await _repository.getTenantById(tenantId);

    return result.fold(
          (failure) => Left(AuthFailure(failure.message, code: failure.code)),
          (tenant) {
        // Handle null tenant case
        if (tenant == null) {
          return const Left(AuthFailure('Tenant not found', code: 'TENANT_NOT_FOUND'));
        }

        // Additional business logic validation using the entity's isValid property
        if (!tenant.isValid) {
          return const Left(AuthFailure('Tenant account is inactive or invalid', code: 'TENANT_INVALID'));
        }

        return Right(tenant);
      },
    );
  }

  /// Get tenant name only (commonly used method)
  Future<Either<AuthFailure, String?>> getTenantName(String tenantId) async {
    final result = await call(tenantId);

    return result.fold(
          (failure) => Left(failure),
          (tenant) => Right(tenant?.displayName),
    );
  }

  /// Check if tenant is active (for security validation)
  Future<Either<AuthFailure, bool>> isTenantActive(String tenantId) async {
    if (tenantId.trim().isEmpty) {
      return const Right(false);
    }

    final result = await _repository.isTenantActive(tenantId);

    return result.fold(
          (failure) => Left(AuthFailure(failure.message, code: failure.code)),
          (isActive) => Right(isActive),
    );
  }
}