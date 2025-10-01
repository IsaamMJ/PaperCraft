import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../../question_papers/domain/entities/exam_type_entity.dart';
import '../../../question_papers/domain/entities/grade_entity.dart';
import '../../../question_papers/domain/entities/subject_entity.dart';
import '../../../question_papers/domain/repositories/exam_type_repository.dart';
import '../../../question_papers/domain/repositories/grade_repository.dart';
import '../../../question_papers/domain/repositories/subject_repository.dart';
import '../../data/template/school_templates.dart';

typedef ProgressCallback = void Function(double progress, String currentItem);

class SeedTenantUseCase {
  final SubjectRepository _subjectRepository;
  final GradeRepository _gradeRepository;
  final ExamTypeRepository _examTypeRepository;
  final ILogger _logger;

  SeedTenantUseCase(
      this._subjectRepository,
      this._gradeRepository,
      this._examTypeRepository,
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

      _logger.info('Starting tenant data seeding', category: LogCategory.auth, context: {
        'tenantId': tenantId,
        'schoolType': schoolType.name,
      });

      final subjects = SchoolTemplates.getSubjects(schoolType);
      final grades = SchoolTemplates.getGrades(schoolType);
      final examTypes = SchoolTemplates.getExamTypes(schoolType);

      final totalItems = subjects.length + grades.length + examTypes.length;
      var completedItems = 0;

      // Seed subjects
      for (final subjectTemplate in subjects) {
        onProgress(completedItems / totalItems, 'Creating ${subjectTemplate.name}...');

        final subject = SubjectEntity(
          id: '',
          tenantId: tenantId,
          name: subjectTemplate.name,
          description: subjectTemplate.description,
          isActive: true,
          createdAt: DateTime.now(),
        );

        final result = await _subjectRepository.createSubject(subject);

        if (result.isLeft()) {
          _logger.warning('Failed to create subject', category: LogCategory.auth, context: {
            'subjectName': subjectTemplate.name,
            'continuing': true,
          });
          // Continue anyway - partial success is acceptable
        }

        completedItems++;
      }

      // Seed grades
      for (final gradeLevel in grades) {
        onProgress(completedItems / totalItems, 'Creating Grade $gradeLevel...');

        final grade = GradeEntity(
          id: '',
          tenantId: tenantId,
          name: 'Grade $gradeLevel',
          level: gradeLevel,
          section: null,
          isActive: true,
          createdAt: DateTime.now(),
        );

        final result = await _gradeRepository.createGrade(grade);

        if (result.isLeft()) {
          _logger.warning('Failed to create grade', category: LogCategory.auth, context: {
            'gradeLevel': gradeLevel,
            'continuing': true,
          });
        }

        completedItems++;
      }

      // Seed exam types
      for (final examTypeTemplate in examTypes) {
        onProgress(completedItems / totalItems, 'Creating ${examTypeTemplate.name}...');

        final sections = examTypeTemplate.sections.map((section) {
          return ExamSectionEntity(
            name: section.name,
            type: section.type,
            questions: section.questions,
            marksPerQuestion: section.marksPerQuestion,
            questionsToAnswer: section.questionsToAnswer,
          );
        }).toList();

        final examType = ExamTypeEntity(
          id: '',
          tenantId: tenantId,
          name: examTypeTemplate.name,
          durationMinutes: examTypeTemplate.durationMinutes,
          totalMarks: null,
          totalQuestions: sections.length,
          sections: sections,
        );

        final result = await _examTypeRepository.createExamType(examType);

        if (result.isLeft()) {
          _logger.warning('Failed to create exam type', category: LogCategory.auth, context: {
            'examTypeName': examTypeTemplate.name,
            'continuing': true,
          });
        }

        completedItems++;
      }

      onProgress(1.0, 'Setup complete!');

      _logger.info('Tenant seeding completed', category: LogCategory.auth, context: {
        'tenantId': tenantId,
        'totalItems': totalItems,
        'completedItems': completedItems,
      });

      return Right(tenantId);
    } catch (e, stackTrace) {
      _logger.error('Failed to seed tenant data',
        category: LogCategory.auth,
        error: e,
        stackTrace: stackTrace,
      );
      return Left(ServerFailure('Failed to initialize tenant: ${e.toString()}'));
    }
  }
}