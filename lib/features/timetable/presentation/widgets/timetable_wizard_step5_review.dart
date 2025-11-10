import 'package:flutter/material.dart';

import '../pages/exam_timetable_create_wizard_page.dart';

/// Step 5: Review and Submit
///
/// Final review of all timetable details before submission.
/// Displays a comprehensive summary of:
/// - Calendar selection
/// - Timetable information
/// - Grades and sections
/// - All exam entries
class TimetableWizardStep5Review extends StatelessWidget {
  final WizardData wizardData;

  const TimetableWizardStep5Review({
    required this.wizardData,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              'Review Your Timetable',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please review the details below before creating the timetable',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 24),

            // Calendar Section
            _buildSection(
              context,
              'Exam Calendar',
              [
                _buildInfoTile(
                  context,
                  'Name',
                  wizardData.selectedCalendar?.examName ?? 'Not selected',
                ),
                _buildInfoTile(
                  context,
                  'Type',
                  wizardData.selectedCalendar?.examType ?? '—',
                ),
                if (wizardData.selectedCalendar != null)
                  _buildInfoTile(
                    context,
                    'Period',
                    '${_formatDate(wizardData.selectedCalendar!.plannedStartDate)} to ${_formatDate(wizardData.selectedCalendar!.plannedEndDate)}',
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Timetable Info Section
            _buildSection(
              context,
              'Timetable Information',
              [
                _buildInfoTile(context, 'Name', wizardData.examName),
                _buildInfoTile(context, 'Type', wizardData.examType),
                _buildInfoTile(context, 'Academic Year', wizardData.academicYear),
              ],
            ),
            const SizedBox(height: 16),

            // Grades & Sections Section
            _buildSection(
              context,
              'Grades & Sections',
              [
                ...wizardData.selectedGrades.map((grade) {
                  final sectionsList = grade.sections.join(', ');
                  return _buildInfoTile(
                    context,
                    grade.gradeName,
                    'Sections: $sectionsList',
                  );
                }),
              ],
            ),
            const SizedBox(height: 16),

            // Exam Entries Section
            Text(
              'Exam Entries (${wizardData.entries.length} total)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            if (wizardData.entries.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange[800]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No exam entries added',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.orange[800],
                            ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: wizardData.entries
                    .asMap()
                    .entries
                    .map((entry) => _buildEntryCard(context, entry.key + 1, entry.value))
                    .toList(),
              ),

            const SizedBox(height: 24),

            // Summary Stats
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Summary',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _buildStatRow(
                    context,
                    'Grades',
                    '${wizardData.selectedGrades.length}',
                  ),
                  _buildStatRow(
                    context,
                    'Total Sections',
                    '${wizardData.selectedGrades.fold<int>(0, (sum, g) => sum + g.sections.length)}',
                  ),
                  _buildStatRow(
                    context,
                    'Exam Entries',
                    '${wizardData.entries.length}',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Confirmation checkbox
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ready to create? Click "Create Timetable" to proceed.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.green[800],
                          ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Build a section card
  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  /// Build info tile
  Widget _buildInfoTile(
    BuildContext context,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  /// Build entry card
  Widget _buildEntryCard(
    BuildContext context,
    int index,
    dynamic entry,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Entry $index',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    entry.subjectId,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.blue[900],
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Details
            _buildDetailRow(
              context,
              'Grade & Section',
              'Grade ${entry.gradeId} - Section ${entry.section}',
            ),
            _buildDetailRow(
              context,
              'Date',
              entry.examDateDisplay,
            ),
            _buildDetailRow(
              context,
              'Time',
              '${entry.startTimeDisplay} to ${entry.endTimeDisplay}',
            ),
            _buildDetailRow(
              context,
              'Duration',
              '${entry.durationMinutes} minutes',
            ),
          ],
        ),
      ),
    );
  }

  /// Build detail row
  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  /// Build stat row
  Widget _buildStatRow(
    BuildContext context,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[700],
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
          ),
        ],
      ),
    );
  }

  /// Format date
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
