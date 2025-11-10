import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/exam_calendar_entity.dart';
import '../bloc/exam_timetable_bloc.dart';
import '../bloc/exam_timetable_event.dart';
import '../bloc/exam_timetable_state.dart';
import '../widgets/exam_calendar_form_dialog.dart';

/// Exam Calendar Setup Page
///
/// Displays a list of exam calendars with options to:
/// - Create new exam calendars
/// - Edit existing calendars
/// - View calendar details
/// - Manage exam timetables for each calendar
///
/// This is typically accessed by admins to set up exam periods
/// before creating detailed timetables.
class ExamCalendarSetupPage extends StatefulWidget {
  final String tenantId;

  const ExamCalendarSetupPage({
    required this.tenantId,
    super.key,
  });

  @override
  State<ExamCalendarSetupPage> createState() => _ExamCalendarSetupPageState();
}

class _ExamCalendarSetupPageState extends State<ExamCalendarSetupPage> {
  @override
  void initState() {
    super.initState();
    // Load calendars when page opens
    context.read<ExamTimetableBloc>().add(
          GetExamCalendarsEvent(tenantId: widget.tenantId),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Calendar Setup'),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Tooltip(
              message: 'Create new exam calendar',
              child: TextButton.icon(
                onPressed: () => _showCreateCalendarDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('New Calendar'),
              ),
            ),
          ),
        ],
      ),
      body: BlocListener<ExamTimetableBloc, ExamTimetableState>(
        listener: (context, state) {
          if (state is ExamCalendarCreated) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Exam calendar created successfully'),
                backgroundColor: Colors.green,
              ),
            );
            // Refresh the list
            context.read<ExamTimetableBloc>().add(
                  GetExamCalendarsEvent(tenantId: widget.tenantId),
                );
          } else if (state is ExamCalendarUpdated) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Exam calendar updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
            context.read<ExamTimetableBloc>().add(
                  GetExamCalendarsEvent(tenantId: widget.tenantId),
                );
          } else if (state is ExamTimetableError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: BlocBuilder<ExamTimetableBloc, ExamTimetableState>(
          builder: (context, state) {
            if (state is ExamTimetableLoading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (state is ExamCalendarsLoaded) {
              if (state.calendars.isEmpty) {
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
                        'No exam calendars created yet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create an exam calendar to get started',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _showCreateCalendarDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Create Calendar'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.calendars.length,
                itemBuilder: (context, index) {
                  final calendar = state.calendars[index];
                  return _buildCalendarCard(context, calendar);
                },
              );
            }

            if (state is ExamTimetableError) {
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
                      state.message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        context.read<ExamTimetableBloc>().add(
                              GetExamCalendarsEvent(tenantId: widget.tenantId),
                            );
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            return const SizedBox.expand(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Build individual calendar card
  Widget _buildCalendarCard(
    BuildContext context,
    ExamCalendarEntity calendar,
  ) {
    final now = DateTime.now();
    final isActive = calendar.plannedStartDate.isBefore(now) &&
        calendar.plannedEndDate.isAfter(now);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            title: Text(calendar.examName),
            subtitle: Text(
              'Exam Type: ${calendar.examType}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: _buildStatusBadge(isActive),
            isThreeLine: false,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                _buildInfoRow(
                  context,
                  Icons.calendar_today,
                  'Start Date',
                  _formatDate(calendar.plannedStartDate),
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  context,
                  Icons.event,
                  'End Date',
                  _formatDate(calendar.plannedEndDate),
                ),
                const SizedBox(height: 8),
                if (calendar.paperSubmissionDeadline != null)
                  _buildInfoRow(
                    context,
                    Icons.assignment_turned_in,
                    'Submission Deadline',
                    _formatDate(calendar.paperSubmissionDeadline!),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _navigateToTimetables(context, calendar),
                    child: const Text('View Timetables'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showEditCalendarDialog(context, calendar),
                    child: const Text('Edit'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build status badge
  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
    );
  }

  /// Build info row with icon, label, and value
  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }

  /// Format date to readable string
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Show create calendar dialog
  void _showCreateCalendarDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ExamCalendarFormDialog(
        tenantId: widget.tenantId,
        onSubmit: (calendar) {
          context.read<ExamTimetableBloc>().add(
                CreateExamCalendarEvent(calendar: calendar),
              );
          Navigator.of(context).pop();
        },
      ),
    );
  }

  /// Show edit calendar dialog
  void _showEditCalendarDialog(
    BuildContext context,
    ExamCalendarEntity calendar,
  ) {
    showDialog(
      context: context,
      builder: (context) => ExamCalendarFormDialog(
        tenantId: widget.tenantId,
        initialCalendar: calendar,
        onSubmit: (updatedCalendar) {
          context.read<ExamTimetableBloc>().add(
                UpdateExamCalendarEvent(calendar: updatedCalendar),
              );
          Navigator.of(context).pop();
        },
      ),
    );
  }

  /// Navigate to timetables page for this calendar
  void _navigateToTimetables(
    BuildContext context,
    ExamCalendarEntity calendar,
  ) {
    // TODO: Implement navigation to timetables list page when available
    // For now, just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigate to timetables for ${calendar.examName}'),
      ),
    );
  }
}
