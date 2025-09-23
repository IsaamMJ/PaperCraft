// features/question_papers/presentation/admin/paper_review_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../domain/entities/question_paper_entity.dart';
import '../../domain/entities/question_entity.dart';
import '../bloc/question_paper_bloc.dart';
import '../widgets/shared/paper_status_badge.dart';
import '../widgets/shared/admin_action_buttons.dart';

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
  bool _isAdmin = false;
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _loadPaper();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _checkAdminStatus() async {
    final isAdmin = sl<UserStateService>().isAdmin;
    if (mounted) {
      setState(() => _isAdmin = isAdmin);

      if (!isAdmin) {
        context.go('/home');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin access required'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
      confirmColor: Colors.green,
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
          const Icon(Icons.description_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Paper Not Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The requested paper could not be found.',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go('/admin/dashboard'),
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
    if (!_isAdmin) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Paper'),
        backgroundColor: Colors.blue.shade700,
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
            // Navigate back to dashboard after successful action
            context.go('/admin/dashboard');
          } else if (state is QuestionPaperError) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: BlocBuilder<QuestionPaperBloc, QuestionPaperState>(
          builder: (context, state) {
            if (state is QuestionPaperLoading) {
              return const Center(child: CircularProgressIndicator());
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPaperHeader(paper),
                const SizedBox(height: 24),
                _buildPaperInfo(paper),
                const SizedBox(height: 24),
                _buildQuestionsSection(paper),
                if (paper.status.isRejected && paper.rejectionReason != null) ...[
                  const SizedBox(height: 24),
                  _buildRejectionFeedback(paper),
                ],
                const SizedBox(height: 100), // Space for fixed bottom actions
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
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                PaperStatusBadge(status: paper.status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Created by: ${paper.createdBy}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Submitted: ${_formatDate(paper.submittedAt)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
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
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paper Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Subject', paper.subject),
            _buildInfoRow('Exam Type', paper.examType),
            _buildInfoRow('Duration', paper.examTypeEntity.formattedDuration),
            _buildInfoRow('Total Questions', paper.totalQuestions.toString()),
            _buildInfoRow('Total Marks', paper.totalMarks.toString()),
            const SizedBox(height: 16),
            Text(
              'Section Breakdown:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            ...paper.examTypeEntity.sections.map((section) {
              final sectionQuestions = paper.questions[section.name] ?? [];
              return Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 4),
                child: Text(
                  '• ${section.name}: ${sectionQuestions.length}/${section.questions} questions (${section.marksPerQuestion} marks each)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsSection(QuestionPaperEntity paper) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Questions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const Spacer(),
                Text(
                  '${paper.totalQuestions} questions • ${paper.totalMarks} marks',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
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
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Text(
            sectionName,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...questions.asMap().entries.map((entry) {
          final index = entry.key;
          final question = entry.value;
          return _buildQuestionCard(index + 1, question);
        }).toList(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildQuestionCard(int questionNumber, Question question) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Q$questionNumber',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${question.marks} marks',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
              if (question.isOptional) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Optional',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            question.text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
          if (question.options != null && question.options!.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...question.options!.asMap().entries.map((optionEntry) {
              final optionIndex = optionEntry.key;
              final option = optionEntry.value;
              final isCorrect = question.correctAnswer == option;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Text(
                      '${String.fromCharCode(65 + optionIndex)}) ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        option,
                        style: TextStyle(
                          fontSize: 13,
                          color: isCorrect ? Colors.green.shade700 : Colors.grey[700],
                          fontWeight: isCorrect ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (isCorrect)
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green.shade700,
                      ),
                  ],
                ),
              );
            }).toList(),
          ],
          if (question.subQuestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Sub-questions:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            ...question.subQuestions.asMap().entries.map((subEntry) {
              final subIndex = subEntry.key;
              final subQuestion = subEntry.value;
              return Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 4),
                child: Text(
                  '${subIndex + 1}. ${subQuestion.text} (${subQuestion.marks} marks)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
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
      elevation: 2,
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Text(
                  'Rejection Feedback',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                paper.rejectionReason!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
            ),
            if (paper.reviewedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Rejected on: ${_formatDate(paper.reviewedAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade600,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
        onViewDetails: null, // Already on details page
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Error Loading Paper',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadPaper,
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
      title: const Text('Reject Paper'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Paper: ${widget.paperTitle}'),
          const SizedBox(height: 16),
          const Text('Please provide a reason for rejection:'),
          const SizedBox(height: 8),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(
              hintText: 'Enter rejection reason...',
              border: OutlineInputBorder(),
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
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}