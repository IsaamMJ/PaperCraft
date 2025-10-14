// features/question_papers/pages/widgets/shared/paper_list_tile.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:papercraft/features/paper_workflow/presentation/widgets/paper_status_badge.dart';
import '../../domain/entities/question_paper_entity.dart';

import '../../../../core/presentation/constants/ui_constants.dart';

class PaperListTile extends StatelessWidget {
  final QuestionPaperEntity paper;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showCreator;
  final bool isCompact;

  const PaperListTile({
    super.key,
    required this.paper,
    this.onTap,
    this.trailing,
    this.showCreator = false,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 16,
        vertical: isCompact ? 4 : 8,
      ),
      elevation: isCompact ? 1 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        child: Padding(
          padding: EdgeInsets.all(isCompact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          paper.title,
                          style: TextStyle(
                            fontSize: isCompact ? 14 : 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!isCompact) SizedBox(height: UIConstants.spacing4),
                        Text(
                          '${paper.subject} • ${paper.examType}',
                          style: TextStyle(
                            fontSize: isCompact ? 12 : 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      PaperStatusBadge(
                        status: paper.status,
                        isCompact: isCompact,
                      ),
                      if (trailing != null) ...[
                        SizedBox(height: UIConstants.spacing8),
                        trailing!,
                      ],
                    ],
                  ),
                ],
              ),

              if (!isCompact) ...[
                SizedBox(height: UIConstants.spacing12),

                // Metrics Row
                Row(
                  children: [
                    _buildMetric(
                      Icons.quiz_outlined,
                      '${paper.totalQuestions} questions',
                    ),
                    const SizedBox(width: 16),
                    _buildMetric(
                      Icons.score_outlined,
                      '${paper.totalMarks} marks',
                    ),
                    const SizedBox(width: 16),
                    _buildMetric(
                      Icons.library_books_outlined,
                      '${paper.paperSections.length} sections',
                    ),
                  ],
                ),

                SizedBox(height: UIConstants.spacing12),

                // Footer Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showCreator)
                            Text(
                              'Created by: ${paper.createdBy}',
                              style: TextStyle(
                                fontSize: UIConstants.fontSizeSmall,
                                color: Colors.grey[600],
                              ),
                            ),
                          Text(
                            _getDateText(),
                            style: TextStyle(
                              fontSize: UIConstants.fontSizeSmall,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (paper.status.isRejected && paper.rejectionReason != null)
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.red.shade400,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetric(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey[500],
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: UIConstants.fontSizeSmall,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  String _getDateText() {
    final formatter = DateFormat('MMM dd, yyyy');

    if (paper.status.isSubmitted && paper.submittedAt != null) {
      return 'Submitted: ${formatter.format(paper.submittedAt!)}';
    } else if (paper.status.isApproved && paper.reviewedAt != null) {
      return 'Approved: ${formatter.format(paper.reviewedAt!)}';
    } else if (paper.status.isRejected && paper.reviewedAt != null) {
      return 'Rejected: ${formatter.format(paper.reviewedAt!)}';
    } else if (paper.status.isDraft) {
      return 'Modified: ${formatter.format(paper.modifiedAt)}';
    }

    return 'Created: ${formatter.format(paper.createdAt)}';
  }
}