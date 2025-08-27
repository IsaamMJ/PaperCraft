import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:papercraft/features/qps/data/models/question_paper_model.dart';
import 'package:papercraft/features/qps/domain/entities/exam_type_entity.dart';
import 'package:papercraft/features/qps/domain/entities/subject_entity.dart';
import 'package:papercraft/features/qps/presentation/widgets/question_input_widget.dart';
import 'package:papercraft/features/qps/presentation/widgets/question_paper_preview_widget.dart';
import 'package:papercraft/features/qps/services/cloud_service.dart';
import 'package:papercraft/features/qps/services/question_paper_cordinator_service.dart';
import 'package:papercraft/features/authentication/data/datasources/local_storage_data_source.dart';

class QuestionPaperEditScreen extends StatefulWidget {
  final String questionPaperId;
  final bool isViewOnly;

  const QuestionPaperEditScreen({
    super.key,
    required this.questionPaperId,
    this.isViewOnly = false,
  });

  @override
  State<QuestionPaperEditScreen> createState() => _QuestionPaperEditScreenState();
}

class _QuestionPaperEditScreenState extends State<QuestionPaperEditScreen> {
  late final QuestionPaperCoordinatorService _coordinatorService;

  QuestionPaperModel? _questionPaper;
  bool _isLoading = true;
  String? _errorMessage;

  // Edit state
  Map<String, List<Question>> _questions = {};
  List<SubjectEntity> _selectedSubjects = [];
  ExamTypeEntity? _examType;

  @override
  void initState() {
    super.initState();
    // Fixed: Removed explicit cast that was causing the type mismatch
    _coordinatorService = QuestionPaperCoordinatorService(LocalStorageDataSourceImpl());
    _loadQuestionPaper();
  }

  Future<void> _loadQuestionPaper() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      QuestionPaperModel? paper;

      // First try to load from local drafts
      print('🔎 Trying to load ${widget.questionPaperId} from drafts');
      final draftsResult = await _coordinatorService.getDrafts();
      if (draftsResult.success) {
        paper = draftsResult.data?.cast<QuestionPaperModel?>().firstWhere(
              (p) => p?.id == widget.questionPaperId,
          orElse: () => null,
        );
        if (paper != null) {
          print('✅ Found in drafts');
        }
      }

      // If not found in drafts, try user submissions (cloud)
      if (paper == null) {
        print('🔎 Trying to load ${widget.questionPaperId} from user submissions');
        final submissionsResult = await _coordinatorService.getUserSubmissions();
        if (submissionsResult.success) {
          final cloudPaper = submissionsResult.data?.cast<QuestionPaperCloudModel?>().firstWhere(
                (p) => p?.id == widget.questionPaperId,
            orElse: () => null,
          );

          if (cloudPaper != null) {
            print('✅ Found in user submissions');
            // Convert CloudModel to local model for editing/viewing
            paper = QuestionPaperModel(
              id: cloudPaper.id,
              title: cloudPaper.title,
              subject: cloudPaper.subject,
              examType: cloudPaper.examType,
              examTypeEntity: cloudPaper.examType != null ? _getExamTypeEntity(cloudPaper.examType) : _getDefaultExamType(),
              selectedSubjects: _getSubjectsFromString(cloudPaper.subject),
              questions: cloudPaper.questions,
              status: cloudPaper.status,
              createdBy: cloudPaper.createdByName ?? '',
              createdAt: cloudPaper.createdAt,
              modifiedAt: cloudPaper.submittedAt,
              rejectionReason: cloudPaper.rejectionReason,
            );
          }
        }
      }

      // If still not found and user has admin permissions, check review queue
      if (paper == null) {
        print('🔎 Trying to load ${widget.questionPaperId} from admin review queue');
        try {
          final hasAdmin = await _coordinatorService.hasAdminPermissions();
          if (hasAdmin) {
            final reviewResult = await _coordinatorService.getPapersForReview();
            if (reviewResult.success) {
              final cloudPaper = reviewResult.data?.cast<QuestionPaperCloudModel?>().firstWhere(
                    (p) => p?.id == widget.questionPaperId,
                orElse: () => null,
              );

              if (cloudPaper != null) {
                print('✅ Found in admin review queue');
                // Convert for viewing
                paper = QuestionPaperModel(
                  id: cloudPaper.id,
                  title: cloudPaper.title,
                  subject: cloudPaper.subject,
                  examType: cloudPaper.examType,
                  examTypeEntity: cloudPaper.examType != null ? _getExamTypeEntity(cloudPaper.examType) : _getDefaultExamType(),
                  selectedSubjects: _getSubjectsFromString(cloudPaper.subject),
                  questions: cloudPaper.questions,
                  status: cloudPaper.status,
                  createdBy: cloudPaper.createdByName ?? '',
                  createdAt: cloudPaper.createdAt,
                  modifiedAt: cloudPaper.submittedAt,
                  rejectionReason: cloudPaper.rejectionReason,
                );
              }
            }
          }
        } catch (e) {
          print('Warning: Could not check admin permissions: $e');
          // Continue without admin check - user might not be admin
        }
      }

