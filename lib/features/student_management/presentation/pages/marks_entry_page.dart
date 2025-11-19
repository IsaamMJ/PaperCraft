import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:papercraft/core/infrastructure/di/injection_container.dart';
import 'package:papercraft/core/presentation/constants/app_colors.dart';
import 'package:papercraft/core/presentation/constants/ui_constants.dart';
import 'package:papercraft/features/student_management/domain/entities/student_exam_marks_entity.dart';
import 'package:papercraft/features/student_management/presentation/bloc/marks_entry_bloc.dart';

/// Marks Entry Page
///
/// Allows teachers to enter marks for students in an exam.
/// Features:
/// - Table view with inline mark editing
/// - Status dropdown (present/absent/medical leave/not appeared)
/// - Auto-validation of marks
/// - Draft auto-save functionality
/// - Bulk CSV upload option
/// - Marks submission with summary
class MarksEntryPage extends StatefulWidget {
  const MarksEntryPage({super.key});

  @override
  State<MarksEntryPage> createState() => _MarksEntryPageState();
}

class _MarksEntryPageState extends State<MarksEntryPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Enter Exam Marks'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          Padding(
            padding: EdgeInsets.all(UIConstants.paddingMedium),
            child: Center(
              child: BlocBuilder<MarksEntryBloc, MarksEntryState>(
                builder: (context, state) {
                  if (state is MarksEntryReady) {
                    return Text(
                      state.isDraft ? '(Draft - Auto-saved)' : '(Submitted)',
                      style: TextStyle(
                        fontSize: 12,
                        color: state.isDraft ? Colors.orange : Colors.green,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ],
      ),
      body: BlocListener<MarksEntryBloc, MarksEntryState>(
        listener: (context, state) {
          if (state is MarksSubmitted) {
            _showSubmissionSummary(context, state.summary);
          } else if (state is MarkValidationError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          } else if (state is MarksEntryError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is BulkUploadFailed) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Upload failed: ${state.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: BlocBuilder<MarksEntryBloc, MarksEntryState>(
          builder: (context, state) {
            if (state is MarksEntryLoading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (state is MarksEntryError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    SizedBox(height: UIConstants.spacing16),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    SizedBox(height: UIConstants.spacing16),
                    ElevatedButton(
                      onPressed: () => context.pop(),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              );
            }

            if (state is MarksEntryReady) {
              return SingleChildScrollView(
                padding: EdgeInsets.all(UIConstants.paddingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    _buildHeader(state),
                    SizedBox(height: UIConstants.spacing24),

                    // Search bar
                    _buildSearchBar(context),
                    SizedBox(height: UIConstants.spacing16),

                    // Marks table
                    _buildMarksTable(context, state),
                    SizedBox(height: UIConstants.spacing24),

                    // Action buttons
                    _buildActionButtons(context, state),
                  ],
                ),
              );
            }

            if (state is MarksSubmitted) {
              return const SizedBox.shrink(); // Summary shown in dialog
            }

            if (state is SubmittingMarks) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Submitting marks...'),
                  ],
                ),
              );
            }

            return const Center(
              child: Text('Unknown state'),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(MarksEntryReady state) {
    return Container(
      padding: EdgeInsets.all(UIConstants.paddingLarge),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.assignment,
                color: Colors.white,
                size: UIConstants.iconLarge,
              ),
              SizedBox(width: UIConstants.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Marks Entry',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    SizedBox(height: UIConstants.spacing4),
                    Text(
                      'Total Students: ${state.students.length}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search by roll number or name...',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: UIConstants.paddingMedium,
          vertical: UIConstants.paddingSmall,
        ),
      ),
    );
  }

  Widget _buildMarksTable(BuildContext context, MarksEntryReady state) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Roll No.')),
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Marks')),
            DataColumn(label: Text('Status')),
          ],
          rows: state.students.map((student) {
            final entry = state.marksEntries[student.id];
            if (entry == null) return DataRow(cells: []);

            return DataRow(
              cells: [
                DataCell(Text(student.rollNumber)),
                DataCell(Text(student.fullName)),
                DataCell(
                  _buildMarksInput(context, student.id, entry),
                ),
                DataCell(
                  _buildStatusDropdown(context, student.id, entry),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMarksInput(BuildContext context, String studentId, StudentMarkEntry entry) {
    final controller = TextEditingController(
      text: entry.marks > 0 ? entry.marks.toString() : '',
    );
    return SizedBox(
      width: 100,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          hintText: '0',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: UIConstants.paddingSmall,
            vertical: UIConstants.paddingSmall,
          ),
        ),
        onChanged: (value) {
          final marks = double.tryParse(value) ?? 0.0;
          context.read<MarksEntryBloc>().add(
                UpdateStudentMarkValue(
                  studentId: studentId,
                  marks: marks,
                ),
              );
        },
      ),
    );
  }

  Widget _buildStatusDropdown(BuildContext context, String studentId, StudentMarkEntry entry) {
    return DropdownButton<StudentMarkStatus>(
      value: entry.status,
      items: StudentMarkStatus.values.map((status) {
        return DropdownMenuItem(
          value: status,
          child: Text(status.displayName),
        );
      }).toList(),
      onChanged: (status) {
        if (status != null) {
          context.read<MarksEntryBloc>().add(
                UpdateStudentMarkStatus(
                  studentId: studentId,
                  status: status,
                ),
              );
        }
      },
    );
  }

  Widget _buildActionButtons(BuildContext context, MarksEntryReady state) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload CSV'),
            onPressed: () {
              // TODO: Implement CSV upload dialog
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('CSV upload not yet implemented')),
              );
            },
          ),
        ),
        SizedBox(width: UIConstants.spacing12),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check_circle),
            label: const Text('Submit Marks'),
            onPressed: state.isDraft
                ? () {
                    context.read<MarksEntryBloc>().add(
                          const SubmitExamMarks(),
                        );
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
          ),
        ),
      ],
    );
  }

  void _showSubmissionSummary(BuildContext context, MarksSubmissionSummary summary) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Marks Submitted Successfully'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _summaryRow('Total Students', summary.totalStudents.toString()),
            _summaryRow('Marked Present', summary.markedPresent.toString()),
            _summaryRow('Absent', summary.absent.toString()),
            _summaryRow('Medical Leave', summary.medicalLeave.toString()),
            const Divider(),
            _summaryRow('Average', summary.average.toStringAsFixed(2)),
            _summaryRow('Highest', summary.highestMarks.toStringAsFixed(2)),
            _summaryRow('Lowest', summary.lowestMarks.toStringAsFixed(2)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop(); // Go back to previous page
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: UIConstants.spacing8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}
