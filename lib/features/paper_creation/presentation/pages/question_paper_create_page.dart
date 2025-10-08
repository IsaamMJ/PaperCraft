import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../../core/presentation/routes/app_routes.dart';
import '../../../../core/presentation/widgets/common_state_widgets.dart';
import '../../../../core/presentation/widgets/info_box.dart';
import '../../../../core/presentation/widgets/step_progress_indicator.dart';
import '../../../authentication/domain/entities/user_role.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../../catalog/domain/entities/exam_type_entity.dart';
import '../../../catalog/domain/entities/grade_entity.dart';
import '../../../catalog/domain/entities/subject_entity.dart';
import '../../../catalog/presentation/bloc/exam_type_bloc.dart' as exam_type;
import '../../../catalog/presentation/bloc/grade_bloc.dart';
import '../../../catalog/presentation/bloc/subject_bloc.dart';
import '../../domain/services/question_input_coordinator.dart';

class QuestionPaperCreatePage extends StatefulWidget {
  const QuestionPaperCreatePage({super.key});

  @override
  State<QuestionPaperCreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<QuestionPaperCreatePage> with TickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  int _currentStep = 1;
  final int _totalSteps = 2;

  // Form state
  List<GradeEntity> _availableGrades = [];
  GradeEntity? _selectedGrade;
  int? _selectedGradeLevel;
  List<String> _availableSections = [];
  List<String> _selectedSections = [];
  bool _isSectionsLoading = false;

  List<ExamTypeEntity> _availableExamTypes = [];
  ExamTypeEntity? _selectedExamType;
  DateTime? _selectedExamDate;

