// features/question_papers/data/repositories/exam_type_repository_impl.dart
import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../domain/entities/exam_type_entity.dart';
import '../../domain/repositories/exam_type_repository.dart';
import '../datasources/exam_type_data_source.dart';
import '../models/exam_type_model.dart';

class ExamTypeRepositoryImpl implements ExamTypeRepository {
  final ExamTypeDataSource _dataSource;
  final ILogger _logger;

  ExamTypeRepositoryImpl(this._dataSource, this._logger);

  Future<String?> _getTenantId() async {
    return sl<UserStateService>().currentTenantId;
  }

  @override
  Future<Either<Failure, List<ExamTypeEntity>>> getExamTypes() async {
    try {
      final tenantId = await _getTenantId();

      print('DEBUG: Current tenant ID: $tenantId');
      print('DEBUG: UserStateService instance: ${sl<UserStateService>()}');

      _logger.debug('Fetching exam types', category: LogCategory.examtype, context: {
        'tenantId': tenantId,
        'operation': 'get_exam_types',
      });

      if (tenantId == null) {
        _logger.warning('Failed to get exam types - no tenant ID',
            category: LogCategory.examtype,
            context: {'operation': 'get_exam_types'}
        );
        return Left(AuthFailure('User not authenticated - no tenant ID'));
      }

      final models = await _dataSource.getExamTypes(tenantId);
      final entities = models.map((model) => model.toEntity()).toList();

      _logger.info('Exam types fetched successfully', category: LogCategory.examtype, context: {
        'tenantId': tenantId,
        'count': entities.length,
        'operation': 'get_exam_types',
      });

      return Right(entities);
    } catch (e, stackTrace) {
      _logger.error('Failed to get exam types',
          category: LogCategory.examtype,
          error: e,
          stackTrace: stackTrace,
          context: {'operation': 'get_exam_types'}
      );
      return Left(ServerFailure('Failed to get exam types: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ExamTypeEntity?>> getExamTypeById(String id) async {
    try {
      _logger.debug('Fetching exam type by ID', category: LogCategory.examtype, context: {
        'examTypeId': id,
        'operation': 'get_exam_type_by_id',
      });

      final model = await _dataSource.getExamTypeById(id);

      if (model == null) {
        _logger.debug('Exam type not found', category: LogCategory.examtype, context: {
          'examTypeId': id,
          'operation': 'get_exam_type_by_id',
        });
        return const Right(null);
      }

      final entity = model.toEntity();

      _logger.debug('Exam type found', category: LogCategory.examtype, context: {
        'examTypeId': id,
        'examTypeName': entity.name,
        'operation': 'get_exam_type_by_id',
      });

      return Right(entity);
    } catch (e, stackTrace) {
      _logger.error('Failed to get exam type by ID',
          category: LogCategory.examtype,
          error: e,
          stackTrace: stackTrace,
          context: {
            'examTypeId': id,
            'operation': 'get_exam_type_by_id',
          }
      );
      return Left(ServerFailure('Failed to get exam type: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ExamTypeEntity>> createExamType(ExamTypeEntity examType) async {
    try {
      final tenantId = await _getTenantId();
      final userStateService = sl<UserStateService>();

      _logger.info('Creating exam type', category: LogCategory.examtype, context: {
        'examTypeName': examType.name,
        'tenantId': tenantId,
        'operation': 'create_exam_type',
      });

      if (tenantId == null) {
        _logger.warning('Failed to create exam type - no tenant ID',
            category: LogCategory.examtype,
            context: {
              'examTypeName': examType.name,
              'operation': 'create_exam_type',
            }
        );
        return Left(AuthFailure('User not authenticated'));
      }

      if (!userStateService.canApprovePapers()) {
        _logger.warning('Failed to create exam type - insufficient permissions',
            category: LogCategory.examtype,
            context: {
              'examTypeName': examType.name,
              'userRole': userStateService.currentRole.toString(),
              'operation': 'create_exam_type',
            }
        );
        return Left(PermissionFailure('Admin privileges required to create exam types'));
      }

      // Ensure tenant ID is set
      final examTypeWithTenant = ExamTypeEntity(
        id: examType.id,
        tenantId: tenantId,
        name: examType.name,
        durationMinutes: examType.durationMinutes,
        totalMarks: examType.totalMarks,
        totalQuestions: examType.totalQuestions,
        sections: examType.sections,
      );

      final model = ExamTypeModel.fromEntity(examTypeWithTenant);
      final createdModel = await _dataSource.createExamType(model);
      final createdEntity = createdModel.toEntity();

      _logger.info('Exam type created successfully', category: LogCategory.examtype, context: {
        'examTypeId': createdEntity.id,
        'examTypeName': createdEntity.name,
        'tenantId': tenantId,
        'operation': 'create_exam_type',
      });

      return Right(createdEntity);
    } catch (e, stackTrace) {
      _logger.error('Failed to create exam type',
          category: LogCategory.examtype,
          error: e,
          stackTrace: stackTrace,
          context: {
            'examTypeName': examType.name,
            'operation': 'create_exam_type',
          }
      );
      return Left(ServerFailure('Failed to create exam type: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ExamTypeEntity>> updateExamType(ExamTypeEntity examType) async {
    try {
      final userStateService = sl<UserStateService>();

      _logger.info('Updating exam type', category: LogCategory.examtype, context: {
        'examTypeId': examType.id,
        'examTypeName': examType.name,
        'operation': 'update_exam_type',
      });

      if (!userStateService.canApprovePapers()) {
        _logger.warning('Failed to update exam type - insufficient permissions',
            category: LogCategory.examtype,
            context: {
              'examTypeId': examType.id,
              'userRole': userStateService.currentRole.toString(),
              'operation': 'update_exam_type',
            }
        );
        return Left(PermissionFailure('Admin privileges required to update exam types'));
      }

      final model = ExamTypeModel.fromEntity(examType);
      final updatedModel = await _dataSource.updateExamType(model);
      final updatedEntity = updatedModel.toEntity();

      _logger.info('Exam type updated successfully', category: LogCategory.examtype, context: {
        'examTypeId': updatedEntity.id,
        'examTypeName': updatedEntity.name,
        'operation': 'update_exam_type',
      });

      return Right(updatedEntity);
    } catch (e, stackTrace) {
      _logger.error('Failed to update exam type',
          category: LogCategory.examtype,
          error: e,
          stackTrace: stackTrace,
          context: {
            'examTypeId': examType.id,
            'operation': 'update_exam_type',
          }
      );
      return Left(ServerFailure('Failed to update exam type: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteExamType(String id) async {
    try {
      final userStateService = sl<UserStateService>();

      _logger.info('Deleting exam type', category: LogCategory.examtype, context: {
        'examTypeId': id,
        'operation': 'delete_exam_type',
      });

      if (!userStateService.canApprovePapers()) {
        _logger.warning('Failed to delete exam type - insufficient permissions',
            category: LogCategory.examtype,
            context: {
              'examTypeId': id,
              'userRole': userStateService.currentRole.toString(),
              'operation': 'delete_exam_type',
            }
        );
        return Left(PermissionFailure('Admin privileges required to delete exam types'));
      }

      await _dataSource.deleteExamType(id);

      _logger.info('Exam type deleted successfully', category: LogCategory.examtype, context: {
        'examTypeId': id,
        'operation': 'delete_exam_type',
      });

      return const Right(null);
    } catch (e, stackTrace) {
      _logger.error('Failed to delete exam type',
          category: LogCategory.examtype,
          error: e,
          stackTrace: stackTrace,
          context: {
            'examTypeId': id,
            'operation': 'delete_exam_type',
          }
      );
      return Left(ServerFailure('Failed to delete exam type: ${e.toString()}'));
    }
  }
}