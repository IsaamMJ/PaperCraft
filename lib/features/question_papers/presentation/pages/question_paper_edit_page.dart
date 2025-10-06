import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/routes/app_routes.dart';
import '../../../../core/presentation/utils/ui_helpers.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../domain/entities/question_paper_entity.dart';
import '../../domain/entities/exam_type_entity.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../domain/entities/subject_entity.dart';
import '../../domain/services/subject_grade_service.dart';
import '../bloc/question_paper_bloc.dart';
import '../bloc/grade_bloc.dart';
import '../bloc/shared_bloc_provider.dart';
import '../bloc/subject_bloc.dart';
import '../widgets/question_input/question_input_dialog.dart';

class QuestionPaperEditPage extends StatelessWidget {
  final String questionPaperId;

  const QuestionPaperEditPage({
    super.key,
    required this.questionPaperId,
  });

  @override
  Widget build(BuildContext context) {
    return SharedBlocProvider(
      child: _EditView(questionPaperId: questionPaperId),
    );
  }
}

class _EditView extends StatefulWidget {
  final String questionPaperId;

  const _EditView({required this.questionPaperId});

  @override
  State<_EditView> createState() => _EditViewState();
}

class _EditViewState extends State<_EditView> with TickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late UserStateService _userStateService;

  // Form controllers and state
  final _titleController = TextEditingController();

  // Grade and Section Selection
  List<int> _availableGradeLevels = [];
  int? _selectedGradeLevel;
  List<String> _availableSections = [];
  List<String> _selectedSections = [];

  // Exam type and subjects - Loaded from BLoC
  ExamTypeEntity? _selectedExamType;
  List<SubjectEntity> _selectedSubjects = [];
  List<SubjectEntity> _filteredSubjects = [];

  // Store data loaded from BLoCs
  List<ExamTypeEntity> _availableExamTypes = [];
  List<SubjectEntity> _availableSubjects = [];

  // Paper being edited
  QuestionPaperEntity? _currentPaper;
  bool _isLoaded = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _userStateService = sl<UserStateService>();

    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));

    // Load all required data from BLoCs
    context.read<QuestionPaperBloc>().add(LoadPaperById(widget.questionPaperId));
    context.read<QuestionPaperBloc>().add(const LoadExamTypes());
    context.read<SubjectBloc>().add(const LoadSubjects());
    context.read<GradeBloc>().add(const LoadGradeLevels());

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _animController.forward();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _populateFormFromPaper(QuestionPaperEntity paper) {
    if (_isLoaded) return;

    setState(() {
      _currentPaper = paper;
      _titleController.text = paper.title;
      _selectedGradeLevel = paper.gradeLevel;
      _selectedSections = List.from(paper.selectedSections);

      // Find matching exam type from LOADED data
      if (_availableExamTypes.isNotEmpty) {
        _selectedExamType = _availableExamTypes.firstWhere(
              (examType) => examType.name == paper.examType,
          orElse: () => _availableExamTypes.first,
        );
      }

      // Filter subjects based on grade level from LOADED data
      if (_selectedGradeLevel != null && _availableSubjects.isNotEmpty) {
        _filteredSubjects = SubjectGradeService.filterSubjectsByGrade(
            _availableSubjects,
            _selectedGradeLevel!
        );
      }

      // Find matching subjects from LOADED data
      if (_availableSubjects.isNotEmpty) {
        _selectedSubjects = _availableSubjects.where(
              (subject) => subject.name == paper.subject,
        ).toList();
      }

      _isLoaded = true;
    });

    // Load sections for the selected grade
    if (_selectedGradeLevel != null) {
      context.read<GradeBloc>().add(LoadSectionsByGrade(_selectedGradeLevel!));
    }
  }

  bool get _canSave {
    final titleValid = _titleController.text.trim().isNotEmpty &&
        _titleController.text.trim().length >= 3;
    final gradeValid = _selectedGradeLevel != null;
    final sectionsValid = _selectedSections.isNotEmpty || _availableSections.isEmpty;
    final examTypeValid = _selectedExamType != null;
    final subjectsValid = _selectedSubjects.isNotEmpty;

    return titleValid && gradeValid && sectionsValid && examTypeValid && subjectsValid;
  }

  void _onGradeSelected(int gradeLevel) {
    setState(() {
      _selectedGradeLevel = gradeLevel;
      _selectedSections.clear();
      _selectedSubjects.clear();
      _availableSections.clear();

      // Filter subjects from LOADED data
      if (_availableSubjects.isNotEmpty) {
        _filteredSubjects = SubjectGradeService.filterSubjectsByGrade(
            _availableSubjects,
            gradeLevel
        );
      }
    });

    context.read<GradeBloc>().add(LoadSectionsByGrade(gradeLevel));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: MultiBlocListener(
        listeners: [
          BlocListener<QuestionPaperBloc, QuestionPaperState>(
            listener: (context, state) {
              if (state is QuestionPaperLoaded) {
                // Load paper data
                if (state.currentPaper != null && !_isLoaded) {
                  _populateFormFromPaper(state.currentPaper!);
                }

                // Load exam types when available
                if (state.examTypes.isNotEmpty) {
                  setState(() {
                    _availableExamTypes = state.examTypes;
                    // Re-populate if paper is already loaded
                    if (_currentPaper != null && _selectedExamType == null) {
                      _selectedExamType = _availableExamTypes.firstWhere(
                            (examType) => examType.name == _currentPaper!.examType,
                        orElse: () => _availableExamTypes.first,
                      );
                    }
                  });
                }
              }

              if (state is QuestionPaperSuccess) {
                UiHelpers.showSuccessMessage(context, state.message);
                if (state.actionType == 'save') {
                  setState(() => _isSaving = false);
                  Future.delayed(const Duration(seconds: 1), () {
                    if (mounted) context.go(AppRoutes.home);
                  });
                }
              }

              if (state is QuestionPaperError) {
                setState(() => _isSaving = false);
                UiHelpers.showErrorMessage(context, state.message);
              }
            },
          ),

          BlocListener<SubjectBloc, SubjectState>(
            listener: (context, state) {
              if (state is SubjectsLoaded) {
                setState(() {
                  _availableSubjects = state.subjects;
                  // Re-filter if grade is already selected
                  if (_selectedGradeLevel != null) {
                    _filteredSubjects = SubjectGradeService.filterSubjectsByGrade(
                        _availableSubjects,
                        _selectedGradeLevel!
                    );
                  }
                  // Re-populate selected subjects if paper is loaded
                  if (_currentPaper != null && _selectedSubjects.isEmpty) {
                    _selectedSubjects = _availableSubjects.where(
                          (subject) => subject.name == _currentPaper!.subject,
                    ).toList();
                  }
                });
              }
            },
          ),
        ],
        child: BlocBuilder<QuestionPaperBloc, QuestionPaperState>(
          builder: (context, state) {
            if (state is QuestionPaperLoading) {
              return _buildLoadingState();
            }
            if (state is QuestionPaperError) {
              return _buildErrorState(state.message);
            }
            if (!_isLoaded) {
              return _buildLoadingState();
            }

            return FadeTransition(
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
                          _buildHeader(),
                          SizedBox(height: UIConstants.spacing24),
                          _buildTitleSection(),
                          SizedBox(height: UIConstants.spacing20),
                          _buildGradeSection(),
                          if (_selectedGradeLevel != null) ...[
                            SizedBox(height: UIConstants.spacing20),
                            _buildSectionSelection(),
                          ],
                          if (_selectedGradeLevel != null &&
                              (_selectedSections.isNotEmpty || _availableSections.isEmpty)) ...[
                            SizedBox(height: UIConstants.spacing20),
                            _buildExamTypeSection(),
                          ],
                          if (_selectedExamType != null) ...[
                            SizedBox(height: UIConstants.spacing20),
                            _buildSubjectSection(),
                          ],
                          if (_currentPaper != null && _currentPaper!.questions.isNotEmpty) ...[
                            SizedBox(height: UIConstants.spacing20),
                            _buildCurrentQuestionsSection(),
                          ],
                          if (_selectedExamType != null && _selectedSubjects.isNotEmpty) ...[
                            SizedBox(height: UIConstants.spacing20),
                            _buildPreview(),
                          ],
                          SizedBox(height: UIConstants.spacing32),
                          _buildActions(),
                          const SizedBox(height: 100),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary),
          onPressed: _navigateBack,
        ),
        title: Text(
          'Edit Paper',
          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
            SizedBox(height: UIConstants.spacing24),
            Text(
              'Loading paper details...',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary),
          onPressed: _navigateBack,
        ),
        title: Text(
          'Edit Paper',
          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(UIConstants.radiusXXLarge),
              ),
              child: Icon(Icons.error_outline_rounded, size: 40, color: AppColors.error),
            ),
            SizedBox(height: UIConstants.spacing24),
            Text(
              'Failed to Load Paper',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: UIConstants.spacing8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
            SizedBox(height: UIConstants.spacing32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => context.read<QuestionPaperBloc>().add(LoadPaperById(widget.questionPaperId)),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: _navigateBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Go Back'),
                ),
              ],
            ),
          ],
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
        'Edit Paper',
        style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Edit Question Paper',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: UIConstants.spacing8),
        Text(
          'Update the details and content of your question paper',
          style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
        ),
        if (_currentPaper != null) ...[
          SizedBox(height: UIConstants.spacing12),
          Container(
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
                    'Editing: ${_currentPaper!.title}',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTitleSection() {
    return _buildCard(
      'Paper Title',
      'Update the title of your question paper',
      TextFormField(
        controller: _titleController,
        decoration: InputDecoration(
          hintText: 'e.g., Mathematics Midterm Exam 2024',
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
          prefixIcon: Icon(Icons.title_rounded, color: AppColors.textSecondary),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildGradeSection() {
    return BlocListener<GradeBloc, GradeState>(
      listener: (context, state) {
        if (state is GradeLevelsLoaded) {
          setState(() {
            _availableGradeLevels = state.gradeLevels;
          });
        }
      },
      child: BlocBuilder<GradeBloc, GradeState>(
        builder: (context, state) {
          return _buildCard(
            'Grade Level',
            'Select the grade level for this question paper',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state is GradeLoading)
                  const Center(child: CircularProgressIndicator())
                else if (state is GradeError)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: AppColors.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.message,
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (state is GradeLevelsLoaded || state is SectionsLoaded) ...[
                    DropdownButtonFormField<int>(
                      value: _selectedGradeLevel,
                      hint: const Text('Select Grade Level'),
                      decoration: InputDecoration(
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
                      items: (state is GradeLevelsLoaded ? state.gradeLevels : _availableGradeLevels)
                          .map((level) {
                        return DropdownMenuItem(
                          value: level,
                          child: Text('Grade $level'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          _onGradeSelected(value);
                        }
                      },
                    ),
                    if (_selectedGradeLevel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Selected: Grade $_selectedGradeLevel',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                            fontSize: UIConstants.fontSizeMedium,
                          ),
                        ),
                      ),
                  ] else
                    const Text('Loading grade levels...'),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionSelection() {
    return BlocBuilder<GradeBloc, GradeState>(
      builder: (context, state) {
        if (state is SectionsLoaded) {
          _availableSections = state.sections;
        }

        return _buildCard(
          'Sections',
          'Select which sections this paper applies to',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_availableSections.isEmpty) ...[
                Container(
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
                          'No specific sections found for Grade $_selectedGradeLevel. This paper will apply to all sections.',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
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
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : AppColors.border,
                      ),
                    );
                  }).toList(),
                ),
                if (_selectedSections.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Please select at least one section',
                      style: TextStyle(color: AppColors.error, fontSize: UIConstants.fontSizeMedium),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildExamTypeSection() {
    if (_availableExamTypes.isEmpty) {
      return _buildCard(
        'Exam Type',
        'Choose the type of exam you want to create',
        Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return _buildCard(
      'Exam Type',
      'Choose the type of exam you want to create',
      Column(
        children: _availableExamTypes.map((type) {
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
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: UIConstants.spacing4),
                            Text(
                              '${type.formattedDuration} • ${type.calculatedTotalMarks} marks • ${type.sections.length} sections',
                              style: TextStyle(fontSize: UIConstants.fontSizeMedium, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected) Icon(Icons.check_circle, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSubjectSection() {
    return _buildCard(
      'Subjects',
      'Select subjects for this paper (filtered by Grade $_selectedGradeLevel)',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_filteredSubjects.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_outlined, color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _availableSubjects.isEmpty
                          ? 'Loading subjects...'
                          : 'No subjects available for Grade $_selectedGradeLevel',
                      style: TextStyle(color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              'Available subjects for Grade $_selectedGradeLevel:',
              style: TextStyle(
                fontSize: UIConstants.fontSizeMedium,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: UIConstants.spacing12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _filteredSubjects.map((subject) {
                final isSelected = _selectedSubjects.contains(subject);
                return FilterChip(
                  label: Text(subject.name),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      selected ? _selectedSubjects.add(subject) : _selectedSubjects.remove(subject);
                    });
                  },
                  backgroundColor: AppColors.surface,
                  selectedColor: AppColors.primary.withOpacity(0.1),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                );
              }).toList(),
            ),
            if (_selectedSubjects.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Please select at least one subject',
                  style: TextStyle(color: AppColors.error, fontSize: UIConstants.fontSizeMedium),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildCurrentQuestionsSection() {
    if (_currentPaper == null || _currentPaper!.questions.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildCard(
      'Current Questions',
      'Questions currently in this paper',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._currentPaper!.questions.entries.map((entry) {
            final sectionName = entry.key;
            final questions = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                border: Border.all(color: AppColors.primary.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sectionName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: UIConstants.spacing8),
                  Text(
                    '${questions.length} questions',
                    style: TextStyle(
                      fontSize: UIConstants.fontSizeMedium,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }),
          SizedBox(height: UIConstants.spacing12),
          ElevatedButton.icon(
            onPressed: _editQuestions,
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Edit Questions'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return _buildCard(
      'Preview',
      'Here\'s how your updated paper will look',
      Container(
        padding: const EdgeInsets.all(UIConstants.paddingMedium),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary.withOpacity(0.05), AppColors.secondary.withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _titleController.text.isNotEmpty ? _titleController.text : 'Untitled Paper',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: UIConstants.spacing12),
            if (_selectedGradeLevel != null)
              _buildPreviewRow(Icons.school_rounded, 'Grade', 'Grade $_selectedGradeLevel'),
            if (_selectedSections.isNotEmpty)
              _buildPreviewRow(Icons.class_rounded, 'Sections', _selectedSections.join(', '))
            else if (_availableSections.isEmpty)
              _buildPreviewRow(Icons.class_rounded, 'Sections', 'All sections'),
            _buildPreviewRow(Icons.quiz_rounded, 'Exam Type', _selectedExamType!.name),
            _buildPreviewRow(Icons.access_time_rounded, 'Duration', _selectedExamType!.formattedDuration),
            _buildPreviewRow(Icons.grade_rounded, 'Total Marks', '${_selectedExamType!.calculatedTotalMarks}'),
            if (_selectedSubjects.isNotEmpty)
              _buildPreviewRow(
                Icons.subject_rounded,
                'Subjects',
                _selectedSubjects.map((s) => s.name).join(', '),
              ),
            if (_currentPaper != null && _currentPaper!.questions.isNotEmpty) ...[
              SizedBox(height: UIConstants.spacing12),
              Text(
                'Current Questions: ${_currentPaper!.totalQuestions}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
            SizedBox(height: UIConstants.spacing12),
            Text('Sections:', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            SizedBox(height: UIConstants.spacing8),
            ..._selectedExamType!.sections.map((section) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${section.name} (${section.questions} questions × ${section.marksPerQuestion} marks)',
                      style: TextStyle(fontSize: UIConstants.fontSizeMedium, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
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

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _navigateBack,
            icon: const Icon(Icons.close_rounded),
            label: const Text('Cancel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UIConstants.radiusLarge)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _canSave && !_isSaving ? _saveChanges : null,
            icon: _isSaving
                ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
                : const Icon(Icons.save_rounded),
            label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UIConstants.radiusLarge)),
              disabledBackgroundColor: AppColors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(String title, String subtitle, Widget child) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: UIConstants.spacing4),
          Text(
            subtitle,
            style: TextStyle(fontSize: UIConstants.fontSizeMedium, color: AppColors.textSecondary),
          ),
          SizedBox(height: UIConstants.spacing16),
          child,
        ],
      ),
    );
  }

  void _editQuestions() {
    if (_currentPaper == null || _selectedExamType == null) return;

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
              Navigator.of(dialogContext).pop();
              UiHelpers.showErrorMessage(context, state.message);
            }
          },
          child: QuestionInputDialog(
            sections: _selectedExamType!.sections,
            examType: _selectedExamType!,
            selectedSubjects: _selectedSubjects,
            paperTitle: _titleController.text.trim(),
            gradeLevel: _selectedGradeLevel!,
            selectedSections: _selectedSections.isNotEmpty ? _selectedSections : ['All'],
            existingQuestions: _currentPaper?.questions,
            isEditing: true,
            existingPaperId: _currentPaper?.id,
            isAdmin: _userStateService.isAdmin,
            onPaperCreated: (_) {},
          ),
        ),
      ),
    );
  }

  void _saveChanges() {
    if (!_canSave || _isSaving || _currentPaper == null) return;

    setState(() => _isSaving = true);

    final updatedPaper = _currentPaper!.copyWith(
      title: _titleController.text.trim(),
      gradeLevel: _selectedGradeLevel,
      selectedSections: _selectedSections.isNotEmpty ? _selectedSections : ['All'],
      examType: _selectedExamType!.name,
      subject: _selectedSubjects.isNotEmpty ? _selectedSubjects.first.name : _currentPaper!.subject,
      examTypeEntity: _selectedExamType!,
      modifiedAt: DateTime.now(),
    );

    context.read<QuestionPaperBloc>().add(SaveDraft(updatedPaper));
  }

  void _showSuccess() {
    _showMessage('Question paper updated successfully!', AppColors.success);
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) context.go(AppRoutes.home);
    });
  }

  void _showMessage(String message, Color color) {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UIConstants.radiusMedium)),
      ),
    );
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