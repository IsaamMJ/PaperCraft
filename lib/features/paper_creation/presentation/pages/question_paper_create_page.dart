import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../../core/infrastructure/logging/app_logger.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../../core/presentation/routes/app_routes.dart';
import '../../../../core/presentation/widgets/common_state_widgets.dart';
import '../../../../core/presentation/widgets/info_box.dart';
import '../../../../core/presentation/widgets/step_progress_indicator.dart';
import '../../../authentication/domain/entities/user_role.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../../assignments/domain/repositories/assignment_repository.dart';
import '../../../catalog/domain/entities/grade_entity.dart';
import '../../../catalog/domain/entities/paper_section_entity.dart';
import '../../../catalog/domain/entities/subject_entity.dart';
import '../../../catalog/domain/entities/exam_type.dart';
import '../../../catalog/presentation/bloc/grade_bloc.dart';
import '../../../catalog/presentation/bloc/subject_bloc.dart';
import '../../../catalog/presentation/bloc/teacher_pattern_bloc.dart';
import '../../../catalog/presentation/widgets/pattern_selector_widget.dart';
import '../../../catalog/presentation/widgets/section_builder_widget.dart';
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

  List<PaperSectionEntity> _paperSections = [];
  DateTime? _selectedExamDate;

  List<SubjectEntity> _availableSubjects = [];
  SubjectEntity? _selectedSubject;

  // Exam type fields
  ExamType? _selectedExamType;
  final TextEditingController _examNumberController = TextEditingController();

  bool _showPatternSelector = false; // Manual toggle for pattern selector

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
    _examNumberController.dispose();
    super.dispose();
  }

  void _loadInitialData() {
    final userStateService = sl<UserStateService>();
    final currentUser = userStateService.currentUser;
    final isTeacher = currentUser?.role == UserRole.teacher;

    // Check if teacher has assigned grades/subjects - if not, redirect to setup
    if (isTeacher && currentUser != null) {
      _checkTeacherSetupStatus(currentUser.id, userStateService.currentAcademicYear);
    }

    context.read<GradeBloc>().add(LoadAssignedGrades(
      teacherId: isTeacher ? currentUser?.id : null,
      academicYear: userStateService.currentAcademicYear,
    ));
  }

  Future<void> _checkTeacherSetupStatus(String teacherId, String academicYear) async {
    try {
      final assignmentRepository = sl<AssignmentRepository>();

      // Check if teacher has any assigned grades
      final gradesResult = await assignmentRepository.getTeacherAssignedGrades(
        teacherId,
        academicYear,
      );

      if (gradesResult.isLeft()) {
        // Error getting grades, continue anyway
        return;
      }

      final grades = gradesResult.fold((_) => null, (g) => g);

      if (grades == null || grades.isEmpty) {
        // Teacher has no assigned grades - redirect to profile setup
        if (mounted) {
          AppLogger.info('Teacher has no assigned grades, redirecting to profile setup',
              category: LogCategory.auth);
          context.go(AppRoutes.teacherProfileSetup);
        }
      }
    } catch (e) {
      AppLogger.warning('Error checking teacher setup status',
          category: LogCategory.auth,
          context: {'error': e.toString()});
      // Continue anyway on error
    }
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
    if (_selectedSubject != null && _selectedExamDate != null && _selectedGradeLevel != null) {
      final dateStr = DateFormat('dd MMM yyyy').format(_selectedExamDate!);
      return 'Grade $_selectedGradeLevel ${_selectedSubject!.name} - $dateStr';
    }
    return 'Untitled Paper';
  }

  String _getAcademicYear(DateTime examDate) {
    final year = examDate.year;
    final month = examDate.month;
    return month >= 6 ? '$year-${year + 1}' : '${year - 1}-$year';
  }

  /// Calculate total marks required from all paper sections
  num _getTotalMarks() {
    return _paperSections.fold(0.0, (sum, section) => sum + section.totalMarks);
  }

  /// Format marks to show decimals properly (0.5 instead of 0)
  String _formatMarks(num marks) {
    if (marks == marks.toInt()) {
      return marks.toInt().toString();
    }
    return marks.toString();
  }

  bool _isStepValid(int step) {
    switch (step) {
      case 1:
        // All metadata must be filled: Grade, Subject, Exam Type, Paper Sections, Date, Class Sections
        return _selectedGradeLevel != null &&
            _selectedSubject != null &&
            _selectedExamType != null &&
            _paperSections.isNotEmpty &&
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

    if (selectedDate != null && mounted) {
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
        BlocListener<GradeBloc, GradeState>(
          listener: (context, state) {
            if (state is GradesLoaded) {
              if (!mounted) return;
              setState(() => _availableGrades = state.grades);
            }
            if (state is SectionsLoaded) {
              if (!mounted) return;
              setState(() {
                _availableSections = state.sections;
                _isSectionsLoading = false;
              });
            }
            // Handle error state for sections loading
            if (state is GradeError) {
              if (!mounted) return;
              setState(() {
                _isSectionsLoading = false;
                _availableSections = [];
              });
            }
          },
        ),
        BlocListener<SubjectBloc, SubjectState>(
          listener: (context, state) {
            if (state is SubjectsLoaded) {
              if (!mounted) return;
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
            // Validation Summary (show if attempted to proceed with errors)
            if (!_isStepValid(1)) _buildValidationSummary(),
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

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Grade Level',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableGrades.map((grade) {
                        final isSelected = _selectedGrade?.id == grade.id;
                        return FilterChip(
                          label: Text('Grade ${grade.gradeNumber}'),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              _onGradeSelected(grade);
                            } else {
                              setState(() => _selectedGrade = null);
                            }
                          },
                          backgroundColor: Colors.transparent,
                          selectedColor: AppColors.primary.withOpacity(0.2),
                          side: BorderSide(
                            color: isSelected ? AppColors.primary : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
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

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Subject',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableSubjects.map((subject) {
                          final isSelected = _selectedSubject?.id == subject.id;
                          return FilterChip(
                            label: Text(subject.name),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedSubject = subject;
                                  _showPatternSelector = false; // Reset pattern selector when subject changes
                                } else {
                                  _selectedSubject = null;
                                  _showPatternSelector = false;
                                }
                              });
                            },
                            backgroundColor: Colors.transparent,
                            selectedColor: AppColors.primary.withOpacity(0.2),
                            side: BorderSide(
                              color: isSelected ? AppColors.primary : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  );
                },
              ),
            ],

            // Exam Type Selection (only show if subject selected)
            if (_selectedSubject != null) ...[
              SizedBox(height: UIConstants.spacing24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Exam Type',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ExamType.allTypes.map((examType) {
                      final isSelected = _selectedExamType == examType;
                      return FilterChip(
                        label: Text(examType.displayName),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedExamType = selected ? examType : null;
                          });
                        },
                        backgroundColor: Colors.transparent,
                        selectedColor: AppColors.primary.withOpacity(0.2),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ],

            // Exam Number Input (only show if exam type selected)
            if (_selectedExamType != null) ...[
              SizedBox(height: UIConstants.spacing24),
              TextFormField(
                controller: _examNumberController,
                decoration: InputDecoration(
                  labelText: 'Exam Number (Optional)',
                  hintText: 'e.g., 1 for "Daily Test - 1"',
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
                  prefixIcon: Icon(Icons.numbers_outlined, color: AppColors.textSecondary),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
              ),
            ],

            // Sections (only show if grade selected)
            if (_selectedGradeLevel != null) ...[
              SizedBox(height: UIConstants.spacing24),
              if (_isSectionsLoading)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary05,
                    borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                    border: Border.all(color: AppColors.primary20),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Loading class sections...',
                        style: TextStyle(
                          fontSize: UIConstants.fontSizeMedium,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              else if (_availableSections.isEmpty)
                const InfoBox(message: 'This paper will apply to all sections')
              else
                _buildSectionSelector(),
            ],

            // Pattern Selector and Section Builder (only show if grade and subject selected)
            if (_selectedGradeLevel != null && _selectedSubject != null) ...[
              SizedBox(height: UIConstants.spacing24),

              // Manual Pattern Selector Toggle (click to load)
              if (!_showPatternSelector)
                Card(
                  child: InkWell(
                    onTap: () {
                      setState(() => _showPatternSelector = true);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.history, color: AppColors.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Load Previous Pattern',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tap to load a previously used pattern',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                )
              else
                // Only load PatternSelectorWidget when user explicitly requests it
                BlocProvider(
                  create: (context) => sl<TeacherPatternBloc>(),
                  child: Builder(
                    builder: (context) {
                      final currentUser = sl<UserStateService>().currentUser;
                      if (currentUser == null) {
                        return Center(
                          child: Text(
                            'User not logged in. Please restart the app.',
                            style: TextStyle(color: AppColors.error),
                          ),
                        );
                      }
                      return PatternSelectorWidget(
                        key: ValueKey(_selectedSubject!.id),
                        teacherId: currentUser.id,
                        subjectId: _selectedSubject!.id,
                        onPatternSelected: (sections) {
                          setState(() => _paperSections = sections);
                        },
                      );
                    },
                  ),
                ),

              SizedBox(height: UIConstants.spacing24),

              // Edit Pattern button - allows changing pattern after selection
              if (_paperSections.isNotEmpty) ...[
                Row(
                  children: [
                    Text(
                      'Question Pattern',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () async {
                        // Show confirmation dialog before clearing pattern
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Edit Question Pattern?'),
                            content: const Text(
                              'This will clear all sections in your current pattern. '
                              'You can then rebuild the pattern from scratch or load a saved pattern.\n\n'
                              'Are you sure you want to continue?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.warning,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Clear & Edit'),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true) {
                          setState(() {
                            _paperSections = [];
                            _showPatternSelector = false;
                          });
                        }
                      },
                      icon: Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit Pattern'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: UIConstants.spacing12),
              ],

              // Section Builder
              SectionBuilderWidget(
                initialSections: _paperSections,
                onSectionsChanged: (sections) {
                  // Validate for duplicate section names
                  final sectionNames = sections.map((s) => s.name.toLowerCase()).toList();
                  final uniqueNames = sectionNames.toSet();

                  if (sectionNames.length != uniqueNames.length) {
                    // Show error for duplicate names
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Duplicate section names are not allowed. Each section must have a unique name.'),
                        backgroundColor: AppColors.error,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                    return; // Don't update sections if there are duplicates
                  }

                  setState(() => _paperSections = sections);
                },
              ),
            ],

            // Exam Date (only show if sections are built)
            if (_paperSections.isNotEmpty) ...[
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
                        ? AppColors.primary05
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

  Widget _buildValidationSummary() {
    // REMOVED: Validation warning dialog has been completely removed as per user request
    // Previously showed: "Please complete the following: Grade level is required, Subject is required, etc."
    return const SizedBox.shrink();
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
              selectedColor: AppColors.primary10,
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



  Widget _buildQuestionsStep() {
    if (_selectedSubject == null || _selectedExamDate == null || _selectedGrade == null || _paperSections.isEmpty) {
      return Container();
    }

    final autoTitle = _generateAutoTitle();
    final userStateService = sl<UserStateService>();
    final academicYear = _getAcademicYear(_selectedExamDate!);

    return BlocProvider(
      create: (context) => sl<TeacherPatternBloc>(),
      child: QuestionInputCoordinator(
        paperSections: _paperSections,
        selectedSubjects: [_selectedSubject!],
        paperTitle: autoTitle,
        gradeLevel: _selectedGradeLevel!,
        gradeId: _selectedGrade!.id,
        academicYear: academicYear,
        selectedSections: _selectedSections.isNotEmpty ? _selectedSections : ['All'],
        examType: _selectedExamType!,
        examNumber: _examNumberController.text.isEmpty ? null : int.tryParse(_examNumberController.text),
        examDate: _selectedExamDate,
        isAdmin: userStateService.isAdmin,
        onPaperCreated: (paper) {
          _showSuccess();
        },
      ),
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
            color: AppColors.black04,
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
      label: Text(_currentStep == 1
          ? 'Add Questions (${_formatMarks(_getTotalMarks())} marks)'
          : 'Next'),
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
      const Duration(milliseconds: 1500),
      () {
        if (!mounted) return;
        // Navigate back to home using proper navigation
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      },
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
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }
}