import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/exam_timetable_entity.dart';
import '../bloc/exam_timetable_bloc.dart';
import '../bloc/exam_timetable_event.dart';
import '../bloc/exam_timetable_state.dart';
import '../widgets/timetable_detail_entries_tab.dart';
import '../widgets/timetable_detail_info_tab.dart';

/// Exam Timetable Detail Page
///
/// Displays detailed information about a timetable including:
/// - Basic timetable information
/// - List of exam entries with details
/// - Export options
/// - Print functionality
class ExamTimetableDetailPage extends StatefulWidget {
  final String timetableId;
  final String tenantId;

  const ExamTimetableDetailPage({
    required this.timetableId,
    required this.tenantId,
    super.key,
  });

  @override
  State<ExamTimetableDetailPage> createState() =>
      _ExamTimetableDetailPageState();
}

class _ExamTimetableDetailPageState extends State<ExamTimetableDetailPage> {
  late int _selectedTabIndex;

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = 0;

    // Load timetable details
    context.read<ExamTimetableBloc>().add(
          GetExamTimetableByIdEvent(timetableId: widget.timetableId),
        );

    // Load entries
    context.read<ExamTimetableBloc>().add(
          GetExamTimetableEntriesEvent(timetableId: widget.timetableId),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable Details'),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  child: Row(
                    children: [
                      Icon(Icons.print),
                      SizedBox(width: 8),
                      Text('Print'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  child: Row(
                    children: [
                      Icon(Icons.download),
                      SizedBox(width: 8),
                      Text('Export PDF'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: BlocBuilder<ExamTimetableBloc, ExamTimetableState>(
        builder: (context, state) {
          if (state is ExamTimetableLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (state is ExamTimetableLoaded) {
            final timetable = state.timetable;

            return Column(
              children: [
                // Header with timetable info
                _buildHeader(context, timetable),

                // Tab bar
                _buildTabBar(),

                // Tab content
                Expanded(
                  child: _buildTabContent(context, timetable),
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
                    'Error loading timetable',
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
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back'),
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
    );
  }

  /// Build header with timetable info
  Widget _buildHeader(BuildContext context, ExamTimetableEntity timetable) {
    return Container(
      color: Colors.blue[50],
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timetable.examName,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Type: ${timetable.examType}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusBadge(context, timetable),
            ],
          ),
          const SizedBox(height: 16),

          // Info grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoItem(
                context,
                'Academic Year',
                timetable.academicYear,
                Icons.calendar_month,
              ),
              _buildInfoItem(
                context,
                'Status',
                timetable.status.toUpperCase(),
                Icons.info,
              ),
              _buildInfoItem(
                context,
                'Created',
                _formatDate(timetable.createdAt),
                Icons.access_time,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build status badge
  Widget _buildStatusBadge(BuildContext context, ExamTimetableEntity timetable) {
    final statusColor = _getStatusColor(timetable.status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor),
      ),
      child: Text(
        timetable.status.toUpperCase(),
        style: TextStyle(
          color: statusColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Build info item
  Widget _buildInfoItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Build tab bar
  Widget _buildTabBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildTab('Information', 0),
          _buildTab('Entries', 1),
        ],
      ),
    );
  }

  /// Build individual tab
  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTabIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.blue : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.blue : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  /// Build tab content
  Widget _buildTabContent(
    BuildContext context,
    ExamTimetableEntity timetable,
  ) {
    switch (_selectedTabIndex) {
      case 0:
        return TimetableDetailInfoTab(timetable: timetable);
      case 1:
        return TimetableDetailEntriesTab(
          timetableId: widget.timetableId,
        );
      default:
        return const SizedBox();
    }
  }

  /// Get status color
  Color _getStatusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.orange;
      case 'published':
        return Colors.green;
      case 'archived':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  /// Format date
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
