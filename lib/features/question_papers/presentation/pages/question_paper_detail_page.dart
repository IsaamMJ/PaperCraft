// features/question_papers/presentation/pages/question_paper_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/question_paper_entity.dart';
import '../../domain/entities/paper_status.dart';
import '../bloc/question_paper_bloc.dart';

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
    return BlocProvider(
      create: (context) => QuestionPaperBloc(
        saveDraftUseCase: sl(),
        submitPaperUseCase: sl(),
        getDraftsUseCase: sl(),
        getUserSubmissionsUseCase: sl(),
        approvePaperUseCase: sl(),
        rejectPaperUseCase: sl(),
        getPapersForReviewUseCase: sl(),
        deleteDraftUseCase: sl(),
        pullForEditingUseCase: sl(),
        getPaperByIdUseCase: sl(),
      )..add(LoadPaperById(questionPaperId)),
      child: QuestionPaperDetailView(
        questionPaperId: questionPaperId,
        isViewOnly: isViewOnly,
      ),
    );
  }
}

class QuestionPaperDetailView extends StatefulWidget {
  final String questionPaperId;
  final bool isViewOnly;

  const QuestionPaperDetailView({
    super.key,
    required this.questionPaperId,
    this.isViewOnly = false,
  });

  @override
  State<QuestionPaperDetailView> createState() => _QuestionPaperDetailViewState();
}

class _QuestionPaperDetailViewState extends State<QuestionPaperDetailView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isViewOnly ? 'View Paper' : 'Paper Details'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<QuestionPaperBloc>().add(LoadPaperById(widget.questionPaperId)),
          ),
        ],
      ),
      body: // Replace the BlocConsumer listener section in question_paper_detail_page.dart

      BlocConsumer<QuestionPaperBloc, QuestionPaperState>(
        listener: (context, state) {
          if (state is QuestionPaperSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );

            // Safe navigation after actions
            if (state.actionType == 'submit') {
              // Show success message first
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Question paper submitted successfully!'),
                  backgroundColor: Colors.green,
                ),
              );

              // Navigate to home
              context.go('/home');
            } else if (state.actionType == 'pull') {
              // Safe way to pop - check if we can pop first
              if (context.canPop()) {
                context.pop();
              } else {
                // Fallback to home if we can't pop
                context.go('/home');
              }
            }
          }

          if (state is QuestionPaperError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is QuestionPaperLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  if (state.message != null) ...[
                    const SizedBox(height: 16),
                    Text(state.message!),
                  ],
                ],
              ),
            );
          }

          if (state is QuestionPaperError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Error Loading Paper',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => context.read<QuestionPaperBloc>().add(LoadPaperById(widget.questionPaperId)),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          if (state is QuestionPaperLoaded && state.currentPaper == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.description_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Paper Not Found',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The requested question paper could not be found.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          if (state is QuestionPaperLoaded && state.currentPaper != null) {
            return _buildPaperContent(state.currentPaper!);
          }

          return const Center(
            child: Text('Loading paper...'),
          );
        },
      ),
    );
  }

  Widget _buildPaperContent(QuestionPaperEntity paper) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPaperInfo(paper),
          const SizedBox(height: 16),
          _buildActionButtons(paper),
          const SizedBox(height: 24),
          _buildQuestionsList(paper),
        ],
      ),
    );
  }

  Widget _buildPaperInfo(QuestionPaperEntity paper) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    paper.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusChip(paper.status),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.subject, 'Subject', paper.subject),
            _buildInfoRow(Icons.quiz, 'Exam Type', paper.examType),
            _buildInfoRow(Icons.help_outline, 'Questions', '${paper.totalQuestions} questions'),
            _buildInfoRow(Icons.grade, 'Total Marks', '${paper.totalMarks} marks'),
            _buildInfoRow(Icons.access_time, 'Created', _formatDate(paper.createdAt)),
            _buildInfoRow(Icons.update, 'Modified', _formatDate(paper.modifiedAt)),

            if (paper.submittedAt != null)
              _buildInfoRow(Icons.send, 'Submitted', _formatDate(paper.submittedAt!)),

            if (paper.reviewedAt != null)
              _buildInfoRow(Icons.rate_review, 'Reviewed', _formatDate(paper.reviewedAt!)),

            if (paper.rejectionReason != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.red.shade700, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Rejection Reason',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      paper.rejectionReason!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(PaperStatus status) {
    Color color;
    switch (status) {
      case PaperStatus.draft:
        color = Colors.orange;
        break;
      case PaperStatus.submitted:
        color = Colors.blue;
        break;
      case PaperStatus.approved:
        color = Colors.green;
        break;
      case PaperStatus.rejected:
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.displayName.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildActionButtons(QuestionPaperEntity paper) {
    final actions = <Widget>[];

    if (paper.canEdit && !widget.isViewOnly) {
      actions.add(
        ElevatedButton.icon(
          onPressed: () => _editPaper(paper),
          icon: const Icon(Icons.edit),
          label: const Text('Edit'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
        ),
      );
    }

    if (paper.canSubmit && !widget.isViewOnly) {
      actions.add(
        ElevatedButton.icon(
          onPressed: () => _submitPaper(paper),
          icon: const Icon(Icons.send),
          label: const Text('Submit'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        ),
      );
    }

    if (paper.canPullForEditing && !widget.isViewOnly) {
      actions.add(
        ElevatedButton.icon(
          onPressed: () => _pullForEditing(paper),
          icon: const Icon(Icons.edit_note),
          label: const Text('Edit Again'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
        ),
      );
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: actions,
    );
  }

  Widget _buildQuestionsList(QuestionPaperEntity paper) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Questions (${paper.totalQuestions} total)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...paper.questions.entries.map((entry) {
              final sectionName = entry.key;
              final questions = entry.value;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$sectionName (${questions.length} questions)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...questions.asMap().entries.map((questionEntry) {
                    final index = questionEntry.key + 1;
                    final question = questionEntry.value;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Q$index. ',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Expanded(
                                child: Text(
                                  question.text,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${question.marks} marks',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (question.options != null && question.options!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ...question.options!.asMap().entries.map((optionEntry) {
                              final optionIndex = String.fromCharCode(65 + optionEntry.key);
                              final option = optionEntry.value;
                              return Padding(
                                padding: const EdgeInsets.only(left: 20, bottom: 4),
                                child: Text('$optionIndex) $option'),
                              );
                            }),
                          ],
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _editPaper(QuestionPaperEntity paper) {
    // Use the correct route from your router
    context.go('/question-papers/edit/${paper.id}');
  }

  void _submitPaper(QuestionPaperEntity paper) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Submit Paper'),
        content: const Text('Are you sure you want to submit this paper for review? You won\'t be able to edit it until it\'s reviewed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              // Use the page context (this.context) not the dialog context
              context.read<QuestionPaperBloc>().add(SubmitPaper(paper));
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _pullForEditing(QuestionPaperEntity paper) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Again'),
        content: const Text('This will create a new draft copy of this rejected paper that you can edit and resubmit.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              // Use the page context (this.context) not the dialog context
              context.read<QuestionPaperBloc>().add(PullForEditing(paper.id));
            },
            child: const Text('Create Draft'),
          ),
        ],
      ),
    );
  }
}