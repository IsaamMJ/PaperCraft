import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:papercraft/core/presentation/constants/app_colors.dart';
import 'package:papercraft/core/presentation/constants/ui_constants.dart';
import 'package:papercraft/features/student_management/presentation/bloc/student_enrollment_bloc.dart';

/// Add Student Page
///
/// Allows users (typically admins) to add a single student to a grade/section.
/// Features:
/// - Form validation for roll number, name, email, phone
/// - Async submission with loading state
/// - Error display with field-level feedback
/// - Success navigation back to student list
class AddStudentPage extends StatefulWidget {
  final String gradeSectionId;

  const AddStudentPage({
    required this.gradeSectionId,
    super.key,
  });

  @override
  State<AddStudentPage> createState() => _AddStudentPageState();
}

class _AddStudentPageState extends State<AddStudentPage> {
  final _formKey = GlobalKey<FormState>();
  final _rollNumberController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _rollNumberController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Student'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: BlocListener<StudentEnrollmentBloc, StudentEnrollmentState>(
        listener: (context, state) {
          if (state is StudentAdded) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Student added successfully'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
            // Navigate back to student list
            context.pop();
          } else if (state is StudentEnrollmentError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.all(UIConstants.paddingMedium),
          child: Column(
            children: [
              SizedBox(height: UIConstants.spacing24),
              _buildHeader(),
              SizedBox(height: UIConstants.spacing32),
              _buildForm(context),
            ],
          ),
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
                Icons.person_add,
                color: Colors.white,
                size: UIConstants.iconLarge,
              ),
              SizedBox(width: UIConstants.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add New Student',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    SizedBox(height: UIConstants.spacing4),
                    Text(
                      'Enter student details below',
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

  Widget _buildForm(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(UIConstants.paddingLarge),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Roll Number Field
            _buildLabel('Roll Number'),
            TextFormField(
              controller: _rollNumberController,
              decoration: InputDecoration(
                hintText: 'e.g., 001',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: UIConstants.paddingMedium,
                  vertical: UIConstants.paddingSmall,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Roll number is required';
                }
                if (value.length > 50) {
                  return 'Roll number must be 50 characters or less';
                }
                return null;
              },
            ),
            SizedBox(height: UIConstants.spacing16),

            // Full Name Field
            _buildLabel('Full Name'),
            TextFormField(
              controller: _fullNameController,
              decoration: InputDecoration(
                hintText: 'Enter student name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: UIConstants.paddingMedium,
                  vertical: UIConstants.paddingSmall,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Name is required';
                }
                if (value.length < 2) {
                  return 'Name must be at least 2 characters';
                }
                if (value.length > 100) {
                  return 'Name must be 100 characters or less';
                }
                return null;
              },
            ),
            SizedBox(height: UIConstants.spacing16),

            // Email Field
            _buildLabel('Email (Optional)'),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                hintText: 'student@example.com',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: UIConstants.paddingMedium,
                  vertical: UIConstants.paddingSmall,
                ),
              ),
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final emailRegex = RegExp(
                    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                  );
                  if (!emailRegex.hasMatch(value)) {
                    return 'Enter a valid email address';
                  }
                }
                return null;
              },
            ),
            SizedBox(height: UIConstants.spacing16),

            // Phone Field
            _buildLabel('Phone (Optional)'),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                hintText: '10 to 15 digits',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: UIConstants.paddingMedium,
                  vertical: UIConstants.paddingSmall,
                ),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final phoneRegex = RegExp(r'^\d{10,15}$');
                  if (!phoneRegex.hasMatch(value)) {
                    return 'Phone must be 10 to 15 digits';
                  }
                }
                return null;
              },
            ),
            SizedBox(height: UIConstants.spacing32),

            // Submit Button
            _buildSubmitButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: UIConstants.spacing8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    return BlocBuilder<StudentEnrollmentBloc, StudentEnrollmentState>(
      builder: (context, state) {
        final isLoading = state is AddingStudent;

        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading ? null : () => _submitForm(context),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(
                vertical: UIConstants.paddingMedium,
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Add Student'),
          ),
        );
      },
    );
  }

  void _submitForm(BuildContext context) {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<StudentEnrollmentBloc>().add(
            AddSingleStudent(
              gradeSectionId: widget.gradeSectionId,
              rollNumber: _rollNumberController.text.trim(),
              fullName: _fullNameController.text.trim(),
              email: _emailController.text.trim().isEmpty
                  ? null
                  : _emailController.text.trim(),
              phone: _phoneController.text.trim().isEmpty
                  ? null
                  : _phoneController.text.trim(),
            ),
          );
    }
  }
}
