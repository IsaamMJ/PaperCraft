import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/teacher_subject.dart';

/// Repository for managing teacher subject assignments
///
/// Stores the exact (grade, subject, section) tuples that each teacher teaches
/// Replaces the cartesian product problem from old grade + subject selections
abstract class TeacherSubjectRepository {
  /// Get all subjects assigned to a teacher
  ///
  /// [tenantId] - the school/tenant ID
  /// [teacherId] - filter by specific teacher (optional)
  /// [academicYear] - filter by academic year (optional)
  /// [activeOnly] - if true, only return is_active = true records
  Future<Either<Failure, List<TeacherSubject>>> getTeacherSubjects({
    required String tenantId,
    String? teacherId,
    String? academicYear,
    bool activeOnly = true,
  });

  /// Get all teachers assigned to a specific (grade, subject, section) tuple
  ///
  /// Used when publishing timetable to find which teachers should get papers
  /// Example: Get all teachers for Grade 5-A Maths
  ///
  /// Returns list of TeacherSubject entities (teacher IDs can be extracted)
  Future<Either<Failure, List<TeacherSubject>>> getTeachersFor({
    required String tenantId,
    required String gradeId,
    required String subjectId,
    required String section,
    required String academicYear,
    bool activeOnly = true,
  });

  /// Save all subject assignments for a teacher
  ///
  /// This is a REPLACE operation:
  /// 1. Delete all existing assignments for this teacher+year
  /// 2. Insert new assignments from [assignments] list
  ///
  /// Example: Teacher onboarding saves all their (grade, subject, section) tuples
  ///
  /// [assignments] - list of new assignments to save (should already have tenantId, teacherId, academicYear)
  Future<Either<Failure, void>> saveTeacherSubjects({
    required String tenantId,
    required String teacherId,
    required String academicYear,
    required List<TeacherSubject> assignments,
  });

  /// Soft delete a single teacher subject assignment
  ///
  /// Used when teacher is unassigned from a specific subject/section
  /// Papers remain visible but read-only
  Future<Either<Failure, void>> deactivateTeacherSubject(String id);

  /// Get single assignment by ID
  Future<Either<Failure, TeacherSubject?>> getTeacherSubjectById(String id);

  /// Count total teachers assigned to a (grade, subject, section)
  ///
  /// Used for validation before publishing timetable:
  /// If count = 0, show error "No teacher assigned to this subject"
  Future<Either<Failure, int>> countTeachersFor({
    required String tenantId,
    required String gradeId,
    required String subjectId,
    required String section,
    required String academicYear,
  });
}
