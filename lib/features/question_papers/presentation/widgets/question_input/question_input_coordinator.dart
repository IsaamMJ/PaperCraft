// features/question_papers/presentation/widgets/question_input/question_input_coordinator.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:papercraft/features/question_papers/presentation/widgets/question_input/question_list_widget.dart';
import 'package:papercraft/features/question_papers/presentation/widgets/question_input/section_progress_widget.dart';
import '../../../../../core/presentation/constants/app_colors.dart';
import '../../../../../core/presentation/routes/app_routes.dart';
import '../../../domain/entities/exam_type_entity.dart';
import '../../../domain/entities/paper_status.dart';
import '../../../domain/entities/subject_entity.dart';
import '../../../domain/entities/question_entity.dart';
import '../../../domain/entities/question_paper_entity.dart';
import '../../../domain/services/paper_validation_service.dart';
import '../../bloc/question_paper_bloc.dart';
import 'bulk_input_widget.dart';
import 'essay_input_widget.dart';
import 'fill_blanks_input_widget.dart';
import 'matching_input_widget.dart';
import 'mcq_input_widget.dart';

class QuestionInputCoordinator extends StatefulWidget {
  final List<ExamSectionEntity> sections;
  final ExamTypeEntity examType;
  final List<SubjectEntity> selectedSubjects;
  final String paperTitle;
  final int gradeLevel;
  final List<String> selectedSections;
  final Function(QuestionPaperEntity) onPaperCreated;
  final DateTime? examDate;

  final bool isAdmin; // ADD THIS

  // Edit mode parameters
  final Map<String, List<Question>>? existingQuestions;
  final bool isEditing;
  final String? existingPaperId;

  const QuestionInputCoordinator({
    super.key,
    required this.sections,
    required this.examType,
    required this.selectedSubjects,
    required this.paperTitle,
    required this.gradeLevel,
    required this.selectedSections,

    required this.isAdmin, // ADD THIS
    required this.onPaperCreated,
    this.existingQuestions,
    this.isEditing = false,
    this.existingPaperId,
    this.examDate,
  });

  @override
  State<QuestionInputCoordinator> createState() => _QuestionInputCoordinatorState();
}

