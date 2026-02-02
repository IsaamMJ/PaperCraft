import '../entities/paper_group.dart';

/// Service to validate teacher assignments and generate paper groups
///
/// Rules:
/// 1. Same teacher, multiple sections → 1 combined paper
/// 2. Different teachers → Multiple papers per teacher
/// 3. No teacher → Validation error, paper not created
class TeacherAssignmentValidator {
  /// Validate that all subjects have teacher assignments
  /// Returns list of validation errors
  List<String> validateTeacherAssignments({
    required Map<String, List<int>> subjectGradeMapping, // subjectId -> [gradeNumbers]
    required Map<String, String?> subjectTeacherMap, // subjectId -> teacherId (or null)
  }) {
    final errors = <String>[];

    for (var entry in subjectGradeMapping.entries) {
      final subjectId = entry.key;
      final grades = entry.value;
      final assignedTeacher = subjectTeacherMap[subjectId];

      if (assignedTeacher == null || assignedTeacher.isEmpty) {
        final gradeList = grades.join(', ');
        errors.add(
          'Missing teacher assignment for subject "$subjectId" in grades: $gradeList'
        );
      }
    }

    return errors;
  }

  /// Generate paper groups from exam schedule
  /// Implements the paper grouping logic
  List<PaperGroup> generatePaperGroups({
    required String timetableId,
    required List<ExamScheduleEntry> scheduleEntries,
    required Map<String, String?> subjectTeacherMap, // subjectId -> teacherId
    required Map<String, String?> subjectTeacherNameMap, // subjectId -> teacherName
    required Map<String, List<GradeSectionInfo>> gradeSectionMapping, // gradeId -> sections
  }) {
    final paperGroups = <PaperGroup>[];
    final processedKey = <String>{}; // To avoid duplicates

    // Group by subject, grade, and teacher
    for (var entry in scheduleEntries) {
      final subjectId = entry.subjectId;
      final gradeId = entry.gradeId;
      final teacherId = subjectTeacherMap[subjectId];

      // Generate unique key for this grouping
      final key = '$subjectId-$gradeId-${teacherId ?? 'no-teacher'}';

      if (processedKey.contains(key)) continue;
      processedKey.add(key);

      // Get all sections for this grade that have this subject
      final sections = gradeSectionMapping[gradeId] ?? [];
      final sectionIds = sections.map((s) => s.id).toList();
      final sectionNames = sections.map((s) => s.name).toList();

      // Create paper group
      final paperGroup = PaperGroup(
        id: _generateId(),
        timetableId: timetableId,
        subjectId: subjectId,
        subjectName: entry.subjectName,
        gradeNumber: entry.gradeNumber,
        sectionIds: sectionIds,
        sectionNames: sectionNames,
        teacherId: teacherId,
        teacherName: teacherId != null ? subjectTeacherNameMap[subjectId] : null,
        examDate: entry.examDate,
        startTime: entry.startTime,
        durationMinutes: entry.durationMinutes,
        subjectType: entry.subjectType,
        status: teacherId != null ? 'pending' : 'pending', // Will be validated before creating
      );

      paperGroups.add(paperGroup);
    }

    return paperGroups;
  }

  /// Check if all paper groups have teacher assignments
  bool areAllPapersAssigned(List<PaperGroup> paperGroups) {
    return paperGroups.every((pg) => pg.hasTeacher);
  }

  /// Get unassigned paper groups
  List<PaperGroup> getUnassignedPapers(List<PaperGroup> paperGroups) {
    return paperGroups.where((pg) => !pg.hasTeacher).toList();
  }

  /// Get summary of paper groups
  String getSummary(List<PaperGroup> paperGroups) {
    final total = paperGroups.length;
    final assigned = paperGroups.where((pg) => pg.hasTeacher).length;
    final unassigned = total - assigned;

    return 'Total Papers: $total | Assigned: $assigned | Unassigned: $unassigned';
  }

  /// Generate unique ID (simple implementation)
  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
           (DateTime.now().microsecond % 1000).toString();
  }
}

/// Represents one exam schedule entry (subject for a grade)
class ExamScheduleEntry {
  final String subjectId;
  final String subjectName;
  final int gradeNumber;
  final String gradeId;
  final DateTime examDate;
  final Duration startTime;
  final int durationMinutes;
  final String subjectType; // 'core' or 'auxiliary'

  ExamScheduleEntry({
    required this.subjectId,
    required this.subjectName,
    required this.gradeNumber,
    required this.gradeId,
    required this.examDate,
    required this.startTime,
    required this.durationMinutes,
    required this.subjectType,
  });
}

/// Section information within a grade
class GradeSectionInfo {
  final String id; // Section ID from grade_sections table
  final String name; // Section name: 'A', 'B', 'C', etc.
  final String gradeId;

  GradeSectionInfo({
    required this.id,
    required this.name,
    required this.gradeId,
  });
}
