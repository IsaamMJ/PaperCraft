import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/grade_subject.dart';

/// Repository for managing subject assignments to grade-section combinations
///
/// Handles CRUD operations for grade_subjects table
/// Key relationship: Grade + Section = unique subject list
abstract class GradeSubjectRepository {
  /// Get all subjects for a specific grade-section combination
  ///
  /// Returns list of GradeSubject entities for the given grade and section
  /// [tenantId] - the school/tenant ID
  /// [gradeId] - the grade ID
  /// [sectionId] - the section ID (e.g., "A", "B", "C")
  /// [activeOnly] - if true, only return is_active = true records
  Future<Either<Failure, List<GradeSubject>>> getSubjectsForGradeSection({
    required String tenantId,
    required String gradeId,
    required String sectionId,
    bool activeOnly = true,
  });

  /// Get a single grade-subject assignment by ID
  Future<Either<Failure, GradeSubject?>> getGradeSubjectById(String id);

  /// Add a subject to a grade-section combination
  ///
  /// Creates a new assignment linking subject to grade+section
  /// Returns the created GradeSubject with ID assigned by database
  Future<Either<Failure, GradeSubject>> addSubjectToSection(
    GradeSubject gradeSubject,
  );

  /// Remove a subject from a grade-section combination
  ///
  /// Soft deletes the assignment (sets is_active = false)
  Future<Either<Failure, void>> removeSubjectFromSection(String gradeSubjectId);

  /// Update a grade-subject assignment
  Future<Either<Failure, void>> updateGradeSubject(GradeSubject gradeSubject);

  /// Get all subjects for a specific grade (across all sections)
  ///
  /// Useful for showing available subjects for a grade
  Future<Either<Failure, List<GradeSubject>>> getSubjectsForGrade({
    required String tenantId,
    required String gradeId,
    bool activeOnly = true,
  });

  /// Batch add multiple subjects to a section
  ///
  /// Useful for applying patterns like "STEM" or "Humanities"
  Future<Either<Failure, List<GradeSubject>>> addMultipleSubjectsToSection({
    required String tenantId,
    required String gradeId,
    required String sectionId,
    required List<String> subjectIds,
  });

  /// Remove all subjects from a section
  ///
  /// Used when replacing subjects with a pattern
  Future<Either<Failure, void>> clearSubjectsFromSection({
    required String tenantId,
    required String gradeId,
    required String sectionId,
  });
}
