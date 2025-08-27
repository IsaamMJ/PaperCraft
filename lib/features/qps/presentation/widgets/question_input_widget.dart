import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:papercraft/features/qps/presentation/widgets/question_paper_preview_widget.dart';
// import 'package:papercraft/features/qps/presentation/widgets/question_paper_preview_widget.dart';
import '../../domain/entities/exam_type_entity.dart';
import '../../domain/entities/grade_entity.dart';
import '../../domain/entities/subject_entity.dart';

// Remove the duplicate ExamSectionEntity class - use the one from domain
// The ExamSectionEntity should only be defined in exam_type_entity.dart

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
  final GradeEntity selectedGrade;
  final Function(Map<String, List<Question>>) onQuestionsSubmitted;

  const QuestionInputDialog({
    super.key,
    required this.sections,
    required this.selectedGrade,
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
  bool showSidebar = true;
  bool isDraftSaved = false;

  // Form controllers
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers =
  List.generate(4, (index) => TextEditingController());
  final TextEditingController _subQuestionController = TextEditingController();
  final TextEditingController _subQuestionMarksController =
  TextEditingController(text: '1');

  // Form state
  List<SubQuestion> currentSubQuestions = [];
  bool isOptionalQuestion = false;
  bool showSubQuestions = false;
  bool isFormValid = false;
  bool showQuestionPreview = false;

  @override
  void initState() {
    super.initState();
    for (var section in widget.sections) {
      allQuestions[section.name] = [];
    }
    _questionController.addListener(_validateForm);
    _setupKeyboardShortcuts();
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

  void _setupKeyboardShortcuts() {
    // Keyboard shortcuts will be handled in the build method with Focus widget
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
        isDraftSaved = false;
      });
    }
  }

  void _saveDraft() {
    // In a real app, this would save to local storage or backend
    setState(() {
      isDraftSaved = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.save, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Draft saved successfully'),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
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
      showQuestionPreview = false;
      isDraftSaved = false;
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
      _subQuestionMarksController.text = '1';
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

  // Check if user can add more questions to current section
  bool _canAddMoreQuestions() {
    final currentSection = widget.sections[currentSectionIndex];
    final sectionName = currentSection.name;
    final sectionQuestions = allQuestions[sectionName]!;
    final requiredQuestions = currentSection.questions;

    // Count mandatory and optional questions
    final mandatoryQuestions = sectionQuestions.where((q) => !q.isOptional).length;
    final optionalQuestions = sectionQuestions.where((q) => q.isOptional).length;

    if (isOptionalQuestion) {
      // For optional questions: can add if we have required mandatory questions + current optional count is less than mandatory count
      return mandatoryQuestions >= requiredQuestions && optionalQuestions < mandatoryQuestions;
    } else {
      // For mandatory questions: can add if we haven't reached the required limit
      return mandatoryQuestions < requiredQuestions;
    }
  }

  void _addQuestion() {
    if (!isFormValid || !_canAddMoreQuestions()) return;

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
      isDraftSaved = false;
    });

    _clearForm();
    _showSuccessMessage(sectionName);
    _checkSectionCompletion();
  }

  void _showSuccessMessage(String sectionName) {
    final currentSection = widget.sections[currentSectionIndex];
    final sectionQuestions = allQuestions[sectionName]!;
    final mandatoryCount = sectionQuestions.where((q) => !q.isOptional).length;
    final optionalCount = sectionQuestions.where((q) => q.isOptional).length;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Question added to $sectionName (${mandatoryCount}/${currentSection.questions} mandatory, $optionalCount optional)'),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _checkSectionCompletion() {
    final currentSection = widget.sections[currentSectionIndex];
    final sectionName = currentSection.name;
    final sectionQuestions = allQuestions[sectionName]!;
    final requiredQuestions = currentSection.questions;

    // Count mandatory questions
    final mandatoryQuestions = sectionQuestions.where((q) => !q.isOptional).length;

    // Section is complete when we have enough mandatory questions to meet the base requirement
    bool sectionComplete = mandatoryQuestions >= requiredQuestions;

    if (sectionComplete && currentSectionIndex < widget.sections.length - 1) {
      // Don't auto-advance immediately, give user a choice
      _showSectionCompletedDialog(sectionName);
    }
  }

  void _showSectionCompletedDialog(String completedSection) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(Icons.check_circle, color: Colors.green, size: 32),
        title: Text('Section Complete!'),
        content: Text('$completedSection has enough mandatory questions. You can add more optional questions or move to the next section.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Continue Here'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                currentSectionIndex++;
              });
            },
            child: Text('Next Section'),
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

  void _goToSection(int index) {
    setState(() {
      currentSectionIndex = index;
      _clearForm();
    });
  }

  Widget _buildSidebar() {
    if (!showSidebar) return SizedBox.shrink();

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          // Sidebar header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Icon(Icons.quiz, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sections Overview',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => showSidebar = false),
                  icon: Icon(Icons.chevron_left, size: 20),
                  constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),

          // Sections list
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(8),
              itemCount: widget.sections.length,
              itemBuilder: (context, index) {
                final section = widget.sections[index];
                final sectionQuestions = allQuestions[section.name]!;
                final mandatoryCount = sectionQuestions.where((q) => !q.isOptional).length;
                final optionalCount = sectionQuestions.where((q) => q.isOptional).length;
                final isComplete = mandatoryCount >= section.questions;
                final isCurrent = index == currentSectionIndex;

                return Container(
                  margin: EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: isCurrent ? Colors.blue.shade50 : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => _goToSection(index),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isCurrent ? Colors.blue.shade200 : Colors.grey.shade200,
                            width: isCurrent ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: isComplete ? Colors.green : (isCurrent ? Colors.blue : Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: isComplete
                                        ? Icon(Icons.check, color: Colors.white, size: 12)
                                        : Text('${index + 1}', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    section.name,
                                    style: TextStyle(
                                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 6),
                            Text(
                              '${section.formattedType} • ${section.marksPerQuestion}m each',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: mandatoryCount >= section.questions ? Colors.green.shade100 : Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '$mandatoryCount/${section.questions}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: mandatoryCount >= section.questions ? Colors.green.shade700 : Colors.orange.shade700,
                                    ),
                                  ),
                                ),
                                if (optionalCount > 0) ...[
                                  SizedBox(width: 4),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '+$optionalCount',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
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

    // Check limits for adding questions
    final canAddMandatory = mandatoryQuestions < requiredQuestions;
    final canAddOptional = mandatoryQuestions >= requiredQuestions && optionalQuestions < mandatoryQuestions;

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
                if (!showSidebar)
                  IconButton(
                    onPressed: () => setState(() => showSidebar = true),
                    icon: Icon(Icons.menu, size: 20),
                    constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
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

            // Question limits info
            if (!canAddMandatory && !canAddOptional) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade700, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Section complete! Maximum questions reached.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.amber.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (isOptionalQuestion && !canAddOptional) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        canAddMandatory
                            ? 'Complete mandatory questions first to add optional ones.'
                            : 'Maximum optional questions reached (can\'t exceed mandatory count).',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

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
            Row(
              children: [
                Text(
                  'Question Text',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Spacer(),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: showQuestionPreview ? null : () => setState(() => showQuestionPreview = !showQuestionPreview),
                      icon: Icon(Icons.preview, size: 16),
                      label: Text('Preview'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                    SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _saveDraft,
                      icon: Icon(isDraftSaved ? Icons.check : Icons.save, size: 16),
                      label: Text(isDraftSaved ? 'Saved' : 'Save Draft'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                  ],
                ),
              ],
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

            // Optional toggle with enhanced info
            InkWell(
              onTap: _canAddMoreQuestions() ? () => setState(() => isOptionalQuestion = !isOptionalQuestion) : null,
              child: Row(
                children: [
                  Checkbox(
                    value: isOptionalQuestion,
                    onChanged: _canAddMoreQuestions() ? (value) => setState(() => isOptionalQuestion = value ?? false) : null,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  Text(
                    'Optional question',
                    style: TextStyle(
                      color: _canAddMoreQuestions() ? null : Colors.grey,
                    ),
                  ),
                  SizedBox(width: 4),
                  Tooltip(
                    message: 'Students can choose whether to answer this question. You can add optional questions equal to your mandatory count.',
                    child: Icon(Icons.help_outline, size: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),

            // Question preview
            if (showQuestionPreview && _questionController.text.isNotEmpty) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.preview, color: Colors.blue.shade700, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Student View Preview',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                            fontSize: 12,
                          ),
                        ),
                        Spacer(),
                        IconButton(
                          onPressed: () => setState(() => showQuestionPreview = false),
                          icon: Icon(Icons.close, size: 16),
                          constraints: BoxConstraints(minWidth: 24, minHeight: 24),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      _questionController.text,
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
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
                          onSubmitted: (_) => _addSubQuestion(),
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
                          onSubmitted: (_) => _addSubQuestion(),
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

  void _navigateToPreview() {
    // Close the current dialog first
    Navigator.of(context).pop();

    // Navigate to preview using the extension method
    QuestionInputDialogExtension.navigateToPreview(
      context: context,
      examType: widget.examType,
      questions: allQuestions,
      selectedSubjects: widget.selectedSubjects,
    );
  }

  Widget _buildKeyboardShortcuts() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Keyboard Shortcuts',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          SizedBox(height: 4),
          Text(
            'Ctrl+S: Save Draft • Ctrl+Enter: Add Question • Ctrl+R: Clear Form',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKey: (node, event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.keyS &&
              event.isControlPressed) {
            _saveDraft();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.enter &&
              event.isControlPressed) {
            if (isFormValid && _canAddMoreQuestions()) {
              _addQuestion();
              return KeyEventResult.handled;
            }
          }
          if (event.logicalKey == LogicalKeyboardKey.keyR &&
              event.isControlPressed) {
            _clearForm();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Dialog(
        child: Container(
          width: 900,
          height: MediaQuery
              .of(context)
              .size
              .height * 0.95,
          child: Row(
            children: [
              // Sidebar
              _buildSidebar(),

              // Main content
              Expanded(
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(bottom: BorderSide(color: Colors.grey
                            .shade200)),
                      ),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create Questions',
                                style: Theme
                                    .of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (widget.selectedSubjects.isNotEmpty)
                                Text(
                                  '${widget.selectedGrade
                                      .displayName} • ${widget.selectedSubjects
                                      .map((s) => s.name).join(", ")}',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                            ],
                          ),
                          Spacer(),
                          if (!isDraftSaved)
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Unsaved changes',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          SizedBox(width: 12),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.grey.shade100,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
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
                                    if (widget.sections[currentSectionIndex]
                                        .type == 'multiple_choice')
                                      SizedBox(height: 16),
                                    _buildSubQuestionsCard(),
                                    SizedBox(height: 16),
                                    _buildKeyboardShortcuts(),
                                  ],
                                ),
                              ),
                            ),

                            SizedBox(height: 20),

                            // Action buttons
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: (isFormValid &&
                                      _canAddMoreQuestions())
                                      ? _addQuestion
                                      : null,
                                  icon: Icon(Icons.add, size: 18),
                                  label: Text('Add Question'),
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: Colors.grey
                                        .shade300,
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
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                // Navigation buttons
                                if (currentSectionIndex > 0)
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _goToSection(currentSectionIndex - 1),
                                    icon: Icon(Icons.arrow_back, size: 18),
                                    label: Text('Previous'),
                                    style: OutlinedButton.styleFrom(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                if (currentSectionIndex <
                                    widget.sections.length - 1 &&
                                    allQuestions[widget
                                        .sections[currentSectionIndex].name]!
                                        .where((q) => !q.isOptional).length >=
                                        widget.sections[currentSectionIndex]
                                            .questions)
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _goToSection(currentSectionIndex + 1),
                                    icon: Icon(Icons.arrow_forward, size: 18),
                                    label: Text('Next'),
                                    style: OutlinedButton.styleFrom(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                Spacer(),
                                ElevatedButton.icon(
                                  onPressed: _allSectionsComplete()
                                      ? _navigateToPreview
                                      : null,
                                  icon: Icon(Icons.preview, size: 18),
                                  label: Text('Preview Paper'),
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: Colors.grey
                                        .shade300,
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
            ],
          ),
        ),
      ),
    );
  }
  }