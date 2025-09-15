// lib/features/question_papers/presentation/pages/question_bank_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'dart:html' as html;
import '../../../../core/services/pdf_generation_service.dart';
import '../../domain/entities/question_paper_entity.dart';
import '../bloc/question_paper_bloc.dart';
import '../widgets/shared/paper_status_badge.dart';

class QuestionBankPage extends StatefulWidget {
  const QuestionBankPage({super.key});

  @override
  State<QuestionBankPage> createState() => _QuestionBankPageState();
}

class _QuestionBankPageState extends State<QuestionBankPage> {
  String _searchQuery = '';
  String _selectedSubject = '';
  String _selectedExamType = '';
  DateTimeRange? _selectedDateRange;
  bool _isGeneratingPdf = false;
  String? _generatingPdfFor;

  @override
  void initState() {
    super.initState();
    _loadApprovedPapers();
  }

  void _loadApprovedPapers() {
    context.read<QuestionPaperBloc>().add(const LoadUserSubmissions());
  }

  void _handleSearch(String query) {
    setState(() => _searchQuery = query);
  }

  void _handleSubjectFilter(String? subject) {
    setState(() => _selectedSubject = subject ?? '');
  }

  void _handleExamTypeFilter(String? examType) {
    setState(() => _selectedExamType = examType ?? '');
  }

