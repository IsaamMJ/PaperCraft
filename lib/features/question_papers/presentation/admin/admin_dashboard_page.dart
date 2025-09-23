// features/question_papers/presentation/admin/admin_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../../core/presentation/routes/app_routes.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../domain/entities/question_paper_entity.dart';
import '../../domain/entities/paper_status.dart';
import '../bloc/question_paper_bloc.dart';
import '../widgets/shared/paper_list_tile.dart';
import '../widgets/shared/admin_action_buttons.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> with TickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _selectedSubject = '';
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkAdminStatus();
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _checkAdminStatus() async {
    final isAdmin = sl<UserStateService>().isAdmin;
    if (mounted) {
      setState(() => _isAdmin = isAdmin);

      if (!isAdmin) {
        // Redirect non-admin users
        context.go('/home');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin access required'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _loadInitialData() {
    context.read<QuestionPaperBloc>().add(const LoadAllPapersForAdmin());
  }

  void _handleApprove(String paperId) async {
    final confirm = await _showConfirmDialog(
      title: 'Approve Paper',
      content: 'Are you sure you want to approve this paper?',
      confirmText: 'Approve',
      confirmColor: Colors.green,
    );

    if (confirm == true && mounted) {
      context.read<QuestionPaperBloc>().add(ApprovePaper(paperId));
    }
  }

  void _handleReject(String paperId, String paperTitle) async {
    showDialog(
      context: context,
      builder: (context) => RejectPaperDialog(
        paperTitle: paperTitle,
        onReject: (reason) {
          context.read<QuestionPaperBloc>().add(RejectPaper(paperId, reason));
        },
      ),
    );
  }

  void _handleViewDetails(String paperId) {
    context.go(AppRoutes.questionPaperViewWithId(paperId));
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
    required String confirmText,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  List<QuestionPaperEntity> _filterPapers(List<QuestionPaperEntity> papers) {
    return papers.where((paper) {
      final matchesSearch = _searchQuery.isEmpty ||
          paper.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          paper.createdBy.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesSubject = _selectedSubject.isEmpty ||
          paper.subject == _selectedSubject;

      return matchesSearch && matchesSubject;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.pending_actions),
              text: 'Pending Review',
            ),
            Tab(
              icon: Icon(Icons.list_alt),
              text: 'All Papers',
            ),
            Tab(
              icon: Icon(Icons.analytics),
              text: 'Analytics',
            ),
          ],
        ),
      ),
      body: BlocListener<QuestionPaperBloc, QuestionPaperState>(
        listener: (context, state) {
          if (state is QuestionPaperSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
            // Refresh data after successful action
            _loadInitialData();
          } else if (state is QuestionPaperError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: Column(
          children: [
            _buildSearchAndFilters(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPendingReviewTab(),
                  _buildAllPapersTab(),
                  _buildAnalyticsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go(AppRoutes.questionPaperCreate),
        backgroundColor: Colors.blue.shade600,
        tooltip: 'Create New Paper',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
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
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search papers by title or creator...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedSubject.isEmpty ? null : _selectedSubject,
                    hint: const Text('Subject'),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('All Subjects')),
                      DropdownMenuItem(value: 'Mathematics', child: Text('Mathematics')),
                      DropdownMenuItem(value: 'Physics', child: Text('Physics')),
                      DropdownMenuItem(value: 'Chemistry', child: Text('Chemistry')),
                    ],
                    onChanged: (value) => setState(() => _selectedSubject = value ?? ''),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingReviewTab() {
    return BlocBuilder<QuestionPaperBloc, QuestionPaperState>(
      builder: (context, state) {
        if (state is QuestionPaperLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is QuestionPaperLoaded) {
          final pendingPapers = _filterPapers(state.papersForReview);

          if (pendingPapers.isEmpty) {
            return _buildEmptyState(
              icon: Icons.inbox_outlined,
              title: 'No Pending Reviews',
              subtitle: _searchQuery.isNotEmpty || _selectedSubject.isNotEmpty
                  ? 'No papers match your current filters'
                  : 'All papers have been reviewed',
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _loadInitialData();
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: pendingPapers.length,
              itemBuilder: (context, index) {
                final paper = pendingPapers[index];
                return PaperListTile(
                  paper: paper,
                  showCreator: true,
                  onTap: () => _handleViewDetails(paper.id),
                  trailing: AdminActionButtons(
                    paper: paper,
                    isCompact: true,
                    onApprove: paper.status.isSubmitted ? () => _handleApprove(paper.id) : null,
                    onReject: paper.status.isSubmitted ? () => _handleReject(paper.id, paper.title) : null,
                    onViewDetails: () => _handleViewDetails(paper.id),
                  ),
                );
              },
            ),
          );
        }

        if (state is QuestionPaperError) {
          return _buildErrorState(state.message);
        }

        return _buildEmptyState(
          icon: Icons.description_outlined,
          title: 'No Data',
          subtitle: 'Pull to refresh',
        );
      },
    );
  }

  Widget _buildAllPapersTab() {
    return BlocBuilder<QuestionPaperBloc, QuestionPaperState>(
      builder: (context, state) {
        if (state is QuestionPaperLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is QuestionPaperLoaded) {
          // For admin, only show papers for review (these are all submitted papers from all users)
          final allPapers = state.allPapersForAdmin;

          final filteredPapers = _filterPapers(allPapers);

          if (filteredPapers.isEmpty) {
            return _buildEmptyState(
              icon: Icons.description_outlined,
              title: 'No Papers Found',
              subtitle: _searchQuery.isNotEmpty || _selectedSubject.isNotEmpty
                  ? 'No papers match your current filters'
                  : 'No papers have been submitted yet',
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _loadInitialData();
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: filteredPapers.length,
              itemBuilder: (context, index) {
                final paper = filteredPapers[index];
                return PaperListTile(
                  paper: paper,
                  showCreator: true,
                  onTap: () => _handleViewDetails(paper.id),
                  trailing: AdminActionButtons(
                    paper: paper,
                    isCompact: true,
                    onApprove: paper.status.isSubmitted ? () => _handleApprove(paper.id) : null,
                    onReject: paper.status.isSubmitted ? () => _handleReject(paper.id, paper.title) : null,
                    onViewDetails: () => _handleViewDetails(paper.id),
                  ),
                );
              },
            ),
          );
        }

        if (state is QuestionPaperError) {
          return _buildErrorState(state.message);
        }

        return _buildEmptyState(
          icon: Icons.description_outlined,
          title: 'No Data',
          subtitle: 'Pull to refresh',
        );
      },
    );
  }

  Widget _buildAnalyticsTab() {
    return BlocBuilder<QuestionPaperBloc, QuestionPaperState>(
      builder: (context, state) {
        if (state is QuestionPaperLoaded) {
          return _buildAnalyticsContent(state);
        }

        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Analytics will be displayed here'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsContent(QuestionPaperLoaded state) {


    final allPapers = <QuestionPaperEntity>[
      ...state.submissions,
      ...state.papersForReview,
    ];

    final uniquePapers = <String, QuestionPaperEntity>{};
    for (final paper in allPapers) {
      uniquePapers[paper.id] = paper;
    }

    final papers = state.papersForReview;
    final totalPapers = papers.length;
    final pendingCount = papers.where((p) => p.status.isSubmitted).length;
    final approvedCount = papers.where((p) => p.status.isApproved).length;
    final rejectedCount = papers.where((p) => p.status.isRejected).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paper Statistics',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),

          // Statistics Cards
          Row(
            children: [
              Expanded(child: _buildStatCard('Total Papers', totalPapers, Colors.blue)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard('Pending', pendingCount, Colors.orange)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildStatCard('Approved', approvedCount, Colors.green)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard('Rejected', rejectedCount, Colors.red)),
            ],
          ),

          if (totalPapers > 0) ...[
            const SizedBox(height: 24),
            Text(
              'Subject Distribution',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            _buildSubjectDistribution(papers),

            const SizedBox(height: 24),
            Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            _buildRecentActivity(papers),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int value, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectDistribution(List<QuestionPaperEntity> papers) {
    final subjectCounts = <String, int>{};
    for (final paper in papers) {
      subjectCounts[paper.subject] = (subjectCounts[paper.subject] ?? 0) + 1;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: subjectCounts.entries.map((entry) {
            final percentage = (entry.value / papers.length * 100).round();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(entry.key),
                  ),
                  Expanded(
                    flex: 3,
                    child: LinearProgressIndicator(
                      value: entry.value / papers.length,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${entry.value} ($percentage%)'),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildRecentActivity(List<QuestionPaperEntity> papers) {
    final recentPapers = papers.where((p) =>
    p.submittedAt != null || p.reviewedAt != null).toList();
    recentPapers.sort((a, b) {
      final aDate = a.reviewedAt ?? a.submittedAt ?? a.createdAt;
      final bDate = b.reviewedAt ?? b.submittedAt ?? b.createdAt;
      return bDate.compareTo(aDate);
    });

    return Card(
      child: Column(
        children: recentPapers.take(5).map((paper) {
          return ListTile(
            leading: Icon(
              paper.status.isApproved ? Icons.check_circle :
              paper.status.isRejected ? Icons.cancel :
              Icons.pending,
              color: paper.status.isApproved ? Colors.green :
              paper.status.isRejected ? Colors.red :
              Colors.orange,
            ),
            title: Text(paper.title),
            subtitle: Text('${paper.subject} • ${paper.createdBy}'),
            trailing: Text(_getActivityDate(paper)),
          );
        }).toList(),
      ),
    );
  }

  String _getActivityDate(QuestionPaperEntity paper) {
    final date = paper.reviewedAt ?? paper.submittedAt ?? paper.createdAt;
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Error',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadInitialData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// RejectPaperDialog Widget
class RejectPaperDialog extends StatefulWidget {
  final String paperTitle;
  final Function(String reason) onReject;

  const RejectPaperDialog({
    super.key,
    required this.paperTitle,
    required this.onReject,
  });

  @override
  State<RejectPaperDialog> createState() => _RejectPaperDialogState();
}

class _RejectPaperDialogState extends State<RejectPaperDialog> {
  final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject Paper'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Paper: ${widget.paperTitle}'),
          const SizedBox(height: 16),
          const Text('Please provide a reason for rejection:'),
          const SizedBox(height: 8),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(
              hintText: 'Enter rejection reason...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_reasonController.text.trim().isNotEmpty) {
              widget.onReject(_reasonController.text.trim());
              Navigator.of(context).pop();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}