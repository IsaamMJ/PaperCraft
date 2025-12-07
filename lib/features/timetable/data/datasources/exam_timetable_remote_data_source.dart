import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/domain/errors/failures.dart';
import '../../domain/entities/exam_calendar_entity.dart';
import '../../domain/entities/exam_calendar_grade_mapping_entity.dart';
import '../../domain/entities/exam_timetable_entity.dart';
import '../../domain/entities/exam_timetable_entry_entity.dart';
import '../models/exam_calendar_grade_mapping_model.dart';
import '../models/exam_calendar_model.dart';
import '../models/exam_timetable_entry_model.dart';
import '../models/exam_timetable_model.dart';

/// Abstract interface for exam timetable remote data operations
///
/// Defines all Supabase API methods for managing exam calendars, timetables, and entries.
/// Implementations use Either<Failure, T> for functional error handling.
abstract class ExamTimetableRemoteDataSource {
  // ===== EXAM CALENDAR OPERATIONS =====

  /// Get all exam calendars for a tenant
  ///
  /// Returns list of active calendars sorted by display_order
  Future<Either<Failure, List<ExamCalendarEntity>>> getExamCalendars(
    String tenantId,
  );

  /// Get a specific exam calendar by ID
  Future<Either<Failure, ExamCalendarEntity>> getExamCalendarById(
    String calendarId,
  );

  /// Create a new exam calendar
  Future<Either<Failure, ExamCalendarEntity>> createExamCalendar(
    ExamCalendarEntity calendar,
  );

  /// Update an existing exam calendar
  Future<Either<Failure, ExamCalendarEntity>> updateExamCalendar(
    ExamCalendarEntity calendar,
  );

  /// Soft delete an exam calendar (sets is_active to false)
  Future<Either<Failure, void>> deleteExamCalendar(String calendarId);

  /// Reactivate a soft-deleted calendar
  Future<Either<Failure, ExamCalendarEntity>> reactivateExamCalendar(
    String calendarId,
  );

  // ===== EXAM TIMETABLE OPERATIONS =====

  /// Get all exam timetables for a tenant, optionally filtered by academic year
  ///
  /// Returns timetables sorted by academic_year DESC
  Future<Either<Failure, List<ExamTimetableEntity>>> getExamTimetables(
    String tenantId, {
    String? academicYear,
  });

  /// Get a specific exam timetable by ID
  ///
  /// Includes all metadata and status information
  Future<Either<Failure, ExamTimetableEntity>> getExamTimetableById(
    String timetableId,
  );

  /// Create a new exam timetable (starts in draft status)
  Future<Either<Failure, ExamTimetableEntity>> createExamTimetable(
    ExamTimetableEntity timetable,
  );

  /// Update an existing exam timetable (only if in draft status)
  ///
  /// Prevents updates to published or archived timetables
  /// (This is a business logic check; RLS handles authorization)
  Future<Either<Failure, ExamTimetableEntity>> updateExamTimetable(
    ExamTimetableEntity timetable,
  );

  /// Publish an exam timetable (draft → published)
  ///
  /// Sets status to 'published' and publishedAt timestamp
  Future<Either<Failure, ExamTimetableEntity>> publishExamTimetable(
    String timetableId,
  );

  /// Archive an exam timetable (published → archived)
  ///
  /// Archived timetables are read-only, kept for records
  Future<Either<Failure, ExamTimetableEntity>> archiveExamTimetable(
    String timetableId,
  );

  /// Soft delete an exam timetable (sets is_active to false)
  ///
  /// Only draft timetables can be deleted
  Future<Either<Failure, void>> deleteExamTimetable(String timetableId);

  /// Reactivate a soft-deleted timetable
  Future<Either<Failure, ExamTimetableEntity>> reactivateExamTimetable(
    String timetableId,
  );

  // ===== EXAM TIMETABLE ENTRY OPERATIONS =====

  /// Get all entries for a specific timetable
  ///
  /// Returns entries sorted by exam_date ASC
  Future<Either<Failure, List<ExamTimetableEntryEntity>>>
      getExamTimetableEntries(String timetableId);

  /// Get a specific exam timetable entry by ID
  Future<Either<Failure, ExamTimetableEntryEntity>> getExamTimetableEntryById(
    String entryId,
  );

  /// Add a new exam entry to a timetable
  Future<Either<Failure, ExamTimetableEntryEntity>> addExamTimetableEntry(
    ExamTimetableEntryEntity entry,
  );

  /// Update an existing exam entry (only if timetable is draft)
  ///
  /// Prevents updates to entries in published timetables
  Future<Either<Failure, ExamTimetableEntryEntity>> updateExamTimetableEntry(
    ExamTimetableEntryEntity entry,
  );

  /// Soft delete an exam entry (sets is_active to false)
  ///
  /// Only entries in draft timetables can be deleted
  Future<Either<Failure, void>> deleteExamTimetableEntry(String entryId);

  /// Reactivate a soft-deleted entry
  Future<Either<Failure, ExamTimetableEntryEntity>>
      reactivateExamTimetableEntry(String entryId);

