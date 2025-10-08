import 'package:flutter/material.dart';
import '../../../../../core/presentation/constants/app_colors.dart';
import '../../../../../core/presentation/constants/ui_constants.dart';
import '../../../../paper_workflow/domain/entities/paper_status.dart';

/// Displays a status badge for a question paper (e.g., APPROVED, DRAFT, SUBMITTED)
class PaperStatusBadge extends StatelessWidget {
  final PaperStatus status;

  const PaperStatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getStatusConfig(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
      ),
      child: Text(
        config.label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: config.color,
        ),
      ),
    );
  }

  _StatusConfig _getStatusConfig(PaperStatus status) {
    switch (status) {
      case PaperStatus.draft:
        return _StatusConfig('DRAFT', AppColors.textSecondary);
      case PaperStatus.submitted:
        return _StatusConfig('SUBMITTED', AppColors.warning);
      case PaperStatus.approved:
        return _StatusConfig('APPROVED', AppColors.success);
      case PaperStatus.rejected:
        return _StatusConfig('REJECTED', AppColors.error);
    }
  }
}

class _StatusConfig {
  final String label;
  final Color color;

  _StatusConfig(this.label, this.color);
}
