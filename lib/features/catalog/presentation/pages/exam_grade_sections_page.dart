import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/grade_section_bloc.dart';
import '../bloc/grade_section_event.dart';
import '../bloc/grade_section_state.dart';
import '../../domain/entities/grade_entity.dart';
import '../../domain/entities/grade_section.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';

/// Page to assign grade sections to exam calendars
///
/// Shows grades grouped with their sections in a hierarchical view
/// Allows selecting which sections participate in an exam
class ExamGradeSectionsPage extends StatefulWidget {
  final String tenantId;
  final String examCalendarId;
  final String examCalendarName;

  const ExamGradeSectionsPage({
    required this.tenantId,
    required this.examCalendarId,
    required this.examCalendarName,
    super.key,
  });

  @override
  State<ExamGradeSectionsPage> createState() => _ExamGradeSectionsPageState();
}

class _ExamGradeSectionsPageState extends State<ExamGradeSectionsPage> {
  // Track which sections are selected
  final Set<String> _selectedSections = {};

  @override
  void initState() {
    super.initState();
    print('[ExamGradeSectionsPage] Initializing for exam calendar: ${widget.examCalendarName}');

    // Load all grade sections
    context.read<GradeSectionBloc>().add(
      LoadGradeSectionsEvent(
        tenantId: widget.tenantId,
        gradeId: null, // Load all grades
      ),
    );
  }

  void _toggleSection(String sectionId) {
    setState(() {
      if (_selectedSections.contains(sectionId)) {
        _selectedSections.remove(sectionId);
        print('[ExamGradeSectionsPage] Deselected section: $sectionId');
      } else {
        _selectedSections.add(sectionId);
        print('[ExamGradeSectionsPage] Selected section: $sectionId');
      }
    });
  }

  void _selectAllForGrade(List<GradeSection> gradeSections) {
    setState(() {
      for (final section in gradeSections) {
        _selectedSections.add(section.id);
      }
    });
    print('[ExamGradeSectionsPage] Selected all sections for grade');
  }

  void _deselectAllForGrade(List<GradeSection> gradeSections) {
    setState(() {
      for (final section in gradeSections) {
        _selectedSections.remove(section.id);
      }
    });
    print('[ExamGradeSectionsPage] Deselected all sections for grade');
  }

  void _confirmSelection() {
    print('[ExamGradeSectionsPage] Confirmed selection of ${_selectedSections.length} sections');
    print('[ExamGradeSectionsPage] Selected section IDs: $_selectedSections');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_selectedSections.length} section(s) assigned to ${widget.examCalendarName}'),
        backgroundColor: Colors.green,
      ),
    );

    // TODO: Save assignment to database/bloc state
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Assign Sections to ${widget.examCalendarName}'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: BlocBuilder<GradeSectionBloc, GradeSectionState>(
        builder: (context, state) {
          // Loading
          if (state is GradeSectionLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error
          if (state is GradeSectionError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(state.message, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.read<GradeSectionBloc>().add(
                      RefreshGradeSectionsEvent(tenantId: widget.tenantId),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          // Empty
          if (state is GradeSectionEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inbox, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No sections found'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          // Loaded - Group sections by grade
          if (state is GradeSectionLoaded) {
            // Group sections by gradeId
            final Map<String, List<GradeSection>> sectionsByGrade = {};
            for (final section in state.sections) {
              sectionsByGrade.putIfAbsent(section.gradeId, () => []).add(section);
            }

            // Sort sections within each grade
            for (final list in sectionsByGrade.values) {
              list.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
            }

            return Column(
              children: [
                // Header with info
                Container(
                  padding: EdgeInsets.all(UIConstants.paddingLarge),
                  color: AppColors.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Sections',
                        style: TextStyle(
                          fontSize: UIConstants.fontSizeXLarge,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: UIConstants.spacing8),
                      Text(
                        'Choose which grade sections will take the ${widget.examCalendarName} exam',
                        style: TextStyle(
                          fontSize: UIConstants.fontSizeSmall,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: UIConstants.spacing12),
                      Text(
                        '${_selectedSections.length} section(s) selected',
                        style: TextStyle(
                          fontSize: UIConstants.fontSizeMedium,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // List of grades with sections
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.all(UIConstants.paddingMedium),
                    itemCount: sectionsByGrade.length,
                    itemBuilder: (context, index) {
                      final gradeId = sectionsByGrade.keys.elementAt(index);
                      final sections = sectionsByGrade[gradeId]!;

                      return _buildGradeCard(gradeId, sections);
                    },
                  ),
                ),
              ],
            );
          }

          return const Center(child: Text('Loading...'));
        },
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.all(UIConstants.paddingLarge),
        child: ElevatedButton(
          onPressed: _selectedSections.isEmpty ? null : _confirmSelection,
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: UIConstants.paddingMedium),
            backgroundColor: _selectedSections.isEmpty ? Colors.grey : AppColors.primary,
          ),
          child: Text(
            'Confirm Selection (${_selectedSections.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradeCard(String gradeId, List<GradeSection> sections) {
    final allSelected = sections.every((s) => _selectedSections.contains(s.id));
    final someSelected = sections.any((s) => _selectedSections.contains(s.id));

    return Card(
      margin: EdgeInsets.only(bottom: UIConstants.spacing12),
      elevation: 0,
      color: AppColors.surface,
      child: Column(
        children: [
          // Grade header with select all
          Padding(
            padding: EdgeInsets.all(UIConstants.paddingMedium),
            child: Row(
              children: [
                // Grade name (placeholder - should fetch real grade name)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Grade ${gradeId.substring(0, 3)}',
                        style: TextStyle(
                          fontSize: UIConstants.fontSizeLarge,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: UIConstants.spacing4),
                      Text(
                        '${sections.length} section(s)',
                        style: TextStyle(
                          fontSize: UIConstants.fontSizeSmall,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Select/Deselect all button
                Checkbox(
                  value: allSelected,
                  tristate: true,
                  onChanged: (_) {
                    if (allSelected) {
                      _deselectAllForGrade(sections);
                    } else {
                      _selectAllForGrade(sections);
                    }
                  },
                ),
              ],
            ),
          ),

          // Divider
          Divider(
            height: 1,
            color: AppColors.border,
          ),

          // Sections list
          ...sections.map((section) {
            final isSelected = _selectedSections.contains(section.id);

            return CheckboxListTile(
              value: isSelected,
              onChanged: (_) => _toggleSection(section.id),
              title: Text(
                'Section ${section.sectionName}',
                style: TextStyle(
                  fontSize: UIConstants.fontSizeMedium,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                'Section ${section.sectionName}',
                style: TextStyle(
                  fontSize: UIConstants.fontSizeSmall,
                  color: AppColors.textTertiary,
                ),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: UIConstants.paddingMedium,
                vertical: UIConstants.paddingSmall,
              ),
              activeColor: AppColors.primary,
            );
          }).toList(),
        ],
      ),
    );
  }
}