  List<SubjectEntity> _availableSubjects = [];
  SubjectEntity? _selectedSubject;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));

    _loadInitialData();
    context.read<exam_type.ExamTypeBloc>().add(const exam_type.LoadExamTypes());

    // Set smart default for exam date (7 days from now)
    _selectedExamDate = DateTime.now().add(const Duration(days: 7));

    Future.delayed(
      const Duration(milliseconds: 200),
          () => mounted ? _animController.forward() : null,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _loadInitialData() {
    final userStateService = sl<UserStateService>();
    final currentUser = userStateService.currentUser;
    final isTeacher = currentUser?.role == UserRole.teacher;

    context.read<GradeBloc>().add(LoadAssignedGrades(
      teacherId: isTeacher ? currentUser?.id : null,
      academicYear: userStateService.currentAcademicYear,
    ));
  }

  void _loadSubjectsForSelectedGrade() {
    final userStateService = sl<UserStateService>();
    final currentUser = userStateService.currentUser;
    final isTeacher = currentUser?.role == UserRole.teacher;

    context.read<SubjectBloc>().add(LoadAssignedSubjects(
      teacherId: isTeacher ? currentUser?.id : null,
      academicYear: userStateService.currentAcademicYear,
    ));
  }

  String _generateAutoTitle() {
    if (_selectedExamType != null && _selectedGradeLevel != null && _selectedSubject != null) {
      final subject = _selectedSubject!.name.split(' ').first;
      final examTypeShort = _selectedExamType!.name.replaceAll('Examination', 'Exam');
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
      return '$subject G$_selectedGradeLevel $examTypeShort #$timestamp';
    }
    return 'Paper #${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
  }

  String _getAcademicYear(DateTime examDate) {
    final year = examDate.year;
    final month = examDate.month;
    return month >= 6 ? '$year-${year + 1}' : '${year - 1}-$year';
  }

  bool _isStepValid(int step) {
    switch (step) {
      case 1:
        // All metadata must be filled: Grade, Subject, Exam Type, Date, Sections
        return _selectedGradeLevel != null &&
            _selectedSubject != null &&
            _selectedExamType != null &&
            _selectedExamDate != null &&
            !_isSectionsLoading &&
            (_availableSections.isEmpty || _selectedSections.isNotEmpty);
      default:
        return true;
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

  void _onGradeSelected(GradeEntity grade) {
    setState(() {
      _selectedGrade = grade;
      _selectedGradeLevel = grade.gradeNumber;
      _selectedSections.clear();
      _selectedSubject = null;
      _availableSections.clear();
      _isSectionsLoading = true;
    });

    context.read<GradeBloc>().add(LoadSectionsByGrade(grade.gradeNumber));
    _loadSubjectsForSelectedGrade();
  }

  void _onSectionToggled(String section, bool selected) {
    setState(() {
      selected ? _selectedSections.add(section) : _selectedSections.remove(section);
    });
  }

  Future<void> _selectExamDate() async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime lastDate = DateTime(now.year + 1);

    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedExamDate ?? today.add(const Duration(days: 7)),
      firstDate: today,
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
      setState(() => _selectedExamDate = selectedDate);
    }
  }

  String _formatExamDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<exam_type.ExamTypeBloc, exam_type.ExamTypeState>(
          listener: (context, state) {
            if (state is exam_type.ExamTypesLoaded) {
              setState(() => _availableExamTypes = state.examTypes);
            }
          },
        ),
        BlocListener<GradeBloc, GradeState>(
          listener: (context, state) {
            if (state is GradesLoaded) {
              setState(() => _availableGrades = state.grades);
            }
            if (state is SectionsLoaded) {
              setState(() {
                _availableSections = state.sections;
                _isSectionsLoading = false;
              });
            }
          },
        ),
        BlocListener<SubjectBloc, SubjectState>(
          listener: (context, state) {
            if (state is SubjectsLoaded) {
              setState(() => _availableSubjects = state.subjects);
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: CustomScrollView(
              slivers: [
                _buildAppBar(),
                SliverPadding(
                  padding: const EdgeInsets.all(UIConstants.paddingMedium),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildProgressIndicator(),
                      SizedBox(height: UIConstants.spacing24),
                      _buildCurrentStep(),
                      SizedBox(height: UIConstants.spacing32),
                      _buildNavigationButtons(),
                      const SizedBox(height: 100),
                    ]),
                  ),
                ),
              ],
            ),
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
        onPressed: _navigateBack,
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
    return StepProgressIndicator(
      currentStep: _currentStep,
      totalSteps: _totalSteps,
      stepTitle: _getStepTitle(_currentStep),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 1: return 'Quick Setup';
      case 2: return 'Add Questions';
      default: return '';
    }
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 1: return _buildQuickSetupStep();
      case 2: return _buildQuestionsStep();
      default: return Container();
    }
  }

  Widget _buildQuickSetupStep() {
    return _buildStepCard(
      'Quick Setup',
      'Configure your question paper details',
      SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grade Selection
            BlocBuilder<GradeBloc, GradeState>(
              builder: (context, state) {
                if (state is GradeLoading) {
                  return LoadingWidget(message: state.message ?? 'Loading...');
                }

                if (state is GradeError) {
                  return ErrorStateWidget(message: state.message, onRetry: _loadInitialData);
                }

                if (_availableGrades.isEmpty) {
                  return EmptyMessageWidget(
                    icon: Icons.school_outlined,
                    title: 'No Grades Available',
                    message: 'Contact your administrator.',
                  );
                }

                return DropdownButtonFormField<GradeEntity>(
                  value: _selectedGrade,
                  hint: const Text('Select Grade Level'),
                  decoration: InputDecoration(
                    labelText: 'Grade Level',
                    filled: true,
                    fillColor: AppColors.backgroundSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                    prefixIcon: Icon(Icons.school_rounded, color: AppColors.textSecondary),
                  ),
                  items: _availableGrades.map((grade) {
                    return DropdownMenuItem(
                      value: grade,
                      child: Text('Grade ${grade.gradeNumber}'),
                    );
                  }).toList(),
                  onChanged: (grade) {
                    if (grade != null) _onGradeSelected(grade);
                  },
                );
              },
            ),

            // Subject Selection (only show if grade selected)
            if (_selectedGradeLevel != null) ...[
              SizedBox(height: UIConstants.spacing24),
              BlocBuilder<SubjectBloc, SubjectState>(
                builder: (context, state) {
                  if (state is SubjectLoading) {
                    return const InfoBox(message: 'Loading subjects...');
                  }

                  if (state is SubjectError) {
                    return Text('Error: ${state.message}', style: TextStyle(color: AppColors.error));
                  }

                  if (_availableSubjects.isEmpty) {
                    return const InfoBox(message: 'No subjects available for this grade');
                  }

                  return DropdownButtonFormField<SubjectEntity>(
                    value: _selectedSubject,
                    hint: const Text('Select Subject'),
                    decoration: InputDecoration(
                      labelText: 'Subject',
                      filled: true,
                      fillColor: AppColors.backgroundSecondary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                      ),
                      prefixIcon: Icon(Icons.subject_rounded, color: AppColors.textSecondary),
                    ),
                    items: _availableSubjects.map((subject) {
                      return DropdownMenuItem(
                        value: subject,
                        child: Text(subject.name),
                      );
                    }).toList(),
                    onChanged: (subject) {
                      setState(() => _selectedSubject = subject);
                    },
                  );
                },
              ),
            ],

            // Sections (only show if grade selected)
            if (_selectedGradeLevel != null) ...[
              SizedBox(height: UIConstants.spacing24),
              if (_isSectionsLoading)
                const InfoBox(message: 'Loading sections...')
              else if (_availableSections.isEmpty)
                const InfoBox(message: 'This paper will apply to all sections')
              else
                _buildSectionSelector(),
            ],

            // Exam Type Selection (only show if grade and subject selected)
            if (_selectedGradeLevel != null && _selectedSubject != null) ...[
              SizedBox(height: UIConstants.spacing24),
              BlocBuilder<exam_type.ExamTypeBloc, exam_type.ExamTypeState>(
                builder: (context, state) {
                  if (state is exam_type.ExamTypeLoading) {
                    return const InfoBox(message: 'Loading exam types...');
                  }

                  if (state is exam_type.ExamTypeError) {
                    return Text('Error: ${state.message}', style: TextStyle(color: AppColors.error));
                  }

                  if (_availableExamTypes.isEmpty) {
                    return const InfoBox(message: 'No exam types available');
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Exam Type',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: UIConstants.spacing12),
                      ..._availableExamTypes.map((type) => _buildExamTypeCard(type)),
                    ],
                  );
                },
              ),
            ],

            // Exam Date (only show if exam type selected)
            if (_selectedExamType != null) ...[
              SizedBox(height: UIConstants.spacing24),
              Text(
                'Exam Date',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: UIConstants.spacing12),
              GestureDetector(
                onTap: _selectExamDate,
                child: Container(
                  padding: const EdgeInsets.all(UIConstants.paddingMedium),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                    border: Border.all(
                      color: _selectedExamDate != null ? AppColors.primary : AppColors.border,
                      width: _selectedExamDate != null ? 2 : 1,
                    ),
                    color: _selectedExamDate != null
                        ? AppColors.primary.withValues(alpha: 0.05)
                        : AppColors.backgroundSecondary,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: _selectedExamDate != null
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedExamDate != null
                              ? _formatExamDate(_selectedExamDate!)
                              : 'Select exam date',
                          style: TextStyle(
                            fontSize: 16,
                            color: _selectedExamDate != null
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontWeight: _selectedExamDate != null
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_drop_down,
                          color: _selectedExamDate != null
                              ? AppColors.primary
                              : AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Sections',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: UIConstants.spacing12),
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
              selectedColor: AppColors.primary.withValues(alpha: 0.1),
              checkmarkColor: AppColors.primary,
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 2 : 1,
              ),
            );
          }).toList(),
        ),
        if (_selectedSections.isEmpty) ...[
          SizedBox(height: UIConstants.spacing8),
          Text(
            'Please select at least one section',
            style: TextStyle(color: AppColors.error, fontSize: UIConstants.fontSizeMedium),
          ),
        ],
      ],
    );
  }


  Widget _buildExamTypeCard(ExamTypeEntity type) {
    final isSelected = _selectedExamType?.id == type.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedExamType = type),
          borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
          child: Container(
            padding: const EdgeInsets.all(UIConstants.paddingMedium),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 2 : 1,
              ),
              color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : AppColors.surface,
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: 2,
                    ),
                    color: isSelected ? AppColors.primary : Colors.transparent,
                  ),
                  child: isSelected ? Icon(Icons.check, size: 12, color: Colors.white) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${type.formattedDuration} • ${type.totalMarks} marks • ${type.sections.length} sections',
                        style: TextStyle(
                          fontSize: UIConstants.fontSizeSmall,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionsStep() {
    if (_selectedSubject == null || _selectedExamDate == null || _selectedGrade == null) {
      return Container();
    }

    final autoTitle = _generateAutoTitle();
    final userStateService = sl<UserStateService>();
    final academicYear = _getAcademicYear(_selectedExamDate!);

    return QuestionInputCoordinator(
      sections: _selectedExamType!.sections,
      examType: _selectedExamType!,
      selectedSubjects: [_selectedSubject!],
      paperTitle: autoTitle,
      gradeLevel: _selectedGradeLevel!,
      gradeId: _selectedGrade!.id,
      academicYear: academicYear,
      selectedSections: _selectedSections.isNotEmpty ? _selectedSections : ['All'],
      examDate: _selectedExamDate,
      isAdmin: userStateService.isAdmin,
      onPaperCreated: (paper) {
        _showSuccess();
      },
    );
  }

  Widget _buildStepCard(String title, String subtitle, Widget child) {
    return Container(
      padding: const EdgeInsets.all(UIConstants.paddingLarge),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: UIConstants.spacing8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          SizedBox(height: UIConstants.spacing24),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
          ),
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
      label: Text(_currentStep == 1 ? 'Add Questions' : 'Next'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                  ),
                ),
              ),
            ),
        ],
    );
  }


  void _showSuccess() {
    _showMessage('Question paper created successfully!', AppColors.success);
    Future.delayed(
      const Duration(seconds: 1),
          () => mounted ? context.go(AppRoutes.home) : null,
    );
  }

  void _showMessage(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == AppColors.success ? Icons.check_circle : Icons.error,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        ),
      ),
    );
  }

  void _navigateBack() {
    try {
      context.canPop() ? context.pop() : context.go(AppRoutes.home);
    } catch (e) {
      context.go(AppRoutes.home);
    }
  }
}