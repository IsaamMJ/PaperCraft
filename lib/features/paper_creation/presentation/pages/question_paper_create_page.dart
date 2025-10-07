import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../../core/presentation/routes/app_routes.dart';
import '../../../../core/presentation/utils/ui_helpers.dart';
import '../../../authentication/domain/entities/user_role.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../../catalog/domain/entities/exam_type_entity.dart';
import '../../../catalog/domain/entities/grade_entity.dart';
import '../../../catalog/domain/entities/subject_entity.dart';
import '../../../catalog/presentation/bloc/exam_type_bloc.dart';
import '../../../catalog/presentation/bloc/exam_type_bloc.dart' as exam_type;
import '../../../catalog/presentation/bloc/grade_bloc.dart';
import '../../../catalog/presentation/bloc/subject_bloc.dart';
import '../../../paper_workflow/presentation/bloc/question_paper_bloc.dart';
import '../../domain/services/paper_validation_service.dart';
import '../widgets/question_input/question_input_dialog.dart';

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
  final int _totalSteps = 4;

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

  bool _isCreating = false;

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
        return _selectedGradeLevel != null &&
            !_isSectionsLoading &&
            (_availableSections.isEmpty || _selectedSections.isNotEmpty);
      case 2:
        return _selectedExamType != null && _selectedExamDate != null;
      case 3:
        return _selectedSubject != null;
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Step $_currentStep of $_totalSteps',
                style: TextStyle(
                  fontSize: UIConstants.fontSizeMedium,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              Text(
                _getStepTitle(_currentStep),
                style: TextStyle(
                  fontSize: UIConstants.fontSizeMedium,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          SizedBox(height: UIConstants.spacing12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _currentStep / _totalSteps,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 1: return 'Basic Info';
      case 2: return 'Exam Setup';
      case 3: return 'Subject';
      case 4: return 'Review';
      default: return '';
    }
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 1: return _buildStep1();
      case 2: return _buildStep2();
      case 3: return _buildStep3();
      case 4: return _buildStep4();
      default: return Container();
    }
  }

  Widget _buildStep1() {
    return _buildStepCard(
      'Basic Information',
      'Select the grade level and sections for your question paper',
      BlocBuilder<GradeBloc, GradeState>(
        builder: (context, state) {
          if (state is GradeLoading) {
            return _buildLoading(state.message ?? 'Loading grades...');
          }

          if (state is GradeError) {
            return _buildError(state.message, _loadInitialData);
          }

          if (_availableGrades.isEmpty) {
            return _buildEmptyMessage(
              Icons.school_outlined,
              sl<UserStateService>().isTeacher ? 'No Grades Assigned' : 'No Grades Available',
              sl<UserStateService>().isTeacher
                  ? 'Contact your administrator to get assigned to grades.'
                  : 'Add grades in Settings → Manage Grades.',
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<GradeEntity>(
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
              ),
              if (_selectedGradeLevel != null) ...[
                SizedBox(height: UIConstants.spacing24),
                if (_isSectionsLoading)
                  _buildInfoBox('Loading sections...')
                else if (_availableSections.isEmpty)
                  _buildInfoBox('This paper will apply to all sections')
                else
                  _buildSectionSelector(),
              ],
            ],
          );
        },
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
              selectedColor: AppColors.primary.withOpacity(0.1),
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

  Widget _buildStep2() {
    return _buildStepCard(
      'Exam Configuration',
      'Configure the exam type and schedule',
      BlocBuilder<exam_type.ExamTypeBloc, exam_type.ExamTypeState>(
        builder: (context, state) {
          if (state is exam_type.ExamTypeLoading) {
            return _buildLoading('Loading exam types...');
          }

          if (state is exam_type.ExamTypeError) {
            return _buildError(state.message, () {
              context.read<exam_type.ExamTypeBloc>().add(const exam_type.LoadExamTypes());
            });
          }

          if (_availableExamTypes.isEmpty) {
            return _buildEmptyMessage(
              Icons.quiz_outlined,
              'No Exam Types Available',
              'Contact your administrator to add exam types.',
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Exam Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              SizedBox(height: UIConstants.spacing12),
              ..._availableExamTypes.map((type) => _buildExamTypeCard(type)),
              if (_selectedExamType != null) ...[
                SizedBox(height: UIConstants.spacing24),
                Text('Exam Date', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
                          ? AppColors.primary.withOpacity(0.05)
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
          );
        },
      ),
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
              color: isSelected ? AppColors.primary.withOpacity(0.05) : AppColors.surface,
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

  Widget _buildStep3() {
    return _buildStepCard(
      'Subject Selection',
      'Choose the subject for this question paper',
      BlocBuilder<SubjectBloc, SubjectState>(
        builder: (context, state) {
          if (state is SubjectLoading) {
            return _buildLoading(state.message ?? 'Loading subjects...');
          }

          if (state is SubjectError) {
            return _buildError(state.message, _loadSubjectsForSelectedGrade);
          }

          if (_availableSubjects.isEmpty) {
            return _buildEmptyMessage(
              Icons.subject_outlined,
              sl<UserStateService>().isTeacher ? 'No Subjects Assigned' : 'No Subjects Available',
              sl<UserStateService>().isTeacher
                  ? 'Contact your administrator for subject assignments.'
                  : 'Add subjects in Settings → Manage Subjects.',
            );
          }

          return Column(
            children: _availableSubjects.map((subject) => _buildSubjectCard(subject)).toList(),
          );
        },
      ),
    );
  }

  Widget _buildSubjectCard(SubjectEntity subject) {
    final isSelected = _selectedSubject?.id == subject.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedSubject = subject),
          borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
          child: Container(
            padding: const EdgeInsets.all(UIConstants.paddingMedium),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 2 : 1,
              ),
              color: isSelected ? AppColors.primary.withOpacity(0.05) : AppColors.surface,
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
                  child: Text(
                    subject.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep4() {
    return _buildStepCard(
      'Review & Create',
      'Review your paper configuration',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(UIConstants.paddingMedium),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.05),
                  AppColors.secondary.withOpacity(0.05)
                ],
              ),
              borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _generateAutoTitle(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: UIConstants.spacing12),
                _buildPreviewRow(Icons.school_rounded, 'Grade', 'Grade $_selectedGradeLevel'),
                _buildPreviewRow(Icons.calendar_today, 'Exam Date',
                    _selectedExamDate != null ? _formatExamDate(_selectedExamDate!) : 'Not set'),
                _buildPreviewRow(Icons.class_rounded, 'Sections',
                    _selectedSections.isNotEmpty ? _selectedSections.join(', ') : 'All'),
                _buildPreviewRow(Icons.quiz_rounded, 'Exam Type', _selectedExamType!.name),
                _buildPreviewRow(Icons.access_time_rounded, 'Duration',
                    _selectedExamType!.formattedDuration),
                _buildPreviewRow(Icons.grade_rounded, 'Total Marks',
                    '${_selectedExamType!.totalMarks}'),
                _buildPreviewRow(Icons.subject_rounded, 'Subject', _selectedSubject!.name),
              ],
            ),
          ),
          SizedBox(height: UIConstants.spacing20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: !_isCreating ? _proceedToQuestions : null,
              icon: _isCreating
                  ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
                  : const Icon(Icons.add_rounded),
              label: Text(_isCreating ? 'Creating...' : 'Create Questions'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                ),
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
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textSecondary),
          ),
          Expanded(child: Text(value, style: TextStyle(color: AppColors.textPrimary))),
        ],
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
            color: Colors.black.withOpacity(0.04),
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
      label: Text(_currentStep == _totalSteps - 1 ? 'Review' : 'Next'),
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

  // Helper widgets
  Widget _buildLoading(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMessage(IconData icon, String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _proceedToQuestions() {
    if (_isCreating || _selectedSubject == null || _selectedExamDate == null || _selectedGrade == null) {
      return;
    }

    final autoTitle = _generateAutoTitle();
    final userStateService = sl<UserStateService>();

    final errors = PaperValidationService.validatePaperForCreation(
      title: autoTitle,
      gradeLevel: _selectedGradeLevel,
      selectedSections: _selectedSections,
      selectedSubjects: [_selectedSubject!],
      examType: _selectedExamType,
    );

    if (errors.isNotEmpty) {
      _showMessage(errors.first, AppColors.error);
      return;
    }

    setState(() => _isCreating = true);

    final academicYear = _getAcademicYear(_selectedExamDate!);

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
              UiHelpers.showErrorMessage(context, state.message);
            }
          },
          child: QuestionInputDialog(
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
            onPaperCreated: (_) {},
          ),
        ),
      ),
    ).then((_) => setState(() => _isCreating = false));
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