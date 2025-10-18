import 'package:flutter/material.dart';
import '../../../../../core/presentation/constants/app_colors.dart';
import '../../../../../core/presentation/constants/ui_constants.dart';

/// Dialog for selecting PDF layout type (single or dual)
class LayoutSelectionDialog extends StatelessWidget {
  final String title;
  final String paperTitle;
  final VoidCallback onSingleLayout;
  final VoidCallback onDualLayout;

  const LayoutSelectionDialog({
    super.key,
    required this.title,
    required this.paperTitle,
    required this.onSingleLayout,
    required this.onDualLayout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(UIConstants.paddingMedium),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 3,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: UIConstants.spacing16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: UIConstants.spacing6),
          Text(
            paperTitle,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: UIConstants.fontSizeSmall,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: UIConstants.spacing20),
          _buildLayoutOption(
            context,
            'Single Page Layout',
            'One question paper per page',
            Icons.description_rounded,
            AppColors.primary,
            onSingleLayout,
          ),
          const SizedBox(height: 10),
          _buildLayoutOption(
            context,
            'Dual Layout',
            'Two identical papers per page',
            Icons.content_copy_rounded,
            AppColors.accent,
            onDualLayout,
          ),
          const SizedBox(height: UIConstants.spacing12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLayoutOption(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          onTap();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: UIConstants.fontSizeMedium,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show preview dialog
  static void showPreviewDialog(
    BuildContext context,
    String paperTitle,
    VoidCallback onSingleLayout,
    VoidCallback onDualLayout,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => LayoutSelectionDialog(
        title: 'Preview PDF',
        paperTitle: paperTitle,
        onSingleLayout: onSingleLayout,
        onDualLayout: onDualLayout,
      ),
    );
  }

  /// Show download dialog
  static void showDownloadDialog(
    BuildContext context,
    String paperTitle,
    VoidCallback onSingleLayout,
    VoidCallback onDualLayout,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => LayoutSelectionDialog(
        title: 'Download PDF',
        paperTitle: paperTitle,
        onSingleLayout: onSingleLayout,
        onDualLayout: onDualLayout,
      ),
    );
  }
}
