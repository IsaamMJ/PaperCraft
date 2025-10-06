// features/settings/presentation/widgets/grade_management_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/presentation/constants/app_colors.dart';
import '../../../../../core/presentation/utils/date_utils.dart';
import '../../../domain/entities/grade_entity.dart';
import '../../bloc/grade_bloc.dart';
import '../../../../../core/presentation/constants/ui_constants.dart';


class GradeManagementWidget extends StatefulWidget {
  const GradeManagementWidget({super.key});

  @override
  State<GradeManagementWidget> createState() => _GradeManagementWidgetState();
}

class _GradeManagementWidgetState extends State<GradeManagementWidget> {
  final _nameController = TextEditingController();
  final _levelController = TextEditingController();
  final _sectionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  GradeEntity? _editingGrade;

  @override
  void initState() {
    super.initState();
    // Load grades on init
    context.read<GradeBloc>().add(const LoadGrades());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _levelController.dispose();
    _sectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GradeBloc, GradeState>(
      listener: _handleStateChanges,
      child: Padding(
        padding: const EdgeInsets.all(UIConstants.paddingMedium),
        child: Column(
          children: [
            // Add/Edit Form
            _buildForm(),
            SizedBox(height: UIConstants.spacing20),
            const Divider(),
            SizedBox(height: UIConstants.spacing20),

            // Grades List
            Expanded(
              child: BlocBuilder<GradeBloc, GradeState>(
                builder: (context, state) {
                  if (state is GradeLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state is GradeError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              size: 48,
                              color: AppColors.error),
                          SizedBox(height: UIConstants.spacing16),
                          Text(state.message,
                              style: TextStyle(color: AppColors.error),
                              textAlign: TextAlign.center),
                          SizedBox(height: UIConstants.spacing16),
                          ElevatedButton(
                            onPressed: () {
                              context.read<GradeBloc>().add(const LoadGrades());
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (state is GradesLoaded) {
                    if (state.grades.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.school_outlined,
                                size: 48,
                                color: AppColors.textTertiary),
                            SizedBox(height: UIConstants.spacing16),
                            Text('No grades yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                )),
                            SizedBox(height: UIConstants.spacing8),
                            Text('Add your first grade above',
                                style: TextStyle(color: AppColors.textTertiary)),
                          ],
                        ),
                      );
                    }

                    // Group grades by level for better organization
                    final groupedGrades = <int, List<GradeEntity>>{};
                    for (final grade in state.grades) {
                      groupedGrades.putIfAbsent(grade.level, () => []).add(grade);
                    }

                    return ListView.builder(
                      itemCount: groupedGrades.keys.length,
                      itemBuilder: (context, index) {
                        final level = groupedGrades.keys.elementAt(index);
                        final gradesForLevel = groupedGrades[level]!;
                        return _buildGradeLevelSection(level, gradesForLevel);
                      },
                    );
                  }

                  return const Center(child: Text('No grades loaded'));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _editingGrade == null ? 'Add Grade' : 'Edit Grade',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: UIConstants.spacing16),

          // Level Selection
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _editingGrade?.level,
                  decoration: InputDecoration(
                    labelText: 'Grade Level',
                    prefixIcon: Icon(Icons.format_list_numbered, color: AppColors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                    ),
                  ),
                  items: List.generate(12, (index) => index + 1)
                      .map((level) => DropdownMenuItem(
                    value: level,
                    child: Text('Grade $level'),
                  ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _levelController.text = value.toString();
                      // Auto-generate name preview
                      _nameController.text = 'Grade $value';
                    });
                  },
                  validator: (value) {
                    if (value == null) return 'Please select a grade level';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _sectionController,
                  decoration: InputDecoration(
                    labelText: 'Section (Optional)',
                    hintText: 'A, B, C...',
                    prefixIcon: Icon(Icons.group, color: AppColors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                    ),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 1,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      if (!RegExp(r'^[A-Za-z]$').hasMatch(value)) {
                        return 'Must be A-Z';
                      }
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: UIConstants.spacing12),

          // Name Preview (Read-only)
          Container(
            padding: EdgeInsets.all(UIConstants.paddingMedium),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.preview, color: AppColors.primary, size: 20),
                SizedBox(width: UIConstants.spacing8),
                Text(
                  'Display Name: ',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: UIConstants.fontSizeMedium,
                  ),
                ),
                Text(
                  _getPreviewName(),
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: UIConstants.fontSizeMedium,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: UIConstants.spacing20),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(_editingGrade == null ? 'Add Grade' : 'Update Grade'),
                ),
              ),
              if (_editingGrade != null) ...[
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _cancelEdit,
                  child: const Text('Cancel'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _getPreviewName() {
    final level = _levelController.text.isEmpty ? '?' : _levelController.text;
    final section = _sectionController.text.trim().toUpperCase();

    if (section.isEmpty) {
      return 'Grade $level';
    } else {
      return 'Grade $level-$section';
    }
  }

  Widget _buildGradeLevelSection(int level, List<GradeEntity> grades) {
    // Sort grades by section
    grades.sort((a, b) {
      final aSection = a.section ?? '';
      final bSection = b.section ?? '';
      return aSection.compareTo(bSection);
    });

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(UIConstants.paddingMedium),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Text(
              'Level $level',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          ...grades.map((grade) => _buildGradeCard(grade)).toList(),
        ],
      ),
    );
  }

  Widget _buildGradeCard(GradeEntity grade) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withOpacity(0.2),
        child: Text(
          grade.level.toString(),
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        grade.displayName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        'Added ${AppDateUtils.formatShortDate(grade.createdAt)}',
        style: TextStyle(color: AppColors.textTertiary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _startEdit(grade),
            icon: Icon(Icons.edit, color: AppColors.primary),
            tooltip: 'Edit grade',
          ),
          IconButton(
            onPressed: () => _showDeleteDialog(grade),
            icon: Icon(Icons.delete, color: AppColors.error),
            tooltip: 'Delete grade',
          ),
        ],
      ),
    );
  }

