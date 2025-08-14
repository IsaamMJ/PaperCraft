import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/question_paper_model.dart';
import '../../domain/entities/exam_type_entity.dart';
import '../../domain/entities/subject_entity.dart';
import '../../services/question_paper_storage_service.dart';
import 'question_input_widget.dart';

class QuestionPaperPreview extends StatefulWidget {
  final ExamTypeEntity examType;
  final Map<String, List<Question>> questions;
  final List<SubjectEntity> selectedSubjects;
  final QuestionPaperModel? existingQuestionPaper;

  const QuestionPaperPreview({
    super.key,
    required this.examType,
    required this.questions,
    required this.selectedSubjects,
    this.existingQuestionPaper,
  });

  @override
  State<QuestionPaperPreview> createState() => _QuestionPaperPreviewState();
}

class _QuestionPaperPreviewState extends State<QuestionPaperPreview> {
  final _storageService = QuestionPaperStorageService();
  QuestionPaperModel? _currentQuestionPaper;
  final _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeQuestionPaper();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _initializeQuestionPaper() {
    if (widget.existingQuestionPaper != null) {
      _currentQuestionPaper = widget.existingQuestionPaper;
      _titleController.text = _currentQuestionPaper!.title;
    } else {
      // Create new question paper
      _currentQuestionPaper = QuestionPaperModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: '${widget.examType.name} - ${widget.selectedSubjects.map((s) => s.name).join(", ")}',
        subject: widget.selectedSubjects.map((s) => s.name).join(", "),
        examType: widget.examType.name,
        createdBy: 'Current User', // Replace with actual user
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        status: 'draft',
        examTypeEntity: widget.examType,
        questions: widget.questions,
        selectedSubjects: widget.selectedSubjects,
      );
      _titleController.text = _currentQuestionPaper!.title;
    }
  }

  Future<pw.Document> _generatePDF() async {
    final pdf = pw.Document();

    // Calculate total marks correctly (using questionsForExam, not total questions)
    int totalMarks = widget.examType.calculatedTotalMarks;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(totalMarks),
              pw.SizedBox(height: 8),

              // Instructions
              _buildInstructions(),
              pw.SizedBox(height: 8),

              // Sections
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: _buildSections(),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  pw.Widget _buildHeader(int totalMarks) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          'PEARL MATRICULATION HIGHER SECONDARY SCHOOL, THEREKALPUTHOOR',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          height: 1,
          width: double.infinity,
          color: PdfColors.black,
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          widget.examType.name,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),

        // Subject name
        if (widget.selectedSubjects.isNotEmpty)
          pw.Text(
            'Subject: ${widget.selectedSubjects.map((s) => s.name).join(", ")}',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        pw.SizedBox(height: 8),

        // Compact exam details
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
          children: [
            pw.Text('Duration: ${widget.examType.durationMinutes ?? 180} min', style: pw.TextStyle(fontSize: 10)),
            pw.Text('Total Marks: $totalMarks', style: pw.TextStyle(fontSize: 10)),
            pw.Text('Date: ${DateTime.now().toString().split(' ')[0]}', style: pw.TextStyle(fontSize: 10)),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildInstructions() {
    List<String> instructions = ['• Read all questions carefully', '• Use black or blue ink only'];

    // Add section-specific instructions for optional questions
    bool hasOptionalSections = widget.examType.sections.any((section) => section.hasOptionalQuestions);
    if (hasOptionalSections) {
      instructions.insert(1, '• Follow question requirements for each section');
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'INSTRUCTIONS:',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          instructions.join(' '),
          style: pw.TextStyle(fontSize: 9),
        ),
      ],
    );
  }

  List<pw.Widget> _buildSections() {
    List<pw.Widget> sectionWidgets = [];

    for (int i = 0; i < widget.examType.sections.length; i++) {
      final section = widget.examType.sections[i];
      final sectionQuestions = widget.questions[section.name] ?? [];

      if (sectionQuestions.isEmpty) continue;

      // Use correct marks calculation
      final totalSectionMarks = section.totalMarksForExam;
      final questionsToAnswer = section.questionsForExam;
      final questionsProvided = sectionQuestions.length;

      // Build section header with correct information
      String sectionTitle;
      if (section.hasOptionalQuestions) {
        sectionTitle = 'SECTION ${String.fromCharCode(65 + i)} - ${section.name.toUpperCase()} '
            '(Answer $questionsToAnswer out of $questionsProvided questions - ${section.marksPerQuestion} marks each = $totalSectionMarks marks)';
      } else {
        sectionTitle = 'SECTION ${String.fromCharCode(65 + i)} - ${section.name.toUpperCase()} '
            '(${section.marksPerQuestion} × $questionsToAnswer = $totalSectionMarks marks)';
      }

      sectionWidgets.add(
        pw.Text(
          sectionTitle,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      );

      sectionWidgets.add(pw.SizedBox(height: 6));

      // Questions
      for (int j = 0; j < sectionQuestions.length; j++) {
        final question = sectionQuestions[j];
        sectionWidgets.add(
          _buildQuestion(question, j + 1, section.hasOptionalQuestions),
        );
        sectionWidgets.add(pw.SizedBox(height: 6));
      }

      sectionWidgets.add(pw.SizedBox(height: 10));
    }

    return sectionWidgets;
  }

  pw.Widget _buildQuestion(Question question, int questionNumber, bool isFromOptionalSection) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Question with optional indicator if needed
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Text(
                'Q$questionNumber. ${question.text}',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            // Show individual question marks if there are sub-questions
            if (question.subQuestions.isNotEmpty) ...[
              pw.SizedBox(width: 8),
              pw.Text(
                '[${question.totalMarks}m]',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ],
        ),

        pw.SizedBox(height: 4),

        // Sub-questions
        if (question.subQuestions.isNotEmpty) ...[
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: question.subQuestions.asMap().entries.map((entry) {
              final index = entry.key;
              final subQuestion = entry.value;
              final subQuestionLetter = String.fromCharCode(97 + index); // a, b, c

              return pw.Padding(
                padding: const pw.EdgeInsets.only(left: 20, bottom: 3),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        '$subQuestionLetter) ${subQuestion.text}',
                        style: pw.TextStyle(fontSize: 10),
                      ),
                    ),
                    pw.Text(
                      '[${subQuestion.marks}m]',
                      style: pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],

        // Multiple choice options
        if (question.type == 'multiple_choice' && question.options != null) ...[
          pw.Padding(
            padding: question.subQuestions.isNotEmpty
                ? const pw.EdgeInsets.only(left: 20, top: 4)
                : const pw.EdgeInsets.only(top: 4),
            child: pw.Wrap(
              spacing: 15,
              children: question.options!.asMap().entries.map((entry) {
                final index = entry.key;
                final option = entry.value;
                final optionLetter = String.fromCharCode(97 + index); // a, b, c, d

                return pw.Text('($optionLetter) $option', style: pw.TextStyle(fontSize: 10));
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  // Save as draft
  Future<void> _saveDraft() async {
    if (_currentQuestionPaper == null) return;

    final updatedPaper = _currentQuestionPaper!.copyWith(
      title: _titleController.text.trim(),
      modifiedAt: DateTime.now(),
    );

    final success = await _storageService.saveQuestionPaper(updatedPaper);

    if (success) {
      setState(() {
        _currentQuestionPaper = updatedPaper;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Question paper saved as draft')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save question paper')),
      );
    }
  }

  // Submit for approval
  Future<void> _submitForApproval() async {
    if (_currentQuestionPaper == null) return;

    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    final updatedPaper = _currentQuestionPaper!.copyWith(
      title: _titleController.text.trim(),
      status: 'submitted',
      modifiedAt: DateTime.now(),
    );

    final success = await _storageService.moveQuestionPaper(_currentQuestionPaper!, 'submitted');

    if (success) {
      setState(() {
        _currentQuestionPaper = updatedPaper;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Question paper submitted for approval')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit question paper')),
      );
    }
  }

  // Show save/submit dialog
  Future<void> _showSaveDialog() async {
    if (_currentQuestionPaper?.status == 'approved') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot modify approved question paper')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Question Paper'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            const Text('What would you like to do?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _saveDraft();
            },
            child: const Text('Save as Draft'),
          ),
          if (_currentQuestionPaper?.status != 'submitted')
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _submitForApproval();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Submit for Approval'),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.orange.shade100;
      case 'submitted':
        return Colors.blue.shade100;
      case 'approved':
        return Colors.green.shade100;
      case 'rejected':
        return Colors.red.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentQuestionPaper?.title ?? 'Question Paper Preview'),
        actions: [
          // Status indicator
          if (_currentQuestionPaper != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text(
                  _currentQuestionPaper!.status.toUpperCase(),
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: _getStatusColor(_currentQuestionPaper!.status),
              ),
            ),

          // Save button
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _showSaveDialog,
            tooltip: 'Save Question Paper',
          ),

          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () async {
              final pdf = await _generatePDF();
              await Printing.layoutPdf(
                onLayout: (PdfPageFormat format) async => pdf.save(),
              );
            },
            tooltip: 'Print',
          ),

          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              final pdf = await _generatePDF();
              await Printing.sharePdf(
                bytes: await pdf.save(),
                filename: '${_currentQuestionPaper?.title.replaceAll(' ', '_') ?? 'Question_Paper'}.pdf',
              );
            },
            tooltip: 'Share PDF',
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => _generatePDF().then((pdf) => pdf.save()),
        canChangePageFormat: false,
        canDebug: false,
        initialPageFormat: PdfPageFormat.a4,
      ),
    );
  }
}

// Extension to navigate to PDF preview
extension QuestionInputDialogExtension on QuestionInputDialog {
  static void navigateToPreview({
    required BuildContext context,
    required ExamTypeEntity examType,
    required Map<String, List<Question>> questions,
    required List<SubjectEntity> selectedSubjects,
    QuestionPaperModel? existingQuestionPaper,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QuestionPaperPreview(
          examType: examType,
          questions: questions,
          selectedSubjects: selectedSubjects,
          existingQuestionPaper: existingQuestionPaper,
        ),
      ),
    );
  }
}