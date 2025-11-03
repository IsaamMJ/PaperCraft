# Exam Timetable System - Backend Architecture

## Overview

This document outlines the backend service layer architecture for the exam timetable system, including Dart entity models, repository patterns, use cases, and API interactions.

---

## Architecture Layers

```
┌─────────────────────────────────────────┐
│         Presentation Layer              │
│   (Flutter UI, BLoCs, Pages)            │
└─────────────┬───────────────────────────┘
              │
┌─────────────▼───────────────────────────┐
│         Application Layer               │
│   (BLoCs, State Management)             │
└─────────────┬───────────────────────────┘
              │
┌─────────────▼───────────────────────────┐
│         Domain Layer                    │
│   (Entities, Use Cases, Interfaces)     │
└─────────────┬───────────────────────────┘
              │
┌─────────────▼───────────────────────────┐
│         Data Layer                      │
│   (Repositories, API Client, Cache)     │
└─────────────┬───────────────────────────┘
              │
         Supabase DB
```

---

## Domain Layer - Entity Models

### 1. GradeSection Entity

**Path**: `lib/features/catalog/domain/entities/grade_section.dart`

```dart
class GradeSection {
  final String id;
  final String tenantId;
  final String gradeId;
  final String sectionName;
  final int displayOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  GradeSection({
    required this.id,
    required this.tenantId,
    required this.gradeId,
    required this.sectionName,
    required this.displayOrder,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  GradeSection copyWith({
    String? id,
    String? tenantId,
    String? gradeId,
    String? sectionName,
    int? displayOrder,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    // Implementation
  }
}
```

### 2. TeacherSubject Entity

**Path**: `lib/features/assignments/domain/entities/teacher_subject.dart`

```dart
class TeacherSubject {
  final String id;
  final String tenantId;
  final String teacherId;
  final String gradeId;
  final String subjectId;
  final String section;
  final String academicYear;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  TeacherSubject({
    required this.id,
    required this.tenantId,
    required this.teacherId,
    required this.gradeId,
    required this.subjectId,
    required this.section,
    required this.academicYear,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  // With reference to related entities (for UI convenience)
  final Grade? grade;
  final Subject? subject;
  final String? teacherName; // From profiles table

  TeacherSubject copyWith({
    // Implementation
  });

  String get displayName => '$gradeId-$section $subjectId';
}
```

### 3. ExamCalendar Entity

**Path**: `lib/features/exams/domain/entities/exam_calendar.dart`

```dart
class ExamCalendar {
  final String id;
  final String tenantId;
  final String examName;
  final String examType; // monthlyTest, quarterlyTest, finalExam, etc.
  final int monthNumber; // 1-12
  final DateTime plannedStartDate;
  final DateTime plannedEndDate;
  final DateTime? paperSubmissionDeadline;
  final int displayOrder;
  final Map<String, dynamic>? metadata;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExamCalendar({
    required this.id,
    required this.tenantId,
    required this.examName,
    required this.examType,
    required this.monthNumber,
    required this.plannedStartDate,
    required this.plannedEndDate,
    this.paperSubmissionDeadline,
    required this.displayOrder,
    this.metadata,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isUpcoming => DateTime.now().isBefore(plannedStartDate);
  bool get isPastDeadline => paperSubmissionDeadline != null &&
      DateTime.now().isAfter(paperSubmissionDeadline!);

  ExamCalendar copyWith({
    // Implementation
  });
}
```

### 4. ExamTimetable Entity

**Path**: `lib/features/exams/domain/entities/exam_timetable.dart`

