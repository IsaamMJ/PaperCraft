import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../../core/presentation/routes/app_routes.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../../core/presentation/utils/ui_helpers.dart';
import '../../../../core/presentation/widgets/common_state_widgets.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../../paper_workflow/domain/entities/question_entity.dart';
import '../../../paper_workflow/domain/entities/question_paper_entity.dart';
import '../../../paper_workflow/presentation/bloc/question_paper_bloc.dart';
import '../../../paper_workflow/presentation/widgets/admin_action_buttons.dart';
import '../../../paper_workflow/presentation/widgets/paper_status_badge.dart';

class PaperReviewPage extends StatefulWidget {
  final String paperId;

  const PaperReviewPage({
    super.key,
    required this.paperId,
  });

  @override
  State<PaperReviewPage> createState() => _PaperReviewPageState();
}

class _PaperReviewPageState extends State<PaperReviewPage> {
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _checkAdminAndLoad();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _checkAdminAndLoad() {
    final isAdmin = sl<UserStateService>().isAdmin;
    if (!isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go(AppRoutes.home);
          UiHelpers.showErrorMessage(context, 'Admin access required');
        }
      });
    } else {
      _loadPaper();
    }
  }

  void _loadPaper() {
    context.read<QuestionPaperBloc>().add(LoadPaperById(widget.paperId));
  }

  void _handleApprove(QuestionPaperEntity paper) async {
    final confirm = await _showConfirmDialog(
      title: 'Approve Paper',
      content: 'Are you sure you want to approve "${paper.title}"?\n\nOnce approved, this paper will be available in the question bank.',
      confirmText: 'Approve',
      confirmColor: AppColors.success,
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      context.read<QuestionPaperBloc>().add(ApprovePaper(paper.id));
    }
  }

  void _handleReject(QuestionPaperEntity paper) {
    showDialog(
      context: context,
      builder: (context) => RejectPaperDialog(
        paperTitle: paper.title,
        onReject: (reason) {
          setState(() => _isLoading = true);
          context.read<QuestionPaperBloc>().add(RejectPaper(paper.id, reason));
        },
      ),
    );
  }

  // ADDED: Handle edit request from admin
  void _handleEdit(QuestionPaperEntity paper) {
    // Navigate to paper edit page as admin
    context.push(AppRoutes.questionPaperEditWithId(paper.id));
  }

  // ADDED: Handle restore spare paper
  void _handleRestore(QuestionPaperEntity paper) async {
    final confirm = await _showConfirmDialog(
      title: 'Restore Spare Paper',
      content: 'Are you sure you want to restore "${paper.title}" from spare?\n\nIt will be marked as submitted for review.',
      confirmText: 'Restore',
      confirmColor: Colors.orange.shade600,
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      context.read<QuestionPaperBloc>().add(RestoreSparePaper(paper.id));
    }
  }

  // ADDED: Handle mark paper as spare
  void _handleMarkSpare(QuestionPaperEntity paper) async {
    final confirm = await _showConfirmDialog(
      title: 'Mark as Spare',
      content: 'Are you sure you want to mark "${paper.title}" as spare?\n\nIt will be archived as a backup paper.',
      confirmText: 'Mark as Spare',
      confirmColor: Colors.orange.shade600,
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      context.read<QuestionPaperBloc>().add(MarkPaperAsSpare(paper.id));
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
    required String confirmText,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
        ),
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              ),
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundState() {
    return const Center(
      child: EmptyMessageWidget(
        icon: Icons.description_outlined,
        title: 'Paper Not Found',
        message: 'The requested paper could not be found.',
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return DateFormat('MMM dd, yyyy at HH:mm').format(date);
  }

  void _showPostActionOptions(String? actionType) {
    final isRejection = actionType == 'reject';
    final title = isRejection ? 'Paper Rejected' : 'Paper Approved';
    final subtitle = isRejection
        ? 'The teacher has been notified with your feedback.'
        : 'The paper is now available in the question bank.';

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(UIConstants.radiusXLarge)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(UIConstants.paddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isRejection ? Icons.check_circle : Icons.check_circle_outline,
              color: isRejection ? AppColors.error : AppColors.success,
              size: 48,
            ),
            SizedBox(height: UIConstants.spacing16),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: UIConstants.spacing8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: UIConstants.spacing24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go(AppRoutes.adminDashboard);
                },
                icon: const Icon(Icons.dashboard),
                label: const Text('Back to Dashboard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                  ),
                ),
              ),
            ),
            SizedBox(height: UIConstants.spacing12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Stay on current page (will show empty state or navigate back)
                },
                icon: const Icon(Icons.close),
                label: const Text('Close'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Paper'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            onPressed: _loadPaper,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: BlocListener<QuestionPaperBloc, QuestionPaperState>(
        listener: (context, state) {
          if (state is QuestionPaperSuccess) {
            setState(() => _isLoading = false);
            UiHelpers.showSuccessMessage(context, state.message);

            // Show post-action options instead of immediate redirect
            _showPostActionOptions(state.actionType);
          } else if (state is QuestionPaperError) {
            setState(() => _isLoading = false);
            UiHelpers.showErrorMessage(context, state.message);
          }
        },
        child: BlocBuilder<QuestionPaperBloc, QuestionPaperState>(
          builder: (context, state) {
            if (state is QuestionPaperLoading) {
              return const LoadingWidget(message: 'Loading paper...');
            }

            if (state is QuestionPaperLoaded && state.currentPaper != null) {
              return _buildPaperReview(state.currentPaper!);
            }

            if (state is QuestionPaperError) {
              return ErrorStateWidget(
                message: state.message,
                onRetry: _loadPaper,
              );
            }

            return _buildNotFoundState();
          },
        ),
      ),
    );
  }

  Widget _buildPaperReview(QuestionPaperEntity paper) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.all(UIConstants.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPaperHeader(paper),
                SizedBox(height: UIConstants.spacing24),
                _buildPaperInfo(paper),
                SizedBox(height: UIConstants.spacing24),
                _buildQuestionsSection(paper),
                if (paper.status.isRejected && paper.rejectionReason != null) ...[
                  SizedBox(height: UIConstants.spacing24),
                  _buildRejectionFeedback(paper),
                ],
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
        if (paper.status.isSubmitted) _buildBottomActions(paper),
      ],
    );
  }

  Widget _buildPaperHeader(QuestionPaperEntity paper) {
    return Card(
      elevation: UIConstants.elevationMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
      ),
      child: Padding(
        padding: EdgeInsets.all(UIConstants.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    paper.title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                PaperStatusBadge(status: paper.status),
              ],
            ),
            SizedBox(height: UIConstants.spacing12),
            Row(
              children: [
                Icon(
                  Icons.person,
                  size: UIConstants.iconSmall,
                  color: AppColors.textSecondary,
                ),
                SizedBox(width: UIConstants.spacing4),
                Text(
                  'Created by: ${paper.createdBy}',
                  style: TextStyle(
                    fontSize: UIConstants.fontSizeMedium,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(width: UIConstants.spacing16),
                Icon(
                  Icons.schedule,
                  size: UIConstants.iconSmall,
                  color: AppColors.textSecondary,
                ),
                SizedBox(width: UIConstants.spacing4),
                Text(
                  'Submitted: ${_formatDate(paper.submittedAt)}',
                  style: TextStyle(
                    fontSize: UIConstants.fontSizeMedium,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaperInfo(QuestionPaperEntity paper) {
    return Card(
      elevation: UIConstants.elevationMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
      ),
      child: Padding(
        padding: EdgeInsets.all(UIConstants.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paper Information',
              style: TextStyle(
                fontSize: UIConstants.fontSizeXLarge,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: UIConstants.spacing16),
            _buildInfoRow('Subject', paper.subject ?? 'Unknown Subject'),
            _buildInfoRow('Sections', '${paper.paperSections.length} sections'),
            _buildInfoRow('Total Questions', paper.totalQuestions.toString()),
            _buildInfoRow('Total Marks', paper.totalMarks.toString()),
            SizedBox(height: UIConstants.spacing16),
            Text(
              'Section Breakdown:',
              style: TextStyle(
                fontSize: UIConstants.fontSizeMedium,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: UIConstants.spacing8),
            ...paper.paperSections.map((section) {
              final sectionQuestions = paper.questions[section.name] ?? [];
              return Padding(
                padding: EdgeInsets.only(
                  left: UIConstants.paddingMedium,
                  bottom: UIConstants.spacing4,
                ),
                child: Text(
                  '• ${section.name}: ${sectionQuestions.length}/${section.questions} questions (${section.marksPerQuestion} marks each)',
                  style: TextStyle(
                    fontSize: UIConstants.fontSizeSmall,
                    color: AppColors.textSecondary,
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: UIConstants.spacing4 / 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: UIConstants.fontSizeMedium,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: UIConstants.fontSizeMedium,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsSection(QuestionPaperEntity paper) {
    return Card(
      elevation: UIConstants.elevationMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
      ),
      child: Padding(
        padding: EdgeInsets.all(UIConstants.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Questions',
                  style: TextStyle(
                    fontSize: UIConstants.fontSizeXLarge,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${paper.totalQuestions} questions • ${paper.totalMarks} marks',
                  style: TextStyle(
                    fontSize: UIConstants.fontSizeMedium,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            SizedBox(height: UIConstants.spacing20),
            ...paper.paperSections.map((section) {
              final questions = paper.questions[section.name] ?? [];
              if (questions.isEmpty) return const SizedBox.shrink();

              return _buildSectionQuestions(section.name, questions);
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionQuestions(String sectionName, List<Question> questions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            vertical: UIConstants.spacing12,
            horizontal: UIConstants.paddingMedium,
          ),
          decoration: BoxDecoration(
            color: AppColors.primary10,
            borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
            border: Border.all(color: AppColors.primary30),
          ),
          child: Text(
            sectionName,
            style: TextStyle(
              fontSize: UIConstants.fontSizeLarge,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
        SizedBox(height: UIConstants.spacing12),
        ...questions.asMap().entries.map((entry) {
          final index = entry.key;
          final question = entry.value;
          return _buildQuestionCard(index + 1, question);
        }).toList(),
        SizedBox(height: UIConstants.spacing20),
      ],
    );
  }

  Widget _buildQuestionCard(int questionNumber, Question question) {
    return Container(
      margin: EdgeInsets.only(bottom: UIConstants.spacing12),
      padding: EdgeInsets.all(UIConstants.paddingMedium),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        color: AppColors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: UIConstants.spacing8,
                  vertical: UIConstants.spacing4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                ),
                child: Text(
                  'Q$questionNumber',
                  style: TextStyle(
                    fontSize: UIConstants.fontSizeSmall,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: UIConstants.spacing8,
                  vertical: UIConstants.spacing4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary10,
                  borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                ),
                child: Text(
                  '${question.marks} marks',
                  style: TextStyle(
                    fontSize: UIConstants.fontSizeSmall,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              if (question.isOptional) ...[
                SizedBox(width: UIConstants.spacing8),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: UIConstants.spacing8,
                    vertical: UIConstants.spacing4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning10,
                    borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                  ),
                  child: Text(
                    'Optional',
                    style: TextStyle(
                      fontSize: UIConstants.fontSizeSmall,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: UIConstants.spacing12),
          Text(
            question.text,
            style: TextStyle(
              fontSize: UIConstants.fontSizeMedium,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          if (question.options != null && question.options!.isNotEmpty) ...[
            SizedBox(height: UIConstants.spacing12),
            ...question.options!.asMap().entries.map((optionEntry) {
              final optionIndex = optionEntry.key;
              final option = optionEntry.value;
              final isCorrect = question.correctAnswer == option;

              return Padding(
                padding: EdgeInsets.symmetric(vertical: UIConstants.spacing4 / 2),
                child: Row(
                  children: [
                    Text(
                      '${String.fromCharCode(65 + optionIndex)}) ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        option,
                        style: TextStyle(
                          fontSize: 13,
                          color: isCorrect ? AppColors.success : AppColors.textPrimary,
                          fontWeight: isCorrect ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (isCorrect)
                      Icon(
                        Icons.check_circle,
                        size: UIConstants.iconSmall,
                        color: AppColors.success,
                      ),
                  ],
                ),
              );
            }).toList(),
          ],
          if (question.subQuestions.isNotEmpty) ...[
            SizedBox(height: UIConstants.spacing12),
            Text(
              'Sub-questions:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: UIConstants.spacing8),
            ...question.subQuestions.asMap().entries.map((subEntry) {
              final subIndex = subEntry.key;
              final subQuestion = subEntry.value;
              return Padding(
                padding: EdgeInsets.only(
                  left: UIConstants.paddingMedium,
                  bottom: UIConstants.spacing4,
                ),
                child: Text(
                  '${String.fromCharCode(97 + subIndex)}) ${subQuestion.text}',
                  style: TextStyle(
                    fontSize: UIConstants.fontSizeSmall,
                    color: AppColors.textSecondary,
                  ),
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildRejectionFeedback(QuestionPaperEntity paper) {
    return Card(
      elevation: UIConstants.elevationMedium,
      color: AppColors.error05,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
      ),
      child: Padding(
        padding: EdgeInsets.all(UIConstants.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.error),
                SizedBox(width: UIConstants.spacing8),
                Text(
                  'Rejection Feedback',
                  style: TextStyle(
                    fontSize: UIConstants.fontSizeLarge,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
            SizedBox(height: UIConstants.spacing12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(UIConstants.paddingMedium),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                border: Border.all(color: AppColors.error30),
              ),
              child: Text(
                paper.rejectionReason!,
                style: TextStyle(
                  fontSize: UIConstants.fontSizeMedium,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (paper.reviewedAt != null) ...[
              SizedBox(height: UIConstants.spacing8),
              Text(
                'Rejected on: ${_formatDate(paper.reviewedAt)}',
                style: TextStyle(
                  fontSize: UIConstants.fontSizeSmall,
                  color: AppColors.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions(QuestionPaperEntity paper) {
    return Container(
      padding: EdgeInsets.all(UIConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.overlayDark,
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: AdminActionButtons(
        paper: paper,
        isLoading: _isLoading,
        onApprove: () => _handleApprove(paper),
        onReject: () => _handleReject(paper),
        onEdit: () => _handleEdit(paper),  // ADDED: Edit callback
        onRestore: () => _handleRestore(paper),  // ADDED: Restore callback
        onMarkSpare: (paper.status.isSubmitted || paper.status.isApproved) ? () => _handleMarkSpare(paper) : null,  // ADDED: Mark spare callback
        onViewDetails: null,
      ),
    );
  }

}

// RejectPaperDialog Widget
class RejectPaperDialog extends StatefulWidget {
  final String paperTitle;
  final Function(String reason) onReject;

  const RejectPaperDialog({
    super.key,
    required this.paperTitle,
    required this.onReject,
  });

  @override
  State<RejectPaperDialog> createState() => _RejectPaperDialogState();
}

class _RejectPaperDialogState extends State<RejectPaperDialog> {
  final TextEditingController _reasonController = TextEditingController();
  final List<String> _commonReasons = [
    'Questions difficulty level inappropriate for grade',
    'Formatting and structure issues',
    'Answer key errors detected',
    'Content does not match exam type requirements',
    'Grammatical or spelling errors',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  bool get _isReasonValid => _reasonController.text.trim().length >= 10;
  int get _charCount => _reasonController.text.length;

  void _showConfirmation() {
    if (!_isReasonValid) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 12),
            const Text('Confirm Rejection'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Paper: ${widget.paperTitle}', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: UIConstants.spacing16),
            const Text('Rejection Reason:', style: TextStyle(fontWeight: FontWeight.w500)),
            SizedBox(height: UIConstants.spacing8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error10,
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                border: Border.all(color: AppColors.error30),
              ),
              child: Text(_reasonController.text.trim()),
            ),
            SizedBox(height: UIConstants.spacing16),
            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'The teacher will be notified with this feedback.',
                    style: TextStyle(fontSize: 12, color: AppColors.error),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onReject(_reasonController.text.trim());
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              ),
            ),
            child: const Text('Confirm Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
      ),
      title: const Text('Reject Paper'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Paper: ${widget.paperTitle}', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: UIConstants.spacing16),
            const Text('Common reasons:', style: TextStyle(fontWeight: FontWeight.w500)),
            SizedBox(height: UIConstants.spacing8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _commonReasons.map((reason) => ActionChip(
                label: Text(reason, style: TextStyle(fontSize: 12)),
                onPressed: () {
                  setState(() {
                    _reasonController.text = reason;
                  });
                },
                backgroundColor: _reasonController.text == reason
                    ? AppColors.primary10
                    : AppColors.surface,
                side: BorderSide(
                  color: _reasonController.text == reason
                      ? AppColors.primary
                      : AppColors.border,
                ),
              )).toList(),
            ),
            SizedBox(height: UIConstants.spacing16),
            const Text('Or provide custom reason:', style: TextStyle(fontWeight: FontWeight.w500)),
            SizedBox(height: UIConstants.spacing8),
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                hintText: 'Enter rejection reason (minimum 10 characters)...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                ),
                errorText: _charCount > 0 && _charCount < 10
                    ? 'Reason must be at least 10 characters'
                    : null,
                helperText: '$_charCount/500 characters',
                counterText: '',
              ),
              maxLength: 500,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isReasonValid ? _showConfirmation : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
            ),
            disabledBackgroundColor: AppColors.textTertiary,
          ),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}