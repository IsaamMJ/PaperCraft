import 'package:flutter/material.dart';

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
      print('[TimetableListItem] $actionName already processing, ignoring duplicate click');
      return;
    }

    print('[TimetableListItem] $actionName action executing (debounced)');
    _isProcessing = true;

    try {
      callback();
    } finally {
      // Reset flag - allow another click after 800ms
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          _isProcessing = false;
          print('[TimetableListItem] Ready for next action');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only card is displayed - no InkWell to prevent double navigation
    // Use buttons to trigger actions instead
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.timetable.examName,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Type: ${widget.timetable.examType}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(context),
              ],
            ),
            const SizedBox(height: 12),

            // Details row
            Row(
              children: [
                Icon(
                  Icons.calendar_month,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Text(
                  'Year: ${widget.timetable.academicYear}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Text(
                  _getCreatedDate(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Action buttons
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  /// Build status badge
  Widget _buildStatusBadge(BuildContext context) {
    final statusColor = _getStatusColor();
    final statusIcon = _getStatusIcon();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 14, color: statusColor),
          const SizedBox(width: 4),
          Text(
            widget.timetable.status.capitalize(),
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // View button (always available)
          _buildActionButton(
            context,
            'View',
            Icons.visibility,
            Colors.blue,
            widget.onTap,
          ),

          // Publish button (draft only)
          if (widget.timetable.isDraft)
            _buildActionButton(
              context,
              'Publish',
              Icons.publish,
              Colors.green,
              widget.onPublish,
            ),

          // Archive button (published only)
          if (widget.timetable.isPublished)
            _buildActionButton(
              context,
              'Archive',
              Icons.archive,
              Colors.purple,
              widget.onArchive,
            ),

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
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: SizedBox(
        height: 32,
        child: OutlinedButton.icon(
          onPressed: () {
            _handleButtonPress(onPressed, label);
          },
          icon: Icon(icon, size: 14),
          label: Text(label, style: const TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          ),
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