```dart
enum TimetableStatus { draft, published, completed, cancelled }

class ExamTimetable {
  final String id;
  final String tenantId;
  final String createdBy;
  final String? examCalendarId;
  final String examName;
  final String examType;
  final int? examNumber; // For daily tests: week number
  final String academicYear;
  final TimetableStatus status;
  final DateTime? publishedAt;
  final bool isActive;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExamTimetable({
    required this.id,
    required this.tenantId,
    required this.createdBy,
    this.examCalendarId,
    required this.examName,
    required this.examType,
    this.examNumber,
    required this.academicYear,
    required this.status,
    this.publishedAt,
    required this.isActive,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDraft => status == TimetableStatus.draft;
  bool get isPublished => status == TimetableStatus.published;
  bool get canEdit => status == TimetableStatus.draft;

  String get displayName => examNumber != null
      ? '$examName - Week $examNumber'
      : examName;

  ExamTimetable copyWith({
    // Implementation
  });
}
```

### 5. ExamTimetableEntry Entity

**Path**: `lib/features/exams/domain/entities/exam_timetable_entry.dart`

```dart
class ExamTimetableEntry {
  final String id;
  final String tenantId;
  final String timetableId;
  final String gradeId;
  final String subjectId;
  final String section;
  final DateTime examDate;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int durationMinutes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExamTimetableEntry({
    required this.id,
    required this.tenantId,
    required this.timetableId,
    required this.gradeId,
    required this.subjectId,
    required this.section,
    required this.examDate,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  String get displayName => '$gradeId-$section $subjectId';
  String get timeRange => '${startTime.format(context)} - ${endTime.format(context)}';

  ExamTimetableEntry copyWith({
    // Implementation
  });
}
```

---

## Use Cases

### 1. LoadGradeSectionsUseCase

**Path**: `lib/features/catalog/domain/usecases/load_grade_sections_usecase.dart`

```dart
class LoadGradeSectionsUseCase {
  final GradeSectionRepository repository;

  LoadGradeSectionsUseCase(this.repository);

  Future<Either<Failure, List<GradeSection>>> call({
    required String tenantId,
    String? gradeId,
  }) async {
    return await repository.getGradeSections(
      tenantId: tenantId,
      gradeId: gradeId,
      activeOnly: true,
    );
  }
}
```

### 2. SaveTeacherSubjectsUseCase

**Path**: `lib/features/assignments/domain/usecases/save_teacher_subjects_usecase.dart`

```dart
class SaveTeacherSubjectsUseCase {
  final TeacherSubjectRepository repository;
  final TeacherSubjectValidator validator;

  SaveTeacherSubjectsUseCase(this.repository, this.validator);

  Future<Either<Failure, void>> call({
    required String tenantId,
    required String teacherId,
    required String academicYear,
    required List<TeacherSubject> assignments,
  }) async {
    // Validate assignments
    final validationResult = validator.validate(assignments);
    if (validationResult.isFailure) {
      return Left(validationResult.failure);
    }

    // Save to repository
    return await repository.saveTeacherSubjects(
      tenantId: tenantId,
      teacherId: teacherId,
      academicYear: academicYear,
      assignments: assignments,
    );
  }
}
```

**Validation Logic**:
- Verify each (grade, subject, section) tuple exists
- Check grade-subject compatibility using subject_catalog.min_grade/max_grade
- Ensure no duplicate tuples

### 3. CreateExamTimetableUseCase

**Path**: `lib/features/exams/domain/usecases/create_exam_timetable_usecase.dart`

```dart
class CreateExamTimetableUseCase {
  final ExamTimetableRepository repository;

  CreateExamTimetableUseCase(this.repository);

  Future<Either<Failure, ExamTimetable>> call({
    required String tenantId,
    required String createdBy,
    required String examName,
    required String examType,
    String? examCalendarId,
    int? examNumber,
    required String academicYear,
    Map<String, dynamic>? metadata,
  }) async {
    final timetable = ExamTimetable(
      id: '', // Will be generated by DB
      tenantId: tenantId,
      createdBy: createdBy,
      examCalendarId: examCalendarId,
      examName: examName,
      examType: examType,
      examNumber: examNumber,
      academicYear: academicYear,
      status: TimetableStatus.draft,
      publishedAt: null,
      isActive: true,
      metadata: metadata,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return await repository.createTimetable(timetable);
  }
}
```

