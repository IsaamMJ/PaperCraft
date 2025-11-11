import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/exam_timetable_entity.dart';
import '../../domain/entities/exam_timetable_entry_entity.dart';
import '../../data/utils/pdf_generator.dart';
import '../bloc/exam_timetable_bloc.dart';
import '../bloc/exam_timetable_event.dart';
import '../bloc/exam_timetable_state.dart';
import '../widgets/timetable_detail_entries_tab.dart';

/// Exam Timetable Detail Page
///
/// Displays timetable header info and exam entries in a table format.
class ExamTimetableDetailPage extends StatefulWidget {
  final String timetableId;
  final String tenantId;

  const ExamTimetableDetailPage({
    required this.timetableId,
    required this.tenantId,
    super.key,
  });

  @override
  State<ExamTimetableDetailPage> createState() =>
      _ExamTimetableDetailPageState();
}

class _ExamTimetableDetailPageState extends State<ExamTimetableDetailPage> {
  bool _entriesLoaded = false;
  ExamTimetableEntity? _cachedTimetable;

  @override
  void initState() {
    super.initState();

    print('[ExamTimetableDetailPage] initState: Loading timetable ID=${widget.timetableId}');

    // Load timetable first, THEN entries after a small delay to ensure proper state ordering
    context.read<ExamTimetableBloc>().add(
          GetExamTimetableByIdEvent(timetableId: widget.timetableId),
        );

    // Load entries AFTER timetable loads to ensure proper state sequence
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!_entriesLoaded) {
          _entriesLoaded = true;
          print('[ExamTimetableDetailPage] Loading entries now');
          context.read<ExamTimetableBloc>().add(
                GetExamTimetableEntriesEvent(timetableId: widget.timetableId),
              );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable Details'),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  onTap: _cachedTimetable != null ? () => _handlePrint(context) : null,
                  child: const Row(
                    children: [
                      Icon(Icons.print),
                      SizedBox(width: 8),
                      Text('Print'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  onTap: _cachedTimetable != null ? () => _handleExportPdf(context) : null,
                  child: const Row(
                    children: [
                      Icon(Icons.download),
                      SizedBox(width: 8),
                      Text('Export PDF'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: BlocBuilder<ExamTimetableBloc, ExamTimetableState>(
        builder: (context, state) {
          print('[ExamTimetableDetailPage] State received: ${state.runtimeType}');

          if (state is ExamTimetableLoading) {
            print('[ExamTimetableDetailPage] Showing loading state');
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (state is ExamTimetableLoaded) {
            final timetable = state.timetable;
            _cachedTimetable = timetable;
            print('[ExamTimetableDetailPage] Showing timetable: ${timetable.examName}');

            return Column(
              children: [
                // Header with timetable info
                _buildHeader(context, timetable),

                // Divider
                Divider(height: 1, color: Colors.grey[300]),

                // Entries table
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: TimetableDetailEntriesTab(
                      timetableId: widget.timetableId,
                    ),
                  ),
                ),
              ],
            );
          }

          // Handle entries loaded state - show with cached timetable header
          if (state is ExamTimetableEntriesLoaded && _cachedTimetable != null) {
            return Column(
              children: [
                // Header with cached timetable info
                _buildHeader(context, _cachedTimetable!),

                // Divider
                Divider(height: 1, color: Colors.grey[300]),

                // Entries table
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: TimetableDetailEntriesTab(
                      timetableId: widget.timetableId,
                    ),
                  ),
                ),
              ],
            );
          }

          if (state is ExamTimetableError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading timetable',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back'),
                  ),
                ],
              ),
            );
          }

          return const SizedBox.expand(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
      ),
    );
  }

  /// Build header with timetable info
  Widget _buildHeader(BuildContext context, ExamTimetableEntity timetable) {
    return Container(
      color: Colors.blue[50],
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timetable.examName,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Type: ${timetable.examType}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusBadge(context, timetable),
            ],
          ),
          const SizedBox(height: 16),

          // Info grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoItem(
                context,
                'Academic Year',
                timetable.academicYear,
                Icons.calendar_month,
              ),
              _buildInfoItem(
                context,
                'Status',
                timetable.status.toUpperCase(),
                Icons.info,
              ),
              _buildInfoItem(
                context,
                'Created',
                _formatDate(timetable.createdAt),
                Icons.access_time,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build status badge
  Widget _buildStatusBadge(BuildContext context, ExamTimetableEntity timetable) {
    final statusColor = _getStatusColor(timetable.status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor),
      ),
      child: Text(
        timetable.status.toUpperCase(),
        style: TextStyle(
          color: statusColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Build info item
  Widget _buildInfoItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
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

  /// Handle export to PDF
  Future<void> _handleExportPdf(BuildContext context) async {
    if (_cachedTimetable == null) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating PDF...')),
      );

      // Get current timetable entries from BLoC
      final bloc = context.read<ExamTimetableBloc>();
      final state = bloc.state;

      List<ExamTimetableEntryEntity> entries = [];
      if (state is ExamTimetableEntriesLoaded) {
        entries = state.entries;
      }

      // Extract unique grade numbers from entries
      final gradeNumbers = <int>{};
      for (final entry in entries) {
        if (entry.gradeNumber != null) {
          gradeNumbers.add(entry.gradeNumber!);
        }
      }

      // Get school name (you may want to pass this or get from tenant)
      const schoolName = 'Your School Name'; // TODO: Get from tenant data

      // Generate PDF
      final pdfBytes = await TimetablePdfGenerator.generateTimetablePdf(
        timetable: _cachedTimetable!,
        entries: entries,
        schoolName: schoolName,
        gradeNumbers: gradeNumbers.toList()..sort(),
      );

      // Save file
      final directory = await getDownloadsDirectory();
      if (directory == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Downloads directory not found')),
        );
        return;
      }

      final fileName = '${_cachedTimetable!.examName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF saved: ${file.path}')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Handle print (placeholder)
  void _handlePrint(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Print feature coming soon')),
    );
  }
}
