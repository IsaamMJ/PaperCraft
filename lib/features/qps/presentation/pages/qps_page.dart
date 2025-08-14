import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/qps_repository_impl.dart';
import '../../domain/entities/exam_type_entity.dart';
import '../../domain/entities/subject_entity.dart';
import '../../domain/usecases/get_exam_types.dart';
import '../../domain/usecases/get_subjects.dart';
import '../bloc/qps_bloc.dart';
import '../widgets/question_input_widget.dart';

class QpsPage extends StatefulWidget {
  const QpsPage({super.key});

  @override
  State<QpsPage> createState() => _QpsPageState();
}

class _QpsPageState extends State<QpsPage> with TickerProviderStateMixin {
  String? selectedExamTypeId;
  ExamTypeEntity? selectedExamType;
  String? selectedSubjectId; // Changed from Set to single String
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocProvider(
      create: (_) => QpsBloc(
        getExamTypes: GetExamTypes(QpsRepositoryImpl(supabase: Supabase.instance.client)),
        getSubjects: GetSubjects(QpsRepositoryImpl(supabase: Supabase.instance.client)),
      )..add(LoadQpsData()),
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
        body: BlocBuilder<QpsBloc, QpsState>(
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
                    // Header Card
                    Card(
                      elevation: 0,
                      color: colorScheme.primaryContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
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
                              'Select exam type and subject to generate questions',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Exam Type Selection
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: colorScheme.outline.withOpacity(0.2),
                        ),
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
                                    Icons.school_outlined,
                                    color: colorScheme.onSecondaryContainer,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Step 1: Select Exam Type',
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
                                child: Text(
                                  e.name,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ))
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedExamTypeId = value;
                                  selectedExamType = state.examTypes
                                      .firstWhere((exam) => exam.id == value);
                                  selectedSubjectId = null; // Clear subject when exam type changes
                                });
                                _fadeController.reset();
                                _fadeController.forward();
                              },
                              decoration: InputDecoration(
                                labelText: "Choose exam type",
                                prefixIcon: const Icon(Icons.assignment_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: colorScheme.outline.withOpacity(0.5),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: colorScheme.primary,
                                    width: 2,
                                  ),
                                ),
                                filled: true,
                                fillColor: colorScheme.surface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Exam Sections (animated)
                    if (selectedExamType != null && selectedExamType!.sections.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Card(
                          elevation: 0,
                          color: colorScheme.tertiaryContainer.withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
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
                                ...selectedExamType!.sections.map(
                                      (section) => Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surface,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: colorScheme.outline.withOpacity(0.2),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: colorScheme.primary.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Icon(
                                            Icons.quiz,
                                            size: 16,
                                            color: colorScheme.primary,
                                          ),
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
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Subject Selection (Updated to single selection)
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: colorScheme.outline.withOpacity(0.2),
                        ),
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
                                  'Step 2: Select Subject',
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

                            // Option 1: Dropdown for subjects (cleaner for single selection)
                            DropdownButtonFormField<String>(
                              value: selectedSubjectId,
                              items: state.subjects
                                  .map((subject) => DropdownMenuItem(
                                value: subject.id,
                                child: Text(
                                  subject.name,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ))
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedSubjectId = value;
                                });
                              },
                              decoration: InputDecoration(
                                labelText: "Choose subject",
                                prefixIcon: const Icon(Icons.book_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: colorScheme.outline.withOpacity(0.5),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: colorScheme.primary,
                                    width: 2,
                                  ),
                                ),
                                filled: true,
                                fillColor: colorScheme.surface,
                              ),
                            ),

                            // Option 2: Radio buttons (alternative implementation - uncomment to use)
                            /*
                            SizedBox(
                              height: 300,
                              child: ListView.builder(
                                itemCount: state.subjects.length,
                                itemBuilder: (context, index) {
                                  final subject = state.subjects[index];
                                  final isSelected = selectedSubjectId == subject.id;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? colorScheme.primaryContainer.withOpacity(0.5)
                                          : colorScheme.surface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? colorScheme.primary
                                            : colorScheme.outline.withOpacity(0.2),
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: RadioListTile<String>(
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 4,
                                      ),
                                      title: Text(
                                        subject.name,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? colorScheme.onPrimaryContainer
                                              : colorScheme.onSurface,
                                        ),
                                      ),
                                      value: subject.id,
                                      groupValue: selectedSubjectId,
                                      activeColor: colorScheme.primary,
                                      onChanged: (value) {
                                        setState(() {
                                          selectedSubjectId = value;
                                        });
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                            */
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: selectedExamTypeId != null && selectedSubjectId != null
                            ? () => _handleCreateQuestions(context, state)
                            : null,
                        icon: const Icon(Icons.create_outlined),
                        label: Text(
                          "Create Questions",
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          disabledBackgroundColor: colorScheme.outline.withOpacity(0.2),
                          disabledForegroundColor: colorScheme.onSurfaceVariant,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: selectedExamTypeId != null && selectedSubjectId != null ? 2 : 0,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Helper text
                    if (selectedExamTypeId == null || selectedSubjectId == null)
                      Center(
                        child: Text(
                          selectedExamTypeId == null
                              ? 'Please select an exam type first'
                              : 'Please select a subject',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            } else if (state is QpsError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Oops! Something went wrong",
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: colorScheme.error,
                      ),
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
                      onPressed: () {
                        context.read<QpsBloc>().add(LoadQpsData());
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox();
          },
        ),
      ),
    );
  }

  void _handleCreateQuestions(BuildContext context, QpsLoaded state) {
    if (selectedExamType == null || selectedSubjectId == null) {
      _showErrorSnackBar(context, 'Please select exam type and subject first');
      return;
    }

    // Find the selected subject entity
    final selectedSubject = state.subjects.firstWhere(
          (subject) => subject.id == selectedSubjectId,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => QuestionInputDialog(
        sections: selectedExamType!.sections,
        examType: selectedExamType!,
        selectedSubjects: [selectedSubject], // Pass as a single-item list
        onQuestionsSubmitted: (questions) {
          // Handle the submitted questions
          print('Questions submitted: $questions');

          // Show success message
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