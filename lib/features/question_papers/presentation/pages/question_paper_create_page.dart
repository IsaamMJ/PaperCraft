import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/routes/app_routes.dart';
import '../../domain/entities/exam_type_entity.dart';
import '../../domain/entities/subject_entity.dart';
import '../../domain/entities/grade_entity.dart';
import '../../domain/services/subject_grade_service.dart';
import '../bloc/question_paper_bloc.dart';
import '../bloc/grade_bloc.dart';
import '../widgets/question_input_dialog.dart';

class QuestionPaperCreatePage extends StatefulWidget {
  const QuestionPaperCreatePage({super.key});

  @override
  State<QuestionPaperCreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<QuestionPaperCreatePage> with TickerProviderStateMixin {
  List<int> _availableGradeLevels = [];
  final _titleController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // Grade and Section Selection
  int? _selectedGradeLevel;
  List<String> _availableSections = [];
  List<String> _selectedSections = [];

  // Existing selections
  ExamTypeEntity? _selectedExamType;
  List<SubjectEntity> _selectedSubjects = [];
  List<SubjectEntity> _filteredSubjects = [];
  bool _isCreating = false;

  // Mock data - replace with actual data from BLoC
  final _examTypes = [
    ExamTypeEntity(
      id: '1', tenantId: 'tenant1', name: 'Midterm Exam',
      durationMinutes: 90, totalMarks: 100,
      sections: [
        ExamSectionEntity(name: 'Multiple Choice', type: 'multiple_choice', questions: 10, marksPerQuestion: 2),
        ExamSectionEntity(name: 'Short Answer', type: 'short_answer', questions: 5, marksPerQuestion: 6),
      ],
    ),
    ExamTypeEntity(
      id: '2', tenantId: 'tenant1', name: 'Final Exam',
      durationMinutes: 120, totalMarks: 150,
      sections: [
        ExamSectionEntity(name: 'Multiple Choice', type: 'multiple_choice', questions: 15, marksPerQuestion: 3),
        ExamSectionEntity(name: 'Essay Questions', type: 'short_answer', questions: 3, marksPerQuestion: 35),
      ],
    ),
  ];

  final _subjects = [
    SubjectEntity(id: '1', tenantId: 'tenant1', name: 'Mathematics', isActive: true, createdAt: DateTime.now()),
    SubjectEntity(id: '2', tenantId: 'tenant1', name: 'Physics', isActive: true, createdAt: DateTime.now()),
    SubjectEntity(id: '3', tenantId: 'tenant1', name: 'Chemistry', isActive: true, createdAt: DateTime.now()),
    SubjectEntity(id: '4', tenantId: 'tenant1', name: 'Biology', isActive: true, createdAt: DateTime.now()),
    SubjectEntity(id: '5', tenantId: 'tenant1', name: 'English', isActive: true, createdAt: DateTime.now()),
    SubjectEntity(id: '6', tenantId: 'tenant1', name: 'Computer Science', isActive: true, createdAt: DateTime.now()),
    SubjectEntity(id: '7', tenantId: 'tenant1', name: 'Economics', isActive: true, createdAt: DateTime.now()),
    SubjectEntity(id: '8', tenantId: 'tenant1', name: 'Psychology', isActive: true, createdAt: DateTime.now()),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));

    // Initialize with all subjects
    _filteredSubjects = _subjects;

    // Load grade levels when page loads
    context.read<GradeBloc>().add(const LoadGradeLevels());

