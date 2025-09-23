import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/routes/app_routes.dart';
import '../../domain/entities/exam_type_entity.dart';
import '../../domain/entities/paper_status.dart';
import '../../domain/entities/subject_entity.dart';
import '../../domain/entities/question_entity.dart';
import '../../domain/entities/question_paper_entity.dart';
import '../bloc/question_paper_bloc.dart';

class QuestionInputDialog extends StatefulWidget {
  final List<ExamSectionEntity> sections;
  final ExamTypeEntity examType;
  final List<SubjectEntity> selectedSubjects;
  final String paperTitle;
  final int gradeLevel;
  final List<String> selectedSections;
  final Function(QuestionPaperEntity) onPaperCreated;

  // NEW: Edit mode parameters
  final Map<String, List<Question>>? existingQuestions;
  final bool isEditing;
  final String? existingPaperId;

  const QuestionInputDialog({
    super.key,
    required this.sections,
    required this.examType,
    required this.selectedSubjects,
    required this.paperTitle,
    required this.gradeLevel,
    required this.selectedSections,
    required this.onPaperCreated,
    this.existingQuestions,
    this.isEditing = false,
    this.existingPaperId,
  });

  @override
  State<QuestionInputDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<QuestionInputDialog> {
  final _questionController = TextEditingController();
  final _subQuestionController = TextEditingController();
  final _optionControllers = List.generate(4, (_) => TextEditingController());

  int _currentSection = 0;
  Map<String, List<Question>> _allQuestions = {};
  List<SubQuestion> _subQuestions = [];
  bool _isOptional = false, _showSubQuestions = false, _isProcessing = false;

  @override
  void initState() {
    super.initState();

    // Initialize questions - use existing ones if in edit mode
    for (var section in widget.sections) {
      if (widget.existingQuestions != null && widget.existingQuestions!.containsKey(section.name)) {
        _allQuestions[section.name] = List.from(widget.existingQuestions![section.name]!);
      } else {
        _allQuestions[section.name] = [];
      }
    }

    // Add listeners to trigger validation on any input change
    _questionController.addListener(() => setState(() {}));
    for (var controller in _optionControllers) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _subQuestionController.dispose();
    for (var controller in _optionControllers) controller.dispose();
    super.dispose();
  }

  bool get _isValid {
    if (_questionController.text.trim().isEmpty) return false;
    final section = widget.sections[_currentSection];
    if (section.type == 'multiple_choice') {
      return _optionControllers.where((c) => c.text.trim().isNotEmpty).length >= 2;
    }
    return true;
  }

  void _clear() {
    _questionController.clear();
    _subQuestionController.clear();
    for (var controller in _optionControllers) controller.clear();
    setState(() {
      _subQuestions.clear();
      _isOptional = _showSubQuestions = false;
    });
  }

  void _addSubQuestion() {
    if (_subQuestionController.text.trim().isEmpty) return;
    setState(() {
      _subQuestions.add(SubQuestion(text: _subQuestionController.text.trim(), marks: 1));
      _subQuestionController.clear();
    });
  }

  void _addQuestion() {
    if (!_isValid) return;

    final section = widget.sections[_currentSection];
    List<String>? options;

    if (section.type == 'multiple_choice') {
      options = _optionControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
      _subQuestions.clear();
    }

    final question = Question(
      text: _questionController.text.trim(),
      type: section.type,
      options: options,
      correctAnswer: null,
      marks: section.marksPerQuestion,
      subQuestions: List.from(_subQuestions),
      isOptional: _isOptional,
    );

    setState(() => _allQuestions[section.name]!.add(question));
    _clear();
    _showMessage('Question added', AppColors.success);
    _checkCompletion();
  }

  void _removeQuestion(String sectionName, int index) {
    setState(() {
      _allQuestions[sectionName]!.removeAt(index);
    });
    _showMessage('Question removed', AppColors.warning);
  }

  void _editQuestion(String sectionName, int index) {
    final question = _allQuestions[sectionName]![index];

    setState(() {
      _questionController.text = question.text;
      _isOptional = question.isOptional;
      _subQuestions = List.from(question.subQuestions);

      if (question.options != null) {
        for (int i = 0; i < _optionControllers.length && i < question.options!.length; i++) {
          _optionControllers[i].text = question.options![i];
        }
      }
    });

    // Remove the question so it can be re-added with changes
    _removeQuestion(sectionName, index);
  }

  void _checkCompletion() {
    final section = widget.sections[_currentSection];
    final questions = _allQuestions[section.name]!;
    final mandatory = questions.where((q) => !q.isOptional).length;

    if (mandatory >= section.questions && _currentSection < widget.sections.length - 1) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _currentSection++);
      });
    }
  }

  bool _allComplete() {
    for (var section in widget.sections) {
      final questions = _allQuestions[section.name]!;
      final mandatory = questions.where((q) => !q.isOptional).length;
      if (mandatory < section.questions) return false;
    }
    return true;
  }

  void _createPaper() {
    if (_isProcessing || !_allComplete()) return;
    setState(() => _isProcessing = true);

    try {
      final paper = widget.isEditing && widget.existingPaperId != null
          ? QuestionPaperEntity(
        id: widget.existingPaperId!,
        title: widget.paperTitle,
        subject: widget.selectedSubjects.map((s) => s.name).join(', '),
        examType: widget.examType.name,
        createdBy: 'current_user',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)), // Preserve original
        modifiedAt: DateTime.now(),
        status: widget.isEditing ? PaperStatus.draft : PaperStatus.draft,
        examTypeEntity: widget.examType,
        gradeLevel: widget.gradeLevel,
        selectedSections: widget.selectedSections,
        questions: _allQuestions,
      )
          : QuestionPaperEntity.createDraft(
        title: widget.paperTitle,
        subject: widget.selectedSubjects.map((s) => s.name).join(', '),
        examType: widget.examType.name,
        createdBy: 'current_user',
        examTypeEntity: widget.examType,
        gradeLevel: widget.gradeLevel,
        selectedSections: widget.selectedSections,
        questions: _allQuestions,
      );

      context.read<QuestionPaperBloc>().add(SaveDraft(paper));
    } catch (e) {
      setState(() => _isProcessing = false);
      _showMessage('Error: $e', AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return BlocListener<QuestionPaperBloc, QuestionPaperState>(
      listener: (context, state) {
        if (state is QuestionPaperSuccess) {
          _showMessage(state.message, AppColors.success);
          if (state.actionType == 'save') {
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) context.go(AppRoutes.home);
            });
          }
        }
        if (state is QuestionPaperError) {
          setState(() => _isProcessing = false);
          _showMessage(state.message, AppColors.error);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          margin: EdgeInsets.only(top: isMobile ? 40 : 60),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(isMobile ? 20 : 12)),
          ),
          child: Column(
            children: [
              _buildHeader(isMobile),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 20 : 24),
                  child: Column(
                    children: [
                      _buildProgress(),
                      SizedBox(height: isMobile ? 24 : 20),
                      _buildExistingQuestions(isMobile),
                      SizedBox(height: isMobile ? 20 : 16),
                      _buildQuestionInput(isMobile),
                      SizedBox(height: isMobile ? 20 : 16),
                      _buildOptionsOrSubQuestions(isMobile),
                      SizedBox(height: isMobile ? 32 : 20),
                    ],
                  ),
                ),
              ),
              _buildActions(isMobile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    final section = widget.sections[_currentSection];
    return Container(
      padding: EdgeInsets.fromLTRB(20, isMobile ? 16 : 20, 16, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isEditing ? 'Edit ${section.name}' : section.name,
                  style: TextStyle(
                    fontSize: isMobile ? 20 : 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${section.formattedType} • ${section.marksPerQuestion} marks',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isProcessing ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            iconSize: isMobile ? 28 : 24,
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey.shade100,
              minimumSize: Size(isMobile ? 48 : 40, isMobile ? 48 : 40),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    final section = widget.sections[_currentSection];
    final questions = _allQuestions[section.name]!;
    final mandatory = questions.where((q) => !q.isOptional).length;
    final progress = (mandatory / section.questions).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Section ${_currentSection + 1} of ${widget.sections.length}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
              Text(
                '$mandatory/${section.questions} questions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation(
              progress >= 1.0 ? AppColors.success : AppColors.primary,
            ),
            minHeight: 6,
          ),
        ],
      ),
    );
  }

  Widget _buildExistingQuestions(bool isMobile) {
    final section = widget.sections[_currentSection];
    final questions = _allQuestions[section.name]!;

    if (questions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Existing Questions (${questions.length})',
          style: TextStyle(
            fontSize: isMobile ? 18 : 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          constraints: BoxConstraints(maxHeight: isMobile ? 200 : 150),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: questions.length,
            itemBuilder: (context, index) {
              final question = questions[index];
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
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        question.text,
                        style: TextStyle(fontSize: isMobile ? 14 : 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (question.isOptional)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Optional',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.warning,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _editQuestion(section.name, index),
                          icon: const Icon(Icons.edit, size: 16),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            minimumSize: const Size(28, 28),
                          ),
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: () => _removeQuestion(section.name, index),
                          icon: const Icon(Icons.delete_outline, size: 16),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.error.withOpacity(0.1),
                            minimumSize: const Size(28, 28),
                          ),
                          color: AppColors.error,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionInput(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add New Question',
          style: TextStyle(
            fontSize: isMobile ? 18 : 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _questionController,
          maxLines: isMobile ? 4 : 3,
          style: TextStyle(fontSize: isMobile ? 16 : 14),
          decoration: InputDecoration(
            hintText: 'Enter your question here...',
            hintStyle: TextStyle(fontSize: isMobile ? 16 : 14),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: EdgeInsets.all(isMobile ? 16 : 12),
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => setState(() => _isOptional = !_isOptional),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Checkbox(
                  value: _isOptional,
                  onChanged: (v) => setState(() => _isOptional = v ?? false),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                Text(
                  'Optional question',
                  style: TextStyle(fontSize: isMobile ? 16 : 14),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsOrSubQuestions(bool isMobile) {
    final section = widget.sections[_currentSection];
    return section.type == 'multiple_choice'
        ? _buildOptions(isMobile)
        : _buildSubQuestions(isMobile);
  }

  Widget _buildOptions(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Options',
          style: TextStyle(
            fontSize: isMobile ? 18 : 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ..._optionControllers.asMap().entries.map((e) {
          final label = String.fromCharCode(65 + e.key);
          return Padding(
            padding: EdgeInsets.only(bottom: isMobile ? 16 : 12),
            child: TextField(
              controller: e.value,
              style: TextStyle(fontSize: isMobile ? 16 : 14),
              decoration: InputDecoration(
                labelText: 'Option $label',
                labelStyle: TextStyle(fontSize: isMobile ? 16 : 14),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
                contentPadding: EdgeInsets.all(isMobile ? 16 : 12),
                prefixIcon: Container(
                  margin: EdgeInsets.all(isMobile ? 14 : 12),
                  width: isMobile ? 28 : 24,
                  height: isMobile ? 28 : 24,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 14 : 12,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSubQuestions(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _showSubQuestions = !_showSubQuestions),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  _showSubQuestions ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.textSecondary,
                  size: isMobile ? 28 : 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Sub-questions',
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                if (_subQuestions.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_subQuestions.length}',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_showSubQuestions) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _subQuestionController,
            style: TextStyle(fontSize: isMobile ? 16 : 14),
            decoration: InputDecoration(
              hintText: 'Enter sub-question',
              hintStyle: TextStyle(fontSize: isMobile ? 16 : 14),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
              contentPadding: EdgeInsets.all(isMobile ? 16 : 12),
              suffixIcon: IconButton(
                onPressed: _addSubQuestion,
                icon: const Icon(Icons.add),
                iconSize: isMobile ? 28 : 24,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: Size(isMobile ? 44 : 40, isMobile ? 44 : 40),
                ),
              ),
            ),
          ),
          if (_subQuestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._subQuestions.asMap().entries.map((e) {
              final label = String.fromCharCode(97 + e.key);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(isMobile ? 16 : 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: isMobile ? 28 : 24,
                      height: isMobile ? 28 : 24,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: isMobile ? 14 : 12,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        e.value.text,
                        style: TextStyle(fontSize: isMobile ? 16 : 14),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _subQuestions.removeAt(e.key)),
                      icon: const Icon(Icons.delete_outline),
                      iconSize: isMobile ? 24 : 20,
                      color: AppColors.error,
                      style: IconButton.styleFrom(
                        minimumSize: Size(isMobile ? 44 : 36, isMobile ? 44 : 36),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ],
    );
  }

  Widget _buildActions(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isValid && !_isProcessing ? _addQuestion : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: isMobile ? 16 : 12,
                      ),
                      minimumSize: Size(0, isMobile ? 52 : 44),
                      textStyle: TextStyle(
                        fontSize: isMobile ? 16 : 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Add Question'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _isProcessing ? null : _clear,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      vertical: isMobile ? 16 : 12,
                      horizontal: isMobile ? 20 : 16,
                    ),
                    minimumSize: Size(0, isMobile ? 52 : 44),
                    textStyle: TextStyle(
                      fontSize: isMobile ? 16 : 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  child: const Text('Clear'),
                ),
              ],
            ),
            if (_allComplete()) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: !_isProcessing ? _createPaper : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: isMobile ? 16 : 12,
                    ),
                    minimumSize: Size(0, isMobile ? 52 : 44),
                    textStyle: TextStyle(
                      fontSize: isMobile ? 16 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: _isProcessing
                      ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(widget.isEditing ? 'Updating...' : 'Saving...'),
                    ],
                  )
                      : Text(widget.isEditing ? 'Update Paper' : 'Save as Draft'),
                ),
              ),
            ],
            // NEW: Navigation between sections
            if (widget.sections.length > 1) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (_currentSection > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _currentSection--),
                        child: const Text('Previous Section'),
                      ),
                    ),
                  if (_currentSection > 0 && _currentSection < widget.sections.length - 1)
                    const SizedBox(width: 12),
                  if (_currentSection < widget.sections.length - 1)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _currentSection++),
                        child: const Text('Next Section'),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showMessage(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}