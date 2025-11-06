import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/infrastructure/di/injection_container.dart';
import '../../../../../core/presentation/constants/app_colors.dart';
import '../../../../../core/presentation/constants/ui_constants.dart';
import '../../domain/entities/grade_section.dart';
import '../../domain/entities/grade_subject.dart';
import '../../domain/entities/subject_entity.dart';
import '../../domain/repositories/grade_repository.dart';
import '../../domain/repositories/grade_section_repository.dart';
import '../../domain/repositories/grade_subject_repository.dart';
import '../../domain/repositories/subject_repository.dart';
import '../bloc/grade_management_bloc.dart';

class GradeManagementPage extends StatelessWidget {
  const GradeManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manage Grades, Sections & Subjects'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: BlocProvider(
        create: (context) => GradeManagementBloc(
          gradeRepository: sl<GradeRepository>(),
          sectionRepository: sl<GradeSectionRepository>(),
          subjectRepository: sl<GradeSubjectRepository>(),
          subjectCatalogRepository: sl<SubjectRepository>(),
          userStateService: sl(),
        )..add(const LoadGradesWithSections()),
        child: const _GradeManagementContent(),
      ),
    );
  }
}

class _GradeManagementContent extends StatefulWidget {
  const _GradeManagementContent({super.key});

  @override
  State<_GradeManagementContent> createState() => _GradeManagementContentState();
}

