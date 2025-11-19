import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:papercraft/core/presentation/constants/app_colors.dart';
import 'package:papercraft/core/presentation/constants/ui_constants.dart';
import 'package:papercraft/features/student_management/presentation/bloc/student_enrollment_bloc.dart';

/// Bulk Upload Students Page
///
/// Allows administrators to upload multiple students via CSV file.
/// Features:
/// - CSV file selection
/// - Preview of parsed students before upload
/// - Validation error display
/// - Confirmation dialog before final upload
/// - Success summary with new/skipped/error counts
class BulkUploadStudentsPage extends StatefulWidget {
  final String gradeSectionId;

  const BulkUploadStudentsPage({
    required this.gradeSectionId,
    super.key,
  });

  @override
  State<BulkUploadStudentsPage> createState() => _BulkUploadStudentsPageState();
}

class _BulkUploadStudentsPageState extends State<BulkUploadStudentsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bulk Upload Students'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: BlocListener<StudentEnrollmentBloc, StudentEnrollmentState>(
        listener: (context, state) {
          if (state is StudentsBulkUploaded) {
            _showUploadSummary(context, state);
          } else if (state is BulkUploadValidationFailed) {
            final errorMessage = state.errors.isEmpty
              ? 'Validation failed'
              : state.errors.entries.first.value.join(', ');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is StudentEnrollmentError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: BlocBuilder<StudentEnrollmentBloc, StudentEnrollmentState>(
          builder: (context, state) {
            if (state is ValidatingBulkData || state is UploadingStudents) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (state is BulkUploadPreview) {
              return _buildPreviewScreen(context, state);
            }

            // Default empty state
            return SingleChildScrollView(
              padding: EdgeInsets.all(UIConstants.paddingMedium),
              child: Column(
                children: [
                  SizedBox(height: UIConstants.spacing24),
                  _buildHeader(),
                  SizedBox(height: UIConstants.spacing32),
                  _buildUploadInstructions(),
                  SizedBox(height: UIConstants.spacing32),
                  _buildUploadButton(context),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
                Icons.upload_file,
                color: Colors.white,
                size: UIConstants.iconLarge,
              ),
              SizedBox(width: UIConstants.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bulk Upload Students',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    SizedBox(height: UIConstants.spacing4),
                    Text(
                      'Import multiple students via CSV',
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

  Widget _buildUploadInstructions() {
    return Container(
      padding: EdgeInsets.all(UIConstants.paddingLarge),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CSV Format Instructions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          SizedBox(height: UIConstants.spacing12),
          _buildInstructionPoint(
            'Header Row: roll_number,full_name,email,phone',
          ),
          SizedBox(height: UIConstants.spacing8),
          _buildInstructionPoint(
            'Roll Number: Required, max 50 characters, must be unique',
          ),
          SizedBox(height: UIConstants.spacing8),
          _buildInstructionPoint(
            'Full Name: Required, 2-100 characters',
          ),
          SizedBox(height: UIConstants.spacing8),
          _buildInstructionPoint(
            'Email: Optional, must be valid email format',
          ),
          SizedBox(height: UIConstants.spacing8),
          _buildInstructionPoint(
            'Phone: Optional, 10-15 digits only',
          ),
          SizedBox(height: UIConstants.spacing16),
          Container(
            padding: EdgeInsets.all(UIConstants.paddingSmall),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
            ),
            child: Text(
              'Example: 001,John Doe,john@example.com,9876543210',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionPoint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(right: UIConstants.spacing8, top: 4),
          child: const Icon(Icons.check_circle, size: 18, color: Colors.green),
        ),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget _buildUploadButton(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(UIConstants.paddingLarge),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.cloud_upload,
            size: 48,
            color: AppColors.primary,
          ),
          SizedBox(height: UIConstants.spacing16),
          Text(
            'Select CSV File',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          SizedBox(height: UIConstants.spacing12),
          ElevatedButton.icon(
            icon: const Icon(Icons.attach_file),
            label: const Text('Choose File'),
            onPressed: () {
              // TODO: Implement file picker
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('File picker not yet implemented'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewScreen(BuildContext context, BulkUploadPreview state) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(UIConstants.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPreviewHeader(state),
          SizedBox(height: UIConstants.spacing16),
          _buildPreviewList(state),
          SizedBox(height: UIConstants.spacing24),
          _buildPreviewActions(context, state),
        ],
      ),
    );
  }

  Widget _buildPreviewHeader(BulkUploadPreview state) {
    return Container(
      padding: EdgeInsets.all(UIConstants.paddingLarge),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preview',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          SizedBox(height: UIConstants.spacing12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total',
                  state.totalRows.toString(),
                  Colors.blue,
                ),
              ),
              SizedBox(width: UIConstants.spacing12),
              Expanded(
                child: _buildStatCard(
                  'Valid',
                  state.studentData.length.toString(),
                  Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(UIConstants.paddingSmall),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewList(BulkUploadPreview state) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: state.studentData.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final student = state.studentData[index];
          return ListTile(
            leading: const Icon(Icons.check_circle, color: Colors.green),
            title: Text(student['full_name'] ?? ''),
            subtitle: Text('Roll: ${student['roll_number'] ?? ''}'),
            trailing: const Icon(Icons.done, color: Colors.green),
          );
        },
      ),
    );
  }

  Widget _buildPreviewActions(BuildContext context, BulkUploadPreview state) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ),
        SizedBox(width: UIConstants.spacing12),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            onPressed: state.studentData.isEmpty
                ? null
                : () => _confirmUpload(context, state),
            child: const Text('Upload'),
          ),
        ),
      ],
    );
  }

  void _confirmUpload(BuildContext context, BulkUploadPreview state) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Upload'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will add ${state.studentData.length} student(s) to this grade section.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<StudentEnrollmentBloc>().add(
                    BulkUploadStudents(
                      studentData: state.studentData,
                    ),
                  );
            },
            child: const Text('Confirm Upload'),
          ),
        ],
      ),
    );
  }

  void _showUploadSummary(BuildContext context, StudentsBulkUploaded state) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Upload Complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _summaryRow('Total Added', state.students.length.toString(), Colors.green),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop(); // Go back to student list
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, [Color? color]) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: UIConstants.spacing8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
