import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../../domain/entities/exam_timetable.dart';
import '../../domain/entities/exam_timetable_entry.dart';
import '../../domain/repositories/exam_timetable_repository.dart';
import '../../domain/services/paper_auto_creation_service.dart';
import '../../../assignments/domain/repositories/teacher_subject_repository.dart';

/// Implementation of PaperAutoCreationService
///
/// This service:
/// 1. Gets all entries from published timetable
/// 2. For each entry, finds teachers assigned to (grade, subject, section)
/// 3. Creates DRAFT papers for each teacher
/// 4. Sends notifications
/// 5. Returns summary
///
/// Dependencies injected:
/// - ExamTimetableRepository: Get timetable and entries
/// - TeacherSubjectRepository: Find teachers for each entry
/// - QuestionPaperRepository: Create papers (from existing system)
/// - NotificationRepository: Send notifications (from existing system)
///
/// Note: Actual question paper creation is delegated to existing system
class PaperAutoCreationServiceImpl implements PaperAutoCreationService {
  final ExamTimetableRepository examTimetableRepository;
  final TeacherSubjectRepository teacherSubjectRepository;

  // These would be injected in production:
  // final QuestionPaperRepository questionPaperRepository;
  // final NotificationRepository notificationRepository;

  PaperAutoCreationServiceImpl({
    required this.examTimetableRepository,
    required this.teacherSubjectRepository,
  });

  @override
  Future<Either<Failure, PaperCreationResult>> createPapersForTimetable({
    required String timetableId,
    required String tenantId,
    DateTime? examDate,
  }) async {
    try {
      // Step 1: Get timetable
      final timetableResult = await examTimetableRepository.getTimetableById(timetableId);
      final timetable = timetableResult.fold(
        (failure) => throw Exception(failure.message),
        (timetable) {
          if (timetable == null) throw Exception('Timetable not found');
          return timetable;
        },
      );

      // Step 2: Get all entries
      final entriesResult = await examTimetableRepository.getTimetableEntries(timetableId);
      final entries = entriesResult.fold(
        (failure) => throw Exception(failure.message),
        (entries) => entries,
      );

      if (entries.isEmpty) {
        return const Left(
          ValidationFailure('Timetable has no entries'),
        );
      }

      // Step 3: Process each entry and create papers
      int totalPapersCreated = 0;
      final entriesWithoutTeachers = <String>[];

      for (final entry in entries) {
        // Find teachers for this (grade, subject, section)
        final teachersResult = await teacherSubjectRepository.getTeachersFor(
          tenantId: tenantId,
          gradeId: entry.gradeId,
          subjectId: entry.subjectId,
          section: entry.section,
          academicYear: timetable.academicYear,
          activeOnly: true,
        );

        final teachers = teachersResult.fold(
          (failure) => <dynamic>[],
          (teachers) => teachers,
        );

        if (teachers.isEmpty) {
          entriesWithoutTeachers.add(entry.displayName);
          continue; // Skip this entry, no teachers
        }

        // Create paper for each teacher
        // NOTE: In production, this would call QuestionPaperRepository
        // For now, we just count the papers that would be created
        totalPapersCreated += teachers.length;

        // Send notification to each teacher
        // NOTE: In production, this would call NotificationRepository
        // For each teacher, send: "New paper created: [Subject] Grade [Grade]-[Section]"
      }

      // Step 4: Return result
      final result = PaperCreationResult(
        totalPapersCreated: totalPapersCreated,
        entriesProcessed: entries.length,
        entriesWithNoTeachers: entriesWithoutTeachers.length,
        entriesWithoutTeachersNames: entriesWithoutTeachers,
        createdAt: DateTime.now(),
      );

      // If some entries have no teachers, return failure
      if (entriesWithoutTeachers.isNotEmpty) {
        return Left(
          ValidationFailure(
            'Cannot publish: No teachers assigned to:\n${entriesWithoutTeachers.join('\n')}',
          ),
        );
      }

      return Right(result);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to create papers: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, PaperCreationSummary>> getSummaryForTimetable({
    required String timetableId,
    required String tenantId,
  }) async {
    try {
      // Step 1: Get timetable
      final timetableResult = await examTimetableRepository.getTimetableById(timetableId);
      final timetable = timetableResult.fold(
        (failure) => throw Exception(failure.message),
        (timetable) {
          if (timetable == null) throw Exception('Timetable not found');
          return timetable;
        },
      );

      // Step 2: Get all entries
      final entriesResult = await examTimetableRepository.getTimetableEntries(timetableId);
      final entries = entriesResult.fold(
        (failure) => throw Exception(failure.message),
        (entries) => entries,
      );

      // Step 3: For each entry, count teachers
      int totalExpectedPapers = 0;
      int entriesWithTeachers = 0;
      final entryDetails = <EntryWithTeachers>[];
      final problematicEntries = <String>[];

      for (final entry in entries) {
        // Find teachers for this (grade, subject, section)
        final teachersResult = await teacherSubjectRepository.getTeachersFor(
          tenantId: tenantId,
          gradeId: entry.gradeId,
          subjectId: entry.subjectId,
          section: entry.section,
          academicYear: timetable.academicYear,
          activeOnly: true,
        );

        final teachers = teachersResult.fold(
          (failure) => <dynamic>[],
          (teachers) => teachers,
        );

        if (teachers.isEmpty) {
          problematicEntries.add(entry.displayName);
          entryDetails.add(
            EntryWithTeachers(
              entryId: entry.id,
              displayName: entry.displayName,
              teacherCount: 0,
              teacherNames: [],
            ),
          );
        } else {
          entriesWithTeachers++;
          totalExpectedPapers += teachers.length;

          // Extract teacher names if available in entity
          final teacherNames = <String>[];
          // Note: TeacherSubject entity has teacherId, but not teacher name
          // In production, would need to fetch teacher names separately

          entryDetails.add(
            EntryWithTeachers(
              entryId: entry.id,
              displayName: entry.displayName,
              teacherCount: teachers.length,
              teacherNames: teacherNames,
            ),
          );
        }
      }

      final summary = PaperCreationSummary(
        expectedPaperCount: totalExpectedPapers,
        entryCount: entries.length,
        entriesWithTeachers: entriesWithTeachers,
        entriesWithoutTeachers: problematicEntries.length,
        entries: entryDetails,
        problematicEntries: problematicEntries,
      );

      return Right(summary);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to get summary: ${e.toString()}'),
      );
    }
  }
}
