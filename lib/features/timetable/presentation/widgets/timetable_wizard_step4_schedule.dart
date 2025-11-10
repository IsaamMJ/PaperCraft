import 'package:flutter/material.dart';
import '../../domain/entities/exam_timetable_entity.dart';
import '../../domain/entities/exam_timetable_entry_entity.dart';
import '../pages/exam_timetable_create_wizard_page.dart';

/// Subject schedule entry for a specific date
class SubjectSchedule {
  String? selectedSubject;
  Duration? startTime;
  Duration? endTime;
  DateTime examDate;

  SubjectSchedule({
    required this.examDate,
    this.selectedSubject,
    this.startTime,
    this.endTime,
  });

  bool get isComplete => selectedSubject != null && startTime != null && endTime != null;

  String get displayTime {
    if (startTime == null || endTime == null) return 'Not set';
    final startHour = startTime!.inHours;
    final startMin = startTime!.inMinutes % 60;
    final endHour = endTime!.inHours;
    final endMin = endTime!.inMinutes % 60;
    return '${startHour.toString().padLeft(2, '0')}:${startMin.toString().padLeft(2, '0')} - '
        '${endHour.toString().padLeft(2, '0')}:${endMin.toString().padLeft(2, '0')}';
  }

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
  final ExamTimetableEntity? calendar;
  final Function(List<ExamTimetableEntryEntity>) onEntriesGenerated;

  const TimetableWizardStep4Schedule({
    required this.wizardData,
    required this.calendar,
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
              'The same time will apply to all selected grades.',
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

  /// Build schedule card for a date
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

            // Subject selection dropdown
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
                });
              },
              validator: (value) =>
                  value == null ? 'Please select a subject' : null,
            ),
            const SizedBox(height: 16),

            // Start time
            GestureDetector(
              onTap: () => _selectStartTime(index),
              child: AbsorbPointer(
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Start Time (HH:MM)',
                    hintText: '09:00',
                    prefixIcon: const Icon(Icons.schedule),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  controller: TextEditingController(
                    text: schedule.startTime != null
                        ? '${schedule.startTime!.inHours.toString().padLeft(2, '0')}:'
                            '${(schedule.startTime!.inMinutes % 60).toString().padLeft(2, '0')}'
                        : '',
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Select start time' : null,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // End time
            GestureDetector(
              onTap: () => _selectEndTime(index),
              child: AbsorbPointer(
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'End Time (HH:MM)',
                    hintText: '11:00',
                    prefixIcon: const Icon(Icons.schedule),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  controller: TextEditingController(
                    text: schedule.endTime != null
                        ? '${schedule.endTime!.inHours.toString().padLeft(2, '0')}:'
                            '${(schedule.endTime!.inMinutes % 60).toString().padLeft(2, '0')}'
                        : '',
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Select end time' : null,
                ),
              ),
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
                      '${schedule.selectedSubject} at ${schedule.displayTime}',
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
                'Incomplete',
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

  /// Select start time for a schedule
  Future<void> _selectStartTime(int scheduleIndex) async {
    final schedule = _schedules[scheduleIndex];
    final initialTime = schedule.startTime ?? const Duration(hours: 9);

    final hours = initialTime.inHours;
    final minutes = initialTime.inMinutes % 60;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => TimePickerDialog(
        initialTime: TimeOfDay(hour: hours, minute: minutes),
        onTimeSelected: (timeOfDay) {
          setState(() {
            schedule.startTime = Duration(
              hours: timeOfDay.hour,
              minutes: timeOfDay.minute,
            );
          });
        },
      ),
    );
  }

  /// Select end time for a schedule
  Future<void> _selectEndTime(int scheduleIndex) async {
    final schedule = _schedules[scheduleIndex];
    final initialTime = schedule.endTime ?? const Duration(hours: 11);

    final hours = initialTime.inHours;
    final minutes = initialTime.inMinutes % 60;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => TimePickerDialog(
        initialTime: TimeOfDay(hour: hours, minute: minutes),
        onTimeSelected: (timeOfDay) {
          setState(() {
            schedule.endTime = Duration(
              hours: timeOfDay.hour,
              minutes: timeOfDay.minute,
            );
          });
        },
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
    // Check if all schedules are complete
    if (_schedules.any((s) => !s.isComplete)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all subject schedules'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    // Check if end time is after start time for all
    for (final schedule in _schedules) {
      if (schedule.endTime! <= schedule.startTime!) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'End time must be after start time for ${schedule.dateDisplay}',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
    }

    return true;
  }

  /// Notify parent of generated entries
  void notifySchedulesGenerated() {
    if (!_validateSchedules()) return;
    final entries = _generateEntries();
    widget.onEntriesGenerated(entries);
  }
}

/// Custom time picker dialog
class TimePickerDialog extends StatefulWidget {
  final TimeOfDay initialTime;
  final Function(TimeOfDay) onTimeSelected;

  const TimePickerDialog({
    required this.initialTime,
    required this.onTimeSelected,
    super.key,
  });

  @override
  State<TimePickerDialog> createState() => _TimePickerDialogState();
}

class _TimePickerDialogState extends State<TimePickerDialog> {
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.initialTime;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Time'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Hour selector
              SizedBox(
                width: 80,
                child: TextField(
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  controller: TextEditingController(
                    text: _selectedTime.hour.toString().padLeft(2, '0'),
                  ),
                  onChanged: (value) {
                    final hour = int.tryParse(value) ?? _selectedTime.hour;
                    if (hour >= 0 && hour < 24) {
                      setState(() {
                        _selectedTime = _selectedTime.replacing(hour: hour);
                      });
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'HH',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(':', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              // Minute selector
              SizedBox(
                width: 80,
                child: TextField(
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  controller: TextEditingController(
                    text: _selectedTime.minute.toString().padLeft(2, '0'),
                  ),
                  onChanged: (value) {
                    final minute = int.tryParse(value) ?? _selectedTime.minute;
                    if (minute >= 0 && minute < 60) {
                      setState(() {
                        _selectedTime = _selectedTime.replacing(minute: minute);
                      });
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'MM',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Selected: ${_selectedTime.format(context)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onTimeSelected(_selectedTime);
            Navigator.pop(context);
          },
          child: const Text('Select'),
        ),
      ],
    );
  }
}