### 4. PublishExamTimetableUseCase

**Path**: `lib/features/exams/domain/usecases/publish_exam_timetable_usecase.dart`

```dart
class PublishExamTimetableUseCase {
  final ExamTimetableRepository timetableRepository;
  final QuestionPaperRepository paperRepository;
  final TeacherSubjectRepository teacherRepository;
  final NotificationRepository notificationRepository;

  PublishExamTimetableUseCase(
    this.timetableRepository,
    this.paperRepository,
    this.teacherRepository,
    this.notificationRepository,
  );

  Future<Either<Failure, void>> call({
    required String timetableId,
  }) async {
    try {
      // Step 1: Get timetable
      final timetable = await timetableRepository.getTimetableById(timetableId);
      if (timetable == null) {
        return Left(TimetableNotFoundFailure());
      }

      // Step 2: Get all entries for this timetable
      final entries = await timetableRepository.getTimetableEntries(timetableId);

      // Step 3: Validate - ensure each entry has at least one teacher assigned
      for (final entry in entries) {
        final teachers = await teacherRepository.getTeachersFor(
          tenantId: timetable.tenantId,
          gradeId: entry.gradeId,
          subjectId: entry.subjectId,
          section: entry.section,
          academicYear: timetable.academicYear,
        );

        if (teachers.isEmpty) {
          return Left(NoTeacherAssignedFailure(
            message: 'No teacher assigned to ${entry.displayName}',
          ));
        }
      }

      // Step 4: Create papers (async if 500+ entries)
      if (entries.length > 500) {
        // Queue background job
        await _queuePaperCreationJob(timetable, entries);
      } else {
        // Create synchronously
        await _createPapersForEntries(timetable, entries);
      }

      // Step 5: Update timetable status
      await timetableRepository.updateTimetableStatus(
        timetableId: timetableId,
        status: TimetableStatus.published,
        publishedAt: DateTime.now(),
      );

      // Step 6: Send notifications
      await notificationRepository.sendBulkNotifications(
        notifications: _buildNotifications(timetable, entries),
      );

      return Right(null);
    } catch (e) {
      return Left(PublishTimetableFailure(e.toString()));
    }
  }

  Future<void> _createPapersForEntries(
    ExamTimetable timetable,
    List<ExamTimetableEntry> entries,
  ) async {
    for (final entry in entries) {
      final teachers = await teacherRepository.getTeachersFor(
        tenantId: timetable.tenantId,
        gradeId: entry.gradeId,
        subjectId: entry.subjectId,
        section: entry.section,
        academicYear: timetable.academicYear,
      );

      for (final teacher in teachers) {
        final paper = QuestionPaper(
          id: '', // Generated by DB
          tenantId: timetable.tenantId,
          userId: teacher.teacherId,
          subjectId: entry.subjectId,
          gradeId: entry.gradeId,
          section: entry.section,
          academicYear: timetable.academicYear,
          title: '${entry.subjectId} - ${timetable.examName}',
          examDate: entry.examDate,
          examType: timetable.examType,
          examNumber: timetable.examNumber,
          status: QuestionPaperStatus.draft,
          questions: [],
          paperSections: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await paperRepository.createPaper(paper);
      }
    }
  }

  Future<void> _queuePaperCreationJob(
    ExamTimetable timetable,
    List<ExamTimetableEntry> entries,
  ) async {
    // Implementation of background job queuing
    // This depends on your job queue system (e.g., Firestore, dedicated service)
  }

  List<Notification> _buildNotifications(
    ExamTimetable timetable,
    List<ExamTimetableEntry> entries,
  ) {
    // Build notifications for all teachers whose papers were created
    // Implementation
  }
}
```

### 5. ValidateTeacherSubjectsUseCase

**Path**: `lib/features/assignments/domain/usecases/validate_teacher_subjects_usecase.dart`

