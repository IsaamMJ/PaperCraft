import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/qps_repository_impl.dart';
import '../../domain/entities/exam_type_entity.dart';
import '../../domain/entities/subject_entity.dart';
import '../../domain/entities/grade_entity.dart';
import '../../domain/usecases/get_exam_types.dart';
import '../../domain/usecases/get_subjects.dart';
import '../../domain/usecases/get_grades.dart';
import '../../domain/usecases/get_user_permissions.dart';
import '../../domain/usecases/get_filtered_subjects.dart';
import '../../domain/usecases/get_filtered_grades.dart';
import '../../domain/usecases/can_create_paper.dart';
import '../bloc/qps_bloc.dart';
import '../bloc/qps_event.dart';
import '../bloc/qps_state.dart';
import '../widgets/question_input_widget.dart';

class QpsPage extends StatefulWidget {
  const QpsPage({super.key});

  @override
  State<QpsPage> createState() => _QpsPageState();
}

class _QpsPageState extends State<QpsPage> with TickerProviderStateMixin {
  String? selectedExamTypeId;
  ExamTypeEntity? selectedExamType;
  String? selectedSubjectId;
  String? selectedGradeId;
  GradeEntity? selectedGrade;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // Helper method to format grade display name
  String _formatGradeName(GradeEntity grade) {
    // Clean up the display name by removing redundant parts
    String name = grade.displayName;

    // Remove duplicate words and extra hyphens
    List<String> parts = name.split('-').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    Set<String> uniqueParts = <String>{};

    for (String part in parts) {
      // Convert to lowercase for comparison but keep original case
      String lowerPart = part.toLowerCase();
      if (!uniqueParts.any((existing) => existing.toLowerCase() == lowerPart)) {
        uniqueParts.add(part);
      }
    }

    return uniqueParts.join(' - ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocProvider(
      create: (_) {
        final repository = QpsRepositoryImpl(supabase: Supabase.instance.client);
        return QpsBloc(
          getExamTypes: GetExamTypes(repository),
          getSubjects: GetSubjects(repository),
          getGrades: GetGrades(repository),
          getUserPermissions: GetUserPermissions(repository),
          getFilteredSubjects: GetFilteredSubjects(repository),
          getFilteredGrades: GetFilteredGrades(repository),
          canCreatePaper: CanCreatePaper(repository),
        )..add(LoadQpsData());
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          title: const Text(
            'Question Paper Setup',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          automaticallyImplyLeading: false,
          elevation: 0,
        ),
        body: BlocConsumer<QpsBloc, QpsState>(
          listener: (context, state) {
            if (state is QpsPermissionValidated) {
              if (!state.canCreate) {
                _showErrorSnackBar(context, state.message);
              }
              // Don't show success message here - just validate silently
            }
          },
          builder: (context, state) {
            if (state is QpsLoading) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 3,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading exam data...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            } else if (state is QpsLoaded) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Card with permissions info
                    _buildHeaderCard(context, state),

                    const SizedBox(height: 24),

                    // Step 1: Grade Selection
                    _buildGradeSelectionCard(context, state),

                    const SizedBox(height: 16),

                    // Step 2: Exam Type Selection
                    _buildExamTypeSelectionCard(context, state),

                    // Exam Sections (animated)
                    if (selectedExamType != null && selectedExamType!.sections.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildExamSectionsCard(context, state),
                    ],

                    const SizedBox(height: 16),

                    // Step 3: Subject Selection
                    _buildSubjectSelectionCard(context, state),

                    const SizedBox(height: 32),

                    // Submit Button
                    _buildSubmitButton(context, state),

                    const SizedBox(height: 16),

                    // Helper text
                    _buildHelperText(context, state),
                  ],
                ),
              );
            } else if (state is QpsError) {
              return _buildErrorState(context, state);
            }
            return const SizedBox();
          },
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, QpsLoaded state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.quiz_outlined,
              size: 48,
              color: colorScheme.onPrimaryContainer,
            ),
            const SizedBox(height: 12),
            Text(
              'Create Question Paper',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.isAdmin
                  ? 'Admin access - Create papers for any subject and grade'
                  : 'Select grade, exam type, and subject to generate questions',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimaryContainer.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
            if (!state.isAdmin && state.userPermissions != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Limited Access - ${state.filteredSubjects.length} subjects, ${state.filteredGrades.length} grades',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGradeSelectionCard(BuildContext context, QpsLoaded state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.grade_outlined,
                    color: colorScheme.onSecondaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Step 1: Select Grade',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            if (selectedGradeId != null) ...[
              const SizedBox(height: 8),
              Text(
                'Grade selected: ${_formatGradeName(selectedGrade!)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedGradeId,
              items: state.filteredGrades
                  .map((grade) => DropdownMenuItem(
                value: grade.id,
                child: Text(
                  _formatGradeName(grade), // Use the formatted name
                  style: theme.textTheme.bodyMedium,
                ),
              ))
                  .toList(),
              onChanged: state.filteredGrades.isEmpty
                  ? null
                  : (value) {
                setState(() {
                  selectedGradeId = value;
                  selectedGrade = state.filteredGrades.firstWhere((g) => g.id == value);
                  // Clear dependent selections
                  selectedExamTypeId = null;
                  selectedExamType = null;
                  selectedSubjectId = null;
                });
                _fadeController.reset();
                _fadeController.forward();
              },
              decoration: InputDecoration(
                labelText: state.filteredGrades.isEmpty
                    ? "No grades available"
                    : "Choose grade level",
                prefixIcon: const Icon(Icons.school_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
                filled: true,
                fillColor: colorScheme.surface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamTypeSelectionCard(BuildContext context, QpsLoaded state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.assignment_outlined,
                    color: colorScheme.onSecondaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Step 2: Select Exam Type',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedExamTypeId,
              items: state.examTypes
                  .map((e) => DropdownMenuItem(
                value: e.id,
                child: Text(e.name, style: theme.textTheme.bodyMedium),
              ))
                  .toList(),
              onChanged: selectedGradeId == null
                  ? null
                  : (value) {
                setState(() {
                  selectedExamTypeId = value;
                  selectedExamType = state.examTypes.firstWhere((exam) => exam.id == value);
                  selectedSubjectId = null; // Clear subject when exam type changes
                });
                _fadeController.reset();
                _fadeController.forward();
              },
              decoration: InputDecoration(
                labelText: selectedGradeId == null ? "Select grade first" : "Choose exam type",
                prefixIcon: const Icon(Icons.quiz_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
                filled: true,
                fillColor: colorScheme.surface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamSectionsCard(BuildContext context, QpsLoaded state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Card(
        elevation: 0,
        color: colorScheme.tertiaryContainer.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.view_list_outlined,
                    color: colorScheme.onTertiaryContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Exam Sections',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onTertiaryContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...selectedExamType!.sections.map((section) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(Icons.quiz, size: 16, color: colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${section.questions} ${section.formattedType} • ${section.totalMarks} marks',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectSelectionCard(BuildContext context, QpsLoaded state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.subject_outlined,
                    color: colorScheme.onSecondaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Step 3: Select Subject',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            if (selectedSubjectId != null) ...[
              const SizedBox(height: 8),
              Text(
                'Subject selected',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedSubjectId,
              items: state.filteredSubjects
                  .map((subject) => DropdownMenuItem(
                value: subject.id,
                child: Text(subject.name, style: theme.textTheme.bodyMedium),
              ))
                  .toList(),
              onChanged: selectedExamTypeId == null || state.filteredSubjects.isEmpty
                  ? null
                  : (value) {
                setState(() {
                  selectedSubjectId = value;
                });
                // Don't validate permissions automatically - let user click the button
              },
              decoration: InputDecoration(
                labelText: selectedExamTypeId == null
                    ? "Select exam type first"
                    : state.filteredSubjects.isEmpty
                    ? "No subjects available"
                    : "Choose subject",
                prefixIcon: const Icon(Icons.book_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
                filled: true,
                fillColor: colorScheme.surface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context, QpsLoaded state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final canSubmit = selectedExamTypeId != null && selectedSubjectId != null && selectedGradeId != null;

    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: canSubmit ? () => _handleCreateQuestions(context, state) : null,
        icon: const Icon(Icons.create_outlined),
        label: Text(
          "Create Questions",
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: colorScheme.outline.withOpacity(0.2),
          disabledForegroundColor: colorScheme.onSurfaceVariant,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: canSubmit ? 2 : 0,
        ),
      ),
    );
  }

  Widget _buildHelperText(BuildContext context, QpsLoaded state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (selectedGradeId != null && selectedExamTypeId != null && selectedSubjectId != null) {
      return const SizedBox.shrink();
    }

    String helperText;
    if (selectedGradeId == null) {
      helperText = 'Please select a grade level first';
    } else if (selectedExamTypeId == null) {
      helperText = 'Please select an exam type';
    } else {
      helperText = state.filteredSubjects.isEmpty
          ? 'No subjects available for your permissions'
          : 'Please select a subject';
    }

    return Center(
      child: Text(
        helperText,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, QpsError state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: colorScheme.error),
          const SizedBox(height: 16),
          Text(
            "Oops! Something went wrong",
            style: theme.textTheme.headlineSmall?.copyWith(color: colorScheme.error),
          ),
          const SizedBox(height: 8),
          Text(
            state.error,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.read<QpsBloc>().add(LoadQpsData()),
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _handleCreateQuestions(BuildContext context, QpsLoaded state) {
    print('_handleCreateQuestions called'); // Debug print

    if (selectedExamType == null || selectedSubjectId == null || selectedGrade == null) {
      print('Missing selections: ExamType: $selectedExamType, Subject: $selectedSubjectId, Grade: $selectedGrade');
      _showErrorSnackBar(context, 'Please select grade, exam type and subject first');
      return;
    }

    final selectedSubject = state.filteredSubjects.firstWhere(
          (subject) => subject.id == selectedSubjectId,
    );

    print('Opening dialog with:');
    print('ExamType: ${selectedExamType!.name}');
    print('Subject: ${selectedSubject.name}');
    print('Grade: ${selectedGrade!.displayName}');
    print('Sections: ${selectedExamType!.sections.length}');

    // Simply open the dialog without permission validation
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => QuestionInputDialog(
        sections: selectedExamType!.sections,
        examType: selectedExamType!,
        selectedSubjects: [selectedSubject],
        selectedGrade: selectedGrade!,
        onQuestionsSubmitted: (questions) {
          print('Questions submitted: $questions');
          Navigator.of(context).pop(); // Close the dialog
          _showSuccessSnackBar(context, 'Questions saved! Ready for preview.');
        },
      ),
    );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}