// features/question_papers/pages/widgets/question_input/question_input_coordinator.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/ai/services/groq_service.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../../core/infrastructure/services/auto_save_service.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../../core/presentation/routes/app_routes.dart';
import '../../../../core/presentation/utils/ui_helpers.dart';
import '../../../../core/presentation/widgets/info_box.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../../catalog/domain/entities/paper_section_entity.dart';
import '../../../catalog/domain/entities/subject_entity.dart';
import '../../../catalog/domain/entities/exam_type.dart';
import '../../../catalog/domain/entities/teacher_pattern_entity.dart';
import '../../../catalog/presentation/bloc/teacher_pattern_bloc.dart';
import '../../../catalog/presentation/bloc/teacher_pattern_event.dart';
import '../../../catalog/presentation/bloc/teacher_pattern_state.dart';
import '../../../paper_workflow/domain/entities/paper_status.dart';
import '../../../paper_workflow/domain/entities/question_entity.dart';
import '../../../paper_workflow/domain/entities/question_paper_entity.dart';
import '../../../paper_workflow/presentation/bloc/question_paper_bloc.dart';
import '../../presentation/dialogs/submission_feedback_dialog.dart';
import '../../presentation/widgets/ai_polish_review_dialog.dart';
import '../../presentation/widgets/polish_loading_dialog.dart';
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
  final List<PaperSectionEntity> paperSections;
  final List<SubjectEntity> selectedSubjects;
  final String paperTitle;
  final int gradeLevel;
  final String gradeId;
  final String academicYear;
  final List<String> selectedSections;
  final Function(QuestionPaperEntity) onPaperCreated;
  final DateTime? examDate;
  final bool isAdmin;

  // Exam type fields
  final ExamType examType;
  final int? examNumber;

  // Edit mode parameters
  final Map<String, List<Question>>? existingQuestions;
  final bool isEditing;
  final String? existingPaperId;
  final String? existingTenantId;
  final String? existingUserId;

  const QuestionInputCoordinator({
    super.key,
    required this.paperSections,
    required this.selectedSubjects,
    required this.paperTitle,
    required this.gradeLevel,
    required this.gradeId,
    required this.academicYear,
    required this.selectedSections,
    required this.isAdmin,
    required this.onPaperCreated,
    required this.examType,
    this.examNumber,
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
  bool _showSaveIndicator = false;
  bool _aiPolishCompleted = false; // Track if AI polish was completed successfully

  @override
  void initState() {
    super.initState();
    _initializeQuestions();
    _startAutoSave();
  }

  void _initializeQuestions() {
    for (var section in widget.paperSections) {
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
          academicYear: widget.academicYear,
          createdBy: userId,
          createdAt: now,
          modifiedAt: now,
          status: PaperStatus.draft,
          paperSections: widget.paperSections,
          questions: _allQuestions,
          examType: widget.examType,
          examDate: widget.examDate,
          examNumber: widget.examNumber,
          subject: widget.selectedSubjects.map((s) => s.name).join(', '),
          grade: 'Grade ${widget.gradeLevel}',
          gradeLevel: widget.gradeLevel,
          selectedSections: widget.selectedSections,
          tenantId: tenantId,
          userId: userId,
        );

        context.read<QuestionPaperBloc>().add(SaveDraft(paper));
        setState(() {
          _lastAutoSave = DateTime.now();
          _showSaveIndicator = true;
        });

        // Hide indicator after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => _showSaveIndicator = false);
          }
        });
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

  PaperSectionEntity get _currentSection => widget.paperSections[_currentSectionIndex];
  List<Question> get _currentSectionQuestions => _allQuestions[_currentSection.name] ?? [];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return MultiBlocListener(
      listeners: [
        BlocListener<QuestionPaperBloc, QuestionPaperState>(
          listener: _handleBlocState,
        ),
        BlocListener<TeacherPatternBloc, TeacherPatternState>(
          listener: (context, state) {
            if (state is TeacherPatternSaved) {
              debugPrint('✅ Pattern saved successfully: ${state.pattern.name}');
              debugPrint('   Pattern ID: ${state.pattern.id}');
              debugPrint('   Was incremented: ${state.wasIncremented}');
              debugPrint('   Use count: ${state.pattern.useCount}');

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.wasIncremented
                                ? 'Pattern usage updated'
                                : 'New pattern saved: ${state.pattern.name}',
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: AppColors.success,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            } else if (state is TeacherPatternError) {
              debugPrint('❌ Pattern save error: ${state.message}');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to save pattern: ${state.message}'),
                    backgroundColor: AppColors.error,
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
            }
          },
        ),
      ],
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(UIConstants.paddingLarge),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black04,
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
                  sections: widget.paperSections,
                  allQuestions: _allQuestions,
                ),
                SizedBox(height: isMobile ? 24 : 20),
                QuestionListWidget(
                  sectionName: _currentSection.name,
                  questions: _currentSectionQuestions,
                  onEditQuestion: _editQuestion,
                  onRemoveQuestion: _removeQuestion,
                  onReorderQuestions: _reorderQuestions,
                  isMobile: isMobile,
                ),
                SizedBox(height: isMobile ? 20 : 16),
                // Word bank mode indicator for fill_in_blanks sections
                if (_currentSection.type == 'fill_in_blanks')
                  _buildWordBankModeIndicator(isMobile),
                if (_currentSection.type == 'fill_in_blanks')
                  SizedBox(height: UIConstants.spacing16),
                _buildQuestionInput(isMobile),
                SizedBox(height: isMobile ? 32 : 20),
                _buildActions(isMobile),
              ],
            ),
          ),
          // Auto-save indicator
          if (_showSaveIndicator || _lastAutoSave != null)
            Positioned(
              bottom: 16,
              right: 16,
              child: _buildAutoSaveIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    final currentMarks = _getCurrentMarks();
    final totalMarks = widget.paperSections.fold(0.0, (sum, section) => sum + section.totalMarks);
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
                    ? AppColors.success10
                    : AppColors.primary10,
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
                  color: AppColors.warning10,
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

  Widget _buildAutoSaveIndicator() {
    String message;
    Color bgColor;
    IconData icon;

    if (_showSaveIndicator) {
      message = 'Saved just now';
      bgColor = AppColors.success;
      icon = Icons.check_circle_rounded;
    } else if (_lastAutoSave != null) {
      final now = DateTime.now();
      final diff = now.difference(_lastAutoSave!);

      if (diff.inMinutes < 1) {
        message = 'Saved just now';
      } else if (diff.inMinutes < 60) {
        message = 'Saved ${diff.inMinutes} min ago';
      } else {
        message = 'Saved ${diff.inHours}h ago';
      }
      bgColor = AppColors.textSecondary;
      icon = Icons.cloud_done_rounded;
    } else {
      return const SizedBox.shrink();
    }

    return AnimatedOpacity(
      opacity: _showSaveIndicator ? 1.0 : 0.7,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
          boxShadow: [
            BoxShadow(
              color: AppColors.overlayLight,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: widget.paperSections.asMap().entries.map((entry) {
          final index = entry.key;
          final section = entry.value;
          final isActive = index == _currentSectionIndex;
          final questions = _allQuestions[section.name] ?? [];
          final mandatoryCount = questions.where((q) => !q.isOptional).length;
          final isComplete = section.type == 'match_following'
              ? mandatoryCount > 0  // For matching: just need 1 question
              : mandatoryCount >= section.questions;  // For others: match count

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
                        ? AppColors.primary10
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

  Widget _buildWordBankModeIndicator(bool isMobile) {
    final sectionName = _currentSection.name;
    final sectionType = _currentSection.type;
    final questions = _currentSectionQuestions;

    // Determine mode
    String modeText;
    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData icon;
    Widget? wordBankPreview;

    if (questions.isEmpty || !_hasAnyWordBank(sectionName)) {
      // No questions yet OR questions exist but no word banks (normal fill-in-blanks)
      modeText = 'Word Bank Mode: None';
      bgColor = Colors.grey.shade50;
      borderColor = Colors.grey.shade300;
      textColor = AppColors.textSecondary;
      icon = Icons.info_outline;
    } else if (_isSharedWordBankMode(sectionName, sectionType)) {
      // Shared mode
      modeText = 'Word Bank Mode: Shared';
      bgColor = AppColors.primary10;
      borderColor = AppColors.primary;
      textColor = AppColors.primary;
      icon = Icons.workspaces_rounded;

      // Build word bank preview
      final sharedWords = _getSharedWordBank(sectionName);
      if (sharedWords.isNotEmpty) {
        wordBankPreview = Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'SHARED WORD BANK',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: sharedWords.map((word) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                    ),
                    child: Text(
                      word,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }
    } else {
      // Individual mode (some questions have 2+ words or no words)
      modeText = 'Word Bank Mode: Individual';
      bgColor = AppColors.success10;
      borderColor = AppColors.success;
      textColor = AppColors.success;
      icon = Icons.list_alt_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: textColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  modeText,
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          // Show explanation based on mode
          if (questions.isEmpty || !_hasAnyWordBank(sectionName)) ...[
            const SizedBox(height: 6),
            Text(
              questions.isEmpty
                  ? 'Add questions with or without a word bank'
                  : 'Normal fill in the blanks - no word bank used',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ] else if (_isSharedWordBankMode(sectionName, sectionType)) ...[
            const SizedBox(height: 6),
            Text(
              'All questions have 1 word each. The word bank will appear at the top of this section.',
              style: TextStyle(
                fontSize: 11,
                color: textColor.withOpacity(0.8),
              ),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              'Questions have different word counts. Each question will display its own word bank.',
              style: TextStyle(
                fontSize: 11,
                color: textColor.withOpacity(0.8),
              ),
            ),
          ],
          // Show word bank preview for shared mode
          if (wordBankPreview != null) wordBankPreview,
        ],
      ),
    );
  }

  double _getOptionalMarks() {
    double total = 0.0;
    for (var section in widget.paperSections) {
      final questions = _allQuestions[section.name] ?? [];
      for (var question in questions) {
        if (question.isOptional) {
          total += question.marks;
        }
      }
    }
    return total;
  }

  double _getCurrentMarks() {
    double total = 0.0;
    for (var section in widget.paperSections) {
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
          title: 'Add Fill in the Blanks Question',
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
          requiredPairs: _currentSection.questions, // Number of pairs = questions in section
          marksPerQuestion: _currentSection.marksPerQuestion,
          isAdmin: widget.isAdmin,
        );

      case 'missing_letters':
      case 'true_false':
      case 'short_answers':
      case 'word_forms':
        return BulkInputWidget(
          questionType: _currentSection.type,
          questionCount: _currentSection.questions,
          marksPerQuestion: _currentSection.marksPerQuestion,
          onQuestionsAdded: _addMultipleQuestions,
          isMobile: isMobile,
          isAdmin: widget.isAdmin,
        );

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

  Future<void> _showPreviewAndSubmit() async {
    // Step 1: Run mandatory AI polish
    final polishedQuestions = await _runAIPolish();

    if (polishedQuestions == null) {
      // Polish failed or was cancelled
      _showMessage('Unable to proceed without AI polish', AppColors.error);
      return;
    }

    // Step 2: Show review dialog with undo options
    final finalQuestions = await _showPolishReview(polishedQuestions);

    if (finalQuestions == null) {
      // User cancelled at review step
      return;
    }

    // Step 3: Update questions with reviewed (and possibly reverted) changes
    setState(() {
      _allQuestions = finalQuestions;
      _aiPolishCompleted = true; // Mark AI polish as completed
    });

    // Step 4: Show paper preview
    final now = DateTime.now();
    final previewPaper = QuestionPaperEntity(
      id: widget.existingPaperId ?? const Uuid().v4(),
      title: widget.paperTitle,
      subjectId: widget.selectedSubjects.first.id,
      gradeId: widget.gradeId,
      academicYear: widget.academicYear,
      createdBy: 'preview',
      createdAt: now,
      modifiedAt: now,
      status: PaperStatus.draft,
      paperSections: widget.paperSections,
      questions: _allQuestions,
      examType: widget.examType,
      examDate: widget.examDate,
      examNumber: widget.examNumber,
      subject: widget.selectedSubjects.map((s) => s.name).join(', '),
      grade: 'Grade ${widget.gradeLevel}',
      gradeLevel: widget.gradeLevel,
      selectedSections: widget.selectedSections,
    );

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PaperPreviewWidget(
        paper: previewPaper,
        onSubmit: _createPaper,
        isAdmin: widget.isAdmin,
        aiPolishCompleted: _aiPolishCompleted,
      ),
    );
  }

  /// Run AI polish on all questions with progress dialog (per-section optimization)
  /// Processes all questions in each section in a single API call for better performance
  Future<Map<String, List<Question>>?> _runAIPolish() async {
    // Calculate total sections with questions
    int nonEmptySections = 0;
    for (var section in widget.paperSections) {
      if ((_allQuestions[section.name] ?? []).isNotEmpty) {
        nonEmptySections++;
      }
    }

    if (nonEmptySections == 0) {
      return _allQuestions; // No questions to polish
    }

    // Track progress with ValueNotifier to avoid rebuilding dialog
    final processedSectionsNotifier = ValueNotifier<int>(0);

    // Show loading dialog once
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PolishLoadingDialog(
        totalQuestions: nonEmptySections,
        processedQuestionsNotifier: processedSectionsNotifier,
        isPerSection: true, // New flag to show section-based progress
      ),
    );

    try {
      final polished = <String, List<Question>>{};

      // Process each section
      for (var section in widget.paperSections) {
        final sectionName = section.name;
        final sectionQuestions = _allQuestions[sectionName] ?? [];

        if (sectionQuestions.isEmpty) {
          polished[sectionName] = [];
          continue;
        }

        try {
          // Polish section using per-section method
          final polishedList = await _polishSectionQuestions(
            sectionQuestions,
            section.type,
          );

          polished[sectionName] = polishedList;

          // Update progress
          processedSectionsNotifier.value++;
        } catch (e) {
          // If polishing fails for this section, keep original questions
          polished[sectionName] = sectionQuestions;
          processedSectionsNotifier.value++;
        }
      }

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
      }
      processedSectionsNotifier.dispose(); // Clean up notifier

      return polished;
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        _showMessage('AI Polish failed: $e', AppColors.error);
      }
      processedSectionsNotifier.dispose(); // Clean up notifier
      return null;
    }
  }

  /// Polish all questions in a section using per-section API optimization
  Future<List<Question>> _polishSectionQuestions(
    List<Question> sectionQuestions,
    String sectionType,
  ) async {
    final polishedList = <Question>[];

    for (final q in sectionQuestions) {
      try {
        // SKIP Match the Following questions - too complex for masking
        if (q.type == 'match_following') {
          polishedList.add(q); // Return unchanged
          continue;
        }

        // SKIP Missing Letters questions - AI tends to fill in the blanks
        if (q.type == 'missing_letters') {
          polishedList.add(q); // Return unchanged
          continue;
        }

        // SKIP Fill in the Blanks questions - AI fills in answers despite masking
        if (q.type == 'fill_in_blanks' || q.type == 'fill_blanks') {
          polishedList.add(q); // Return unchanged
          continue;
        }

        // SKIP Word Forms questions - single-word transformation questions
        if (q.type == 'word_forms') {
          polishedList.add(q); // Return unchanged
          continue;
        }

        // Prepare text with smart masking for misc_grammar (if needed in future)
        String textToPolish = q.text;
        bool hasBlanks = false;

        // For misc_grammar: Replace "________" with "[BLANK]" if it has blanks
        if (q.type == 'misc_grammar') {
          if (q.text.contains('_')) {
            textToPolish = q.text.replaceAll(RegExp(r'_{2,}'), '[BLANK]');
            hasBlanks = true;
          }
        }

        // Polish question text with masked version, passing question type for better AI context
        final textResult = await GroqService.polishText(textToPolish, questionType: q.type);

        // Restore original blanks in polished text
        String restoredText = textResult.polished;
        if (hasBlanks) {
          // Restore blanks by matching [BLANK] back to original blanks
          final originalBlanks = RegExp(r'_{2,}').allMatches(q.text).map((m) => m.group(0)!).toList();
          int blankIndex = 0;
          restoredText = restoredText.replaceAllMapped(
            RegExp(r'\[BLANK\]'),
            (match) {
              if (blankIndex < originalBlanks.length) {
                return originalBlanks[blankIndex++];
              }
              return match.group(0)!;
            },
          );
        }

        // Polish MCQ options if present (with question context for better accuracy)
        List<String>? polishedOptions;
        if (q.type == 'multiple_choice' && q.options != null && q.options!.isNotEmpty) {
          polishedOptions = [];
          for (final option in q.options!) {
            // Skip empty options
            if (option.trim().isEmpty) {
              polishedOptions.add(option);
              continue;
            }
            try {
              // Format option with question context for Groq to understand the MCQ context
              // This prevents meaningless rewording and keeps options in proper context
              final contextualOption = 'Question: ${restoredText}\nOption: $option';
              final optionResult = await GroqService.polishText(
                contextualOption,
                questionType: 'mcq',
              );

              // Extract only the polished option (everything after "Option: ")
              final polishedText = optionResult.polished;
              final optionPrefix = 'Option: ';
              final optionStartIndex = polishedText.indexOf(optionPrefix);

              if (optionStartIndex != -1) {
                // Extract only the option part after "Option: "
                final extractedOption = polishedText.substring(optionStartIndex + optionPrefix.length).trim();
                polishedOptions.add(extractedOption);
              } else {
                // Fallback: if extraction fails, use the whole response or original
                polishedOptions.add(polishedText.isNotEmpty ? polishedText : option);
              }
            } catch (e) {
              // If option polish fails, keep original
              polishedOptions.add(option);
            }
          }
        }

        // Polish subquestions if present
        List<SubQuestion>? polishedSubQuestions;
        if (q.subQuestions.isNotEmpty) {
          polishedSubQuestions = [];
          for (final subQ in q.subQuestions) {
            try {
              final subQResult = await GroqService.polishText(subQ.text);
              polishedSubQuestions.add(SubQuestion(
                text: subQResult.polished,
              ));
            } catch (e) {
              // If subquestion polish fails, keep original
              polishedSubQuestions.add(subQ);
            }
          }
        }

        polishedList.add(q.copyWith(
          text: restoredText,
          options: polishedOptions ?? q.options,
          subQuestions: polishedSubQuestions ?? q.subQuestions,
          originalText: textResult.original,
          polishChanges: textResult.changesSummary,
        ));
      } catch (e) {
        // If polishing fails for one question, keep original
        polishedList.add(q);
      }
    }

    return polishedList;
  }

  /// Show polish review dialog with undo options
  Future<Map<String, List<Question>>?> _showPolishReview(
    Map<String, List<Question>> polished,
  ) async {
    final result = await showDialog<Map<String, List<Question>>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AIPolishReviewDialog(
        originalQuestions: _allQuestions,
        polishedQuestions: polished,
        paperSections: widget.paperSections,
      ),
    );

    return result; // Returns null if cancelled, or final questions map if accepted
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
    // Prevent adding more than 1000 questions per section to avoid OOM
    const maxQuestionsPerSection = 1000;
    final currentQuestions = _allQuestions[_currentSection.name]!;

    if (currentQuestions.length >= maxQuestionsPerSection) {
      UiHelpers.showErrorMessage(
        context,
        'Cannot add more than $maxQuestionsPerSection questions per section. Please create a new paper.'
      );
      return;
    }

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

  void _reorderQuestions(int oldIndex, int newIndex) {
    setState(() {
      final questions = _allQuestions[_currentSection.name]!;
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final question = questions.removeAt(oldIndex);
      questions.insert(newIndex, question);
    });
    UiHelpers.showSuccessMessage(context, 'Question order updated');
  }

  /// Check if any question in section has a word bank
  bool _hasAnyWordBank(String sectionName) {
    final questions = _allQuestions[sectionName] ?? [];
    return questions.any((q) => q.options != null && q.options!.isNotEmpty);
  }

  /// Auto-detect word bank mode for fill_in_blanks sections
  /// Returns true if shared mode (all questions have exactly 1 word)
  /// Returns false if individual mode (some questions have 2+ words)
  bool _isSharedWordBankMode(String sectionName, String sectionType) {
    // Only applies to fill_in_blanks type
    if (sectionType != 'fill_in_blanks') return false;

    final questions = _allQuestions[sectionName] ?? [];
    if (questions.isEmpty) return false;

    // Check if ANY question has a word bank
    if (!_hasAnyWordBank(sectionName)) {
      return false; // No word bank at all (normal fill-in-blanks)
    }

    // If some questions have words, check if ALL have exactly 1 word
    for (final q in questions) {
      if (q.options == null || q.options!.length != 1) {
        return false; // Individual mode if any question has 0 or 2+ words
      }
    }

    return true; // Shared mode: all questions have exactly 1 word
  }

  /// Get combined word bank for shared mode
  List<String> _getSharedWordBank(String sectionName) {
    final questions = _allQuestions[sectionName] ?? [];
    final words = <String>[];

    for (final q in questions) {
      if (q.options != null && q.options!.isNotEmpty) {
        words.addAll(q.options!);
      }
    }

    return words;
  }

  void _checkSectionCompletion() {
    final section = _currentSection;
    final questions = _allQuestions[section.name]!;
    final mandatoryQuestions = questions.where((q) => !q.isOptional).toList();

    bool sectionComplete;

    // Special handling for matching questions
    if (section.type == 'match_following') {
      // For matching: 1 question with N pairs = complete
      sectionComplete = mandatoryQuestions.isNotEmpty;
    } else {
      // For other types: count must match section.questions
      sectionComplete = mandatoryQuestions.length >= section.questions;
    }

    // Additional validation for fill_in_blanks with shared word bank
    if (sectionComplete && section.type == 'fill_in_blanks') {
      // If it's detected as shared word bank mode, ensure at least one word exists
      if (_isSharedWordBankMode(section.name, section.type)) {
        final sharedWords = _getSharedWordBank(section.name);
        if (sharedWords.isEmpty) {
          // Don't auto-advance if shared mode but no words yet
          sectionComplete = false;
          if (mounted) {
            _showMessage('Shared word bank detected - please add at least one word', AppColors.warning);
          }
        }
      }
    }

    if (sectionComplete && _currentSectionIndex < widget.paperSections.length - 1) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _currentSectionIndex++);
      });
    }
  }

  bool _allComplete() {
    for (var section in widget.paperSections) {
      final questions = _allQuestions[section.name] ?? [];
      final mandatoryQuestions = questions.where((q) => !q.isOptional).toList();

      // Special handling for matching questions
      if (section.type == 'match_following') {
        // For matching: just need at least 1 question
        if (mandatoryQuestions.isEmpty) return false;
      } else {
        // For other types: count must match section.questions
        if (mandatoryQuestions.length < section.questions) return false;
      }
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
        paperSections: widget.paperSections,
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
        academicYear: widget.academicYear,
        createdBy: widget.isEditing ? (widget.existingUserId ?? userId) : userId,
        createdAt: widget.isEditing ? now.subtract(const Duration(hours: 1)) : now,
        modifiedAt: now,
        status: PaperStatus.draft,
        paperSections: widget.paperSections,
        questions: _allQuestions,
        examType: widget.examType,
        examDate: widget.examDate,
        examNumber: widget.examNumber,
        subject: widget.selectedSubjects.map((s) => s.name).join(', '),
        grade: 'Grade ${widget.gradeLevel}',
        gradeLevel: widget.gradeLevel,
        selectedSections: widget.selectedSections,
        tenantId: widget.isEditing ? (widget.existingTenantId ?? tenantId) : tenantId,
      );

      // Show submission feedback dialog IMMEDIATELY before sending to BLoC
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => SubmissionFeedbackDialog(
          onComplete: () {
            Navigator.of(context).pop(); // Close dialog
            if (mounted) context.go(AppRoutes.home);
          },
        ),
      );

      if (widget.isAdmin) {
        context.read<QuestionPaperBloc>().add(SubmitPaper(paper));
      } else {
        // For teachers: Submit if AI polish completed, otherwise save as draft
        if (_aiPolishCompleted) {
          context.read<QuestionPaperBloc>().add(SubmitPaper(paper));
        } else {
          context.read<QuestionPaperBloc>().add(SaveDraft(paper));
        }
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

      // Save pattern for teachers (not admins) when paper is submitted
      if (!widget.isAdmin && !widget.isEditing) {
        _saveTeacherPattern(context);
      }

      // Dialog is now shown immediately in _createPaper() method,
      // not here, to avoid the 5 second lag before showing "Submitting Paper..."
    }
    if (state is QuestionPaperError) {
      setState(() => _isProcessing = false);
      UiHelpers.showErrorMessage(context, state.message);
    }
  }

  void _saveTeacherPattern(BuildContext context) {
    try {
      final userStateService = sl<UserStateService>();
      final userId = userStateService.currentUserId;
      final tenantId = userStateService.currentTenantId;

      if (userId == null || tenantId == null) return;

      // Safety check: Ensure subjects list is not empty
      if (widget.selectedSubjects.isEmpty) {
        debugPrint('Cannot save pattern: No subjects selected');
        return;
      }

      // Generate pattern name from paper title
      final patternName = '${widget.paperTitle} - ${DateTime.now().year}';

      final pattern = TeacherPatternEntity(
        id: const Uuid().v4(),
        tenantId: tenantId,
        teacherId: userId,
        subjectId: widget.selectedSubjects.first.id,
        name: patternName,
        sections: widget.paperSections,
        totalQuestions: widget.paperSections.fold(0, (sum, s) => sum + s.questions),
        totalMarks: widget.paperSections.fold(0.0, (sum, s) => sum + s.totalMarks).toInt(),
        useCount: 1,
        lastUsedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      // Save pattern (will auto-deduplicate if identical structure exists)
      context.read<TeacherPatternBloc>().add(SaveTeacherPattern(pattern));

      // Reload patterns after saving to update the UI
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && widget.selectedSubjects.isNotEmpty) {
          context.read<TeacherPatternBloc>().add(
            LoadTeacherPatterns(
              teacherId: userId,
              subjectId: widget.selectedSubjects.first.id,
            ),
          );
        }
      });

      // Show success message (for debugging - can be removed later)
      debugPrint('✅ Pattern save initiated: $patternName');
    } catch (e) {
      // Show error for debugging
      debugPrint('❌ Failed to save pattern: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pattern save error: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
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