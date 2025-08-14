import 'package:flutter/material.dart';
import 'package:papercraft/features/qps/presentation/widgets/question_paper_preview_widget.dart';
import '../../domain/entities/exam_type_entity.dart';
import '../../domain/entities/subject_entity.dart';

class SubQuestion {
  final String text;
  final int marks;

  SubQuestion({
    required this.text,
    required this.marks,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'marks': marks,
    };
  }

  factory SubQuestion.fromJson(Map<String, dynamic> json) {
    return SubQuestion(
      text: json['text'],
      marks: json['marks'],
    );
  }
}

class Question {
  final String text;
  final String type;
  final List<String>? options;
  final String? correctAnswer;
  final int marks;
  final List<SubQuestion> subQuestions;
  final bool isOptional;

  Question({
    required this.text,
    required this.type,
    this.options,
    this.correctAnswer,
    required this.marks,
    this.subQuestions = const [],
    this.isOptional = false,
  });

  int get totalMarks {
    if (subQuestions.isEmpty) return marks;
    return marks + subQuestions.fold(0, (sum, sub) => sum + sub.marks);
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'type': type,
      'options': options,
      'correct_answer': correctAnswer,
      'marks': marks,
      'sub_questions': subQuestions.map((sq) => sq.toJson()).toList(),
      'is_optional': isOptional,
    };
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      text: json['text'],
      type: json['type'],
      options: json['options'] != null
          ? List<String>.from(json['options'])
          : null,
      correctAnswer: json['correct_answer'],
      marks: json['marks'],
      subQuestions: json['sub_questions'] != null
          ? (json['sub_questions'] as List)
          .map((sq) => SubQuestion.fromJson(sq))
          .toList()
          : [],
      isOptional: json['is_optional'] ?? false,
    );
  }
}

class QuestionInputDialog extends StatefulWidget {
  final List<ExamSectionEntity> sections;
  final ExamTypeEntity examType;
  final List<SubjectEntity> selectedSubjects;
  final Function(Map<String, List<Question>>) onQuestionsSubmitted;

  const QuestionInputDialog({
    super.key,
    required this.sections,
    required this.examType,
    required this.selectedSubjects,
    required this.onQuestionsSubmitted,
  });

  @override
  State<QuestionInputDialog> createState() => _QuestionInputDialogState();
}

