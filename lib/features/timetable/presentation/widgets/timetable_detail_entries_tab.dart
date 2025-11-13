import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/exam_timetable_entry_entity.dart';
import '../bloc/exam_timetable_bloc.dart';
import '../bloc/exam_timetable_state.dart';

/// Timetable Detail - Entries Tab
///
/// Displays table of exam entries for the timetable (Date | Grade | Section | Subject | Time).
class TimetableDetailEntriesTab extends StatelessWidget {
  final String timetableId;

  const TimetableDetailEntriesTab({
    required this.timetableId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExamTimetableBloc, ExamTimetableState>(
      builder: (context, state) {
        print('[TimetableDetailEntriesTab] State: ${state.runtimeType}');

        // CHECK ENTRIES LOADED FIRST (most specific state)
        if (state is ExamTimetableEntriesLoaded) {
          print('[TimetableDetailEntriesTab] ✅ Entries loaded state received: ${state.entries.length} entries');
          final entries = state.entries;

          if (entries.isEmpty) {
            print('[TimetableDetailEntriesTab] ✅ Showing empty state');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No exam entries',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No exam entries have been added to this timetable',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            );
          }

          print('[TimetableDetailEntriesTab] ✅ Showing table with ${entries.length} entries');
          return _buildEntriesTable(context, entries);
        }

        // If timetable is loaded but entries are still loading, show loading indicator
        if (state is ExamTimetableLoaded) {
          print('[TimetableDetailEntriesTab] Timetable loaded, waiting for entries...');
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (state is ExamTimetableLoading) {
          return const Center(
            child: CircularProgressIndicator(),
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
                  'Error loading entries',
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
    );
  }

  /// Build entries as a scrollable table
  Widget _buildEntriesTable(
    BuildContext context,
    List<ExamTimetableEntryEntity> entries,
  ) {
    // Group entries by (examDate, subjectName, scheduleDisplay)
    final Map<String, List<ExamTimetableEntryEntity>> groupedEntries = {};
    for (final entry in entries) {
      final key = '${entry.examDate}|${entry.subjectName}|${entry.scheduleDisplay}';
      groupedEntries.putIfAbsent(key, () => []).add(entry);
    }

    // Sort by exam date and time
    final sortedKeys = groupedEntries.keys.toList()
      ..sort((a, b) {
        final dateA = a.split('|')[0];
        final dateB = b.split('|')[0];
        return dateA.compareTo(dateB);
      });

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Table header
            _buildTableHeader(context),
            const SizedBox(height: 8),
            // Divider
            Divider(color: Colors.grey[300], height: 1),
            const SizedBox(height: 8),
            // Table rows - one per subject per time
            ...sortedKeys.asMap().entries.map((entry) {
              final key = entry.value;
              final groupedList = groupedEntries[key] ?? [];
              final isEvenRow = entry.key % 2 == 0;
              return _buildGroupedTableRow(context, groupedList, isEvenRow);
            }).toList(),
          ],
        ),
      ),
    );
  }

  /// Build table header row
  Widget _buildTableHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _buildHeaderCell(context, 'Date'),
          ),
          Expanded(
            flex: 3,
            child: _buildHeaderCell(context, 'Subject'),
          ),
          Expanded(
            flex: 2,
            child: _buildHeaderCell(context, 'Time'),
          ),
          Expanded(
            flex: 2,
            child: _buildHeaderCell(context, 'Grades'),
          ),
        ],
      ),
    );
  }

  /// Build header cell
  Widget _buildHeaderCell(BuildContext context, String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
    );
  }

  /// Build grouped table row showing all grades for a subject
  Widget _buildGroupedTableRow(
    BuildContext context,
    List<ExamTimetableEntryEntity> groupedEntries,
    bool isEvenRow,
  ) {
    if (groupedEntries.isEmpty) return const SizedBox.shrink();

    final firstEntry = groupedEntries.first;

    // Extract unique grades and sections from the group
    final gradesSet = <String>{};
    for (final entry in groupedEntries) {
      final gradeNum = entry.gradeNumber ?? 0;
      final section = entry.section ?? '';
      gradesSet.add('$gradeNum$section');
    }
    final gradesList = gradesSet.toList()..sort();
    final gradesDisplay = gradesList.join(', ');

    return Container(
      color: isEvenRow ? Colors.grey[50] : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      margin: const EdgeInsets.only(bottom: 1),
      child: Row(
        children: [
          // Date
          Expanded(
            flex: 2,
            child: Text(
              _formatDate(firstEntry.examDate),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          // Subject
          Expanded(
            flex: 3,
            child: Text(
              firstEntry.subjectName ?? 'Unknown',
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Time
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                firstEntry.scheduleDisplay,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[900],
                    ),
              ),
            ),
          ),
          // Grades - showing all grades/sections for this subject
          Expanded(
            flex: 2,
            child: Tooltip(
              message: gradesDisplay,
              child: Text(
                gradesDisplay,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build table row for each entry
  Widget _buildTableRow(
    BuildContext context,
    ExamTimetableEntryEntity entry,
  ) {
    final isEvenRow = entry.hashCode % 2 == 0;

    return Container(
      color: isEvenRow ? Colors.grey[50] : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      margin: const EdgeInsets.only(bottom: 1),
      child: Row(
        children: [
          // Date
          Expanded(
            flex: 2,
            child: Text(
              _formatDate(entry.examDate),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          // Subject
          Expanded(
            flex: 3,
            child: Text(
              entry.subjectName ?? 'Unknown',
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Time
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                entry.scheduleDisplay,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[900],
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Format date as "10-Nov-2025"
  String _formatDate(DateTime date) {
    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = monthNames[date.month - 1];
    return '${date.day.toString().padLeft(2, '0')}-$month-${date.year}';
  }
}
