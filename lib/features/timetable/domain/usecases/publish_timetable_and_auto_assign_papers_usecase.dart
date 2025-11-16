import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../assignments/domain/repositories/teacher_subject_repository.dart';
import '../../../authentication/domain/repositories/user_repository.dart';
import '../../../paper_workflow/domain/usecases/auto_assign_question_papers_usecase.dart';
import '../entities/exam_timetable_entity.dart';
import '../entities/exam_timetable_entry_entity.dart';
import '../repositories/exam_timetable_repository.dart';
import '../usecases/publish_exam_timetable_usecase.dart';

/// Use case for publishing exam timetable and automatically assigning question papers to teachers
///
/// This orchestrates a two-step process:
/// 1. Publish the exam timetable (lock entries, set status to published)
/// 2. Auto-assign question papers to all teachers for their subjects
///
/// Flow:
/// ```
/// Office Staff publishes timetable
///   ↓
/// Timetable status changes to 'published'
///   ↓
/// Fetch all exam timetable entries
///   ↓
/// For each entry, get teachers assigned to (grade, section, subject)
///   ↓
/// Create blank question papers for each teacher
///   ↓
/// Teachers see papers in their dashboard with pre-filled metadata
/// ```
///
/// Example:
/// ```dart
/// final usecase = PublishTimetableAndAutoAssignPapersUsecase(
///   publishUsecase: publishUsecase,
///   timetableRepository: repository,
///   teacherSubjectRepository: teacherRepo,
///   userRepository: userRepo,
///   autoAssignUsecase: autoAssignUsecase,
///   logger: logger,
/// );
/// final result = await usecase(
///   params: PublishTimetableAndAutoAssignPapersParams(
///     timetableId: 'timetable-123',
///   ),
/// );
/// result.fold(
///   (failure) => print('Error: ${failure.message}'),
///   (result) {
///     print('Timetable published: ${result.timetable.examName}');
///     print('Papers auto-assigned: ${result.autoAssignedPapersCount}');
///   },
/// );
/// ```
class PublishTimetableAndAutoAssignPapersUsecase {
  final PublishExamTimetableUsecase _publishUsecase;
  final ExamTimetableRepository _timetableRepository;
  final TeacherSubjectRepository _teacherSubjectRepository;
  final UserRepository _userRepository;
  final AutoAssignQuestionPapersUsecase _autoAssignUsecase;
  final ILogger _logger;

  PublishTimetableAndAutoAssignPapersUsecase({
    required PublishExamTimetableUsecase publishUsecase,
    required ExamTimetableRepository timetableRepository,
    required TeacherSubjectRepository teacherSubjectRepository,
    required UserRepository userRepository,
    required AutoAssignQuestionPapersUsecase autoAssignUsecase,
    required ILogger logger,
  })  : _publishUsecase = publishUsecase,
        _timetableRepository = timetableRepository,
        _teacherSubjectRepository = teacherSubjectRepository,
        _userRepository = userRepository,
        _autoAssignUsecase = autoAssignUsecase,
        _logger = logger;

