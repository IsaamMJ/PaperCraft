import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../core/services/logger.dart';
import '../../../authentication/data/datasources/local_storage_data_source.dart';
import '../../data/models/question_paper_model.dart';
import '../../domain/entities/exam_type_entity.dart';
import '../../domain/entities/subject_entity.dart';
import '../../services/question_paper_cordinator_service.dart';
import '../../services/question_paper_storage_service.dart';
import 'question_input_widget.dart';

enum PrintLayout { single, dual }

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
  LocalStorageDataSource? _localStorage;
  QuestionPaperCoordinatorService? _coordinatorService;
  QuestionPaperModel? _currentQuestionPaper;
  final _titleController = TextEditingController();
  PrintLayout _currentLayout = PrintLayout.single;
  bool _isLoading = false;
  bool _servicesInitialized = false;

  @override
  void initState() {
    super.initState();
    // Initialize services after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
    });
    _initializeQuestionPaper();
  }

  void _initializeServices() {
    try {
      // Initialize LocalStorageDataSource with your concrete implementation
      _localStorage = LocalStorageDataSourceImpl();
      LoggingService.debug('LocalStorageDataSource initialized successfully');

      // Try to initialize coordinator service
      _initializeCoordinatorService();

      _servicesInitialized = true;

    } catch (e) {
      LoggingService.error('Failed to initialize services: $e');
      _handleServiceInitializationError(e);
    }
  }

  void _initializeCoordinatorService() {
    try {
      if (_localStorage != null) {
        // Check if user is authenticated first
        _checkAuthenticationAndInitialize();
      }
    } catch (e) {
      LoggingService.warning('Coordinator service initialization failed: $e');
      _coordinatorService = null;
      _showOfflineModeNotification();
    }
  }

  Future<void> _checkAuthenticationAndInitialize() async {
    try {
      // Verify user authentication
      final hasUserData = await _localStorage!.hasUserData();
      if (!hasUserData) {
        LoggingService.warning('User not authenticated - running in local mode only');
        _coordinatorService = null;
        _showOfflineModeNotification();
        return;
      }

      // Get user context for debugging
      final tenantId = await _localStorage!.getTenantId();
      final userId = await _localStorage!.getUserId();
      final userRole = await _localStorage!.getUserRole();

      LoggingService.debug('User context: tenantId=$tenantId, userId=$userId, role=$userRole');

      // Try to initialize the coordinator service
      _coordinatorService = QuestionPaperCoordinatorService(_localStorage!);

      // Test the service by validating session
      final isValidSession = await _coordinatorService!.isValidSession();
      if (!isValidSession) {
        LoggingService.warning('Invalid session - coordinator service disabled');
        _coordinatorService = null;
        _showAuthenticationError();
        return;
      }

      LoggingService.debug('Coordinator service initialized successfully');

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cloud sync available'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

    } catch (e) {
      LoggingService.error('Authentication check failed: $e');
      _coordinatorService = null;
      _showOfflineModeNotification();
    }
  }

  void _showOfflineModeNotification() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Running in offline mode - local save only'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _showAuthenticationError() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication expired - please log in again'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _handleServiceInitializationError(dynamic error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Service initialization failed: ${error.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _initializeServices(),
          ),
        ),
      );
    }
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
      _currentQuestionPaper = QuestionPaperModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: '${widget.examType.name} - ${widget.selectedSubjects.map((s) => s.name).join(", ")}',
        subject: widget.selectedSubjects.map((s) => s.name).join(", "),
        examType: widget.examType.name,
        createdBy: 'Current User',
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

  // Helper methods to check service availability
  bool _isCoordinatorServiceAvailable() {
    return _coordinatorService != null;
  }

  bool _isLocalStorageAvailable() {
    return _localStorage != null;
  }

  Future<void> _saveDraft() async {
    if (_currentQuestionPaper == null) return;

    try {
      final updatedPaper = _currentQuestionPaper!.copyWith(
        title: _titleController.text.trim(),
        modifiedAt: DateTime.now(),
      );

      final success = await _storageService.saveQuestionPaper(updatedPaper);

      if (success && mounted) {
        setState(() {
          _currentQuestionPaper = updatedPaper;
        });

        final message = _isCoordinatorServiceAvailable()
            ? 'Question paper saved as draft'
            : 'Question paper saved locally (offline mode)';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: _isCoordinatorServiceAvailable() ? Colors.green : Colors.blue,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save question paper'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      LoggingService.error('Error saving draft: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error saving question paper - please try again'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveDraftBeforeSubmit() async {
    if (_currentQuestionPaper == null) return;

    try {
      final updatedPaper = _currentQuestionPaper!.copyWith(
        title: _titleController.text.trim(),
        modifiedAt: DateTime.now(),
      );

      // Check if coordinator service is available
      if (!_isCoordinatorServiceAvailable()) {
        // Fallback to local storage only
        final success = await _storageService.saveQuestionPaper(updatedPaper);
        if (success) {
          setState(() {
            _currentQuestionPaper = updatedPaper;
          });
          LoggingService.debug('Draft saved locally (coordinator service not available)');
        } else {
          throw Exception('Failed to save draft locally');
        }
        return;
      }

      final result = await _coordinatorService!.saveDraft(updatedPaper);

      if (result.success && result.data != null) {
        setState(() {
          _currentQuestionPaper = result.data;
        });
        LoggingService.debug('Draft saved before submission');
      } else {
        LoggingService.error('Failed to save draft: ${result.error}');
        throw Exception(result.error ?? 'Failed to save draft');
      }
    } catch (e) {
      LoggingService.error('Error in _saveDraftBeforeSubmit: $e');
      rethrow;
    }
  }

  Future<void> _submitForApproval() async {
    if (_currentQuestionPaper == null) return;

    // Check if coordinator service is available
    if (!_isCoordinatorServiceAvailable()) {
      if (mounted) {
        _showOfflineModeDialog();
      }
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a title')),
        );
      }
      return;
    }

    // Show confirmation dialog
    final bool? confirmed = await _showSubmissionConfirmationDialog();
    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // First, save as draft to ensure we have the latest version
      await _saveDraftBeforeSubmit();

      if (_currentQuestionPaper == null) {
        throw Exception('Failed to save draft before submission');
      }

      // Then submit for approval
      final result = await _coordinatorService!.submitForApproval(_currentQuestionPaper!);

      if (result.success && mounted) {
        setState(() {
          _currentQuestionPaper = null;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.data ?? 'Question paper submitted for approval'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.of(context).pop();
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });

        _handleSubmissionError(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        LoggingService.error('Error in _submitForApproval: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An unexpected error occurred. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper method to show offline mode dialog
  void _showOfflineModeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cloud_off, color: Colors.orange),
            SizedBox(width: 8),
            Text('Offline Mode'),
          ],
        ),
        content: const Text(
          'Cloud sync is not available. You can save your question paper locally, '
              'but submission for approval requires an internet connection and proper authentication.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _saveDraft();
            },
            child: const Text('Save Locally'),
          ),
        ],
      ),
    );
  }

  // Helper method for submission confirmation
  Future<bool?> _showSubmissionConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Submit for Approval'),
          content: const Text(
            'Are you sure you want to submit this question paper for approval? '
                'Once submitted, it cannot be edited until reviewed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  // Helper method to handle submission errors
  void _handleSubmissionError(dynamic result) {
    String errorMessage;
    Color backgroundColor = Colors.red;

    switch (result.errorCode) {
      case 'AUTH_ERROR':
        errorMessage = 'Authentication required. Please log in again.';
        break;
      case 'NETWORK_ERROR':
        errorMessage = 'Network error. Please check your connection.';
        backgroundColor = Colors.orange;
        break;
      default:
        errorMessage = result.error ?? 'Failed to submit question paper';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 4),
        action: result.errorCode == 'AUTH_ERROR'
            ? SnackBarAction(
          label: 'Login',
          onPressed: () {
            Navigator.of(context).pushReplacementNamed('/login');
          },
        )
            : null,
      ),
    );
  }

  Future<void> _showSaveDialog() async {
    if (_currentQuestionPaper?.status == 'approved') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot modify approved question paper')),
      );
      return;
    }

    final bool coordinatorAvailable = _isCoordinatorServiceAvailable();
    final bool localStorageAvailable = _isLocalStorageAvailable();

    if (!localStorageAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Storage not available - cannot save question paper'),
          backgroundColor: Colors.red,
        ),
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
            Row(
              children: [
                Icon(
                  coordinatorAvailable ? Icons.cloud : Icons.cloud_off,
                  color: coordinatorAvailable ? Colors.green : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    coordinatorAvailable
                        ? 'Cloud sync available'
                        : 'Offline mode - local save only',
                    style: TextStyle(
                      color: coordinatorAvailable ? Colors.green.shade700 : Colors.orange.shade700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              coordinatorAvailable
                  ? 'Choose what you would like to do:'
                  : 'You can save locally, but cloud submission is not available.',
              style: const TextStyle(fontSize: 14),
            ),
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
            child: Text(coordinatorAvailable ? 'Save as Draft' : 'Save Locally'),
          ),
          if (coordinatorAvailable && _currentQuestionPaper?.status != 'submitted')
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

  // PDF generation methods remain the same
  Future<pw.Document> _generatePDF() async {
    final pdf = pw.Document();

    if (_currentLayout == PrintLayout.single) {
      return _generateSingleLayoutPDF(pdf);
    } else {
      return _generateDualLayoutPDF(pdf);
    }
  }

  Future<pw.Document> _generateSingleLayoutPDF(pw.Document pdf) async {
    int totalMarks = widget.examType.calculatedTotalMarks;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(totalMarks),
              pw.SizedBox(height: 8),
              _buildInstructions(),
              pw.SizedBox(height: 8),
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

  Future<pw.Document> _generateDualLayoutPDF(pw.Document pdf) async {
    int totalMarks = widget.examType.calculatedTotalMarks;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape, // Landscape orientation
        margin: const pw.EdgeInsets.all(10),
        build: (pw.Context context) {
          return pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // First copy
              pw.Expanded(
                child: pw.Container(
                  height: double.infinity,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildCompactHeader(totalMarks),
                      pw.SizedBox(height: 4),
                      _buildCompactInstructions(),
                      pw.SizedBox(height: 4),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: _buildCompactSections(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              pw.SizedBox(width: 8),

              // Divider line
              pw.Container(
                width: 0.5,
                height: double.infinity,
                color: PdfColors.grey400,
              ),

              pw.SizedBox(width: 8),

              // Second copy
              pw.Expanded(
                child: pw.Container(
                  height: double.infinity,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildCompactHeader(totalMarks),
                      pw.SizedBox(height: 4),
                      _buildCompactInstructions(),
                      pw.SizedBox(height: 4),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: _buildCompactSections(),
                        ),
                      ),
                    ],
                  ),
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
        if (widget.selectedSubjects.isNotEmpty)
          pw.Text(
            'Subject: ${widget.selectedSubjects.map((s) => s.name).join(", ")}',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        pw.SizedBox(height: 8),
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

  pw.Widget _buildCompactHeader(int totalMarks) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          'PEARL MATRICULATION HIGHER SECONDARY SCHOOL, THEREKALPUTHOOR',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          height: 0.5,
          width: double.infinity,
          color: PdfColors.black,
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          widget.examType.name,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 3),
        if (widget.selectedSubjects.isNotEmpty)
          pw.Text(
            'Subject: ${widget.selectedSubjects.map((s) => s.name).join(", ")}',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
          children: [
            pw.Text('Duration: ${widget.examType.durationMinutes ?? 180} min', style: pw.TextStyle(fontSize: 9)),
            pw.Text('Total Marks: $totalMarks', style: pw.TextStyle(fontSize: 9)),
            pw.Text('Date: ${DateTime.now().toString().split(' ')[0]}', style: pw.TextStyle(fontSize: 9)),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildInstructions() {
    List<String> instructions = ['• Read all questions carefully', '• Use black or blue ink only'];
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

  pw.Widget _buildCompactInstructions() {
    List<String> instructions = ['• Read all questions carefully', '• Use black or blue ink only'];
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
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          instructions.join(' '),
          style: pw.TextStyle(fontSize: 8),
        ),
      ],
    );
  }

  List<pw.Widget> _buildSections() {
    return _buildSectionsList(isCompact: false);
  }

  List<pw.Widget> _buildCompactSections() {
    return _buildSectionsList(isCompact: true);
  }

  List<pw.Widget> _buildSectionsList({required bool isCompact}) {
    List<pw.Widget> sectionWidgets = [];
    double headerFontSize = isCompact ? 10.0 : 12.0;
    double spacing = isCompact ? 4.0 : 6.0;

    for (int i = 0; i < widget.examType.sections.length; i++) {
      final section = widget.examType.sections[i];
      final sectionQuestions = widget.questions[section.name] ?? [];

      if (sectionQuestions.isEmpty) continue;

      final totalSectionMarks = section.totalMarksForExam;
      final questionsToAnswer = section.questionsForExam;
      final questionsProvided = sectionQuestions.length;

      String sectionTitle;
      if (section.hasOptionalQuestions) {
        sectionTitle = 'SECTION ${String.fromCharCode(65 + i)} - ${section.name.toUpperCase()} '
            '(Answer $questionsToAnswer out of $questionsProvided questions - ${section.marksPerQuestion} marks each = ${totalSectionMarks} marks)';
      } else {
        sectionTitle = 'SECTION ${String.fromCharCode(65 + i)} - ${section.name.toUpperCase()} '
            '(${section.marksPerQuestion} × $questionsToAnswer = ${totalSectionMarks} marks)';
      }

      sectionWidgets.add(
        pw.Text(
          sectionTitle,
          style: pw.TextStyle(
            fontSize: headerFontSize,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      );

      sectionWidgets.add(pw.SizedBox(height: spacing));

      for (int j = 0; j < sectionQuestions.length; j++) {
        final question = sectionQuestions[j];
        sectionWidgets.add(
          _buildQuestion(question, j + 1, section.hasOptionalQuestions, isCompact),
        );
        sectionWidgets.add(pw.SizedBox(height: spacing));
      }

      sectionWidgets.add(pw.SizedBox(height: spacing * 1.2));
    }

    return sectionWidgets;
  }

  pw.Widget _buildQuestion(Question question, int questionNumber, bool isFromOptionalSection, bool isCompact) {
    double fontSize = isCompact ? 8.5 : 11.0;
    double questionFontSize = isCompact ? 9.0 : 11.0;
    double marksFontSize = isCompact ? 8.0 : 10.0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Text(
                'Q$questionNumber. ${question.text}',
                style: pw.TextStyle(
                  fontSize: questionFontSize,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            if (question.subQuestions.isNotEmpty) ...[
              pw.SizedBox(width: 4),
              pw.Text(
                '[${question.totalMarks}m]',
                style: pw.TextStyle(
                  fontSize: marksFontSize,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ],
        ),

        if (question.subQuestions.isNotEmpty) ...[
          pw.SizedBox(height: 3),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: question.subQuestions.asMap().entries.map((entry) {
              final index = entry.key;
              final subQuestion = entry.value;
              final subQuestionLetter = String.fromCharCode(97 + index);

              return pw.Padding(
                padding: pw.EdgeInsets.only(left: isCompact ? 15 : 20, bottom: isCompact ? 2 : 3),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        '$subQuestionLetter) ${subQuestion.text}',
                        style: pw.TextStyle(fontSize: fontSize),
                      ),
                    ),
                    pw.Text(
                      '[${subQuestion.marks}m]',
                      style: pw.TextStyle(fontSize: marksFontSize),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],

        if (question.type == 'multiple_choice' && question.options != null) ...[
          pw.Padding(
            padding: pw.EdgeInsets.only(
              left: question.subQuestions.isNotEmpty ? (isCompact ? 15 : 20) : 0,
              top: 3,
            ),
            child: pw.Wrap(
              spacing: isCompact ? 12 : 15,
              children: question.options!.asMap().entries.map((entry) {
                final index = entry.key;
                final option = entry.value;
                final optionLetter = String.fromCharCode(97 + index);

                return pw.Text(
                  '($optionLetter) $option',
                  style: pw.TextStyle(fontSize: fontSize),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLayoutSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: SegmentedButton<PrintLayout>(
        segments: const [
          ButtonSegment<PrintLayout>(
            value: PrintLayout.single,
            label: Text('Single', style: TextStyle(fontSize: 12)),
            icon: Icon(Icons.description, size: 16),
          ),
          ButtonSegment<PrintLayout>(
            value: PrintLayout.dual,
            label: Text('Dual', style: TextStyle(fontSize: 12)),
            icon: Icon(Icons.view_column, size: 16),
          ),
        ],
        selected: {_currentLayout},
        onSelectionChanged: (Set<PrintLayout> newSelection) {
          setState(() {
            _currentLayout = newSelection.first;
          });
        },
        style: SegmentedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(80, 32),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentQuestionPaper?.title ?? 'Question Paper Preview'),
        actions: [
          // Layout selector
          _buildLayoutSelector(),
          const SizedBox(width: 8),

          // Service status indicator
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: Icon(
              _isCoordinatorServiceAvailable() ? Icons.cloud : Icons.cloud_off,
              color: _isCoordinatorServiceAvailable() ? Colors.green : Colors.orange,
              size: 20,
            ),
          ),

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

          // Show loading indicator when submitting
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _showSaveDialog,
              tooltip: 'Save Question Paper',
            ),

            IconButton(
              icon: const Icon(Icons.print),
              onPressed: () async {
                try {
                  final pdf = await _generatePDF();
                  await Printing.layoutPdf(
                    onLayout: (PdfPageFormat format) async => pdf.save(),
                  );
                } catch (e) {
                  LoggingService.error('Error printing PDF: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to print PDF')),
                    );
                  }
                }
              },
              tooltip: _currentLayout == PrintLayout.dual
                  ? 'Print Dual Layout (Landscape)'
                  : 'Print Single Layout',
            ),

            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () async {
                try {
                  final pdf = await _generatePDF();
                  final layoutSuffix = _currentLayout == PrintLayout.dual ? '_Dual' : '';
                  await Printing.sharePdf(
                    bytes: await pdf.save(),
                    filename: '${_currentQuestionPaper?.title.replaceAll(' ', '_') ?? 'Question_Paper'}$layoutSuffix.pdf',
                  );
                } catch (e) {
                  LoggingService.error('Error sharing PDF: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to share PDF')),
                    );
                  }
                }
              },
              tooltip: 'Share PDF',
            ),
          ],
        ],
      ),
      body: PdfPreview(
        build: (format) async {
          try {
            final pdf = await _generatePDF();
            return pdf.save();
          } catch (e) {
            LoggingService.error('Error generating PDF preview: $e');
            rethrow;
          }
        },
        canChangePageFormat: false,
        canDebug: false,
        initialPageFormat: _currentLayout == PrintLayout.dual
            ? PdfPageFormat.a4.landscape
            : PdfPageFormat.a4,
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