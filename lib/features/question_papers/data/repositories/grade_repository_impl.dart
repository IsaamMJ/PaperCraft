import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../domain/entities/grade_entity.dart';
import '../../domain/repositories/grade_repository.dart';
import '../datasources/grade_data_source.dart';

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
}