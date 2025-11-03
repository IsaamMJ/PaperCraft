import 'package:flutter/material.dart';
import '../../domain/entities/admin_setup_state.dart' as domain;

/// Step 4: Review and confirm the setup
class AdminSetupStep4Review extends StatelessWidget {
  final domain.AdminSetupState setupState;

  const AdminSetupStep4Review({
    Key? key,
    required this.setupState,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        const Text(
          'Review Your Setup',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Please review the configuration before completing the setup',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 24),

        // Summary card
        Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Grades summary
                _buildSummarySection(
                  'Grades',
                  '${setupState.selectedGrades.length} grades selected',
                  setupState.selectedGrades
                      .map((g) => g.gradeNumber.toString())
                      .join(', '),
                ),

                const SizedBox(height: 20),

                // Sections summary
                _buildSummarySection(
                  'Sections',
                  'Sections per grade',
                  _formatSectionsPerGrade(),
                ),

                const SizedBox(height: 20),

                // Subjects summary
                _buildSummarySection(
                  'Subjects',
                  'Subjects per grade',
                  _formatSubjectsPerGrade(),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Info box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info, color: Colors.blue[700], size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You can edit these settings later from the admin dashboard',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue[900],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build a summary section
  Widget _buildSummarySection(String title, String subtitle, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(
            fontSize: 13,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  /// Format sections per grade for display
  String _formatSectionsPerGrade() {
    final buffer = StringBuffer();

    for (final grade in setupState.selectedGrades) {
      final sections = setupState.getSectionsForGrade(grade.gradeNumber);
      if (sections.isNotEmpty) {
        buffer.write('Grade ${grade.gradeNumber}: ${sections.join(', ')}\n');
      }
    }

    return buffer.toString().trim();
  }

  /// Format subjects per grade for display
  String _formatSubjectsPerGrade() {
    final buffer = StringBuffer();

    for (final grade in setupState.selectedGrades) {
      final subjects = setupState.getSubjectsForGrade(grade.gradeNumber);
      if (subjects.isNotEmpty) {
        buffer.write('Grade ${grade.gradeNumber}: ${subjects.join(', ')}\n');
      }
    }

    return buffer.toString().trim();
  }
}