class _QuestionInputCoordinatorState extends State<QuestionInputCoordinator> {
  int _currentSectionIndex = 0;
  Map<String, List<Question>> _allQuestions = {};
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeQuestions();
  }

  void _initializeQuestions() {
    for (var section in widget.sections) {
      if (widget.existingQuestions != null && widget.existingQuestions!.containsKey(section.name)) {
        _allQuestions[section.name] = List.from(widget.existingQuestions![section.name]!);
      } else {
        _allQuestions[section.name] = [];
      }
    }
  }

  ExamSectionEntity get _currentSection => widget.sections[_currentSectionIndex];
  List<Question> get _currentSectionQuestions => _allQuestions[_currentSection.name] ?? [];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return BlocListener<QuestionPaperBloc, QuestionPaperState>(
      listener: _handleBlocState,
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
                      SectionProgressWidget(
                        currentSection: _currentSectionIndex,
                        sections: widget.sections,
                        allQuestions: _allQuestions,
                      ),
                      SizedBox(height: isMobile ? 24 : 20),
                      QuestionListWidget(
                        sectionName: _currentSection.name,
                        questions: _currentSectionQuestions,
                        onEditQuestion: _editQuestion,
                        onRemoveQuestion: _removeQuestion,
                        isMobile: isMobile,
                      ),
                      SizedBox(height: isMobile ? 20 : 16),
                      _buildQuestionInput(isMobile),
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
    final currentMarks = _getCurrentMarks();
    final totalMarks = widget.examType.calculatedTotalMarks;

    return Container(
      padding: EdgeInsets.fromLTRB(20, isMobile ? 16 : 20, 16, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          // Paper title + marks counter
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.paperTitle,
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: currentMarks == totalMarks
                      ? AppColors.success.withOpacity(0.1)
                      : AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$currentMarks/$totalMarks marks',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: currentMarks == totalMarks ? AppColors.success : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _isProcessing ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          // Current section info
          Row(
            children: [
              Text(
                'Section ${_currentSectionIndex + 1}: ${_currentSection.name}',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _getCurrentMarks() {
    int total = 0;
    for (var section in widget.sections) {
      final questions = _allQuestions[section.name] ?? [];
      for (var question in questions) {
        total += question.marks;
      }
    }
    return total;
  }

  Widget _buildQuestionInput(bool isMobile) {
    switch (_currentSection.type) {
      case 'multiple_choice':
        return McqInputWidget(
          onQuestionAdded: _addQuestion,
          isMobile: isMobile,
          isAdmin: widget.isAdmin,
        );

      case 'fill_in_blanks':
        return FillBlanksInputWidget(
          onQuestionAdded: _addQuestion,
          isMobile: isMobile,
          isAdmin: widget.isAdmin,
        );

      case 'match_following':
      // UPDATED: Pass requiredPairs parameter for matching questions
        return MatchingInputWidget(
          onQuestionAdded: _addQuestion,
          isMobile: isMobile,
          requiredPairs: _currentSection.marksPerQuestion, // This is the number of pairs needed

          isAdmin: widget.isAdmin,
        );

    // USE BULK INPUT for these simple question types:
      case 'missing_letters':
      case 'true_false':
      case 'short_answers':
        return BulkInputWidget(
          questionType: _currentSection.type,
          questionCount: _currentSection.questions,
          onQuestionsAdded: _addMultipleQuestions, // Different callback
          isMobile: isMobile,

          isAdmin: widget.isAdmin,
        );

    // Keep single input for other types:
      case 'meanings':
      case 'opposites':
      case 'frame_sentences':
      case 'misc_grammar':
      case 'long_answers':
      default:
        return EssayInputWidget(
          onQuestionAdded: _addQuestion,
          isMobile: isMobile,
          questionType: _currentSection.type,

          isAdmin: widget.isAdmin,
        );
    }
  }

  // ADD this new method to handle multiple questions:
  void _addMultipleQuestions(List<Question> questions) {
    setState(() {
      _allQuestions[_currentSection.name]!.addAll(questions);
    });
    _showMessage('${questions.length} questions added', AppColors.success);
    _checkSectionCompletion();
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
            // Navigation between sections
            if (widget.sections.length > 1) ...[
              Row(
                children: [
                  if (_currentSectionIndex > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _currentSectionIndex--),
                        child: const Text('Previous Section'),
                      ),
                    ),
                  if (_currentSectionIndex > 0 && _currentSectionIndex < widget.sections.length - 1)
                    const SizedBox(width: 12),
                  if (_currentSectionIndex < widget.sections.length - 1)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _currentSectionIndex++),
                        child: const Text('Next Section'),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Complete paper action
            if (_allComplete())
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: !_isProcessing ? _createPaper : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: isMobile ? 16 : 12),
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
                      Text(_getProcessingText()),
                    ],
                  )
                      : Text(_getCompleteButtonText()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getProcessingText() {
    if (widget.isEditing) {
      return widget.isAdmin ? 'Submitting Updates...' : 'Updating Draft...';
    } else {
      return widget.isAdmin ? 'Submitting Paper...' : 'Saving Draft...';
    }
  }

  String _getCompleteButtonText() {
    if (widget.isEditing) {
      return widget.isAdmin ? 'Submit Updated Paper' : 'Update Draft';
    } else {
      return widget.isAdmin ? 'Submit Paper' : 'Save as Draft';
    }
  }

  void _addQuestion(Question question) {
    setState(() {
      _allQuestions[_currentSection.name]!.add(question);
    });
    _showMessage('Question added', AppColors.success);
    _checkSectionCompletion();
  }

  void _editQuestion(int index, Question updatedQuestion) {
    setState(() {
      _allQuestions[_currentSection.name]![index] = updatedQuestion;
    });
    _showMessage('Question updated', AppColors.success);
  }

  void _removeQuestion(int index) {
    setState(() {
      _allQuestions[_currentSection.name]!.removeAt(index);
    });
    _showMessage('Question removed', AppColors.warning);
  }

  void _checkSectionCompletion() {
    final section = _currentSection;
    final questions = _allQuestions[section.name]!;
    final mandatoryQuestions = questions.where((q) => !q.isOptional).length;

    // ✅ Same logic for ALL question types - clean and consistent
    bool sectionComplete = mandatoryQuestions >= section.questions;

    if (sectionComplete && _currentSectionIndex < widget.sections.length - 1) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _currentSectionIndex++);
      });
    }
  }

  bool _allComplete() {
    for (var section in widget.sections) {
      final questions = _allQuestions[section.name] ?? [];
      final mandatoryCount = questions.where((q) => !q.isOptional).length;

      // ✅ Same logic for ALL question types - clean and consistent
      if (mandatoryCount < section.questions) return false;
    }
    return true;
  }

  void _createPaper() {
    if (_isProcessing || !_allComplete()) return;
    setState(() => _isProcessing = true);

    try {
      // Validation
      final errors = PaperValidationService.validatePaperForCreation(
        title: widget.paperTitle,
        gradeLevel: widget.gradeLevel,
        selectedSections: widget.selectedSections,
        selectedSubjects: widget.selectedSubjects,
        examType: widget.examType,
      );

      if (errors.isNotEmpty) {
        setState(() => _isProcessing = false);
        _showMessage('Validation failed: ${errors.join(', ')}', AppColors.error);
        return;
      }

      final paper = widget.isEditing && widget.existingPaperId != null
          ? QuestionPaperEntity(
        id: widget.existingPaperId!,
        title: widget.paperTitle,
        subject: widget.selectedSubjects.map((s) => s.name).join(', '),
        examType: widget.examType.name,
        createdBy: 'current_user',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
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
        examDate: widget.examDate,
        questions: _allQuestions,
      );

      // WORKFLOW LOGIC: Admin submits directly, Teacher saves as draft first
      if (widget.isAdmin) {
        // Admin: Submit directly for approval
        context.read<QuestionPaperBloc>().add(SubmitPaper(paper));
      } else {
        // Teacher: Save as draft first
        context.read<QuestionPaperBloc>().add(SaveDraft(paper));
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      _showMessage('Error: $e', AppColors.error);
    }
  }

  void _handleBlocState(BuildContext context, QuestionPaperState state) {
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