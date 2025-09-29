// features/settings/presentation/widgets/grade_management_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/presentation/constants/app_colors.dart';
import '../../../domain/entities/grade_entity.dart';
import '../../bloc/grade_bloc.dart';

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
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Add/Edit Form
            _buildForm(),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),

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
                          const SizedBox(height: 16),
                          Text(state.message,
                              style: TextStyle(color: AppColors.error),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 16),
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
                            const SizedBox(height: 16),
                            Text('No grades yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                )),
                            const SizedBox(height: 8),
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
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Grade Name',
                    hintText: 'e.g., Grade 1, Class 10',
                    prefixIcon: Icon(Icons.school, color: AppColors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Grade name is required';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _levelController,
                  decoration: InputDecoration(
                    labelText: 'Level',
                    hintText: '1-12',
                    prefixIcon: Icon(Icons.format_list_numbered, color: AppColors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Level required';
                    }
                    final level = int.tryParse(value.trim());
                    if (level == null || level < 1 || level > 12) {
                      return 'Level must be 1-12';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _sectionController,
            decoration: InputDecoration(
              labelText: 'Section (Optional)',
              hintText: 'e.g., A, B, C',
              prefixIcon: Icon(Icons.group, color: AppColors.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 20),

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
            padding: const EdgeInsets.all(16),
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
        'Added ${_formatDate(grade.createdAt)}',
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

    final name = _nameController.text.trim();
    final level = int.parse(_levelController.text.trim());
    final section = _sectionController.text.trim();

    if (_editingGrade == null) {
      // Create new grade
      final newGrade = GradeEntity(
        id: '', // Will be generated by the backend
        tenantId: '', // Will be set by the repository
        name: name,
        level: level,
        section: section.isEmpty ? null : section,
        isActive: true,
        createdAt: DateTime.now(),
      );

      context.read<GradeBloc>().add(CreateGrade(newGrade));
    } else {
      // Update existing grade
      final updatedGrade = GradeEntity(
        id: _editingGrade!.id,
        tenantId: _editingGrade!.tenantId,
        name: name,
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}