```dart
class ValidateTeacherSubjectsUseCase {
  final SubjectCatalogRepository catalogRepository;

  ValidateTeacherSubjectsUseCase(this.catalogRepository);

  Future<Either<Failure, List<ValidationError>>> call({
    required List<TeacherSubject> assignments,
  }) async {
    final errors = <ValidationError>[];

    for (final assignment in assignments) {
      // Check if grade is in valid range for subject
      final subject = await catalogRepository.getSubjectById(
        assignment.subjectId,
      );

      if (subject == null) {
        errors.add(ValidationError(
          field: 'subjectId',
          message: 'Subject not found: ${assignment.subjectId}',
        ));
        continue;
      }

      final grade = int.tryParse(
        assignment.gradeId.replaceAll(RegExp(r'[^0-9]'), ''),
      );

      if (grade != null &&
          (grade < subject.minGrade || grade > subject.maxGrade)) {
        errors.add(ValidationError(
          field: 'gradeId',
          message: '${subject.name} is not available for Grade $grade '
              '(available: ${subject.minGrade}-${subject.maxGrade})',
        ));
      }
    }

    if (errors.isEmpty) {
      return Right([]);
    }
    return Left(ValidationFailure(errors: errors));
  }
}
```

---

## Repository Interfaces

### 1. GradeSectionRepository

**Path**: `lib/features/catalog/domain/repositories/grade_section_repository.dart`

```dart
abstract class GradeSectionRepository {
  Future<Either<Failure, List<GradeSection>>> getGradeSections({
    required String tenantId,
    String? gradeId,
    bool activeOnly = true,
  });

  Future<Either<Failure, GradeSection>> getGradeSectionById(String id);

  Future<Either<Failure, GradeSection>> createGradeSection(
    GradeSection section,
  );

  Future<Either<Failure, void>> updateGradeSection(GradeSection section);

  Future<Either<Failure, void>> deleteGradeSection(String id);
}
```

### 2. TeacherSubjectRepository

**Path**: `lib/features/assignments/domain/repositories/teacher_subject_repository.dart`

```dart
abstract class TeacherSubjectRepository {
  Future<Either<Failure, List<TeacherSubject>>> getTeacherSubjects({
    required String tenantId,
    String? teacherId,
    String? academicYear,
    bool activeOnly = true,
  });

  Future<Either<Failure, void>> saveTeacherSubjects({
    required String tenantId,
    required String teacherId,
    required String academicYear,
    required List<TeacherSubject> assignments,
  });

  Future<Either<Failure, List<TeacherSubject>>> getTeachersFor({
    required String tenantId,
    required String gradeId,
    required String subjectId,
    required String section,
    required String academicYear,
    bool activeOnly = true,
  });

  Future<Either<Failure, void>> deactivateTeacherSubject(String id);
}
```

### 3. ExamTimetableRepository

**Path**: `lib/features/exams/domain/repositories/exam_timetable_repository.dart`

```dart
abstract class ExamTimetableRepository {
  Future<Either<Failure, ExamTimetable>> createTimetable(
    ExamTimetable timetable,
  );

  Future<Either<Failure, ExamTimetable>> getTimetableById(String id);

  Future<Either<Failure, List<ExamTimetable>>> getTimetablesForTenant({
    required String tenantId,
    String? academicYear,
    TimetableStatus? status,
  });

  Future<Either<Failure, void>> addTimetableEntry(
    ExamTimetableEntry entry,
  );

  Future<Either<Failure, List<ExamTimetableEntry>>> getTimetableEntries(
    String timetableId,
  );

  Future<Either<Failure, void>> updateTimetableStatus({
    required String timetableId,
    required TimetableStatus status,
    DateTime? publishedAt,
  });

  Future<Either<Failure, void>> removeTimetableEntry(String entryId);
}
```

---

## Data Layer - API Client Methods

### 1. Create Grade Section

