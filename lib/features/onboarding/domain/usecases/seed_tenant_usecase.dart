// features/onboarding/domain/usecases/seed_tenant_usecase.dart
import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../../catalog/data/datasources/subject_data_source.dart';
import '../../../catalog/domain/entities/grade_entity.dart';
import '../../../catalog/domain/entities/subject_entity.dart';
import '../../../catalog/domain/repositories/grade_repository.dart';
import '../../../catalog/domain/repositories/subject_repository.dart';
import '../../data/template/school_templates.dart';

typedef ProgressCallback = void Function(double progress, String currentItem);

class SeedTenantUseCase {
  final SubjectRepository _subjectRepository;
  final GradeRepository _gradeRepository;
  final ILogger _logger;

  SeedTenantUseCase(
      this._subjectRepository,
      this._gradeRepository,
      this._logger,
      );

  Future<Either<Failure, String>> call({
    required SchoolType schoolType,
    required ProgressCallback onProgress,
  }) async {
    try {
      final tenantId = sl<UserStateService>().currentTenantId;

      if (tenantId == null) {
        return Left(AuthFailure('No tenant ID found'));
      }

      _logger.info('Starting tenant data seeding',
          category: LogCategory.auth,
          context: {'tenantId': tenantId, 'schoolType': schoolType.name});

      final subjectTemplates = SchoolTemplates.getSubjects(schoolType);
      final grades = SchoolTemplates.getGrades(schoolType);

      final totalItems = subjectTemplates.length + grades.length;
      var completedItems = 0;

      // Step 1: Load subject catalog to get IDs
      final dataSource = sl<SubjectDataSource>();
      final catalog = await dataSource.getSubjectCatalog();

      final catalogMap = {for (var c in catalog) c.name: c.id};

      // Step 2: Enable subjects from catalog
      final createdSubjects = <String, String>{}; // name -> subjectId

      for (final template in subjectTemplates) {
        onProgress(completedItems / totalItems, 'Enabling ${template.name}...');

        final catalogId = catalogMap[template.catalogSubjectId];
        if (catalogId == null) {
          _logger.warning('Catalog subject not found',
              category: LogCategory.auth,
              context: {'subjectName': template.catalogSubjectId});
          completedItems++;
          continue;
        }

        final subject = SubjectEntity(
          id: '',
          tenantId: tenantId,
          catalogSubjectId: catalogId,
          name: template.name,
          isActive: true,
          createdAt: DateTime.now(),
        );

        final result = await _subjectRepository.createSubject(subject);

        result.fold(
              (failure) => _logger.warning('Failed to enable subject',
              category: LogCategory.auth,
              context: {'subjectName': template.name, 'error': failure.message}),
              (created) => createdSubjects[template.name] = created.id,
        );

        completedItems++;
      }

      // Step 3: Create grades
      for (final gradeNumber in grades) {
        onProgress(completedItems / totalItems, 'Creating Grade $gradeNumber...');

        final grade = GradeEntity(
          id: '',
          tenantId: tenantId,
          gradeNumber: gradeNumber,
          isActive: true,
          createdAt: DateTime.now(),
        );

        final result = await _gradeRepository.createGrade(grade);

        if (result.isLeft()) {
          _logger.warning('Failed to create grade',
              category: LogCategory.auth, context: {'gradeLevel': gradeNumber});
        }

        completedItems++;
      }

      onProgress(1.0, 'Setup complete!');

      _logger.info('Tenant seeding completed',
          category: LogCategory.auth,
          context: {
            'tenantId': tenantId,
            'totalItems': totalItems,
            'completedItems': completedItems
          });

      return Right(tenantId);
    } catch (e, stackTrace) {
      _logger.error('Failed to seed tenant data',
          category: LogCategory.auth, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to initialize tenant: ${e.toString()}'));
    }
  }
}