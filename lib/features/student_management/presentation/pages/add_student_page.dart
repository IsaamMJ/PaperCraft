import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:papercraft/core/presentation/constants/app_colors.dart';
import 'package:papercraft/core/presentation/constants/ui_constants.dart';
import 'package:papercraft/features/student_management/presentation/bloc/student_enrollment_bloc.dart';
import 'package:papercraft/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:papercraft/features/authentication/presentation/bloc/auth_state.dart';

/// Add Student Page
///
/// Allows users (typically admins) to add a single student to a grade/section.
/// Features:
/// - Display selected grade/section prominently
/// - Form validation for roll number, name, email, phone
/// - Auto-association with grade_section_id
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

  String? _gradeNumber;
  String? _sectionName;
  bool _loadingGradeSection = true;

  @override
  void initState() {
    super.initState();
    _loadGradeSectionDetails();
  }

  Future<void> _loadGradeSectionDetails() async {
    try {
      print('[DEBUG ADD STUDENT] Loading grade section details for: ${widget.gradeSectionId}');

      final authBloc = context.read<AuthBloc>();
      String? tenantId;

      if (authBloc.state is AuthAuthenticated) {
        final user = (authBloc.state as AuthAuthenticated).user;
        tenantId = user.tenantId;
      }

      if (tenantId == null) {
        print('[DEBUG ADD STUDENT] Could not get tenant ID');
        return;
      }

      final supabase = Supabase.instance.client;

      // Fetch grade section with related grade info
      final gradeSection = await supabase
          .from('grade_sections')
          .select('*, grades(grade_number)')
          .eq('id', widget.gradeSectionId)
          .eq('tenant_id', tenantId)
          .single();

      if (mounted) {
        setState(() {
          _gradeNumber = gradeSection['grades']['grade_number'].toString();
          _sectionName = gradeSection['section_name'] as String;
          _loadingGradeSection = false;
          print('[DEBUG ADD STUDENT] Loaded: Grade $_gradeNumber Section $_sectionName');
        });
      }
    } catch (e) {
      print('[DEBUG ADD STUDENT] Error loading grade section: $e');
      if (mounted) {
        setState(() {
          _loadingGradeSection = false;
        });
      }
    }
  }

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
    print('[DEBUG ADD STUDENT] Page build - gradeSectionId: ${widget.gradeSectionId}');
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
          print('[DEBUG ADD STUDENT] BlocListener state changed: ${state.runtimeType}');
          if (state is StudentAdded) {
            print('[DEBUG ADD STUDENT] Student added successfully!');
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
            print('[DEBUG ADD STUDENT] Student enrollment error: ${state.message}');
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
    print('[DEBUG ADD STUDENT] Building header');

    if (_loadingGradeSection) {
      return Container(
        padding: EdgeInsets.all(UIConstants.paddingLarge),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

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
          SizedBox(height: UIConstants.spacing16),
          // Grade Section Allocation Card
          Container(
            padding: EdgeInsets.all(UIConstants.paddingMedium),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.class_,
                  color: Colors.white,
                  size: UIConstants.iconMedium,
                ),
                SizedBox(width: UIConstants.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Grade & Section Allocation',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: UIConstants.spacing4),
                      Text(
                        'Grade $_gradeNumber • Section $_sectionName',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    print('[DEBUG ADD STUDENT] Building form');
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
            // Info Note
            Container(
              padding: EdgeInsets.all(UIConstants.paddingMedium),
              decoration: BoxDecoration(
                color: AppColors.primary10,
                borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                border: Border.all(color: AppColors.primary30),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.primary,
                    size: UIConstants.iconMedium,
                  ),
                  SizedBox(width: UIConstants.spacing12),
                  Expanded(
                    child: Text(
                      'Grade & section are automatically set to Grade $_gradeNumber Section $_sectionName',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: UIConstants.fontSizeSmall,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: UIConstants.spacing24),

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
        print('[DEBUG ADD STUDENT] Building submit button - isLoading: $isLoading');

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
    print('[DEBUG ADD STUDENT] Submit button clicked');
    print('[DEBUG ADD STUDENT] gradeSectionId: "${widget.gradeSectionId}"');
    if (_formKey.currentState?.validate() ?? false) {
      print('[DEBUG ADD STUDENT] Form validation passed');
      final rollNumber = _rollNumberController.text.trim();
      final fullName = _fullNameController.text.trim();
      final email = _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim();
      final phone = _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim();

      print('[DEBUG ADD STUDENT] Adding student: rollNumber=$rollNumber, fullName=$fullName, email=$email, phone=$phone, gradeSectionId="${widget.gradeSectionId}"');

      context.read<StudentEnrollmentBloc>().add(
            AddSingleStudent(
              gradeSectionId: widget.gradeSectionId,
              rollNumber: rollNumber,
              fullName: fullName,
              email: email,
              phone: phone,
            ),
          );
      print('[DEBUG ADD STUDENT] AddSingleStudent event added to BLoC');
    } else {
      print('[DEBUG ADD STUDENT] Form validation failed');
    }
  }
}
