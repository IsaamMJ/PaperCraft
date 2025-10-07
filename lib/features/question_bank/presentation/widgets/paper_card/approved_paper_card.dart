import 'package:flutter/material.dart';
import '../../../../../core/presentation/constants/app_colors.dart';
import '../../../../../core/presentation/constants/ui_constants.dart';
import '../../../../paper_workflow/domain/entities/question_paper_entity.dart';
import 'paper_tag.dart';
import 'paper_metric.dart';
import 'paper_status_badge.dart';

/// A card displaying an approved question paper with actions for preview and download
class ApprovedPaperCard extends StatelessWidget {
  final QuestionPaperEntity paper;
  final String creatorName;
  final bool isGeneratingPdf;
  final VoidCallback onPreview;
  final VoidCallback onDownload;

  const ApprovedPaperCard({
    super.key,
    required this.paper,
    required this.creatorName,
    required this.isGeneratingPdf,
    required this.onPreview,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final subjectDisplay = paper.subject ?? 'Unknown Subject';
    final examTypeDisplay = paper.examType ?? paper.examTypeEntity.name;

    return Container(
      key: ValueKey(paper.id),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: AppColors.border.withOpacity(0.1)),
      ),
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.035),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(subjectDisplay, examTypeDisplay),
            const SizedBox(height: UIConstants.spacing12),
            _buildMetricsAndActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String subjectDisplay, String examTypeDisplay) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                paper.title,
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
                  PaperTag(text: examTypeDisplay, color: AppColors.accent),
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
                icon: Icons.access_time_rounded,
                value: paper.examTypeEntity.formattedDuration,
                label: 'Duration',
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
          icon: Icons.visibility_outlined,
          color: AppColors.primary,
          onPressed: onPreview,
        ),
        const SizedBox(width: 6),
        _buildActionButton(
          icon: isGeneratingPdf ? null : Icons.download_rounded,
          color: AppColors.success,
          isLoading: isGeneratingPdf,
          onPressed: isGeneratingPdf ? null : onDownload,
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
        color: color.withOpacity(0.1),
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
