import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/routes/app_routes.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../domain/entities/exam_type_entity.dart';
import '../../domain/entities/subject_entity.dart';
import '../../domain/services/subject_grade_service.dart';
import '../../domain/services/paper_validation_service.dart';
import '../bloc/question_paper_bloc.dart';
import '../bloc/grade_bloc.dart';
import '../bloc/subject_bloc.dart';
import '../widgets/question_input/question_input_dialog.dart';

class QuestionPaperCreatePage extends StatefulWidget {
  const QuestionPaperCreatePage({super.key});

  @override
  State<QuestionPaperCreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<QuestionPaperCreatePage> with TickerProviderStateMixin {
  List<int> _availableGradeLevels = [];
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  bool _isSectionsLoading = false;
  DateTime? _selectedExamDate;


  // Step management
  int _currentStep = 1;
  final int _totalSteps = 4;

  // Form state
  int? _selectedGradeLevel;
  List<String> _availableSections = [];
  List<String> _selectedSections = [];
  ExamTypeEntity? _selectedExamType;
  List<SubjectEntity> _selectedSubjects = [];
  bool _isCreating = false;

  // Exam types will now come from BLoC instead of hardcoded data
  List<ExamTypeEntity> _availableExamTypes = [];


  String _formatExamDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  void initState() {
    super.initState();

    final userStateService = sl<UserStateService>();
    print('=== USER STATE DEBUG ===');
    print('User authenticated: ${userStateService.isAuthenticated}');
    print('Current user: ${userStateService.currentUser}');
    print('User tenantId: ${userStateService.currentUser?.tenantId}');
    print('User isValid: ${userStateService.currentUser?.isValid}');
    print('User info: ${userStateService.getUserInfo()}');
    print('========================');

    _animController = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));



    // Load initial data from BLoC
    context.read<GradeBloc>().add(const LoadGradeLevels());
    context.read<QuestionPaperBloc>().add(const LoadExamTypes());
    // Load all subjects initially
    context.read<SubjectBloc>().add(const LoadSubjects());

