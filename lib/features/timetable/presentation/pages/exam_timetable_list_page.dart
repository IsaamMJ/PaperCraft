import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/exam_timetable_entity.dart';
import '../bloc/exam_timetable_bloc.dart';
import '../bloc/exam_timetable_event.dart';
import '../bloc/exam_timetable_state.dart';
import '../widgets/timetable_list_item.dart';
import 'exam_timetable_create_wizard_page.dart';
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
  /// Current filter status
  String _filterStatus = 'all'; // all, draft, published, archived

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
      appBar: AppBar(
        title: const Text('Exam Timetables'),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Tooltip(
              message: 'Create new timetable',
              child: TextButton.icon(
                onPressed: () => _navigateToWizard(context),
                icon: const Icon(Icons.add),
                label: const Text('New'),
              ),
            ),
          ),
        ],
      ),
      body: BlocListener<ExamTimetableBloc, ExamTimetableState>(
        listener: (context, state) {
          if (state is ExamTimetablePublished) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Timetable published successfully'),
                backgroundColor: Colors.green,
              ),
            );
            _refreshTimetables();
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
              final filteredTimetables = _filterTimetables(state.timetables);

              if (filteredTimetables.isEmpty) {
                return _buildEmptyState(context);
              }

              return Column(
                children: [
                  // Filter chips
                  _buildFilterBar(),
                  // Timetable list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredTimetables.length,
                      itemBuilder: (context, index) {
                        final timetable = filteredTimetables[index];
                        return TimetableListItem(
                          timetable: timetable,
                          onTap: () => _navigateToDetail(context, timetable),
                          onPublish: () =>
                              _publishTimetable(context, timetable),
                          onArchive: () =>
                              _archiveTimetable(context, timetable),
                          onDelete: () =>
                              _deleteTimetable(context, timetable),
                        );
                      },
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
            Icons.calendar_today,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No timetables found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _filterStatus == 'all'
                ? 'Create a new timetable to get started'
                : 'No timetables in this status',
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

  /// Build filter bar
  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _buildFilterChip('All', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip('Draft', 'draft'),
          const SizedBox(width: 8),
          _buildFilterChip('Published', 'published'),
          const SizedBox(width: 8),
          _buildFilterChip('Archived', 'archived'),
        ],
      ),
    );
  }

  /// Build filter chip
  Widget _buildFilterChip(String label, String status) {
    final isSelected = _filterStatus == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = status;
        });
      },
      backgroundColor: Colors.white,
      selectedColor: Colors.blue[100],
      side: BorderSide(
        color: isSelected ? Colors.blue : Colors.grey[300]!,
      ),
    );
  }

  /// Filter timetables by status
  List<ExamTimetableEntity> _filterTimetables(
    List<ExamTimetableEntity> timetables,
  ) {
    if (_filterStatus == 'all') {
      return timetables;
    }
    return timetables.where((t) => t.status == _filterStatus).toList();
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
      print('[ExamTimetableListPage] VIEW: Timetable ${timetable.examName} (ID: ${timetable.id}, Status: ${timetable.status})');
      print('[ExamTimetableListPage] VIEW: Attempting navigation...');

      // Get the BLoC from current context before navigating
      final bloc = context.read<ExamTimetableBloc>();
      print('[ExamTimetableListPage] VIEW: BLoC retrieved: $bloc');

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
      print('[ExamTimetableListPage] VIEW: Navigation completed');
    } catch (e) {
      print('[ExamTimetableListPage] VIEW ERROR: $e');
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

    print('[ExamTimetableListPage] EDIT: Timetable ${timetable.examName} (ID: ${timetable.id})');
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

    print('[ExamTimetableListPage] PUBLISH: Confirming timetable ${timetable.examName} (ID: ${timetable.id})');
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publish Timetable?'),
        content: Text(
          'Are you sure you want to publish "${timetable.examName}"? '
          'Published timetables cannot be edited.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              try {
                final bloc = context.read<ExamTimetableBloc>();
                print('[ExamTimetableListPage] PUBLISH: Got BLoC instance: $bloc');
                print('[ExamTimetableListPage] PUBLISH: Current state: ${bloc.state}');
                print('[ExamTimetableListPage] PUBLISH: Sending PublishExamTimetableEvent for ${timetable.examName}');
                bloc.add(PublishExamTimetableEvent(timetableId: timetable.id));
              } catch (e, st) {
                print('[ExamTimetableListPage] PUBLISH ERROR: $e\n$st');
                rethrow;
              }
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

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Timetable?'),
        content: Text(
          'Archive "${timetable.examName}"? '
          'Archived timetables are read-only.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ExamTimetableBloc>().add(
                    ArchiveExamTimetableEvent(timetableId: timetable.id),
                  );
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

    print('[ExamTimetableListPage] DELETE: Confirming deletion of timetable ${timetable.examName} (ID: ${timetable.id})');
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Timetable?'),
        content: Text(
          'Are you sure you want to delete "${timetable.examName}"? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              try {
                final bloc = context.read<ExamTimetableBloc>();
                print('[ExamTimetableListPage] DELETE: Got BLoC instance: $bloc');
                print('[ExamTimetableListPage] DELETE: Current state: ${bloc.state}');
                print('[ExamTimetableListPage] DELETE: Sending DeleteExamTimetableEvent for ${timetable.examName}');
                bloc.add(DeleteExamTimetableEvent(timetableId: timetable.id));
              } catch (e, st) {
                print('[ExamTimetableListPage] DELETE ERROR: $e\n$st');
                rethrow;
              }
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
