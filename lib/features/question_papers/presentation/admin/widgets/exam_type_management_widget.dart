// features/settings/presentation/widgets/exam_type_management_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/presentation/constants/app_colors.dart';
import '../../../../../core/presentation/constants/ui_constants.dart';
import '../../../domain/entities/exam_type_entity.dart';
import '../../bloc/exam_type_bloc.dart';

class ExamTypeManagementWidget extends StatefulWidget {
  const ExamTypeManagementWidget({super.key});

  @override
  State<ExamTypeManagementWidget> createState() => _ExamTypeManagementWidgetState();
}

class _ExamTypeManagementWidgetState extends State<ExamTypeManagementWidget> {
  final _nameController = TextEditingController();
  final _durationController = TextEditingController();
  final _totalMarksController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  ExamTypeEntity? _editingExamType;
  List<ExamSectionEntity> _sections = [];

  @override
  void initState() {
    super.initState();
    // Load exam types on init
    context.read<ExamTypeBloc>().add(const LoadExamTypes());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    _totalMarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExamTypeBloc, ExamTypeState>(
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

            // Exam Types List
            Expanded(
              child: BlocBuilder<ExamTypeBloc, ExamTypeState>(
                builder: (context, state) {
                  if (state is ExamTypeLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state is ExamTypeError) {
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
                              context.read<ExamTypeBloc>().add(const LoadExamTypes());
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (state is ExamTypesLoaded) {
                    if (state.examTypes.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.quiz_outlined,
                                size: 48,
                                color: AppColors.textTertiary),
                            SizedBox(height: UIConstants.spacing16),
                            Text('No exam types yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                )),
                            SizedBox(height: UIConstants.spacing8),
                            Text('Add your first exam type above',
                                style: TextStyle(color: AppColors.textTertiary)),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: state.examTypes.length,
                      itemBuilder: (context, index) {
                        final examType = state.examTypes[index];
                        return _buildExamTypeCard(examType);
                      },
                    );
                  }

                  return const Center(child: Text('No exam types loaded'));
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
            _editingExamType == null ? 'Add Exam Type' : 'Edit Exam Type',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: UIConstants.spacing16),

          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Exam Type Name',
              hintText: 'e.g., Quarterly Exam, Annual Exam',
              prefixIcon: Icon(Icons.quiz, color: AppColors.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Exam type name is required';
              }
              return null;
            },
          ),
          SizedBox(height: UIConstants.spacing16),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _durationController,
                  decoration: InputDecoration(
                    labelText: 'Duration (minutes)',
                    hintText: '180',
                    prefixIcon: Icon(Icons.timer, color: AppColors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      final duration = int.tryParse(value.trim());
                      if (duration == null || duration < 1) {
                        return 'Invalid duration';
                      }
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _totalMarksController,
                  decoration: InputDecoration(
                    labelText: 'Total Marks',
                    hintText: '100',
                    prefixIcon: Icon(Icons.grade, color: AppColors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      final marks = int.tryParse(value.trim());
                      if (marks == null || marks < 1) {
                        return 'Invalid marks';
                      }
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: UIConstants.spacing16),

          // Sections Management
          _buildSectionsManagement(),
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
                  child: Text(_editingExamType == null ? 'Add Exam Type' : 'Update Exam Type'),
                ),
              ),
              if (_editingExamType != null) ...[
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

  Widget _buildSectionsManagement() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Sections',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _addSection,
              icon: Icon(Icons.add, size: 18),
              label: const Text('Add Section'),
            ),
          ],
        ),
        SizedBox(height: UIConstants.spacing8),

        if (_sections.isEmpty)
          Container(
            padding: const EdgeInsets.all(UIConstants.paddingMedium),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.textTertiary.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
            ),
            child: Center(
              child: Text(
                'No sections added yet',
                style: TextStyle(color: AppColors.textTertiary),
              ),
            ),
          )
        else
          ..._sections.asMap().entries.map((entry) {
            final index = entry.key;
            final section = entry.value;
            return _buildSectionCard(section, index);
          }).toList(),
      ],
    );
  }

  Widget _buildSectionCard(ExamSectionEntity section, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(section.name),
        subtitle: Text(
          '${section.formattedType} • ${section.questions} questions • ${section.marksPerQuestion} marks each',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _editSection(index),
              icon: Icon(Icons.edit, color: AppColors.primary),
              tooltip: 'Edit section',
            ),
            IconButton(
              onPressed: () => _removeSection(index),
              icon: Icon(Icons.delete, color: AppColors.error),
              tooltip: 'Remove section',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamTypeCard(ExamTypeEntity examType) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: Icon(
            Icons.quiz,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        title: Text(
          examType.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${examType.formattedDuration} • ${examType.calculatedTotalMarks} marks • ${examType.sections.length} sections',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _startEdit(examType),
              icon: Icon(Icons.edit, color: AppColors.primary),
              tooltip: 'Edit exam type',
            ),
            IconButton(
              onPressed: () => _showDeleteDialog(examType),
              icon: Icon(Icons.delete, color: AppColors.error),
              tooltip: 'Delete exam type',
            ),
          ],
        ),
        children: [
          if (examType.sections.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sections:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: UIConstants.spacing8),
                  ...examType.sections.map((section) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${section.name}: ${section.questionRequirement} (${section.totalMarksForExam} marks)',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                  SizedBox(height: UIConstants.spacing8),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _addSection() {
    _showSectionDialog();
  }

  void _editSection(int index) {
    _showSectionDialog(section: _sections[index], index: index);
  }

  void _removeSection(int index) {
    setState(() {
      _sections.removeAt(index);
    });
  }

  void _showSectionDialog({ExamSectionEntity? section, int? index}) {
    final nameController = TextEditingController(text: section?.name ?? '');
    final questionsController = TextEditingController(text: section?.questions.toString() ?? '');
    final marksController = TextEditingController(text: section?.marksPerQuestion.toString() ?? '');
    final questionsToAnswerController = TextEditingController(text: section?.questionsToAnswer?.toString() ?? '');
    String selectedType = section?.type ?? 'multiple_choice';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(section == null ? 'Add Section' : 'Edit Section'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Section Name',
                        hintText: 'e.g., Part A, MCQs',
                      ),
                    ),
                    SizedBox(height: UIConstants.spacing12),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Question Type',
                      ),
                      items: [
                        'multiple_choice',
                        'short_answer',
                        'fill_blanks',
                        'true_false',
                        'matching',
                      ].map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(_formatQuestionType(type)),
                      )).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedType = value!;
                        });
                      },
                    ),
                    SizedBox(height: UIConstants.spacing12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: questionsController,
                            decoration: const InputDecoration(
                              labelText: 'Total Questions',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: marksController,
                            decoration: const InputDecoration(
                              labelText: 'Marks Each',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: UIConstants.spacing12),
                    TextFormField(
                      controller: questionsToAnswerController,
                      decoration: const InputDecoration(
                        labelText: 'Questions to Answer (Optional)',
                        hintText: 'Leave empty if all questions must be answered',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final questions = int.tryParse(questionsController.text.trim()) ?? 0;
                    final marks = int.tryParse(marksController.text.trim()) ?? 0;
                    final questionsToAnswer = questionsToAnswerController.text.trim().isEmpty
                        ? null
                        : int.tryParse(questionsToAnswerController.text.trim());

                    if (name.isNotEmpty && questions > 0 && marks > 0) {
                      final newSection = ExamSectionEntity(
                        name: name,
                        type: selectedType,
                        questions: questions,
                        marksPerQuestion: marks,
                        questionsToAnswer: questionsToAnswer,
                      );

                      setState(() {
                        if (index != null) {
                          _sections[index] = newSection;
                        } else {
                          _sections.add(newSection);
                        }
                      });

                      Navigator.of(context).pop();
                    }
                  },
                  child: Text(section == null ? 'Add' : 'Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _handleStateChanges(BuildContext context, ExamTypeState state) {
    if (state is ExamTypeCreated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exam type "${state.examType.name}" created successfully'),
          backgroundColor: AppColors.success,
        ),
      );
      _clearForm();
      context.read<ExamTypeBloc>().add(const LoadExamTypes());
    } else if (state is ExamTypeUpdated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exam type "${state.examType.name}" updated successfully'),
          backgroundColor: AppColors.success,
        ),
      );
      _clearForm();
      context.read<ExamTypeBloc>().add(const LoadExamTypes());
    } else if (state is ExamTypeDeleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exam type deleted successfully'),
          backgroundColor: Colors.orange,
        ),
      );
      context.read<ExamTypeBloc>().add(const LoadExamTypes());
    }
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final durationText = _durationController.text.trim();
    final totalMarksText = _totalMarksController.text.trim();

    final duration = durationText.isEmpty ? null : int.tryParse(durationText);
    final totalMarks = totalMarksText.isEmpty ? null : int.tryParse(totalMarksText);

    if (_editingExamType == null) {
      // Create new exam type
      final newExamType = ExamTypeEntity(
        id: '', // Will be generated by the backend
        tenantId: '', // Will be set by the repository
        name: name,
        durationMinutes: duration,
        totalMarks: totalMarks,
        totalQuestions: _sections.length,
        sections: _sections,
      );

      context.read<ExamTypeBloc>().add(CreateExamType(newExamType));
    } else {
      // Update existing exam type
      final updatedExamType = ExamTypeEntity(
        id: _editingExamType!.id,
        tenantId: _editingExamType!.tenantId,
        name: name,
        durationMinutes: duration,
        totalMarks: totalMarks,
        totalQuestions: _sections.length,
        sections: _sections,
      );

      context.read<ExamTypeBloc>().add(UpdateExamType(updatedExamType));
    }
  }

  void _startEdit(ExamTypeEntity examType) {
    setState(() {
      _editingExamType = examType;
      _nameController.text = examType.name;
      _durationController.text = examType.durationMinutes?.toString() ?? '';
      _totalMarksController.text = examType.totalMarks?.toString() ?? '';
      _sections = List.from(examType.sections);
    });
  }

  void _cancelEdit() {
    _clearForm();
  }

  void _clearForm() {
    setState(() {
      _editingExamType = null;
      _nameController.clear();
      _durationController.clear();
      _totalMarksController.clear();
      _sections.clear();
    });
  }

  void _showDeleteDialog(ExamTypeEntity examType) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Exam Type'),
          content: Text('Are you sure you want to delete "${examType.name}"?\n\nThis action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.read<ExamTypeBloc>().add(DeleteExamType(examType.id));
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

  String _formatQuestionType(String type) {
    switch (type) {
      case 'multiple_choice':
        return 'Multiple Choice';
      case 'fill_blanks':
        return 'Fill in Blanks';
      case 'matching':
        return 'Match the Following';
      case 'short_answer':
        return 'Short Answer';
      case 'true_false':
        return 'True/False';
      default:
        return type;
    }
  }
}