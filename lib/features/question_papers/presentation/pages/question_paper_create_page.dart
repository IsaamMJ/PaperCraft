// features/question_papers/presentation/pages/question_paper_create_page.dart
// Updated to fix the BLoC provider issue

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/exam_type_entity.dart';
import '../../domain/entities/subject_entity.dart';
import '../bloc/question_paper_bloc.dart';
import '../widgets/question_input_dialog.dart';

class QuestionPaperCreatePage extends StatefulWidget {
  const QuestionPaperCreatePage({super.key});

  @override
  State<QuestionPaperCreatePage> createState() => _QuestionPaperCreatePageState();
}

class _QuestionPaperCreatePageState extends State<QuestionPaperCreatePage> {
  // Form controllers
  final TextEditingController _titleController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Selected values
  ExamTypeEntity? _selectedExamType;
  List<SubjectEntity> _selectedSubjects = [];

  // Mock data - replace with actual data from your system
  final List<ExamTypeEntity> _availableExamTypes = [
    ExamTypeEntity(
      id: '1',
      tenantId: 'tenant1',
      name: 'Midterm Exam',
      durationMinutes: 90,
      totalMarks: 100,
      sections: [
        ExamSectionEntity(
          name: 'Section A - Multiple Choice',
          type: 'multiple_choice',
          questions: 10,
          marksPerQuestion: 2,
        ),
        ExamSectionEntity(
          name: 'Section B - Short Answer',
          type: 'short_answer',
          questions: 5,
          marksPerQuestion: 6,
        ),
      ],
    ),
    ExamTypeEntity(
      id: '2',
      tenantId: 'tenant1',
      name: 'Final Exam',
      durationMinutes: 120,
      totalMarks: 150,
      sections: [
        ExamSectionEntity(
          name: 'Section A - Multiple Choice',
          type: 'multiple_choice',
          questions: 15,
          marksPerQuestion: 3,
        ),
        ExamSectionEntity(
          name: 'Section B - Essay Questions',
          type: 'short_answer',
          questions: 3,
          marksPerQuestion: 35,
        ),
      ],
    ),
  ];

  final List<SubjectEntity> _availableSubjects = [
    SubjectEntity(
      id: '1',
      tenantId: 'tenant1',
      name: 'Mathematics',
      isActive: true,
      createdAt: DateTime.now(),
    ),
    SubjectEntity(
      id: '2',
      tenantId: 'tenant1',
      name: 'Physics',
      isActive: true,
      createdAt: DateTime.now(),
    ),
    SubjectEntity(
      id: '3',
      tenantId: 'tenant1',
      name: 'Chemistry',
      isActive: true,
      createdAt: DateTime.now(),
    ),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  bool get _canProceedToQuestions {
    return _formKey.currentState?.validate() == true &&
        _selectedExamType != null &&
        _selectedSubjects.isNotEmpty;
  }

  void _proceedToQuestionCreation() {
    if (!_canProceedToQuestions) return;

    // Create BLoC provider at this level to ensure it's available in the dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => BlocProvider(
        // Create new BLoC instance for the dialog
        create: (context) => QuestionPaperBloc(
          saveDraftUseCase: sl(),
          submitPaperUseCase: sl(),
          getDraftsUseCase: sl(),
          getUserSubmissionsUseCase: sl(),
          approvePaperUseCase: sl(),
          rejectPaperUseCase: sl(),
          getPapersForReviewUseCase: sl(),
          deleteDraftUseCase: sl(),
          pullForEditingUseCase: sl(),
          getPaperByIdUseCase: sl(),
        ),
        child: BlocListener<QuestionPaperBloc, QuestionPaperState>(
          listener: (context, state) {
            if (state is QuestionPaperSuccess) {
              Navigator.of(dialogContext).pop(); // Close dialog
              _onPaperCreated(); // Handle success
            } else if (state is QuestionPaperError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: QuestionInputDialog(
            sections: _selectedExamType!.sections,
            examType: _selectedExamType!,
            selectedSubjects: _selectedSubjects,
            paperTitle: _titleController.text.trim(),
            onPaperCreated: (paper) {
              // This will be handled by the BlocListener above
            },
          ),
        ),
      ),
    );
  }

  void _onPaperCreated() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Question paper created successfully!'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () => context.go('/question-papers'),
        ),
      ),
    );

    // Navigate back to home
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Question Paper'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Paper Details',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Set up the basic information for your question paper',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),

              // Paper Title
              _buildPaperTitleSection(),
              const SizedBox(height: 24),

              // Exam Type Selection
              _buildExamTypeSection(),
              const SizedBox(height: 24),

              // Subject Selection
              _buildSubjectSelection(),
              const SizedBox(height: 32),

              // Paper Preview
              if (_selectedExamType != null) ...[
                _buildPaperPreview(),
                const SizedBox(height: 32),
              ],

              // Action Buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaperTitleSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paper Title',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'e.g., Mathematics Midterm Exam 2024',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.blue, width: 2),
                ),
                prefixIcon: const Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a paper title';
                }
                if (value.trim().length < 3) {
                  return 'Title must be at least 3 characters long';
                }
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamTypeSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Exam Type',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            ...(_availableExamTypes.map((examType) {
              final isSelected = _selectedExamType?.id == examType.id;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => setState(() => _selectedExamType = examType),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: isSelected ? Colors.blue.shade50 : Colors.white,
                    ),
                    child: Row(
                      children: [
                        Radio<ExamTypeEntity>(
                          value: examType,
                          groupValue: _selectedExamType,
                          onChanged: (value) => setState(() => _selectedExamType = value),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                examType.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.blue.shade700 : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${examType.formattedDuration} • ${examType.calculatedTotalMarks} marks • ${examType.sections.length} sections',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectSelection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Subjects',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select one or more subjects for this paper',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableSubjects.map((subject) {
                final isSelected = _selectedSubjects.contains(subject);
                return FilterChip(
                  label: Text(subject.name),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedSubjects.add(subject);
                      } else {
                        _selectedSubjects.remove(subject);
                      }
                    });
                  },
                  selectedColor: Colors.blue.shade100,
                  checkmarkColor: Colors.blue.shade700,
                );
              }).toList(),
            ),
            if (_selectedSubjects.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Please select at least one subject',
                  style: TextStyle(
                    color: Colors.red.shade600,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaperPreview() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.preview, color: Colors.green.shade600),
                const SizedBox(width: 8),
                Text(
                  'Paper Preview',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _titleController.text.isNotEmpty ? _titleController.text : 'Untitled Paper',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Exam Type: ${_selectedExamType!.name}'),
                  Text('Duration: ${_selectedExamType!.formattedDuration}'),
                  Text('Total Marks: ${_selectedExamType!.calculatedTotalMarks}'),
                  if (_selectedSubjects.isNotEmpty)
                    Text('Subjects: ${_selectedSubjects.map((s) => s.name).join(', ')}'),
                  const SizedBox(height: 12),
                  Text(
                    'Sections:',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  ..._selectedExamType!.sections.map((section) => Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Text(
                      '• ${section.name} (${section.questions} questions × ${section.marksPerQuestion} marks)',
                      style: TextStyle(color: Colors.grey[700], fontSize: 12),
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Cancel'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _canProceedToQuestions ? _proceedToQuestionCreation : null,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Create Questions'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}