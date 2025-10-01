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

  Future<String?> _getTenantId() async {
    return sl<UserStateService>().currentTenantId;
  }

  @override
  Future<Either<Failure, List<SubjectEntity>>> getSubjects() async {
    try {
      final tenantId = await _getTenantId();

      if (tenantId == null) {
        _logger.warning('Failed to fetch subjects - no tenant ID',
            category: LogCategory.paper,
            context: {'operation': 'get_subjects'}
        );
        return Left(AuthFailure('User not authenticated'));
      }

      _logger.debug('Fetching subjects for tenant', category: LogCategory.paper, context: {
        'tenantId': tenantId,
        'operation': 'get_subjects',
      });

      final models = await _dataSource.getSubjects(tenantId);
      final entities = models.map((model) => model.toEntity()).toList();

      _logger.info('Subjects fetched successfully', category: LogCategory.paper, context: {
        'tenantId': tenantId,
        'subjectsCount': entities.length,
        'operation': 'get_subjects',
      });

      return Right(entities);
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch subjects',
          category: LogCategory.paper,
          error: e,
          stackTrace: stackTrace,
          context: {'operation': 'get_subjects'}
      );
      return Left(ServerFailure('Failed to get subjects: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<SubjectEntity>>> getSubjectsByGrade(int gradeLevel) async {
    try {
      final tenantId = await _getTenantId();

      if (tenantId == null) {
        _logger.warning('Failed to fetch subjects by grade - no tenant ID',
            category: LogCategory.paper,
            context: {
              'gradeLevel': gradeLevel,
              'operation': 'get_subjects_by_grade',
            }
        );
        return Left(AuthFailure('User not authenticated'));
      }

      _logger.debug('Fetching subjects by grade for tenant', category: LogCategory.paper, context: {
        'tenantId': tenantId,
        'gradeLevel': gradeLevel,
        'operation': 'get_subjects_by_grade',
      });

      // First get all subjects
      final models = await _dataSource.getSubjects(tenantId);
      final allSubjects = models.map((model) => model.toEntity()).toList();

      // Filter by grade level using the existing service
      final filteredSubjects = SubjectGradeService.filterSubjectsByGrade(allSubjects, gradeLevel);

      _logger.info('Subjects filtered by grade successfully', category: LogCategory.paper, context: {
        'tenantId': tenantId,
        'gradeLevel': gradeLevel,
        'totalSubjects': allSubjects.length,
        'filteredSubjects': filteredSubjects.length,
        'operation': 'get_subjects_by_grade',
      });

      return Right(filteredSubjects);
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch subjects by grade',
          category: LogCategory.paper,
          error: e,
          stackTrace: stackTrace,
          context: {
            'gradeLevel': gradeLevel,
            'operation': 'get_subjects_by_grade',
          }
      );
      return Left(ServerFailure('Failed to get subjects by grade: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, SubjectEntity?>> getSubjectById(String id) async {
    try {
      _logger.debug('Fetching subject by ID', category: LogCategory.paper, context: {
        'subjectId': id,
        'operation': 'get_subject_by_id',
      });

      final model = await _dataSource.getSubjectById(id);

      if (model == null) {
        _logger.debug('Subject not found', category: LogCategory.paper, context: {
          'subjectId': id,
          'operation': 'get_subject_by_id',
        });
        return const Right(null);
      }

      final entity = model.toEntity();

      _logger.debug('Subject found', category: LogCategory.paper, context: {
        'subjectId': id,
        'subjectName': entity.name,
        'operation': 'get_subject_by_id',
      });

      return Right(entity);
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch subject by ID',
          category: LogCategory.paper,
          error: e,
          stackTrace: stackTrace,
          context: {
            'subjectId': id,
            'operation': 'get_subject_by_id',
          }
      );
      return Left(ServerFailure('Failed to get subject by ID: ${e.toString()}'));
    }
  }

  // =============== NEW CRUD METHODS ===============

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

      // Create entity with tenant ID but WITHOUT generating ID
      final subjectWithTenant = SubjectEntity(
        id: '', // Empty - database will generate
        tenantId: tenantId,
        name: subject.name.trim(), // Trim whitespace
        description: subject.description?.trim(),
        isActive: true,
        createdAt: DateTime.now(), // This will be ignored anyway
      );

      final model = SubjectModel.fromEntity(subjectWithTenant);
      final createdModel = await _dataSource.createSubject(model);
      return Right(createdModel.toEntity());
    } catch (e, stackTrace) {
      _logger.error('Failed to create subject',
          category: LogCategory.paper,
          error: e,
          stackTrace: stackTrace);
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