import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/exam_timetable_entity.dart';
import '../../domain/entities/exam_timetable_entry_entity.dart';
import '../pages/exam_timetable_create_wizard_page.dart';

/// Subject schedule entry for a specific grade-section and date
class SubjectSchedule {
  final String gradeId;
  final String section;
  String? selectedSubject;
  DateTime examDate;

  // Fixed times (not shown in UI but used when generating entries)
  static const Duration defaultStartTime = Duration(hours: 10);
  static const Duration defaultEndTime = Duration(hours: 12);

  SubjectSchedule({
    required this.gradeId,
    required this.section,
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

  String get gradeSection => '$gradeId-$section';
}

/// Step 4: Schedule Subjects by Grade-Section
///
/// Allows users to assign exam subjects to dates for each grade and section.
/// Respects the academic structure: only shows valid subjects for each grade-section.
///
/// Uses a tabbed interface where each tab represents a grade.
/// For each grade's sections, users assign subjects for exam dates.
///
/// When submitted, automatically generates entries for all scheduled grade-section-subject combinations.
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
    extends State<TimetableWizardStep4Schedule>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late Map<String, List<SubjectSchedule>> _schedulesByGrade;

  @override
  void initState() {
    super.initState();
    _initializeSchedules();
    _tabController = TabController(
      length: widget.wizardData.selectedGrades.length,
      vsync: this,
    );
    // Auto-generate entries when initialization completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateAndPassEntries();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Initialize schedules for exam dates and grade-sections
  void _initializeSchedules() {
    _schedulesByGrade = {};

    // Get dates from calendar if available
    // For now, using mock dates - in production, fetch from calendar entity
    final now = DateTime.now();
    final mockDates = List.generate(5, (i) => now.add(Duration(days: i + 1)));

    // For each selected grade, create schedules for all sections and dates
    for (final gradeSelection in widget.wizardData.selectedGrades) {
      final gradeId = gradeSelection.gradeId;
      final gradeSchedules = <SubjectSchedule>[];

      // For each section in the grade
      for (final section in gradeSelection.sections) {
        // For each exam date, create a schedule entry
        for (final examDate in mockDates) {
          gradeSchedules.add(
            SubjectSchedule(
              gradeId: gradeId,
              section: section,
              examDate: examDate,
            ),
          );
        }
      }

      _schedulesByGrade[gradeId] = gradeSchedules;
    }
  }

  /// Get available subjects for a specific grade-section
  List<String> _getSubjectsForGradeSection(String gradeId, String section) {
    // Build the key as expected from Step 3: "gradeId_section"
    final key = '${gradeId}_$section';
    return widget.wizardData.validSubjectsPerGradeSection[key] ?? [];
  }

  /// Generate and pass entries to parent when all schedules are complete
  void _generateAndPassEntries() {
    // Only generate if all schedules are complete
    final allSchedules = _schedulesByGrade.values.expand((s) => s).toList();
    if (allSchedules.isNotEmpty && allSchedules.every((s) => s.isComplete)) {
      final entries = _generateEntries();
      widget.onEntriesGenerated(entries);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grades = widget.wizardData.selectedGrades;

    // Check if valid subjects are available
    if (widget.wizardData.validSubjectsPerGradeSection.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 64,
              color: Colors.orange[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No valid subjects configured',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Please ensure subjects are configured in the academic structure for the selected grades',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Tab bar for grade selection
        Material(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            tabs: grades
                .map((grade) => Tab(
                      child: Text('Grade ${grade.gradeName}'),
                    ))
                .toList(),
            indicatorColor: Colors.blue,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey[600],
          ),
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: grades
                .asMap()
                .entries
                .map((entry) {
                  final gradeId = entry.value.gradeId;
                  return _buildGradeTab(context, gradeId, entry.value);
                })
                .toList(),
          ),
        ),
      ],
    );
  }

  /// Build tab content for a specific grade
  Widget _buildGradeTab(
    BuildContext context,
    String gradeId,
    GradeSelection grade,
  ) {
    final gradeSchedules = _schedulesByGrade[gradeId] ?? [];

    // Group schedules by section
    final schedulesBySection = <String, List<SubjectSchedule>>{};
    for (final schedule in gradeSchedules) {
      schedulesBySection.putIfAbsent(schedule.section, () => []).add(schedule);
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions
            Text(
              'Assign subjects for Grade ${grade.gradeName}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select subjects for each section and date. Only subjects configured for this grade are shown.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 24),

            // Sections with their schedules
            ...schedulesBySection.entries.map((entry) {
              final section = entry.key;
              final sectionSchedules = entry.value;
              return _buildSectionGroup(
                context,
                gradeId,
                section,
                sectionSchedules,
              );
            }).toList(),

            const SizedBox(height: 16),

            // Progress summary
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
                        'Scheduled: ${_getCompletedCount()}/${_getTotalCount()} entries',
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

  /// Build section group with all date schedules
  Widget _buildSectionGroup(
    BuildContext context,
    String gradeId,
    String section,
    List<SubjectSchedule> schedules,
  ) {
    // Get valid subjects for this grade-section
    final validSubjects = _getSubjectsForGradeSection(gradeId, section);

    // Check if no subjects are available
    if (validSubjects.isEmpty) {
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        color: Colors.orange[50],
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No subjects configured for Section $section',
                  style: TextStyle(color: Colors.orange[700]),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Text(
                'Section $section',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.blue[900],
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${validSubjects.length} subjects available)',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.blue[700],
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Date cards for this section
        ...schedules.asMap().entries.map((entry) {
          final index = entry.key;
          final schedule = entry.value;
          return _buildScheduleCard(
            context,
            index,
            schedule,
            validSubjects,
          );
        }).toList(),

        const SizedBox(height: 20),
      ],
    );
  }

  /// Build schedule card for a date
  Widget _buildScheduleCard(
    BuildContext context,
    int index,
    SubjectSchedule schedule,
    List<String> validSubjects,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Text(
              schedule.dateDisplay,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

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
              items: validSubjects
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  schedule.selectedSubject = value;
                  // Check if all schedules complete and generate entries
                  if (_allSchedulesComplete()) {
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

  /// Check if all schedules are complete
  bool _allSchedulesComplete() {
    for (final schedules in _schedulesByGrade.values) {
      if (!schedules.every((s) => s.isComplete)) {
        return false;
      }
    }
    return true;
  }

  /// Get count of completed schedules
  int _getCompletedCount() {
    int count = 0;
    for (final schedules in _schedulesByGrade.values) {
      count += schedules.where((s) => s.isComplete).length;
    }
    return count;
  }

  /// Get total count of schedules
  int _getTotalCount() {
    int count = 0;
    for (final schedules in _schedulesByGrade.values) {
      count += schedules.length;
    }
    return count;
  }

  /// Generate entries for all grades and schedules
  List<ExamTimetableEntryEntity> _generateEntries() {
    final entries = <ExamTimetableEntryEntity>[];
    final now = DateTime.now();

    for (final schedules in _schedulesByGrade.values) {
      for (final schedule in schedules) {
        if (!schedule.isComplete) continue;

        const uuid = Uuid();
        final entry = ExamTimetableEntryEntity(
          id: null,
          tenantId: widget.wizardData.tenantId,
          timetableId: '', // Will be set when timetable is created
          gradeSectionId: uuid.v4(), // Placeholder
          gradeId: schedule.gradeId,
          section: schedule.section,
          subjectId: schedule.selectedSubject!,
          examDate: schedule.examDate,
          startTime: schedule.startTime,
          endTime: schedule.endTime,
          durationMinutes: schedule.endTime.inMinutes - schedule.startTime.inMinutes,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );
        entries.add(entry);
      }
    }

    return entries;
  }

  /// Validate all schedules are complete
  bool _validateSchedules() {
    // Check if all schedules are complete
    if (!_allSchedulesComplete()) {
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