class _QuestionInputDialogState extends State<QuestionInputDialog> {
  int currentSectionIndex = 0;
  Map<String, List<Question>> allQuestions = {};

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
    for (var section in widget.sections) {
      allQuestions[section.name] = [];
    }
    _questionController.addListener(_validateForm);
  }

  @override
  void dispose() {
    _questionController.removeListener(_validateForm);
    _questionController.dispose();
    _subQuestionController.dispose();
    _subQuestionMarksController.dispose();
    for (var controller in _optionControllers) {
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
    _subQuestionMarksController.clear();
    for (var controller in _optionControllers) {
      controller.clear();
    }
    setState(() {
      currentSubQuestions.clear();
      isOptionalQuestion = false;
      showSubQuestions = false;
    });
  }

  void _addSubQuestion() {
    if (_subQuestionController.text.trim().isEmpty) return;

    int marks = int.tryParse(_subQuestionMarksController.text.trim()) ?? 1;

    setState(() {
      currentSubQuestions.add(SubQuestion(
        text: _subQuestionController.text.trim(),
        marks: marks,
      ));
      _subQuestionController.clear();
      _subQuestionMarksController.text = '1'; // Default for next
    });
  }

  void _removeSubQuestion(int index) {
    setState(() {
      currentSubQuestions.removeAt(index);
      if (currentSubQuestions.isEmpty) {
        showSubQuestions = false;
      }
    });
  }

  void _addQuestion() {
    if (!isFormValid) return;

    final currentSection = widget.sections[currentSectionIndex];
    final sectionName = currentSection.name;
    final questionType = currentSection.type;
    final marksPerQuestion = currentSection.marksPerQuestion;

    List<String>? options;
    if (questionType == 'multiple_choice') {
      options = _optionControllers
          .map((controller) => controller.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();
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

    setState(() {
      allQuestions[sectionName]!.add(question);
    });

    _clearForm();
    _showSuccessMessage(sectionName);
    _checkSectionCompletion();
  }

  void _showSuccessMessage(String sectionName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Question added to $sectionName'),
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

    // Count mandatory and optional questions
    final mandatoryQuestions = sectionQuestions.where((q) => !q.isOptional).length;
    final totalQuestions = sectionQuestions.length;

    // Section is complete when we have enough mandatory questions to meet the base requirement
    bool sectionComplete = mandatoryQuestions >= requiredQuestions;

    if (sectionComplete) {
      if (currentSectionIndex < widget.sections.length - 1) {
        Future.delayed(const Duration(milliseconds: 500), () {
          setState(() {
            currentSectionIndex++;
          });
          _showSectionCompletedDialog(sectionName);
        });
      }
    }
  }

  void _showSectionCompletedDialog(String completedSection) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(Icons.check_circle, color: Colors.green, size: 32),
        title: Text('Section Complete!'),
        content: Text('$completedSection is done. Moving to the next section.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Continue'),
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

      // Check if we have enough mandatory questions for this section
      final mandatoryQuestions = sectionQuestions.where((q) => !q.isOptional).length;
      if (mandatoryQuestions < requiredQuestions) {
        return false;
      }
    }
    return true;
  }

  Widget _buildSectionProgress() {
    final currentSection = widget.sections[currentSectionIndex];
    final sectionName = currentSection.name;
    final sectionQuestions = allQuestions[sectionName]!;
    final requiredQuestions = currentSection.questions;

    // Count mandatory and optional questions
    final mandatoryQuestions = sectionQuestions.where((q) => !q.isOptional).length;
    final optionalQuestions = sectionQuestions.where((q) => q.isOptional).length;
    final totalQuestions = sectionQuestions.length;

    // Calculate progress based on mandatory questions only
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
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                Spacer(),
                if (optionalQuestions > 0)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
            SizedBox(height: 12),
            Text(
              sectionName,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              '${currentSection.formattedType} • ${currentSection.marksPerQuestion} marks each',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            SizedBox(height: 4),
            Text(
              progressText,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 12),
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
            Text(
              'Question Text',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
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
                  borderSide: BorderSide(color: Colors.blue, width: 2),
                ),
              ),
            ),
            SizedBox(height: 16),

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
                  Text('Optional question'),
                  SizedBox(width: 4),
                  Tooltip(
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
    if (currentSection.type != 'multiple_choice') return SizedBox.shrink();

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Answer Options',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            ..._optionControllers.asMap().entries.map((entry) {
              int index = entry.key;
              TextEditingController controller = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: controller,
                  onChanged: (_) => _validateForm(),
                  decoration: InputDecoration(
                    labelText: 'Option ${String.fromCharCode(65 + index)}', // A, B, C, D
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: Container(
                      margin: EdgeInsets.all(12),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          String.fromCharCode(65 + index),
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
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
                  SizedBox(width: 8),
                  Text(
                    'Sub-questions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${currentSubQuestions.length}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Spacer(),
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
            Divider(height: 1),
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
                            hintText: 'e.g., Why is the woman crying?',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _subQuestionMarksController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Marks',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _addSubQuestion,
                        icon: Icon(Icons.add, size: 16),
                        label: Text('Add'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),

                  // Display current sub-questions
                  if (currentSubQuestions.isNotEmpty) ...[
                    SizedBox(height: 16),
                    ...currentSubQuestions.asMap().entries.map((entry) {
                      int index = entry.key;
                      SubQuestion subQ = entry.value;
                      return Container(
                        margin: EdgeInsets.only(bottom: 8),
                        padding: EdgeInsets.all(12),
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
                            SizedBox(width: 12),
                            Expanded(child: Text(subQ.text)),
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                            SizedBox(width: 8),
                            IconButton(
                              onPressed: () => _removeSubQuestion(index),
                              icon: Icon(Icons.delete_outline, size: 16, color: Colors.red),
                              constraints: BoxConstraints(minWidth: 32, minHeight: 32),
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
    return Dialog(
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
                      if (widget.selectedSubjects.isNotEmpty)
                        Text(
                          widget.selectedSubjects.map((s) => s.name).join(", "),
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                  Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
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
                    SizedBox(height: 20),

                    // Form content
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildQuestionInput(),
                            SizedBox(height: 16),
                            _buildOptionsInput(),
                            if (widget.sections[currentSectionIndex].type == 'multiple_choice')
                              SizedBox(height: 16),
                            _buildSubQuestionsCard(),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 20),

                    // Action buttons
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: isFormValid ? _addQuestion : null,
                          icon: Icon(Icons.add, size: 18),
                          label: Text('Add Question'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade300,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () => _clearForm(),
                          icon: Icon(Icons.refresh, size: 18),
                          label: Text('Clear'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        Spacer(),
                        ElevatedButton.icon(
                          onPressed: _allSectionsComplete()
                              ? () {
                            widget.onQuestionsSubmitted(allQuestions);
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => QuestionPaperPreview(
                                  examType: widget.examType,
                                  questions: allQuestions,
                                  selectedSubjects: widget.selectedSubjects,
                                ),
                              ),
                            );
                          }
                              : null,
                          icon: Icon(Icons.preview, size: 18),
                          label: Text('Preview Paper'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
    );
  }
}