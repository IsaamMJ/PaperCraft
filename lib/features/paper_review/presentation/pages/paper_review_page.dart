import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../../core/presentation/routes/app_routes.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../../core/presentation/utils/ui_helpers.dart';
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: UIConstants.iconHuge,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: UIConstants.spacing16),
          Text(
            'Paper Not Found',
            style: TextStyle(
              fontSize: UIConstants.fontSizeXLarge,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: UIConstants.spacing8),
          Text(
            'The requested paper could not be found.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          SizedBox(height: UIConstants.spacing16),
          ElevatedButton(
            onPressed: () => context.go(AppRoutes.adminDashboard),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              ),
            ),
            child: const Text('Back to Dashboard'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return DateFormat('MMM dd, yyyy at HH:mm').format(date);
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
            context.go(AppRoutes.adminDashboard);
          } else if (state is QuestionPaperError) {
            setState(() => _isLoading = false);
            UiHelpers.showErrorMessage(context, state.message);
          }
        },
        child: BlocBuilder<QuestionPaperBloc, QuestionPaperState>(
          builder: (context, state) {
            if (state is QuestionPaperLoading) {
              return Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              );
            }

            if (state is QuestionPaperLoaded && state.currentPaper != null) {
              return _buildPaperReview(state.currentPaper!);
            }

            if (state is QuestionPaperError) {
              return _buildErrorState(state.message);
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
            _buildInfoRow('Exam Type', paper.examType ?? paper.examTypeEntity.name),
            _buildInfoRow('Duration', paper.examTypeEntity.formattedDuration),
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
            ...paper.examTypeEntity.sections.map((section) {
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
            ...paper.examTypeEntity.sections.map((section) {
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
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
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
                  color: AppColors.primary.withOpacity(0.1),
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
                    color: AppColors.warning.withOpacity(0.1),
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
                  '${subIndex + 1}. ${subQuestion.text} (${subQuestion.marks} marks)',
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
      color: AppColors.error.withOpacity(0.05),
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
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
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
            color: Colors.grey.withOpacity(0.3),
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
        onViewDetails: null,
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: UIConstants.iconHuge,
            color: AppColors.error,
          ),
          SizedBox(height: UIConstants.spacing16),
          Text(
            'Error Loading Paper',
            style: TextStyle(
              fontSize: UIConstants.fontSizeXLarge,
              fontWeight: FontWeight.w600,
              color: AppColors.error,
            ),
          ),
          SizedBox(height: UIConstants.spacing8),
          Text(
            message,
            style: TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: UIConstants.spacing16),
          ElevatedButton(
            onPressed: _loadPaper,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
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

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
      ),
      title: const Text('Reject Paper'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Paper: ${widget.paperTitle}'),
          SizedBox(height: UIConstants.spacing16),
          const Text('Please provide a reason for rejection:'),
          SizedBox(height: UIConstants.spacing8),
          TextField(
            controller: _reasonController,
            decoration: InputDecoration(
              hintText: 'Enter rejection reason...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              ),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_reasonController.text.trim().isNotEmpty) {
              widget.onReject(_reasonController.text.trim());
              Navigator.of(context).pop();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
            ),
          ),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}