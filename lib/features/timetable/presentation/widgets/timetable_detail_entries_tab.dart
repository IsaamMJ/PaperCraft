import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/exam_timetable_bloc.dart';
import '../bloc/exam_timetable_state.dart';

/// Timetable Detail - Entries Tab
///
/// Displays list of exam entries for the timetable.
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
        if (state is ExamTimetableLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (state is ExamTimetableEntriesLoaded) {
          final entries = state.entries;

          if (entries.isEmpty) {
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

          // Sort entries by date
          final sortedEntries = List.from(entries);
          sortedEntries.sort((a, b) => a.examDate.compareTo(b.examDate));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedEntries.length,
            itemBuilder: (context, index) {
              final entry = sortedEntries[index];
              final isFirst = index == 0;
              final isSameDay = index > 0 &&
                  sortedEntries[index - 1].examDate.day ==
                      entry.examDate.day &&
                  sortedEntries[index - 1].examDate.month ==
                      entry.examDate.month &&
                  sortedEntries[index - 1].examDate.year == entry.examDate.year;

              return Column(
                children: [
                  // Date header (if different from previous)
                  if (isFirst || !isSameDay)
                    Padding(
                      padding: EdgeInsets.only(
                        top: isFirst ? 0 : 16,
                        bottom: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            entry.examDateDisplay,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                          ),
                        ],
                      ),
                    ),
                  // Entry card
                  _buildEntryCard(context, entry),
                ],
              );
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

  /// Build entry card
  Widget _buildEntryCard(BuildContext context, dynamic entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subject and Grade/Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.subjectId,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Grade: ${entry.gradeId} | Section: ${entry.section}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    entry.durationMinutes < 60
                        ? '${entry.durationMinutes} min'
                        : '${entry.durationMinutes ~/ 60}h',
                    style: TextStyle(
                      color: Colors.blue[900],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Time details
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 18,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  '${entry.startTimeDisplay} - ${entry.endTimeDisplay}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