      if (paper == null) {
        print('❌ Question paper not found in any location');
        setState(() {
          _errorMessage = 'Question paper not found';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _questionPaper = paper;
        _questions = Map.from(paper!.questions);
        _selectedSubjects = List.from(paper.selectedSubjects);
        _examType = paper.examTypeEntity;
        _isLoading = false;
      });

      print('Successfully loaded question paper: ${paper.title}');
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading question paper: $e';
        _isLoading = false;
      });
      print('Error loading question paper: $e');
    }
  }

  // Fixed: Added required id and tenantId parameters
  ExamTypeEntity _getExamTypeEntity(String examTypeName) {
    // Get tenant ID from your auth service or use a default
    // You might need to inject this from your auth service
    const String tenantId = 'default_tenant'; // Replace with actual tenant ID

    return ExamTypeEntity(
      id: 'exam_type_${examTypeName.toLowerCase().replaceAll(' ', '_')}',
      tenantId: tenantId,
      name: examTypeName,
      sections: [], // You'll need to populate this based on your data structure
      totalMarks: 0, // You'll need to calculate this
      totalQuestions: 0,
      durationMinutes: null,
    );
  }

  // Fixed: Added required id and tenantId parameters
  ExamTypeEntity _getDefaultExamType() {
    const String tenantId = 'default_tenant'; // Replace with actual tenant ID

    return ExamTypeEntity(
      id: 'unknown_exam_type',
      tenantId: tenantId,
      name: 'Unknown',
      sections: [],
      totalMarks: 0,
      totalQuestions: 0,
      durationMinutes: null,
    );
  }

  List<SubjectEntity> _getSubjectsFromString(String subjectName) {
    // Convert subject string to list of SubjectEntity
    if (subjectName.isEmpty) return [];

    // Get tenant ID from your auth service or use a default
    const String tenantId = 'default_tenant'; // Replace with actual tenant ID

    return [
      SubjectEntity(
        id: 'subject_${subjectName.toLowerCase().replaceAll(' ', '_')}',
        tenantId: tenantId,
        name: subjectName,
        description: null, // Optional description
        isActive: true, // Default to active
      )
    ];
  }

  Future<void> _saveChanges() async {
    if (_questionPaper == null) return;

    try {
      final updatedPaper = _questionPaper!.copyWith(
        questions: _questions,
        selectedSubjects: _selectedSubjects,
        modifiedAt: DateTime.now(),
      );

      // Use coordinator service to save changes
      final result = await _coordinatorService.saveDraft(updatedPaper);

      if (result.success) {
        setState(() {
          _questionPaper = updatedPaper;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Changes saved successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save changes: ${result.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error saving changes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving changes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showEditDialog(String sectionName) async {
    if (_examType == null) return;

    final section = _examType!.sections.firstWhere(
          (s) => s.name == sectionName,
      orElse: () => _examType!.sections.first,
    );

    // Simple approach - show dialog with current questions count
    final result = await showDialog<List<Question>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${section.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Section: ${section.name}'),
            Text('Current Questions: ${_questions[sectionName]?.length ?? 0}'),
            Text('Marks per Question: ${section.marksPerQuestion}'),
            const SizedBox(height: 16),
            const Text('This will open your question input dialog.'),
            const Text('Please update the parameters to match your QuestionInputDialog constructor.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // For now, just close - you'll need to implement actual editing
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please implement QuestionInputDialog with correct parameters'),
                ),
              );
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );

    // TODO: Replace above with your actual QuestionInputDialog
    // final result = await showDialog<List<Question>>(
    //   context: context,
    //   barrierDismissible: false,
    //   builder: (context) => QuestionInputDialog(
    //     // Add your actual parameters here
    //   ),
    // );

    if (result != null) {
      setState(() {
        _questions[sectionName] = result;
      });
    }
  }

  void _previewQuestionPaper() {
    if (_questionPaper == null || _examType == null) return;

    // Simple preview - show a dialog with basic info
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preview'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Title: ${_questionPaper!.title}'),
            Text('Subject: ${_questionPaper!.subject}'),
            Text('Exam Type: ${_questionPaper!.examType}'),
            const SizedBox(height: 16),
            const Text('Questions by Section:'),
            ..._examType!.sections.map((section) {
              final count = _questions[section.name]?.length ?? 0;
              return Text('• ${section.name}: $count questions');
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.orange;
      case 'submitted':
        return Colors.blue;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_questionPaper?.title ?? 'Edit Question Paper'),
        actions: [
          // Status indicator
          if (_questionPaper != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text(
                  _questionPaper!.status.toUpperCase(),
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
                backgroundColor: _getStatusColor(_questionPaper!.status),
              ),
            ),

          // Save changes
          if (_questionPaper != null && !widget.isViewOnly && _questionPaper!.status != 'approved')
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveChanges,
              tooltip: 'Save Changes',
            ),

          // Preview
          if (_questionPaper != null)
            IconButton(
              icon: const Icon(Icons.preview),
              onPressed: _previewQuestionPaper,
              tooltip: 'Preview',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading question paper...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center),
            SizedBox(height: 24),
            ElevatedButton(onPressed: _loadQuestionPaper, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_questionPaper == null || _examType == null) {
      return const Center(child: Text('Question paper data is incomplete'));
    }

    // Updated this block with correct constructor
    if (widget.isViewOnly) {
      return QuestionPaperPreview(
        examType: _examType!,
        questions: _questions,
        selectedSubjects: _selectedSubjects,
        existingQuestionPaper: _questionPaper,
      );
    }

    // Otherwise render the editor
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(),
          const SizedBox(height: 16),
          if (_questionPaper!.status == 'approved') _buildApprovedNotice(),
          _buildSectionsEditor(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Question Paper Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _buildInfoRow('Title', _questionPaper!.title),
            _buildInfoRow('Subject', _questionPaper!.subject),
            _buildInfoRow('Exam Type', _questionPaper!.examType),
            _buildInfoRow('Created By', _questionPaper!.createdBy),
            _buildInfoRow('Created', _formatDate(_questionPaper!.createdAt)),
            _buildInfoRow('Modified', _formatDate(_questionPaper!.modifiedAt)),

            if (_questionPaper!.status == 'rejected' && _questionPaper!.rejectionReason != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red[700], size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Rejection Reason:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _questionPaper!.rejectionReason!,
                      style: TextStyle(color: Colors.red[700]),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedNotice() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock, color: Colors.green[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This question paper is approved',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Approved question papers cannot be edited. You can only view and preview them.',
                  style: TextStyle(color: Colors.green[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionsEditor() {
    if (_examType == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Question Sections',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _questionPaper!.status == 'approved'
              ? 'View the questions in each section:'
              : 'Tap on a section to edit its questions:',
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),

        ..._examType!.sections.map((section) => _buildSectionCard(section)),
      ],
    );
  }

  Widget _buildSectionCard(ExamSectionEntity section) {
    final sectionQuestions = _questions[section.name] ?? [];
    final isEditable = !widget.isViewOnly && _questionPaper!.status != 'approved';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: isEditable ? () => _showEditDialog(section.name) : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      section.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isEditable)
                    Icon(Icons.edit, color: Colors.grey[600], size: 20)
                  else
                    Icon(Icons.visibility, color: Colors.grey[600], size: 20),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  _buildSectionStat(
                    'Questions',
                    '${sectionQuestions.length}',
                    Colors.blue,
                  ),
                  const SizedBox(width: 16),
                  _buildSectionStat(
                    'Marks Each',
                    '${section.marksPerQuestion}',
                    Colors.green,
                  ),
                  const SizedBox(width: 16),
                  _buildSectionStat(
                    'Total Marks',
                    '${sectionQuestions.length * section.marksPerQuestion}',
                    Colors.orange,
                  ),
                ],
              ),

              if (sectionQuestions.isEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange[700], size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'No questions added yet',
                        style: TextStyle(color: Colors.orange[700]),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}