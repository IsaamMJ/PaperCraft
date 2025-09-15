// features/question_papers/presentation/widgets/question_input_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/exam_type_entity.dart';
import '../../domain/entities/subject_entity.dart';
import '../../domain/entities/question_entity.dart';
import '../../domain/entities/question_paper_entity.dart';
import '../../domain/entities/paper_status.dart';
import '../bloc/question_paper_bloc.dart';

class QuestionInputDialog extends StatefulWidget {
  final List<ExamSectionEntity> sections;
  final ExamTypeEntity examType;
  final List<SubjectEntity> selectedSubjects;
  final String paperTitle;
  final Function(QuestionPaperEntity) onPaperCreated;

  const QuestionInputDialog({
    super.key,
    required this.sections,
    required this.examType,
    required this.selectedSubjects,
    required this.paperTitle,
    required this.onPaperCreated,
  });

  @override
  State<QuestionInputDialog> createState() => _QuestionInputDialogState();
}

class _QuestionInputDialogState extends State<QuestionInputDialog> {
  int currentSectionIndex = 0;
  Map<String, List<Question>> allQuestions = {};
  bool _isProcessing = false;

  // Form controllers
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers =
  List.generate(4, (index) => TextEditingController());
  final TextEditingController _subQuestionController = TextEditingController();
  final TextEditingController _subQuestionMarksController = TextEditingController();

  // Form state
  List<SubQuestion> currentSubQuestions = [];
  bool isOptionalQuestion = false;
  bool showSubQuestions = false;
  bool isFormValid = false;

  @override
  void initState() {
    super.initState();
    // Initialize questions map for all sections
    for (var section in widget.sections) {
      allQuestions[section.name] = [];
    }
    _questionController.addListener(_validateForm);
    _subQuestionMarksController.text = '1'; // Default marks

    // Add listeners to option controllers for validation
    for (var controller in _optionControllers) {
      controller.addListener(_validateForm);
    }
  }

  @override
  void dispose() {
    _questionController.removeListener(_validateForm);
    _questionController.dispose();
    _subQuestionController.dispose();
    _subQuestionMarksController.dispose();

    // Properly dispose all option controllers
    for (var controller in _optionControllers) {
      controller.removeListener(_validateForm);
      controller.dispose();
    }
    super.dispose();
  }

  void _validateForm() {
    final currentSection = widget.sections[currentSectionIndex];
    bool valid = _questionController.text.trim().isNotEmpty;

    if (currentSection.type == 'multiple_choice') {
      final filledOptions = _optionControllers
          .map((c) => c.text.trim())
          .where((text) => text.isNotEmpty)
          .length;
      valid = valid && filledOptions >= 2;
    }

    if (valid != isFormValid) {
      setState(() {
        isFormValid = valid;
      });
    }
  }

  void _clearForm() {
    _questionController.clear();
    _subQuestionController.clear();
    _subQuestionMarksController.text = '1';
    for (var controller in _optionControllers) {
      controller.clear();
    }
    setState(() {
      currentSubQuestions.clear();
      isOptionalQuestion = false;
      showSubQuestions = false;
      isFormValid = false; // Reset form validation
    });
  }

