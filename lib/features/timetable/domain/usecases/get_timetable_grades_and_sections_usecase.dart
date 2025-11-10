import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/domain/errors/failures.dart';
import '../entities/timetable_grade_entity.dart';

/// Use case for fetching grades and sections available for creating timetables
///
/// Business Logic:
/// - Fetches grades from the 'grades' table filtered by tenant
/// - Fetches sections from the 'grade_section_subject' junction table filtered by tenant
/// - Deduplicates sections (junction table has multiple rows per section due to different subjects)
/// - Maps sections to grades by gradeNumber
/// - Returns Either<Failure, TimetableGradesAndSectionsData>
///
/// This follows the same pattern as teacher onboarding for data consistency
///
/// Example:
/// ```dart
/// final usecase = GetTimetableGradesAndSectionsUsecase(supabase: supabase);
/// final result = await usecase(params: GetTimetableGradesAndSectionsParams(
///   tenantId: 'tenant-123',
/// ));
/// result.fold(
///   (failure) => print('Error: ${failure.message}'),
///   (gradesData) => print('Found ${gradesData.grades.length} grades'),
/// );
/// ```
class GetTimetableGradesAndSectionsUsecase {
  final SupabaseClient _supabase;

  GetTimetableGradesAndSectionsUsecase({required SupabaseClient supabase})
      : _supabase = supabase;

  /// Fetch grades and sections for a tenant
  ///
  /// Parameters:
  /// - [params] - Contains tenantId for filtering grades/sections
  ///
  /// Returns:
  /// - [Either<Failure, TimetableGradesAndSectionsData>] - Grades with sections or failure
  Future<Either<Failure, TimetableGradesAndSectionsData>> call({
    required GetTimetableGradesAndSectionsParams params,
  }) async {
    try {
      print('[GetTimetableGradesAndSections] Fetching for tenant: ${params.tenantId}');

      // Step 1: Load grades for this tenant
      print('[GetTimetableGradesAndSections] Fetching grades from database');
      final gradesData = await _supabase
          .from('grades')
          .select()
          .eq('tenant_id', params.tenantId);

      print('[GetTimetableGradesAndSections] Grades fetched: ${(gradesData as List).length}');

      final availableGrades = (gradesData as List).map((g) {
        print('[GetTimetableGradesAndSections] Processing grade: ${g['grade_number']}');
        return TimetableGradeEntity(
          gradeId: g['id'] as String,
          gradeNumber: g['grade_number'] as int,
          sections: [], // Will be populated below
        );
      }).toList();

      // Step 2: Load sections from grade_section_subject table
      print('[GetTimetableGradesAndSections] Fetching sections from database');
      final sectionsRaw = await _supabase
          .from('grade_section_subject')
          .select('grade_id, section')
          .eq('tenant_id', params.tenantId);

      print('[GetTimetableGradesAndSections] Raw sections fetched: ${(sectionsRaw as List).length}');

      // Deduplicate: junction table has multiple rows per (grade_id, section) due to different subjects
      final sectionsMap = <String, Set<String>>{}; // grade_id -> set of sections
      for (var row in (sectionsRaw as List)) {
        final gradeId = row['grade_id'] as String;
        final section = row['section'] as String;
        sectionsMap.putIfAbsent(gradeId, () => {}).add(section);
      }

      print('[GetTimetableGradesAndSections] Deduped sections map: ${sectionsMap.length} grades');

      // Step 3: Build grade_number lookup map
      final gradeNumberMap = <String, int>{}; // grade_id -> grade_number
      for (var grade in (gradesData as List)) {
        gradeNumberMap[grade['id'] as String] = grade['grade_number'] as int;
      }

      print('[GetTimetableGradesAndSections] Grade number map built: ${gradeNumberMap.length} entries');

      // Step 4: Map sections to grades
      final sectionsByGradeNumber = <int, List<String>>{};
      for (var gradeId in sectionsMap.keys) {
        if (gradeNumberMap.containsKey(gradeId)) {
          final gradeNumber = gradeNumberMap[gradeId]!;
          final sections = sectionsMap[gradeId]!.toList()..sort();
          sectionsByGradeNumber[gradeNumber] = sections;
          print('[GetTimetableGradesAndSections] Grade $gradeNumber: ${sections.join(", ")}');
        }
      }

      print('[GetTimetableGradesAndSections] Final sections by grade: ${sectionsByGradeNumber.length}');

      // Step 5: Create grades with populated sections
      final gradesWithSections = availableGrades
          .map((grade) {
            final sections = sectionsByGradeNumber[grade.gradeNumber] ?? [];
            return TimetableGradeEntity(
              gradeId: grade.gradeId,
              gradeNumber: grade.gradeNumber,
              sections: sections,
            );
          })
          .toList();

      print('[GetTimetableGradesAndSections] SUCCESS: ${gradesWithSections.length} grades fetched');

      return Right(
        TimetableGradesAndSectionsData(
          grades: gradesWithSections,
          sectionsByGradeNumber: sectionsByGradeNumber,
        ),
      );
    } catch (e) {
      print('[GetTimetableGradesAndSections] ERROR: $e');
      return Left(
        ServerFailure(
          message: 'Failed to fetch grades and sections: $e',
        ),
      );
    }
  }
}

/// Parameters for GetTimetableGradesAndSectionsUsecase
class GetTimetableGradesAndSectionsParams {
  final String tenantId;

  GetTimetableGradesAndSectionsParams({required this.tenantId});
}