```dart
Future<GradeSection> createGradeSection(
  String tenantId,
  String gradeId,
  String sectionName,
  int displayOrder,
) async {
  final response = await apiClient.create<GradeSection>(
    table: 'grade_sections',
    data: {
      'tenant_id': tenantId,
      'grade_id': gradeId,
      'section_name': sectionName,
      'display_order': displayOrder,
      'is_active': true,
    },
    fromJson: (json) => GradeSection.fromJson(json),
  );
  return response;
}
```

### 2. Get Teacher Subjects

```dart
Future<List<TeacherSubject>> getTeacherSubjects({
  required String tenantId,
  required String teacherId,
  required String academicYear,
}) async {
  final response = await apiClient.select<TeacherSubject>(
    table: 'teacher_subjects',
    filters: {
      'tenant_id': tenantId,
      'teacher_id': teacherId,
      'academic_year': academicYear,
      'is_active': true,
    },
    fromJson: (json) => TeacherSubject.fromJson(json),
  );
  return response;
}
```

### 3. Save Teacher Subjects (Bulk Operation)

```dart
Future<void> saveTeacherSubjects({
  required String tenantId,
  required String teacherId,
  required String academicYear,
  required List<Map<String, dynamic>> assignments,
}) async {
  // Step 1: Delete existing assignments for this year
  await apiClient.delete(
    table: 'teacher_subjects',
    filters: {
      'tenant_id': tenantId,
      'teacher_id': teacherId,
      'academic_year': academicYear,
    },
  );

  // Step 2: Insert new assignments (use batch insert for performance)
  await apiClient.batchInsert(
    table: 'teacher_subjects',
    data: assignments,
  );
}
```

### 4. Find Teachers for Timetable Entry

```dart
Future<List<String>> getTeacherIdsFor({
  required String tenantId,
  required String gradeId,
  required String subjectId,
  required String section,
  required String academicYear,
}) async {
  final response = await apiClient.select<TeacherSubject>(
    table: 'teacher_subjects',
    filters: {
      'tenant_id': tenantId,
      'grade_id': gradeId,
      'subject_id': subjectId,
      'section': section,
      'academic_year': academicYear,
      'is_active': true,
    },
    select: 'teacher_id',
    fromJson: (json) => TeacherSubject.fromJson(json),
  );
  return response.map((ts) => ts.teacherId).toList();
}
```

### 5. Create Exam Timetable

```dart
Future<ExamTimetable> createExamTimetable(
  ExamTimetable timetable,
) async {
  final response = await apiClient.create<ExamTimetable>(
    table: 'exam_timetables',
    data: {
      'tenant_id': timetable.tenantId,
      'created_by': timetable.createdBy,
      'exam_calendar_id': timetable.examCalendarId,
      'exam_name': timetable.examName,
      'exam_type': timetable.examType,
      'exam_number': timetable.examNumber,
      'academic_year': timetable.academicYear,
      'status': timetable.status.toString(),
      'is_active': true,
      'metadata': timetable.metadata,
    },
    fromJson: (json) => ExamTimetable.fromJson(json),
  );
  return response;
}
```

### 6. Add Timetable Entry

```dart
Future<ExamTimetableEntry> addTimetableEntry(
  ExamTimetableEntry entry,
) async {
  final response = await apiClient.create<ExamTimetableEntry>(
    table: 'exam_timetable_entries',
    data: {
      'tenant_id': entry.tenantId,
      'timetable_id': entry.timetableId,
      'grade_id': entry.gradeId,
      'subject_id': entry.subjectId,
      'section': entry.section,
      'exam_date': entry.examDate.toIso8601String(),
      'start_time': _timeToString(entry.startTime),
      'end_time': _timeToString(entry.endTime),
      'duration_minutes': entry.durationMinutes,
      'is_active': true,
    },
    fromJson: (json) => ExamTimetableEntry.fromJson(json),
  );
  return response;
}

String _timeToString(TimeOfDay time) {
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}
```

### 7. Publish Timetable (Update Status)