class _GradeManagementContentState extends State<_GradeManagementContent> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GradeManagementBloc, GradeManagementState>(
      builder: (context, state) {
        if (state is GradeManagementLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is GradeManagementError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: AppColors.error),
                SizedBox(height: UIConstants.spacing16),
                Text(
                  state.message,
                  style: TextStyle(color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: UIConstants.spacing16),
                ElevatedButton(
                  onPressed: () {
                    context.read<GradeManagementBloc>().add(const LoadGradesWithSections());
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (state is GradeManagementLoaded) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(UIConstants.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with tenant info
                _buildHeader(state.tenantName),
                SizedBox(height: UIConstants.spacing20),

                // Add new grade button
                _buildAddGradeButton(context),
                SizedBox(height: UIConstants.spacing20),

                // Grades list
                if (state.grades.isEmpty)
                  _buildEmptyState()
                else
                  _buildGradesList(context, state),

                const SizedBox(height: 100),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildHeader(String tenantName) {
    return Container(
      padding: EdgeInsets.all(UIConstants.paddingMedium),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary10, AppColors.secondary10],
        ),
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        border: Border.all(color: AppColors.primary30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'School: $tenantName',
            style: TextStyle(
              fontSize: UIConstants.fontSizeMedium,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: UIConstants.spacing8),
          Text(
            'Manage grades and their sections',
            style: TextStyle(
              fontSize: UIConstants.fontSizeSmall,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddGradeButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showAddGradeDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add New Grade'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: UIConstants.spacing16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: UIConstants.spacing32),
          Icon(Icons.school_outlined, size: 48, color: AppColors.textTertiary),
          SizedBox(height: UIConstants.spacing16),
          Text(
            'No grades yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: UIConstants.spacing8),
          Text(
            'Add your first grade above',
            style: TextStyle(color: AppColors.textTertiary),
          ),
          SizedBox(height: UIConstants.spacing32),
        ],
      ),
    );
  }

  Widget _buildGradesList(BuildContext context, GradeManagementLoaded state) {
    return Column(
      children: state.grades.map((grade) {
        final isExpanded = state.expandedGradeId == grade.id;
        final sections = state.sectionsPerGrade[grade.id] ?? [];

        return Padding(
          padding: EdgeInsets.only(bottom: UIConstants.spacing12),
          child: _buildGradeCard(
            context,
            grade,
            sections,
            isExpanded,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGradeCard(
    BuildContext context,
    dynamic grade,
    List<GradeSection> sections,
    bool isExpanded,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: AppColors.black04,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Grade header (always visible)
          GestureDetector(
            onTap: () {
              context.read<GradeManagementBloc>().add(
                    ToggleExpandGradeEvent(grade.id),
                  );
            },
            child: Container(
              padding: EdgeInsets.all(UIConstants.paddingMedium),
              child: Row(
                children: [
                  // Grade info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          grade.displayName,
                          style: TextStyle(
                            fontSize: UIConstants.fontSizeLarge,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: UIConstants.spacing4),
                        Text(
                          '${sections.length} section${sections.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: UIConstants.fontSizeSmall,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action buttons
                  _buildGradeActionButtons(context, grade),

                  // Expand indicator
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),

          // Expanded content with tabs (Sections and Subjects)
          if (isExpanded) ...[
            Divider(height: 1, color: AppColors.textTertiary.withOpacity(0.3)),
            DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  // Tab bar
                  TabBar(
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorColor: AppColors.primary,
                    tabs: const [
                      Tab(text: 'Sections'),
                      Tab(text: 'Subjects'),
                    ],
                  ),
                  // Tab content
                  SizedBox(
                    height: 400, // Give tab content a fixed height
                    child: TabBarView(
                      children: [
                        // Sections tab
                        _buildSectionsTab(context, grade, sections),
                        // Subjects tab
                        _buildSubjectsTab(context, grade, sections),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionsTab(
    BuildContext context,
    dynamic grade,
    List<GradeSection> sections,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(UIConstants.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current sections
          if (sections.isNotEmpty) ...[
            Text(
              'Current Sections',
              style: TextStyle(
                fontSize: UIConstants.fontSizeMedium,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: UIConstants.spacing12),
            Wrap(
              spacing: UIConstants.spacing8,
              runSpacing: UIConstants.spacing8,
              children: sections.map((section) {
                return InputChip(
                  label: Text(section.sectionName),
                  onDeleted: () {
                    context.read<GradeManagementBloc>().add(
                          RemoveSectionEvent(
                            grade.id,
                            grade.gradeNumber,
                            section.id,
                          ),
                        );
                  },
                  deleteIcon: const Icon(Icons.close, size: 18),
                  backgroundColor: AppColors.primary10,
                  labelStyle: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: UIConstants.spacing16),
          ],

          // Quick pattern buttons
          Text(
            'Quick Patterns',
            style: TextStyle(
              fontSize: UIConstants.fontSizeMedium,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: UIConstants.spacing8),
          Wrap(
            spacing: UIConstants.spacing8,
            runSpacing: UIConstants.spacing8,
            children: [
              _buildPatternButton(
                context,
                grade,
                'A, B, C',
                ['A', 'B', 'C'],
              ),
              _buildPatternButton(
                context,
                grade,
                'A, B, C, D',
                ['A', 'B', 'C', 'D'],
              ),
              _buildPatternButton(
                context,
                grade,
                'A-E',
                ['A', 'B', 'C', 'D', 'E'],
              ),
            ],
          ),
          SizedBox(height: UIConstants.spacing16),

          // Add section input
          Text(
            'Add Section',
            style: TextStyle(
              fontSize: UIConstants.fontSizeMedium,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: UIConstants.spacing8),
          _buildAddSectionInput(context, grade),
        ],
      ),
    );
  }

  Widget _buildSubjectsTab(
    BuildContext context,
    dynamic grade,
    List<GradeSection> sections,
  ) {
    if (sections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 48, color: AppColors.textTertiary),
            SizedBox(height: UIConstants.spacing16),
            Text(
              'Add sections first to assign subjects',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return BlocBuilder<GradeManagementBloc, GradeManagementState>(
      builder: (context, state) {
        if (state is! GradeManagementLoaded) {
          return const SizedBox.shrink();
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(UIConstants.paddingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section selector dropdown
              Text(
                'Select Section',
                style: TextStyle(
                  fontSize: UIConstants.fontSizeMedium,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: UIConstants.spacing8),
              DropdownButtonFormField<String>(
                value: state.selectedSubjectSectionId,
                decoration: InputDecoration(
                  labelText: 'Choose a section',
                  prefixIcon: Icon(Icons.class_, color: AppColors.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                  ),
                ),
                items: sections
                    .map((section) => DropdownMenuItem(
                          value: section.id,
                          child: Text(section.sectionName),
                        ))
                    .toList(),
                onChanged: (sectionId) {
                  if (sectionId != null) {
                    context.read<GradeManagementBloc>().add(
                          SelectSubjectSectionEvent(sectionId),
                        );
                    // Load subjects for selected section
                    context.read<GradeManagementBloc>().add(
                          LoadSubjectsForSectionEvent(grade.id, sectionId),
                        );
                    // Load available subjects for this grade
                    context.read<GradeManagementBloc>().add(
                          LoadAvailableSubjectsForGradeEvent(grade.gradeNumber),
                        );
                  }
                },
              ),
              SizedBox(height: UIConstants.spacing16),

              // Show subjects for selected section
              if (state.selectedSubjectSectionId != null) ...[
                Text(
                  'Subjects',
                  style: TextStyle(
                    fontSize: UIConstants.fontSizeMedium,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: UIConstants.spacing12),

                // List of subjects for selected section
                if ((state.subjectsPerSection[state.selectedSubjectSectionId] ??
                        [])
                    .isNotEmpty)
                  Wrap(
                    spacing: UIConstants.spacing8,
                    runSpacing: UIConstants.spacing8,
                    children: (state.subjectsPerSection[
                            state.selectedSubjectSectionId] ??
                        [])
                        .map((subject) {
                      // Look up subject name from available subjects
                      final availableSubjects = state.availableSubjectsPerGrade[grade.gradeNumber] ?? [];
                      final subjectName = availableSubjects
                          .firstWhere(
                            (s) => s.id == subject.subjectId,
                            orElse: () => SubjectEntity(
                              id: subject.subjectId,
                              name: subject.subjectId,
                              catalogSubjectId: '',
                              tenantId: '',
                              isActive: true,
                              createdAt: DateTime.now(),
                            ),
                          )
                          .name;

                      return InputChip(
                        label: Text(subjectName),
                        onDeleted: () {
                          context.read<GradeManagementBloc>().add(
                                RemoveSubjectFromSectionEvent(
                                  grade.id,
                                  state.selectedSubjectSectionId!,
                                  subject.id,
                                ),
                              );
                        },
                        deleteIcon: const Icon(Icons.close, size: 18),
                        backgroundColor: AppColors.secondary10,
                        labelStyle: TextStyle(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    }).toList(),
                  )
                else
                  Text(
                    'No subjects assigned yet',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),

                SizedBox(height: UIConstants.spacing16),

                // Available subjects selector
                if ((state.availableSubjectsPerGrade[grade.gradeNumber] ?? []).isNotEmpty)
                  _buildAvailableSubjectsSelector(
                    context,
                    grade,
                    state.selectedSubjectSectionId ?? '',
                    sections,
                    state.availableSubjectsPerGrade[grade.gradeNumber] ?? [],
                    state.subjectsPerSection[state.selectedSubjectSectionId] ?? [],
                  )
                else
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: UIConstants.spacing16),
                      child: Column(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.textTertiary, size: 24),
                          SizedBox(height: UIConstants.spacing8),
                          Text(
                            'Loading available subjects...',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvailableSubjectsSelector(
    BuildContext context,
    dynamic grade,
    String selectedSectionId,
    List<GradeSection> sections,
    List<SubjectEntity> availableSubjects,
    List<GradeSubject> assignedSubjects,
  ) {
    // Find the section name from the sections list
    final selectedSection = sections.firstWhere(
      (s) => s.id == selectedSectionId,
      orElse: () => sections.first,
    );
    final sectionName = selectedSection.sectionName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Subjects',
          style: TextStyle(
            fontSize: UIConstants.fontSizeMedium,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: UIConstants.spacing12),
        Wrap(
          spacing: UIConstants.spacing8,
          runSpacing: UIConstants.spacing8,
          children: availableSubjects.map((subject) {
            final isAssigned = assignedSubjects.any((s) => s.subjectId == subject.id);

            return FilterChip(
              label: Text(subject.name),
              selected: isAssigned,
              onSelected: isAssigned
                  ? null
                  : (_) {
                      context.read<GradeManagementBloc>().add(
                            AddSubjectToSectionEvent(
                              grade.id,
                              selectedSectionId,
                              sectionName,
                              subject.id,
                            ),
                          );
                    },
              backgroundColor: isAssigned
                  ? AppColors.primary.withOpacity(0.2)
                  : Colors.grey[100],
              selectedColor: AppColors.primary.withOpacity(0.3),
              side: BorderSide(
                color: isAssigned ? AppColors.primary : Colors.grey[300]!,
                width: isAssigned ? 2 : 1,
              ),
              labelStyle: TextStyle(
                fontSize: UIConstants.fontSizeSmall,
                color: isAssigned ? AppColors.primary : AppColors.textPrimary,
                fontWeight: isAssigned ? FontWeight.w600 : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGradeActionButtons(BuildContext context, dynamic grade) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => _showDeleteConfirmation(context, grade),
          icon: Icon(Icons.delete_outline, color: AppColors.error),
          tooltip: 'Delete grade',
          iconSize: 20,
        ),
      ],
    );
  }

  Widget _buildPatternButton(
    BuildContext context,
    dynamic grade,
    String label,
    List<String> sections,
  ) {
    return OutlinedButton(
      onPressed: () {
        context.read<GradeManagementBloc>().add(
              ApplyQuickPatternEvent(
                grade.id,
                grade.gradeNumber,
                sections,
              ),
            );
      },
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AppColors.primary),
        foregroundColor: AppColors.primary,
      ),
      child: Text(label),
    );
  }

  Widget _buildAddSectionInput(BuildContext context, dynamic grade) {
    final controller = TextEditingController();

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'e.g., A, B, C',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: UIConstants.spacing12,
                vertical: UIConstants.spacing8,
              ),
            ),
            textCapitalization: TextCapitalization.characters,
          ),
        ),
        SizedBox(width: UIConstants.spacing8),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              final sectionName = controller.text.trim().toUpperCase();
              if (sectionName.isNotEmpty) {
                context.read<GradeManagementBloc>().add(
                      AddSectionEvent(
                        grade.id,
                        grade.gradeNumber,
                        sectionName,
                      ),
                    );
                controller.clear();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Icon(Icons.add, size: 20),
          ),
        ),
      ],
    );
  }

  void _showAddGradeDialog(BuildContext context) {
    int? selectedGrade;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
        ),
        title: Row(
          children: [
            Icon(Icons.add, color: AppColors.primary),
            SizedBox(width: UIConstants.spacing12),
            const Text('Add New Grade'),
          ],
        ),
        content: DropdownButtonFormField<int>(
          value: selectedGrade,
          decoration: InputDecoration(
            labelText: 'Select Grade',
            prefixIcon: Icon(Icons.school, color: AppColors.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
            ),
          ),
          items: List.generate(12, (index) => index + 1)
              .map((grade) => DropdownMenuItem(
                    value: grade,
                    child: Text('Grade $grade'),
                  ))
              .toList(),
          onChanged: (value) {
            selectedGrade = value;
          },
          validator: (value) {
            if (value == null) return 'Please select a grade';
            return null;
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (selectedGrade != null) {
                context.read<GradeManagementBloc>().add(
                      AddGradeEvent(selectedGrade!),
                    );
                Navigator.of(dialogContext).pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, dynamic grade) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
        ),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: AppColors.error),
            SizedBox(width: UIConstants.spacing12),
            const Text('Delete Grade'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${grade.displayName}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<GradeManagementBloc>().add(
                    DeleteGradeEvent(grade.id, grade.gradeNumber),
                  );
              Navigator.of(dialogContext).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