  void _addSubQuestion() {
    if (_subQuestionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a sub-question'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    int marks = int.tryParse(_subQuestionMarksController.text.trim()) ?? 1;
    if (marks <= 0) marks = 1;

    setState(() {
      currentSubQuestions.add(SubQuestion(
        text: _subQuestionController.text.trim(),
        marks: marks,
      ));
      _subQuestionController.clear();
      _subQuestionMarksController.text = '1';
    });
  }

  void _removeSubQuestion(int index) {
    if (index >= 0 && index < currentSubQuestions.length) {
      setState(() {
        currentSubQuestions.removeAt(index);
        if (currentSubQuestions.isEmpty) {
          showSubQuestions = false;
        }
      });
    }
  }

  void _addQuestion() {
    if (!isFormValid) return;

    final currentSection = widget.sections[currentSectionIndex];
    final sectionName = currentSection.name;
    final questionType = currentSection.type;
    final marksPerQuestion = currentSection.marksPerQuestion;

    // Prepare options for MCQ
    List<String>? options;
    if (questionType == 'multiple_choice') {
      options = _optionControllers
          .map((controller) => controller.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      // For MCQ, clear sub-questions (mutually exclusive)
      currentSubQuestions.clear();
    }

    // For non-MCQ questions, clear options (mutually exclusive)
    if (questionType != 'multiple_choice') {
      options = null;
    }

    final question = Question(
      text: _questionController.text.trim(),
      type: questionType,
      options: options,
      correctAnswer: null,
      marks: marksPerQuestion,
      subQuestions: List.from(currentSubQuestions),
      isOptional: isOptionalQuestion,
    );

    // Validate the question
    if (!question.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Question validation error: ${question.validationError}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      allQuestions[sectionName]!.add(question);
    });

    _clearForm();
    _showSuccessMessage(sectionName);
    _checkSectionCompletion();
  }

  void _showSuccessMessage(String sectionName) {
    final currentSection = widget.sections[currentSectionIndex];
    final sectionQuestions = allQuestions[sectionName]!;
    final mandatoryCount = sectionQuestions.where((q) => !q.isOptional).length;
    final required = currentSection.questions;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Question added to $sectionName ($mandatoryCount/$required required)'),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _checkSectionCompletion() {
    final currentSection = widget.sections[currentSectionIndex];
    final sectionName = currentSection.name;
    final sectionQuestions = allQuestions[sectionName]!;
    final requiredQuestions = currentSection.questions;

    final mandatoryQuestions = sectionQuestions.where((q) => !q.isOptional).length;
    bool sectionComplete = mandatoryQuestions >= requiredQuestions;

    if (sectionComplete && currentSectionIndex < widget.sections.length - 1) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            currentSectionIndex++;
          });
          _showSectionCompletedDialog(sectionName);
        }
      });
    }
  }

  void _showSectionCompletedDialog(String completedSection) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 32),
        title: const Text('Section Complete!'),
        content: Text('$completedSection is done. Moving to the next section.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  bool _allSectionsComplete() {
    for (var section in widget.sections) {
      final sectionName = section.name;
      final sectionQuestions = allQuestions[sectionName]!;
      final requiredQuestions = section.questions;

      final mandatoryQuestions = sectionQuestions.where((q) => !q.isOptional).length;
      if (mandatoryQuestions < requiredQuestions) {
        return false;
      }
    }
    return true;
  }

  List<String> _getValidationErrors() {
    final errors = <String>[];

    for (var section in widget.sections) {
      final sectionName = section.name;
      final sectionQuestions = allQuestions[sectionName]!;
      final requiredQuestions = section.questions;
      final mandatoryQuestions = sectionQuestions.where((q) => !q.isOptional).length;

      if (mandatoryQuestions < requiredQuestions) {
        errors.add('$sectionName needs ${requiredQuestions - mandatoryQuestions} more questions');
      }

      // Check question validity
      for (var i = 0; i < sectionQuestions.length; i++) {
        final question = sectionQuestions[i];
        if (!question.isValid) {
          errors.add('$sectionName Question ${i + 1}: ${question.validationError}');
        }
      }
    }

    return errors;
  }

  void _createQuestionPaper() {
    if (_isProcessing) return;

    if (!_allSectionsComplete()) {
      final errors = _getValidationErrors();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot create paper: ${errors.join(', ')}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final questionPaper = QuestionPaperEntity.createDraft(
        title: widget.paperTitle,
        subject: widget.selectedSubjects.map((s) => s.name).join(', '),
        examType: widget.examType.name,
        createdBy: 'current_user',
        examTypeEntity: widget.examType,
        questions: allQuestions,
      );

      // Save as draft using BLoC
      context.read<QuestionPaperBloc>().add(SaveDraft(questionPaper));
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating question paper: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSectionProgress() {
    final currentSection = widget.sections[currentSectionIndex];
    final sectionName = currentSection.name;
    final sectionQuestions = allQuestions[sectionName]!;
    final requiredQuestions = currentSection.questions;

    final mandatoryQuestions = sectionQuestions.where((q) => !q.isOptional).length;
    final optionalQuestions = sectionQuestions.where((q) => q.isOptional).length;
    final totalQuestions = sectionQuestions.length;

    final progress = (mandatoryQuestions / requiredQuestions).clamp(0.0, 1.0);

    String progressText;
    if (optionalQuestions > 0) {
      progressText = '$mandatoryQuestions mandatory + $optionalQuestions optional = $totalQuestions total (need $requiredQuestions mandatory)';
    } else {
      progressText = '$mandatoryQuestions / $requiredQuestions questions';
    }

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Section ${currentSectionIndex + 1} of ${widget.sections.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                const Spacer(),
                if (optionalQuestions > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$optionalQuestions Optional',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              sectionName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${currentSection.formattedType} • ${currentSection.marksPerQuestion} marks each',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Text(
              progressText,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress >= 1.0 ? Colors.green : Colors.blue,
                ),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionInput() {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Question Text',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _questionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter your question here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Optional toggle
            InkWell(
              onTap: () => setState(() => isOptionalQuestion = !isOptionalQuestion),
              child: Row(
                children: [
                  Checkbox(
                    value: isOptionalQuestion,
                    onChanged: (value) => setState(() => isOptionalQuestion = value ?? false),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  const Text('Optional question'),
                  const SizedBox(width: 4),
                  const Tooltip(
                    message: 'Students can choose whether to answer this question',
                    child: Icon(Icons.help_outline, size: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsInput() {
    final currentSection = widget.sections[currentSectionIndex];
    if (currentSection.type != 'multiple_choice') return const SizedBox.shrink();

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Text(
                  'Answer Options',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                SizedBox(width: 8),
                Tooltip(
                  message: 'Multiple choice questions cannot have sub-questions',
                  child: Icon(Icons.info_outline, size: 16, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._optionControllers.asMap().entries.map((entry) {
              int index = entry.key;
              TextEditingController controller = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: controller,
                  onChanged: (_) => _validateForm(),
                  decoration: InputDecoration(
                    labelText: 'Option ${String.fromCharCode(65 + index)}',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: Container(
                      margin: const EdgeInsets.all(12),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          String.fromCharCode(65 + index),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSubQuestionsCard() {
    final currentSection = widget.sections[currentSectionIndex];
    if (currentSection.type == 'multiple_choice') return const SizedBox.shrink();

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => showSubQuestions = !showSubQuestions),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    showSubQuestions ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Sub-questions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${currentSubQuestions.length}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Optional',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

          // Expandable content
          if (showSubQuestions) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Add sub-question input
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _subQuestionController,
                          decoration: InputDecoration(
                            hintText: 'e.g., Explain your reasoning',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _subQuestionMarksController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Marks',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _addSubQuestion,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),

                  // Display current sub-questions
                  if (currentSubQuestions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ...currentSubQuestions.asMap().entries.map((entry) {
                      int index = entry.key;
                      SubQuestion subQ = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  String.fromCharCode(97 + index), // a, b, c
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(subQ.text)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${subQ.marks}m',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => _removeSubQuestion(index),
                              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<QuestionPaperBloc, QuestionPaperState>(
      listener: (context, state) {
        if (state is QuestionPaperSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate back after certain actions
          if (state.actionType == 'submit') {
            // Show success message first
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Question paper submitted successfully!'),
                backgroundColor: Colors.green,
              ),
            );

            // Navigate to a more relevant page
            context.go('/home'); // or '/question-papers/my-submissions'
          } else if (state.actionType == 'pull') {
            // Safe way to pop - check if we can pop first
            if (context.canPop()) {
              context.pop();
            } else {
              // Fallback to home if we can't pop
              context.go('/home');
            }
          } else if (state.actionType == 'save') {
            // For draft saves, stay on current page or show confirmation
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Draft saved successfully!')),
            );
          }
        }

        if (state is QuestionPaperError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Dialog(
        child: Container(
          width: 700,
          height: MediaQuery.of(context).size.height * 0.9,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create Questions',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.paperTitle,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        if (widget.selectedSubjects.isNotEmpty)
                          Text(
                            widget.selectedSubjects.map((s) => s.name).join(", "),
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                          ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),

              // Body
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Section progress
                      _buildSectionProgress(),
                      const SizedBox(height: 20),

                      // Form content
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              _buildQuestionInput(),
                              const SizedBox(height: 16),
                              _buildOptionsInput(),
                              if (widget.sections[currentSectionIndex].type != 'multiple_choice') ...[
                                const SizedBox(height: 16),
                                _buildSubQuestionsCard(),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Action buttons
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: (isFormValid && !_isProcessing) ? _addQuestion : null,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Question'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: _isProcessing ? null : () => _clearForm(),
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Clear'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: (_allSectionsComplete() && !_isProcessing) ? _createQuestionPaper : null,
                            icon: _isProcessing
                                ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                                : const Icon(Icons.save, size: 18),
                            label: Text(_isProcessing ? 'Saving...' : 'Save as Draft'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}