  /// Add multiple entries in one operation (bulk insert)
  ///
  /// Used for importing or creating timetables with many entries
  /// Returns all successfully created entries
  /// Rolls back on first validation error (transactional)
  Future<Either<Failure, List<ExamTimetableEntryEntity>>>
      addMultipleExamTimetableEntries(
    List<ExamTimetableEntryEntity> entries,
  );

  // ===== VALIDATION & UTILITY OPERATIONS =====

  /// Check if a grade+subject+date combination already exists in timetable
  ///
  /// Returns true if duplicate exists, false otherwise
  /// Used for real-time validation in UI
  Future<Either<Failure, bool>> checkDuplicateEntry(
    String timetableId,
    String gradeId,
    String subjectId,
    DateTime examDate,
    String section,
  );

  /// Get all duplicate entries for a timetable (for debugging/audit)
  ///
  /// Returns entries that violate unique constraint
  Future<Either<Failure, List<ExamTimetableEntryEntity>>> getDuplicateEntries(
    String timetableId,
  );

  /// Get statistics about a timetable
  ///
  /// Returns map with:
  /// - total_entries: int
  /// - active_entries: int
  /// - draft_entries: int (if applicable)
  /// - date_range: {start: DateTime, end: DateTime}
  /// - grades_covered: List<String>
  /// - subjects_covered: List<String>
  Future<Either<Failure, Map<String, dynamic>>> getExamTimetableStats(
    String timetableId,
  );

  /// Validate complete timetable before publishing
  ///
  /// Checks:
  /// - No duplicate entries
  /// - All entries have valid time ranges
  /// - All required fields filled
  /// - At least one entry exists
  ///
  /// Returns list of validation errors (empty if valid)
  Future<Either<Failure, List<String>>> validateExamTimetable(
    String timetableId,
  );

  /// Duplicate a timetable (copy structure for new academic year)
  ///
  /// Creates new timetable with same structure but:
  /// - New ID
  /// - New academicYear (must be provided)
  /// - Status: draft
  /// - New timestamps
  /// - Can adjust exam dates via dateOffset
  ///
  /// Returns newly created timetable
  Future<Either<Failure, ExamTimetableEntity>> duplicateExamTimetable(
    String sourceTimetableId,
    String newAcademicYear, {
    Duration? dateOffset,
  });

  // ===== EXAM CALENDAR GRADE MAPPING OPERATIONS (STEP 2) =====

  /// Get all grades mapped to an exam calendar
  ///
  /// Returns list of grade IDs that are associated with a specific calendar
  /// Used in Step 2 to show which grades are already selected
  Future<Either<Failure, List<String>>> getGradesForCalendar(
    String examCalendarId,
  );

  /// Add a grade to an exam calendar
  ///
  /// Creates a mapping entry for Step 2
  /// Returns the created mapping entity
  /// Throws error if grade already mapped to this calendar (unique constraint)
  Future<Either<Failure, ExamCalendarGradeMappingEntity>>
      addGradeToCalendar(
    String tenantId,
    String examCalendarId,
    String gradeId,
  );

  /// Add multiple grades to an exam calendar (bulk operation)
  ///
  /// Used for Step 2 when user selects multiple grades at once
  /// Returns all created mappings
  /// Rolls back on constraint violation
  Future<Either<Failure, List<ExamCalendarGradeMappingEntity>>>
      addGradesToCalendar(
    String tenantId,
    String examCalendarId,
    List<String> gradeIds,
  );

  /// Remove a grade from an exam calendar
  ///
  /// Soft deletes the mapping (sets is_active to false)
  Future<Either<Failure, void>> removeGradeFromCalendar(
    String examCalendarId,
    String gradeId,
  );

  /// Remove multiple grades from a calendar (bulk operation)
  ///
  /// Soft deletes multiple mappings at once
  Future<Either<Failure, void>> removeGradesFromCalendar(
    String examCalendarId,
    List<String> gradeIds,
  );

  /// Get all grade mappings for a calendar (including inactive)
  ///
  /// Includes soft-deleted mappings for audit trail
  Future<Either<Failure, List<ExamCalendarGradeMappingEntity>>>
      getCalendarGradeMappings(String examCalendarId);

  /// Check if a grade is already mapped to a calendar
  ///
  /// Returns true if mapping exists and is active
  Future<Either<Failure, bool>> isGradeMappedToCalendar(
    String examCalendarId,
    String gradeId,
  );

  // ===== SUBJECT VALIDATION OPERATIONS =====

  /// Get valid subjects for selected grade-section combinations
  ///
  /// Fetches all subjects offered in the given grade+section combinations
  /// from the grade_section_subject table, filtered by is_offered = true.
  ///
  /// Parameters:
  /// - tenantId: School tenant ID
  /// - selectedGradeSectionIds: List of grade_section UUIDs selected in Step 3
  ///
  /// Returns a map with key format "gradeNumber_section" and values as list of subject names
  Future<Either<Failure, Map<String, List<String>>>>
      getValidSubjectsForGradeSelection({
    required String tenantId,
    required List<String> selectedGradeSectionIds,
  });
}

/// Implementation of ExamTimetableRemoteDataSource using Supabase
///
/// All methods follow the Either<Failure, T> pattern for functional error handling.
/// Soft delete pattern is used instead of hard deletes to maintain audit trail.
class ExamTimetableRemoteDataSourceImpl implements ExamTimetableRemoteDataSource {
  final SupabaseClient _supabaseClient;

