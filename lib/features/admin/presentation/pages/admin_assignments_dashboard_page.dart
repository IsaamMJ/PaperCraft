import 'package:flutter/material.dart';
import '../../domain/entities/admin_setup_state.dart';
import '../../domain/usecases/validate_subject_assignment_usecase.dart';

/// Admin dashboard for viewing and managing grade-section-subject assignments
class AdminAssignmentsDashboardPage extends StatefulWidget {
  final AdminSetupState setupState;

  const AdminAssignmentsDashboardPage({
    Key? key,
    required this.setupState,
  }) : super(key: key);

  @override
  State<AdminAssignmentsDashboardPage> createState() =>
      _AdminAssignmentsDashboardPageState();
}

class _AdminAssignmentsDashboardPageState
    extends State<AdminAssignmentsDashboardPage> {
  late ValidateSubjectAssignmentUseCase _validationUseCase;
  Map<String, dynamic>? _validationReport;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _validationUseCase = ValidateSubjectAssignmentUseCase();
    _loadValidationReport();
  }

  void _loadValidationReport() {
    setState(() => _isLoading = true);
    final result = _validationUseCase.getValidationReport(widget.setupState);

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${failure.message}')),
        );
        setState(() => _isLoading = false);
      },
      (report) {
        setState(() {
          _validationReport = report;
          _isLoading = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grade-Section-Subject Assignments'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadValidationReport,
            tooltip: 'Refresh Report',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _validationReport == null
              ? _buildEmptyState()
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildOverviewCards(),
                      const SizedBox(height: 24),
                      _buildCompletionStatus(),
                      const SizedBox(height: 24),
                      _buildGradesBreakdown(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No assignments configured',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Create grades, sections, and assign subjects to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCards() {
    if (_validationReport == null) return const SizedBox.shrink();

    final totalGrades = _validationReport!['totalGrades'] as int;
    final totalSections = _validationReport!['totalSections'] as int;
    final totalSubjects = _validationReport!['totalSubjects'] as int;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildOverviewCard(
              title: 'Grades',
              value: totalGrades.toString(),
              icon: Icons.school,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildOverviewCard(
              title: 'Sections',
              value: totalSections.toString(),
              icon: Icons.layers,
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildOverviewCard(
              title: 'Subjects',
              value: totalSubjects.toString(),
              icon: Icons.subject,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionStatus() {
    if (_validationReport == null) return const SizedBox.shrink();

    final completedSections =
        _validationReport!['completedGradeSections'] as int;
    final incompleteSections =
        _validationReport!['incompleteGradeSections'] as int;
    final isFullyConfigured = _validationReport!['isFullyConfigured'] as bool;
    final totalSections = completedSections + incompleteSections;

    final completionPercentage = totalSections > 0
        ? ((completedSections / totalSections) * 100).toStringAsFixed(1)
        : '0';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: isFullyConfigured
              ? Colors.green.withOpacity(0.1)
              : Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFullyConfigured
                ? Colors.green.withOpacity(0.3)
                : Colors.orange.withOpacity(0.3),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isFullyConfigured ? Icons.check_circle : Icons.info,
                  color: isFullyConfigured ? Colors.green : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  isFullyConfigured
                      ? 'All Sections Configured'
                      : 'Incomplete Configuration',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: isFullyConfigured
                            ? Colors.green[800]
                            : Colors.orange[800],
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: completionPercentage == '0'
                    ? 0
                    : (completedSections / totalSections),
                minHeight: 8,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  isFullyConfigured ? Colors.green : Colors.orange,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Completion: $completionPercentage%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  '$completedSections/$totalSections sections configured',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
            if (incompleteSections > 0) ...[
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red[700],
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$incompleteSections section${incompleteSections > 1 ? 's' : ''} missing subject assignments',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.red[700],
                              fontWeight: FontWeight.w600,
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

  Widget _buildGradesBreakdown() {
    if (_validationReport == null) return const SizedBox.shrink();

    final grades = _validationReport!['grades'] as List<dynamic>;

    if (grades.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Grades & Sections Breakdown',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: grades.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, gradeIndex) {
              final grade = grades[gradeIndex] as Map<String, dynamic>;
              final gradeNumber = grade['gradeNumber'] as int;
              final sections = grade['sections'] as List<dynamic>;

              return _buildGradeCard(gradeNumber, sections);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGradeCard(int gradeNumber, List<dynamic> sections) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ExpansionTile(
        title: Text(
          'Grade $gradeNumber',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        subtitle: Text(
          '${sections.length} section${sections.length > 1 ? 's' : ''}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sections.length,
            separatorBuilder: (_, __) =>
                Divider(color: Colors.grey[300], height: 1),
            itemBuilder: (context, sectionIndex) {
              final section = sections[sectionIndex] as Map<String, dynamic>;
              final sectionName = section['sectionName'] as String;
              final subjectCount = section['subjectCount'] as int;
              final isComplete = section['isComplete'] as bool;

              return _buildSectionTile(
                gradeNumber: gradeNumber,
                sectionName: sectionName,
                subjectCount: subjectCount,
                isComplete: isComplete,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTile({
    required int gradeNumber,
    required String sectionName,
    required int subjectCount,
    required bool isComplete,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isComplete ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: 12),
          // Section info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Section $sectionName',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$subjectCount subject${subjectCount > 1 ? 's' : ''} assigned',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ),
          // Status chip
          Container(
            decoration: BoxDecoration(
              color: isComplete
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              isComplete ? 'Complete' : 'Incomplete',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color:
                        isComplete ? Colors.green[700] : Colors.red[700],
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
