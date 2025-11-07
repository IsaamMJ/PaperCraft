import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../../core/presentation/routes/app_routes.dart';
import '../../../../core/presentation/utils/ui_helpers.dart';
import '../../../../core/presentation/widgets/common_state_widgets.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../../catalog/domain/entities/grade_entity.dart';
import '../../../catalog/domain/entities/subject_entity.dart';
import '../../../catalog/presentation/bloc/grade_bloc.dart';
import '../../../catalog/presentation/bloc/subject_bloc.dart';
import '../../../catalog/presentation/bloc/teacher_pattern_bloc.dart';
import '../../../paper_workflow/domain/entities/question_paper_entity.dart';
import '../../../paper_workflow/presentation/bloc/question_paper_bloc.dart';
import '../../../paper_workflow/presentation/bloc/shared_bloc_provider.dart';
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
  List<GradeEntity> _availableGrades = [];
  GradeEntity? _selectedGrade;
  int? _selectedGradeLevel;
  List<String> _selectedSections = [];

  // Subject - Loaded from BLoC
  SubjectEntity? _selectedSubject; // FIXED: Single subject, not list

  // Store data loaded from BLoCs (already filtered by grade from the database)
  List<SubjectEntity> _availableSubjects = [];

  // Paper being edited
  QuestionPaperEntity? _currentPaper;
  bool _isLoaded = false;

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
    // Exam types removed - using dynamic sections
    context.read<SubjectBloc>().add(const LoadSubjects());
    context.read<GradeBloc>().add(const LoadGrades());

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
    if (!mounted) return; // Safety check

    setState(() {
      _currentPaper = paper;
      _titleController.text = paper.title;
      _selectedGradeLevel = paper.gradeLevel;
      // FIXED: Handle nullable List<String>?
      _selectedSections = paper.selectedSections != null
          ? List<String>.from(paper.selectedSections!)
          : [];

      // Find matching grade entity
      if (_availableGrades.isNotEmpty && paper.gradeLevel != null) {
        try {
          _selectedGrade = _availableGrades.firstWhere(
                (grade) => grade.gradeNumber == paper.gradeLevel,
          );
        } catch (e) {
          // If exact match not found, use first available grade
          _selectedGrade = _availableGrades.first;
        }
      }

      // NOTE: Subjects are already filtered by grade at the database level
      // No need for client-side filtering with hardcoded values

      // Find matching subject (SINGLE subject, not list)
      if (_availableSubjects.isNotEmpty && paper.subjectId.isNotEmpty) {
        try {
          _selectedSubject = _availableSubjects.firstWhere(
                (subject) => subject.id == paper.subjectId,
          );
        } catch (e) {
          // If exact match not found, try to find by name
          try {
            _selectedSubject = _availableSubjects.firstWhere(
                  (subject) => subject.name == paper.subject,
            );
          } catch (e2) {
            // If still not found, use first available subject
            _selectedSubject = _availableSubjects.isNotEmpty
                ? _availableSubjects.first
                : null;
          }
        }
      }

      _isLoaded = true;
    });

    // Load sections for the selected grade
    if (_selectedGradeLevel != null) {
      context.read<GradeBloc>().add(LoadSectionsByGrade(_selectedGradeLevel!));
    }
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

                // Exam types removed - using dynamic sections
              }

              if (state is QuestionPaperSuccess) {
                UiHelpers.showSuccessMessage(context, state.message);
                Future.delayed(const Duration(seconds: 1), () {
                  if (mounted) context.go(AppRoutes.home);
                });
              }

              if (state is QuestionPaperError) {
                UiHelpers.showErrorMessage(context, state.message);
              }
            },
          ),
          BlocListener<SubjectBloc, SubjectState>(
            listener: (context, state) {
              if (state is SubjectsLoaded) {
                setState(() {
                  _availableSubjects = state.subjects;
                  // NOTE: Subjects are already filtered by grade at the database level

                  // Re-populate selected subject if paper is loaded
                  if (_currentPaper != null && _selectedSubject == null) {
                    try {
                      _selectedSubject = _availableSubjects.firstWhere(
                        (subject) => subject.id == _currentPaper!.subjectId,
                      );
                    } catch (e) {
                      // If exact match not found, try to find by name
                      try {
                        _selectedSubject = _availableSubjects.firstWhere(
                          (subject) => subject.name == _currentPaper!.subject,
                        );
                      } catch (e2) {
                        // If still not found, use first available subject
                        if (_availableSubjects.isNotEmpty) {
                          _selectedSubject = _availableSubjects.first;
                        }
                      }
                    }
                  }
                });
              }
            },
          ),
          BlocListener<GradeBloc, GradeState>(
            listener: (context, state) {
              if (state is GradesLoaded) {
                setState(() {
                  _availableGrades = state.grades;
                  // Re-populate if paper is already loaded
                  if (_currentPaper != null && _selectedGrade == null) {
                    _selectedGrade = _availableGrades.firstWhere(
                          (grade) => grade.gradeNumber == _currentPaper!.gradeLevel,
                      orElse: () => _availableGrades.first,
                    );
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
                          _buildPaperDetailsCard(),
                          if (_currentPaper != null) ...[
                            SizedBox(height: UIConstants.spacing20),
                            _buildCurrentQuestionsSection(),
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
      body: const LoadingWidget(message: 'Loading paper details...'),
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
      body: ErrorStateWidget(
        message: error,
        onRetry: () => context.read<QuestionPaperBloc>().add(LoadPaperById(widget.questionPaperId)),
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
          'Edit Questions',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: UIConstants.spacing8),
        Text(
          'Add, edit, or remove questions from this paper',
          style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
        ),
        SizedBox(height: UIConstants.spacing12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warning10,
            borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
          ),
          child: Row(
            children: [
              Icon(Icons.lock_outline, color: AppColors.warning, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Paper details (title, grade, subject, exam type) cannot be changed after creation',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaperDetailsCard() {
    return _buildCard(
      'Paper Details',
      'These details are locked and cannot be changed',
      Container(
        padding: const EdgeInsets.all(UIConstants.paddingMedium),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLockedRow(Icons.title_rounded, 'Title', _titleController.text.isNotEmpty ? _titleController.text : 'Loading...'),
            Divider(height: 24, color: AppColors.border),
            _buildLockedRow(Icons.school_rounded, 'Grade', _selectedGradeLevel != null ? 'Grade $_selectedGradeLevel' : 'Loading...'),
            Divider(height: 24, color: AppColors.border),
            _buildLockedRow(Icons.class_rounded, 'Sections', _selectedSections.isNotEmpty ? _selectedSections.join(', ') : 'All sections'),
            Divider(height: 24, color: AppColors.border),
            _buildLockedRow(Icons.quiz_rounded, 'Paper Sections', '${_currentPaper?.paperSections.length ?? 0} sections'),
            if (_currentPaper != null && _currentPaper!.paperSections.isNotEmpty) ...[
              SizedBox(height: UIConstants.spacing4),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: Text(
                  '${_currentPaper!.totalMarks} marks • ${_currentPaper!.totalQuestions} questions',
                  style: TextStyle(
                    fontSize: UIConstants.fontSizeSmall,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
            Divider(height: 24, color: AppColors.border),
            _buildLockedRow(Icons.subject_rounded, 'Subject', _selectedSubject?.name ?? 'Loading...'),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.lock, size: 16, color: AppColors.textTertiary),
      ],
    );
  }

  Widget _buildCurrentQuestionsSection() {
    if (_currentPaper == null) {
      return const SizedBox.shrink();
    }

    final hasQuestions = _currentPaper!.questions.isNotEmpty;

    return _buildCard(
      'Questions',
      hasQuestions ? 'Manage questions for this paper' : 'No questions added yet',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasQuestions) ...[
            ..._currentPaper!.questions.entries.map((entry) {
              final sectionName = entry.key;
              final questions = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary05,
                  borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                  border: Border.all(color: AppColors.primary10),
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
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning10,
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This paper has no questions yet. Click below to add questions.',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: UIConstants.spacing16),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _editQuestions,
              icon: Icon(hasQuestions ? Icons.edit_rounded : Icons.add_rounded),
              label: Text(hasQuestions ? 'Edit Questions' : 'Add Questions'),
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


  Widget _buildActions() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _navigateBack,
        icon: const Icon(Icons.arrow_back_rounded),
        label: const Text('Back to Papers'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UIConstants.radiusLarge)),
        ),
      ),
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
    // Comprehensive validation to prevent crashes
    if (_currentPaper == null) {
      UiHelpers.showErrorMessage(context, 'Paper data not loaded. Please try again.');
      return;
    }

    if (_selectedSubject == null) {
      UiHelpers.showErrorMessage(context, 'Please select a subject first.');
      return;
    }

    if (_selectedGrade == null || _selectedGradeLevel == null) {
      UiHelpers.showErrorMessage(context, 'Please select a grade first.');
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      UiHelpers.showErrorMessage(context, 'Please enter a paper title first.');
      return;
    }

    // Check if paper has required data
    if (_currentPaper!.paperSections.isEmpty) {
      UiHelpers.showErrorMessage(context, 'Paper must have at least one section.');
      return;
    }

    // All validations passed - safe to open dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<QuestionPaperBloc>()),
          BlocProvider.value(value: context.read<TeacherPatternBloc>()),
        ],
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
            paperSections: _currentPaper!.paperSections,
            selectedSubjects: [_selectedSubject!],
            paperTitle: title,
            gradeLevel: _selectedGradeLevel!,
            gradeId: _selectedGrade!.id,
            academicYear: _currentPaper!.academicYear,
            selectedSections: _selectedSections.isNotEmpty ? _selectedSections : ['All'],
            examType: _currentPaper!.examType,
            examNumber: _currentPaper?.examNumber,
            existingQuestions: _currentPaper?.questions,
            isEditing: true,
            existingPaperId: _currentPaper?.id,
            existingTenantId: _currentPaper?.tenantId,
            existingUserId: _currentPaper?.createdBy,
            examDate: _currentPaper?.examDate,
            isAdmin: _userStateService.isAdmin,
            onPaperCreated: (_) {},
          ),
        ),
      ),
    );
  }


  void _showSuccess() {
    _showMessage('Question paper updated successfully!', AppColors.success);
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) context.go(AppRoutes.home);
    });
  }

  void _showMessage(String message, Color color) {
    if (!mounted) return; // Prevent errors if widget is disposed

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
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }
}