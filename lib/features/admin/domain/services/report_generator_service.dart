import 'package:csv/csv.dart';
import '../../../catalog/domain/entities/grade_entity.dart';
import '../../../catalog/domain/entities/grade_section.dart';
import '../../../catalog/domain/entities/grade_subject.dart';
import '../../../catalog/domain/entities/subject_entity.dart';

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
}
