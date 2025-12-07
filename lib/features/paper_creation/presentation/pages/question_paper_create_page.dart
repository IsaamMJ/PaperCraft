import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
import '../../../catalog/domain/entities/grade_entity.dart';
import '../../../catalog/domain/entities/paper_section_entity.dart';
import '../../../catalog/domain/entities/subject_entity.dart';
import '../../../catalog/domain/entities/exam_type.dart';
import '../../../catalog/presentation/bloc/grade_bloc.dart';
import '../../../catalog/presentation/bloc/subject_bloc.dart';
import '../../../catalog/presentation/bloc/teacher_pattern_bloc.dart';
import '../../../catalog/presentation/widgets/pattern_selector_widget.dart';
import '../../../catalog/presentation/widgets/section_builder_widget.dart';
import '../../../paper_workflow/presentation/bloc/question_paper_bloc.dart';
import '../../../paper_workflow/domain/entities/question_paper_entity.dart';
import '../../domain/services/question_input_coordinator.dart';
import '../widgets/paper_details_card.dart' show PaperDetailsDisplay;

class QuestionPaperCreatePage extends StatefulWidget {
  final String? draftPaperId; // Optional: for editing existing draft papers

  const QuestionPaperCreatePage({
    super.key,
    this.draftPaperId,
  });

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

  // Subject management - teacher's assigned subjects for selected grade
  List<String> _availableSubjects = []; // List of subject names
  Map<String, String> _subjectNameToIdMap = {}; // Subject name -> Subject ID (UUID)
  String? _selectedSubject;
  String? _selectedSubjectId; // Actual UUID
  bool _isSubjectsLoading = false;

  // Exam type fields
  ExamType? _selectedExamType;
  final TextEditingController _examNumberController = TextEditingController();

  bool _showPatternSelector = false; // Manual toggle for pattern selector

  // Loaded paper from draft (auto-assigned)
  QuestionPaperEntity? _loadedPaper; // Paper loaded from draft (for auto-assigned papers)

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

    // If editing a draft paper, load it from BLoC
    if (widget.draftPaperId != null) {
      context.read<QuestionPaperBloc>().add(LoadPaperById(widget.draftPaperId!));
    } else {
      // Only load initial data for new papers (non-draft)
      _loadInitialData();
      // Set smart default for exam date (7 days from now)
      _selectedExamDate = DateTime.now().add(const Duration(days: 7));
    }

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

