// features/question_papers/pages/widgets/question_input/question_input_coordinator.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../../core/infrastructure/services/auto_save_service.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../../core/presentation/routes/app_routes.dart';
import '../../../../core/presentation/utils/ui_helpers.dart';
import '../../../../core/presentation/widgets/info_box.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../../catalog/domain/entities/exam_type_entity.dart';
import '../../../catalog/domain/entities/subject_entity.dart';
import '../../../paper_workflow/domain/entities/paper_status.dart';
import '../../../paper_workflow/domain/entities/question_entity.dart';
import '../../../paper_workflow/domain/entities/question_paper_entity.dart';
import '../../../paper_workflow/presentation/bloc/question_paper_bloc.dart';
import '../../presentation/widgets/question_input/bulk_input_widget.dart';
import '../../presentation/widgets/question_input/essay_input_widget.dart';
import '../../presentation/widgets/question_input/fill_blanks_input_widget.dart';
import '../../presentation/widgets/question_input/matching_input_widget.dart';
import '../../presentation/widgets/question_input/mcq_input_widget.dart';
import '../../presentation/widgets/question_input/question_list_widget.dart';
import '../../presentation/widgets/question_input/section_progress_widget.dart';
import '../../presentation/widgets/paper_preview_widget.dart';
import 'paper_validation_service.dart';

class QuestionInputCoordinator extends StatefulWidget {
  final List<ExamSectionEntity> sections;
  final ExamTypeEntity examType;
  final List<SubjectEntity> selectedSubjects;
  final String paperTitle;
  final int gradeLevel;
  final String gradeId;
  final String academicYear;
  final List<String> selectedSections;
  final Function(QuestionPaperEntity) onPaperCreated;
  final DateTime? examDate;
  final bool isAdmin;

  // Edit mode parameters
  final Map<String, List<Question>>? existingQuestions;
  final bool isEditing;
  final String? existingPaperId;
  final String? existingTenantId;
  final String? existingUserId;

  const QuestionInputCoordinator({
    super.key,
    required this.sections,
    required this.examType,
    required this.selectedSubjects,
    required this.paperTitle,
    required this.gradeLevel,
    required this.gradeId,
    required this.academicYear,
    required this.selectedSections,
    required this.isAdmin,
    required this.onPaperCreated,
    this.existingQuestions,
    this.isEditing = false,
    this.existingPaperId,
    this.existingTenantId,
    this.existingUserId,
    this.examDate,
  });

  @override
  State<QuestionInputCoordinator> createState() => _QuestionInputCoordinatorState();
}

class _QuestionInputCoordinatorState extends State<QuestionInputCoordinator> {
  int _currentSectionIndex = 0;
  Map<String, List<Question>> _allQuestions = {};
  bool _isProcessing = false;
  final _autoSaveService = AutoSaveService();
  DateTime? _lastAutoSave;

