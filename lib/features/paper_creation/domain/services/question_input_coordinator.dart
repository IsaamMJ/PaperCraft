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
  final String? examTimetableEntryId; // For auto-assigned draft papers

  // Callbacks to preserve state across step navigation
  final ValueChanged<Map<String, List<Question>>>? onQuestionsChanged;
  final ValueChanged<List<PaperSectionEntity>>? onSectionsChanged;

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
    this.examTimetableEntryId,
    this.onQuestionsChanged,
    this.onSectionsChanged,
  });

  @override
  State<QuestionInputCoordinator> createState() => _QuestionInputCoordinatorState();
}

class _QuestionInputCoordinatorState extends State<QuestionInputCoordinator> {
  int _currentSectionIndex = 0;
  Map<String, List<Question>> _allQuestions = {};
  late List<PaperSectionEntity> _sections; // Mutable copy for renaming
  bool _isProcessing = false;
  final _autoSaveService = AutoSaveService();
  DateTime? _lastAutoSave;
  bool _showSaveIndicator = false;
  bool _aiPolishCompleted = false; // Track if AI polish was completed successfully

  // AI Polish timeout and cancellation
  bool _aiPolishCancelled = false;
  static const Duration _aiPolishTimeout = Duration(seconds: 30); // 30 seconds timeout

  @override
  void initState() {
    super.initState();
    _sections = List.from(widget.paperSections);
    _initializeQuestions();
    _startAutoSave();
  }

  @override
  void didUpdateWidget(covariant QuestionInputCoordinator oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync section metadata (marks, question count, type) from parent
    // without losing questions already entered in Step 2
    if (widget.paperSections != oldWidget.paperSections) {
      setState(() {
        for (int i = 0; i < widget.paperSections.length; i++) {
          final newSection = widget.paperSections[i];
          final existingIdx = _sections.indexWhere((s) => s.name == newSection.name);
          if (existingIdx >= 0) {
            _sections[existingIdx] = newSection;
          } else {
            _sections.add(newSection);
            _allQuestions[newSection.name] = [];
          }
        }
        // Remove sections that no longer exist in parent
        _sections.removeWhere((s) => !widget.paperSections.any((ps) => ps.name == s.name));
      });
    }
  }

