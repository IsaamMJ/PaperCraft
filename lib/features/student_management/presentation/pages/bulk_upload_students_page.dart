import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
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
          // Download Template Button
          OutlinedButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('Download Template'),
            onPressed: () {
              _downloadCsvTemplate();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('CSV template copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          SizedBox(height: UIConstants.spacing12),
          // Upload File Button
          ElevatedButton.icon(
            icon: const Icon(Icons.attach_file),
            label: const Text('Choose File'),
            onPressed: () => _pickAndParseCSVFile(context),
          ),
        ],
      ),
    );
  }

  /// Generate CSV template with headers and sample data
  String _generateCsvTemplate() {
    final List<List<String>> rows = [
      // Header row
      ['roll_number', 'full_name', 'email', 'phone'],
      // Sample data rows
      ['001', 'John Doe', 'john.doe@example.com', '9876543210'],
      ['002', 'Jane Smith', 'jane.smith@example.com', '9876543211'],
      ['003', 'Alice Johnson', 'alice.johnson@example.com', '9876543212'],
    ];

    // Convert to CSV format
    return rows.map((row) => row.map((cell) {
      // Quote cells that contain commas or quotes
      if (cell.contains(',') || cell.contains('"')) {
        return '"${cell.replaceAll('"', '""')}"';
      }
      return cell;
    }).join(',')).join('\n');
  }

  /// Download CSV template (shows dialog with template content)
  void _downloadCsvTemplate() {
    final csv = _generateCsvTemplate();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('CSV Template'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Copy the template below and save as students.csv',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              SizedBox(height: UIConstants.spacing12),
              Container(
                padding: EdgeInsets.all(UIConstants.paddingSmall),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SelectableText(
                  csv,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(height: UIConstants.spacing12),
              Text(
                'Instructions:\n'
                '1. Copy the text above\n'
                '2. Open a text editor or Excel\n'
                '3. Paste the content\n'
                '4. Fill in your student data\n'
                '5. Save as CSV file',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
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

  /// Pick a CSV file and parse it
  Future<void> _pickAndParseCSVFile(BuildContext context) async {
    try {
      // Open file picker - allow only CSV files
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        // User cancelled the picker
        return;
      }

      final file = result.files.first;

      // Read file content as string
      final content = await file.xFile.readAsString();

      // Parse CSV content
      final List<List<dynamic>> csvData = const CsvToListConverter().convert(content);

      if (csvData.isEmpty) {
        _showError(context, 'CSV file is empty');
        return;
      }

      // Parse and validate students
      final studentData = _parseCSVData(csvData);

      if (studentData.isEmpty) {
        _showError(context, 'No valid students found in CSV file');
        return;
      }

      // Show preview with the parsed student data
      if (mounted) {
        // Trigger preview by adding the BulkUploadStudents event
        // The BLoC will show the preview screen based on the state
        // First convert to List<Map<String, String>>
        final stringStudentData = studentData
            .map((e) => Map<String, String>.from(
              e.map((key, value) => MapEntry(key, value?.toString() ?? '')),
            ))
            .toList();

        // Trigger validation/preview
        context.read<StudentEnrollmentBloc>().add(
          BulkUploadStudents(studentData: stringStudentData),
        );
      }
    } catch (e) {
      _showError(context, 'Error reading file: ${e.toString()}');
    }
  }

  /// Parse CSV data and convert to student map format
  List<Map<String, dynamic>> _parseCSVData(List<List<dynamic>> csvData) {
    final List<Map<String, dynamic>> students = [];

    // Skip header row (index 0)
    for (int i = 1; i < csvData.length; i++) {
      final row = csvData[i];

      // Skip empty rows
      if (row.isEmpty || row.every((cell) => cell == null || cell.toString().trim().isEmpty)) {
        continue;
      }

      try {
        // Extract fields from CSV row
        final rollNumber = row.isNotEmpty ? row[0]?.toString().trim() ?? '' : '';
        final fullName = row.length > 1 ? row[1]?.toString().trim() ?? '' : '';
        final email = row.length > 2 ? row[2]?.toString().trim() ?? '' : '';
        final phone = row.length > 3 ? row[3]?.toString().trim() ?? '' : '';

        // Skip if required fields are missing
        if (rollNumber.isEmpty || fullName.isEmpty) {
          continue;
        }

        // Validate roll number (max 50 chars)
        if (rollNumber.length > 50) {
          continue;
        }

        // Validate full name (2-100 characters)
        if (fullName.length < 2 || fullName.length > 100) {
          continue;
        }

        // Validate email format if provided
        if (email.isNotEmpty && !_isValidEmail(email)) {
          continue;
        }

        // Validate phone (10-15 digits only if provided)
        if (phone.isNotEmpty && !_isValidPhone(phone)) {
          continue;
        }

        // Add to list
        students.add({
          'roll_number': rollNumber,
          'full_name': fullName,
          'email': email.isEmpty ? null : email,
          'phone': phone.isEmpty ? null : phone,
        });
      } catch (e) {
        // Skip invalid rows
        continue;
      }
    }

    return students;
  }

  /// Validate email format
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  /// Validate phone format (10-15 digits)
  bool _isValidPhone(String phone) {
    final phoneRegex = RegExp(r'^\d{10,15}$');
    return phoneRegex.hasMatch(phone.replaceAll(RegExp(r'[^\d]'), ''));
  }

  /// Show error dialog
  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        ),
      ),
    );
  }
}