    Future.delayed(const Duration(milliseconds: 200), () => mounted ? _animController.forward() : null);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }


  // Smart title generation
  String _generateAutoTitle() {
    if (_selectedExamType != null && _selectedGradeLevel != null && _selectedSubjects.isNotEmpty) {
      final subject = _selectedSubjects.first.name.split(' ').first; // Take first word of subject
      final examTypeShort = _selectedExamType!.name.replaceAll('Examination', 'Exam');
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(8); // Last 5 digits for uniqueness

      return '$subject G$_selectedGradeLevel $examTypeShort #$timestamp';
      // Example: "Math G5 Final Exam #48293"
    }
    return 'Paper #${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
  }
  // Step validation with enhanced checks
  bool _isStepValid(int step) {
    switch (step) {
      case 1:
        return _selectedGradeLevel != null &&
            (_availableSections.isEmpty || _selectedSections.isNotEmpty);
      case 2:
        return _selectedExamType != null && _selectedExamDate != null;
      case 3:
        return _selectedSubjects.isNotEmpty;
      case 4:
        return true;
      default:
        return false;
    }
  }


  void _nextStep() {
    if (_isStepValid(_currentStep) && _currentStep < _totalSteps) {
      setState(() => _currentStep++);
      _animController.reset();
      _animController.forward();
    }
  }

  void _previousStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
      _animController.reset();
      _animController.forward();
    }
  }

  void _onGradeSelected(int gradeLevel) {
    setState(() {
      _selectedGradeLevel = gradeLevel;
      _selectedSections.clear();
      _selectedSubjects.clear();
      _availableSections.clear();

      _isSectionsLoading = true;
    });

    // Load sections for the grade
    context.read<GradeBloc>().add(LoadSectionsByGrade(gradeLevel));

    // Load subjects - this should trigger the listener
    context.read<SubjectBloc>().add(const LoadSubjects());
  }

  void _onSectionToggled(String section, bool selected) {
    setState(() {
      if (selected) {
        _selectedSections.add(section);
      } else {
        _selectedSections.remove(section);
      }
    });
  }

  Future<void> _selectExamDate() async {
    final DateTime now = DateTime.now();
    final DateTime firstDate = now;
    final DateTime lastDate = DateTime(now.year + 1);

    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedExamDate ?? now.add(const Duration(days: 7)), // Default to next week
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null) {
      setState(() {
        _selectedExamDate = selectedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: CustomScrollView(
            slivers: [
              _buildAppBar(),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildProgressIndicator(),
                    const SizedBox(height: 24),
                    _buildCurrentStep(),
                    const SizedBox(height: 32),
                    _buildNavigationButtons(),
                    const SizedBox(height: 100),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary),
        onPressed: () => _navigateBack(),
      ),
      title: Text(
        'Create Paper',
        style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      ),
      actions: [
        if (_currentStep > 1)
          TextButton(
            onPressed: () => setState(() => _currentStep = 1),
            child: Text('Start Over', style: TextStyle(color: AppColors.primary)),
          ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Step $_currentStep of $_totalSteps',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              Text(
                _getStepTitle(_currentStep),
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _currentStep / _totalSteps,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(_totalSteps, (index) {
              final stepNumber = index + 1;
              final isCompleted = stepNumber < _currentStep || _isStepValid(stepNumber);
              final isCurrent = stepNumber == _currentStep;

              return Expanded(
                child: GestureDetector(
                  onTap: stepNumber < _currentStep ? () => setState(() => _currentStep = stepNumber) : null,
                  child: Container(
                    margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppColors.primary.withOpacity(0.1)
                          : isCompleted
                          ? AppColors.success.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                          size: 16,
                          color: isCompleted ? AppColors.success : AppColors.textTertiary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getStepTitle(stepNumber),
                          style: TextStyle(
                            fontSize: 10,
                            color: isCurrent ? AppColors.primary : AppColors.textTertiary,
                            fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 1: return 'Basic Info';
      case 2: return 'Exam Setup';
      case 3: return 'Subjects';
      case 4: return 'Review';
      default: return '';
    }
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2();
      case 3:
        return _buildStep3();
      case 4:
        return _buildStep4();
      default:
        return Container();
    }
  }

  Widget _buildStep1() {
    return _buildStepCard(
      'Basic Information',
      'Select the grade level and sections for your question paper',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grade Level Selection
          BlocListener<GradeBloc, GradeState>(
            listener: (context, state) {
              if (state is GradeLevelsLoaded) {
                setState(() => _availableGradeLevels = state.gradeLevels);
              }
              if (state is SectionsLoaded) {
                setState(() {
                  _availableSections = state.sections;
                  _isSectionsLoading = false;
                });
              }
            },
            child: BlocBuilder<GradeBloc, GradeState>(
              builder: (context, state) {
                if (state is GradeLoading) {
                  return Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(child: CircularProgressIndicator()),
                  );
                }

                if (state is GradeError) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: AppColors.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Failed to load grades',
                                  style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                              Text(state.message, style: TextStyle(color: AppColors.error, fontSize: 12)),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.read<GradeBloc>().add(const LoadGradeLevels()),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final gradeLevels = state is GradeLevelsLoaded ? state.gradeLevels : _availableGradeLevels;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Grade Level Dropdown
                    DropdownButtonFormField<int>(
                      value: _selectedGradeLevel,
                      hint: const Text('Select Grade Level'),
                      decoration: InputDecoration(
                        labelText: 'Grade Level',
                        filled: true,
                        fillColor: AppColors.backgroundSecondary,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                        prefixIcon: Icon(Icons.school_rounded, color: AppColors.textSecondary),
                      ),
                      items: gradeLevels.map((level) {
                        return DropdownMenuItem(value: level, child: Text('Grade $level'));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) _onGradeSelected(value);
                      },
                      validator: (value) => value == null ? 'Please select a grade level' : null,
                    ),

                    // Grade Selection Confirmation
                    if (_selectedGradeLevel != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: AppColors.success, size: 20),
                            const SizedBox(width: 8),
                            Text('Grade $_selectedGradeLevel selected',
                                style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Sections Selection - SINGLE INSTANCE
                      if (_isSectionsLoading) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Loading sections for Grade $_selectedGradeLevel...',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (_availableSections.isEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'This paper will apply to all sections in Grade $_selectedGradeLevel',
                                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Text('Select Sections',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                        Text('Choose which sections this paper will be for:',
                            style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                        const SizedBox(height: 12),

                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: _availableSections.map((section) {
                            final isSelected = _selectedSections.contains(section);
                            return FilterChip(
                              label: Text('Section $section'),
                              selected: isSelected,
                              onSelected: (selected) => _onSectionToggled(section, selected),
                              backgroundColor: AppColors.surface,
                              selectedColor: AppColors.primary.withOpacity(0.1),
                              checkmarkColor: AppColors.primary,
                              elevation: isSelected ? 2 : 0,
                              side: BorderSide(
                                color: isSelected ? AppColors.primary : AppColors.border,
                                width: isSelected ? 2 : 1,
                              ),
                            );
                          }).toList(),
                        ),

                        if (_selectedSections.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Please select at least one section',
                              style: TextStyle(color: AppColors.error, fontSize: 14)),
                        ] else ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, color: AppColors.success, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${_selectedSections.length} section${_selectedSections.length > 1 ? 's' : ''} selected: ${_selectedSections.join(', ')}',
                                    style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildStep2() {
    return _buildStepCard(
      'Exam Configuration',
      'Configure the exam type and schedule for your paper',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exam Type Selection
          Text('Exam Type',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text('Choose the type of examination:',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 12),

          BlocListener<QuestionPaperBloc, QuestionPaperState>(
            listener: (context, state) {
              if (state is QuestionPaperLoaded) {
                setState(() => _availableExamTypes = state.examTypes);
              }
            },
            child: BlocBuilder<QuestionPaperBloc, QuestionPaperState>(
              builder: (context, state) {
                if (state is QuestionPaperLoading) {
                  return Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Loading exam types...'),
                        ],
                      ),
                    ),
                  );
                }

                if (state is QuestionPaperError) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, color: AppColors.error, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          'Failed to load exam types',
                          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          state.message,
                          style: TextStyle(color: AppColors.error, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            context.read<QuestionPaperBloc>().add(const LoadExamTypes());
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final examTypes = state is QuestionPaperLoaded ? state.examTypes : _availableExamTypes;

                if (examTypes.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.warning),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.warning_amber, color: AppColors.warning, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          'No exam types available',
                          style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Please contact your administrator to set up exam types.',
                          style: TextStyle(color: AppColors.warning, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: examTypes.map((type) {
                    final isSelected = _selectedExamType?.id == type.id;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => setState(() => _selectedExamType = type),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : AppColors.border,
                                width: isSelected ? 2 : 1,
                              ),
                              color: isSelected ? AppColors.primary.withOpacity(0.05) : AppColors.surface,
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ] : null,
                            ),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 20, height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: isSelected ? AppColors.primary : AppColors.border, width: 2),
                                    color: isSelected ? AppColors.primary : Colors.transparent,
                                  ),
                                  child: isSelected ? Icon(Icons.check, size: 12, color: Colors.white) : null,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(type.name,
                                          style: TextStyle(fontWeight: FontWeight.w600,
                                              color: isSelected ? AppColors.primary : AppColors.textPrimary)),
                                      Text('${type.formattedDuration} • ${type.calculatedTotalMarks} marks • ${type.sections.length} sections',
                                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),

          // Exam Date Selection (appears after exam type is selected)
          if (_selectedExamType != null) ...[
            const SizedBox(height: 24),
            Text('Exam Date',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text('When will this exam be conducted?',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 12),

            GestureDetector(
              onTap: _selectExamDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedExamDate != null ? AppColors.primary : AppColors.border,
                    width: _selectedExamDate != null ? 2 : 1,
                  ),
                  color: _selectedExamDate != null
                      ? AppColors.primary.withOpacity(0.05)
                      : AppColors.backgroundSecondary,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: _selectedExamDate != null ? AppColors.primary : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedExamDate != null
                            ? _formatExamDate(_selectedExamDate!)
                            : 'Select exam date',
                        style: TextStyle(
                          fontSize: 16,
                          color: _selectedExamDate != null ? AppColors.primary : AppColors.textSecondary,
                          fontWeight: _selectedExamDate != null ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: _selectedExamDate != null ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),

            if (_selectedExamDate != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.success, size: 20),
                    const SizedBox(width: 8),
                    Text(
                        'Exam scheduled for ${_formatExamDate(_selectedExamDate!)}',
                        style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w500)
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // Updated Step 3 method for question_paper_create_page.dart
// Replace the existing _buildStep3 method with this implementation

  Widget _buildStep3() {
    return _buildStepCard(
      'Subject Selection',
      'Choose the subject for this question paper',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject Selection with BLoC integration - SIMPLIFIED
          BlocBuilder<SubjectBloc, SubjectState>(
            builder: (context, state) {
              print('🔍 DEBUG: Building SubjectBloc UI with state: ${state.runtimeType}');

              if (state is SubjectLoading) {
                return Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Loading subjects...'),
                      ],
                    ),
                  ),
                );
              }

              if (state is SubjectError) {
                print('🔍 DEBUG: Showing error UI for: ${state.message}');
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, color: AppColors.error, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        'Failed to load subjects',
                        style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        state.message,
                        style: TextStyle(color: AppColors.error, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          print('🔍 DEBUG: Retry button pressed, loading all subjects');
                          context.read<SubjectBloc>().add(const LoadSubjects());
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Get subjects directly from BLoC state
              final subjectsToShow = state is SubjectsLoaded ? state.subjects : <SubjectEntity>[];
              print('🔍 DEBUG: subjectsToShow length: ${subjectsToShow.length}');

              if (subjectsToShow.isEmpty) {
                print('🔍 DEBUG: No subjects to show, displaying empty state');
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.warning_amber, color: AppColors.warning, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        'No subjects available',
                        style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Please contact your administrator to set up subjects.',
                        style: TextStyle(color: AppColors.warning, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          print('🔍 DEBUG: Reload button pressed');
                          context.read<SubjectBloc>().add(const LoadSubjects());
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reload Subjects'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              }

              print('🔍 DEBUG: Rendering ${subjectsToShow.length} subjects');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Select a subject:',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500)
                  ),
                  const SizedBox(height: 12),

                  // Subject selection with radio button style
                  Column(
                    children: subjectsToShow.map((subject) {
                      final isSelected = _selectedSubjects.contains(subject);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _onSubjectSelected(subject),
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : AppColors.border,
                                  width: isSelected ? 2 : 1,
                                ),
                                color: isSelected ? AppColors.primary.withOpacity(0.05) : AppColors.surface,
                              ),
                              child: Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: isSelected ? AppColors.primary : AppColors.border,
                                          width: 2
                                      ),
                                      color: isSelected ? AppColors.primary : Colors.transparent,
                                    ),
                                    child: isSelected
                                        ? Icon(Icons.check, size: 12, color: Colors.white)
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          subject.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                          ),
                                        ),
                                        if (subject.description != null && subject.description!.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            subject.description!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  if (_selectedSubjects.isEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Please select a subject',
                        style: TextStyle(color: AppColors.error, fontSize: 14)),
                  ] else ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: AppColors.success, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_selectedSubjects.first.name} selected',
                              style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }


  Widget _buildStep4() {
    return _buildStepCard(
      'Review & Create',
      'Review your paper configuration and create questions',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary.withOpacity(0.05), AppColors.secondary.withOpacity(0.05)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_generateAutoTitle(),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                _buildPreviewRow(Icons.school_rounded, 'Grade', 'Grade $_selectedGradeLevel'),
                _buildPreviewRow(Icons.calendar_today, 'Exam Date',
                    _selectedExamDate != null ? _formatExamDate(_selectedExamDate!) : 'Not selected'),
                _buildPreviewRow(Icons.class_rounded, 'Sections',
                    _selectedSections.isNotEmpty ? _selectedSections.join(', ') : 'All sections'),
                _buildPreviewRow(Icons.quiz_rounded, 'Exam Type', _selectedExamType!.name),
                _buildPreviewRow(Icons.access_time_rounded, 'Duration', _selectedExamType!.formattedDuration),
                _buildPreviewRow(Icons.grade_rounded, 'Total Marks', '${_selectedExamType!.calculatedTotalMarks}'),
                _buildPreviewRow(Icons.subject_rounded, 'Subject', _selectedSubjects.map((s) => s.name).join(', ')),
                const SizedBox(height: 12),
                Text('Question Sections:', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                ..._selectedExamType!.sections.map((section) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Container(width: 4, height: 4, decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${section.name} (${section.questions} questions × ${section.marksPerQuestion} marks)',
                            style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: !_isCreating ? _proceedToQuestions : null,
              icon: _isCreating
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                  : const Icon(Icons.add_rounded),
              label: Text(_isCreating ? 'Creating Questions...' : 'Create Questions'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
          Expanded(child: Text(value, style: TextStyle(color: AppColors.textPrimary))),
        ],
      ),
    );
  }

  Widget _buildStepCard(String title, String subtitle, Widget child) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        if (_currentStep > 1)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _previousStep,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Previous'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        if (_currentStep > 1) const SizedBox(width: 16),
        if (_currentStep < _totalSteps)
          Expanded(
            flex: _currentStep == 1 ? 1 : 2,
            child: ElevatedButton.icon(
              onPressed: _isStepValid(_currentStep) ? _nextStep : null,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(_currentStep == _totalSteps - 1 ? 'Review' : 'Next'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                disabledBackgroundColor: AppColors.textTertiary,
              ),
            ),
          ),
        if (_currentStep == 1)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _navigateBack,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Cancel'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
      ],
    );
  }


  void _proceedToQuestions() {
    if (_isCreating) return;

    final autoTitle = _generateAutoTitle();
    final userStateService = sl<UserStateService>();

    if (_selectedExamDate == null) {
      _showMessage('Please select an exam date', AppColors.error);
      return;
    }

    final errors = PaperValidationService.validatePaperForCreation(
      title: autoTitle,
      gradeLevel: _selectedGradeLevel,
      selectedSections: _selectedSections,
      selectedSubjects: _selectedSubjects,
      examType: _selectedExamType,
    );

    if (errors.isNotEmpty) {
      _showMessage(errors.first, AppColors.error);
      return;
    }

    setState(() => _isCreating = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<QuestionPaperBloc>(),
        child: BlocListener<QuestionPaperBloc, QuestionPaperState>(
          listener: (context, state) {
            if (state is QuestionPaperSuccess) {
              Navigator.of(dialogContext).pop();
              _showSuccess();
            } else if (state is QuestionPaperError) {
              setState(() => _isCreating = false);
              Navigator.of(dialogContext).pop();
              _showMessage(state.message, AppColors.error);
            }
          },
          child: QuestionInputDialog(
            sections: _selectedExamType!.sections,
            examType: _selectedExamType!,
            selectedSubjects: _selectedSubjects,
            paperTitle: autoTitle,
            gradeLevel: _selectedGradeLevel!,
            selectedSections: _selectedSections.isNotEmpty ? _selectedSections : ['All'],
            examDate: _selectedExamDate,
            isAdmin: userStateService.isAdmin,
            onPaperCreated: (_) {},
          ),
        ),
      ),
    ).then((_) => setState(() => _isCreating = false));
  }

  void _showSuccess() {
    _showMessage('Question paper created successfully!', AppColors.success);
    Future.delayed(const Duration(seconds: 1), () => mounted ? context.go(AppRoutes.home) : null);
  }

  void _showMessage(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(color == AppColors.success ? Icons.check_circle : Icons.error, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _onSubjectSelected(SubjectEntity subject) {
    setState(() {
      // Clear existing selection and select only the new one
      _selectedSubjects.clear();
      _selectedSubjects.add(subject);
    });
  }

  void _navigateBack() {
    try {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.home);
      }
    } catch (e) {
      context.go(AppRoutes.home);
    }
  }
}