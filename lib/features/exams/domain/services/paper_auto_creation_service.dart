import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
/// Result of paper auto-creation
class PaperCreationResult {
  final int totalPapersCreated;
  final int entriesProcessed;
  final int entriesWithNoTeachers;
  final List<String> entriesWithoutTeachersNames;
  final DateTime createdAt;

  PaperCreationResult({
    required this.totalPapersCreated,
    required this.entriesProcessed,
    required this.entriesWithNoTeachers,
    required this.entriesWithoutTeachersNames,
    required this.createdAt,
  });

  bool get success => entriesWithNoTeachers == 0;
}

/// Service for automatically creating papers when timetable is published
///
/// Workflow:
/// 1. Admin publishes timetable
/// 2. PaperAutoCreationService is called
/// 3. For each entry in timetable:
///    - Find all teachers assigned to (grade, subject, section)
///    - Create DRAFT paper for each teacher
/// 4. Send notifications
/// 5. Return summary
///
/// This service is injected into PublishExamTimetableUseCase
/// and handles all paper creation logic
abstract class PaperAutoCreationService {
  /// Create papers for all entries in a timetable
  ///
  /// [timetableId] - ID of timetable being published
  /// [examDate] - Date of exam (optional, used for paper metadata)
  ///
  /// Returns:
  /// - Right(PaperCreationResult) if successful
  /// - Left(Failure) if system error
  ///
  /// Note: Validates that all entries have teachers before creating papers
  /// If any entry has no teachers, returns Left(ValidationFailure)
  Future<Either<Failure, PaperCreationResult>> createPapersForTimetable({
    required String timetableId,
    required String tenantId,
    DateTime? examDate,
  });

  /// Get summary of what papers WILL be created (without creating them)
  ///
  /// Used for confirmation dialog:
  /// "Publishing will create X papers for Y entries"
  ///
  /// Also identifies entries with missing teachers:
  /// "⚠️ No teacher assigned to Grade 5-A Maths"
  Future<Either<Failure, PaperCreationSummary>> getSummaryForTimetable({
    required String timetableId,
    required String tenantId,
  });
}

/// Summary of papers that would be created
class PaperCreationSummary {
  final int expectedPaperCount;
  final int entryCount;
  final int entriesWithTeachers;
  final int entriesWithoutTeachers;
  final List<EntryWithTeachers> entries;
  final List<String> problematicEntries; // Entries with no teachers

  PaperCreationSummary({
    required this.expectedPaperCount,
    required this.entryCount,
    required this.entriesWithTeachers,
    required this.entriesWithoutTeachers,
    required this.entries,
    required this.problematicEntries,
  });

  bool get canPublish => entriesWithoutTeachers == 0;
}

/// Details for each entry
class EntryWithTeachers {
  final String entryId;
  final String displayName; // "Grade 5-A Maths"
  final int teacherCount;
  final List<String> teacherNames;

  EntryWithTeachers({
    required this.entryId,
    required this.displayName,
    required this.teacherCount,
    required this.teacherNames,
  });
}