```dart
Future<void> publishTimetable({
  required String timetableId,
}) async {
  await apiClient.update<void>(
    table: 'exam_timetables',
    data: {
      'status': 'published',
      'published_at': DateTime.now().toIso8601String(),
    },
    filters: {
      'id': timetableId,
    },
    fromJson: (_) => null,
  );
}
```

---

## Failure/Error Handling

### Custom Failures

```dart
abstract class ExamTimetableFailure extends Failure {
  ExamTimetableFailure(String message) : super(message);
}

class TimetableNotFoundFailure extends ExamTimetableFailure {
  TimetableNotFoundFailure() : super('Timetable not found');
}

class NoTeacherAssignedFailure extends ExamTimetableFailure {
  NoTeacherAssignedFailure({required String message}) : super(message);
}

class PublishTimetableFailure extends ExamTimetableFailure {
  PublishTimetableFailure(String message) : super('Failed to publish: $message');
}

class ValidationFailure extends ExamTimetableFailure {
  final List<ValidationError> errors;

  ValidationFailure({required this.errors})
      : super('Validation failed: ${errors.length} error(s)');
}

class ValidationError {
  final String field;
  final String message;

  ValidationError({required this.field, required this.message});
}
```

---

## Integration with Existing Systems

### 1. Connection with Question Papers

When publishing a timetable, the system creates DRAFT question papers:

```dart
// In PublishExamTimetableUseCase
final paper = QuestionPaper(
  id: '', // Generated by DB
  tenantId: timetable.tenantId,
  userId: teacher.teacherId,
  subject_id: entry.subjectId,
  grade_id: entry.gradeId,
  section: entry.section, // NEW FIELD
  academicYear: timetable.academicYear,
  title: '${entry.subjectName} - ${timetable.examName}',
  examDate: entry.examDate,
  examType: timetable.examType,
  examNumber: timetable.examNumber,
  status: 'draft',
  questions: jsonb_array_literal([]), // Empty JSON array
  paper_sections: jsonb_array_literal([]), // Empty JSON array
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);
```

### 2. Connection with Notifications

After papers are created, send notifications:

```dart
// In PublishExamTimetableUseCase
await notificationRepository.createNotification(
  userId: teacher.teacherId,
  tenantId: timetable.tenantId,
  type: NotificationType.paperCreated,
  title: 'New Paper Created',
  message: 'A new ${entry.subjectName} paper for Grade ${entry.gradeId}-${entry.section} has been assigned',
  data: {
    'paperId': paper.id,
    'examType': timetable.examType,
  },
);
```

### 3. Connection with Teacher Assignments

During onboarding, teachers now select teacher_subjects instead of separate grades + subjects:

```dart
// In TeacherProfileSetupPage
// OLD: Just select grades + subjects separately
// NEW: Select exact (grade, subject, section) tuples

List<TeacherSubject> selectedAssignments = [
  TeacherSubject(
    teacherId: userId,
    gradeId: 'Grade 5',
    subjectId: 'Maths',
    section: 'A',
    academicYear: '2024-2025',
  ),
  TeacherSubject(
    teacherId: userId,
    gradeId: 'Grade 5',
    subjectId: 'Maths',
    section: 'B',
    academicYear: '2024-2025',
  ),
];
```

---

## State Management (BLoC Layer)

### ExamTimetableBloc

```dart
class ExamTimetableBloc extends Bloc<ExamTimetableEvent, ExamTimetableState> {
  final CreateExamTimetableUseCase createTimetableUseCase;
  final PublishExamTimetableUseCase publishTimetableUseCase;

  ExamTimetableBloc({
    required this.createTimetableUseCase,
    required this.publishTimetableUseCase,
  }) : super(const ExamTimetableInitial()) {
    on<CreateTimetableEvent>(_onCreateTimetable);
    on<PublishTimetableEvent>(_onPublishTimetable);
    on<AddTimetableEntryEvent>(_onAddEntry);
  }

  Future<void> _onPublishTimetable(
    PublishTimetableEvent event,
    Emitter<ExamTimetableState> emit,
  ) async {
    emit(const PublishingTimetable());

    final result = await publishTimetableUseCase(
      timetableId: event.timetableId,
    );

    result.fold(
      (failure) {
        emit(PublishTimetableFailure(failure.message));
      },
      (_) {
        emit(PublishTimetableSuccess());
      },
    );
  }
}
```