  /// Execute publish and auto-assign
  Future<Either<Failure, PublishTimetableAndAutoAssignPapersResult>> call({
    required PublishTimetableAndAutoAssignPapersParams params,
  }) async {
    try {
      // Step 1: Publish the timetable
      final publishResult = await _publishUsecase(
        params: PublishExamTimetableParams(timetableId: params.timetableId),
      );

      return await publishResult.fold(
        (failure) => Left(failure),
        (publishedTimetable) async {
          // Step 2: Auto-assign papers after successful publish
          return await _autoAssignPapersAfterPublish(
            timetable: publishedTimetable,
            params: params,
          );
        },
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Error in publish and auto-assign',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(ServerFailure('Failed to publish and auto-assign: ${e.toString()}'));
    }
  }

  /// After successful publish, fetch entries and auto-assign papers
  Future<Either<Failure, PublishTimetableAndAutoAssignPapersResult>>
      _autoAssignPapersAfterPublish({
    required ExamTimetableEntity timetable,
    required PublishTimetableAndAutoAssignPapersParams params,
  }) async {
    try {
      _logger.info(
        'Starting auto-assignment of papers',
        context: {'timetableId': timetable.id},
      );

      // Fetch all exam entries for this timetable
      final entriesResult = await _timetableRepository.getExamTimetableEntries(timetable.id);

      final entries = await entriesResult.fold(
        (failure) async {
          _logger.warning(
            'Failed to fetch exam entries for auto-assignment',
            context: {'timetableId': timetable.id, 'error': failure.message},
          );
          return <ExamTimetableEntryEntity>[];
        },
        (entries) async => entries,
      );

      if (entries.isEmpty) {
        _logger.info(
          'No exam entries found for auto-assignment',
          context: {'timetableId': timetable.id},
        );
        return Right(
          PublishTimetableAndAutoAssignPapersResult(
            timetable: timetable,
            autoAssignedPapersCount: 0,
          ),
        );
      }

      // Step 2: For each entry, fetch teachers and build timetableEntries data
      final timetableEntriesForAssignment = <Map<String, dynamic>>[];

      for (final entry in entries) {
        if (!entry.isActive || entry.gradeId == null) continue;

        // Get teachers assigned to this grade/section/subject
        // IMPORTANT: Use the actual section value from the entry (can be null, 'A', 'B', etc.)
        // Do NOT default to 'A' - that would cause mismatches with teacher assignments
        final section = entry.section ?? '';
        _logger.info(
          'Querying teachers',
          context: {
            'gradeId': entry.gradeId,
            'gradeNumber': entry.gradeNumber,
            'subjectId': entry.subjectId,
            'subjectName': entry.subjectName,
            'section': section.isEmpty ? '(empty/null)' : section,
            'academicYear': timetable.academicYear,
            'tenantId': timetable.tenantId,
          },
        );

        final teachersResult = await _teacherSubjectRepository.getTeachersFor(
          tenantId: timetable.tenantId,
          gradeId: entry.gradeId!,
          subjectId: entry.subjectId,
          section: section,
          academicYear: timetable.academicYear,
          activeOnly: true,
        );

        final teachers = await teachersResult.fold(
          (failure) async {
            _logger.warning(
              'Failed to fetch teachers for entry',
              context: {
                'entryId': entry.id,
                'gradeId': entry.gradeId,
                'gradeNumber': entry.gradeNumber,
                'subjectId': entry.subjectId,
                'subjectName': entry.subjectName,
                'section': section,
                'error': failure.toString(),
              },
            );
            return <Map<String, dynamic>>[];
          },
          (teacherSubjects) async {
            _logger.info(
              'Found teachers for entry',
              context: {
                'entryId': entry.id,
                'count': teacherSubjects.length,
                'gradeNumber': entry.gradeNumber,
                'subjectName': entry.subjectName,
                'section': section,
              },
            );
            // Fetch teacher names
            final teacherMaps = <Map<String, dynamic>>[];
            for (final ts in teacherSubjects) {
              final userResult = await _userRepository.getUserById(ts.teacherId);
              final fullName = await userResult.fold(
                (_) => ts.teacherId, // Fallback to ID if fetch fails
                (user) => user?.fullName ?? ts.teacherId,
              );
              teacherMaps.add({
                'teacher_id': ts.teacherId,
                'teacher_name': fullName,
              });
            }
            return teacherMaps;
          },
        );

        // Build entry data for auto-assignment
        timetableEntriesForAssignment.add({
          'id': entry.id,
          'grade_id': entry.gradeId,
          'grade_number': entry.gradeNumber,
          'subject_id': entry.subjectId,
          'subject_name': entry.subjectName,
          'section': entry.section,
          'exam_date': entry.examDate.toIso8601String(),
          'exam_type': timetable.examType,
          'exam_number': timetable.examNumber,
          'teachers': teachers,
        });
      }

      _logger.info(
        'Prepared entries for auto-assignment',
        context: {
          'timetableId': timetable.id,
          'entriesCount': timetableEntriesForAssignment.length,
        },
      );

      // Step 3: Call auto-assignment usecase
      if (timetableEntriesForAssignment.isEmpty) {
        return Right(
          PublishTimetableAndAutoAssignPapersResult(
            timetable: timetable,
            autoAssignedPapersCount: 0,
          ),
        );
      }

      final autoAssignResult = await _autoAssignUsecase(
        params: AutoAssignQuestionPapersParams(
          timetableId: timetable.id,
          tenantId: timetable.tenantId,
          timetableEntries: timetableEntriesForAssignment,
          academicYear: timetable.academicYear,
        ),
      );

      return autoAssignResult.fold(
        (failure) {
          _logger.error(
            'Auto-assignment failed after successful publish',
            context: {
              'timetableId': timetable.id,
              'error': failure.message,
            },
          );
          // Don't fail the whole operation - timetable is already published
          // Just return with 0 papers assigned
          return Right(
            PublishTimetableAndAutoAssignPapersResult(
              timetable: timetable,
              autoAssignedPapersCount: 0,
            ),
          );
        },
        (assignedPapers) {
          _logger.info(
            'Successfully auto-assigned papers',
            context: {
              'timetableId': timetable.id,
              'papersCount': assignedPapers.length,
            },
          );
          return Right(
            PublishTimetableAndAutoAssignPapersResult(
              timetable: timetable,
              autoAssignedPapersCount: assignedPapers.length,
            ),
          );
        },
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Error during auto-assignment after publish',
        error: e,
        stackTrace: stackTrace,
      );
      // Return published timetable even if auto-assignment fails
      return Right(
        PublishTimetableAndAutoAssignPapersResult(
          timetable: timetable,
          autoAssignedPapersCount: 0,
        ),
      );
    }
  }
}

/// Parameters for PublishTimetableAndAutoAssignPapersUsecase
class PublishTimetableAndAutoAssignPapersParams {
  final String timetableId;

  PublishTimetableAndAutoAssignPapersParams({required this.timetableId});
}

/// Result of publishing timetable and auto-assigning papers
class PublishTimetableAndAutoAssignPapersResult {
  final ExamTimetableEntity timetable;
  final int autoAssignedPapersCount;

  PublishTimetableAndAutoAssignPapersResult({
    required this.timetable,
    required this.autoAssignedPapersCount,
  });
}
