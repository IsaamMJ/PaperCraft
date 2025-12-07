import 'package:csv/csv.dart';
import '../../../catalog/domain/entities/grade_entity.dart';
import '../../../catalog/domain/entities/grade_section.dart';
import '../../../catalog/domain/entities/grade_subject.dart';
import '../../../catalog/domain/entities/subject_entity.dart';
import '../../../assignments/domain/entities/teacher_subject.dart';

/// Service to generate reports in various formats
class ReportGeneratorService {
  /// Generate Academic Structure Report as CSV (Verification Checklist Format)
  /// Returns detailed format with Grade | Section | Subject checkmarks for easy verification
  /// Perfect for printing and school review
  static String generateAcademicStructureCSV({
    required List<GradeEntity> grades,
    required Map<String, List<GradeSection>> sectionsPerGrade,
    required Map<String, List<GradeSubject>> subjectsPerSection,
    required Map<String, SubjectEntity> subjectsMap, // subjectId -> SubjectEntity
  }) {
    // Prepare data for CSV
    final List<List<dynamic>> rows = [];

    // Add report header
    final now = DateTime.now();
    final formattedDate = '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute}';

    rows.add(['ACADEMIC STRUCTURE VERIFICATION REPORT']);
    rows.add(['Generated:', formattedDate]);
    rows.add([]);

    // Sort grades by grade number
    final sortedGrades = [...grades]..sort((a, b) => a.gradeNumber.compareTo(b.gradeNumber));

    // Collect all unique subjects across all grades/sections and sort alphabetically
    final allSubjectsSet = <String>{};
    for (final grade in sortedGrades) {
      final sections = sectionsPerGrade[grade.id] ?? [];
      for (final section in sections) {
        final subjects = subjectsPerSection[section.id] ?? [];
        for (final subject in subjects) {
          final subjectEntity = subjectsMap[subject.subjectId];
          if (subjectEntity != null) {
            allSubjectsSet.add(subjectEntity.name);
          }
        }
      }
    }

    // Sort subjects alphabetically
    final allSubjects = allSubjectsSet.toList()..sort();

    // Create headers: Grade | Section | Subject1 | Subject2 | Subject3 | etc.
    final headers = ['Grade', 'Section'];
    headers.addAll(allSubjects);
    rows.add(headers);

    // Add data rows - one row per grade+section combination
    int totalSections = 0;
    int totalSubjectAssignments = 0;

    for (final grade in sortedGrades) {
      final sections = sectionsPerGrade[grade.id] ?? [];
      final sortedSections = [...sections]..sort((a, b) => a.sectionName.compareTo(b.sectionName));

      for (final section in sortedSections) {
        totalSections++;
        final row = ['Grade ${grade.gradeNumber}', section.sectionName];

        // Get subjects assigned to this section
        final subjectsInSection = subjectsPerSection[section.id] ?? [];
        totalSubjectAssignments += subjectsInSection.length;

        // Build a map of subject names assigned to this section
        final assignedSubjectNames = <String>{};
        for (final subject in subjectsInSection) {
          final subjectEntity = subjectsMap[subject.subjectId];
          if (subjectEntity != null) {
            assignedSubjectNames.add(subjectEntity.name);
          }
        }

        // For each subject column, add checkmark if assigned, else empty
        for (final subject in allSubjects) {
          if (assignedSubjectNames.contains(subject)) {
            row.add('✓');
          } else {
            row.add('');
          }
        }

        rows.add(row);
      }
    }

    // Add summary statistics at bottom
    rows.add([]);
    rows.add(['SUMMARY']);
    rows.add(['Total Grades:', sortedGrades.length.toString()]);
    rows.add(['Total Sections:', totalSections.toString()]);
    rows.add(['Total Subjects:', allSubjects.length.toString()]);
    rows.add(['Total Assignments:', totalSubjectAssignments.toString()]);

    if (totalSections > 0) {
      final avgSubjectsPerSection = totalSubjectAssignments / totalSections;
      rows.add(['Average per Section:', avgSubjectsPerSection.toStringAsFixed(1)]);
    }

    // Convert to CSV with proper escaping
    final csv = const ListToCsvConverter().convert(rows);
    return csv;
  }