---

## Database Transaction Handling

For critical operations like publishing (creating 500+ papers atomically):

```dart
Future<void> _publishTimetableTransaction(
  ExamTimetable timetable,
  List<ExamTimetableEntry> entries,
) async {
  // Use Supabase transaction or handle atomicity at app level
  try {
    // Update timetable status
    await timetableRepository.updateTimetableStatus(
      timetableId: timetable.id,
      status: TimetableStatus.published,
    );

    // Create all papers (with retry logic)
    await _createPapersWithRetry(timetable, entries);

    // Send notifications
    await _sendNotificationsWithRetry(timetable, entries);

  } catch (e) {
    // Log error and potentially rollback
    AppLogger.error('Publish timetable failed', error: e);
    rethrow;
  }
}
```

---

## Performance Optimization

### 1. Batch Operations

```dart
// Create multiple papers in single DB operation
Future<void> createPapersInBatch(List<QuestionPaper> papers) async {
  await apiClient.batchInsert(
    table: 'question_papers',
    data: papers.map((p) => p.toJson()).toList(),
  );
}
```

### 2. Query Optimization

```dart
// Use select to fetch only needed columns
Future<List<String>> getTeacherIdsFor(...) async {
  return await apiClient.select(
    table: 'teacher_subjects',
    select: 'teacher_id', // Only fetch teacher_id, not entire row
    filters: {...},
  );
}
```

### 3. Caching

```dart
// Cache exam calendar for the year
@override
Future<List<ExamCalendar>> getExamCalendar(...) async {
  final cached = _cache.get('exam_calendar_$year');
  if (cached != null) return cached;

  final result = await apiClient.select(...);
  _cache.set('exam_calendar_$year', result);
  return result;
}
```

---

## Testing Strategy

### Unit Tests

```dart
// test/features/exams/domain/usecases/publish_exam_timetable_usecase_test.dart

void main() {
  group('PublishExamTimetableUseCase', () {
    late PublishExamTimetableUseCase useCase;
    late MockExamTimetableRepository mockTimetableRepo;
    late MockTeacherSubjectRepository mockTeacherRepo;

    setUp(() {
      mockTimetableRepo = MockExamTimetableRepository();
      mockTeacherRepo = MockTeacherSubjectRepository();
      useCase = PublishExamTimetableUseCase(
        mockTimetableRepo,
        mockTeacherRepo,
      );
    });

    test('should fail if no teacher assigned to entry', () async {
      // Arrange
      when(mockTeacherRepo.getTeachersFor(...))
          .thenAnswer((_) async => []);

      // Act
      final result = await useCase(timetableId: 'test-id');

      // Assert
      expect(result, isA<Left<Failure, void>>());
    });

    test('should create papers for all assigned teachers', () async {
      // Arrange
      when(mockTeacherRepo.getTeachersFor(...))
          .thenAnswer((_) async => ['teacher1', 'teacher2']);

      // Act
      final result = await useCase(timetableId: 'test-id');

      // Assert
      expect(result, isA<Right<Failure, void>>());
      verify(mockPaperRepo.createPaper(...)).called(2);
    });
  });
}
```

### Integration Tests

Test complete flow from timetable creation to paper creation.

---

## Summary

This architecture provides:
- ✅ Clean separation of concerns (Domain, Data, Presentation)
- ✅ Reusable repository pattern
- ✅ Type-safe use cases
- ✅ Comprehensive error handling
- ✅ Scalable for bulk operations
- ✅ Easy testing with interfaces
- ✅ Natural integration with existing exam system
