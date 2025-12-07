import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../domain/entities/exam_timetable_entity.dart';
import '../bloc/exam_timetable_bloc.dart';
import '../bloc/exam_timetable_event.dart';
import '../bloc/exam_timetable_state.dart';
import '../widgets/timetable_list_item.dart';
import 'exam_timetable_detail_page.dart';
import 'exam_timetable_edit_page.dart';

/// Exam Timetable List Page
///
/// Displays list of exam timetables with options to:
/// - Create new timetables
/// - View timetable details
/// - Edit draft timetables
/// - Publish timetables
/// - Archive published timetables
/// - Delete timetables
/// - Filter by status (all, draft, published, archived)
///
/// This is the main management dashboard for exam timetables.
class ExamTimetableListPage extends StatefulWidget {
  final String tenantId;

  const ExamTimetableListPage({
    required this.tenantId,
    super.key,
  });

  @override
  State<ExamTimetableListPage> createState() => _ExamTimetableListPageState();
}

class _ExamTimetableListPageState extends State<ExamTimetableListPage> {
  @override
  void initState() {
    super.initState();
    // Load timetables when page opens
    context.read<ExamTimetableBloc>().add(
          GetExamTimetablesEvent(tenantId: widget.tenantId),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Exam Timetables'),
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshTimetables,
          ),
        ],
      ),
      body: BlocListener<ExamTimetableBloc, ExamTimetableState>(
        listener: (context, state) {
          if (state is ExamTimetablePublishing) {
            // Show loading dialog
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Publishing ${state.timetableName}...',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Assigning question papers to teachers...',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
            );
          } else if (state is ExamTimetablePublished) {
            // Close loading dialog if shown
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }

            // Show results dialog
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('Publication Complete'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          border: Border.all(color: Colors.green[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green[600]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${state.papersAssigned} papers assigned',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          color: Colors.green[600],
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  Text(
                                    'Questions papers successfully created for teachers',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (state.failedAssignments.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            border: Border.all(color: Colors.orange[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.warning, color: Colors.orange[600]),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Failed to assign ${state.failedAssignments.length} papers',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          color: Colors.orange[600],
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...state.failedAssignments.map((failure) => Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '• $failure',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              )),
                            ],
                          ),
                        ),
                      ],
                      if (state.skippedEntries.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            border: Border.all(color: Colors.blue[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info, color: Colors.blue[600]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${state.skippedEntries.length} entries skipped - no teachers assigned',
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                            color: Colors.blue[600],
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...state.skippedEntries.map((skipped) => Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '• $skipped',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.blue[700],
                                      ),
                                ),
                              )),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _refreshTimetables();
                    },
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          } else if (state is ExamTimetableArchived) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Timetable archived successfully'),
                backgroundColor: Colors.green,
              ),
            );
            _refreshTimetables();
          } else if (state is ExamTimetableDeleted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Timetable deleted successfully'),
                backgroundColor: Colors.green,
              ),
            );
            _refreshTimetables();
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

            if (state is ExamTimetablesLoaded) {
              if (state.timetables.isEmpty) {
                return _buildEmptyState(context);
              }

              // Organize timetables by status
              final draftTimetables = state.timetables.where((t) => t.isDraft).toList();
              final publishedTimetables = state.timetables.where((t) => t.isPublished).toList();
              final archivedTimetables = state.timetables.where((t) => t.isArchived).toList();

              return Column(
                children: [
                  // Create button
                  Padding(
                    padding: EdgeInsets.all(UIConstants.paddingMedium),
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToWizard(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Create Timetable'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ),
                  // Timetable sections
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.symmetric(
                        horizontal: UIConstants.paddingMedium,
                      ),
                      children: [
                        if (draftTimetables.isNotEmpty) ...[
                          _buildSectionHeader('Draft', Colors.orange),
                          ...draftTimetables.map((t) => TimetableListItem(
                            timetable: t,
                            onTap: () => _navigateToDetail(context, t),
                            onPublish: () => _publishTimetable(context, t),
                            onArchive: () => _archiveTimetable(context, t),
                            onDelete: () => _deleteTimetable(context, t),
                          )),
                          SizedBox(height: UIConstants.spacing24),
                        ],
                        if (publishedTimetables.isNotEmpty) ...[
                          _buildSectionHeader('Published', Colors.green),
                          ...publishedTimetables.map((t) => TimetableListItem(
                            timetable: t,
                            onTap: () => _navigateToDetail(context, t),
                            onPublish: () => _publishTimetable(context, t),
                            onArchive: () => _archiveTimetable(context, t),
                            onDelete: () => _deleteTimetable(context, t),
                          )),
                          SizedBox(height: UIConstants.spacing24),
                        ],
                        if (archivedTimetables.isNotEmpty) ...[
                          _buildSectionHeader('Archived', Colors.grey),
                          ...archivedTimetables.map((t) => TimetableListItem(
                            timetable: t,
                            onTap: () => _navigateToDetail(context, t),
                            onPublish: () => _publishTimetable(context, t),
                            onArchive: () => _archiveTimetable(context, t),
                            onDelete: () => _deleteTimetable(context, t),
                          )),
                        ],
                      ],
                    ),
                  ),
                ],
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
                      'Error loading timetables',
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
                      onPressed: _refreshTimetables,
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


  /// Build empty state
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.schedule,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No timetables scheduled',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first timetable to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _navigateToWizard(context),
            icon: const Icon(Icons.add),
            label: const Text('Create Timetable'),
          ),
        ],
      ),
    );
  }

  /// Build section header with colored bar (like exam calendars)
  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: EdgeInsets.only(
        top: UIConstants.spacing12,
        bottom: UIConstants.spacing12,
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: UIConstants.spacing12),
          Text(
            title,
            style: TextStyle(
              fontSize: UIConstants.fontSizeLarge,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }


  /// Refresh timetables
  void _refreshTimetables() {
    context.read<ExamTimetableBloc>().add(
          GetExamTimetablesEvent(tenantId: widget.tenantId),
        );
  }

  /// Navigate to timetable detail page
  void _navigateToDetail(
    BuildContext context,
    ExamTimetableEntity timetable,
  ) {
    try {

      // Get the BLoC from current context before navigating
      final bloc = context.read<ExamTimetableBloc>();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BlocProvider<ExamTimetableBloc>.value(
            value: bloc,
            child: ExamTimetableDetailPage(
              timetableId: timetable.id,
              tenantId: widget.tenantId,
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Navigate to wizard for creating new timetable
  void _navigateToWizard(BuildContext context) {
    // Use GoRouter to navigate to the new wizard
    context.pushNamed('examTimetableWizard').then((_) {
      // Refresh list when returning from wizard
      _refreshTimetables();
    });
  }

  /// Edit timetable (only for draft)
  void _editTimetable(
    BuildContext context,
    ExamTimetableEntity timetable,
  ) {
    if (!timetable.isDraft) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only draft timetables can be edited'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Get the BLoC from current context before navigating
    final bloc = context.read<ExamTimetableBloc>();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider<ExamTimetableBloc>.value(
          value: bloc,
          child: ExamTimetableEditPage(
            timetableId: timetable.id,
            tenantId: widget.tenantId,
            createdBy: timetable.createdBy ?? 'unknown',
          ),
        ),
      ),
    ).then((_) {
      // Refresh list when returning from edit page
      _refreshTimetables();
    });
  }

  /// Publish timetable
  void _publishTimetable(
    BuildContext context,
    ExamTimetableEntity timetable,
  ) {
    if (!timetable.isDraft) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only draft timetables can be published'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }


    // IMPORTANT: Capture the BLoC BEFORE showing the dialog
    // This is because the dialog's context doesn't include the BLoC provider
    final bloc = context.read<ExamTimetableBloc>();

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Publish Timetable?'),
        content: Text(
          'Are you sure you want to publish "${timetable.examName}"? '
          'Published timetables cannot be edited.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              bloc.add(PublishExamTimetableEvent(
                timetableId: timetable.id,
                timetableName: timetable.examName,
              ));
            },
            child: const Text('Publish'),
          ),
        ],
      ),
    );
  }

  /// Archive timetable
  void _archiveTimetable(
    BuildContext context,
    ExamTimetableEntity timetable,
  ) {
    if (!timetable.isPublished) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only published timetables can be archived'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // IMPORTANT: Capture the BLoC BEFORE showing the dialog
    // This is because the dialog's context doesn't include the BLoC provider
    final bloc = context.read<ExamTimetableBloc>();

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive Timetable?'),
        content: Text(
          'Archive "${timetable.examName}"? '
          'Archived timetables are read-only.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              bloc.add(ArchiveExamTimetableEvent(timetableId: timetable.id));
            },
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }

  /// Delete timetable
  void _deleteTimetable(
    BuildContext context,
    ExamTimetableEntity timetable,
  ) {
    if (!timetable.isDraft) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only draft timetables can be deleted'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }


    // IMPORTANT: Capture the BLoC BEFORE showing the dialog
    // This is because the dialog's context doesn't include the BLoC provider
    final bloc = context.read<ExamTimetableBloc>();

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Timetable?'),
        content: Text(
          'Are you sure you want to delete "${timetable.examName}"? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              bloc.add(DeleteExamTimetableEvent(timetableId: timetable.id));
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
}
