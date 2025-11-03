import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../domain/entities/admin_setup_grade.dart';
import '../bloc/admin_setup_bloc.dart';
import '../bloc/admin_setup_event.dart';

/// Step 2: Add sections for each selected grade
class AdminSetupStep2Sections extends StatefulWidget {
  final List<AdminSetupGrade> selectedGrades;
  final Map<int, List<String>> sectionsPerGrade;

  const AdminSetupStep2Sections({
    Key? key,
    required this.selectedGrades,
    required this.sectionsPerGrade,
  }) : super(key: key);

  @override
  State<AdminSetupStep2Sections> createState() => _AdminSetupStep2SectionsState();
}

class _AdminSetupStep2SectionsState extends State<AdminSetupStep2Sections> {
  final Map<int, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    // Initialize text controllers for each grade
    for (final grade in widget.selectedGrades) {
      _controllers[grade.gradeNumber] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          'Create Sections',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Add sections (A, B, C, etc.) for each grade. Example: Grade 9 might have Section A, B, C.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 24),

        // Quick patterns
        Wrap(
          spacing: 8,
          children: [
            _buildQuickPatternButton('A, B, C', ['A', 'B', 'C']),
            _buildQuickPatternButton('A, B, C, D', ['A', 'B', 'C', 'D']),
            _buildQuickPatternButton('All Sections', ['A', 'B', 'C', 'D', 'E']),
          ],
        ),
        const SizedBox(height: 24),

        // Grade sections
        ...widget.selectedGrades.map((grade) {
          final sections = widget.sectionsPerGrade[grade.gradeNumber] ?? [];

          return Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: _buildGradeSectionCard(context, grade, sections),
          );
        }),
      ],
    );
  }

  /// Build a card for a single grade's sections
  Widget _buildGradeSectionCard(
    BuildContext context,
    AdminSetupGrade grade,
    List<String> sections,
  ) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grade title
            Text(
              'Grade ${grade.gradeNumber}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Existing sections as chips
            if (sections.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                children: sections.map((section) {
                  return InputChip(
                    label: Text(section),
                    onDeleted: () {
                      context.read<AdminSetupBloc>().add(
                            RemoveSectionEvent(
                              gradeNumber: grade.gradeNumber,
                              sectionName: section,
                            ),
                          );
                    },
                    deleteIcon: const Icon(Icons.close, size: 18),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Input field for new section
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controllers[grade.gradeNumber],
                    decoration: InputDecoration(
                      hintText: 'Enter section (e.g., A, B, C)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: (value) {
                      _addSection(context, grade.gradeNumber, value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final value = _controllers[grade.gradeNumber]!.text.trim();
                    _addSection(context, grade.gradeNumber, value);
                  },
                  child: const Icon(Icons.add),
                ),
              ],
            ),

            // Quick add buttons
            const SizedBox(height: 12),
            _buildQuickAddButtons(context, grade),
          ],
        ),
      ),
    );
  }

  /// Add a section to a grade
  void _addSection(BuildContext context, int gradeNumber, String sectionName) {
    if (sectionName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a section name')),
      );
      return;
    }

    context.read<AdminSetupBloc>().add(
          AddSectionEvent(
            gradeNumber: gradeNumber,
            sectionName: sectionName.toUpperCase(),
          ),
        );

    _controllers[gradeNumber]!.clear();
  }

  /// Build quick pattern button for top level
  Widget _buildQuickPatternButton(String label, List<String> sections) {
    return Material(
      child: InkWell(
        onTap: () {
          // Apply pattern to all grades
          for (final grade in widget.selectedGrades) {
            for (final section in sections) {
              if (!(widget.sectionsPerGrade[grade.gradeNumber] ?? [])
                  .contains(section)) {
                context.read<AdminSetupBloc>().add(
                      AddSectionEvent(
                        gradeNumber: grade.gradeNumber,
                        sectionName: section,
                      ),
                    );
              }
            }
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  /// Build quick add buttons for common section patterns
  Widget _buildQuickAddButtons(BuildContext context, AdminSetupGrade grade) {
    return Wrap(
      spacing: 8,
      children: [
        _buildQuickButton(context, grade, 'A, B, C', ['A', 'B', 'C']),
        _buildQuickButton(context, grade, 'A, B, C, D', ['A', 'B', 'C', 'D']),
      ],
    );
  }

  /// Build a quick add button for individual grade
  Widget _buildQuickButton(
    BuildContext context,
    AdminSetupGrade grade,
    String label,
    List<String> sections,
  ) {
    return Material(
      child: InkWell(
        onTap: () {
          for (final section in sections) {
            if (!(widget.sectionsPerGrade[grade.gradeNumber] ?? [])
                .contains(section)) {
              context.read<AdminSetupBloc>().add(
                    AddSectionEvent(
                      gradeNumber: grade.gradeNumber,
                      sectionName: section,
                    ),
                  );
            }
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
