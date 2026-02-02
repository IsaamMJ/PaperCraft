import 'package:equatable/equatable.dart';

/// Represents scheduling for a subject across different grades
///
/// Allows assigning different dates and times to the same subject
/// for different grades. Example:
///
/// Drawing exam:
/// - Grade 1, 2, 3: June 1, 9:00 AM
/// - Grade 4, 5: June 2, 10:00 AM
class GradeSubjectSchedule extends Equatable {
  final String subjectId;
  final String subjectName;

  /// Maps gradeId to exam date
  /// Example: { "grade-1": DateTime(2025, 6, 1), "grade-4": DateTime(2025, 6, 2) }
  final Map<String, DateTime> gradeDateMapping;

  /// Maps gradeId to start time as Duration
  /// Example: { "grade-1": Duration(hours: 9), "grade-4": Duration(hours: 10) }
  final Map<String, Duration> gradeStartTimeMapping;

  /// Duration of the exam in minutes (same for all grades)
  final int durationMinutes;

  /// Subject type: 'core' or 'auxiliary'
  final String subjectType;

  const GradeSubjectSchedule({
    required this.subjectId,
    required this.subjectName,
    required this.gradeDateMapping,
    required this.gradeStartTimeMapping,
    required this.durationMinutes,
    required this.subjectType,
  });

  @override
  List<Object?> get props => [
    subjectId,
    subjectName,
    gradeDateMapping,
    gradeStartTimeMapping,
    durationMinutes,
    subjectType,
  ];

  /// Get date for a specific grade
  DateTime? getDateForGrade(String gradeId) => gradeDateMapping[gradeId];

  /// Get start time for a specific grade
  Duration? getStartTimeForGrade(String gradeId) => gradeStartTimeMapping[gradeId];

  /// Get end time for a specific grade
  Duration? getEndTimeForGrade(String gradeId) {
    final startTime = gradeStartTimeMapping[gradeId];
    if (startTime == null) return null;
    return startTime + Duration(minutes: durationMinutes);
  }

  /// Check if all grades have the same date (indicates it can be combined)
  bool get hasSameDateForAllGrades {
    if (gradeDateMapping.isEmpty) return false;
    final firstDate = gradeDateMapping.values.first;
    return gradeDateMapping.values.every((date) => date == firstDate);
  }

  /// Check if all grades have the same start time
  bool get hasSameStartTimeForAllGrades {
    if (gradeStartTimeMapping.isEmpty) return false;
    final firstTime = gradeStartTimeMapping.values.first;
    return gradeStartTimeMapping.values.every((time) => time == firstTime);
  }

  /// Get the schedule display string for a specific grade
  String getScheduleDisplayForGrade(String gradeId) {
    final startTime = gradeStartTimeMapping[gradeId];
    if (startTime == null) return 'Not scheduled';

    final hours = startTime.inHours;
    final minutes = startTime.inMinutes % 60;
    final endHours = (startTime + Duration(minutes: durationMinutes)).inHours;
    final endMinutes = (startTime + Duration(minutes: durationMinutes)).inMinutes % 60;

    final period = hours >= 12 ? 'PM' : 'AM';
    final displayHours = hours > 12 ? hours - 12 : (hours == 0 ? 12 : hours);
    final displayEndHours = endHours > 12 ? endHours - 12 : (endHours == 0 ? 12 : endHours);

    return '${displayHours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')} $period - '
           '${displayEndHours.toString().padLeft(2, '0')}:${endMinutes.toString().padLeft(2, '0')} ${endHours >= 12 ? 'PM' : 'AM'}';
  }

  /// Copy with modified fields
  GradeSubjectSchedule copyWith({
    String? subjectId,
    String? subjectName,
    Map<String, DateTime>? gradeDateMapping,
    Map<String, Duration>? gradeStartTimeMapping,
    int? durationMinutes,
    String? subjectType,
  }) {
    return GradeSubjectSchedule(
      subjectId: subjectId ?? this.subjectId,
      subjectName: subjectName ?? this.subjectName,
      gradeDateMapping: gradeDateMapping ?? this.gradeDateMapping,
      gradeStartTimeMapping: gradeStartTimeMapping ?? this.gradeStartTimeMapping,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      subjectType: subjectType ?? this.subjectType,
    );
  }
}
