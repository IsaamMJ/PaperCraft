import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../exams/domain/entities/exam_timetable_entry.dart';
import '../../domain/services/exam_timetable_grouping_service.dart';
import '../bloc/exam_timetable_wizard_bloc.dart';
import '../bloc/exam_timetable_wizard_event.dart';
import '../bloc/exam_timetable_wizard_state.dart';

/// Step 3: Review Papers by Grade
class WizardStep3AssignTeachers extends StatefulWidget {
  const WizardStep3AssignTeachers({Key? key}) : super(key: key);

  @override
  State<WizardStep3AssignTeachers> createState() =>
      _WizardStep3AssignTeachersState();
}

class _WizardStep3AssignTeachersState extends State<WizardStep3AssignTeachers> {
  @override
  void initState() {
    super.initState();
    _loadTeachersIfNeeded();
  }

  void _loadTeachersIfNeeded() {
    final state = context.read<ExamTimetableWizardBloc>().state;
    if (state is WizardStep3State && state.entryTeacherNames.isEmpty) {
      // Get academic year from the initial wizard event (usually stored somewhere)
      // For now, use the current year + next year format
      final now = DateTime.now();
      final academicYear = '${now.year}-${now.year + 1}';

      context.read<ExamTimetableWizardBloc>().add(
        LoadTeacherAssignmentsEvent(
          tenantId: state.tenantId,
          academicYear: academicYear,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExamTimetableWizardBloc, ExamTimetableWizardState>(
      builder: (context, state) {
        if (state is! WizardStep2State && state is! WizardStep3State) {
          return const Center(child: Text('Invalid state'));
        }

        late final dynamic selectedCalendar;
        late final List<dynamic> entries;
        late final List<dynamic> subjects;
        late final Map<String, int> gradeIdToNumberMap;
        late final Map<String, String> entryTeacherNames;
        late final bool isLoadingTeachers;

        if (state is WizardStep2State) {
          selectedCalendar = state.selectedCalendar;
          entries = state.entries;
          subjects = state.subjects;
          gradeIdToNumberMap = state.gradeIdToNumberMap;
          entryTeacherNames = {};
          isLoadingTeachers = false;
        } else if (state is WizardStep3State) {
          final step3 = state as WizardStep3State;
          selectedCalendar = step3.selectedCalendar;
          entries = step3.entries;
          subjects = step3.subjects;
          gradeIdToNumberMap = step3.gradeIdToNumberMap;
          entryTeacherNames = step3.entryTeacherNames;
          isLoadingTeachers = step3.isLoading;
        }

        // Apply same grouping logic as paper creation
        // This shows what will actually be created
        late final List<dynamic> groupedEntries;
        late final Map<String, String> updatedTeacherNames = entryTeacherNames;

        if (entryTeacherNames.isNotEmpty && entries is List<ExamTimetableEntry>) {
          final groupingResult = ExamTimetableGroupingService.groupEntriesBySubjectAndTeacherWithMapping(
            entries as List<ExamTimetableEntry>,
            entryTeacherNames,
          );
          groupedEntries = (groupingResult['entries'] as List<ExamTimetableEntry>).cast<dynamic>();
          updatedTeacherNames.addAll(groupingResult['entryTeacherNames'] as Map<String, String>);
        } else {
          // If no teacher names loaded yet, show individual entries
          groupedEntries = entries;
        }

        final groupedByGrade = _groupByGrade(groupedEntries, gradeIdToNumberMap);

        // DEBUG PRINTS

        if (entries is List<ExamTimetableEntry>) {
          for (var entry in entries as List<ExamTimetableEntry>) {
          }
        }

        if (groupedEntries is List<ExamTimetableEntry>) {
          for (var entry in groupedEntries as List<ExamTimetableEntry>) {
          }
        }


        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Review & Create Timetable',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Verify subject assignments and teacher assignments',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),

                // Exam Info Card
                _buildExamInfoCard(context, selectedCalendar, groupedEntries),
                const SizedBox(height: 24),

                // Papers by Grade
                if (groupedEntries.isEmpty)
                  _buildEmptyState(context)
                else
                  _buildPapersByGrade(
                    context,
                    groupedByGrade,
                    subjects,
                    updatedTeacherNames,
                    isLoadingTeachers,
                  ),

                const SizedBox(height: 32),

                // Status Footer
                _buildStatusFooter(context, groupedEntries, updatedTeacherNames),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExamInfoCard(
      BuildContext context,
      dynamic selectedCalendar,
      List<dynamic> entries,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedCalendar.examName ?? 'Exam',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_formatDate(selectedCalendar.plannedStartDate)} - ${_formatDate(selectedCalendar.plannedEndDate)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  '${entries.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Papers',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No subjects scheduled',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Go back to Step 2 and assign subjects to dates',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPapersByGrade(
      BuildContext context,
      Map<String, List<dynamic>> groupedByGrade,
      List<dynamic> subjects,
      Map<String, String> entryTeacherNames,
      bool isLoading,
      ) {
    return Column(
      children: [
        ...groupedByGrade.entries.map((entry) {
          final gradeName = entry.key;
          final gradeEntries = entry.value;
          return _buildGradeGroup(
            context,
            gradeName,
            gradeEntries,
            subjects,
            entryTeacherNames,
            isLoading,
          );
        }),
      ],
    );
  }

  Widget _buildGradeGroup(
      BuildContext context,
      String gradeName,
      List<dynamic> gradeEntries,
      List<dynamic> subjects,
      Map<String, String> entryTeacherNames,
      bool isLoading,
      ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grade Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(
                  color: Colors.blue.shade400,
                  width: 4,
                ),
              ),
            ),
            child: Text(
              gradeName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Subject Cards for this Grade
          ...gradeEntries.asMap().entries.map((indexedEntry) {
            final index = indexedEntry.key;
            final entry = indexedEntry.value;
            final subject = subjects
                .where((s) => s.id == entry.subjectId)
                .firstOrNull;

            final entryKey = '${entry.gradeId}_${entry.subjectId}_${entry.section}';
            final teacherName = entryTeacherNames[entryKey] ?? 'Loading...';

            return Padding(
              padding: EdgeInsets.only(
                bottom: index < gradeEntries.length - 1 ? 10 : 0,
              ),
              child: _buildSubjectCard(
                context,
                subject?.name ?? 'Subject',
                entry.section,
                teacherName,
                isLoading,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(
      BuildContext context,
      String subjectName,
      String section,
      String teacherName,
      bool isLoading,
      ) {
    final hasTeacher = !teacherName.contains('No teacher') &&
        teacherName != 'Loading...' &&
        teacherName.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: hasTeacher ? Colors.green.shade300 : Colors.orange.shade300,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Subject & Section
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subjectName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Section $section',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Teacher Info
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: hasTeacher ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Teacher',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (isLoading)
                    SizedBox(
                      height: 16,
                      child: Text(
                        'Loading...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else
                    Text(
                      teacherName,
                      style: TextStyle(
                        fontSize: 12,
                        color: hasTeacher
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Status Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: hasTeacher ? Colors.green.shade50 : Colors.orange.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasTeacher ? Icons.check_circle : Icons.info_outline,
              size: 18,
              color: hasTeacher ? Colors.green.shade600 : Colors.orange.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFooter(
      BuildContext context,
      List<dynamic> entries,
      Map<String, String> entryTeacherNames,
      ) {
    // Check if all entries have valid teachers assigned
    final allAssigned = entries.isNotEmpty && entries.every((entry) {
      final entryKey = '${entry.gradeId}_${entry.subjectId}_${entry.section}';
      final teacherName = entryTeacherNames[entryKey] ?? '';
      return teacherName.isNotEmpty &&
          !teacherName.contains('No teacher') &&
          teacherName != 'Loading...';
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: allAssigned ? Colors.green.shade50 : Colors.amber.shade50,
        border: Border.all(
          color: allAssigned ? Colors.green.shade300 : Colors.amber.shade300,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            allAssigned ? Icons.check_circle : Icons.info,
            color:
            allAssigned ? Colors.green.shade600 : Colors.amber.shade600,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allAssigned
                      ? 'Ready to Create Timetable'
                      : 'Create Timetable',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: allAssigned
                        ? Colors.green.shade800
                        : Colors.amber.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  allAssigned
                      ? 'All subjects have teachers assigned'
                      : 'Some subjects do not have teachers assigned',
                  style: TextStyle(
                    fontSize: 12,
                    color: allAssigned
                        ? Colors.green.shade700
                        : Colors.amber.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<dynamic>> _groupByGrade(
      List<dynamic> entries,
      Map<String, int> gradeIdToNumberMap,
      ) {
    final grouped = <String, List<dynamic>>{};

    for (final entry in entries) {
      final gradeNumber = gradeIdToNumberMap[entry.gradeId] ?? 0;
      final key = 'Grade $gradeNumber';

      grouped.putIfAbsent(key, () => []).add(entry);
    }

    // Sort by grade number
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        final gradeA = int.tryParse(a.split(' ')[1]) ?? 0;
        final gradeB = int.tryParse(b.split(' ')[1]) ?? 0;
        return gradeA.compareTo(gradeB);
      });

    final sorted = <String, List<dynamic>>{};
    for (final key in sortedKeys) {
      sorted[key] = grouped[key]!;
    }

    return sorted;
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}