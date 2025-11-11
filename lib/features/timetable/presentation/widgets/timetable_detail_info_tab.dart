import 'package:flutter/material.dart';

import '../../domain/entities/exam_timetable_entity.dart';

/// Timetable Detail - Information Tab
///
/// Displays detailed timetable information in a structured format.
class TimetableDetailInfoTab extends StatelessWidget {
  final ExamTimetableEntity timetable;

  const TimetableDetailInfoTab({
    required this.timetable,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    print('[TimetableDetailInfoTab] Building with timetable: ${timetable.examName}, createdBy: ${timetable.createdBy}, status: ${timetable.status}');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Information Section
          _buildSection(
            context,
            'Basic Information',
            [
              _buildInfoRow(context, 'Exam Name', timetable.examName),
              _buildInfoRow(context, 'Exam Type', timetable.examType),
              _buildInfoRow(context, 'Academic Year', timetable.academicYear),
              if (timetable.examNumber != null)
                _buildInfoRow(
                  context,
                  'Exam Number',
                  '#${timetable.examNumber}',
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Status Section
          _buildSection(
            context,
            'Status',
            [
              _buildStatusRow(context, 'Current Status', timetable.status),
              _buildInfoRow(
                context,
                'Active',
                timetable.isActive ? 'Yes' : 'No',
              ),
              if (timetable.publishedAt != null)
                _buildInfoRow(
                  context,
                  'Published Date',
                  _formatDate(timetable.publishedAt!),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Calendar Information Section
          if (timetable.examCalendarId != null)
            _buildSection(
              context,
              'Calendar Reference',
              [
                _buildInfoRow(
                  context,
                  'Calendar ID',
                  timetable.examCalendarId!,
                ),
              ],
            ),

          if (timetable.examCalendarId != null)
            const SizedBox(height: 16),

          // Metadata Section
          if (timetable.metadata != null && timetable.metadata!.isNotEmpty)
            _buildSection(
              context,
              'Additional Information',
              [
                ..._buildMetadataRows(context),
              ],
            ),

          if (timetable.metadata != null && timetable.metadata!.isNotEmpty)
            const SizedBox(height: 16),

          // Audit Information Section
          _buildSection(
            context,
            'Audit Information',
            [
              _buildInfoRow(
                context,
                'Created By',
                timetable.createdBy,
              ),
              _buildInfoRow(
                context,
                'Created',
                _formatDateTime(timetable.createdAt),
              ),
              _buildInfoRow(
                context,
                'Last Updated',
                _formatDateTime(timetable.updatedAt),
              ),
              _buildInfoRow(
                context,
                'Timetable ID',
                timetable.id,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build information section
  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  /// Build information row
  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  /// Build status row with colored badge
  Widget _buildStatusRow(BuildContext context, String label, String status) {
    final statusColor = _getStatusColor(status);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build metadata rows
  List<Widget> _buildMetadataRows(BuildContext context) {
    final List<Widget> rows = [];
    timetable.metadata?.forEach((key, value) {
      rows.add(
        _buildInfoRow(
          context,
          key,
          value.toString(),
        ),
      );
    });
    return rows;
  }

  /// Get status color
  Color _getStatusColor(String status) {
    switch (status) {
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

  /// Format date
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Format datetime
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
