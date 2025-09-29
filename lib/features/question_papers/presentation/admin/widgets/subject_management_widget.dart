// features/settings/presentation/widgets/subject_management_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/presentation/constants/app_colors.dart';
import '../../../domain/entities/subject_entity.dart';
import '../../bloc/subject_bloc.dart';

class SubjectManagementWidget extends StatefulWidget {
  const SubjectManagementWidget({super.key});

  @override
  State<SubjectManagementWidget> createState() => _SubjectManagementWidgetState();
}

class _SubjectManagementWidgetState extends State<SubjectManagementWidget> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  SubjectEntity? _editingSubject;

  @override
  void initState() {
    super.initState();
    // Load subjects on init
    context.read<SubjectBloc>().add(const LoadSubjects());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SubjectBloc, SubjectState>(
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

            // Subjects List
            Expanded(
              child: BlocBuilder<SubjectBloc, SubjectState>(
                builder: (context, state) {
                  if (state is SubjectLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state is SubjectError) {
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
                              context.read<SubjectBloc>().add(const LoadSubjects());
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (state is SubjectsLoaded) {
                    if (state.subjects.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.subject_outlined,
                                size: 48,
                                color: AppColors.textTertiary),
                            const SizedBox(height: 16),
                            Text('No subjects yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                )),
                            const SizedBox(height: 8),
                            Text('Add your first subject above',
                                style: TextStyle(color: AppColors.textTertiary)),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: state.subjects.length,
                      itemBuilder: (context, index) {
                        final subject = state.subjects[index];
                        return _buildSubjectCard(subject);
                      },
                    );
                  }

                  return const Center(child: Text('No subjects loaded'));
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
            _editingSubject == null ? 'Add Subject' : 'Edit Subject',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Subject Name',
              hintText: 'e.g., Mathematics, Physics, English',
              prefixIcon: Icon(Icons.subject, color: AppColors.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Subject name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: 'Description (Optional)',
              hintText: 'Brief description of the subject',
              prefixIcon: Icon(Icons.description, color: AppColors.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            maxLines: 2,
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
                  child: Text(_editingSubject == null ? 'Add Subject' : 'Update Subject'),
                ),
              ),
              if (_editingSubject != null) ...[
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

  Widget _buildSubjectCard(SubjectEntity subject) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: Icon(
            Icons.subject,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        title: Text(
          subject.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: subject.description != null && subject.description!.isNotEmpty
            ? Text(subject.description!)
            : Text(
          'Added ${_formatDate(subject.createdAt)}',
          style: TextStyle(color: AppColors.textTertiary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _startEdit(subject),
              icon: Icon(Icons.edit, color: AppColors.primary),
              tooltip: 'Edit subject',
            ),
            IconButton(
              onPressed: () => _showDeleteDialog(subject),
              icon: Icon(Icons.delete, color: AppColors.error),
              tooltip: 'Delete subject',
            ),
          ],
        ),
      ),
    );
  }

  void _handleStateChanges(BuildContext context, SubjectState state) {
    if (state is SubjectCreated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Subject "${state.subject.name}" created successfully'),
          backgroundColor: AppColors.success,
        ),
      );
      _clearForm();
      context.read<SubjectBloc>().add(const LoadSubjects());
    } else if (state is SubjectUpdated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Subject "${state.subject.name}" updated successfully'),
          backgroundColor: AppColors.success,
        ),
      );
      _clearForm();
      context.read<SubjectBloc>().add(const LoadSubjects());
    } else if (state is SubjectDeleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subject deleted successfully'),
          backgroundColor: Colors.orange,
        ),
      );
      context.read<SubjectBloc>().add(const LoadSubjects());
    }
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    if (_editingSubject == null) {
      // Create new subject
      final newSubject = SubjectEntity(
        id: '', // Will be generated by the backend
        tenantId: '', // Will be set by the repository
        name: name,
        description: description.isEmpty ? null : description,
        isActive: true,
        createdAt: DateTime.now(),
      );

      context.read<SubjectBloc>().add(CreateSubject(newSubject));
    } else {
      // Update existing subject
      final updatedSubject = SubjectEntity(
        id: _editingSubject!.id,
        tenantId: _editingSubject!.tenantId,
        name: name,
        description: description.isEmpty ? null : description,
        isActive: _editingSubject!.isActive,
        createdAt: _editingSubject!.createdAt,
      );

      context.read<SubjectBloc>().add(UpdateSubject(updatedSubject));
    }
  }

  void _startEdit(SubjectEntity subject) {
    setState(() {
      _editingSubject = subject;
      _nameController.text = subject.name;
      _descriptionController.text = subject.description ?? '';
    });
  }

  void _cancelEdit() {
    _clearForm();
  }

  void _clearForm() {
    setState(() {
      _editingSubject = null;
      _nameController.clear();
      _descriptionController.clear();
    });
  }

  void _showDeleteDialog(SubjectEntity subject) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Subject'),
          content: Text('Are you sure you want to delete "${subject.name}"?\n\nThis action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.read<SubjectBloc>().add(DeleteSubject(subject.id));
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