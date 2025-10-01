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

  Future<String?> _getTenantId() async {
    return sl<UserStateService>().currentTenantId;
  }

  @override
  Future<Either<Failure, List<GradeEntity>>> getGrades() async {
    try {
      final tenantId = await _getTenantId();

      if (tenantId == null) {
        _logger.warning('Failed to fetch grades - no tenant ID',
            category: LogCategory.paper);
        return Left(AuthFailure('User not authenticated'));
      }

      _logger.debug('Fetching grades for tenant', category: LogCategory.paper, context: {
        'tenantId': tenantId,
      });

      final models = await _dataSource.getGrades(tenantId);
      final entities = models.map((model) => model.toEntity()).toList();

      _logger.info('Grades fetched successfully', category: LogCategory.paper, context: {
        'tenantId': tenantId,
        'gradesCount': entities.length,
      });

      return Right(entities);
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch grades',
          category: LogCategory.paper,
          error: e,
          stackTrace: stackTrace
      );
      return Left(ServerFailure('Failed to get grades: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<GradeEntity>>> getGradesByLevel(int level) async {
    try {
      final tenantId = await _getTenantId();

      if (tenantId == null) {
        return Left(AuthFailure('User not authenticated'));
      }

      final models = await _dataSource.getGradesByLevel(tenantId, level);
      final entities = models.map((model) => model.toEntity()).toList();

      return Right(entities);
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch grades by level',
          category: LogCategory.paper,
          error: e,
          stackTrace: stackTrace
      );
      return Left(ServerFailure('Failed to get grades by level: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<int>>> getAvailableGradeLevels() async {
    try {
      final tenantId = await _getTenantId();

      if (tenantId == null) {
        return Left(AuthFailure('User not authenticated'));
      }

      final levels = await _dataSource.getAvailableGradeLevels(tenantId);
      return Right(levels);
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch grade levels',
          category: LogCategory.paper,
          error: e,
          stackTrace: stackTrace
      );
      return Left(ServerFailure('Failed to get grade levels: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getSectionsByGradeLevel(int level) async {
    try {
      final tenantId = await _getTenantId();

      if (tenantId == null) {
        return Left(AuthFailure('User not authenticated'));
      }

      final sections = await _dataSource.getSectionsByGradeLevel(tenantId, level);
      return Right(sections);
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch sections by grade level',
          category: LogCategory.paper,
          error: e,
          stackTrace: stackTrace
      );
      return Left(ServerFailure('Failed to get sections: ${e.toString()}'));
    }
  }

  // =============== NEW CRUD METHODS ===============

  @override
  Future<Either<Failure, GradeEntity>> createGrade(GradeEntity grade) async {
    try {
      final tenantId = await _getTenantId();
      final userStateService = sl<UserStateService>();

      if (tenantId == null) {
        return Left(AuthFailure('User not authenticated'));
      }

      if (!userStateService.canManageUsers()) {
        return Left(PermissionFailure('Admin privileges required'));
      }

      // Validate level range
      if (grade.level < 1 || grade.level > 12) {
        return Left(ValidationFailure('Grade level must be between 1 and 12'));
      }

      // Trim and validate section
      final section = grade.section?.trim().toUpperCase();
      if (section != null && section.isNotEmpty && !RegExp(r'^[A-Z]$').hasMatch(section)) {
        return Left(ValidationFailure('Section must be a single letter (A-Z)'));
      }

      // Auto-generate standardized name
      final standardizedName = 'Grade ${grade.level}';

      final gradeWithTenant = GradeEntity(
        id: '', // Empty - database will generate
        tenantId: tenantId,
        name: standardizedName, // Auto-generated
        level: grade.level,
        section: section,
        isActive: true,
        createdAt: DateTime.now(),
      );

      final model = GradeModel.fromEntity(gradeWithTenant);
      final createdModel = await _dataSource.createGrade(model);
      return Right(createdModel.toEntity());
    } catch (e, stackTrace) {
      _logger.error('Failed to create grade',
          category: LogCategory.paper,
          error: e,
          stackTrace: stackTrace);
      return Left(ServerFailure('Failed to create grade: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, GradeEntity>> updateGrade(GradeEntity grade) async {
    try {
      final userStateService = sl<UserStateService>();

      if (!userStateService.canManageUsers()) {
        return Left(PermissionFailure('Admin privileges required'));
      }

      final model = GradeModel.fromEntity(grade);
      final updatedModel = await _dataSource.updateGrade(model);
      return Right(updatedModel.toEntity());
    } catch (e, stackTrace) {
      _logger.error('Failed to update grade', category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to update grade: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteGrade(String id) async {
    try {
      final userStateService = sl<UserStateService>();

      if (!userStateService.canManageUsers()) {
        return Left(PermissionFailure('Admin privileges required'));
      }

      await _dataSource.deleteGrade(id);
      return const Right(null);
    } catch (e, stackTrace) {
      _logger.error('Failed to delete grade', category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to delete grade: ${e.toString()}'));
    }
  }
}