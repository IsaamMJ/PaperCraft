import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/exam_timetable_bloc.dart';
import '../bloc/exam_timetable_event.dart';
import '../bloc/exam_timetable_state.dart';
import '../../domain/entities/exam_timetable.dart';

/// Page to view exam timetables
///
/// Allows admins to:
/// - View all timetables (draft, published, completed)
/// - Create new timetable
/// - Edit timetable entries
/// - Publish timetable (triggers paper auto-creation)
class ExamTimetableListPage extends StatefulWidget {
  final String tenantId;
  final String academicYear;

  const ExamTimetableListPage({
    Key? key,
    required this.tenantId,
    required this.academicYear,
  }) : super(key: key);

  @override
  State<ExamTimetableListPage> createState() => _ExamTimetableListPageState();
}

class _ExamTimetableListPageState extends State<ExamTimetableListPage> {
  @override
  void initState() {
    super.initState();
    // Load timetables on init
    context.read<ExamTimetableBloc>().add(
          LoadExamTimetablesEvent(
            tenantId: widget.tenantId,
            academicYear: widget.academicYear,
          ),
        );
  }

  void _showDeleteConfirmation(String timetableId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Timetable?'),
        content: const Text('This will deactivate the timetable.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<ExamTimetableBloc>().add(
                    DeleteTimetableEvent(timetableId: timetableId),
                  );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Exam Timetables - ${widget.academicYear}'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<ExamTimetableBloc>().add(
                    RefreshTimetablesEvent(tenantId: widget.tenantId),
                  );
            },
          ),
        ],
      ),
      body: BlocListener<ExamTimetableBloc, ExamTimetableState>(
        listener: (context, state) {
          if (state is TimetablePublished) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${state.timetable.displayName} published! ${state.papersCreated} papers created.',
                ),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is PublishTimetableError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${state.message}'),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is TimetableDeleted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Timetable deleted'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        child: BlocBuilder<ExamTimetableBloc, ExamTimetableState>(
          builder: (context, state) {
            // Loading state
            if (state is ExamTimetableLoading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            // Empty state
            if (state is ExamTimetableEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.schedule,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No timetables found',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Navigate to create timetable page
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Create Timetable'),
                    ),
                  ],
                ),
              );
            }

            // Error state
            if (state is ExamTimetableError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        context.read<ExamTimetableBloc>().add(
                              RefreshTimetablesEvent(tenantId: widget.tenantId),
                            );
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            // Loaded state
            if (state is ExamTimetableLoaded) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Navigate to create timetable page
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Create Timetable'),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: state.timetables.length,
                      itemBuilder: (context, index) {
                        final timetable = state.timetables[index];
                        return _ExamTimetableCard(
                          timetable: timetable,
                          onEdit: () {
                            // TODO: Navigate to edit page
                          },
                          onPublish: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Publish Timetable?'),
                                content: const Text(
                                  'This will validate all entries and create papers for all teachers. This action cannot be undone.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      context.read<ExamTimetableBloc>().add(
                                            PublishTimetableEvent(
                                              timetableId: timetable.id,
                                            ),
                                          );
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Publish'),
                                  ),
                                ],
                              ),
                            );
                          },
                          onDelete: () => _showDeleteConfirmation(timetable.id),
                        );
                      },
                    ),
                  ),
                ],
              );
            }

            return const Center(
              child: Text('Loading...'),
            );
          },
        ),
      ),
    );
  }
}

class _ExamTimetableCard extends StatelessWidget {
  final ExamTimetable timetable;
  final VoidCallback onEdit;
  final VoidCallback onPublish;
  final VoidCallback onDelete;

  const _ExamTimetableCard({
    required this.timetable,
    required this.onEdit,
    required this.onPublish,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(timetable.status);
    final statusLabel = timetable.status.toShortString();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timetable.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timetable.academicYear,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(statusLabel),
                  backgroundColor: statusColor.withOpacity(0.2),
                  labelStyle: TextStyle(color: statusColor),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Published date if applicable
            if (timetable.publishedAt != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'Published: ${DateFormat('MMM d, yyyy').format(timetable.publishedAt!)}',
                      style: const TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            // Action buttons
            Wrap(
              spacing: 8,
              children: [
                if (timetable.canEdit)
                  OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                  ),
                if (timetable.isDraft)
                  ElevatedButton.icon(
                    onPressed: onPublish,
                    icon: const Icon(Icons.publish),
                    label: const Text('Publish'),
                  ),
                if (timetable.canEdit)
                  OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(TimetableStatus status) {
    switch (status) {
      case TimetableStatus.draft:
        return Colors.blue;
      case TimetableStatus.published:
        return Colors.green;
      case TimetableStatus.completed:
        return Colors.purple;
      case TimetableStatus.cancelled:
        return Colors.red;
    }
  }
}