    if (isTeacher) {
      _loadTeacherAssignedGrades(currentUser!.id);
    } else {
      // Admins can see all grades
      context.read<GradeBloc>().add(const LoadGrades());
    }
  }

  /// Populate form state from a loaded draft paper (auto-assigned)
  void _populateFromLoadedPaper(QuestionPaperEntity paper) {
    debugPrint('[DEBUG] Populating form from loaded paper: ${paper.id}');
    setState(() {
      _loadedPaper = paper;
      // Use the paper's existing sections as the pattern
      _paperSections = paper.paperSections;
    });
    // Fetch target marks from exam calendar
    _fetchTargetMarksFromExamCalendar(paper);
  }

  /// Fetch target marks from exam_calendar based on paper's exam timetable entry
  Future<void> _fetchTargetMarksFromExamCalendar(QuestionPaperEntity paper) async {
    try {
      if (paper.examTimetableEntryId == null) return;

      final supabase = Supabase.instance.client;

      // Step 1: Get exam timetable entry to find timetable ID
      final entryData = await supabase
          .from('exam_timetable_entries')
          .select('timetable_id')
          .eq('id', paper.examTimetableEntryId!)
          .single();

      final timetableId = entryData['timetable_id'] as String;

      // Step 2: Get exam timetable to find exam_calendar_id
      final timetableData = await supabase
          .from('exam_timetables')
          .select('exam_calendar_id')
          .eq('id', timetableId)
          .single();

      final examCalendarId = timetableData['exam_calendar_id'] as String?;
      if (examCalendarId == null) return;

      // Target marks are now fetched directly from paper.maxMarks (added during auto-assignment)
      // No need to query exam_calendar separately
    } catch (e) {
      debugPrint('[DEBUG] Error loading draft paper: $e');
      // Silently fail - paper loading is optional
    }
  }

  Future<void> _loadTeacherAssignedGrades(String teacherId) async {

    try {
      final supabase = Supabase.instance.client;

      // Get unique grades where teacher has assignments
      final teacherAssignments = await supabase
          .from('teacher_subjects')
          .select('grade_id')
          .eq('teacher_id', teacherId)
          .select();

      final gradeIds = <String>{};
      for (var assignment in teacherAssignments as List) {
        final gradeId = assignment['grade_id'] as String?;
        if (gradeId != null) {
          gradeIds.add(gradeId);
        }
      }


      if (gradeIds.isEmpty) {
        setState(() => _availableGrades = []);
        return;
      }

      // Fetch grade details
      final gradesData = await supabase
          .from('grades')
          .select()
          .inFilter('id', gradeIds.toList());


      // Convert to GradeEntity objects
      final grades = <GradeEntity>[];
      for (var gradeData in gradesData as List) {
        try {
          final data = gradeData as Map<String, dynamic>;
          final grade = GradeEntity(
            id: data['id'] as String,
            gradeNumber: data['grade_number'] as int,
            tenantId: data['tenant_id'] as String,
            isActive: data['is_active'] as bool? ?? true,
            createdAt: DateTime.parse(data['created_at'] as String),
          );
          grades.add(grade);
        } catch (e) {
        }
      }


      setState(() => _availableGrades = grades);
    } catch (e, stackTrace) {
      setState(() => _availableGrades = []);
    }
  }


  String _generateAutoTitle() {
    if (_selectedSubject != null && _selectedExamDate != null && _selectedGradeLevel != null) {
      final dateStr = DateFormat('dd MMM yyyy').format(_selectedExamDate!);
      return 'Grade $_selectedGradeLevel $_selectedSubject - $dateStr';
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

  /// Check if pattern total marks matches paper's maxMarks
  bool _marksMatchTarget() {
    if (_loadedPaper?.maxMarks == null || _paperSections.isEmpty) return true;
    final patternTotal = _getTotalMarks().toInt();
    return patternTotal == _loadedPaper!.maxMarks;
  }

  /// Get validation message for marks mismatch
  String? _getMarksValidationMessage() {
    if (_loadedPaper?.maxMarks == null || _paperSections.isEmpty) return null;
    final patternTotal = _getTotalMarks().toInt();
    if (patternTotal != _loadedPaper!.maxMarks) {
      return 'Pattern total ($patternTotal marks) should be ${_loadedPaper!.maxMarks} marks';
    }
    return null;
  }

  bool _isStepValid(int step) {
    switch (step) {
      case 1:
        // If editing a draft paper (auto-assigned), pattern must be complete + marks must match paper's maxMarks
        if (_loadedPaper != null) {
          final hasPattern = _paperSections.isNotEmpty;
          // If paper has maxMarks, pattern must match exactly; otherwise any pattern is fine
          final marksValid = _loadedPaper?.maxMarks == null || _marksMatchTarget();
          return hasPattern && marksValid;
        }

        // For new papers, all metadata must be filled
        return _selectedGradeLevel != null &&
            _selectedSubject != null &&
            _selectedSubjectId != null &&
            _selectedExamType != null &&
            _paperSections.isNotEmpty &&
            _selectedExamDate != null &&
            !_isSectionsLoading &&
            !_isSubjectsLoading &&
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
      _selectedSubjectId = null;
      _availableSections.clear();
      _availableSubjects.clear();
      _subjectNameToIdMap.clear();
      _isSectionsLoading = true;
      _isSubjectsLoading = false; // Don't load subjects yet
    });

    // Load sections first - subjects will be loaded after sections are selected
    _loadSectionsForGrade(grade.id);
  }

  Future<void> _loadSectionsForGrade(String gradeId) async {
    try {
      final userStateService = sl<UserStateService>();
      final currentUser = userStateService.currentUser;


      if (currentUser == null) {
        setState(() {
          _availableSections = [];
          _isSectionsLoading = false;
        });
        return;
      }

      final supabase = Supabase.instance.client;

      // Load ONLY sections that this teacher is assigned to teach in this grade
      // Query teacher_subjects table and get unique section names for this grade

      final sectionsData = await supabase
          .from('teacher_subjects')
          .select('section')
          .eq('teacher_id', currentUser.id)
          .eq('grade_id', gradeId)
          .eq('is_active', true);


      // Extract unique section names (since there can be multiple subjects per section)
      final sections = <String>{};
      for (var record in sectionsData as List) {
        final section = record['section'] as String?;
        if (section != null) {
          sections.add(section);
        }
      }

      final sectionsList = sections.toList()..sort();

      setState(() {
        _availableSections = sectionsList;
        _isSectionsLoading = false;
      });
    } catch (e, stackTrace) {
      setState(() {
        _availableSections = [];
        _isSectionsLoading = false;
      });
    }
  }

  void _onSectionToggled(String section, bool selected) {

    setState(() {
      selected ? _selectedSections.add(section) : _selectedSections.remove(section);
    });

    // Load subjects for selected sections
    if (_selectedSections.isNotEmpty) {
      _loadSubjectsForSelectedSections();
    } else {
      // Clear subjects if no sections selected
      setState(() {
        _availableSubjects.clear();
        _subjectNameToIdMap.clear();
        _selectedSubject = null;
        _selectedSubjectId = null;
      });
    }
  }

  /// Load subjects only for the selected sections (not all sections in grade)
  Future<void> _loadSubjectsForSelectedSections() async {

    if (_selectedGradeLevel == null || _selectedSections.isEmpty) {
      return;
    }

    final userStateService = sl<UserStateService>();
    final currentUser = userStateService.currentUser;
    final tenantId = currentUser?.tenantId;


    if (tenantId == null || _selectedGrade == null) {
      return;
    }

    setState(() => _isSubjectsLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // Step 1: Get teacher's assigned subjects for this grade

      final teacherAssignments = await supabase
          .from('teacher_subjects')
          .select('subject_id')
          .eq('teacher_id', currentUser!.id)
          .eq('grade_id', _selectedGrade!.id);


      final assignedSubjectIds = <String>{};
      for (var assignment in teacherAssignments as List) {
        final subjectId = assignment['subject_id'] as String?;
        if (subjectId != null) {
          assignedSubjectIds.add(subjectId);
        }
      }


      if (assignedSubjectIds.isEmpty) {
        setState(() {
          _availableSubjects = [];
          _subjectNameToIdMap = {};
          _isSubjectsLoading = false;
        });
        return;
      }

      // Step 2: Get subjects offered in the SELECTED sections only
      // Build a filter for each selected section

      final selectedSubjectIds = <String>{};

      for (var sectionName in _selectedSections) {
        final gradeSubjectsData = await supabase
            .from('grade_section_subject')
            .select('subjects(id, catalog_subject_id)')
            .eq('tenant_id', tenantId)
            .eq('grade_id', _selectedGrade!.id)
            .eq('section', sectionName)
            .eq('is_offered', true);


        for (var record in gradeSubjectsData as List) {
          final subjectData = record['subjects'] as Map<String, dynamic>?;
          final subjectId = subjectData?['id'] as String?;

          // Only include subjects that the teacher is assigned to
          if (subjectId != null && assignedSubjectIds.contains(subjectId)) {
            selectedSubjectIds.add(subjectId);
          } else {
          }
        }
      }


      if (selectedSubjectIds.isEmpty) {
        setState(() {
          _availableSubjects = [];
          _subjectNameToIdMap = {};
          _isSubjectsLoading = false;
        });
        return;
      }

      // Step 3: Get catalog IDs for subjects in selected sections

      final subjectData = await supabase
          .from('subjects')
          .select('id, catalog_subject_id')
          .inFilter('id', selectedSubjectIds.toList());


      final catalogSubjectIds = <String>{};
      final subjectIdToCatalogId = <String, String>{};

      for (var record in subjectData as List) {
        final id = record['id'] as String;
        final catalogId = record['catalog_subject_id'] as String?;
        if (catalogId != null) {
          catalogSubjectIds.add(catalogId);
          subjectIdToCatalogId[catalogId] = id;
        }
      }


      // Step 4: Fetch subject names from catalog
      final catalogSubjectMap = <String, String>{};
      if (catalogSubjectIds.isNotEmpty) {
        final catalogData = await supabase
            .from('subject_catalog')
            .select('id, subject_name')
            .inFilter('id', catalogSubjectIds.toList());


        for (var catalog in catalogData as List) {
          final id = catalog['id'] as String;
          final name = catalog['subject_name'] as String;
          catalogSubjectMap[id] = name;
        }
      }


      // Step 5: Build display list with name-to-ID mapping
      final subjectNames = <String>[];
      final nameToIdMap = <String, String>{};

      for (var catalogId in catalogSubjectIds) {
        final subjectName = catalogSubjectMap[catalogId];
        final subjectId = subjectIdToCatalogId[catalogId];

        if (subjectName != null && subjectId != null) {
          subjectNames.add(subjectName);
          nameToIdMap[subjectName] = subjectId;
        }
      }


      setState(() {
        _availableSubjects = subjectNames;
        _subjectNameToIdMap = nameToIdMap;
        _selectedSubject = null;
        _selectedSubjectId = null;
        _isSubjectsLoading = false;
      });
    } catch (e, stackTrace) {
      setState(() {
        _availableSubjects = [];
        _subjectNameToIdMap = {};
        _isSubjectsLoading = false;
      });
    }
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
      // Set time to 10:00 AM for the selected date
      final examDateWith10AM = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        10, // 10 AM
        0,
        0,
      );
      setState(() => _selectedExamDate = examDateWith10AM);
    }
  }

  String _formatExamDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBackNavigation,
      child: MultiBlocListener(
        listeners: [
          // Listen for paper loading (for auto-assigned draft papers)
          BlocListener<QuestionPaperBloc, QuestionPaperState>(
            listener: (context, state) {
              if (state is QuestionPaperLoaded && state.currentPaper != null) {
                if (!mounted) return;
                _populateFromLoadedPaper(state.currentPaper!);
              }
              if (state is QuestionPaperError) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error loading paper: ${state.message}'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
          ),
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
    // If editing a draft paper (auto-assigned), show read-only details + pattern only
    if (_loadedPaper != null) {
      return _buildQuickSetupForDraftPaper();
    }

    // Otherwise, show the full form for creating new papers
    return _buildStepCard(
      'Paper Structure',
      'Build your question paper',
      SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Validation Summary (show if attempted to proceed with errors)
            if (!_isStepValid(1)) _buildValidationSummary(),

            // Paper Details Summary (Inline - Compact)
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
                    // Grade Selection
                    Text('Grade', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
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

                    // Sections (only show if grade selected)
                    if (_selectedGradeLevel != null) ...[
                      SizedBox(height: UIConstants.spacing16),
                      if (_isSectionsLoading)
                        const InfoBox(message: 'Loading sections...')
                      else if (_availableSections.isEmpty)
                        const InfoBox(message: 'Will apply to all sections')
                      else ...[
                        Text('Sections', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        _buildSectionSelector(),
                      ],
                    ],

                    // Subject Selection (only show if grade selected)
                    if (_selectedGradeLevel != null) ...[
                      SizedBox(height: UIConstants.spacing16),
                      if (_isSubjectsLoading)
                        const InfoBox(message: 'Loading subjects...')
                      else if (_availableSubjects.isEmpty)
                        const InfoBox(message: 'No subjects for this grade')
                      else ...[
                        Text('Subject', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _availableSubjects.map((subjectName) {
                            final isSelected = _selectedSubject == subjectName;
                            return FilterChip(
                              label: Text(subjectName),
                              selected: isSelected,
                              onSelected: (selected) {
                                final subjectId = _subjectNameToIdMap[subjectName];
                                setState(() {
                                  if (selected) {
                                    _selectedSubject = subjectName;
                                    _selectedSubjectId = subjectId;
                                    _showPatternSelector = false;
                                  } else {
                                    _selectedSubject = null;
                                    _selectedSubjectId = null;
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
                    ],

                    // Exam Type Selection (only show if subject selected)
                    if (_selectedSubject != null) ...[
                      SizedBox(height: UIConstants.spacing16),
                      Text('Exam Type', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
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
                  ],
                );
              },
            ),

            // Paper Details Summary Badge
            if (_selectedGrade != null || _selectedSubject != null || _selectedExamType != null) ...[
              SizedBox(height: UIConstants.spacing16),
              PaperDetailsDisplay(
                selectedGrade: _selectedGrade,
                selectedSections: _selectedSections,
                selectedSubject: _selectedSubject,
                selectedExamType: _selectedExamType,
              ),
            ],

            // Section Builder (Main Focus)
            if (_selectedGradeLevel != null && _selectedSubject != null) ...[
              SizedBox(height: UIConstants.spacing24),
              if (_paperSections.isEmpty) ...[
                Text(
                  'Question Sections',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: UIConstants.spacing12),
                Text(
                  'Define sections and question pattern',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: UIConstants.spacing12),
              ] else ...[
                // Paper Structure Summary Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary10,
                    borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                    border: Border.all(color: AppColors.primary20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.article_outlined, color: AppColors.primary, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '${_paperSections.length} Section${_paperSections.length != 1 ? 's' : ''} • ${_paperSections.fold<int>(0, (sum, s) => sum + s.totalMarks.toInt())} Marks',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: UIConstants.spacing12),
              ],
              SectionBuilderWidget(
                initialSections: _paperSections,
                onSectionsChanged: (sections) {
                  // Validate for duplicate section names
                  final sectionNames = sections.map((s) => s.name.toLowerCase()).toList();
                  final uniqueNames = sectionNames.toSet();

                  if (sectionNames.length != uniqueNames.length) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Duplicate section names not allowed.'),
                        backgroundColor: AppColors.error,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                    return;
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
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: UIConstants.spacing8),
              GestureDetector(
                onTap: _selectExamDate,
                child: Container(
                  padding: const EdgeInsets.all(12),
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
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedExamDate != null
                              ? _formatExamDate(_selectedExamDate!)
                              : 'Select exam date',
                          style: TextStyle(
                            fontSize: 14,
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
                              : AppColors.textSecondary, size: 20),
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

  Widget _buildQuickSetupForDraftPaper() {
    if (_loadedPaper == null) {
      return Container(); // Should not reach here
    }

    final paper = _loadedPaper!;

    return _buildStepCard(
      'Paper Structure',
      'Build your question paper',
      SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Read-only Paper Details (Compact)
            _buildReadOnlyDetailsCard(paper),

            SizedBox(height: UIConstants.spacing24),

            // Section Builder (Main Focus)
            if (_paperSections.isEmpty) ...[
              Text(
                'Question Sections',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: UIConstants.spacing12),
              Text(
                'Define sections and question pattern',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: UIConstants.spacing16),
            ] else ...[
              // Paper Structure Summary Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary10,
                  borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                  border: Border.all(color: AppColors.primary20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.article_outlined, color: AppColors.primary, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${_paperSections.length} Section${_paperSections.length != 1 ? 's' : ''} • ${_paperSections.fold<int>(0, (sum, s) => sum + s.totalMarks.toInt())} Marks',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: UIConstants.spacing12),
            ],

            SectionBuilderWidget(
              initialSections: _paperSections,
              onSectionsChanged: (sections) {
                // Validate for duplicate section names
                final sectionNames = sections.map((s) => s.name.toLowerCase()).toList();
                final uniqueNames = sectionNames.toSet();

                if (sectionNames.length != uniqueNames.length) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Duplicate section names not allowed.'),
                      backgroundColor: AppColors.error,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  return;
                }

                setState(() => _paperSections = sections);
              },
            ),
            // Show marks validation warning if maxMarks mismatch
            if (_loadedPaper?.maxMarks != null && _paperSections.isNotEmpty && !_marksMatchTarget()) ...[
              SizedBox(height: UIConstants.spacing16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_rounded, color: AppColors.warning, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _getMarksValidationMessage() ?? 'Marks mismatch',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.warning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyDetailsCard(QuestionPaperEntity paper) {
    return Card(
      elevation: 0,
      color: AppColors.primary05,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  'Paper Details (Locked)',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            SizedBox(height: UIConstants.spacing16),
            _buildReadOnlyField('Grade', paper.grade ?? 'N/A'),
            _buildReadOnlyField('Subject', paper.subject ?? 'N/A'),
            _buildReadOnlyField('Exam Type', paper.examType.displayName),
            _buildReadOnlyField('Exam Date', paper.examDate != null ? _formatExamDate(paper.examDate!) : 'N/A'),
            _buildReadOnlyField('Class Sections', paper.section ?? 'All Sections'),
            if (paper.examNumber != null) _buildReadOnlyField('Exam Number', paper.examNumber.toString()),
            if (paper.maxMarks != null) _buildReadOnlyField('Total Marks', paper.maxMarks.toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
    // For draft papers (auto-assigned)
    if (_loadedPaper != null) {
      return _buildQuestionsStepForDraftPaper();
    }

    // For new papers
    if (_selectedSubject == null || _selectedExamDate == null || _selectedGrade == null || _paperSections.isEmpty) {
      return Container();
    }

    final autoTitle = _generateAutoTitle();
    final userStateService = sl<UserStateService>();
    final academicYear = _getAcademicYear(_selectedExamDate!);

    // Create SubjectEntity from selected subject name and ID
    final tenantId = userStateService.currentUser?.tenantId;
    if (tenantId == null) {
      return Container(); // Safety check
    }

    final selectedSubjectEntity = SubjectEntity(
      id: _selectedSubjectId!,
      name: _selectedSubject!,
      tenantId: tenantId,
      catalogSubjectId: _selectedSubjectId!,
      isActive: true,
      minGrade: _selectedGradeLevel,
      maxGrade: _selectedGradeLevel,
      createdAt: DateTime.now(),
    );

    return BlocProvider(
      create: (context) => sl<TeacherPatternBloc>(),
      child: QuestionInputCoordinator(
        paperSections: _paperSections,
        selectedSubjects: [selectedSubjectEntity],
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

  Widget _buildQuestionsStepForDraftPaper() {
    final paper = _loadedPaper!;

    if (_paperSections.isEmpty) {
      return Container();
    }

    final userStateService = sl<UserStateService>();
    final tenantId = userStateService.currentUser?.tenantId;
    if (tenantId == null) {
      return Container(); // Safety check
    }

    final selectedSubjectEntity = SubjectEntity(
      id: paper.subjectId,
      name: paper.subject ?? 'Unknown Subject',
      tenantId: tenantId,
      catalogSubjectId: paper.subjectId,
      isActive: true,
      minGrade: paper.gradeLevel,
      maxGrade: paper.gradeLevel,
      createdAt: DateTime.now(),
    );

    return BlocProvider(
      create: (context) => sl<TeacherPatternBloc>(),
      child: QuestionInputCoordinator(
        paperSections: _paperSections,
        selectedSubjects: [selectedSubjectEntity],
        paperTitle: paper.title,
        gradeLevel: paper.gradeLevel ?? 0,
        gradeId: paper.gradeId,
        academicYear: _getAcademicYear(paper.examDate ?? DateTime.now()),
        selectedSections: paper.selectedSections?.isNotEmpty == true ? paper.selectedSections! : ['All'],
        examType: paper.examType,
        examNumber: paper.examNumber,
        examDate: paper.examDate,
        isAdmin: userStateService.isAdmin,
        onPaperCreated: (paper) {
          _showSuccess();
        },
        // Edit mode parameters for updating existing draft
        isEditing: true,
        existingPaperId: paper.id,
        existingQuestions: paper.questions,
        existingTenantId: tenantId,
        existingUserId: userStateService.currentUser?.id,
        examTimetableEntryId: paper.examTimetableEntryId, // Preserve exam timetable link
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

  /// Handle system back gesture (swipe back)
  /// Ensures we don't exit the app, but navigate properly instead
  Future<bool> _handleBackNavigation() async {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
    return false; // Return false to prevent default behavior
  }

  void _navigateBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }
}