    Future.delayed(const Duration(milliseconds: 200), () => mounted ? _animController.forward() : null);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _animController.dispose();
    super.dispose();
  }

  bool get _canProceed {
    // Check if title has valid content (without triggering form validation)
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

      // Filter subjects based on grade level
      _filteredSubjects = SubjectGradeService.filterSubjectsByGrade(_subjects, gradeLevel);
    });

    // Load sections for this grade level
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
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildTitleSection(),
                    const SizedBox(height: 20),
                    _buildGradeSection(),
                    if (_selectedGradeLevel != null) ...[
                      const SizedBox(height: 20),
                      _buildSectionSelection(),
                    ],
                    if (_selectedGradeLevel != null && (_selectedSections.isNotEmpty || _availableSections.isEmpty)) ...[
                      const SizedBox(height: 20),
                      _buildExamTypeSection(),
                    ],
                    if (_selectedExamType != null) ...[
                      const SizedBox(height: 20),
                      _buildSubjectSection(),
                    ],
                    if (_selectedExamType != null && _selectedSubjects.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildPreview(),
                    ],
                    const SizedBox(height: 32),
                    _buildActions(),
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
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'New Question Paper',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'Set up the basic information for your question paper',
          style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildTitleSection() {
    return _buildCard(
      'Paper Title',
      'Give your paper a clear, descriptive title',
      Form(
        key: _formKey,
        child: TextFormField(
          controller: _titleController,
          decoration: InputDecoration(
            hintText: 'e.g., Mathematics Midterm Exam 2024',
            filled: true,
            fillColor: AppColors.backgroundSecondary,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            prefixIcon: Icon(Icons.title_rounded, color: AppColors.textSecondary),
          ),
          validator: (value) {
            if (value?.trim().isEmpty ?? true) return 'Please enter a paper title';
            if (value!.trim().length < 3) return 'Title must be at least 3 characters';
            return null;
          },
          onChanged: (_) => setState(() {}),
        ),
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
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: AppColors.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(state.message, style: TextStyle(color: AppColors.error))),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                        prefixIcon: Icon(Icons.school_rounded, color: AppColors.textSecondary),
                      ),
                      items: (state is GradeLevelsLoaded ? state.gradeLevels : _availableGradeLevels).map((level) {
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
                      validator: (value) => value == null ? 'Please select a grade level' : null,
                    ),
                    if (_selectedGradeLevel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Selected: Grade $_selectedGradeLevel',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
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
                    borderRadius: BorderRadius.circular(8),
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
                      style: TextStyle(color: AppColors.error, fontSize: 14),
                    ),
                  ),

                // Quick selection buttons
                if (_availableSections.length > 1) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedSections = List.from(_availableSections);
                          });
                        },
                        icon: const Icon(Icons.select_all, size: 16),
                        label: const Text('Select All'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedSections.clear();
                          });
                        },
                        icon: const Icon(Icons.clear_all, size: 16),
                        label: const Text('Clear All'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildExamTypeSection() {
    return _buildCard(
      'Exam Type',
      'Choose the type of exam you want to create',
      Column(
        children: _examTypes.map((type) {
          final isSelected = _selectedExamType?.id == type.id;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _selectedExamType = type),
                borderRadius: BorderRadius.circular(12),
                child: Container(
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
                      Container(
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
                            Text(
                              type.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${type.formattedDuration} • ${type.calculatedTotalMarks} marks • ${type.sections.length} sections',
                              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
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
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_outlined, color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No subjects available for Grade $_selectedGradeLevel',
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
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
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
                  style: TextStyle(color: AppColors.error, fontSize: 14),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return _buildCard(
      'Preview',
      'Here\'s how your paper will look',
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
            Text(
              _titleController.text.isNotEmpty ? _titleController.text : 'Untitled Paper',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
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
              _buildPreviewRow(Icons.subject_rounded, 'Subjects', _selectedSubjects.map((s) => s.name).join(', ')),
            const SizedBox(height: 12),
            Text('Sections:', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            ..._selectedExamType!.sections.map((section) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 4, height: 4,
                    decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${section.name} (${section.questions} questions × ${section.marksPerQuestion} marks)',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
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
          Text('$label: ', style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _canProceed && !_isCreating ? _proceedToQuestions : null,
            icon: _isCreating
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                : const Icon(Icons.arrow_forward_rounded),
            label: Text(_isCreating ? 'Creating...' : 'Create Questions'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  void _proceedToQuestions() {
    if (!_canProceed || _isCreating) return;

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
            paperTitle: _titleController.text.trim(),
            gradeLevel: _selectedGradeLevel!,
            selectedSections: _selectedSections.isNotEmpty ? _selectedSections : ['All'],
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