  ExamTimetableRemoteDataSourceImpl({
    required SupabaseClient supabaseClient,
  }) : _supabaseClient = supabaseClient;

  // ===== EXAM CALENDAR OPERATIONS =====

  @override
  Future<Either<Failure, List<ExamCalendarEntity>>> getExamCalendars(
    String tenantId,
  ) async {
    try {
      final response = await _supabaseClient
          .from('exam_calendar')
          .select()
          .eq('tenant_id', tenantId)
          .eq('is_active', true)
          .order('display_order', ascending: true);

      final calendars = (response as List<dynamic>)
          .map((json) => ExamCalendarModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return Right(calendars);
    } on PostgrestException catch (e) {
      return Left(_mapPostgrestException(e));
    } catch (e) {
      return Left(ServerFailure('Failed to fetch exam calendars: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ExamCalendarEntity>> getExamCalendarById(
    String calendarId,
  ) async {
    try {
      final response = await _supabaseClient
          .from('exam_calendar')
          .select()
          .eq('id', calendarId)
          .maybeSingle();

      if (response == null) {
        return Left(NotFoundFailure('Exam calendar not found'));
      }

      final calendar = ExamCalendarModel.fromJson(response as Map<String, dynamic>);
      return Right(calendar);
    } on PostgrestException catch (e) {
      return Left(_mapPostgrestException(e));
    } catch (e) {
      return Left(ServerFailure('Failed to fetch exam calendar: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ExamCalendarEntity>> createExamCalendar(
    ExamCalendarEntity calendar,
  ) async {
    try {
      final model = ExamCalendarModel.fromEntity(calendar);
      final response = await _supabaseClient
          .from('exam_calendar')
          .insert(model.toJson())
          .select()
          .single();

      final created = ExamCalendarModel.fromJson(response as Map<String, dynamic>);
      return Right(created);
    } on PostgrestException catch (e) {
      return Left(_mapPostgrestException(e));
    } catch (e) {
      return Left(ServerFailure('Failed to create exam calendar: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ExamCalendarEntity>> updateExamCalendar(
    ExamCalendarEntity calendar,
  ) async {
    try {
      final model = ExamCalendarModel.fromEntity(calendar);
      final response = await _supabaseClient
          .from('exam_calendar')
          .update(model.toJsonRequest())
          .eq('id', calendar.id)
          .select()
          .single();

      final updated = ExamCalendarModel.fromJson(response as Map<String, dynamic>);
      return Right(updated);
    } on PostgrestException catch (e) {
      return Left(_mapPostgrestException(e));
    } catch (e) {
      return Left(ServerFailure('Failed to update exam calendar: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteExamCalendar(String calendarId) async {
    try {
      await _supabaseClient
          .from('exam_calendar')
          .update({'is_active': false, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', calendarId);

      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(_mapPostgrestException(e));
    } catch (e) {
      return Left(ServerFailure('Failed to delete exam calendar: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ExamCalendarEntity>> reactivateExamCalendar(
    String calendarId,
  ) async {
    try {
      final response = await _supabaseClient
          .from('exam_calendar')
          .update({'is_active': true, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', calendarId)
          .select()
          .single();

      final reactivated = ExamCalendarModel.fromJson(response as Map<String, dynamic>);
      return Right(reactivated);
    } on PostgrestException catch (e) {
      return Left(_mapPostgrestException(e));
    } catch (e) {
      return Left(ServerFailure('Failed to reactivate exam calendar: ${e.toString()}'));
    }
  }

  // ===== EXAM TIMETABLE OPERATIONS =====

  @override
  Future<Either<Failure, List<ExamTimetableEntity>>> getExamTimetables(
    String tenantId, {
    String? academicYear,
  }) async {
    try {
      var query = _supabaseClient
          .from('exam_timetables')
          .select()
          .eq('tenant_id', tenantId)
          .eq('is_active', true);

      if (academicYear != null) {
        query = query.eq('academic_year', academicYear);
      }

      final response = await query.order('created_at', ascending: false);

      final timetables = (response as List<dynamic>)
          .map((json) => ExamTimetableModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return Right(timetables);
    } on PostgrestException catch (e) {
      return Left(_mapPostgrestException(e));
    } catch (e) {
      return Left(ServerFailure('Failed to fetch exam timetables: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ExamTimetableEntity>> getExamTimetableById(
    String timetableId,
  ) async {
    try {
      final response = await _supabaseClient
          .from('exam_timetables')
          .select()
          .eq('id', timetableId)
          .maybeSingle();

      if (response == null) {
        return Left(NotFoundFailure('Exam timetable not found'));
      }

      final timetable = ExamTimetableModel.fromJson(response as Map<String, dynamic>);
      return Right(timetable);
    } on PostgrestException catch (e) {
      return Left(_mapPostgrestException(e));
    } catch (e) {
      return Left(ServerFailure('Failed to fetch exam timetable: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ExamTimetableEntity>> createExamTimetable(
    ExamTimetableEntity timetable,
  ) async {
    try {
      final model = ExamTimetableModel.fromEntity(timetable);
      final jsonData = model.toJson();

      final response = await _supabaseClient
          .from('exam_timetables')
          .insert(jsonData)
          .select()
          .single();

      final created = ExamTimetableModel.fromJson(response as Map<String, dynamic>);
      return Right(created);
    } on PostgrestException catch (e) {
      return Left(_mapPostgrestException(e));
    } catch (e) {
      return Left(ServerFailure('Failed to create exam timetable: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ExamTimetableEntity>> updateExamTimetable(
    ExamTimetableEntity timetable,
  ) async {
    try {
      final model = ExamTimetableModel.fromEntity(timetable);
      final response = await _supabaseClient
          .from('exam_timetables')
          .update(model.toJsonRequest())
          .eq('id', timetable.id)
          .select()
          .single();

      final updated = ExamTimetableModel.fromJson(response as Map<String, dynamic>);
      return Right(updated);
    } on PostgrestException catch (e) {
      return Left(_mapPostgrestException(e));
    } catch (e) {
      return Left(ServerFailure('Failed to update exam timetable: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ExamTimetableEntity>> publishExamTimetable(
    String timetableId,
  ) async {
    try {
      final now = DateTime.now();
      final response = await _supabaseClient
          .from('exam_timetables')
          .update({
            'status': 'published',
            'published_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          })
          .eq('id', timetableId)
          .select()
          .single();

      final published = ExamTimetableModel.fromJson(response as Map<String, dynamic>);
      return Right(published);
    } on PostgrestException catch (e) {
      return Left(_mapPostgrestException(e));
    } catch (e) {
      return Left(ServerFailure('Failed to publish exam timetable: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ExamTimetableEntity>> archiveExamTimetable(
    String timetableId,
  ) async {
    try {
      final now = DateTime.now();
      final response = await _supabaseClient
          .from('exam_timetables')
          .update({
            'status': 'archived',
            'updated_at': now.toIso8601String(),
          })
          .eq('id', timetableId)
          .select()
          .single();

      final archived = ExamTimetableModel.fromJson(response as Map<String, dynamic>);
      return Right(archived);
    } on PostgrestException catch (e) {
      return Left(_mapPostgrestException(e));
    } catch (e) {
      return Left(ServerFailure('Failed to archive exam timetable: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteExamTimetable(String timetableId) async {
    try {
      await _supabaseClient
          .from('exam_timetables')
          .update({'is_active': false, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', timetableId);

      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(_mapPostgrestException(e));
    } catch (e) {
      return Left(ServerFailure('Failed to delete exam timetable: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ExamTimetableEntity>> reactivateExamTimetable(
    String timetableId,
  ) async {
    try {
      final response = await _supabaseClient
          .from('exam_timetables')
          .update({'is_active': true, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', timetableId)
          .select()
          .single();

      final reactivated = ExamTimetableModel.fromJson(response as Map<String, dynamic>);
      return Right(reactivated);
    } on PostgrestException catch (e) {
      return Left(_mapPostgrestException(e));
    } catch (e) {
      return Left(ServerFailure('Failed to reactivate exam timetable: ${e.toString()}'));
    }
  }

  // ===== EXAM TIMETABLE ENTRY OPERATIONS =====

  @override
  Future<Either<Failure, List<ExamTimetableEntryEntity>>> getExamTimetableEntries(
    String timetableId,
  ) async {
    try {

      // Fetch basic entries first
      final response = await _supabaseClient
          .from('exam_timetable_entries')
          .select()
          .eq('timetable_id', timetableId)
          .eq('is_active', true)
          .order('exam_date', ascending: true);

      final entries = (response as List<dynamic>)
          .map((json) => ExamTimetableEntryModel.fromJson(json as Map<String, dynamic>))
          .toList();


      if (entries.isEmpty) {
        return Right(entries);
      }

      // Batch fetch all unique grade sections and their corresponding grades
      final uniqueGradeSectionIds = entries.map((e) => e.gradeSectionId).toSet().toList();
      final gradesMap = <String, int>{}; // gradeId -> gradeNumber mapping

      try {
        // Step 1: Get grade_id from grade_sections table
        final gradeSectionsResponse = await _supabaseClient
            .from('grade_sections')
            .select('id, grade_id')
            .inFilter('id', uniqueGradeSectionIds);

        // Collect all unique grade IDs
        final uniqueGradeIds = <String>{};
        for (var gs in (gradeSectionsResponse as List<dynamic>)) {
          final gradeId = gs['grade_id'] as String;
          uniqueGradeIds.add(gradeId);
        }

        // Step 2: Fetch grade numbers for all collected grade IDs
        if (uniqueGradeIds.isNotEmpty) {
          final gradesResponse = await _supabaseClient
              .from('grades')
              .select('id, grade_number')
              .inFilter('id', uniqueGradeIds.toList());

          for (var gradeData in (gradesResponse as List<dynamic>)) {
            final id = gradeData['id'] as String;
            final gradeNumber = gradeData['grade_number'] as int;
            gradesMap[id] = gradeNumber;
          }
        }
      } catch (e) {
      }

      // Step 3: Map grade_section_id -> (gradeNumber, sectionName) by joining through grade_id
      final gradeSectionToGradeNumber = <String, int>{};
      final gradeSectionToSectionName = <String, String>{};
      try {
        final gradeSectionsResponse = await _supabaseClient
            .from('grade_sections')
            .select('id, grade_id, section_name')
            .inFilter('id', uniqueGradeSectionIds);


        for (var gs in (gradeSectionsResponse as List<dynamic>)) {
          final gradeSectionId = gs['id'] as String;
          final gradeId = gs['grade_id'] as String;
          final sectionName = gs['section_name'] as String?;
          final gradeNumber = gradesMap[gradeId];
          if (gradeNumber != null) {
            gradeSectionToGradeNumber[gradeSectionId] = gradeNumber;
          }
          if (sectionName != null) {
            gradeSectionToSectionName[gradeSectionId] = sectionName;
          }
        }
      } catch (e) {
      }

      // Batch fetch all unique subjects and their catalog info
      final uniqueSubjectIds = entries.map((e) => e.subjectId).toSet().toList();
      final subjectsMap = <String, String>{};

      try {
        final subjectsResponse = await _supabaseClient
            .from('subjects')
            .select('id, catalog_subject_id')
            .inFilter('id', uniqueSubjectIds);

        final catalogIds = <String>[];
        final catalogIdToSubjectId = <String, String>{};

        for (var subjectData in (subjectsResponse as List<dynamic>)) {
          final subjectId = subjectData['id'] as String;
          final catalogId = subjectData['catalog_subject_id'] as String?;
          if (catalogId != null) {
            catalogIds.add(catalogId);
            catalogIdToSubjectId[catalogId] = subjectId;
          }
        }

        // Batch fetch subject names from catalog
        if (catalogIds.isNotEmpty) {
          final catalogResponse = await _supabaseClient
              .from('subject_catalog')
              .select('id, subject_name')
              .inFilter('id', catalogIds);

          for (var catalogData in (catalogResponse as List<dynamic>)) {
            final catalogId = catalogData['id'] as String;
            final subjectName = catalogData['subject_name'] as String?;
            if (subjectName != null && catalogIdToSubjectId.containsKey(catalogId)) {
              subjectsMap[catalogIdToSubjectId[catalogId]!] = subjectName;
            }
          }
        }
      } catch (e) {
      }

      // Create enriched entries with fetched data
      // Use gradeSectionToGradeNumber and gradeSectionToSectionName mappings to enrich entries
      final enrichedEntries = entries
          .map((entry) => entry.copyWith(
                gradeNumber: gradeSectionToGradeNumber[entry.gradeSectionId],
                section: gradeSectionToSectionName[entry.gradeSectionId] ?? entry.section,
                subjectName: subjectsMap[entry.subjectId],
              ))
          .toList();

      return Right(enrichedEntries);
    } on PostgrestException catch (e) {
      return Left(_mapPostgrestException(e));
    } catch (e) {
      return Left(ServerFailure('Failed to fetch exam entries: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ExamTimetableEntryEntity>> getExamTimetableEntryById(
    String entryId,
  ) async {
    try {
      final response = await _supabaseClient
          .from('exam_timetable_entries')
          .select()
          .eq('id', entryId)
          .maybeSingle();

      if (response == null) {
        return Left(NotFoundFailure('Exam entry not found'));
      }

      final entry = ExamTimetableEntryModel.fromJson(response as Map<String, dynamic>);
      return Right(entry);
    } on PostgrestException catch (e) {
      return Left(_mapPostgrestException(e));
    } catch (e) {
      return Left(ServerFailure('Failed to fetch exam entry: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ExamTimetableEntryEntity>> addExamTimetableEntry(
    ExamTimetableEntryEntity entry,
  ) async {
    try {
      final model = ExamTimetableEntryModel.fromEntity(entry);
      final response = await _supabaseClient
          .from('exam_timetable_entries')
          .insert(model.toJson())
          .select()
          .single();

      final created = ExamTimetableEntryModel.fromJson(response as Map<String, dynamic>);
      return Right(created);
    } on PostgrestException catch (e) {
      return Left(_mapPostgrestException(e));
    } catch (e) {
      return Left(ServerFailure('Failed to add exam entry: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ExamTimetableEntryEntity>> updateExamTimetableEntry(
    ExamTimetableEntryEntity entry,
  ) async {
    try {
      final model = ExamTimetableEntryModel.fromEntity(entry);
      final response = await _supabaseClient
          .from('exam_timetable_entries')
          .update(model.toJsonRequest())
          .eq('id', entry.id ?? '')
          .select()
          .single();

      final updated = ExamTimetableEntryModel.fromJson(response as Map<String, dynamic>);
      return Right(updated);
    } on PostgrestException catch (e) {
      return Left(_mapPostgrestException(e));
    } catch (e) {
      return Left(ServerFailure('Failed to update exam entry: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteExamTimetableEntry(String entryId) async {
    try {
      await _supabaseClient
          .from('exam_timetable_entries')
          .update({'is_active': false, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', entryId);

      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(_mapPostgrestException(e));
    } catch (e) {
      return Left(ServerFailure('Failed to delete exam entry: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ExamTimetableEntryEntity>> reactivateExamTimetableEntry(
    String entryId,
  ) async {
    try {
      final response = await _supabaseClient
          .from('exam_timetable_entries')
          .update({'is_active': true, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', entryId)
          .select()
          .single();

      final reactivated = ExamTimetableEntryModel.fromJson(response as Map<String, dynamic>);
      return Right(reactivated);
    } on PostgrestException catch (e) {
      return Left(_mapPostgrestException(e));
    } catch (e) {
      return Left(ServerFailure('Failed to reactivate exam entry: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<ExamTimetableEntryEntity>>> addMultipleExamTimetableEntries(
    List<ExamTimetableEntryEntity> entries,
  ) async {
    try {
      if (entries.isEmpty) {
        return const Right([]);
      }


      final models = entries.map((e) {

        final model = ExamTimetableEntryModel.fromEntity(e);
        final json = model.toJson();
        return json;
      }).toList();


      try {
        final response = await _supabaseClient
            .from('exam_timetable_entries')
            .insert(models)
            .select();


        final created = (response as List<dynamic>)
            .map((json) {
              return ExamTimetableEntryModel.fromJson(json as Map<String, dynamic>);
            })
            .toList();

        return Right(created);
      } on PostgrestException catch (e) {
        return Left(_mapPostgrestException(e));
      }
    } catch (e, st) {
      return Left(ServerFailure('Failed to add multiple exam entries: ${e.toString()}'));
    }
  }

  // ===== VALIDATION & UTILITY OPERATIONS =====

  @override
  Future<Either<Failure, bool>> checkDuplicateEntry(
    String timetableId,
    String gradeId,
    String subjectId,
    DateTime examDate,
    String section,
  ) async {
    try {
      final response = await _supabaseClient
          .from('exam_timetable_entries')
          .select('id')
          .eq('timetable_id', timetableId)
          .eq('grade_id', gradeId)
          .eq('subject_id', subjectId)
          .eq('section', section)
          .eq('exam_date', examDate.toIso8601String().split('T')[0]) // Date only
          .eq('is_active', true)
          .maybeSingle();

      return Right(response != null);
    } on PostgrestException catch (e) {
      return Left(_mapPostgrestException(e));
    } catch (e) {
      return Left(ServerFailure('Failed to check duplicate entry: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<ExamTimetableEntryEntity>>> getDuplicateEntries(
    String timetableId,
  ) async {
    try {
      // Query to find duplicates: same grade+subject+section+date combinations
      final response = await _supabaseClient.rpc(
        'get_duplicate_timetable_entries',
        params: {'p_timetable_id': timetableId},
      ) as List<dynamic>;

      final duplicates = response
          .map((json) => ExamTimetableEntryModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return Right(duplicates);
    } on PostgrestException catch (e) {
      return Left(_mapPostgrestException(e));
    } catch (e) {
      // Return empty list if RPC doesn't exist (fallback)
      return const Right([]);
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getExamTimetableStats(
    String timetableId,
  ) async {
    try {
      // Get all entries for the timetable
      final entries = await _supabaseClient
          .from('exam_timetable_entries')
          .select()
          .eq('timetable_id', timetableId);

      final entryList = entries as List<dynamic>;
      final totalEntries = entryList.length;
      final activeEntries = entryList.where((e) => e['is_active'] == true).length;

      // Calculate date range and grades/subjects covered
      DateTime? minDate;
      DateTime? maxDate;
      final grades = <String>{};
      final subjects = <String>{};

      for (final entry in entryList) {
        if (entry['is_active'] == true) {
          final examDate = DateTime.parse(entry['exam_date'] as String);
          minDate = minDate == null ? examDate : (examDate.isBefore(minDate) ? examDate : minDate);
          maxDate = maxDate == null ? examDate : (examDate.isAfter(maxDate) ? examDate : maxDate);

          grades.add(entry['grade_id'] as String);
          subjects.add(entry['subject_id'] as String);
        }
      }

      return Right({
        'total_entries': totalEntries,
        'active_entries': activeEntries,
        'date_range': {
          'start': minDate?.toIso8601String(),
          'end': maxDate?.toIso8601String(),
        },
        'grades_covered': grades.toList(),
        'subjects_covered': subjects.toList(),
      });
    } on PostgrestException catch (e) {
      return Left(_mapPostgrestException(e));
    } catch (e) {
      return Left(ServerFailure('Failed to get timetable stats: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<String>>> validateExamTimetable(
    String timetableId,
  ) async {
    try {
      final entries = await _supabaseClient
          .from('exam_timetable_entries')
          .select()
          .eq('timetable_id', timetableId)
          .eq('is_active', true);

      final errors = <String>[];
      final entryList = entries as List<dynamic>;

      // Check: at least one entry exists
      if (entryList.isEmpty) {
        errors.add('Timetable must have at least one entry');
      }

      // Check: no duplicate entries
      final seen = <String>{};
      for (final entry in entryList) {
        final key =
            '${entry['grade_id']}_${entry['subject_id']}_${entry['section']}_${entry['exam_date']}';
        if (seen.contains(key)) {
          errors.add(
            'Duplicate entry found: Grade ${entry['grade_id']}, '
            'Subject ${entry['subject_id']}, Section ${entry['section']}',
          );
        }
        seen.add(key);
      }

      // Check: all entries have valid time ranges
      for (final entry in entryList) {
        try {
          final startStr = entry['start_time'] as String;
          final endStr = entry['end_time'] as String;
          final startDuration = _parseTimeString(startStr);
          final endDuration = _parseTimeString(endStr);

          if (startDuration >= endDuration) {
            errors.add(
              'Invalid time range for Grade ${entry['grade_id']}, '
              'Subject ${entry['subject_id']}: Start time must be before end time',
            );
          }
        } catch (e) {
          errors.add('Invalid time format in entry: ${e.toString()}');
        }
      }

      return Right(errors);
    } on PostgrestException catch (e) {
      return Left(_mapPostgrestException(e));
    } catch (e) {
      return Left(ServerFailure('Failed to validate timetable: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ExamTimetableEntity>> duplicateExamTimetable(
    String sourceTimetableId,
    String newAcademicYear, {
    Duration? dateOffset,
  }) async {
    try {
      // Get source timetable
      final sourceResponse = await _supabaseClient
          .from('exam_timetables')
          .select()
          .eq('id', sourceTimetableId)
          .single();

      final sourceTimetable = ExamTimetableModel.fromJson(sourceResponse as Map<String, dynamic>);

      // Get all entries from source
      final entriesResponse = await _supabaseClient
          .from('exam_timetable_entries')
          .select()
          .eq('timetable_id', sourceTimetableId)
          .eq('is_active', true);

      final sourceEntries = entriesResponse as List<dynamic>;

      // Create new timetable with new ID and academic year
      final newTimetableId = _generateId('timetable');
      final now = DateTime.now();
      final newTimetable = ExamTimetableEntity(
        id: newTimetableId,
        tenantId: sourceTimetable.tenantId,
        createdBy: sourceTimetable.createdBy,
        examCalendarId: sourceTimetable.examCalendarId,
        examName: sourceTimetable.examName,
        examType: sourceTimetable.examType,
        examNumber: sourceTimetable.examNumber,
        academicYear: newAcademicYear,
        status: 'draft',
        publishedAt: null,
        isActive: true,
        metadata: sourceTimetable.metadata,
        createdAt: now,
        updatedAt: now,
      );

      // Insert new timetable
      final newTimetableModel = ExamTimetableModel.fromEntity(newTimetable);
      final createdTimetableResponse = await _supabaseClient
          .from('exam_timetables')
          .insert(newTimetableModel.toJson())
          .select()
          .single();

      // Duplicate entries with new IDs and adjusted dates if offset provided
      final newEntries = <Map<String, dynamic>>[];
      for (final entry in sourceEntries) {
        final entryData = entry as Map<String, dynamic>;
        var examDate = DateTime.parse(entryData['exam_date'] as String);

        if (dateOffset != null) {
          examDate = examDate.add(dateOffset);
        }

        newEntries.add({
          'id': _generateId('entry'),
          'timetable_id': newTimetableId,
          'tenant_id': sourceTimetable.tenantId,
          'grade_id': entryData['grade_id'],
          'subject_id': entryData['subject_id'],
          'section': entryData['section'],
          'exam_date': examDate.toIso8601String(),
          'start_time': entryData['start_time'],
          'end_time': entryData['end_time'],
          'duration_minutes': entryData['duration_minutes'],
          'is_active': true,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });
      }

      if (newEntries.isNotEmpty) {
        await _supabaseClient.from('exam_timetable_entries').insert(newEntries);
      }

      final duplicated = ExamTimetableModel.fromJson(createdTimetableResponse as Map<String, dynamic>);
      return Right(duplicated);
    } on PostgrestException catch (e) {
      return Left(_mapPostgrestException(e));
    } catch (e) {
      return Left(ServerFailure('Failed to duplicate exam timetable: ${e.toString()}'));
    }
  }

  // ===== PRIVATE HELPER METHODS =====

  /// Map PostgreSQL exceptions to domain Failure objects
  Failure _mapPostgrestException(PostgrestException e) {
    switch (e.code) {
      case '23505': // unique_violation
        return ValidationFailure('This record already exists');
      case '23503': // foreign_key_violation
        return ValidationFailure('Referenced record does not exist');
      case '42P01': // undefined_table
        return ServerFailure('Database table not found');
      case '42703': // undefined_column
        return ServerFailure('Database column not found');
      case '42501': // insufficient_privilege
      case 'PGRST301': // RLS policy violation
        return PermissionFailure('You do not have permission to perform this action');
      default:
        return ServerFailure('Database error: ${e.message}');
    }
  }

  /// Parse time string in "HH:MM:SS" format to Duration
  Duration _parseTimeString(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length < 2) {
      throw FormatException('Invalid time format: $timeStr');
    }
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    return Duration(hours: hours, minutes: minutes);
  }

  /// Generate a unique ID for new records
  String _generateId(String prefix) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (DateTime.now().microsecond % 10000).toString().padLeft(4, '0');
    return '$prefix-$timestamp-$random';
  }

  // ===== EXAM CALENDAR GRADE MAPPING OPERATIONS (STEP 2) =====

  @override
  Future<Either<Failure, List<String>>> getGradesForCalendar(
    String examCalendarId,
  ) async {
    try {
      final response = await _supabaseClient
          .from('exam_calendar_grade_mapping')
          .select('grade_section_id')
          .eq('exam_calendar_id', examCalendarId)
          .eq('is_active', true);

      final gradeSectionIds = (response as List<dynamic>)
          .map((json) => (json as Map<String, dynamic>)['grade_section_id'] as String)
          .toList();

      return Right(gradeSectionIds);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ExamCalendarGradeMappingEntity>>
      addGradeToCalendar(
    String tenantId,
    String examCalendarId,
    String gradeId,
  ) async {
    try {
      final response = await _supabaseClient
          .from('exam_calendar_grade_mapping')
          .insert({
        'tenant_id': tenantId,
        'exam_calendar_id': examCalendarId,
        'grade_id': gradeId,
        'is_active': true,
      }).select();

      final mapping = ExamCalendarGradeMappingModel.fromJson(
          response[0] as Map<String, dynamic>);
      return Right(mapping);
    } on PostgrestException catch (e) {
      if (e.message.contains('unique')) {
        return Left(
            ValidationFailure('Grade already mapped to this calendar'));
      }
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ExamCalendarGradeMappingEntity>>>
      addGradesToCalendar(
    String tenantId,
    String examCalendarId,
    List<String> gradeSectionIds,
  ) async {
    try {

      final inserts = gradeSectionIds.map((gradeSectionId) {
        return {
          'tenant_id': tenantId,
          'exam_calendar_id': examCalendarId,
          'grade_section_id': gradeSectionId,
          'is_active': true,
        };
      }).toList();


      final response = await _supabaseClient
          .from('exam_calendar_grade_mapping')
          .upsert(inserts, onConflict: 'exam_calendar_id,grade_section_id')
          .select();

      final mappings = (response as List<dynamic>)
          .map((json) => ExamCalendarGradeMappingModel.fromJson(
              json as Map<String, dynamic>))
          .toList();

      return Right(mappings);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> removeGradeFromCalendar(
    String examCalendarId,
    String gradeSectionId,
  ) async {
    try {
      await _supabaseClient
          .from('exam_calendar_grade_mapping')
          .update({'is_active': false})
          .eq('exam_calendar_id', examCalendarId)
          .eq('grade_section_id', gradeSectionId);

      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> removeGradesFromCalendar(
    String examCalendarId,
    List<String> gradeSectionIds,
  ) async {
    try {
      // Delete/deactivate each grade section mapping individually
      for (final gradeSectionId in gradeSectionIds) {
        await _supabaseClient
            .from('exam_calendar_grade_mapping')
            .update({'is_active': false})
            .eq('exam_calendar_id', examCalendarId)
            .eq('grade_section_id', gradeSectionId);
      }

      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ExamCalendarGradeMappingEntity>>>
      getCalendarGradeMappings(String examCalendarId) async {
    try {
      final response = await _supabaseClient
          .from('exam_calendar_grade_mapping')
          .select()
          .eq('exam_calendar_id', examCalendarId);

      final mappings = (response as List<dynamic>)
          .map((json) => ExamCalendarGradeMappingModel.fromJson(
              json as Map<String, dynamic>))
          .toList();

      return Right(mappings);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> isGradeMappedToCalendar(
    String examCalendarId,
    String gradeId,
  ) async {
    try {
      final response = await _supabaseClient
          .from('exam_calendar_grade_mapping')
          .select('id')
          .eq('exam_calendar_id', examCalendarId)
          .eq('grade_id', gradeId)
          .eq('is_active', true);

      return Right(response.isNotEmpty);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, List<String>>>>
      getValidSubjectsForGradeSelection({
    required String tenantId,
    required List<String> selectedGradeSectionIds,
  }) async {
    try {
      if (selectedGradeSectionIds.isEmpty) {
        return const Right({});
      }

      // Query grade_section_subject joined with grade_sections and subject_catalog
      // to get all valid (grade_number, section, subject_name) combinations
      final response = await _supabaseClient
          .from('grade_section_subject')
          .select('''
            grade_section_id,
            subject_id,
            grade_sections!inner(grade_id, section_name),
            subjects!inner(catalog_subject_id),
            subject_catalog!inner(subject_name)
          ''')
          .eq('tenant_id', tenantId)
          .eq('is_offered', true)
          .eq('grade_sections.is_active', true)
          .eq('subjects.is_active', true)
          .inFilter('grade_section_id', selectedGradeSectionIds);

      // Build the result map: "gradeNumber_section" -> [subject_names]
      final Map<String, List<String>> result = {};

      if (response.isNotEmpty && response is List) {
        for (final item in response) {
          if (item is Map<String, dynamic>) {
            final gradeSection = item['grade_sections'];
            final subjects = item['subjects'];
            final subjectCatalog = item['subject_catalog'];

            if (gradeSection != null && subjectCatalog != null) {
              final gradeId = gradeSection['grade_id'];
              final sectionName = gradeSection['section_name'];
              final subjectName = subjectCatalog['subject_name'];

              final key = '${gradeId}_$sectionName';

              if (!result.containsKey(key)) {
                result[key] = [];
              }

              if (subjectName != null && !result[key]!.contains(subjectName)) {
                result[key]!.add(subjectName);
              }
            }
          }
        }
      }

      return Right(result);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(
          'Failed to fetch valid subjects: ${e.message}'));
    } catch (e) {
      return Left(ServerFailure(
          'Error fetching valid subjects: ${e.toString()}'));
    }
  }
}