  @override
  void initState() {
    super.initState();
    _initializeQuestions();
    _startAutoSave();
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

  void _startAutoSave() {
    if (widget.isAdmin) return; // Only auto-save for teachers, not admins

    _autoSaveService.startAutoSave(
      onSave: () async {
        final userStateService = sl<UserStateService>();
        final userId = userStateService.currentUserId;
        final tenantId = userStateService.currentTenantId;

        if (userId == null || tenantId == null) return;

        final now = DateTime.now();
        final paper = QuestionPaperEntity(
          id: widget.existingPaperId ?? const Uuid().v4(),
          title: widget.paperTitle,
          subjectId: widget.selectedSubjects.first.id,
          gradeId: widget.gradeId,
          examTypeId: widget.examType.id,
          academicYear: widget.academicYear,
          createdBy: userId,
          createdAt: now,
          modifiedAt: now,
          status: PaperStatus.draft,
          examTypeEntity: widget.examType,
          questions: _allQuestions,
          examDate: widget.examDate,
          subject: widget.selectedSubjects.map((s) => s.name).join(', '),
          grade: 'Grade ${widget.gradeLevel}',
          examType: widget.examType.name,
          gradeLevel: widget.gradeLevel,
          selectedSections: widget.selectedSections,
          tenantId: tenantId,
          userId: userId,
        );

        context.read<QuestionPaperBloc>().add(SaveDraft(paper));
        _lastAutoSave = DateTime.now();
      },
      shouldSave: () {
        // Only save if there are questions and it's been at least 30 seconds
        final hasQuestions = _allQuestions.values.any((questions) => questions.isNotEmpty);
        return hasQuestions && !_isProcessing;
      },
    );
  }

  @override
  void dispose() {
    _autoSaveService.dispose();
    super.dispose();
  }

  ExamSectionEntity get _currentSection => widget.sections[_currentSectionIndex];
  List<Question> get _currentSectionQuestions => _allQuestions[_currentSection.name] ?? [];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return BlocListener<QuestionPaperBloc, QuestionPaperState>(
      listener: _handleBlocState,
      child: Container(
        padding: const EdgeInsets.all(UIConstants.paddingLarge),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isMobile),
            SizedBox(height: UIConstants.spacing24),
            _buildSectionTabs(),
            SizedBox(height: UIConstants.spacing16),
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
            _buildActions(isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    final currentMarks = _getCurrentMarks();
    final totalMarks = widget.examType.calculatedTotalMarks;
    final optionalMarks = _getOptionalMarks();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.paperTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: currentMarks == totalMarks
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(UIConstants.radiusXXLarge),
              ),
              child: Text(
                '$currentMarks/$totalMarks marks',
                style: TextStyle(
                  fontSize: UIConstants.fontSizeMedium,
                  fontWeight: FontWeight.w600,
                  color: currentMarks == totalMarks ? AppColors.success : AppColors.primary,
                ),
              ),
            ),
            if (optionalMarks > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(UIConstants.radiusXXLarge),
                ),
                child: Text(
                  '+$optionalMarks optional',
                  style: TextStyle(
                    fontSize: UIConstants.fontSizeSmall,
                    fontWeight: FontWeight.w500,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: UIConstants.spacing8),
        Text(
          'Add questions for each section',
          style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildSectionTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: widget.sections.asMap().entries.map((entry) {
          final index = entry.key;
          final section = entry.value;
          final isActive = index == _currentSectionIndex;
          final questions = _allQuestions[section.name] ?? [];
          final mandatoryCount = questions.where((q) => !q.isOptional).length;
          final isComplete = mandatoryCount >= section.questions;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _currentSectionIndex = index),
                borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                    border: Border.all(
                      color: isActive ? AppColors.primary : AppColors.border,
                      width: isActive ? 2 : 1,
                    ),
                    color: isActive
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.surface,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isComplete)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.check_circle,
                            size: 16,
                            color: AppColors.success,
                          ),
                        ),
                      Text(
                        section.name,
                        style: TextStyle(
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                          color: isActive ? AppColors.primary : AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '($mandatoryCount/${section.questions})',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  int _getOptionalMarks() {
    int total = 0;
    for (var section in widget.sections) {
      final questions = _allQuestions[section.name] ?? [];
      for (var question in questions) {
        if (question.isOptional) {
          total += question.marks;
        }
      }
    }
    return total;
  }

  int _getCurrentMarks() {
    int total = 0;
    for (var section in widget.sections) {
      final questions = _allQuestions[section.name] ?? [];
      for (var question in questions) {
        if (!question.isOptional) {
          total += question.marks;
        }
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

      case 'misc_grammar':
        return FillBlanksInputWidget(
          onQuestionAdded: _addQuestion,
          isMobile: isMobile,
          isAdmin: widget.isAdmin,
          title: 'Add Grammar Question',
        );

      case 'match_following':
        return MatchingInputWidget(
          onQuestionAdded: _addQuestion,
          isMobile: isMobile,
          requiredPairs: _currentSection.marksPerQuestion,
          isAdmin: widget.isAdmin,
        );

      case 'missing_letters':
      case 'true_false':
      case 'short_answers':
        return BulkInputWidget(
          questionType: _currentSection.type,
          questionCount: _currentSection.questions,
          marksPerQuestion: _currentSection.marksPerQuestion,
          onQuestionsAdded: _addMultipleQuestions,
          isMobile: isMobile,
          isAdmin: widget.isAdmin,
        );

      case 'meanings':
      case 'opposites':
      case 'frame_sentences':
      case 'long_answers':
      default:
        return EssayInputWidget(
          onQuestionAdded: _addQuestion,
          isMobile: isMobile,
          questionType: _currentSection.type,
          isAdmin: widget.isAdmin,
          marksPerQuestion: _currentSection.marksPerQuestion,
        );
    }
  }

  void _addMultipleQuestions(List<Question> questions) {
    setState(() {
      _allQuestions[_currentSection.name]!.addAll(questions);
    });
    UiHelpers.showSuccessMessage(context, '${questions.length} questions added');
    _checkSectionCompletion();
  }

  Widget _buildActions(bool isMobile) {
    return Column(
      children: [
        if (_allComplete())
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: !_isProcessing ? _showPreviewAndSubmit : null,
              icon: _isProcessing
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.preview_rounded),
              label: Text(_isProcessing ? _getProcessingText() : 'Preview & ${_getCompleteButtonText()}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                ),
              ),
            ),
          )
        else
          const InfoBox(
            message: 'Complete all sections to submit the paper',
          ),
      ],
    );
  }

  void _showPreviewAndSubmit() {
    final now = DateTime.now();
    final previewPaper = QuestionPaperEntity(
      id: widget.existingPaperId ?? const Uuid().v4(),
      title: widget.paperTitle,
      subjectId: widget.selectedSubjects.first.id,
      gradeId: widget.gradeId,
      examTypeId: widget.examType.id,
      academicYear: widget.academicYear,
      createdBy: 'preview',
      createdAt: now,
      modifiedAt: now,
      status: PaperStatus.draft,
      examTypeEntity: widget.examType,
      questions: _allQuestions,
      examDate: widget.examDate,
      subject: widget.selectedSubjects.map((s) => s.name).join(', '),
      grade: 'Grade ${widget.gradeLevel}',
      examType: widget.examType.name,
      gradeLevel: widget.gradeLevel,
      selectedSections: widget.selectedSections,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PaperPreviewWidget(
        paper: previewPaper,
        onSubmit: _createPaper,
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
    final correctedQuestion = Question(
      text: question.text,
      type: _currentSection.type,
      marks: question.marks,
      options: question.options,
      subQuestions: question.subQuestions,
      isOptional: question.isOptional,
    );

    setState(() {
      _allQuestions[_currentSection.name]!.add(correctedQuestion);
    });
    UiHelpers.showSuccessMessage(context, 'Question added');
    _checkSectionCompletion();
  }

  void _editQuestion(int index, Question updatedQuestion) {
    setState(() {
      _allQuestions[_currentSection.name]![index] = updatedQuestion;
    });
    UiHelpers.showSuccessMessage(context, 'Question updated');
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

      if (mandatoryCount < section.questions) return false;
    }
    return true;
  }

  void _createPaper() {
    if (_isProcessing || !_allComplete()) return;
    setState(() => _isProcessing = true);

    try {
      final userStateService = sl<UserStateService>();
      final userId = userStateService.currentUserId;
      final tenantId = userStateService.currentTenantId;

      // Validate user authentication state
      if (userId == null || userId.isEmpty) {
        setState(() => _isProcessing = false);
        _showMessage('User not authenticated. Please log in again.', AppColors.error);
        return;
      }

      if (tenantId == null || tenantId.isEmpty) {
        setState(() => _isProcessing = false);
        _showMessage('Tenant information missing. Please log in again.', AppColors.error);
        return;
      }

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

      final now = DateTime.now();

      final paper = QuestionPaperEntity(
        id: widget.isEditing && widget.existingPaperId != null
            ? widget.existingPaperId!
            : const Uuid().v4(),
        title: widget.paperTitle,
        subjectId: widget.selectedSubjects.first.id,
        gradeId: widget.gradeId,
        examTypeId: widget.examType.id,
        academicYear: widget.academicYear,
        createdBy: widget.isEditing ? (widget.existingUserId ?? userId) : userId,
        createdAt: widget.isEditing ? now.subtract(const Duration(hours: 1)) : now,
        modifiedAt: now,
        status: PaperStatus.draft,
        examTypeEntity: widget.examType,
        questions: _allQuestions,
        examDate: widget.examDate,
        subject: widget.selectedSubjects.map((s) => s.name).join(', '),
        grade: 'Grade ${widget.gradeLevel}',
        examType: widget.examType.name,
        gradeLevel: widget.gradeLevel,
        selectedSections: widget.selectedSections,
        tenantId: widget.isEditing ? (widget.existingTenantId ?? tenantId) : tenantId,
      );

      if (widget.isAdmin) {
        context.read<QuestionPaperBloc>().add(SubmitPaper(paper));
      } else {
        context.read<QuestionPaperBloc>().add(SaveDraft(paper));
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      _showMessage('Error: $e', AppColors.error);
    }
  }

  void _handleBlocState(BuildContext context, QuestionPaperState state) {
    if (state is QuestionPaperSuccess) {
      setState(() => _isProcessing = false);
      UiHelpers.showSuccessMessage(context, state.message);
      if (state.actionType == 'save') {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) context.go(AppRoutes.home);
        });
      }
    }
    if (state is QuestionPaperError) {
      setState(() => _isProcessing = false);
      UiHelpers.showErrorMessage(context, state.message);
    }
  }

  void _showMessage(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(UIConstants.paddingMedium),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UIConstants.radiusMedium)),
      ),
    );
  }
}