  void _initializeQuestions() {
    for (var section in _sections) {
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
          paperSections: _sections,
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
  @override
  void dispose() {
    // Preserve state before destruction (back-navigation)
    _notifyQuestionsChanged();
    _notifySectionsChanged();
    _autoSaveService.dispose();
    super.dispose();
  }

  PaperSectionEntity get _currentSection => _sections[_currentSectionIndex];

  /// Notify parent of question changes for state preservation
  void _notifyQuestionsChanged() {
    widget.onQuestionsChanged?.call(Map.from(_allQuestions));
  }

  /// Notify parent of section changes for state preservation
  void _notifySectionsChanged() {
    widget.onSectionsChanged?.call(List.from(_sections));
  }

  void _showRenameSectionDialog(int index) {
    final section = _sections[index];
    final nameController = TextEditingController(text: section.name);
    final marksController = TextEditingController(text: section.marksPerQuestion.toString());
    final questionsController = TextEditingController(text: section.questions.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Section'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Section Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: questionsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Questions',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: marksController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Marks each',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = nameController.text.trim();
              final newMarks = double.tryParse(marksController.text) ?? section.marksPerQuestion;
              final newQuestions = int.tryParse(questionsController.text) ?? section.questions;

              if (newName.isEmpty) return;

              Navigator.pop(ctx);

              setState(() {
                final oldName = section.name;
                final oldMarks = section.marksPerQuestion;

                _sections[index] = section.copyWith(
                  name: newName,
                  marksPerQuestion: newMarks,
                  questions: newQuestions,
                );

                // Update questions map key if name changed
                final questionsKey = oldName != newName && _allQuestions.containsKey(oldName)
                    ? newName
                    : oldName;
                if (oldName != newName && _allQuestions.containsKey(oldName)) {
                  _allQuestions[newName] = _allQuestions.remove(oldName) ?? [];
                }

                // Update marks on existing questions if marks changed
                if (newMarks != oldMarks && _allQuestions.containsKey(questionsKey)) {
                  _allQuestions[questionsKey] = _allQuestions[questionsKey]!
                      .map((q) => q.copyWith(marks: newMarks))
                      .toList();
                }
              });

              _notifySectionsChanged();
              _notifyQuestionsChanged();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _renameSectionAndClose(BuildContext ctx, int index, String newName) {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    final oldName = _sections[index].name;
    if (trimmed == oldName) {
      Navigator.pop(ctx);
      return;
    }
    // Check for duplicates
    final existingNames = _sections.asMap().entries
        .where((e) => e.key != index)
        .map((e) => e.value.name.toLowerCase())
        .toSet();
    var safeName = trimmed;
    if (existingNames.contains(trimmed.toLowerCase())) {
      for (int i = 0; i < 26; i++) {
        final suffix = String.fromCharCode(65 + i);
        final candidate = '$trimmed ($suffix)';
        if (!existingNames.contains(candidate.toLowerCase())) {
          safeName = candidate;
          break;
        }
      }
    }
    setState(() {
      _sections[index] = _sections[index].copyWith(name: safeName);
      // Update questions map key
      if (_allQuestions.containsKey(oldName)) {
        _allQuestions[safeName] = _allQuestions.remove(oldName) ?? [];
      }
    });
    _notifyQuestionsChanged();
    _notifySectionsChanged();
    Navigator.pop(ctx);
  }
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
    final totalMarks = _sections.fold(0.0, (sum, section) => sum + section.totalMarks);
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
        children: _sections.asMap().entries.map((entry) {
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
                      Flexible(
                        child: Text(
                          section.name,
                          style: TextStyle(
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                            color: isActive ? AppColors.primary : AppColors.textPrimary,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        section.type == 'match_following'
                            ? '($mandatoryCount/1)'
                            : '($mandatoryCount/${section.questions})',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _showRenameSectionDialog(index),
                          child: Icon(Icons.edit, size: 14, color: AppColors.primary),
                        ),
                      ],
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
    for (var section in _sections) {
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
    for (var section in _sections) {
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
          sectionName: _currentSection.name,
          marksPerQuestion: _currentSection.marksPerQuestion,
        );

      case 'fill_in_blanks':
        return FillBlanksInputWidget(
          onQuestionAdded: _addQuestion,
          isMobile: isMobile,
          isAdmin: widget.isAdmin,
          title: _currentSection.name,
          marksPerQuestion: _currentSection.marksPerQuestion,
        );

      case 'misc_grammar':
        return FillBlanksInputWidget(
          onQuestionAdded: _addQuestion,
          isMobile: isMobile,
          isAdmin: widget.isAdmin,
          title: _currentSection.name,
          marksPerQuestion: _currentSection.marksPerQuestion,
        );

      case 'match_following':
        return MatchingInputWidget(
          onQuestionAdded: _addQuestion,
          isMobile: isMobile,
          requiredPairs: _currentSection.questions, // Number of pairs = questions in section
          marksPerQuestion: _currentSection.marksPerQuestion,
          isAdmin: widget.isAdmin,
          sectionName: _currentSection.name,
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
          sectionName: _currentSection.name,
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
          sectionName: _currentSection.name,
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
    final currentMarks = _getCurrentMarks();
    final totalMarks = _sections.fold(0.0, (sum, section) => sum + section.totalMarks);
    final optionalMarks = _getOptionalMarks();

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
        // Show marks summary when all sections are complete
        if (_allComplete())
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success10,
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                border: Border.all(color: AppColors.success, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Marks:',
                    style: TextStyle(
                      fontSize: UIConstants.fontSizeMedium,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    currentMarks == totalMarks
                        ? '$currentMarks marks${optionalMarks > 0 ? ' + $optionalMarks optional' : ''}'
                        : '$currentMarks/$totalMarks marks',
                    style: TextStyle(
                      fontSize: UIConstants.fontSizeMedium,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showPreviewAndSubmit() async {
    // Step 0: Silent auto-fixes (no UI, no waiting)
    _applySilentFixes();

    // Step 1: Run AI polish (optional — failure/cancel proceeds with originals)
    final polishedQuestions = await _runAIPolish();

    // Use polished if available, otherwise use originals
    final questionsForReview = polishedQuestions ?? _allQuestions;

    // Step 2: Show review dialog only for ambiguous changes
    // (skip review for minor single-word spelling fixes)
    int ambiguousChanges = 0;
    if (polishedQuestions != null) {
      for (final entry in polishedQuestions.entries) {
        final originals = _allQuestions[entry.key] ?? [];
        for (int i = 0; i < entry.value.length && i < originals.length; i++) {
          if (entry.value[i].text != originals[i].text) {
            // Count words changed — if more than 2 words differ, it's ambiguous
            final origWords = originals[i].text.split(RegExp(r'\s+'));
            final newWords = entry.value[i].text.split(RegExp(r'\s+'));
            int wordDiffs = 0;
            for (int w = 0; w < origWords.length && w < newWords.length; w++) {
              if (origWords[w] != newWords[w]) wordDiffs++;
            }
            wordDiffs += (origWords.length - newWords.length).abs();
            if (wordDiffs > 2) ambiguousChanges++;
          }
        }
      }
    }
    Map<String, List<Question>>? finalQuestions;

    if (ambiguousChanges > 0) {
      finalQuestions = await _showPolishReview(questionsForReview);
      if (finalQuestions == null) {
        // User cancelled at review step — go back, don't submit
        return;
      }
    } else {
      // Minor fixes — auto-accept silently
      finalQuestions = questionsForReview;
    }

    // Step 3: Update questions with reviewed changes
    setState(() {
      _allQuestions = finalQuestions!;
      _aiPolishCompleted = polishedQuestions != null;
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
      paperSections: _sections,
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

  /// Silent auto-fixes applied before AI polish — no UI, instant
  /// 1. Replaces ₹ with Rs. (PDF can't render ₹)
  /// 2. word_forms with long text (>25 chars) auto-switched to short_answer
  void _applySilentFixes() {
    final fixedQuestions = <String, List<Question>>{};
    bool anyChanges = false;

    for (final entry in _allQuestions.entries) {
      final sectionName = entry.key;
      final questions = entry.value;
      final fixedList = <Question>[];

      for (final q in questions) {
        var text = q.text;
        var options = q.options;
        var type = q.type;
        bool changed = false;

        // Fix 1: Replace ₹ with Rs. in text and options
        if (text.contains('\u20B9')) {
          text = text.replaceAll('\u20B9', 'Rs.');
          changed = true;
        }
        if (options != null) {
          final fixedOptions = options.map((o) {
            if (o.contains('\u20B9')) {
              changed = true;
              return o.replaceAll('\u20B9', 'Rs.');
            }
            return o;
          }).toList();
          if (changed) options = fixedOptions;
        }

        // Fix 2: Long word_forms → short_answer
        if (type == 'word_forms' && text.length > 25) {
          type = 'short_answer';
          changed = true;
        }

        if (changed) {
          anyChanges = true;
          fixedList.add(q.copyWith(text: text, options: options, type: type));
        } else {
          fixedList.add(q);
        }
      }
      fixedQuestions[sectionName] = fixedList;
    }

    if (anyChanges) {
      setState(() {
        _allQuestions = fixedQuestions;

        // Update section types if word_forms questions were changed
        _sections = _sections.map((s) {
          final questions = fixedQuestions[s.name] ?? [];
          if (s.type == 'word_forms' && questions.any((q) => q.type == 'short_answer')) {
            return s.copyWith(type: 'short_answer');
          }
          return s;
        }).toList();
      });
    }
  }

  /// Run AI polish on all questions with progress dialog (per-section optimization)
  /// Processes all questions in each section in a single API call for better performance
  /// Supports timeout and cancellation to prevent UI blocking
  Future<Map<String, List<Question>>?> _runAIPolish() async {
    // Calculate total sections with questions
    int nonEmptySections = 0;
    for (var section in _sections) {
      if ((_allQuestions[section.name] ?? []).isNotEmpty) {
        nonEmptySections++;
      }
    }

    if (nonEmptySections == 0) {
      return _allQuestions; // No questions to polish
    }

    // Reset cancellation flag before starting
    _aiPolishCancelled = false;

    // Track progress with ValueNotifier to avoid rebuilding dialog
    final processedSectionsNotifier = ValueNotifier<int>(0);

    // Show loading dialog with cancel callback
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PolishLoadingDialog(
        totalQuestions: nonEmptySections,
        processedQuestionsNotifier: processedSectionsNotifier,
        isPerSection: true,
        onCancel: () {
          // Set cancellation flag
          _aiPolishCancelled = true;
          // Close the dialog
          if (mounted) {
            Navigator.pop(context);
          }
        },
      ),
    );

    try {
      // Wrap entire operation in a timeout to prevent indefinite hanging
      final polished = await _performAIPolish(
        nonEmptySections,
        processedSectionsNotifier,
      ).timeout(
        _aiPolishTimeout,
        onTimeout: () {
          _aiPolishCancelled = true;
          throw Exception('AI Polish operation timed out after ${_aiPolishTimeout.inSeconds} seconds');
        },
      );

      processedSectionsNotifier.dispose();

      if (_aiPolishCancelled) {
        // Dialog already closed by cancel callback
        _showMessage('AI Polish skipped', AppColors.warning);
        return null; // Caller will use originals
      }

      if (mounted) {
        Navigator.pop(context); // Close loading dialog (only if not cancelled)
      }

      return polished;
    } catch (e) {
      // Only pop if cancel callback hasn't already closed the dialog
      if (mounted && !_aiPolishCancelled) {
        Navigator.pop(context);
      }
      processedSectionsNotifier.dispose();
      if (mounted) {
        if (e.toString().contains('timed out')) {
          _showMessage('AI Polish timed out. Proceeding with original questions.', AppColors.warning);
        } else {
          _showMessage('AI Polish unavailable. Proceeding with original questions.', AppColors.warning);
        }
      }
      return null; // Caller will use originals
    }
  }

  /// Perform the actual AI polish operation with cancellation support
  Future<Map<String, List<Question>>?> _performAIPolish(
    int nonEmptySections,
    ValueNotifier<int> processedSectionsNotifier,
  ) async {
    final result = <String, List<Question>>{};

    // Process each section
    for (var section in _sections) {
      // Check if user cancelled
      if (_aiPolishCancelled) {
        return null;
      }

      final sectionName = section.name;
      final sectionQuestions = _allQuestions[sectionName] ?? [];

      if (sectionQuestions.isEmpty) {
        result[sectionName] = [];
        continue;
      }

      try {
        // Polish section using per-section method
        final polishedList = await _polishSectionQuestions(
          sectionQuestions,
          section.type,
        );

        result[sectionName] = polishedList;

        // Update progress
        processedSectionsNotifier.value++;
      } catch (e) {
        // If polishing fails for this section, keep original questions
        result[sectionName] = sectionQuestions;
        processedSectionsNotifier.value++;
      }
    }

    return result;
  }

  /// Polish all questions in a section using batch API for performance
  /// Skips types that AI can't handle well (match, missing_letters, fill_blanks, word_forms)
  Future<List<Question>> _polishSectionQuestions(
    List<Question> sectionQuestions,
    String sectionType,
  ) async {
    // Types to skip — AI tends to corrupt these
    const skipTypes = {'match_following', 'missing_letters', 'fill_in_blanks', 'fill_blanks', 'word_forms'};

    // If entire section should be skipped, return unchanged
    if (skipTypes.contains(sectionType)) {
      return sectionQuestions;
    }

    // Collect polishable question texts and their indices
    final textsToPolish = <String>[];
    final polishableIndices = <int>[];

    for (int i = 0; i < sectionQuestions.length; i++) {
      final q = sectionQuestions[i];
      if (!skipTypes.contains(q.type) && q.text.trim().isNotEmpty) {
        textsToPolish.add(q.text);
        polishableIndices.add(i);
      }
    }

    if (textsToPolish.isEmpty) {
      return sectionQuestions;
    }

    // Batch polish all texts in one API call
    final polishResults = await GroqService.polishSection(
      textsToPolish,
      questionTypes: polishableIndices.map((i) => sectionQuestions[i].type).toList(),
    );

    // Build result list, merging polished texts back
    final result = List<Question>.from(sectionQuestions);
    for (int i = 0; i < polishableIndices.length && i < polishResults.length; i++) {
      final originalIndex = polishableIndices[i];
      final polishResult = polishResults[i];
      final original = sectionQuestions[originalIndex];

      result[originalIndex] = original.copyWith(
        text: polishResult.polished,
        originalText: polishResult.original,
        polishChanges: polishResult.changesSummary,
      );
    }

    return result;
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
        paperSections: _sections,
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

    if (sectionComplete && _currentSectionIndex < _sections.length - 1) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _currentSectionIndex++);
      });
    }
  }

  bool _allComplete() {
    for (var section in _sections) {
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
        paperSections: _sections,
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
        paperSections: _sections,
        questions: _allQuestions,
        examType: widget.examType,
        examDate: widget.examDate,
        examNumber: widget.examNumber,
        subject: widget.selectedSubjects.map((s) => s.name).join(', '),
        grade: 'Grade ${widget.gradeLevel}',
        gradeLevel: widget.gradeLevel,
        selectedSections: widget.selectedSections,
        tenantId: widget.isEditing ? (widget.existingTenantId ?? tenantId) : tenantId,
        examTimetableEntryId: widget.examTimetableEntryId, // Preserve for auto-assigned draft papers
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

      // Auto-save as draft when submission fails
      final userStateService = sl<UserStateService>();
      final userId = userStateService.currentUserId;
      final tenantId = userStateService.currentTenantId;

      if (userId != null && tenantId != null) {
        final now = DateTime.now();
        final draftPaper = QuestionPaperEntity(
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
          paperSections: _sections,
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

        // Save as draft silently (show success message)
        context.read<QuestionPaperBloc>().add(SaveDraft(draftPaper));
        UiHelpers.showSuccessMessage(context, 'Paper saved as draft due to submission error');
      }
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
        sections: _sections,
        totalQuestions: _sections.fold(0, (sum, s) => sum + s.questions),
        totalMarks: _sections.fold(0.0, (sum, s) => sum + s.totalMarks).toInt(),
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
    } catch (e) {
      // Show error for debugging
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