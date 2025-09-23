import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/routes/app_routes.dart';
import '../../domain/entities/question_paper_entity.dart';
import '../../domain/entities/paper_status.dart';
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

  @override
  void initState() {
    super.initState();
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
      _showMessage(state.message, AppColors.success);
      if (state.actionType == 'submit') {
        setState(() => _isSubmitting = false);
        Future.delayed(const Duration(seconds: 1), () => mounted ? context.go(AppRoutes.home) : null);
      } else if (state.actionType == 'pull') {
        setState(() => _isPulling = false);
        // Navigate to edit page - this will be handled by the BLoC success state
        Future.delayed(const Duration(seconds: 1), () => mounted ? context.go(AppRoutes.home) : null);
      }
    }
    if (state is QuestionPaperError) {
      setState(() => _isSubmitting = _isPulling = false);
      _showMessage(state.message, AppColors.error);
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
                const SizedBox(height: 4),
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
    if (state is QuestionPaperLoading) return _buildState(Icons.refresh, 'Loading paper details...', null);
    if (state is QuestionPaperError) return _buildState(Icons.error_outline_rounded, 'Failed to Load Paper', state.message);
    if (state is QuestionPaperLoaded) {
      if (state.currentPaper == null) return _buildState(Icons.description_outlined, 'Paper Not Found', 'The requested paper could not be found.');
      return _buildPaperContent(state.currentPaper!);
    }
    return _buildState(Icons.refresh, 'Loading...', null);
  }

  Widget _buildState(IconData icon, String title, String? message) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon == Icons.refresh)
              SizedBox(
                width: 40, height: 40,
                child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation(AppColors.primary)),
              )
            else
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: (icon == Icons.error_outline_rounded ? AppColors.error : AppColors.textTertiary).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, size: 40, color: icon == Icons.error_outline_rounded ? AppColors.error : AppColors.textTertiary),
              ),
            const SizedBox(height: 24),
            Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 32),
            if (icon == Icons.error_outline_rounded)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => context.read<QuestionPaperBloc>().add(LoadPaperById(widget.questionPaperId)),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: _navigateBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Go Back'),
                  ),
                ],
              )
            else
              ElevatedButton.icon(
                onPressed: _navigateBack,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Go Back'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaperContent(QuestionPaperEntity paper) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildOverview(paper),
              const SizedBox(height: 16),
              _buildActions(paper),
              const SizedBox(height: 24),
              _buildInfo(paper),
              const SizedBox(height: 24),
              _buildSummary(paper),
              const SizedBox(height: 24),
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
          colors: [AppColors.primary.withOpacity(0.05), AppColors.secondary.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('${paper.subject} • ${paper.examType}', style: TextStyle(fontSize: 16, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    if (paper.gradeLevel != null) ...[
                      const SizedBox(height: 4),
                      Text(paper.gradeAndSectionsDisplay, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    ],
                  ],
                ),
              ),
              _buildStatusChip(paper.status),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStat(Icons.quiz_rounded, '${paper.totalQuestions}', 'Questions'),
              const SizedBox(width: 24),
              _buildStat(Icons.grade_rounded, '${paper.totalMarks}', 'Marks'),
              const SizedBox(width: 24),
              _buildStat(Icons.access_time_rounded, paper.examTypeEntity.formattedDuration, 'Duration'),
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
            Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(status.displayName.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _buildActions(QuestionPaperEntity paper) {
    final actions = <Widget>[];

    // For DRAFT papers only - show edit and submit
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

    // For REJECTED papers only - show edit again (creates new draft)
    if (paper.status == PaperStatus.rejected && !widget.isViewOnly) {
      actions.add(_buildActionBtn(
          Icons.edit_note_rounded,
          'Edit Again',
          AppColors.accent,
              () => _pullForEditing(paper),
          _isPulling
      ));
    }

    // For SUBMITTED papers - no actions for teacher (admin handles these)
    // For APPROVED papers - no actions needed

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildInfo(QuestionPaperEntity paper) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Paper Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.person_rounded, 'Created by', paper.createdBy),
          if (paper.gradeLevel != null)
            _buildInfoRow(Icons.school_rounded, 'Grade Level', paper.gradeDisplayName),
          if (paper.selectedSections.isNotEmpty)
            _buildInfoRow(Icons.class_rounded, 'Sections', paper.sectionsDisplayName),
          _buildInfoRow(Icons.calendar_today_rounded, 'Created', _formatDate(paper.createdAt)),
          _buildInfoRow(Icons.update_rounded, 'Last modified', _formatDate(paper.modifiedAt)),
          if (paper.submittedAt != null) _buildInfoRow(Icons.send_rounded, 'Submitted', _formatDate(paper.submittedAt!)),
          if (paper.reviewedAt != null) _buildInfoRow(Icons.rate_review_rounded, 'Reviewed', _formatDate(paper.reviewedAt!)),
          if (paper.rejectionReason != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withOpacity(0.2)),
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
                  const SizedBox(height: 12),
                  Text(paper.rejectionReason!, style: TextStyle(fontSize: 14, color: AppColors.error.withOpacity(0.8), height: 1.4)),
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
                Text(label, style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Question Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          ...paper.examTypeEntity.sections.map((section) {
            final questions = paper.questions[section.name] ?? [];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(section.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        Text('${questions.length} questions • ${section.marksPerQuestion} marks each', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Text('${questions.length * section.marksPerQuestion} marks', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildQuestions(QuestionPaperEntity paper) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Questions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          ...paper.questions.entries.map((entry) => _buildSection(entry.key, entry.value)),
        ],
      ),
    );
  }

  Widget _buildSection(String name, List<dynamic> questions) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(8)),
          child: Text('$name (${questions.length} questions)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        ),
        ...questions.asMap().entries.map((e) => _buildQuestion(e.key + 1, e.value)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildQuestion(int index, dynamic question) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text('$index', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(question.text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary, height: 1.4)),
                if (question.options != null && question.options!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...question.options!.asMap().entries.map((optionEntry) {
                    final label = String.fromCharCode(65 + (optionEntry.key as int));
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(color: AppColors.textTertiary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                            child: Center(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(optionEntry.value, style: TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.3))),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text('${question.marks} marks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _navigateBack() {
    try {
      context.canPop() ? context.pop() : context.go(AppRoutes.home);
    } catch (_) {
      context.go(AppRoutes.home);
    }
  }

  void _editPaper(QuestionPaperEntity paper) {
    print('Navigating to edit page for paper: ${paper.id}');
    print('Paper Status: ${paper.status}');
    print('Can Edit: ${paper.canEdit}');
    print('Edit Route: ${AppRoutes.questionPaperEditWithId(paper.id)}');

    try {
      // Navigate to the dedicated edit page
      context.go(AppRoutes.questionPaperEditWithId(paper.id));
    } catch (e) {
      print('Navigation error: $e');
      _showMessage('Navigation failed. Please try again.', AppColors.error);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    final time = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    if (diff.inDays == 0) return 'Today at $time';
    if (diff.inDays == 1) return 'Yesterday at $time';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}