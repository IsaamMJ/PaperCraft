import 'package:flutter/material.dart';
import '../../../../../core/presentation/constants/app_colors.dart';
import '../../../../../core/presentation/constants/ui_constants.dart';
import '../../../../paper_workflow/domain/entities/question_paper_entity.dart';
import 'paper_tag.dart';
import 'paper_metric.dart';
import 'paper_status_badge.dart';

/// A card displaying an approved question paper with action for preview
class ApprovedPaperCard extends StatelessWidget {
  final QuestionPaperEntity paper;
  final String creatorName;
  final bool isGeneratingPdf;
  final VoidCallback onPreview;

  const ApprovedPaperCard({
    super.key,
    required this.paper,
    required this.creatorName,
    required this.isGeneratingPdf,
    required this.onPreview,
  });

  /// Format paper title for UI display
  /// Format: "Daily Test 2 • G5 Social Science • 23/10"
  String _formatDisplayTitle() {
    final parts = <String>[];

    // 1. Exam type and number (e.g., "Daily Test 2")
    final examName = paper.examType.displayName;
    if (paper.examNumber != null) {
      parts.add('$examName ${paper.examNumber}');
    } else {
      parts.add(examName);
    }

    // 2. Grade and subject (e.g., "G5 Social Science")
    final gradePrefix = paper.gradeLevel != null ? 'G${paper.gradeLevel}' : 'Grade ?';
    final subject = paper.subject ?? 'Unknown';
    parts.add('$gradePrefix $subject');

    // 3. Date (e.g., "23/10")
    if (paper.examDate != null) {
      final date = paper.examDate!;
      parts.add('${date.day}/${date.month}');
    }

    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final subjectDisplay = paper.subject ?? 'Unknown Subject';

    return Container(
      key: ValueKey(paper.id),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: AppColors.black04,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.035),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(subjectDisplay),
            const SizedBox(height: UIConstants.spacing12),
            _buildMetricsAndActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String subjectDisplay) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatDisplayTitle(),
                style: TextStyle(
                  fontSize: UIConstants.fontSizeMedium,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: UIConstants.spacing4),
              Text(
                'by $creatorName',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: UIConstants.spacing6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  PaperTag(text: subjectDisplay, color: AppColors.primary),
                  PaperTag(text: '${paper.paperSections.length} sections', color: AppColors.accent),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            PaperStatusBadge(status: paper.status),
            const SizedBox(height: UIConstants.spacing4),
            Text(
              _formatDate(paper.reviewedAt ?? paper.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricsAndActions() {
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              PaperMetric(
                icon: Icons.quiz_rounded,
                value: '${paper.totalQuestions}',
                label: 'Questions',
              ),
              PaperMetric(
                icon: Icons.grade_rounded,
                value: '${paper.totalMarks}',
                label: 'Marks',
              ),
              PaperMetric(
                icon: Icons.library_books_rounded,
                value: '${paper.paperSections.length}',
                label: 'Sections',
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _buildActions(),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActionButton(
          icon: isGeneratingPdf ? null : Icons.visibility_outlined,
          color: AppColors.primary,
          isLoading: isGeneratingPdf,
          onPressed: isGeneratingPdf ? null : onPreview,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    IconData? icon,
    required Color color,
    VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  )
                : Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}
