import 'package:flutter/material.dart';
import '../../domain/entities/exam_timetable_entity.dart';
import '../../domain/entities/exam_timetable_entry_entity.dart';
import '../pages/exam_timetable_create_wizard_page.dart';

/// Subject schedule entry for a specific date
/// Uses fixed time: 10:00 AM - 12:00 PM (2 hours)
class SubjectSchedule {
  String? selectedSubject;
  DateTime examDate;

  // Fixed times (not shown in UI but used when generating entries)
  static const Duration defaultStartTime = Duration(hours: 10);
  static const Duration defaultEndTime = Duration(hours: 12);

  SubjectSchedule({
    required this.examDate,
    this.selectedSubject,
  });

  // A schedule is complete when subject is selected (time is always fixed)
  bool get isComplete => selectedSubject != null;

  // Get start time (always 10:00 AM)
  Duration get startTime => defaultStartTime;

  // Get end time (always 12:00 PM)
  Duration get endTime => defaultEndTime;

  String get dateDisplay {
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = monthNames[examDate.month - 1];
    return '$month ${examDate.day}';
  }
}

/// Step 4: Schedule Subjects by Date
///
/// Allows users to map subjects to exam dates.
/// For each exam date from the calendar, select:
/// - Which subject will be conducted
/// - What time (applies to all selected grades)
///
/// When submitted, automatically generates entries for all grades × subjects.
class TimetableWizardStep4Schedule extends StatefulWidget {
  final WizardData wizardData;
  final Function(List<ExamTimetableEntryEntity>) onEntriesGenerated;

  const TimetableWizardStep4Schedule({
    required this.wizardData,
    required this.onEntriesGenerated,
    super.key,
  });

  @override
  State<TimetableWizardStep4Schedule> createState() =>
      _TimetableWizardStep4ScheduleState();
}

class _TimetableWizardStep4ScheduleState
    extends State<TimetableWizardStep4Schedule> {
  late List<SubjectSchedule> _schedules;

  /// Available subjects
  final List<String> _subjects = [
    'Mathematics',
    'English',
    'Science',
    'Social Studies',
    'Hindi',
    'Computer',
    'Physical Education',
    'Art',
  ];

  @override
  void initState() {
    super.initState();
    _initializeSchedules();
    // Auto-generate entries when initialization completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateAndPassEntries();
    });
  }

  /// Initialize schedules for exam dates from calendar
  void _initializeSchedules() {
    _schedules = [];
    // Get dates from calendar if available
    // For now, using mock dates - in production, fetch from calendar entity
    final now = DateTime.now();
    for (var i = 0; i < 5; i++) {
      _schedules.add(
        SubjectSchedule(examDate: now.add(Duration(days: i + 1))),
      );
    }
  }

  /// Generate and pass entries to parent when all schedules are complete
  void _generateAndPassEntries() {
    // Only generate if all schedules are complete (no validation - that shows snackbar)
    if (_schedules.every((s) => s.isComplete)) {
      final entries = _generateEntries();
      widget.onEntriesGenerated(entries);
      print('[TimetableWizardStep4Schedule] Generated and passed ${entries.length} entries to parent');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions
            Text(
              'Schedule subjects for exam dates',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select which subject will be conducted on each date. '
              'All exams are scheduled for 10:00 AM - 12:00 PM.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 24),

            // Schedule cards
            ..._schedules.asMap().entries.map((entry) {
              final index = entry.key;
              final schedule = entry.value;
              return _buildScheduleCard(context, index, schedule);
            }).toList(),

            const SizedBox(height: 24),

            // Summary
            if (_getCompletedCount() > 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Scheduled: ${_getCompletedCount()}/${_schedules.length} dates',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.green[800],
                            ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build schedule card for a date (date + subject only, time is fixed internally)
  Widget _buildScheduleCard(
    BuildContext context,
    int index,
    SubjectSchedule schedule,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Text(
              schedule.dateDisplay,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // Subject selection dropdown (only input field)
            DropdownButtonFormField<String>(
              value: schedule.selectedSubject,
              decoration: InputDecoration(
                labelText: 'Subject',
                prefixIcon: const Icon(Icons.book),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: _subjects
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  schedule.selectedSubject = value;
                  // Check if all schedules complete and generate entries
                  if (_schedules.every((s) => s.isComplete)) {
                    _generateAndPassEntries();
                  }
                });
              },
              validator: (value) =>
                  value == null ? 'Please select a subject' : null,
            ),

            // Status indicator
            const SizedBox(height: 12),
            if (schedule.isComplete)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${schedule.selectedSubject} - 10:00 AM to 12:00 PM',
                      style: TextStyle(
                        color: Colors.green[800],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                'Please select a subject',
                style: TextStyle(
                  color: Colors.orange[700],
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Get count of completed schedules
  int _getCompletedCount() {
    return _schedules.where((s) => s.isComplete).length;
  }

  /// Generate entries for all grades and schedules
  List<ExamTimetableEntryEntity> _generateEntries() {
    final entries = <ExamTimetableEntryEntity>[];
    final now = DateTime.now();

    for (final schedule in _schedules) {
      if (!schedule.isComplete) continue;

      // Generate entry for each selected grade
      for (final gradeSelection in widget.wizardData.selectedGrades) {
        for (final section in gradeSelection.sections) {
          final entry = ExamTimetableEntryEntity(
            id: 'entry_${DateTime.now().millisecondsSinceEpoch}_${entries.length}',
            tenantId: widget.wizardData.tenantId,
            timetableId: '', // Will be set when timetable is created
            gradeId: gradeSelection.gradeId,
            section: section,
            subjectId: schedule.selectedSubject!,
            examDate: schedule.examDate,
            startTime: schedule.startTime!,
            endTime: schedule.endTime!,
            durationMinutes: schedule.endTime!.inMinutes - schedule.startTime!.inMinutes,
            isActive: true,
            createdAt: now,
            updatedAt: now,
          );
          entries.add(entry);
        }
      }
    }

    return entries;
  }

  /// Validate all schedules are complete
  bool _validateSchedules() {
    // Check if all schedules are complete (all subjects selected)
    if (_schedules.any((s) => !s.isComplete)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all subject schedules'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    return true;
  }

}
