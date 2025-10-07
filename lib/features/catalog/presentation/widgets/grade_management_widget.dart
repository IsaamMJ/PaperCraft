// features/catalog/presentation/widgets/grade_management_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../domain/entities/grade_entity.dart';
import '../bloc/grade_bloc.dart';

class GradeManagementWidget extends StatefulWidget {
  const GradeManagementWidget({super.key});

  @override
  State<GradeManagementWidget> createState() => _GradeManagementWidgetState();
}

class _GradeManagementWidgetState extends State<GradeManagementWidget> {
  final _formKey = GlobalKey<FormState>();
  GradeEntity? _editingGrade;
  int? _selectedGradeNumber;

  @override
  void initState() {
    super.initState();
    context.read<GradeBloc>().add(const LoadGrades());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GradeBloc, GradeState>(
      listener: _handleStateChanges,
      child: Padding(
        padding: const EdgeInsets.all(UIConstants.paddingMedium),
        child: Column(
          children: [
            _buildForm(),
            SizedBox(height: UIConstants.spacing20),
            const Divider(),
            SizedBox(height: UIConstants.spacing20),
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
                          Icon(Icons.error_outline, size: 48, color: AppColors.error),
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
                            Icon(Icons.school_outlined, size: 48, color: AppColors.textTertiary),
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

                    return ListView.builder(
                      itemCount: state.grades.length,
                      itemBuilder: (context, index) {
                        final grade = state.grades[index];
                        return _buildGradeCard(grade);
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
          DropdownButtonFormField<int>(
            value: _selectedGradeNumber,
            decoration: InputDecoration(
              labelText: 'Grade Number',
              prefixIcon: Icon(Icons.format_list_numbered, color: AppColors.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              ),
            ),
            items: List.generate(12, (index) => index + 1)
                .map((number) => DropdownMenuItem(
              value: number,
              child: Text('Grade $number'),
            ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedGradeNumber = value;
              });
            },
            validator: (value) {
              if (value == null) return 'Please select a grade number';
              return null;
            },
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

  Widget _buildGradeCard(GradeEntity grade) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.2),
          child: Text(
            grade.gradeNumber.toString(),
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
          'Created ${_formatDate(grade.createdAt)}',
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

    if (_editingGrade == null) {
      final newGrade = GradeEntity(
        id: '',
        tenantId: '',
        gradeNumber: _selectedGradeNumber!,
        isActive: true,
        createdAt: DateTime.now(),
      );

      context.read<GradeBloc>().add(CreateGrade(newGrade));
    } else {
      final updatedGrade = GradeEntity(
        id: _editingGrade!.id,
        tenantId: _editingGrade!.tenantId,
        gradeNumber: _selectedGradeNumber!,
        isActive: _editingGrade!.isActive,
        createdAt: _editingGrade!.createdAt,
      );

      context.read<GradeBloc>().add(UpdateGrade(updatedGrade));
    }
  }

  void _startEdit(GradeEntity grade) {
    setState(() {
      _editingGrade = grade;
      _selectedGradeNumber = grade.gradeNumber;
    });
  }

  void _cancelEdit() {
    _clearForm();
  }

  void _clearForm() {
    setState(() {
      _editingGrade = null;
      _selectedGradeNumber = null;
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
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'today';
    } else if (diff.inDays == 1) {
      return 'yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}