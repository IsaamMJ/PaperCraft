// features/question_papers/data/repositories/subject_repository_impl.dart
import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../domain/entities/subject_entity.dart';
import '../../domain/repositories/subject_repository.dart';
import '../../domain/services/subject_grade_service.dart';
import '../datasources/subject_data_source.dart';
import '../models/subject_model.dart';

class SubjectRepositoryImpl implements SubjectRepository {
  final SubjectDataSource _dataSource;
  final ILogger _logger;

  SubjectRepositoryImpl(this._dataSource, this._logger);

  Future<String?> _getTenantId() async => sl<UserStateService>().currentTenantId;

  @override
  Future<Either<Failure, List<SubjectEntity>>> getAssignedSubjects({
    String? teacherId,
    String? academicYear,
  }) async {
    try {
      // If no teacherId provided (admin), return all subjects
      if (teacherId == null) {
        return getSubjects(); // Call existing method
      }

      // For teachers, fetch only assigned subjects
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

      // Query using the subject data source (positional parameters)
      final models = await _dataSource.getAssignedSubjects(
        tenantId,
        teacherId,
        year,
      );

      final entities = models.map((m) => m.toEntity()).toList();

      return Right(entities);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get assigned subjects',
        category: LogCategory.paper,
        error: e,
        stackTrace: stackTrace,
      );
      return Left(ServerFailure('Failed to get assigned subjects: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<SubjectEntity>>> getSubjects() async {
    try {
      final tenantId = await _getTenantId();

      if (tenantId == null) {
        return Left(AuthFailure('User not authenticated'));
      }

      final models = await _dataSource.getSubjects(tenantId);
      final entities = models.map((m) => m.toEntity()).toList();

      return Right(entities);
    } catch (e, stackTrace) {
      _logger.error('Failed to get subjects', category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to get subjects: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<SubjectEntity>>> getSubjectsByGrade(int gradeLevel) async {
    try {
      final tenantId = await _getTenantId();

      if (tenantId == null) {
        return Left(AuthFailure('User not authenticated'));
      }

      final models = await _dataSource.getSubjects(tenantId);
      final allSubjects = models.map((m) => m.toEntity()).toList();

      // Filter by grade level
      final filtered = SubjectGradeService.filterSubjectsByGrade(allSubjects, gradeLevel);

      return Right(filtered);
    } catch (e, stackTrace) {
      _logger.error('Failed to get subjects by grade', category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to get subjects: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, SubjectEntity?>> getSubjectById(String id) async {
    try {
      final model = await _dataSource.getSubjectById(id);
      return Right(model?.toEntity());
    } catch (e, stackTrace) {
      _logger.error('Failed to get subject', category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to get subject: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, SubjectEntity>> createSubject(SubjectEntity subject) async {
    try {
      final tenantId = await _getTenantId();
      final userStateService = sl<UserStateService>();

      if (tenantId == null) {
        return Left(AuthFailure('User not authenticated'));
      }

      if (!userStateService.canManageUsers()) {
        return Left(PermissionFailure('Admin privileges required'));
      }

      final subjectWithTenant = SubjectEntity(
        id: '',
        tenantId: tenantId,
        catalogSubjectId: subject.catalogSubjectId,
        name: subject.name.trim(),
        description: subject.description?.trim(),
        minGrade: subject.minGrade,
        maxGrade: subject.maxGrade,
        isActive: true,
        createdAt: DateTime.now(),
      );

      final model = SubjectModel.fromEntity(subjectWithTenant);
      final createdModel = await _dataSource.createSubject(model);

      return Right(createdModel.toEntity());
    } catch (e, stackTrace) {
      _logger.error('Failed to create subject', category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to create subject: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, SubjectEntity>> updateSubject(SubjectEntity subject) async {
    try {
      final userStateService = sl<UserStateService>();

      if (!userStateService.canManageUsers()) {
        return Left(PermissionFailure('Admin privileges required'));
      }

      final model = SubjectModel.fromEntity(subject);
      final updatedModel = await _dataSource.updateSubject(model);

      return Right(updatedModel.toEntity());
    } catch (e, stackTrace) {
      _logger.error('Failed to update subject', category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to update subject: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteSubject(String id) async {
    try {
      final userStateService = sl<UserStateService>();

      if (!userStateService.canManageUsers()) {
        return Left(PermissionFailure('Admin privileges required'));
      }

      await _dataSource.deleteSubject(id);
      return const Right(null);
    } catch (e, stackTrace) {
      _logger.error('Failed to delete subject', category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to delete subject: ${e.toString()}'));
    }
  }
}