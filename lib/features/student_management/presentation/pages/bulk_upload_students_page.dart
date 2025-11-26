import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:papercraft/core/presentation/constants/app_colors.dart';
import 'package:papercraft/core/presentation/constants/ui_constants.dart';
import 'package:papercraft/core/infrastructure/di/injection_container.dart';
import 'package:papercraft/features/student_management/presentation/bloc/student_enrollment_bloc.dart';
import 'package:papercraft/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:papercraft/features/authentication/presentation/bloc/auth_state.dart';
import 'package:papercraft/features/authentication/domain/services/user_state_service.dart';
import 'package:papercraft/features/catalog/domain/entities/grade_entity.dart';
import 'package:papercraft/features/catalog/domain/entities/grade_section.dart';

/// Bulk Upload Students Page
///
/// Allows administrators to upload multiple students via CSV file.
/// Features:
/// - Grade and section selection
/// - CSV file selection
/// - Preview of parsed students before upload
/// - Validation error display
/// - Confirmation dialog before final upload
/// - Success summary with new/skipped/error counts
class BulkUploadStudentsPage extends StatefulWidget {
  final String? gradeSectionId;

  const BulkUploadStudentsPage({
    this.gradeSectionId,
    super.key,
  });

  @override
  State<BulkUploadStudentsPage> createState() => _BulkUploadStudentsPageState();
}

class _BulkUploadStudentsPageState extends State<BulkUploadStudentsPage> {
  @override
  void initState() {
    super.initState();
  }

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
          print('[DEBUG UPLOAD] BLoC state changed: ${state.runtimeType}');

