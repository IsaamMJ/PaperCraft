import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../authentication/presentation/bloc/auth_bloc.dart';
import '../../../authentication/presentation/bloc/auth_event.dart';
import '../../../authentication/presentation/bloc/auth_state.dart';
import '../../../authentication/data/datasources/local_storage_data_source.dart';
import '../../../qps/data/models/question_paper_model.dart';
import '../../../qps/services/cloud_service.dart';
import '../../../../core/services/logger.dart';
import '../../../qps/services/question_paper_cordinator_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final QuestionPaperCoordinatorService _coordinatorService;

  // For teachers: drafts + submissions
  List<QuestionPaperModel> _drafts = [];
  List<QuestionPaperCloudModel> _submissions = [];

  // For admins: papers pending review
  List<QuestionPaperCloudModel> _reviewQueue = [];

  bool _isLoading = true;
  String _selectedStatus = 'all';
  String _errorMessage = '';
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _coordinatorService = QuestionPaperCoordinatorService(LocalStorageDataSourceImpl());
    _checkUserRoleAndLoadData();
  }

  Future<void> _checkUserRoleAndLoadData() async {
    try {
      _isAdmin = await _coordinatorService.hasAdminPermissions();
      await _loadQuestionPapers();
    } catch (e) {
      LoggingService.error('Error checking user role: $e');
      setState(() {
        _errorMessage = 'Error checking user permissions';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadQuestionPapers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      if (_isAdmin) {
        await _loadAdminData();
      } else {
        await _loadTeacherData();
      }

      setState(() {
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading question papers: $e';
      });

      LoggingService.error('Error loading question papers: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading question papers: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _loadQuestionPapers,
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadAdminData() async {
    LoggingService.debug('Loading admin data - papers for review');

    final result = await _coordinatorService.getPapersForReview();

    if (result.success) {
      _reviewQueue = result.data!;
      LoggingService.debug('Loaded ${_reviewQueue.length} papers for review');
    } else {
      throw Exception(result.error);
    }
  }

  Future<void> _loadTeacherData() async {
    LoggingService.debug('Loading teacher data - drafts and submissions');

    // Load drafts and submissions in parallel
    final results = await Future.wait([
      _coordinatorService.getDrafts(),
      _coordinatorService.getUserSubmissions(),
    ]);

    final draftsResult = results[0] as QuestionPaperResult<List<QuestionPaperModel>>;
    final submissionsResult = results[1] as QuestionPaperResult<List<QuestionPaperCloudModel>>;

    if (draftsResult.success && submissionsResult.success) {
      _drafts = draftsResult.data!;
      _submissions = submissionsResult.data!;
      LoggingService.debug('Loaded ${_drafts.length} drafts and ${_submissions.length} submissions');
    } else {
      final error = draftsResult.error ?? submissionsResult.error ?? 'Unknown error';
      throw Exception(error);
    }
  }

  Future<void> _showLogoutDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.logout, color: Colors.orange[700]),
            const SizedBox(width: 8),
            const Text('Sign Out'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to sign out?'),
            const SizedBox(height: 8),
            Text(
              'You will need to sign in again to access your question papers.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.logout, size: 16),
            label: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.read<AuthBloc>().add(SignOutEvent());
    }
  }

  Future<void> _approveQuestionPaper(QuestionPaperCloudModel paper) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Question Paper'),
        content: Text('Are you sure you want to approve "${paper.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await _coordinatorService.approveQuestionPaper(paper.id);

      if (result.success) {
        _loadQuestionPapers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Question paper "${paper.title}" approved successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to approve question paper: ${result.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _rejectQuestionPaper(QuestionPaperCloudModel paper) async {
    String? rejectionReason;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Question Paper'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to reject "${paper.title}"?'),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Rejection Reason (Required)',
                hintText: 'Please provide feedback for the teacher',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              onChanged: (value) => rejectionReason = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (rejectionReason?.trim().isNotEmpty ?? false) {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a rejection reason'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true && rejectionReason != null) {
      final result = await _coordinatorService.rejectQuestionPaper(paper.id, rejectionReason!);

      if (result.success) {
        _loadQuestionPapers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Question paper "${paper.title}" rejected with feedback'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to reject question paper: ${result.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteQuestionPaper(QuestionPaperModel paper) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Question Paper'),
        content: Text('Are you sure you want to delete "${paper.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await _coordinatorService.deleteDraft(paper.id);

      if (result.success) {
        _loadQuestionPapers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Question paper deleted successfully')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete question paper: ${result.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _pullForEditing(QuestionPaperCloudModel paper) async {
    final result = await _coordinatorService.pullForEditing(paper.id);

    if (result.success) {
      _loadQuestionPapers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Question paper "${paper.title}" is now available for editing'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pull for editing: ${result.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToEdit(dynamic paper) {
    if (paper is QuestionPaperModel) {
      // Local draft - navigate to edit
      context.go('/qps/${paper.id}');
    } else if (paper is QuestionPaperCloudModel) {
      if (_isAdmin) {
        // Admin viewing submission - show view-only mode
        context.go('/qps/${paper.id}?view=true');
      } else {
        // Teacher viewing their submission
        if (paper.status == 'rejected') {
          // Can pull for editing
          _showQuestionPaperOptions(paper);
        } else {
          // View only
          context.go('/qps/${paper.id}?view=true');
        }
      }
    }
  }

  void _showQuestionPaperOptions(dynamic paper) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              paper is QuestionPaperModel ? paper.title : paper.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Admin actions
            if (_isAdmin && paper is QuestionPaperCloudModel) ...[
              ListTile(
                leading: const Icon(Icons.visibility, color: Colors.blue),
                title: const Text('View Details'),
                subtitle: const Text('View question paper details'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/qps/${paper.id}?view=true');
                },
              ),
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text('Approve'),
                subtitle: const Text('Approve this question paper'),
                onTap: () {
                  Navigator.pop(context);
                  _approveQuestionPaper(paper);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.red),
                title: const Text('Reject'),
                subtitle: const Text('Reject with feedback'),
                onTap: () {
                  Navigator.pop(context);
                  _rejectQuestionPaper(paper);
                },
              ),
            ],

            // Teacher actions
            if (!_isAdmin) ...[
              // Draft actions
              if (paper is QuestionPaperModel) ...[
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.green),
                  title: const Text('Edit'),
                  subtitle: const Text('Edit question paper'),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToEdit(paper);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete', style: TextStyle(color: Colors.red)),
                  subtitle: const Text('Permanently delete this question paper'),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteQuestionPaper(paper);
                  },
                ),
              ],

              // Submission actions
              if (paper is QuestionPaperCloudModel) ...[
                ListTile(
                  leading: Icon(
                    paper.status == 'rejected' ? Icons.edit : Icons.visibility,
                    color: paper.status == 'rejected' ? Colors.orange : Colors.blue,
                  ),
                  title: Text(paper.status == 'rejected' ? 'Pull for Editing' : 'View'),
                  subtitle: Text(
                      paper.status == 'rejected'
                          ? 'Edit and resubmit this question paper'
                          : 'View question paper details'
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    if (paper.status == 'rejected') {
                      _pullForEditing(paper);
                    } else {
                      context.go('/qps/${paper.id}?view=true');
                    }
                  },
                ),
              ],
            ],

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  List<dynamic> _getFilteredPapers() {
    if (_isAdmin) {
      return _reviewQueue;
    } else {
      switch (_selectedStatus) {
        case 'all':
          return [..._drafts, ..._submissions];
        case 'draft':
          return _drafts;
        case 'submitted':
          return _submissions.where((p) => p.status == 'submitted').toList();
        case 'approved':
          return _submissions.where((p) => p.status == 'approved').toList();
        case 'rejected':
          return _submissions.where((p) => p.status == 'rejected').toList();
        default:
          return [..._drafts, ..._submissions];
      }
    }
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

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'draft':
        return Icons.edit;
      case 'submitted':
        return Icons.send;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.description;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Authentication error: ${state.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, authState) {
        final user = authState is AuthAuthenticated ? authState.user : null;

        if (user == null) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final filteredPapers = _getFilteredPapers();

        return Scaffold(
          appBar: AppBar(
            title: Text(_isAdmin
                ? "Admin Dashboard - ${user.name ?? 'User'}"
                : "Welcome ${user.name ?? 'User'}"
            ),
            elevation: 0,
            actions: [
              // Role indicator
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isAdmin ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isAdmin ? Colors.red.withOpacity(0.3) : Colors.blue.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  _isAdmin ? 'ADMIN' : 'TEACHER',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _isAdmin ? Colors.red : Colors.blue,
                  ),
                ),
              ),
              // Logout button
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: _showLogoutDialog,
                tooltip: 'Sign Out',
              ),
            ],
          ),
          body: Column(
            children: [
              // Header section
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isAdmin ? "Papers for Review" : "Question Papers",
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "${filteredPapers.length} ${_isAdmin ? 'submissions pending approval' : 'papers found'}",
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          if (_errorMessage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _errorMessage,
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Only show create button for teachers
                    if (!_isAdmin)
                      ElevatedButton.icon(
                        onPressed: () => context.go('/qps'),
                        icon: const Icon(Icons.add),
                        label: const Text("Create New"),
                      ),
                  ],
                ),
              ),

              // Status filter chips - different for admin vs teacher
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _isAdmin
                      ? [
                    _buildFilterChip('all', 'All Submissions'),
                  ]
                      : [
                    _buildFilterChip('all', 'All'),
                    _buildFilterChip('draft', 'Drafts'),
                    _buildFilterChip('submitted', 'Submitted'),
                    _buildFilterChip('approved', 'Approved'),
                    _buildFilterChip('rejected', 'Rejected'),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Question papers list
              Expanded(
                child: _isLoading
                    ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading question papers...'),
                    ],
                  ),
                )
                    : filteredPapers.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                  onRefresh: _loadQuestionPapers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredPapers.length,
                    itemBuilder: (context, index) {
                      final paper = filteredPapers[index];
                      return _buildQuestionPaperCard(paper);
                    },
                  ),
                ),
              ),
            ],
          ),
          // Only show FAB for teachers
          floatingActionButton: !_isAdmin ? FloatingActionButton(
            onPressed: () => context.go('/qps'),
            tooltip: 'Create Question Paper',
            child: const Icon(Icons.add),
          ) : null,
        );
      },
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedStatus == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedStatus = value;
          });
        },
        selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
        checkmarkColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildQuestionPaperCard(dynamic paper) {
    // Determine if this is a draft or cloud model
    final isLocalDraft = paper is QuestionPaperModel;
    final title = isLocalDraft ? paper.title : paper.title;
    final subject = isLocalDraft ? paper.subject : paper.subject;
    final examType = isLocalDraft ? paper.examType : paper.examType;
    final status = isLocalDraft ? paper.status : paper.status;
    final createdBy = isLocalDraft ? paper.createdBy : (paper.createdByName ?? 'Unknown');
    final modifiedAt = isLocalDraft ? paper.modifiedAt : paper.submittedAt;
    // Replace the existing questionCount calculation with this:
    final questionCount = () {
      int count = 0;
      final questions = isLocalDraft
          ? (paper as QuestionPaperModel).questions
          : (paper as QuestionPaperCloudModel).questions;

      for (var questionList in questions.values) {
        count += questionList.length;
      }
      return count;
    }();
    final rejectionReason = isLocalDraft ? paper.rejectionReason : paper.rejectionReason;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _navigateToEdit(paper),
        onLongPress: () => _showQuestionPaperOptions(paper),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Status chip with menu
                  InkWell(
                    onTap: () => _showQuestionPaperOptions(paper),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getStatusColor(status).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStatusIcon(status),
                            size: 14,
                            color: _getStatusColor(status),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(status),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.more_vert,
                            size: 14,
                            color: _getStatusColor(status),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Subject and exam type
              Row(
                children: [
                  Icon(Icons.subject, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      subject,
                      style: TextStyle(color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.quiz, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    examType,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Question count and dates
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.help_outline, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          "$questionCount questions",
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        isLocalDraft ? "Modified: ${_formatDate(modifiedAt)}" : "Submitted: ${_formatDate(modifiedAt)}",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                      if (createdBy.isNotEmpty)
                        Text(
                          "By: $createdBy",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              // Rejection reason (if applicable)
              if (status == 'rejected' && rejectionReason != null && rejectionReason.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.red[700]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "Rejection reason: $rejectionReason",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Admin quick actions
              if (_isAdmin && paper is QuestionPaperCloudModel)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _approveQuestionPaper(paper),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _rejectQuestionPaper(paper),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Reject'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Tap hint for teachers
              if (!_isAdmin)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        isLocalDraft ? Icons.edit :
                        (status == 'rejected' ? Icons.edit : Icons.visibility),
                        size: 14,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isLocalDraft ? 'Tap to edit' :
                        (status == 'rejected' ? 'Tap to pull for editing' : 'Tap to view'),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[400],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Long press for options',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[400],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    String subtitle;
    IconData icon;

    if (_errorMessage.isNotEmpty) {
      message = "Failed to load question papers";
      subtitle = "Please check your connection and try again";
      icon = Icons.error_outline;
    } else if (_isAdmin) {
      message = "No submissions for review";
      subtitle = "All submitted question papers have been reviewed";
      icon = Icons.inbox_outlined;
    } else {
      message = _selectedStatus == 'all'
          ? "No question papers found"
          : "No ${_selectedStatus} papers found";
      subtitle = "Create your first question paper to get started";
      icon = Icons.description_outlined;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_errorMessage.isNotEmpty)
            ElevatedButton.icon(
              onPressed: _loadQuestionPapers,
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
            )
          else if (!_isAdmin)
            ElevatedButton.icon(
              onPressed: () => context.go('/qps'),
              icon: const Icon(Icons.add),
              label: const Text("Create Question Paper"),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return "Today";
    } else if (difference.inDays == 1) {
      return "Yesterday";
    } else if (difference.inDays < 7) {
      return "${difference.inDays} days ago";
    } else {
      return "${date.day}/${date.month}/${date.year}";
    }
  }
}