import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/teacher_subject_assignment_entity.dart';

/// Repository interface for teacher subject assignments (for settings/management)
///
/// This is distinct from [TeacherSubjectRepository] which is used for onboarding.
/// This repository is optimized for the teacher assignments management screen with:
/// - Display fields (teacher names, grades, sections, subjects from DB joins)
/// - Settings screen operations (view, update, delete)
/// - Single year operations (2025-2026)
/// - Admin/settings context
abstract class TeacherAssignmentRepository {
  /// Get all teacher assignments for a tenant with optional filtering
  ///
  /// Returns entities with populated display fields (names, grades, sections, subjects)
  /// Ready to display in UI without additional queries
  ///
  /// [tenantId] - required tenant identifier
  /// [teacherId] - optional filter by specific teacher
  /// [academicYear] - filter by academic year (defaults to 2025-2026)
  /// [activeOnly] - if true, only return is_active = true records
  Future<Either<Failure, List<TeacherSubjectAssignmentEntity>>> getTeacherAssignments({
    required String tenantId,
    String? teacherId,
    String academicYear = '2025-2026',
    bool activeOnly = true,
  });

  /// Get assignment count by grade+section for stats dashboard
  ///
  /// Returns a map of "gradeNumber:section" → count
  /// Example: {"2:A": 3, "2:B": 4, "5:A": 2}
  Future<Either<Failure, Map<String, int>>> getAssignmentStats({
    required String tenantId,
    String academicYear = '2025-2026',
  });

  /// Save a single teacher assignment
  ///
  /// Creates new or updates existing (UPSERT by unique constraint)
  /// Ensures idempotency for safe retry behavior
  ///
  /// The assignment must have:
  /// - id: Unique identifier (can generate from tenantId+teacherId+gradeId+subjectId)
  /// - tenantId, teacherId, gradeId, subjectId: Required identifiers
  /// - academicYear: Academic year (defaults to 2025-2026)
  /// - isActive: true for new assignments
  /// - createdAt: Current timestamp
  /// - Display fields (teacherName, gradeNumber, section, subjectName) populated
  Future<Either<Failure, void>> saveAssignment(
    TeacherSubjectAssignmentEntity assignment,
  );

  /// Soft delete a teacher assignment
  ///
  /// Sets is_active = false instead of hard delete
  /// Preserves record for audit trail
  ///
  /// [assignmentId] - the ID of the assignment to deactivate
  Future<Either<Failure, void>> deleteAssignment(String assignmentId);

  /// Get a single assignment by ID
  ///
  /// Includes all display fields
  Future<Either<Failure, TeacherSubjectAssignmentEntity?>> getAssignmentById(String id);

  /// Get assignments for a specific teacher with counts by grade+section
  ///
  /// Useful for teacher detail page showing summary
  /// Returns assignments grouped and counted by grade+section
  Future<Either<Failure, List<TeacherSubjectAssignmentEntity>>> getAssignmentsForTeacher({
    required String tenantId,
    required String teacherId,
    String academicYear = '2025-2026',
  });
}
