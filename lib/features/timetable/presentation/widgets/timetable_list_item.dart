import 'package:flutter/material.dart';

import '../../../../../core/presentation/constants/app_colors.dart';
import '../../../../../core/presentation/constants/ui_constants.dart';
import '../../domain/entities/exam_timetable_entity.dart';

/// Timetable List Item Card
///
/// Displays a single timetable with:
/// - Basic info (name, type, academic year, status)
/// - Status badge (draft/published/archived)
/// - Action buttons (view, edit, publish, archive, delete)
class TimetableListItem extends StatefulWidget {
  final ExamTimetableEntity timetable;
  final VoidCallback onTap;
  final VoidCallback onPublish;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  const TimetableListItem({
    required this.timetable,
    required this.onTap,
    required this.onPublish,
    required this.onArchive,
    required this.onDelete,
    super.key,
  });

  @override
  State<TimetableListItem> createState() => _TimetableListItemState();
}

class _TimetableListItemState extends State<TimetableListItem> {
  bool _isProcessing = false;

  void _handleButtonPress(VoidCallback callback, String actionName) {
    if (_isProcessing) {
      return;
    }

    _isProcessing = true;

    try {
      callback();
    } finally {
      // Reset flag - allow another click after 800ms
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          _isProcessing = false;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: UIConstants.spacing12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.black04,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header section with gradient left border
          Container(
            padding: EdgeInsets.all(UIConstants.paddingMedium),
            decoration: BoxDecoration(
              color: _getStatusBackgroundColor(),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(UIConstants.radiusLarge),
                topRight: Radius.circular(UIConstants.radiusLarge),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.timetable.examName,
                        style: TextStyle(
                          fontSize: UIConstants.fontSizeLarge,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: UIConstants.spacing4),
                      Text(
                        widget.timetable.examType,
                        style: TextStyle(
                          fontSize: UIConstants.fontSizeSmall,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: UIConstants.spacing12),
                _buildStatusBadge(context),
              ],
            ),
          ),

          // Details section
          Container(
            padding: EdgeInsets.all(UIConstants.paddingMedium),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildDetailItem(
                      icon: Icons.school,
                      label: 'Year',
                      value: widget.timetable.academicYear,
                    ),
                    const Spacer(),
                    _buildDetailItem(
                      icon: Icons.calendar_today,
                      label: 'Created',
                      value: _getCreatedDate(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action buttons section
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: UIConstants.paddingMedium,
              vertical: UIConstants.paddingSmall,
            ),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(UIConstants.radiusLarge),
                bottomRight: Radius.circular(UIConstants.radiusLarge),
              ),
            ),
            child: _buildActionButtons(context),
          ),
        ],
      ),
    );
  }

  /// Build status badge
  Widget _buildStatusBadge(BuildContext context) {
    final statusColor = _getStatusColor();
    final statusIcon = _getStatusIcon();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: UIConstants.spacing8,
        vertical: UIConstants.spacing6,
      ),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 14, color: Colors.white),
          SizedBox(width: UIConstants.spacing6),
          Text(
            widget.timetable.status.capitalize(),
            style: TextStyle(
              color: Colors.white,
              fontSize: UIConstants.fontSizeSmall,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Build action buttons
  Widget _buildActionButtons(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // View button (always available)
          _buildActionButton(
            context,
            'View',
            Icons.visibility,
            Colors.blue,
            widget.onTap,
          ),
          SizedBox(width: UIConstants.spacing8),

          // Publish button (draft only)
          if (widget.timetable.isDraft) ...[
            _buildActionButton(
              context,
              'Publish',
              Icons.publish,
              Colors.green,
              widget.onPublish,
            ),
            SizedBox(width: UIConstants.spacing8),
          ],

          // Archive button (published only)
          if (widget.timetable.isPublished) ...[
            _buildActionButton(
              context,
              'Archive',
              Icons.archive,
              Colors.purple,
              widget.onArchive,
            ),
            SizedBox(width: UIConstants.spacing8),
          ],

          // Delete button (draft only)
          if (widget.timetable.isDraft)
            _buildActionButton(
              context,
              'Delete',
              Icons.delete,
              Colors.red,
              widget.onDelete,
            ),
        ],
      ),
    );
  }

  /// Build individual action button
  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: () {
        _handleButtonPress(onPressed, label);
      },
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        elevation: 0,
        side: BorderSide(color: color.withValues(alpha: 0.3)),
        padding: EdgeInsets.symmetric(
          horizontal: UIConstants.spacing12,
          vertical: UIConstants.spacing8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        ),
      ),
    );
  }

  /// Get status color
  Color _getStatusColor() {
    switch (widget.timetable.status) {
      case 'draft':
        return Colors.orange;
      case 'published':
        return Colors.green;
      case 'archived':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  /// Get status background color for header
  Color _getStatusBackgroundColor() {
    final color = _getStatusColor();
    return color.withValues(alpha: 0.08);
  }

  /// Get status icon
  IconData _getStatusIcon() {
    switch (widget.timetable.status) {
      case 'draft':
        return Icons.edit;
      case 'published':
        return Icons.check_circle;
      case 'archived':
        return Icons.archive;
      default:
        return Icons.info;
    }
  }

  /// Build detail item with icon
  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.textSecondary,
        ),
        SizedBox(width: UIConstants.spacing6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: UIConstants.fontSizeSmall,
                color: AppColors.textTertiary,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: UIConstants.fontSizeSmall,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Get created date formatted
  String _getCreatedDate() {
    final date = widget.timetable.createdAt;
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// String extension to capitalize first letter
extension StringExtension on String {
  String capitalize() {
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