  /// Generate filename for academic structure report
  static String getAcademicStructureReportFilename() {
    final now = DateTime.now();
    final timestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}';
    return 'academic_structure_$timestamp.csv';
  }

  /// Generate Teacher Assignments Report as CSV
  /// Returns Grade | Section | Subject1 | Subject2 | ... format with teacher names
  /// Handles multiple teachers per subject-section by showing count and names
  static String generateTeacherAssignmentsCSV({
    required List<GradeEntity> grades,
    required Map<String, List<GradeSection>> sectionsPerGrade,
    required Map<String, List<TeacherSubject>> teacherAssignmentsPerSection,
    required Map<String, SubjectEntity> subjectsMap, // subjectId -> SubjectEntity
    required Map<String, String> teacherNamesMap, // teacherId -> teacher name
    required String academicYear,
  }) {
    // Prepare data for CSV
    final List<List<dynamic>> rows = [];

    // Add report header
    final now = DateTime.now();
    final formattedDate = '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute}';

    rows.add(['TEACHER ASSIGNMENTS REPORT']);
    rows.add(['Generated:', formattedDate]);
    rows.add(['Academic Year:', academicYear]);
    rows.add([]);

    // Sort grades by grade number
    final sortedGrades = [...grades]..sort((a, b) => a.gradeNumber.compareTo(b.gradeNumber));

    // Collect all unique subjects across all selected grades/sections and sort alphabetically
    final allSubjectsSet = <String>{};
    for (final grade in sortedGrades) {
      final sections = sectionsPerGrade[grade.id] ?? [];
      for (final section in sections) {
        final key = '${grade.id}_${section.id}';
        final assignments = teacherAssignmentsPerSection[key] ?? [];
        for (final assignment in assignments) {
          final subjectEntity = subjectsMap[assignment.subjectId];
          if (subjectEntity != null) {
            allSubjectsSet.add(subjectEntity.name);
          }
        }
      }
    }

    // Sort subjects alphabetically
    final allSubjects = allSubjectsSet.toList()..sort();

    // Create headers: Grade | Section | Subject1 | Subject2 | Subject3 | etc.
    final headers = ['Grade', 'Section'];
    headers.addAll(allSubjects);
    rows.add(headers);

    // Add data rows - one row per grade+section combination
    for (final grade in sortedGrades) {
      final sections = sectionsPerGrade[grade.id] ?? [];
      final sortedSections = [...sections]..sort((a, b) => a.sectionName.compareTo(b.sectionName));

      for (final section in sortedSections) {
        final row = ['Grade ${grade.gradeNumber}', section.sectionName];

        // Get teacher assignments for this section
        final key = '${grade.id}_${section.id}';
        final assignments = teacherAssignmentsPerSection[key] ?? [];

        // Build a map of subject assignments with teacher details
        // Map of subjectId -> List of teacher names
        final assignmentMap = <String, List<String>>{};
        for (final assignment in assignments) {
          if (!assignmentMap.containsKey(assignment.subjectId)) {
            assignmentMap[assignment.subjectId] = [];
          }
          // Get teacher name from map, fallback to teacherId if not found
          final teacherName = teacherNamesMap[assignment.teacherId] ?? assignment.teacherId;
          assignmentMap[assignment.subjectId]!.add(teacherName);
        }

        // For each subject column, add teacher name(s) if assigned, else "Unassigned"
        for (final subject in allSubjects) {
          // Find the subject ID for this subject name
          String? subjectId;
          for (final entry in subjectsMap.entries) {
            if (entry.value.name == subject) {
              subjectId = entry.key;
              break;
            }
          }

          if (subjectId != null && assignmentMap.containsKey(subjectId)) {
            final teachers = assignmentMap[subjectId]!;
            if (teachers.length == 1) {
              row.add(teachers.first);
            } else if (teachers.length > 1) {
              // Multiple teachers - show count and names
              final teacherList = teachers.join(', ');
              row.add('${teachers.length} teachers: $teacherList');
            }
          } else {
            row.add('Unassigned');
          }
        }

        rows.add(row);
      }
    }

    // Add summary statistics at bottom
    rows.add([]);
    rows.add(['SUMMARY']);
    rows.add(['Total Grades:', sortedGrades.length.toString()]);

    int totalSections = 0;
    int totalAssignments = 0;
    for (final grade in sortedGrades) {
      final sections = sectionsPerGrade[grade.id] ?? [];
      totalSections += sections.length;
      for (final section in sections) {
        final key = '${grade.id}_${section.id}';
        final assignments = teacherAssignmentsPerSection[key] ?? [];
        totalAssignments += assignments.length;
      }
    }

    rows.add(['Total Sections:', totalSections.toString()]);
    rows.add(['Total Subjects:', allSubjects.length.toString()]);
    rows.add(['Total Assignments:', totalAssignments.toString()]);

    if (totalSections > 0) {
      final avgAssignmentsPerSection = totalAssignments / totalSections;
      rows.add(['Average per Section:', avgAssignmentsPerSection.toStringAsFixed(1)]);
    }

    // Convert to CSV with proper escaping
    final csv = const ListToCsvConverter().convert(rows);
    return csv;
  }

  /// Generate filename for teacher assignments report
  static String getTeacherAssignmentsReportFilename() {
    final now = DateTime.now();
    final timestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}';
    return 'teacher_assignments_$timestamp.csv';
  }

}
