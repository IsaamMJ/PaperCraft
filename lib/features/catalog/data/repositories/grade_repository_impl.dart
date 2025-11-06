// features/catalog/data/repositories/grade_repository_impl.dart
import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../domain/entities/grade_entity.dart';
import '../../domain/repositories/grade_repository.dart';
import '../datasources/grade_data_source.dart';
import '../models/grade_model.dart';

class GradeRepositoryImpl implements GradeRepository {
  final GradeDataSource _dataSource;
  final ILogger _logger;

  GradeRepositoryImpl(this._dataSource, this._logger);

  Future<String?> _getTenantId() async => sl<UserStateService>().currentTenantId;

  @override
  Future<Either<Failure, List<GradeEntity>>> getAssignedGrades({
    String? teacherId,
    String? academicYear,
  }) async {
    try {
      // If no teacherId provided (admin), return all grades
      if (teacherId == null) {
        return getGrades(); // Call existing method
      }

      // For teachers, fetch only assigned grades
      final tenantId = await _getTenantId();

      if (tenantId == null) {
        return Left(AuthFailure('User not authenticated'));
      }

      // Get academic year from UserStateService if not provided
      final userStateService = sl<UserStateService>();
      final year = academicYear ?? userStateService.currentAcademicYear;

      if (year == null) {
        return Left(ValidationFailure('Academic year not set'));
      }

      // Query using the grade data source (positional parameters)
      final models = await _dataSource.getAssignedGrades(
        tenantId,
        teacherId,
        year,
      );

      final entities = models.map((m) => m.toEntity()).toList();

      return Right(entities);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get assigned grades',
        category: LogCategory.paper,
        error: e,
        stackTrace: stackTrace,
      );
      return Left(ServerFailure('Failed to get assigned grades: ${e.toString()}'));
    }
  }


  @override
  Future<Either<Failure, List<GradeEntity>>> getGrades() async {
    try {
      final tenantId = await _getTenantId();

      if (tenantId == null) {
        return Left(AuthFailure('User not authenticated'));
      }

      final models = await _dataSource.getGrades(tenantId);
      final entities = models.map((m) => m.toEntity()).toList();

      return Right(entities);
    } catch (e, stackTrace) {
      _logger.error('Failed to get grades', category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to get grades: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<int>>> getAvailableGradeLevels() async {
    try {
      final tenantId = await _getTenantId();

      if (tenantId == null) {
        return Left(AuthFailure('User not authenticated'));
      }

      final models = await _dataSource.getGrades(tenantId);

      // Extract unique grade numbers and sort them
      final gradeLevels = models
          .map((m) => m.gradeNumber)
          .toSet()
          .toList()
        ..sort();

      return Right(gradeLevels);
    } catch (e, stackTrace) {
      _logger.error('Failed to get grade levels', category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to get grade levels: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<GradeEntity>>> getGradesByLevel(int level) async {
    try {
      final tenantId = await _getTenantId();

      if (tenantId == null) {
        return Left(AuthFailure('User not authenticated'));
      }

      final models = await _dataSource.getGrades(tenantId);

      // Filter by grade number
      final filtered = models
          .where((m) => m.gradeNumber == level)
          .map((m) => m.toEntity())
          .toList();

      return Right(filtered);
    } catch (e, stackTrace) {
      _logger.error('Failed to get grades by level', category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to get grades by level: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getSectionsByGradeLevel(int gradeLevel) async {
    try {
      final tenantId = await _getTenantId();

      if (tenantId == null) {
        return Left(AuthFailure('User not authenticated'));
      }

      final models = await _dataSource.getGrades(tenantId);

      // Since your DB schema doesn't have sections, return empty list
      // This method exists for backward compatibility with your grade_bloc
      return const Right([]);

    } catch (e, stackTrace) {
      _logger.error('Failed to get sections', category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to get sections: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, GradeEntity>> createGrade(GradeEntity grade) async {
    try {
      print('📦 [REPO] createGrade called with: $grade');
      final tenantId = await _getTenantId();
      final userStateService = sl<UserStateService>();

      print('   Tenant ID: $tenantId');
      print('   Can manage users: ${userStateService.canManageUsers()}');

      if (tenantId == null) {
        print('❌ [REPO] User not authenticated');
        return Left(AuthFailure('User not authenticated'));
      }

      if (!userStateService.canManageUsers()) {
        print('❌ [REPO] User does not have admin privileges');
        return Left(PermissionFailure('Admin privileges required'));
      }

      if (grade.gradeNumber < 1 || grade.gradeNumber > 12) {
        print('❌ [REPO] Invalid grade number: ${grade.gradeNumber}');
        return Left(ValidationFailure('Grade number must be between 1 and 12'));
      }

      final gradeWithTenant = GradeEntity(
        id: '',
        tenantId: tenantId,
        gradeNumber: grade.gradeNumber,
        isActive: true,
        createdAt: DateTime.now(),
      );

      print('   Sending to datasource...');
      final model = GradeModel.fromEntity(gradeWithTenant);
      final createdModel = await _dataSource.createGrade(model);

      print('✅ [REPO] Grade created successfully: ${createdModel.displayName}');
      return Right(createdModel.toEntity());
    } catch (e, stackTrace) {
      print('❌ [REPO] Exception in createGrade: $e');
      print('   StackTrace: $stackTrace');
      _logger.error('Failed to create grade', category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to create grade: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, GradeEntity>> updateGrade(GradeEntity grade) async {
    try {
      print('📝 [REPO] updateGrade called with: ${grade.displayName} (ID: ${grade.id})');
      final userStateService = sl<UserStateService>();

      print('   Can manage users: ${userStateService.canManageUsers()}');

      if (!userStateService.canManageUsers()) {
        print('❌ [REPO] User does not have admin privileges');
        return Left(PermissionFailure('Admin privileges required'));
      }

      print('   Sending to datasource...');
      final model = GradeModel.fromEntity(grade);
      final updatedModel = await _dataSource.updateGrade(model);

      print('✅ [REPO] Grade updated successfully: ${updatedModel.displayName}');
      return Right(updatedModel.toEntity());
    } catch (e, stackTrace) {
      print('❌ [REPO] Exception in updateGrade: $e');
      print('   StackTrace: $stackTrace');
      _logger.error('Failed to update grade', category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to update grade: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteGrade(String id) async {
    try {
      print('🗑️ [REPO] deleteGrade called with ID: $id');
      final userStateService = sl<UserStateService>();

      print('   Can manage users: ${userStateService.canManageUsers()}');

      if (!userStateService.canManageUsers()) {
        print('❌ [REPO] User does not have admin privileges');
        return Left(PermissionFailure('Admin privileges required'));
      }

      print('   Sending deletion request to datasource...');
      await _dataSource.deleteGrade(id);
      print('✅ [REPO] Grade deleted successfully (ID: $id)');
      return const Right(null);
    } catch (e, stackTrace) {
      print('❌ [REPO] Exception in deleteGrade: $e');
      print('   StackTrace: $stackTrace');
      _logger.error('Failed to delete grade', category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to delete grade: ${e.toString()}'));
    }
  }
}