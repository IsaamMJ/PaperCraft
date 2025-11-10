import 'package:flutter/material.dart';

import '../../domain/entities/exam_calendar_entity.dart';
import '../bloc/exam_timetable_state.dart';
import '../pages/exam_timetable_create_wizard_page.dart';

/// Step 1: Select Exam Calendar
///
/// Allows users to select an existing exam calendar to base the timetable on.
/// Shows list of available calendars with their details.
class TimetableWizardStep1Calendar extends StatelessWidget {
  final WizardData wizardData;
  final Function(ExamCalendarEntity) onCalendarSelected;
  final ExamTimetableState state;

  const TimetableWizardStep1Calendar({
    required this.wizardData,
    required this.onCalendarSelected,
    required this.state,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    print('[TimetableWizardStep1Calendar] build: state=${state.runtimeType}');

    // Show loading for initial state or explicit loading state
    if (state is ExamTimetableInitial || state is ExamTimetableLoading) {
      print('[TimetableWizardStep1Calendar] Showing loading state');
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading exam calendars...'),
          ],
        ),
      );
    }

    if (state is ExamCalendarsLoaded) {
      final loadedState = state as ExamCalendarsLoaded;
      final calendars = loadedState.calendars;
      print('[TimetableWizardStep1Calendar] Calendars loaded: ${calendars.length} calendars');

      if (calendars.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_today,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No exam calendars available',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Please create exam calendars first',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        );
      }

      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select an exam calendar to create a timetable',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 16),
              ...calendars.map(
                (calendar) => _buildCalendarCard(context, calendar),
              ),
            ],
          ),
        ),
      );
    }

    if (state is ExamTimetableError) {
      final errorState = state as ExamTimetableError;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading calendars',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              errorState.message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return const SizedBox();
  }

  /// Build calendar selection card
  Widget _buildCalendarCard(
    BuildContext context,
    ExamCalendarEntity calendar,
  ) {
    final isSelected = wizardData.selectedCalendar?.id == calendar.id;
    print('[TimetableWizardStep1Calendar] Building card for: ${calendar.examName} (selected=$isSelected)');
    final now = DateTime.now();
    final isActive = calendar.plannedStartDate.isBefore(now) &&
        calendar.plannedEndDate.isAfter(now);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: isSelected ? Colors.blue[50] : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: () {
            print('[TimetableWizardStep1Calendar] Calendar tapped: ${calendar.examName}');
            onCalendarSelected(calendar);
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with title and status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            calendar.examName,
                            style:
                                Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Type: ${calendar.examType}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.green[100] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          color: isActive ? Colors.green[800] : Colors.grey[800],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Dates
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(calendar.plannedStartDate),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 8),
                    const Text('to'),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(calendar.plannedEndDate),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                if (calendar.paperSubmissionDeadline != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.assignment_turned_in,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Submission: ${_formatDate(calendar.paperSubmissionDeadline!)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                // Selection indicator
                if (isSelected)
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Selected',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Format date to readable string
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
