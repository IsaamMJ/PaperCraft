// features/question_papers/presentation/widgets/shared/paper_status_badge.dart
import 'package:flutter/material.dart';
import '../../../../../core/presentation/constants/ui_constants.dart';
import '../../../domain/entities/paper_status.dart';

class PaperStatusBadge extends StatelessWidget {
  final PaperStatus status;
  final bool isCompact;

  const PaperStatusBadge({
    super.key,
    required this.status,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 6 : 8,
        vertical: isCompact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        border: Border.all(
          color: _getBorderColor(),
          width: 1,
        ),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: _getTextColor(),
          fontSize: isCompact ? 10 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (status) {
      case PaperStatus.draft:
        return Colors.grey.shade100;
      case PaperStatus.submitted:
        return Colors.amber.shade50;
      case PaperStatus.approved:
        return Colors.green.shade50;
      case PaperStatus.rejected:
        return Colors.red.shade50;
    }
  }

  Color _getBorderColor() {
    switch (status) {
      case PaperStatus.draft:
        return Colors.grey.shade300;
      case PaperStatus.submitted:
        return Colors.amber.shade300;
      case PaperStatus.approved:
        return Colors.green.shade300;
      case PaperStatus.rejected:
        return Colors.red.shade300;
    }
  }

  Color _getTextColor() {
    switch (status) {
      case PaperStatus.draft:
        return Colors.grey.shade700;
      case PaperStatus.submitted:
        return Colors.amber.shade700;
      case PaperStatus.approved:
        return Colors.green.shade700;
      case PaperStatus.rejected:
        return Colors.red.shade700;
    }
  }
}