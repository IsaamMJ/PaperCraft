import 'package:equatable/equatable.dart';
import 'package:papercraft/features/timetable/domain/entities/exam_calendar_entity.dart';
import 'package:papercraft/features/timetable/domain/entities/exam_timetable_entry_entity.dart';

/// Data container for the 3-step exam timetable wizard
/// This holds all intermediate data as user progresses through the wizard
class ExamTimetableWizardData extends Equatable {
  // Tenant and academic year context
  final String tenantId;
  final String academicYear;

  // Step 1: Selected exam calendars (can select multiple)
  final List<ExamCalendarEntity> selectedCalendars;

  // Step 2: Selected grades for the exam calendars
  final Map<String, List<String>> calendarGradeMapping; // calendar_id -> [grade_ids]

  // Step 3: Timetable entries (subject -> date mapping)
  final List<ExamTimetableEntryEntity> timetableEntries;

  // Metadata
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ExamTimetableWizardData({
    required this.tenantId,
    required this.academicYear,
    this.selectedCalendars = const [],
    this.calendarGradeMapping = const {},
    this.timetableEntries = const [],
    this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [
        tenantId,
        academicYear,
        selectedCalendars,
        calendarGradeMapping,
        timetableEntries,
        createdAt,
        updatedAt,
      ];

  /// Check if Step 1 is complete (at least one calendar selected)
  bool isStep1Complete() {
    return selectedCalendars.isNotEmpty;
  }

  /// Check if Step 2 is complete (at least one grade selected for each calendar)
  bool isStep2Complete() {
    if (selectedCalendars.isEmpty) return false;
    for (final calendar in selectedCalendars) {
      if (!(calendarGradeMapping[calendar.id]?.isNotEmpty ?? false)) {
        return false;
      }
    }
    return true;
  }

  /// Check if Step 3 is complete (all subjects assigned to dates)
  bool isStep3Complete() {
    if (timetableEntries.isEmpty) return false;
    // Validation: all entries should have valid dates
    return timetableEntries.every((entry) => entry.examDate != null);
  }

  /// Get all selected grade IDs from Step 2
  List<String> getAllSelectedGradeIds() {
    final gradeIds = <String>{};
    calendarGradeMapping.values.forEach((ids) => gradeIds.addAll(ids));
    return gradeIds.toList();
  }

  /// Get selected grades for a specific calendar
  List<String> getGradesForCalendar(String calendarId) {
    return calendarGradeMapping[calendarId] ?? [];
  }

  /// Copy with modified fields
  ExamTimetableWizardData copyWith({
    String? tenantId,
    String? academicYear,
    List<ExamCalendarEntity>? selectedCalendars,
    Map<String, List<String>>? calendarGradeMapping,
    List<ExamTimetableEntryEntity>? timetableEntries,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExamTimetableWizardData(
      tenantId: tenantId ?? this.tenantId,
      academicYear: academicYear ?? this.academicYear,
      selectedCalendars: selectedCalendars ?? this.selectedCalendars,
      calendarGradeMapping: calendarGradeMapping ?? this.calendarGradeMapping,
      timetableEntries: timetableEntries ?? this.timetableEntries,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Reset wizard data (used for starting over)
  ExamTimetableWizardData reset() {
    return ExamTimetableWizardData(
      tenantId: tenantId,
      academicYear: academicYear,
    );
  }
}
