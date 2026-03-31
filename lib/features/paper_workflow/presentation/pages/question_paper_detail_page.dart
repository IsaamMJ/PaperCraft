import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:papercraft/features/pdf_generation/presentation/pages/pdf_preview_page.dart';
import '../../../pdf_generation/domain/services/pdf_generation_service.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/routes/app_routes.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../../core/presentation/utils/ui_helpers.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../../core/presentation/widgets/common_state_widgets.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../domain/entities/paper_status.dart';
import '../../domain/entities/question_paper_entity.dart';
import '../../domain/entities/question_entity.dart';
import '../../../catalog/domain/entities/paper_section_entity.dart';
import '../../domain/repositories/question_paper_repository.dart';
import '../../domain/services/enhanced_date_formatter.dart';
import '../../domain/services/section_ordering_helper.dart';
import '../../domain/services/user_info_service.dart';
import '../../../../core/ai/services/groq_service.dart';
import '../bloc/question_paper_bloc.dart';
import '../bloc/shared_bloc_provider.dart';
import '../widgets/question_inline_edit_modal.dart';
import '../widgets/section_edit_modal.dart';

class QuestionPaperDetailPage extends StatelessWidget {
  final String questionPaperId;
  final bool isViewOnly;

  const QuestionPaperDetailPage({
    super.key,
    required this.questionPaperId,
    this.isViewOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return SharedBlocProvider(
      child: _DetailView(questionPaperId: questionPaperId, isViewOnly: isViewOnly),
    );
  }
}

class _DetailView extends StatefulWidget {
  final String questionPaperId;
  final bool isViewOnly;

  const _DetailView({required this.questionPaperId, this.isViewOnly = false});

  @override
  State<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends State<_DetailView> with TickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  bool _isSubmitting = false, _isPulling = false;
  bool _isGeneratingPdf = false;
  bool _cancelPdfGeneration = false;
  bool _isApproving = false, _isRejecting = false;

  // Add user info service
  late final UserInfoService _userInfoService;
  String? _createdByName;
  bool _loadingUserInfo = false;

  // AI spelling check — runs automatically on page load
  // Maps "sectionName_questionIndex" -> suggested corrected text
  final Map<String, String> _aiSuggestions = {};
  // Maps "sectionName_questionIndex" -> reason for suggestion
  final Map<String, String> _aiSuggestionReasons = {};
  // Maps "sectionName_questionIndex" -> suggested fixed options
  final Map<String, List<String>> _aiOptionSuggestions = {};
  // Maps "sectionName_questionIndex" -> original text before fix (for undo)
  final Map<String, String> _aiUndoTexts = {};
  // Maps "sectionName_questionIndex" -> original options before fix (for undo)
  final Map<String, List<String>?> _aiUndoOptions = {};
  // Maps "sectionName_questionIndex" -> warning text (no fix, informational only)
  final Map<String, String> _aiWarnings = {};
  bool _isAiChecking = false;
  bool _aiCheckDone = false;

