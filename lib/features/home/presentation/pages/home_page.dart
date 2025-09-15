// features/home/presentation/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../../authentication/domain/entities/user_role.dart';
import '../../../authentication/presentation/bloc/auth_bloc.dart';
import '../../../authentication/presentation/bloc/auth_state.dart';
import '../../../question_papers/domain/entities/question_paper_entity.dart';
import '../../../question_papers/domain/entities/paper_status.dart';
import '../../../question_papers/presentation/bloc/question_paper_bloc.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _selectedFilter = 'all';
  bool _isAdmin = false;

  // Helper method to get role display name
  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'ADMIN';
      case UserRole.teacher:
        return 'TEACHER';
      default:
        return 'USER';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, authState) {
        if (authState is AuthAuthenticated) {
          setState(() {
            _isAdmin = authState.user.role == UserRole.admin ||
                authState.user.role == UserRole.teacher;
          });
        }
      },
      builder: (context, authState) {
        if (authState is! AuthAuthenticated) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authState.user;

        // Wrap the entire content with BlocProvider
        return BlocProvider(
          create: (context) => QuestionPaperBloc(
            saveDraftUseCase: sl(),
            submitPaperUseCase: sl(),
            getDraftsUseCase: sl(),
            pullForEditingUseCase: sl(),
            getUserSubmissionsUseCase: sl(),
            approvePaperUseCase: sl(),
            rejectPaperUseCase: sl(),
            getPapersForReviewUseCase: sl(),
            deleteDraftUseCase: sl(),
            getPaperByIdUseCase: sl(),
          )..add(const LoadDrafts())..add(const LoadUserSubmissions()),
          child: Builder(
            builder: (context) {
              // Load admin data if user is admin
              if (_isAdmin) {
                context.read<QuestionPaperBloc>().add(const LoadPapersForReview());
              }

              return Scaffold(
                appBar: AppBar(
                  title: Text(_isAdmin ? 'Admin Dashboard' : 'Question Papers'),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () => _refreshData(context),
                    ),
                  ],
                ),
                body: Column(
                  children: [
                    _buildHeader(context, user),
                    _buildFilterChips(),
                    Expanded(child: _buildContent()),
                  ],
                ),
                floatingActionButton: !_isAdmin ? FloatingActionButton(
                  onPressed: () => context.go('/question-papers/create'),
                  child: const Icon(Icons.add),
                  tooltip: 'Create Question Paper',
                ) : null,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, dynamic user) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome ${user.fullName}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _isAdmin ? 'Admin Dashboard' : 'Manage your question papers',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isAdmin ? Colors.red.shade100 : Colors.blue.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getRoleDisplayName(user.role),
              style: TextStyle(
                color: _isAdmin ? Colors.red.shade700 : Colors.blue.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = _isAdmin
        ? ['all', 'submitted', 'approved', 'rejected']
        : ['all', 'drafts', 'submitted', 'approved', 'rejected'];

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: filters.map((filter) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            label: Text(_getFilterLabel(filter)),
            selected: _selectedFilter == filter,
            onSelected: (selected) {
              setState(() {
                _selectedFilter = filter;
              });
            },
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildContent() {
    return BlocBuilder<QuestionPaperBloc, QuestionPaperState>(
      builder: (context, state) {
        if (state is QuestionPaperLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is QuestionPaperError) {
          return _buildErrorState(state.message);
        }

        if (state is QuestionPaperLoaded) {
          final papers = _getFilteredPapers(state);
          return _buildPapersList(papers);
        }

        return _buildEmptyState();
      },
    );
  }

  Widget _buildPapersList(List<QuestionPaperEntity> papers) {
    if (papers.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () => _refreshData(context),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: papers.length,
        itemBuilder: (context, index) {
          final paper = papers[index];
          return _buildPaperCard(paper);
        },
      ),
    );
  }

  Widget _buildPaperCard(QuestionPaperEntity paper) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToPaper(paper),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      paper.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildStatusChip(paper.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.subject, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(paper.subject),
                  const SizedBox(width: 16),
                  Icon(Icons.quiz, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(paper.examType),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.help_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('${paper.totalQuestions} questions'),
                  const Spacer(),
                  Text(
                    _formatDate(paper.modifiedAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
              if (paper.rejectionReason != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Rejected: ${paper.rejectionReason}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_isAdmin && paper.status.isSubmitted) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _approvePaper(paper.id),
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
                        onPressed: () => _rejectPaper(paper.id),
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
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(PaperStatus status) {
    Color color;
    switch (status) {
      case PaperStatus.draft:
        color = Colors.orange;
        break;
      case PaperStatus.submitted:
        color = Colors.blue;
        break;
      case PaperStatus.approved:
        color = Colors.green;
        break;
      case PaperStatus.rejected:
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.displayName.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color is MaterialColor ? color.shade700 : color,
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _refreshData(context),
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _getEmptyStateTitle(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getEmptyStateSubtitle(),
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          if (!_isAdmin) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/question-papers/create'),
              icon: const Icon(Icons.add),
              label: const Text('Create Question Paper'),
            ),
          ],
        ],
      ),
    );
  }

  List<QuestionPaperEntity> _getFilteredPapers(QuestionPaperLoaded state) {
    if (_isAdmin) {
      switch (_selectedFilter) {
        case 'submitted':
          return state.papersForReview;
        case 'approved':
          return [...state.submissions, ...state.papersForReview]
              .where((p) => p.status.isApproved).toList();
        case 'rejected':
          return [...state.submissions, ...state.papersForReview]
              .where((p) => p.status.isRejected).toList();
        default:
          return [...state.submissions, ...state.papersForReview];
      }
    } else {
      switch (_selectedFilter) {
        case 'drafts':
          return state.drafts;
        case 'submitted':
          return state.submissions.where((p) => p.status.isSubmitted).toList();
        case 'approved':
          return state.submissions.where((p) => p.status.isApproved).toList();
        case 'rejected':
          return state.submissions.where((p) => p.status.isRejected).toList();
        default:
          return [...state.drafts, ...state.submissions];
      }
    }
  }

  String _getFilterLabel(String filter) {
    switch (filter) {
      case 'all': return 'All';
      case 'drafts': return 'Drafts';
      case 'submitted': return 'Submitted';
      case 'approved': return 'Approved';
      case 'rejected': return 'Rejected';
      default: return filter.toUpperCase();
    }
  }

  String _getEmptyStateTitle() {
    if (_isAdmin) {
      return _selectedFilter == 'submitted'
          ? 'No papers to review'
          : 'No papers found';
    } else {
      return _selectedFilter == 'drafts'
          ? 'No drafts yet'
          : 'No papers found';
    }
  }

  String _getEmptyStateSubtitle() {
    if (_isAdmin) {
      return 'All submitted papers have been reviewed';
    } else {
      return _selectedFilter == 'drafts'
          ? 'Create your first question paper to get started'
          : 'You haven\'t created any question papers yet';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _refreshData(BuildContext context) async {
    final bloc = context.read<QuestionPaperBloc>();
    bloc.add(const LoadDrafts());
    bloc.add(const LoadUserSubmissions());
    if (_isAdmin) {
      bloc.add(const LoadPapersForReview());
    }
  }

  void _navigateToPaper(QuestionPaperEntity paper) {
    if (paper.status.isDraft) {
      context.go('/question-papers/edit/${paper.id}');
    } else {
      context.go('/question-papers/view/${paper.id}');
    }
  }

  void _approvePaper(String paperId) {
    context.read<QuestionPaperBloc>().add(ApprovePaper(paperId));
  }

  Future<void> _rejectPaper(String paperId) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _RejectPaperDialog(),
    );

    if (reason != null && reason.isNotEmpty) {
      context.read<QuestionPaperBloc>().add(RejectPaper(paperId, reason));
    }
  }
}

class _RejectPaperDialog extends StatefulWidget {
  @override
  _RejectPaperDialogState createState() => _RejectPaperDialogState();
}

class _RejectPaperDialogState extends State<_RejectPaperDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject Question Paper'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Please provide a reason for rejection:'),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Rejection Reason',
              hintText: 'Enter feedback for the teacher',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            autofocus: true,
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
            if (_controller.text.trim().isNotEmpty) {
              Navigator.pop(context, _controller.text.trim());
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}