import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../authentication/presentation/bloc/auth_bloc.dart';
import '../../../authentication/presentation/bloc/auth_event.dart';
import '../../../authentication/presentation/bloc/auth_state.dart';
import '../../../qps/services/question_paper_storage_service.dart';
import '../../../qps/data/models/question_paper_model.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final QuestionPaperStorageService _storageService = QuestionPaperStorageService();
  List<QuestionPaperModel> _questionPapers = [];
  bool _isLoading = true;
  String _selectedStatus = 'all';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadQuestionPapers();
  }

  Future<void> _loadQuestionPapers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      List<QuestionPaperModel> papers;
      if (_selectedStatus == 'all') {
        papers = await _storageService.getAllQuestionPapers();
      } else {
        papers = await _storageService.getQuestionPapersByStatus(_selectedStatus);
      }

      setState(() {
        _questionPapers = papers;
        _isLoading = false;
      });

      print('Successfully loaded ${papers.length} question papers');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading question papers: $e';
      });

      print('Error loading question papers: $e');

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
      // Trigger sign out event - router will handle navigation automatically
      context.read<AuthBloc>().add(SignOutEvent());
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
      final success = await _storageService.deleteQuestionPaper(paper.id, paper.status);
      if (success) {
        _loadQuestionPapers(); // Refresh the list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Question paper deleted successfully')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete question paper'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text('Are you sure you want to delete all question papers? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _storageService.clearAllQuestionPapers();
      if (success) {
        _loadQuestionPapers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All question papers cleared successfully')),
          );
        }
      }
    }
  }

  void _navigateToEdit(QuestionPaperModel paper) {
    // Navigate to the edit screen using the question paper ID
    context.go('/qps/${paper.id}');
  }

  void _showQuestionPaperOptions(QuestionPaperModel paper) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              paper.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Edit option
            ListTile(
              leading: Icon(
                paper.status == 'approved' ? Icons.visibility : Icons.edit,
                color: paper.status == 'approved' ? Colors.blue : Colors.green,
              ),
              title: Text(paper.status == 'approved' ? 'View' : 'Edit'),
              subtitle: Text(
                paper.status == 'approved'
                    ? 'View question paper details'
                    : 'Edit question paper',
              ),
              onTap: () {
                Navigator.pop(context);
                _navigateToEdit(paper);
              },
            ),

            // Duplicate option
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.orange),
              title: const Text('Duplicate'),
              subtitle: const Text('Create a copy of this question paper'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Duplicate feature coming soon')),
                );
              },
            ),

            // Delete option
            if (paper.status != 'approved') // Don't allow deleting approved papers
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                subtitle: const Text('Permanently delete this question paper'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteQuestionPaper(paper);
                },
              ),

            const SizedBox(height: 8),
          ],
        ),
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
        // Router handles navigation automatically, so we just handle loading states
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
        // Get user from auth state instead of widget parameter
        final user = authState is AuthAuthenticated ? authState.user : null;

        if (user == null) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text("Welcome ${user.name ?? 'User'}"),
            elevation: 0,
            actions: [
              // Logout button
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: _showLogoutDialog,
                tooltip: 'Sign Out',
              ),
              // Debug: Show storage stats
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () async {
                  final stats = await _storageService.getStorageStats();
                  if (mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Storage Statistics'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Drafts: ${stats['draft'] ?? 0}'),
                            Text('Submitted: ${stats['submitted'] ?? 0}'),
                            Text('Approved: ${stats['approved'] ?? 0}'),
                            Text('Rejected: ${stats['rejected'] ?? 0}'),
                            const Divider(),
                            Text('Total: ${stats.values.fold<int>(0, (sum, count) => sum + count)}'),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                          if (stats.values.fold<int>(0, (sum, count) => sum + count) > 0)
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _clearAllData();
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              child: const Text('Clear All'),
                            ),
                        ],
                      ),
                    );
                  }
                },
                tooltip: 'Storage Info',
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
                            "Question Papers",
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "${_questionPapers.length} papers found",
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          // Show error message if any
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
                    ElevatedButton.icon(
                      onPressed: () => context.go('/qps'),
                      icon: const Icon(Icons.add),
                      label: const Text("Create New"),
                    ),
                  ],
                ),
              ),

              // Status filter chips
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
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
                    : _questionPapers.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                  onRefresh: _loadQuestionPapers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _questionPapers.length,
                    itemBuilder: (context, index) {
                      final paper = _questionPapers[index];
                      return _buildQuestionPaperCard(paper);
                    },
                  ),
                ),
              ),
            ],
          ),
          // Add floating action button for quick access
          floatingActionButton: FloatingActionButton(
            onPressed: () => context.go('/qps'),
            tooltip: 'Create Question Paper',
            child: const Icon(Icons.add),
          ),
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
          _loadQuestionPapers();
        },
        selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
        checkmarkColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildQuestionPaperCard(QuestionPaperModel paper) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _navigateToEdit(paper), // Navigate to edit when tapped
        onLongPress: () => _showQuestionPaperOptions(paper), // Show options on long press
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
                      paper.title,
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
                        color: _getStatusColor(paper.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getStatusColor(paper.status).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStatusIcon(paper.status),
                            size: 14,
                            color: _getStatusColor(paper.status),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            paper.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(paper.status),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.more_vert,
                            size: 14,
                            color: _getStatusColor(paper.status),
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
                      paper.subject,
                      style: TextStyle(color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.quiz, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    paper.examType,
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
                          "${paper.questions.values.fold<int>(0, (sum, list) => sum + list.length)} questions",
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "Modified: ${_formatDate(paper.modifiedAt)}",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                      if (paper.createdBy.isNotEmpty)
                        Text(
                          "By: ${paper.createdBy}",
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
              if (paper.status == 'rejected' && paper.rejectionReason != null)
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
                          "Rejection reason: ${paper.rejectionReason}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Tap hint
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    paper.status == 'approved' ? Icons.visibility : Icons.edit,
                    size: 14,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    paper.status == 'approved' ? 'Tap to view' : 'Tap to edit',
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    String subtitle;

    if (_errorMessage.isNotEmpty) {
      message = "Failed to load question papers";
      subtitle = "Please check your connection and try again";
    } else {
      message = _selectedStatus == 'all'
          ? "No question papers found"
          : "No ${_selectedStatus} papers found";
      subtitle = "Create your first question paper to get started";
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _errorMessage.isNotEmpty ? Icons.error_outline : Icons.description_outlined,
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
          else
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