          if (state is StudentsBulkUploaded) {
            _showUploadSummary(context, state);
          } else if (state is BulkUploadValidationFailed) {
            final errorMessage = state.errors.isEmpty
              ? 'Validation failed'
              : state.errors.entries.first.value.join(', ');
            print('[DEBUG UPLOAD] Validation failed: $errorMessage');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          } else if (state is StudentEnrollmentError) {
            print('[DEBUG UPLOAD] Upload error: ${state.message}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
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
            'Header Row: roll_number,full_name,grade,section,gender,date_of_birth,email,phone',
          ),
          SizedBox(height: UIConstants.spacing8),
          _buildInstructionPoint(
            'Roll Number: Required, max 50 characters, must be unique within grade/section',
          ),
          SizedBox(height: UIConstants.spacing8),
          _buildInstructionPoint(
            'Full Name: Required, 2-100 characters',
          ),
          SizedBox(height: UIConstants.spacing8),
          _buildInstructionPoint(
            'Grade: Required, numeric (e.g., I, II, III) or (9, 10, 11)',
          ),
          SizedBox(height: UIConstants.spacing8),
          _buildInstructionPoint(
            'Section: Required, letter (e.g., A, B, C)',
          ),
          SizedBox(height: UIConstants.spacing8),
          _buildInstructionPoint(
            'Gender: Optional (Male, Female, Other)',
          ),
          SizedBox(height: UIConstants.spacing8),
          _buildInstructionPoint(
            'Date of Birth: Optional (YYYY-MM-DD format)',
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
              'Example: 001,John Doe,I,A,Male,2010-05-15,john@example.com,9876543210',
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
      ['roll_number', 'full_name', 'grade', 'section', 'gender', 'date_of_birth', 'email', 'phone'],
      // Sample data rows
      ['001', 'John Doe', 'I', 'A', 'Male', '2010-05-15', 'john.doe@example.com', '9876543210'],
      ['002', 'Jane Smith', 'I', 'A', 'Female', '2010-08-22', 'jane.smith@example.com', '9876543211'],
      ['003', 'Alice Johnson', 'I', 'B', 'Female', '2010-12-03', 'alice.johnson@example.com', '9876543212'],
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
    // Group students by grade and section
    final groupedStudents = <String, List<Map<String, String>>>{};

    for (final student in state.studentData) {
      final grade = student['grade'] ?? 'Unknown';
      final section = student['section'] ?? 'Unknown';
      final key = 'Grade $grade - Section $section';

      groupedStudents.putIfAbsent(key, () => []);
      groupedStudents[key]!.add(student);
    }

    // Sort keys
    final sortedKeys = groupedStudents.keys.toList()..sort();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: sortedKeys.length,
        itemBuilder: (context, index) {
          final key = sortedKeys[index];
          final students = groupedStudents[key]!;

          return _buildGradeSectionGroup(key, students);
        },
      ),
    );
  }

  Widget _buildGradeSectionGroup(String title, List<Map<String, String>> students) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Row(
          children: [
            Icon(Icons.folder_open, color: AppColors.primary, size: 20),
            SizedBox(width: UIConstants.spacing12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: UIConstants.spacing8,
                vertical: UIConstants.spacing4,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary10,
                borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
              ),
              child: Text(
                '${students.length} students',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        initiallyExpanded: true,
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: students.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final student = students[index];
              return Padding(
                padding: EdgeInsets.symmetric(vertical: UIConstants.spacing8),
                child: ListTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    student['full_name'] ?? '',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Roll: ${student['roll_number'] ?? ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: student['email'] != null && student['email']!.isNotEmpty
                      ? Tooltip(
                          message: student['email']!,
                          child: Icon(
                            Icons.email,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        )
                      : null,
                ),
              );
            },
          ),
        ],
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
                : () {
                    print('[DEBUG UPLOAD] Upload button clicked in preview');
                    _confirmUpload(context, state);
                  },
            child: const Text('Upload'),
          ),
        ),
      ],
    );
  }

  void _confirmUpload(BuildContext context, BulkUploadPreview state) {
    print('[DEBUG UPLOAD] _confirmUpload called');
    // Capture the BLoC reference before showing the dialog to avoid context issues
    final bloc = context.read<StudentEnrollmentBloc>();
    print('[DEBUG UPLOAD] BLoC instance captured: $bloc');

    print('[DEBUG UPLOAD] About to show dialog...');
    showDialog(
      context: context,
      builder: (dialogContext) {
        print('[DEBUG UPLOAD] Dialog builder called');
        return AlertDialog(
          title: const Text('Confirm Upload'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will add ${state.studentData.length} student(s) across their respective grades and sections.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                print('[DEBUG UPLOAD] Confirm button pressed');
                print('[DEBUG UPLOAD] Event will have ${state.studentData.length} students');

                final event = ValidateStudentData(
                  gradeSectionId: '', // Not used, each student has their own gradeSectionId
                  studentData: state.studentData,
                );
                print('[DEBUG UPLOAD] Event created: ${event.runtimeType}');
                print('[DEBUG UPLOAD] BLoC instance: $bloc');
                bloc.add(event);
                print('[DEBUG UPLOAD] Event added to BLoC');

                // Close dialog AFTER adding event
                Navigator.pop(dialogContext);
              },
              child: const Text('Confirm Upload'),
            ),
          ],
        );
      },
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

      // Get tenant ID for grade/section lookup
      final authBloc = context.read<AuthBloc>();
      String? tenantId;
      if (authBloc.state is AuthAuthenticated) {
        final user = (authBloc.state as AuthAuthenticated).user;
        tenantId = user.tenantId;
      }

      if (tenantId == null) {
        _showError(context, 'Error: Could not get tenant information');
        return;
      }

      // Fetch grades and sections to build a lookup map
      try {
        final supabase = Supabase.instance.client;

        // Fetch all grades and sections for this tenant
        final gradesData = await supabase
            .from('grades')
            .select()
            .eq('tenant_id', tenantId)
            .eq('is_active', true);

        final sectionsData = await supabase
            .from('grade_sections')
            .select()
            .eq('tenant_id', tenantId)
            .eq('is_active', true);

        // Build maps for quick lookup
        final gradeMap = <String, String>{}; // grade_number -> grade_id
        final sectionMap = <String, String>{}; // "${grade_id}|${section_name}" -> section_id

        for (final grade in gradesData) {
          gradeMap[grade['grade_number'].toString()] = grade['id'];
        }

        for (final section in sectionsData) {
          final key = "${section['grade_id']}|${section['section_name']}";
          sectionMap[key] = section['id'];
        }

        // Enrich student data with grade_section_id
        final enrichedData = <Map<String, String>>[];
        for (final student in studentData) {
          final gradeStr = student['grade'] as String?;
          final sectionStr = student['section'] as String?;

          if (gradeStr == null || sectionStr == null) {
            continue;
          }

          final gradeId = gradeMap[gradeStr];
          if (gradeId == null) {
            _showError(context, 'Grade "$gradeStr" not found in system');
            return;
          }

          final sectionKey = "$gradeId|$sectionStr";
          final gradeSectionId = sectionMap[sectionKey];
          if (gradeSectionId == null) {
            _showError(context, 'Section "$sectionStr" not found for Grade "$gradeStr"');
            return;
          }

          // Create the enriched student data with grade/section for preview display
          enrichedData.add({
            'roll_number': student['roll_number'].toString(),
            'full_name': student['full_name'].toString(),
            'gender': student['gender']?.toString() ?? '',
            'date_of_birth': student['date_of_birth']?.toString() ?? '',
            'email': student['email']?.toString() ?? '',
            'phone': student['phone']?.toString() ?? '',
            'grade': gradeStr,
            'section': sectionStr,
            'grade_section_id': gradeSectionId,
          });
        }

        if (enrichedData.isEmpty) {
          _showError(context, 'No valid students found after processing');
          return;
        }

        // Show preview with the enriched student data
        if (mounted) {
          context.read<StudentEnrollmentBloc>().add(
            BulkUploadStudents(
              studentData: enrichedData,
              gradeSectionId: '', // Not used anymore, but required by event
            ),
          );
        }
      } catch (e) {
        _showError(context, 'Error processing students: ${e.toString()}');
      }
    } catch (e) {
      _showError(context, 'Error reading file: ${e.toString()}');
    }
  }

  /// Parse CSV data and convert to student map format
  List<Map<String, dynamic>> _parseCSVData(List<List<dynamic>> csvData) {
    final List<Map<String, dynamic>> students = [];

    print('[DEBUG CSV PARSE] Total rows in CSV: ${csvData.length}');

    // Skip header row (index 0)
    for (int i = 1; i < csvData.length; i++) {
      final row = csvData[i];

      // Skip empty rows
      if (row.isEmpty || row.every((cell) => cell == null || cell.toString().trim().isEmpty)) {
        print('[DEBUG CSV PARSE] Row $i is empty, skipping');
        continue;
      }

      try {
        // Extract fields from CSV row (roll_number, full_name, grade, section, gender, date_of_birth, email, phone)
        final rollNumber = row.isNotEmpty ? row[0]?.toString().trim() ?? '' : '';
        final fullName = row.length > 1 ? row[1]?.toString().trim() ?? '' : '';
        final grade = row.length > 2 ? row[2]?.toString().trim() ?? '' : '';
        final section = row.length > 3 ? row[3]?.toString().trim() ?? '' : '';
        final gender = row.length > 4 ? row[4]?.toString().trim() ?? '' : '';
        final dateOfBirth = row.length > 5 ? row[5]?.toString().trim() ?? '' : '';
        final email = row.length > 6 ? row[6]?.toString().trim() ?? '' : '';
        final phone = row.length > 7 ? row[7]?.toString().trim() ?? '' : '';

        print('[DEBUG CSV PARSE] Row $i: rollNumber=$rollNumber, fullName=$fullName, grade=$grade, section=$section, gender=$gender, dob=$dateOfBirth, email=$email, phone=$phone');

        // Skip if required fields are missing
        if (rollNumber.isEmpty || fullName.isEmpty || grade.isEmpty || section.isEmpty) {
          print('[DEBUG CSV PARSE] Row $i has empty required fields, skipping');
          continue;
        }

        // Validate roll number (max 50 chars)
        if (rollNumber.length > 50) {
          print('[DEBUG CSV PARSE] Row $i: rollNumber too long (${rollNumber.length} > 50), skipping');
          continue;
        }

        // Validate full name (2-100 characters)
        if (fullName.length < 2 || fullName.length > 100) {
          print('[DEBUG CSV PARSE] Row $i: fullName invalid length (${fullName.length}), skipping');
          continue;
        }

        // Validate email format if provided
        if (email.isNotEmpty && !_isValidEmail(email)) {
          print('[DEBUG CSV PARSE] Row $i: email invalid format ($email), skipping');
          continue;
        }

        // Validate phone (10-15 digits only if provided)
        if (phone.isNotEmpty && !_isValidPhone(phone)) {
          print('[DEBUG CSV PARSE] Row $i: phone invalid format ($phone), skipping');
          continue;
        }

        // Add to list (grade and section will be used to look up grade_section_id later)
        students.add({
          'roll_number': rollNumber,
          'full_name': fullName,
          'grade': grade,
          'section': section,
          'gender': gender.isEmpty ? null : gender,
          'date_of_birth': dateOfBirth.isEmpty ? null : dateOfBirth,
          'email': email.isEmpty ? null : email,
          'phone': phone.isEmpty ? null : phone,
        });
        print('[DEBUG CSV PARSE] Row $i: added successfully');
      } catch (e) {
        // Skip invalid rows
        print('[DEBUG CSV PARSE] Row $i: exception caught - $e');
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