  @override
  void initState() {
    super.initState();
    _userInfoService = sl<UserInfoService>();

    _animController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _animController.forward();
    });
    context.read<QuestionPaperBloc>().add(LoadPaperById(widget.questionPaperId));
  }

  @override
  void didUpdateWidget(covariant _DetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the paper ID changed, load the new paper
    if (oldWidget.questionPaperId != widget.questionPaperId) {
      // Reset user info cache since it's a different paper
      _createdByName = null;
      _loadingUserInfo = false;
      context.read<QuestionPaperBloc>().add(LoadPaperById(widget.questionPaperId));
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // Load user info when paper is loaded
  Future<void> _loadUserInfo(String userId) async {
    if (_loadingUserInfo || _createdByName != null) return;

    setState(() => _loadingUserInfo = true);

    try {
      final fullName = await _userInfoService.getUserFullName(userId);
      if (mounted) {
        setState(() {
          _createdByName = fullName;
          _loadingUserInfo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _createdByName = 'User $userId';
          _loadingUserInfo = false;
        });
      }
    }
  }

  /// Check for characters that won't render correctly in PDF
  void _runPdfSymbolCheck(QuestionPaperEntity paper) {
    const pdfUnsafeChars = {'₹': 'Rs.'};

    for (final entry in paper.questions.entries) {
      final sectionName = entry.key;
      final questions = entry.value;

      for (int i = 0; i < questions.length; i++) {
        String text = questions[i].text;
        bool hasTextChanges = false;
        bool hasOptionChanges = false;

        for (final charEntry in pdfUnsafeChars.entries) {
          if (text.contains(charEntry.key)) {
            text = text.replaceAll(charEntry.key, charEntry.value);
            hasTextChanges = true;
          }
        }

        // Check options too (MCQ, etc.)
        List<String>? fixedOptions;
        if (questions[i].options != null) {
          fixedOptions = questions[i].options!.map((o) {
            String fixed = o;
            for (final charEntry in pdfUnsafeChars.entries) {
              if (fixed.contains(charEntry.key)) {
                fixed = fixed.replaceAll(charEntry.key, charEntry.value);
                hasOptionChanges = true;
              }
            }
            return fixed;
          }).toList();
        }

        if (hasTextChanges || hasOptionChanges) {
          final key = '${sectionName}_$i';
          setState(() {
            _aiSuggestions[key] = text;
            _aiSuggestionReasons[key] = 'Symbol won\'t display in PDF printout';
            if (hasOptionChanges && fixedOptions != null) {
              _aiOptionSuggestions[key] = fixedOptions;
            }
          });
        }

        // Check for type mismatch: long questions in word_forms type
        if (questions[i].type == 'word_forms' && questions[i].text.length > 25) {
          final key = '${sectionName}_$i';
          if (!_aiSuggestions.containsKey(key)) {
            setState(() {
              _aiWarnings[key] = 'Long question in \'Word Forms\' section — may look cramped in PDF';
            });
          }
        }
      }
    }

    // Check "any X" sections for missing optional questions
    for (final entry in paper.questions.entries) {
      final sectionName = entry.key;
      final questions = entry.value;
      final match = RegExp(r'any\s+(\d+)', caseSensitive: false).firstMatch(sectionName);
      if (match == null) continue;

      final requiredCount = int.tryParse(match.group(1) ?? '');
      if (requiredCount == null) continue;

      final optionalCount = questions.where((q) => q.isOptional == true).length;

      // Check if multiple questions typed in one block
      if (questions.length == 1 && questions.first.text.contains(RegExp(r'\d\)'))) {
        final numberedLines = RegExp(r'\d+\)').allMatches(questions.first.text).length;
        if (numberedLines > 1) {
          final key = '${sectionName}_0';
          setState(() {
            _aiWarnings[key] = 'This looks like $numberedLines questions in one block. Add each question separately and mark ${numberedLines - requiredCount} as optional with ☆.';
          });
        }
      } else if (questions.length > requiredCount && optionalCount == 0) {
        final key = '${sectionName}_0';
        if (!_aiWarnings.containsKey(key)) {
          setState(() {
            _aiWarnings[key] = '\'$sectionName\' has ${questions.length} questions but none marked optional. Mark ${questions.length - requiredCount} with ☆ for correct marks.';
          });
        }
      }
    }
  }

  /// Run full AI check (spelling + PDF symbols) — for submitted papers
  Future<void> _runAiSpellingCheck(QuestionPaperEntity paper) async {
    if (_aiCheckDone || _isAiChecking || widget.isViewOnly) return;

    // PDF symbol check runs for submitted + approved
    if (paper.status == PaperStatus.submitted || paper.status == PaperStatus.approved) {
      _runPdfSymbolCheck(paper);
    }

    // AI spelling check only for submitted papers
    if (paper.status != PaperStatus.submitted) {
      setState(() => _aiCheckDone = true);
      return;
    }

    if (GroqService.isDryRun || GroqService.apiKey.isEmpty) return;

    setState(() => _isAiChecking = true);

    const skipTypes = {'match_following', 'missing_letters', 'fill_in_blanks', 'fill_blanks', 'word_forms'};

    try {
      for (final entry in paper.questions.entries) {
        final sectionName = entry.key;
        final questions = entry.value;

        // Skip types AI can't handle
        if (questions.isNotEmpty && skipTypes.contains(questions.first.type)) continue;

        final texts = questions.map((q) => q.text).where((t) => t.trim().isNotEmpty).toList();
        if (texts.isEmpty) continue;

        final results = await GroqService.polishSection(texts);

        for (int i = 0; i < results.length && i < questions.length; i++) {
          if (results[i].hasChanges) {
            final key = '${sectionName}_$i';
            if (mounted) {
              setState(() {
                _aiSuggestions[key] = results[i].polished;
                _aiSuggestionReasons[key] = 'Spelling / grammar fix';
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[AI Check] Failed: $e');
    }

    if (mounted) {
      setState(() {
        _isAiChecking = false;
        _aiCheckDone = true;
      });
    }
  }

  /// Manual AI check for approved papers (triggered by button)
  Future<void> _runManualAiCheck(QuestionPaperEntity paper) async {
    if (_isAiChecking) return;
    if (GroqService.isDryRun || GroqService.apiKey.isEmpty) {
      setState(() => _aiCheckDone = true);
      return;
    }

    setState(() => _isAiChecking = true);

    const skipTypes = {'match_following', 'missing_letters', 'fill_in_blanks', 'fill_blanks', 'word_forms'};

    try {
      for (final entry in paper.questions.entries) {
        final sectionName = entry.key;
        final questions = entry.value;

        if (questions.isNotEmpty && skipTypes.contains(questions.first.type)) continue;

        final texts = questions.map((q) => q.text).where((t) => t.trim().isNotEmpty).toList();
        if (texts.isEmpty) continue;

        final results = await GroqService.polishSection(texts);

        for (int i = 0; i < results.length && i < questions.length; i++) {
          if (results[i].hasChanges) {
            final key = '${sectionName}_$i';
            if (mounted && !_aiSuggestions.containsKey(key)) {
              setState(() {
                _aiSuggestions[key] = results[i].polished;
                _aiSuggestionReasons[key] = 'Spelling / grammar fix';
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[AI Check] Manual check failed: $e');
    }

    if (mounted) {
      setState(() {
        _isAiChecking = false;
        _aiCheckDone = true;
      });
    }
  }

  Future<void> _splitAndFixQuestion(String sectionName, int questionIndex, dynamic question) async {
    // Parse numbered lines from the text block
    final text = question.text as String;
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();

    // Extract individual questions by removing numbering prefixes
    final splitQuestions = <String>[];
    for (final line in lines) {
      // Remove patterns like "1)", "2)", "a)", "b)", leading whitespace
      final cleaned = line.trim().replaceFirst(RegExp(r'^[\d]+\)\s*'), '').replaceFirst(RegExp(r'^[a-z]\)\s*'), '').trim();
      if (cleaned.isNotEmpty) {
        splitQuestions.add(cleaned);
      }
    }

    if (splitQuestions.length <= 1) {
      _showMessage('Could not detect separate questions', AppColors.warning);
      return;
    }

    // Detect "any X" to know how many to mark optional
    final anyMatch = RegExp(r'any\s+(\d+)', caseSensitive: false).firstMatch(sectionName);
    final requiredCount = anyMatch != null ? (int.tryParse(anyMatch.group(1) ?? '') ?? splitQuestions.length) : splitQuestions.length;
    final optionalCount = splitQuestions.length - requiredCount;

    final bloc = context.read<QuestionPaperBloc>();
    final marks = question.marks as double;
    final marksPerQuestion = requiredCount > 0 ? marks / requiredCount : marks / splitQuestions.length;

    // Step 1: Delete the original block question
    // We'll rebuild by updating the paper directly
    final state = bloc.state;
    if (state is! QuestionPaperLoaded || state.currentPaper == null) return;

    final currentPaper = state.currentPaper!;
    final updatedQuestions = Map<String, List<Question>>.from(currentPaper.questions);

    if (!updatedQuestions.containsKey(sectionName)) return;

    final sectionQuestions = List<Question>.from(updatedQuestions[sectionName]!);

    // Remove the original block
    if (questionIndex < sectionQuestions.length) {
      sectionQuestions.removeAt(questionIndex);
    }

    // Add split questions
    for (int i = 0; i < splitQuestions.length; i++) {
      final isOptional = optionalCount > 0 && i >= requiredCount;
      sectionQuestions.insert(questionIndex + i, Question(
        text: splitQuestions[i],
        type: question.type,
        marks: marksPerQuestion,
        isOptional: isOptional,
      ));
    }

    updatedQuestions[sectionName] = sectionQuestions;

    // Update section question count
    final updatedSections = List<PaperSectionEntity>.from(currentPaper.paperSections);
    for (int i = 0; i < updatedSections.length; i++) {
      if (updatedSections[i].name == sectionName) {
        updatedSections[i] = updatedSections[i].copyWith(
          questions: sectionQuestions.length,
          marksPerQuestion: marksPerQuestion,
        );
        break;
      }
    }

    // Save directly via repository
    final updatedPaper = currentPaper.copyWith(
      questions: updatedQuestions,
      paperSections: updatedSections,
    );

    try {
      final repo = sl<QuestionPaperRepository>();
      await repo.updatePaper(updatedPaper);
    } catch (e) {
      debugPrint('[Split & Fix] Save failed: $e');
    }

    // Reload to reflect all changes
    bloc.add(LoadPaperById(widget.questionPaperId));

    setState(() {
      _aiWarnings.remove('${sectionName}_$questionIndex');
    });

    _showMessage('Split into ${splitQuestions.length} questions${optionalCount > 0 ? ' ($optionalCount optional)' : ''}', AppColors.success);
  }

  void _fixAllSuggestions() {
    final bloc = context.read<QuestionPaperBloc>();
    for (final entry in Map<String, String>.from(_aiSuggestions).entries) {
      final parts = entry.key.split('_');
      if (parts.length >= 2) {
        final sectionName = parts.sublist(0, parts.length - 1).join('_');
        final questionIndex = int.tryParse(parts.last);
        if (questionIndex != null) {
          bloc.add(UpdateQuestionInline(
            sectionName: sectionName,
            questionIndex: questionIndex,
            updatedText: entry.value,
            updatedOptions: _aiOptionSuggestions[entry.key],
          ));
        }
      }
    }
    setState(() {
      _aiSuggestions.clear();
      _aiSuggestionReasons.clear();
      _aiOptionSuggestions.clear();
    });
    _showMessage('All fixes applied', AppColors.success);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBackNavigation,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: BlocConsumer<QuestionPaperBloc, QuestionPaperState>(
          listener: _handleStateChanges,
          builder: (context, state) => CustomScrollView(
            slivers: [
              _buildAppBar(state),
              SliverToBoxAdapter(child: _buildContent(state)),
            ],
          ),
        ),
      ),
    );
  }

  void _handleStateChanges(BuildContext context, QuestionPaperState state) {
    // Trigger AI spelling check when paper loads
    if (state is QuestionPaperLoaded && state.currentPaper != null && !_aiCheckDone) {
      _loadUserInfo(state.currentPaper!.createdBy);
      _runAiSpellingCheck(state.currentPaper!);
    }

    if (state is QuestionPaperSuccess) {
      UiHelpers.showSuccessMessage(context, state.message);
      if (state.actionType == 'submit') {
        setState(() => _isSubmitting = false);
        Future.delayed(const Duration(seconds: 1), () => mounted ? context.go(AppRoutes.home) : null);
      } else if (state.actionType == 'pull') {
        setState(() => _isPulling = false);
        Future.delayed(const Duration(seconds: 1), () => mounted ? context.go(AppRoutes.home) : null);
      } else if (state.actionType == 'approve') {
        setState(() => _isApproving = false);
        Future.delayed(const Duration(seconds: 1), () => mounted ? context.go(AppRoutes.home) : null);
      } else if (state.actionType == 'reject') {
        setState(() => _isRejecting = false);
        Future.delayed(const Duration(seconds: 1), () => mounted ? context.go(AppRoutes.home) : null);
      }
    }
    if (state is QuestionPaperError) {
      setState(() => _isSubmitting = _isPulling = _isApproving = _isRejecting = false);
      UiHelpers.showErrorMessage(context, state.message);
    }

    if (state is QuestionPaperLoaded) {

      // Load user info when paper is loaded
      if (state.currentPaper != null) {
        _loadUserInfo(state.currentPaper!.createdBy);
      }
    }
  }

  Widget _buildAppBar(QuestionPaperState state) {
    final paper = state is QuestionPaperLoaded ? state.currentPaper : null;
    return SliverAppBar(
      pinned: true,
      expandedHeight: 120,
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary),
        onPressed: _navigateBack,
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
          onPressed: () => context.read<QuestionPaperBloc>().add(LoadPaperById(widget.questionPaperId)),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          padding: EdgeInsets.fromLTRB(16, kToolbarHeight + MediaQuery.of(context).padding.top, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                widget.isViewOnly ? 'View Paper' : 'Paper Details',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(QuestionPaperState state) {

    if (state is QuestionPaperLoading) {
      return const LoadingWidget(message: 'Loading paper details...');
    }
    if (state is QuestionPaperError) {
      return ErrorStateWidget(
        message: state.message,
        onRetry: () => context.read<QuestionPaperBloc>().add(LoadPaperById(widget.questionPaperId)),
      );
    }
    if (state is QuestionPaperLoaded) {
      if (state.currentPaper == null) {
        return const EmptyMessageWidget(
          icon: Icons.description_outlined,
          title: 'Paper Not Found',
          message: 'The requested paper could not be found.',
        );
      }
      return _buildPaperContent(state.currentPaper!);
    }
    return const LoadingWidget(message: 'Loading...');
  }

  Widget _buildPaperContent(QuestionPaperEntity paper) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: const EdgeInsets.all(UIConstants.paddingMedium),
          child: Column(
            children: [
              _buildCombinedHeader(paper),
              SizedBox(height: UIConstants.spacing24),
              _buildQuestions(paper),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildCombinedHeader(QuestionPaperEntity paper) {
    final examDateText = paper.examDate != null
        ? EnhancedDateFormatter.formatForContext(paper.examDate!, DateContext.examDate)
        : 'Not set';
    final createdByText = _loadingUserInfo ? 'Loading...' : (_createdByName ?? 'Unknown');
    final marksText = paper.maxMarks != null
        ? '${paper.totalMarks}/${paper.maxMarks}'
        : '${paper.totalMarks}';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
        boxShadow: [BoxShadow(color: AppColors.black04, blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + Status
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary05, AppColors.secondary08]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            paper.subject ?? 'Unknown Subject',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${paper.examType.displayName} • ${paper.gradeDisplayName} • Section ${paper.sectionsDisplayName}',
                            style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusChip(paper.status),
                  ],
                ),
              ],
            ),
          ),

          // Metadata grid
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildCompactInfo(Icons.event_rounded, 'Exam Date', examDateText)),
                    Expanded(child: _buildCompactInfo(Icons.person_rounded, 'Created by', createdByText)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildCompactInfo(Icons.quiz_rounded, 'Questions', '${paper.totalQuestions}')),
                    Expanded(child: _buildCompactInfo(Icons.grade_rounded, 'Marks', marksText)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildCompactInfo(Icons.library_books_rounded, 'Sections', '${paper.paperSections.length}')),
                    Expanded(child: _buildCompactInfo(Icons.update_rounded, 'Modified', EnhancedDateFormatter.formatForContext(paper.modifiedAt, DateContext.modified))),
                  ],
                ),
              ],
            ),
          ),

          // Rejection reason
          if (paper.rejectionReason != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error05,
                  borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                  border: Border.all(color: AppColors.error20),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(paper.rejectionReason!, style: TextStyle(fontSize: 13, color: AppColors.error80, height: 1.4)),
                    ),
                  ],
                ),
              ),
            ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: _buildActions(paper),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInfo(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverview(QuestionPaperEntity paper) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary05, AppColors.secondary08],
        ),
        borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(paper.title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    SizedBox(height: UIConstants.spacing8),
                    Row(
                      children: [
                        Text('${paper.subject} • ${paper.examType}', style: TextStyle(fontSize: 16, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    if (paper.gradeLevel != null) ...[
                      SizedBox(height: UIConstants.spacing4),
                      Text(paper.gradeAndSectionsDisplay, style: TextStyle(fontSize: UIConstants.fontSizeMedium, color: AppColors.textSecondary)),
                    ],
                  ],
                ),
              ),
              _buildStatusChip(paper.status),
            ],
          ),
          SizedBox(height: UIConstants.spacing20),
          Row(
            children: [
              _buildStat(Icons.quiz_rounded, '${paper.totalQuestions}', 'Questions'),
              const SizedBox(width: 24),
              _buildStat(Icons.grade_rounded, '${paper.totalMarks}', 'Marks'),
              const SizedBox(width: 24),
              _buildStat(Icons.library_books_rounded, '${paper.paperSections.length}', 'Sections'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Text(label, style: TextStyle(fontSize: UIConstants.fontSizeSmall, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusChip(PaperStatus status) {
    final colors = {
      PaperStatus.draft: AppColors.warning,
      PaperStatus.submitted: AppColors.primary,
      PaperStatus.approved: AppColors.success,
      PaperStatus.rejected: AppColors.error,
      PaperStatus.spare: AppColors.warning,
    };
    final color = colors[status]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(status.displayName.toUpperCase(), style: TextStyle(fontSize: UIConstants.fontSizeSmall, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _buildActions(QuestionPaperEntity paper) {
    final actions = <Widget>[];

    // Print PDF button (visible for draft, submitted, approved, AND spare papers)
    if (paper.status == PaperStatus.draft ||
        paper.status == PaperStatus.submitted ||
        paper.status == PaperStatus.approved ||
        paper.status == PaperStatus.spare) {
      actions.add(_buildActionBtn(
          Icons.print_rounded,
          'Print PDF',
          AppColors.accent,
              () => _generateAndShowPreview(paper),
          _isGeneratingPdf
      ));
    }

    if (paper.status == PaperStatus.draft && !widget.isViewOnly) {
      actions.add(_buildActionBtn(
          Icons.edit_rounded,
          'Edit Paper',
          AppColors.primary,
              () => _editPaper(paper)
      ));

      actions.add(_buildActionBtn(
          Icons.send_rounded,
          'Submit for Review',
          AppColors.success,
              () => _submitPaper(paper),
          _isSubmitting
      ));
    }

    if (paper.status == PaperStatus.rejected && !widget.isViewOnly) {
      actions.add(_buildActionBtn(
          Icons.edit_note_rounded,
          'Edit Again',
          AppColors.accent,
              () => _pullForEditing(paper),
          _isPulling
      ));
    }

    // Approve and Reject buttons for submitted papers (admin/reviewer only)
    if (paper.status == PaperStatus.submitted && !widget.isViewOnly) {
      actions.add(
        Row(
          children: [
            Expanded(
              child: _buildActionBtn(
                Icons.check_circle_rounded,
                'Approve Paper',
                AppColors.success,
                () => _approvePaper(paper),
                _isApproving,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionBtn(
                Icons.cancel_rounded,
                'Reject Paper',
                AppColors.error,
                () => _showRejectDialog(paper),
                _isRejecting,
              ),
            ),
          ],
        ),
      );
    }

    // Mark as Spare button for approved papers (admin/reviewer only, NOT for office staff)
    if (paper.status == PaperStatus.approved && !widget.isViewOnly) {
      final userStateService = sl<UserStateService>();
      final isOfficeStaff = userStateService.isOfficeStaff;

      if (!isOfficeStaff) {
        actions.add(
          _buildActionBtn(
            Icons.bookmark_outline,
            'Mark as Spare',
            AppColors.warning,
            () => _markPaperAsSpare(paper),
          ),
        );

        // AI Check Spelling button for approved papers (manual trigger)
        if (!_aiCheckDone || _aiSuggestions.isNotEmpty) {
          actions.add(
            _buildActionBtn(
              Icons.auto_fix_high,
              _isAiChecking ? 'Checking...' : 'AI Check Spelling',
              Colors.amber.shade700,
              _isAiChecking ? () {} : () {
                setState(() {
                  _aiCheckDone = false;
                  _aiSuggestions.clear();
                  _aiSuggestionReasons.clear();
                });
                _runPdfSymbolCheck(paper);
                _runManualAiCheck(paper);
              },
              _isAiChecking,
            ),
          );
        }
      }
    }

    return actions.isEmpty ? const SizedBox.shrink() : Column(children: actions);
  }

  Widget _buildActionBtn(IconData icon, String label, Color color, VoidCallback onPressed, [bool loading = false]) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onPressed,
        icon: loading
            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
            : Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UIConstants.radiusLarge)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildInfo(QuestionPaperEntity paper) {
    return Container(
      padding: const EdgeInsets.all(UIConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
        boxShadow: [BoxShadow(color: AppColors.black04, blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Paper Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          SizedBox(height: UIConstants.spacing16),
          if (paper.examDate != null)
            _buildInfoRow(Icons.event_rounded, 'Exam Date',
                EnhancedDateFormatter.formatForContext(paper.examDate!, DateContext.examDate)),
          _buildInfoRow(Icons.person_rounded, 'Created by',
              _loadingUserInfo
                  ? 'Loading...'
                  : (_createdByName ?? 'User ${paper.createdBy}')),
          if (paper.gradeLevel != null)
            _buildInfoRow(Icons.school_rounded, 'Grade Level', paper.gradeDisplayName),
          // FIX: Added null check before accessing isNotEmpty
          if (paper.selectedSections != null && paper.selectedSections!.isNotEmpty)
            _buildInfoRow(Icons.class_rounded, 'Sections', paper.sectionsDisplayName),
          _buildInfoRow(Icons.calendar_today_rounded, 'Created',
              EnhancedDateFormatter.formatForContext(paper.createdAt, DateContext.created)),
          _buildInfoRow(Icons.update_rounded, 'Last modified',
              EnhancedDateFormatter.formatForContext(paper.modifiedAt, DateContext.modified)),
          if (paper.submittedAt != null)
            _buildInfoRow(Icons.send_rounded, 'Submitted',
                EnhancedDateFormatter.formatForContext(paper.submittedAt!, DateContext.submitted)),
          if (paper.reviewedAt != null)
            _buildInfoRow(Icons.rate_review_rounded, 'Reviewed',
                EnhancedDateFormatter.formatForContext(paper.reviewedAt!, DateContext.reviewed)),
          if (paper.rejectionReason != null) ...[
            SizedBox(height: UIConstants.spacing16),
            Container(
              padding: const EdgeInsets.all(UIConstants.paddingMedium),
              decoration: BoxDecoration(
                color: AppColors.error05,
                borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                border: Border.all(color: AppColors.error20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                      Text('Rejection Feedback', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.error)),
                    ],
                  ),
                  SizedBox(height: UIConstants.spacing12),
                  Text(paper.rejectionReason!, style: TextStyle(fontSize: UIConstants.fontSizeMedium, color: AppColors.error80, height: 1.4)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: UIConstants.fontSizeMedium, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 16, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestions(QuestionPaperEntity paper) {
    // Use ordered sections for questions display
    if (paper.questions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(UIConstants.paddingLarge),
          child: Text(
            'No questions added yet',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: UIConstants.fontSizeMedium,
            ),
          ),
        ),
      );
    }

    final orderedSections = SectionOrderingHelper.getOrderedSections(paper.paperSections, paper.questions);

    return Container(
      padding: const EdgeInsets.all(UIConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
        boxShadow: [BoxShadow(color: AppColors.black04, blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Questions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const Spacer(),
              if (_isAiChecking)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber.shade700)),
                    const SizedBox(width: 6),
                    Text('Checking spelling...', style: TextStyle(fontSize: 12, color: Colors.amber.shade700)),
                  ],
                ),
              if (!_isAiChecking && _aiSuggestions.isNotEmpty)
                GestureDetector(
                  onTap: _fixAllSuggestions,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_fix_high, size: 14, color: Colors.amber.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Fix All (${_aiSuggestions.length})',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber.shade700),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!_isAiChecking && _aiWarnings.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(left: _aiSuggestions.isNotEmpty ? 6 : 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange.shade700),
                        const SizedBox(width: 4),
                        Text(
                          '${_aiWarnings.length} warning${_aiWarnings.length == 1 ? '' : 's'}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange.shade700),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: UIConstants.spacing16),
          ...orderedSections.map((orderedSection) =>
              _buildSection(orderedSection.sectionNumber, orderedSection.section.name, orderedSection.section.type, orderedSection.questions)),
        ],
      ),
    );
  }


  Widget _buildSection(int sectionNumber, String name, String type, List<dynamic> questions) {
    // Get display name for the question type
    String typeDisplayName;
    switch (type) {
      case 'multiple_choice':
        typeDisplayName = 'Multiple Choice';
        break;
      case 'short_answer':
        typeDisplayName = 'Short Answer';
        break;
      case 'fill_in_blanks':
      case 'fill_blanks':
        typeDisplayName = 'Fill in the blanks';
        break;
      case 'true_false':
        typeDisplayName = 'True/False';
        break;
      case 'match_following':
        typeDisplayName = 'Match the Following';
        break;
      case 'word_forms':
        typeDisplayName = 'Word Forms';
        break;
      default:
        typeDisplayName = type;
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(UIConstants.radiusMedium)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Section $sectionNumber: $name (${questions.length} questions)',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            typeDisplayName,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
                          ),
                        ),
                        if (!widget.isViewOnly && type == 'word_forms' && _aiWarnings.keys.any((k) => k.startsWith('${name}_')))
                          GestureDetector(
                            onTap: () {
                              context.read<QuestionPaperBloc>().add(UpdateSectionType(sectionName: name, newType: 'short_answer'));
                              setState(() {
                                _aiWarnings.removeWhere((k, _) => k.startsWith('${name}_'));
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.swap_horiz, size: 12, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Switch to Short Answer',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!widget.isViewOnly)
                IconButton(
                  icon: const Icon(Icons.edit, size: 18, color: Colors.white),
                  onPressed: () => _showEditSectionModal(name, sectionNumber, type),
                  tooltip: 'Edit section',
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
        ),
        // Shared word bank for fill_blanks sections (displayed once below header)
        if (questions.isNotEmpty &&
            (questions.first.type == 'fill_blanks' || questions.first.type == 'fill_in_blanks')) ...[
          Builder(builder: (_) {
            final allWords = <String>{};
            for (final q in questions) {
              if (q.options != null) allWords.addAll(q.options!);
            }
            if (allWords.isEmpty) return const SizedBox.shrink();
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary10,
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Word Bank:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allWords.map((word) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                          border: Border.all(color: AppColors.primary, width: 1),
                        ),
                        child: Text(word, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primary)),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),
        ],
        ...questions.asMap().entries.map((e) => _buildQuestion(e.key + 1, e.value, name)),
        if (!widget.isViewOnly) _buildAddQuestionButton(name, type),
        SizedBox(height: UIConstants.spacing24),
      ],
    );
  }

  Widget _buildQuestion(int index, dynamic question, String sectionName) {
    final bool isOptional = question.isOptional ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(UIConstants.paddingMedium),
      decoration: BoxDecoration(
        color: isOptional ? Colors.orange.shade50 : AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        border: Border.all(color: isOptional ? Colors.orange.shade200 : AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: isOptional ? Colors.orange : AppColors.primary, borderRadius: BorderRadius.circular(UIConstants.radiusMedium)),
            child: Center(child: Text('$index', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: UIConstants.fontSizeMedium))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isOptional)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('Optional', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.orange.shade800)),
                    ),
                  ),
                Text(question.text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary, height: 1.4)),
                // Undo button (appears after fix, auto-expires in 10s)
                Builder(builder: (_) {
                  final undoKey = '${sectionName}_${index - 1}';
                  final undoText = _aiUndoTexts[undoKey];
                  if (undoText == null) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.only(top: 4),
                    child: GestureDetector(
                      onTap: () {
                        context.read<QuestionPaperBloc>().add(
                          UpdateQuestionInline(
                            sectionName: sectionName,
                            questionIndex: index - 1,
                            updatedText: undoText,
                            updatedOptions: _aiUndoOptions[undoKey],
                          ),
                        );
                        setState(() {
                          _aiUndoTexts.remove(undoKey);
                          _aiUndoOptions.remove(undoKey);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.undo, size: 13, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text('Undo', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                // AI spelling suggestion (inline)
                Builder(builder: (_) {
                  final suggestionKey = '${sectionName}_${index - 1}';
                  final suggestion = _aiSuggestions[suggestionKey];
                  if (suggestion == null) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.auto_fix_high, size: 14, color: Colors.amber.shade700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_aiSuggestionReasons.containsKey(suggestionKey))
                                Text(
                                  _aiSuggestionReasons[suggestionKey]!,
                                  style: TextStyle(fontSize: 10, color: Colors.amber.shade800, fontWeight: FontWeight.w600),
                                ),
                              Text(
                                suggestion,
                                style: TextStyle(fontSize: 13, color: Colors.amber.shade900, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            // Store original for undo
                            final originalText = question.text;
                            final originalOptions = question.options;
                            // Accept: update the question text and options
                            context.read<QuestionPaperBloc>().add(
                              UpdateQuestionInline(
                                sectionName: sectionName,
                                questionIndex: index - 1,
                                updatedText: suggestion,
                                updatedOptions: _aiOptionSuggestions[suggestionKey],
                              ),
                            );
                            setState(() {
                              _aiUndoTexts[suggestionKey] = originalText;
                              _aiUndoOptions[suggestionKey] = originalOptions;
                              _aiSuggestions.remove(suggestionKey);
                              _aiSuggestionReasons.remove(suggestionKey);
                              _aiOptionSuggestions.remove(suggestionKey);
                            });
                            // Auto-expire undo after 10 seconds
                            Future.delayed(const Duration(seconds: 10), () {
                              if (mounted) {
                                setState(() {
                                  _aiUndoTexts.remove(suggestionKey);
                                  _aiUndoOptions.remove(suggestionKey);
                                });
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Fix', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _aiSuggestions.remove(suggestionKey);
                              _aiSuggestionReasons.remove(suggestionKey);
                            });
                          },
                          child: Icon(Icons.close, size: 16, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }),
                // Warning chip with optional Split & Fix action
                Builder(builder: (_) {
                  final warningKey = '${sectionName}_${index - 1}';
                  final warning = _aiWarnings[warningKey];
                  if (warning == null) return const SizedBox.shrink();
                  final isMultiQuestionBlock = warning.contains('questions in one block');
                  return Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange.shade700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            warning,
                            style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                          ),
                        ),
                        if (isMultiQuestionBlock) ...[
                          GestureDetector(
                            onTap: () => _splitAndFixQuestion(sectionName, index - 1, question),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade700,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Split & Fix', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        GestureDetector(
                          onTap: () => setState(() => _aiWarnings.remove(warningKey)),
                          child: Icon(Icons.close, size: 14, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  );
                }),
                // Options for MCQ and other types (word bank for fill_blanks shown at section level)
                if (question.type != 'fill_blanks' && question.options != null && question.options!.isNotEmpty) ...[
                  SizedBox(height: UIConstants.spacing12),
                  if (question.type == 'match_following' && question.options!.contains('---SEPARATOR---')) ...[
                    _buildMatchingPairsForDetail(question.options!),
                  ] else ...[
                    ...question.options!.asMap().entries.map((optionEntry) {
                      final label = String.fromCharCode(65 + (optionEntry.key as int));
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 24, height: 24,
                              decoration: BoxDecoration(color: AppColors.overlayLight, borderRadius: BorderRadius.circular(UIConstants.radiusSmall)),
                              child: Center(child: Text(label, style: TextStyle(fontSize: UIConstants.fontSizeSmall, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(optionEntry.value, style: TextStyle(fontSize: UIConstants.fontSizeMedium, color: AppColors.textPrimary, height: 1.3))),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
                // Display sub-questions if they exist
                if (_hasSubQuestions(question)) ...[
                  SizedBox(height: UIConstants.spacing12),
                  ..._getSubQuestionsList(question).asMap().entries.map((subQEntry) {
                    final subQLabel = String.fromCharCode(97 + (subQEntry.key as int)); // a, b, c, d...
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 20, height: 20,
                            decoration: BoxDecoration(color: AppColors.primary10, borderRadius: BorderRadius.circular(UIConstants.radiusSmall)),
                            child: Center(child: Text(subQLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary))),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(subQEntry.value.text, style: TextStyle(fontSize: UIConstants.fontSizeSmall, color: AppColors.textPrimary, height: 1.3))),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primary10, borderRadius: BorderRadius.circular(UIConstants.radiusMedium)),
                child: Text('${question.marks} marks', style: TextStyle(fontSize: UIConstants.fontSizeSmall, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ),
              SizedBox(height: UIConstants.spacing8),
              if (!widget.isViewOnly) ...[
                IconButton(
                  icon: Icon(Icons.edit, size: 18, color: AppColors.primary),
                  onPressed: () => _showEditQuestionModal(question, index - 1, sectionName),
                  tooltip: 'Edit question',
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
                IconButton(
                  icon: Icon(
                    isOptional ? Icons.star : Icons.star_border,
                    size: 18,
                    color: isOptional ? Colors.orange : Colors.grey.shade400,
                  ),
                  onPressed: () async {
                    final action = isOptional ? 'required' : 'optional';
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Mark as $action?'),
                        content: Text('Are you sure you want to mark this question as $action?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isOptional ? AppColors.primary : Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                            child: Text('Mark as $action'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      context.read<QuestionPaperBloc>().add(
                        UpdateQuestionInline(
                          sectionName: sectionName,
                          questionIndex: index - 1,
                          updatedText: question.text,
                          isOptional: !isOptional,
                        ),
                      );
                    }
                  },
                  tooltip: isOptional ? 'Mark as required' : 'Mark as optional',
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddQuestionButton(String sectionName, String sectionType) {
    return _AddQuestionInline(
      sectionName: sectionName,
      sectionType: sectionType,
      onAdd: (text, isOptional, {List<String>? options}) {
        context.read<QuestionPaperBloc>().add(
          AddQuestionToSection(
            sectionName: sectionName,
            questionText: text,
            isOptional: isOptional,
            options: options,
          ),
        );
      },
    );
  }

  // FIXED: Handle system back button and swipe-to-go-back gestures
  Future<bool> _handleBackNavigation() async {
    if (context.canPop()) {
      context.pop();
      return false; // Don't exit the app, we handled the back navigation
    } else {
      context.go(AppRoutes.home);
      return false; // Don't exit the app, we navigated to home
    }
  }

  void _navigateBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  void _editPaper(QuestionPaperEntity paper) {
    try {
      context.push(AppRoutes.questionPaperEditWithId(paper.id));
    } catch (e) {
      _showMessage('Navigation failed. Please try again.', AppColors.error);
    }
  }

  void _showEditQuestionModal(Question question, int questionIndex, String sectionName) {

    // Capture the page context to use in callbacks
    final pageContext = context;
    final bloc = context.read<QuestionPaperBloc>();

    // Check if user is admin/reviewer to allow type changes
    final userStateService = sl<UserStateService>();
    final allowTypeChange = userStateService.isAdminOrReviewer && !widget.isViewOnly;

    showDialog(
      context: context,
      builder: (dialogContext) => QuestionInlineEditModal(
        question: question,
        questionIndex: questionIndex,
        sectionName: sectionName,
        allowTypeChange: allowTypeChange,
        onSave: (updatedText, updatedOptions, newType) {

          try {
            bloc.add(
              UpdateQuestionInline(
                sectionName: sectionName,
                questionIndex: questionIndex,
                updatedText: updatedText,
                updatedOptions: updatedOptions,
                newType: newType,
              ),
            );

            // Close the modal
            Navigator.pop(dialogContext);
          } catch (e, stackTrace) {
          }
        },
        onCancel: () {
          Navigator.pop(dialogContext);
        },
      ),
    );
  }

  void _showEditSectionModal(String sectionName, int sectionNumber, String currentType) {

    final bloc = context.read<QuestionPaperBloc>();
    final state = bloc.state;
    final existingNames = state is QuestionPaperLoaded && state.currentPaper != null
        ? state.currentPaper!.paperSections.map((s) => s.name).toList()
        : <String>[];

    showDialog(
      context: context,
      builder: (dialogContext) => SectionEditModal(
        sectionName: sectionName,
        sectionNumber: sectionNumber,
        currentType: currentType,
        existingSectionNames: existingNames,
        onSave: (newName, newType) {

          try {
            if (newName != sectionName) {
              bloc.add(
                UpdateSectionName(
                  oldSectionName: sectionName,
                  newSectionName: newName,
                ),
              );
            }

            if (newType != null && newType != currentType) {
              bloc.add(
                UpdateSectionType(
                  sectionName: newName,
                  newType: newType,
                ),
              );
            }

            // Close the modal
            Navigator.pop(dialogContext);
          } catch (e, stackTrace) {
          }
        },
        onCancel: () {
          Navigator.pop(dialogContext);
        },
      ),
    );
  }

  Future<void> _generateAndShowPreview(QuestionPaperEntity paper) async {
    debugPrint('\n🚀 === PDF GENERATION STARTED ===');
    debugPrint('📝 Paper: ${paper.title}');
    debugPrint('🎯 Total Questions: ${paper.totalQuestions}');
    debugPrint('📊 Total Marks: ${paper.totalMarks}');
    debugPrint('🗂️  Sections: ${paper.questions.keys.join(", ")}');

    setState(() {
      _isGeneratingPdf = true;
      _cancelPdfGeneration = false;
    });

    try {
      // Show loading dialog with cancel option
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(UIConstants.paddingLarge),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: UIConstants.spacing16),
                  Text(
                    'Generating PDF...',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: UIConstants.spacing8),
                  Text(
                    'This may take a few seconds',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: UIConstants.fontSizeSmall,
                    ),
                  ),
                  SizedBox(height: UIConstants.spacing16),
                  TextButton(
                    onPressed: () {
                      setState(() => _cancelPdfGeneration = true);
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final pdfService = SimplePdfService();
      final userStateService = sl<UserStateService>();
      final schoolName = userStateService.schoolName;

      debugPrint('⚙️  Starting PDF generation...');
      debugPrint('   School: $schoolName');
      debugPrint('   Font Multiplier: 1.3');
      debugPrint('   Spacing Multiplier: 1.0');

      // Generate PDF with standard layout
      final pdfBytes = await pdfService.generateStudentPdf(
        paper: paper,
        schoolName: schoolName,
        fontSizeMultiplier: 1.3,
        spacingMultiplier: 1.0,
      );

      debugPrint('✅ PDF Generated Successfully!');
      debugPrint('   Size: ${(pdfBytes.length / 1024).toStringAsFixed(2)} KB');

      // Check if cancelled
      if (_cancelPdfGeneration) {
        if (mounted) {
          setState(() => _isGeneratingPdf = false);
          _showMessage('PDF generation cancelled', AppColors.warning);
        }
        return;
      }

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Navigate directly to preview page
      if (mounted) {
        debugPrint('🔄 Navigating to PDF Preview page...');
        debugPrint('🚀 === PDF GENERATION ENDED ===\n');

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PdfPreviewPage(
              pdfBytes: pdfBytes,
              paperTitle: paper.title,
              layoutType: 'single',
              onRegeneratePdf: (fontMultiplier, spacingMultiplier) async {
                debugPrint('\n🔄 === PDF REGENERATION TRIGGERED ===');
                debugPrint('   Font Multiplier: $fontMultiplier');
                debugPrint('   Spacing Multiplier: $spacingMultiplier');

                final regeneratedPdf = await pdfService.generateStudentPdf(
                  paper: paper,
                  schoolName: schoolName,
                  fontSizeMultiplier: fontMultiplier,
                  spacingMultiplier: spacingMultiplier,
                );

                debugPrint('✅ PDF Regenerated!');
                debugPrint('   Size: ${(regeneratedPdf.length / 1024).toStringAsFixed(2)} KB');
                debugPrint('🔄 === PDF REGENERATION ENDED ===\n');

                return regeneratedPdf;
              },
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        _showMessage('Unable to generate PDF. Please check your paper and try again.', AppColors.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  void _submitPaper(QuestionPaperEntity paper) => _showDialog(
    'Submit Paper',
    'Are you sure you want to submit this paper for review?\n\n• You won\'t be able to edit it until it\'s reviewed\n• The admin will receive it for approval',
    Icons.send_rounded,
    AppColors.success,
    'Submit',
        () {
      setState(() => _isSubmitting = true);
      context.read<QuestionPaperBloc>().add(SubmitPaper(paper));
    },
  );

  Widget _buildMatchingPairsForDetail(List<String> options) {
    int separatorIndex = options.indexOf('---SEPARATOR---');
    if (separatorIndex == -1) return const SizedBox.shrink();

    List<String> leftColumn = options.sublist(0, separatorIndex);
    List<String> rightColumn = options.sublist(separatorIndex + 1);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary05,
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        border: Border.all(color: AppColors.primary20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Column A',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: UIConstants.fontSizeSmall, color: AppColors.primary),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Column B',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: UIConstants.fontSizeSmall, color: AppColors.primary),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          SizedBox(height: UIConstants.spacing8),
          ...List.generate(
            leftColumn.length.compareTo(rightColumn.length) <= 0 ? leftColumn.length : rightColumn.length,
                (i) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      i < leftColumn.length ? leftColumn[i] : '',
                      style: TextStyle(fontSize: UIConstants.fontSizeMedium, color: AppColors.textPrimary),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward, size: 16, color: AppColors.textSecondary),
                  ),
                  Expanded(
                    child: Text(
                      i < rightColumn.length ? rightColumn[i] : '',
                      style: TextStyle(fontSize: UIConstants.fontSizeMedium, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _pullForEditing(QuestionPaperEntity paper) => _showDialog(
    'Edit Again',
    'This will create a new draft copy of this rejected paper.\n\n• A new draft will be created\n• You can edit and resubmit it',
    Icons.edit_note_rounded,
    AppColors.accent,
    'Create Draft',
        () {
      setState(() => _isPulling = true);
      context.read<QuestionPaperBloc>().add(PullForEditing(paper.id));
    },
  );

  void _approvePaper(QuestionPaperEntity paper) => _showDialog(
    'Approve Paper',
    'Are you sure you want to approve this paper?\n\n• This paper will be marked as approved\n• It can be used for exams',
    Icons.check_circle_rounded,
    AppColors.success,
    'Approve',
        () {
      setState(() => _isApproving = true);
      context.read<QuestionPaperBloc>().add(ApprovePaper(paper.id));
    },
  );

  void _markPaperAsSpare(QuestionPaperEntity paper) => _showDialog(
    'Mark as Spare',
    'Are you sure you want to mark this paper as spare?\n\n• This paper will be archived as a backup\n• It can be restored later if needed',
    Icons.bookmark_outline,
    AppColors.warning,
    'Mark as Spare',
        () {
      debugPrint('DEBUG: Mark as Spare clicked for paper: ${paper.id}');
      debugPrint('DEBUG: Paper status: ${paper.status}');
      debugPrint('DEBUG: Paper title: ${paper.title}');
      debugPrint('DEBUG: Paper grade: ${paper.gradeId}');
      debugPrint('DEBUG: Paper subject: ${paper.subjectId}');
      context.read<QuestionPaperBloc>().add(MarkPaperAsSpare(paper.id));
    },
  );

  void _showRejectDialog(QuestionPaperEntity paper) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UIConstants.radiusXLarge)),
        title: Row(
          children: [
            Icon(Icons.cancel_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 12),
            Text('Reject Paper'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please provide a reason for rejection:',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: UIConstants.spacing12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              minLines: 2,
              decoration: InputDecoration(
                hintText: 'e.g., Question formatting needs improvement, Math calculation error...',
                hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(UIConstants.radiusMedium)),
                contentPadding: const EdgeInsets.all(12),
                filled: true,
                fillColor: AppColors.background,
              ),
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                UiHelpers.showErrorMessage(context, 'Please provide a rejection reason');
                return;
              }
              Navigator.pop(ctx);
              setState(() => _isRejecting = true);
              context.read<QuestionPaperBloc>().add(
                RejectPaper(paper.id, reasonController.text.trim()),
              );
            },
            icon: Icon(Icons.cancel_rounded, size: 18),
            label: const Text('Reject'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showDialog(String title, String content, IconData icon, Color color, String actionText, VoidCallback action) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UIConstants.radiusXLarge)),
        title: Row(children: [Icon(icon, color: color, size: 24), const SizedBox(width: 12), Text(title)]),
        content: Text(content, style: TextStyle(height: 1.4, color: AppColors.textPrimary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton.icon(
            onPressed: () {Navigator.pop(ctx); action();},
            icon: Icon(icon, size: 18),
            label: Text(actionText),
            style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  // FIXED: Safe extraction of sub-questions from dynamic question object
  bool _hasSubQuestions(dynamic question) {
    try {
      // Handle case where question is a Question entity
      if (question is Question) {
        return question.subQuestions.isNotEmpty;
      }

      // Handle case where question is a dynamic object with subQuestions property
      final subQuestions = question.subQuestions;
      if (subQuestions != null && subQuestions is List && subQuestions.isNotEmpty) {
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // FIXED: Safe extraction of sub-questions list from dynamic question object
  List<dynamic> _getSubQuestionsList(dynamic question) {
    try {
      // Handle case where question is a Question entity
      if (question is Question) {
        return question.subQuestions;
      }

      // Handle case where question is a dynamic object
      final subQuestions = question.subQuestions;
      if (subQuestions is List) {
        return subQuestions;
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [Icon(color == AppColors.success ? Icons.check_circle_rounded : Icons.error_rounded, color: Colors.white, size: 20), const SizedBox(width: 12), Expanded(child: Text(message))]),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UIConstants.radiusMedium)),
      ),
    );
  }
}

/// Inline add question widget with proper state management
/// Supports regular text input for most types and pair input for match_following
class _AddQuestionInline extends StatefulWidget {
  final String sectionName;
  final String sectionType;
  final Function(String text, bool isOptional, {List<String>? options}) onAdd;

  const _AddQuestionInline({
    required this.sectionName,
    required this.sectionType,
    required this.onAdd,
  });

  @override
  State<_AddQuestionInline> createState() => _AddQuestionInlineState();
}

class _AddQuestionInlineState extends State<_AddQuestionInline> {
  bool _isAdding = false;
  bool _isOptional = false;
  late TextEditingController _controller;

  // Match pair state
  final List<_MatchPair> _matchPairs = [];

  bool get _isMatchType => widget.sectionType == 'match_following';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final pair in _matchPairs) {
      pair.dispose();
    }
    super.dispose();
  }

  void _addMatchPair() {
    setState(() {
      _matchPairs.add(_MatchPair());
    });
  }

  void _removeMatchPair(int index) {
    setState(() {
      _matchPairs[index].dispose();
      _matchPairs.removeAt(index);
    });
  }

  void _resetForm() {
    setState(() {
      _isAdding = false;
      _controller.clear();
      _isOptional = false;
      for (final pair in _matchPairs) {
        pair.dispose();
      }
      _matchPairs.clear();
    });
  }

  void _submitRegular() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onAdd(text, _isOptional);
      _resetForm();
    }
  }

  void _submitMatch() {
    final validPairs = _matchPairs.where((p) => p.left.trim().isNotEmpty && p.right.trim().isNotEmpty).toList();
    if (validPairs.isEmpty) return;

    final leftItems = validPairs.map((p) => p.left.trim()).toList();
    final rightItems = validPairs.map((p) => p.right.trim()).toList();
    final options = [...leftItems, '---SEPARATOR---', ...rightItems];

    widget.onAdd('Match the following', _isOptional, options: options);
    _resetForm();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdding) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: OutlinedButton.icon(
          onPressed: () {
            setState(() => _isAdding = true);
            if (_isMatchType && _matchPairs.isEmpty) {
              _addMatchPair();
            }
          },
          icon: const Icon(Icons.add, size: 16),
          label: Text(_isMatchType ? 'Add Match Pairs' : 'Add Question'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isMatchType) _buildMatchPairInput() else _buildRegularInput(),
          const SizedBox(height: 8),
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _isOptional = !_isOptional),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isOptional ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 20,
                      color: _isOptional ? Colors.orange : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Optional',
                      style: TextStyle(fontSize: 13, color: _isOptional ? Colors.orange : Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _resetForm,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isMatchType ? _submitMatch : _submitRegular,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text(_isMatchType ? 'Add Match' : 'Add'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegularInput() {
    return TextField(
      controller: _controller,
      autofocus: true,
      maxLines: 2,
      minLines: 1,
      decoration: InputDecoration(
        hintText: 'Type your question here...',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.all(10),
        isDense: true,
      ),
    );
  }

  Widget _buildMatchPairInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Expanded(
              child: Text('Column A', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Column B', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ),
            const SizedBox(width: 32),
          ],
        ),
        const SizedBox(height: 8),
        // Pair rows
        ..._matchPairs.asMap().entries.map((entry) {
          final index = entry.key;
          final pair = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: pair.leftController,
                    autofocus: index == _matchPairs.length - 1,
                    decoration: InputDecoration(
                      hintText: 'Left item',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey.shade400),
                ),
                Expanded(
                  child: TextField(
                    controller: pair.rightController,
                    decoration: InputDecoration(
                      hintText: 'Right item',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                GestureDetector(
                  onTap: () => _removeMatchPair(index),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(Icons.close, size: 18, color: Colors.red.shade300),
                  ),
                ),
              ],
            ),
          );
        }),
        // Add pair button
        TextButton.icon(
          onPressed: _addMatchPair,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add pair'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      ],
    );
  }
}

/// Helper class for match pair input
class _MatchPair {
  final TextEditingController leftController;
  final TextEditingController rightController;

  _MatchPair()
      : leftController = TextEditingController(),
        rightController = TextEditingController();

  String get left => leftController.text;
  String get right => rightController.text;

  void dispose() {
    leftController.dispose();
    rightController.dispose();
  }
}