  void _handleDateRangeFilter() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );

    if (picked != null) {
      setState(() => _selectedDateRange = picked);
    }
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _selectedSubject = '';
      _selectedExamType = '';
      _selectedDateRange = null;
    });
  }

  Future<void> _generatePdf(QuestionPaperEntity paper, {bool isTeacherCopy = false}) async {
    setState(() {
      _isGeneratingPdf = true;
      _generatingPdfFor = paper.id;
    });

    try {
      final pdfBytes = isTeacherCopy
          ? await SimplePdfService.generateTeacherPdf(
        paper: paper,
        schoolName: 'Your School Name',
      )
          : await SimplePdfService.generateStudentPdf(
        paper: paper,
        schoolName: 'Your School Name',
      );

      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);

      final fileName = '${paper.title}_${isTeacherCopy ? 'Teacher_with_Answers' : 'Student'}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();

      html.Url.revokeObjectUrl(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF generated successfully: $fileName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
          _generatingPdfFor = null;
        });
      }
    }
  }

  List<QuestionPaperEntity> _filterPapers(List<QuestionPaperEntity> papers) {
    return papers.where((paper) {
      if (!paper.status.isApproved) return false;

      final matchesSearch = _searchQuery.isEmpty ||
          paper.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          paper.subject.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          paper.createdBy.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesSubject = _selectedSubject.isEmpty ||
          paper.subject == _selectedSubject;

      final matchesExamType = _selectedExamType.isEmpty ||
          paper.examType == _selectedExamType;

      final matchesDateRange = _selectedDateRange == null ||
          (paper.reviewedAt != null &&
              paper.reviewedAt!.isAfter(_selectedDateRange!.start) &&
              paper.reviewedAt!.isBefore(_selectedDateRange!.end.add(const Duration(days: 1))));

      return matchesSearch && matchesSubject && matchesExamType && matchesDateRange;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Question Bank'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            onPressed: _loadApprovedPapers,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: BlocListener<QuestionPaperBloc, QuestionPaperState>(
              listener: (context, state) {
                if (state is QuestionPaperError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: BlocBuilder<QuestionPaperBloc, QuestionPaperState>(
                builder: (context, state) {
                  if (state is QuestionPaperLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state is QuestionPaperLoaded) {
                    final approvedPapers = _filterPapers(state.submissions);

                    if (approvedPapers.isEmpty) {
                      return _buildEmptyState();
                    }

                    return RefreshIndicator(
                      onRefresh: () async => _loadApprovedPapers(),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: approvedPapers.length,
                        itemBuilder: (context, index) {
                          final paper = approvedPapers[index];
                          return _buildPaperCard(paper);
                        },
                      ),
                    );
                  }

                  return _buildEmptyState();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search papers by title, subject, or creator...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                onPressed: () => _handleSearch(''),
                icon: const Icon(Icons.clear),
              )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: _handleSearch,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: DropdownButton<String>(
                    value: _selectedSubject.isEmpty ? null : _selectedSubject,
                    hint: const Text('Subject'),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('All Subjects')),
                      DropdownMenuItem(value: 'Mathematics', child: Text('Mathematics')),
                      DropdownMenuItem(value: 'Physics', child: Text('Physics')),
                      DropdownMenuItem(value: 'Chemistry', child: Text('Chemistry')),
                      DropdownMenuItem(value: 'Biology', child: Text('Biology')),
                      DropdownMenuItem(value: 'English', child: Text('English')),
                    ],
                    onChanged: _handleSubjectFilter,
                    underline: Container(),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: DropdownButton<String>(
                    value: _selectedExamType.isEmpty ? null : _selectedExamType,
                    hint: const Text('Exam Type'),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('All Types')),
                      DropdownMenuItem(value: 'Midterm Exam', child: Text('Midterm')),
                      DropdownMenuItem(value: 'Final Exam', child: Text('Final')),
                      DropdownMenuItem(value: 'Quiz', child: Text('Quiz')),
                      DropdownMenuItem(value: 'Practice Test', child: Text('Practice')),
                    ],
                    onChanged: _handleExamTypeFilter,
                    underline: Container(),
                  ),
                ),
                FilterChip(
                  label: Text(_selectedDateRange == null
                      ? 'Date Range'
                      : '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}'),
                  selected: _selectedDateRange != null,
                  onSelected: (_) => _handleDateRangeFilter(),
                  selectedColor: Colors.green.shade100,
                ),
                const SizedBox(width: 8),
                if (_searchQuery.isNotEmpty || _selectedSubject.isNotEmpty ||
                    _selectedExamType.isNotEmpty || _selectedDateRange != null)
                  TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaperCard(QuestionPaperEntity paper) {
    final isGenerating = _isGeneratingPdf && _generatingPdfFor == paper.id;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        paper.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${paper.subject} • ${paper.examType}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                PaperStatusBadge(status: paper.status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildMetric(Icons.quiz_outlined, '${paper.totalQuestions} questions'),
                const SizedBox(width: 16),
                _buildMetric(Icons.score_outlined, '${paper.totalMarks} marks'),
                const SizedBox(width: 16),
                _buildMetric(Icons.schedule_outlined, paper.examTypeEntity.formattedDuration),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Created by: ${paper.createdBy}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (paper.reviewedAt != null)
                        Text(
                          'Approved: ${_formatDate(paper.reviewedAt!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/question-papers/view/${paper.id}'),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Preview'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade600,
                      side: BorderSide(color: Colors.blue.shade600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isGenerating ? null : () => _showPdfOptions(paper),
                    icon: isGenerating
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.download),
                    label: Text(isGenerating ? 'Generating...' : 'Generate PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  void _showPdfOptions(QuestionPaperEntity paper) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Generate PDF',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              paper.title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _generatePdf(paper, isTeacherCopy: false);
              },
              icon: const Icon(Icons.school),
              label: const Text('Student Copy'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _generatePdf(paper, isTeacherCopy: true);
              },
              icon: const Icon(Icons.key),
              label: const Text('Teacher Copy (with answers)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
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
            Icons.library_books_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Approved Papers Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _hasActiveFilters()
                ? 'Try adjusting your search filters'
                : 'Approved papers will appear here for PDF generation',
            style: TextStyle(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          if (_hasActiveFilters()) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _clearFilters,
              child: const Text('Clear Filters'),
            ),
          ],
        ],
      ),
    );
  }

  bool _hasActiveFilters() {
    return _searchQuery.isNotEmpty ||
        _selectedSubject.isNotEmpty ||
        _selectedExamType.isNotEmpty ||
        _selectedDateRange != null;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}