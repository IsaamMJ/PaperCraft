import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
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

/// Add Student Page
///
/// Allows admins to add a single student to the system.
/// Features:
/// - Grade dropdown (all available grades)
/// - Section dropdown (filtered by selected grade)
/// - Form validation for roll number, name, email, phone
/// - Async submission with loading state
/// - Success navigation back to previous screen
class AddStudentPage extends StatefulWidget {
  final String? gradeSectionId;

  const AddStudentPage({
    this.gradeSectionId,
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

  List<GradeEntity> _grades = [];
  List<GradeSection> _allSections = [];
  List<GradeSection> _filteredSections = [];

  GradeEntity? _selectedGrade;
  GradeSection? _selectedSection;
  String? _selectedGender; // M, F, or Other
  DateTime? _selectedDateOfBirth;

  bool _loadingData = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadGradesAndSections();
  }

  Future<void> _loadGradesAndSections() async {
    try {
      print('[DEBUG ADD STUDENT] Loading grades and sections');

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

      // Fetch all grades
      final gradesData = await supabase
          .from('grades')
          .select()
          .eq('tenant_id', tenantId)
          .eq('is_active', true)
          .order('grade_number');

      // Fetch all grade sections
      final sectionsData = await supabase
          .from('grade_sections')
          .select()
          .eq('tenant_id', tenantId)
          .eq('is_active', true)
          .order('display_order');

      if (mounted) {
        setState(() {
          _grades = List<GradeEntity>.from(
            (gradesData as List).map((g) => GradeEntity(
              id: g['id'] as String,
              tenantId: g['tenant_id'] as String,
              gradeNumber: g['grade_number'] as int,
              isActive: g['is_active'] as bool,
              createdAt: DateTime.parse(g['created_at'] as String),
            )),
          );

          _allSections = List<GradeSection>.from(
            (sectionsData as List).map((s) => GradeSection(
              id: s['id'] as String,
              tenantId: s['tenant_id'] as String,
              gradeId: s['grade_id'] as String,
              sectionName: s['section_name'] as String,
              displayOrder: s['display_order'] as int,
              isActive: s['is_active'] as bool,
              createdAt: DateTime.parse(s['created_at'] as String),
              updatedAt: DateTime.parse(s['updated_at'] as String),
            )),
          );

          _loadingData = false;
          print('[DEBUG ADD STUDENT] Loaded ${_grades.length} grades and ${_allSections.length} sections');
        });
      }
    } catch (e) {
      print('[DEBUG ADD STUDENT] Error loading data: $e');
      if (mounted) {
        setState(() {
          _loadingData = false;
          _loadError = 'Failed to load grades and sections';
        });
      }
    }
  }

  void _onGradeChanged(GradeEntity? grade) {
    setState(() {
      _selectedGrade = grade;
      _selectedSection = null; // Reset section when grade changes

      // Filter sections by selected grade
      if (grade != null) {
        _filteredSections = _allSections
            .where((section) => section.gradeId == grade.id)
            .toList();
        print('[DEBUG ADD STUDENT] Filtered ${_filteredSections.length} sections for grade ${grade.gradeNumber}');
      } else {
        _filteredSections = [];
      }
    });
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
    print('[DEBUG ADD STUDENT] Page build');
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
            // Navigate back to previous screen
            Future.delayed(const Duration(milliseconds: 500), () {
              if (context.mounted) {
                context.pop();
              }
            });
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

    return Container(
      padding: EdgeInsets.all(UIConstants.paddingLarge),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
      ),
      child: Row(
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
                  'Select grade & section to allocate student',
                  style: const TextStyle(color: Colors.white70),
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

    if (_loadingData) {
      return Container(
        padding: EdgeInsets.all(UIConstants.paddingLarge),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_loadError != null) {
      return Container(
        padding: EdgeInsets.all(UIConstants.paddingLarge),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Text(
            _loadError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

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
            // Grade & Section Selection
            _buildLabel('Grade *'),
            DropdownButtonFormField<GradeEntity>(
              value: _selectedGrade,
              items: _grades
                  .map((grade) => DropdownMenuItem(
                        value: grade,
                        child: Text('Grade ${grade.gradeNumber}'),
                      ))
                  .toList(),
              onChanged: _onGradeChanged,
              decoration: InputDecoration(
                hintText: 'Select a grade',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: UIConstants.paddingMedium,
                  vertical: UIConstants.paddingSmall,
                ),
              ),
              validator: (value) {
                if (value == null) {
                  return 'Grade is required';
                }
                return null;
              },
            ),
            SizedBox(height: UIConstants.spacing16),

            // Section Dropdown
            _buildLabel('Section *'),
            DropdownButtonFormField<GradeSection>(
              value: _selectedSection,
              items: _filteredSections
                  .map((section) => DropdownMenuItem(
                        value: section,
                        child: Text(section.sectionName),
                      ))
                  .toList(),
              onChanged: (section) {
                setState(() {
                  _selectedSection = section;
                });
              },
              decoration: InputDecoration(
                hintText: 'Select a section',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: UIConstants.paddingMedium,
                  vertical: UIConstants.paddingSmall,
                ),
              ),
              validator: (value) {
                if (value == null) {
                  return 'Section is required';
                }
                return null;
              },
              disabledHint: Text(
                _selectedGrade == null ? 'Select a grade first' : 'No sections available',
              ),
              isExpanded: true,
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
            SizedBox(height: UIConstants.spacing16),

            // Gender Dropdown
            _buildLabel('Gender (Optional)'),
            DropdownButtonFormField<String>(
              value: _selectedGender,
              onChanged: (value) {
                setState(() => _selectedGender = value);
              },
              items: const [
                DropdownMenuItem(value: 'M', child: Text('Male')),
                DropdownMenuItem(value: 'F', child: Text('Female')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              decoration: InputDecoration(
                hintText: 'Select gender',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: UIConstants.paddingMedium,
                  vertical: UIConstants.paddingSmall,
                ),
              ),
            ),
            SizedBox(height: UIConstants.spacing16),

            // Date of Birth Picker
            _buildLabel('Date of Birth (Optional)'),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDateOfBirth ?? DateTime.now(),
                  firstDate: DateTime(1990),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _selectedDateOfBirth = picked);
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  hintText: 'Tap to select date',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: UIConstants.paddingMedium,
                    vertical: UIConstants.paddingSmall,
                  ),
                  suffixIcon: const Icon(Icons.calendar_today),
                ),
                child: Text(
                  _selectedDateOfBirth != null
                      ? _selectedDateOfBirth!.toString().split(' ')[0]
                      : 'No date selected',
                  style: TextStyle(
                    color: _selectedDateOfBirth != null
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
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
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedSection == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a grade and section'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      print('[DEBUG ADD STUDENT] Form validation passed');
      final rollNumber = _rollNumberController.text.trim();
      final fullName = _fullNameController.text.trim();
      final email = _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim();
      final phone = _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim();

      // Get tenant info for debugging
      final userStateService = sl<UserStateService>();
      print('[DEBUG ADD STUDENT] User state - tenantId: ${userStateService.currentTenantId}, academicYear: ${userStateService.currentAcademicYear}');

      print('[DEBUG ADD STUDENT] Adding student: rollNumber=$rollNumber, fullName=$fullName, email=$email, phone=$phone, gradeSectionId="${_selectedSection!.id}"');

      context.read<StudentEnrollmentBloc>().add(
            AddSingleStudent(
              gradeSectionId: _selectedSection!.id,
              rollNumber: rollNumber,
              fullName: fullName,
              email: email,
              phone: phone,
              gender: _selectedGender,
              dateOfBirth: _selectedDateOfBirth,
              gradeNumber: _selectedGrade?.gradeNumber,
              sectionName: _selectedSection?.sectionName,
            ),
          );
      print('[DEBUG ADD STUDENT] AddSingleStudent event added to BLoC');
    } else {
      print('[DEBUG ADD STUDENT] Form validation failed');
    }
  }
}
