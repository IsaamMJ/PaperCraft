import 'package:equatable/equatable.dart';

/// Represents a group of sections that take the same question paper
///
/// Paper Creation Rules:
/// 1. Same teacher, multiple sections → 1 combined paper
///    Example: Ms. Smith teaches Math to Grade 1 (Sections A, B, C)
///    Result: 1 paper for all 3 sections
///
/// 2. Different teachers, same subject → Multiple papers
///    Example: Ms. Smith teaches Grade 1 A,B | Mr. Johnson teaches Grade 1 C
///    Result: 2 papers
///
/// 3. No teacher assigned → No paper created
///    Example: English teacher not assigned for Grade 2
///    Result: ❌ Validation error
class PaperGroup extends Equatable {
  /// Unique identifier (generated UUID)
  final String id;

  /// References the exam timetable
  final String timetableId;

  /// The subject being examined
  final String subjectId;
  final String subjectName;

  /// Grade number (1-12)
  final int gradeNumber;

  /// List of section IDs that take this paper
  /// Example: ['section-a-uuid', 'section-b-uuid', 'section-c-uuid']
  final List<String> sectionIds;

  /// Section names for display
  /// Example: ['A', 'B', 'C']
  final List<String> sectionNames;

  /// Teacher assigned to invigilate/create this paper
  final String? teacherId;
  final String? teacherName;

  /// Exam details
  final DateTime examDate;
  final Duration startTime;
  final int durationMinutes;

  /// Subject type: 'core' or 'auxiliary'
  final String subjectType;

  /// Paper generation status
  final String status; // 'pending', 'generated', 'failed'
  final String? errorMessage;

  /// Metadata
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PaperGroup({
    required this.id,
    required this.timetableId,
    required this.subjectId,
    required this.subjectName,
    required this.gradeNumber,
    required this.sectionIds,
    required this.sectionNames,
    this.teacherId,
    this.teacherName,
    required this.examDate,
    required this.startTime,
    required this.durationMinutes,
    required this.subjectType,
    this.status = 'pending',
    this.errorMessage,
    this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [
    id,
    timetableId,
    subjectId,
    subjectName,
    gradeNumber,
    sectionIds,
    sectionNames,
    teacherId,
    teacherName,
    examDate,
    startTime,
    durationMinutes,
    subjectType,
    status,
    errorMessage,
    createdAt,
    updatedAt,
  ];

  /// Check if teacher is assigned
  bool get hasTeacher => teacherId != null && teacherId!.isNotEmpty;

  /// Check if teacher is missing
  bool get isTeacherMissing => !hasTeacher;

  /// Get formatted section list for display
  String get formattedSections {
    if (sectionNames.isEmpty) return 'No sections';
    if (sectionNames.length == 1) return 'Section ${sectionNames.first}';
    return 'Sections ${sectionNames.join(', ')}';
  }

  /// Get schedule display
  String get scheduleDisplay {
    final hours = startTime.inHours;
    final minutes = startTime.inMinutes % 60;
    final endHours = (startTime + Duration(minutes: durationMinutes)).inHours;
    final endMinutes = (startTime + Duration(minutes: durationMinutes)).inMinutes % 60;

    final period = hours >= 12 ? 'PM' : 'AM';
    final displayHours = hours > 12 ? hours - 12 : (hours == 0 ? 12 : hours);
    final displayEndHours = endHours > 12 ? endHours - 12 : (endHours == 0 ? 12 : endHours);
    final endPeriod = endHours >= 12 ? 'PM' : 'AM';

    return '${displayHours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')} $period - '
           '${displayEndHours.toString().padLeft(2, '0')}:${endMinutes.toString().padLeft(2, '0')} $endPeriod';
  }

  /// Get exam date formatted
  String get examDateDisplay {
    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = monthNames[examDate.month - 1];
    return '$month ${examDate.day}, ${examDate.year}';
  }

  /// Check if paper is ready to be created (has teacher assigned)
  bool get canCreatePaper => hasTeacher && status == 'pending';

  /// Check if paper generation failed
  bool get hasFailed => status == 'failed';

  /// Get display status
  String get displayStatus {
    switch (status) {
      case 'pending':
        return hasTeacher ? 'Ready to Create' : 'Missing Teacher';
      case 'generated':
        return 'Paper Created ✓';
      case 'failed':
        return 'Failed: ${errorMessage ?? 'Unknown error'}';
      default:
        return status;
    }
  }

  /// Copy with modified fields
  PaperGroup copyWith({
    String? id,
    String? timetableId,
    String? subjectId,
    String? subjectName,
    int? gradeNumber,
    List<String>? sectionIds,
    List<String>? sectionNames,
    String? teacherId,
    String? teacherName,
    DateTime? examDate,
    Duration? startTime,
    int? durationMinutes,
    String? subjectType,
    String? status,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaperGroup(
      id: id ?? this.id,
      timetableId: timetableId ?? this.timetableId,
      subjectId: subjectId ?? this.subjectId,
      subjectName: subjectName ?? this.subjectName,
      gradeNumber: gradeNumber ?? this.gradeNumber,
      sectionIds: sectionIds ?? this.sectionIds,
      sectionNames: sectionNames ?? this.sectionNames,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      examDate: examDate ?? this.examDate,
      startTime: startTime ?? this.startTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      subjectType: subjectType ?? this.subjectType,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'PaperGroup(grade: $gradeNumber, subject: $subjectName, sections: $formattedSections, teacher: $teacherName)';
}
