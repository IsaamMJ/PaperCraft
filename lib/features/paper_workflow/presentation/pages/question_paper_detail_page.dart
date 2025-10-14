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
import '../../domain/services/enhanced_date_formatter.dart';
import '../../domain/services/section_ordering_helper.dart';
import '../../domain/services/user_info_service.dart';
import '../bloc/question_paper_bloc.dart';
import '../bloc/shared_bloc_provider.dart';

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

  // Add user info service
  late final UserInfoService _userInfoService;
  String? _createdByName;
  bool _loadingUserInfo = false;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
    );
  }

  void _handleStateChanges(BuildContext context, QuestionPaperState state) {
    if (state is QuestionPaperSuccess) {
      UiHelpers.showSuccessMessage(context, state.message);
      if (state.actionType == 'submit') {
        setState(() => _isSubmitting = false);
        Future.delayed(const Duration(seconds: 1), () => mounted ? context.go(AppRoutes.home) : null);
      } else if (state.actionType == 'pull') {
        setState(() => _isPulling = false);
        Future.delayed(const Duration(seconds: 1), () => mounted ? context.go(AppRoutes.home) : null);
      }
    }
    if (state is QuestionPaperError) {
      setState(() => _isSubmitting = _isPulling = false);
      UiHelpers.showErrorMessage(context, state.message);
    }

    // Load user info when paper is loaded
    if (state is QuestionPaperLoaded && state.currentPaper != null) {
      _loadUserInfo(state.currentPaper!.createdBy);
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
              if (paper != null) ...[
                SizedBox(height: UIConstants.spacing4),
                Text(
                  paper.title,
                  style: TextStyle(fontSize: 16, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
              _buildOverview(paper),
              SizedBox(height: UIConstants.spacing16),
              _buildActions(paper),
              SizedBox(height: UIConstants.spacing24),
              _buildInfo(paper),
              SizedBox(height: UIConstants.spacing24),
              _buildSummary(paper),
              SizedBox(height: UIConstants.spacing24),
              _buildQuestions(paper),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildOverview(QuestionPaperEntity paper) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withValues(alpha: 0.05), AppColors.secondary.withValues(alpha: 0.05)],
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

    // Print PDF button (visible for draft, submitted, AND approved papers)
    if (paper.status == PaperStatus.draft ||
        paper.status == PaperStatus.submitted ||
        paper.status == PaperStatus.approved) {
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
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
                color: AppColors.error.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
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
                  Text(paper.rejectionReason!, style: TextStyle(fontSize: UIConstants.fontSizeMedium, color: AppColors.error.withValues(alpha: 0.8), height: 1.4)),
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

  Widget _buildSummary(QuestionPaperEntity paper) {
    // Use the new section ordering helper
    final orderedSections = SectionOrderingHelper.getOrderedSections(paper.paperSections, paper.questions);

    return Container(
      padding: const EdgeInsets.all(UIConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Question Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          SizedBox(height: UIConstants.spacing16),
          ...orderedSections.map((orderedSection) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(UIConstants.radiusMedium)),
                    child: Center(
                      child: Text('${orderedSection.sectionNumber}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: UIConstants.fontSizeMedium)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(orderedSection.section.name,
                            style: TextStyle(fontSize: UIConstants.fontSizeMedium, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        Text(SectionOrderingHelper.getSectionSummary(orderedSection),
                            style: TextStyle(fontSize: UIConstants.fontSizeSmall, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Text('${orderedSection.totalMarks} marks',
                      style: TextStyle(fontSize: UIConstants.fontSizeMedium, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ],
              ),
            );
          }),
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Questions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          SizedBox(height: UIConstants.spacing16),
          ...orderedSections.map((orderedSection) =>
              _buildSection(orderedSection.sectionNumber, orderedSection.section.name, orderedSection.questions)),
        ],
      ),
    );
  }


  Widget _buildSection(int sectionNumber, String name, List<dynamic> questions) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(UIConstants.radiusMedium)),
          child: Text(
              'Section $sectionNumber: $name (${questions.length} questions)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        ),
        ...questions.asMap().entries.map((e) => _buildQuestion(e.key + 1, e.value)),
        SizedBox(height: UIConstants.spacing24),
      ],
    );
  }

  Widget _buildQuestion(int index, dynamic question) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(UIConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(UIConstants.radiusMedium)),
            child: Center(child: Text('$index', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: UIConstants.fontSizeMedium))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(question.text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary, height: 1.4)),
                if (question.options != null && question.options!.isNotEmpty) ...[
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
                              decoration: BoxDecoration(color: AppColors.textTertiary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(UIConstants.radiusSmall)),
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
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(UIConstants.radiusMedium)),
            child: Text('${question.marks} marks', style: TextStyle(fontSize: UIConstants.fontSizeSmall, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ),
        ],
      ),
    );
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

  Future<void> _generateAndShowPreview(QuestionPaperEntity paper) async {
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

      // Generate PDF with standard layout
      final pdfBytes = await pdfService.generateStudentPdf(
        paper: paper,
        schoolName: schoolName,
      );

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
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PdfPreviewPage(
              pdfBytes: pdfBytes,
              paperTitle: paper.title,
              layoutType: 'single',
              onRegeneratePdf: (fontMultiplier, spacingMultiplier) async {
                return await pdfService.generateStudentPdf(
                  paper: paper,
                  schoolName: schoolName,
                  fontSizeMultiplier: fontMultiplier,
                  spacingMultiplier: spacingMultiplier,
                );
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
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
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