  void _handleStateChanges(BuildContext context, GradeState state) {
    if (state is GradeCreated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Grade "${state.grade.displayName}" created successfully'),
          backgroundColor: AppColors.success,
        ),
      );
      _clearForm();
      context.read<GradeBloc>().add(const LoadGrades());
    } else if (state is GradeUpdated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Grade "${state.grade.displayName}" updated successfully'),
          backgroundColor: AppColors.success,
        ),
      );
      _clearForm();
      context.read<GradeBloc>().add(const LoadGrades());
    } else if (state is GradeDeleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Grade deleted successfully'),
          backgroundColor: Colors.orange,
        ),
      );
      context.read<GradeBloc>().add(const LoadGrades());
    }
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;

    final level = int.parse(_levelController.text.trim());
    final section = _sectionController.text.trim().toUpperCase();

    // Name is auto-generated - no manual input
    final name = 'Grade $level';

    if (_editingGrade == null) {
      final newGrade = GradeEntity(
        id: '', // Will be generated by database
        tenantId: '', // Will be set by repository
        name: name, // Auto-generated
        level: level,
        section: section.isEmpty ? null : section,
        isActive: true,
        createdAt: DateTime.now(),
      );

      context.read<GradeBloc>().add(CreateGrade(newGrade));
    } else {
      final updatedGrade = GradeEntity(
        id: _editingGrade!.id,
        tenantId: _editingGrade!.tenantId,
        name: name, // Auto-generated
        level: level,
        section: section.isEmpty ? null : section,
        isActive: _editingGrade!.isActive,
        createdAt: _editingGrade!.createdAt,
      );

      context.read<GradeBloc>().add(UpdateGrade(updatedGrade));
    }
  }

  void _startEdit(GradeEntity grade) {
    setState(() {
      _editingGrade = grade;
      _nameController.text = grade.name;
      _levelController.text = grade.level.toString();
      _sectionController.text = grade.section ?? '';
    });
  }

  void _cancelEdit() {
    _clearForm();
  }

  void _clearForm() {
    setState(() {
      _editingGrade = null;
      _nameController.clear();
      _levelController.clear();
      _sectionController.clear();
    });
  }

  void _showDeleteDialog(GradeEntity grade) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Grade'),
          content: Text('Are you sure you want to delete "${grade.displayName}"?\n\nThis action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.read<GradeBloc>().add(DeleteGrade(grade.id));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }


}