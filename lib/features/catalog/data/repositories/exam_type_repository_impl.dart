// features/question_papers/data/repositories/exam_type_repository_impl.dart
import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../domain/entities/exam_type_entity.dart';
import '../../domain/repositories/exam_type_repository.dart';
import '../datasources/exam_type_data_source.dart';
import '../models/exam_type_model.dart';

class ExamTypeRepositoryImpl implements ExamTypeRepository {
  final ExamTypeDataSource _dataSource;
  final ILogger _logger;
  final UserStateService _userStateService;

  ExamTypeRepositoryImpl(
      this._dataSource,
      this._logger,
      this._userStateService,
      );

  String? _getTenantId() => _userStateService.currentTenantId;

  @override
  Future<Either<Failure, List<ExamTypeEntity>>> getExamTypes() async {
    try {
      _logger.info('🔍 Getting exam types...', category: LogCategory.examtype);

      final tenantId = _getTenantId();

      _logger.info('🔍 Tenant ID: $tenantId', category: LogCategory.examtype);

      if (tenantId == null) {
        _logger.error('❌ Tenant ID is null!', category: LogCategory.examtype);
        return Left(AuthFailure('User not authenticated')); // POSITIONAL
      }

      _logger.info('🔍 Fetching from data source...', category: LogCategory.examtype);
      final models = await _dataSource.getExamTypes(tenantId);

      _logger.info('✅ Data source returned ${models.length} exam types',
          category: LogCategory.examtype);

      final entities = models.map((m) => m.toEntity()).toList();

      _logger.info('✅ Exam types fetched successfully',
          category: LogCategory.examtype,
          context: {
            'count': entities.length,
            'names': entities.map((e) => e.name).toList(),
          });

      return Right(entities);
    } catch (e, stackTrace) {
      _logger.error('❌ Failed to get exam types',
          category: LogCategory.examtype,
          error: e,
          stackTrace: stackTrace);
      return Left(ServerFailure('Failed to get exam types: ${e.toString()}')); // POSITIONAL
    }
  }

  @override
  Future<Either<Failure, ExamTypeEntity?>> getExamTypeById(String id) async {
    try {
      final model = await _dataSource.getExamTypeById(id);
      return Right(model?.toEntity());
    } catch (e, stackTrace) {
      _logger.error('Failed to get exam type',
          category: LogCategory.examtype,
          error: e,
          stackTrace: stackTrace);
      return Left(ServerFailure('Failed to get exam type: ${e.toString()}')); // POSITIONAL
    }
  }

  @override
  Future<Either<Failure, ExamTypeEntity>> createExamType(ExamTypeEntity examType) async {
    try {
      final tenantId = _getTenantId();

      if (tenantId == null) {
        return Left(AuthFailure('User not authenticated')); // POSITIONAL
      }

      if (!_userStateService.canApprovePapers()) {
        return Left(PermissionFailure('Admin privileges required')); // POSITIONAL
      }

      if (examType.name.trim().isEmpty) {
        return Left(ValidationFailure('Exam type name cannot be empty')); // POSITIONAL
      }

      if (examType.sections.isEmpty) {
        return Left(ValidationFailure('At least one section is required')); // POSITIONAL
      }

      for (final section in examType.sections) {
        if (section.questions < 1) {
          return Left(ValidationFailure(
              'Section "${section.name}" must have at least 1 question')); // POSITIONAL
        }
        if (section.marksPerQuestion < 1) {
          return Left(ValidationFailure(
              'Section "${section.name}" must have marks greater than 0')); // POSITIONAL
        }
      }

      final examTypeWithTenant = ExamTypeEntity(
        id: '',
        tenantId: tenantId,
        subjectId: examType.subjectId,
        name: examType.name.trim(),
        description: examType.description,
        durationMinutes: examType.durationMinutes,
        totalMarks: examType.totalMarks,
        totalSections: examType.sections.length,
        sections: examType.sections,
        isActive: true,
      );

      final model = ExamTypeModel.fromEntity(examTypeWithTenant);
      final createdModel = await _dataSource.createExamType(model);

      return Right(createdModel.toEntity());
    } catch (e, stackTrace) {
      _logger.error('Failed to create exam type',
          category: LogCategory.examtype,
          error: e,
          stackTrace: stackTrace);
      return Left(ServerFailure('Failed to create exam type: ${e.toString()}')); // POSITIONAL
    }
  }

  @override
  Future<Either<Failure, ExamTypeEntity>> updateExamType(ExamTypeEntity examType) async {
    try {
      if (!_userStateService.canApprovePapers()) {
        return Left(PermissionFailure('Admin privileges required')); // POSITIONAL
      }

      final model = ExamTypeModel.fromEntity(examType);
      final updatedModel = await _dataSource.updateExamType(model);

      return Right(updatedModel.toEntity());
    } catch (e, stackTrace) {
      _logger.error('Failed to update exam type',
          category: LogCategory.examtype,
          error: e,
          stackTrace: stackTrace);
      return Left(ServerFailure('Failed to update exam type: ${e.toString()}')); // POSITIONAL
    }
  }

  @override
  Future<Either<Failure, void>> deleteExamType(String id) async {
    try {
      if (!_userStateService.canApprovePapers()) {
        return Left(PermissionFailure('Admin privileges required')); // POSITIONAL
      }

      await _dataSource.deleteExamType(id);
      return const Right(null);
    } catch (e, stackTrace) {
      _logger.error('Failed to delete exam type',
          category: LogCategory.examtype,
          error: e,
          stackTrace: stackTrace);
      return Left(ServerFailure('Failed to delete exam type: ${e.toString()}')); // POSITIONAL
    }
  }
}