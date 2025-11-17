import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../../paper_workflow/domain/entities/question_paper_entity.dart';
import '../../../paper_workflow/domain/entities/paper_status.dart';
import '../../../paper_workflow/presentation/bloc/question_paper_bloc.dart';
import '../../../paper_workflow/presentation/widgets/paper_status_badge.dart';
import '../../../../core/infrastructure/di/injection_container.dart';

/// Admin Dashboard for viewing all question papers organized by exam and date
class AdminPapersViewPage extends StatefulWidget {
  final String tenantId;

  const AdminPapersViewPage({
    required this.tenantId,
    super.key,
  });

  @override
  State<AdminPapersViewPage> createState() => _AdminPapersViewPageState();
}

class _AdminPapersViewPageState extends State<AdminPapersViewPage> {
  late final UserStateService _userStateService;

  @override
  void initState() {
    super.initState();
    _userStateService = sl<UserStateService>();
    // Load all papers for the tenant
    context.read<QuestionPaperBloc>().add(
          const LoadAllPapersForAdmin(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<QuestionPaperBloc>().add(
                const LoadAllPapersForAdmin(),
              );
        },
        backgroundColor: AppColors.surface,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildHeader(),
            _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(UIConstants.paddingMedium),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary08,
              AppColors.secondary08,
            ],
          ),
          borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question Papers',
              style: TextStyle(
                fontSize: UIConstants.fontSizeMedium,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: UIConstants.spacing4),
            Text(
              _userStateService.currentTenantName,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: BlocBuilder<QuestionPaperBloc, QuestionPaperState>(
        builder: (context, state) {
          if (state is QuestionPaperLoading) {
            return _buildLoading();
          }

          if (state is QuestionPaperError) {
            return _buildError(state.message);
          }

          if (state is QuestionPaperLoaded) {
            final papers = state.allPapersForAdmin;
            if (papers.isEmpty) {
              return _buildEmptyState();
            }
            return _buildPapersView(papers);
          }

          return _buildEmptyState();
        },
      ),
    );
  }

  Widget _buildLoading() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading papers...',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading papers',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
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
              'No question papers',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Papers will appear once teachers submit them',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPapersView(List<QuestionPaperEntity> allPapers) {
    // Group papers by exam name
    final Map<String, List<QuestionPaperEntity>> papersByExam = {};

    for (var paper in allPapers) {
      final examName = paper.examName ?? 'Unassigned Papers';
      papersByExam.putIfAbsent(examName, () => []).add(paper);
    }

    // Sort each exam's papers by date
    papersByExam.forEach((_, papers) {
      papers.sort((a, b) {
        final dateA = a.examTimetableDate ?? a.examDate ?? DateTime(2999);
        final dateB = b.examTimetableDate ?? b.examDate ?? DateTime(2999);
        return dateA.compareTo(dateB);
      });
    });

    // Sort exams by earliest date
    final sortedExams = papersByExam.keys.toList()
      ..sort((examA, examB) {
        final firstDateA = papersByExam[examA]?.first.examTimetableDate ??
            papersByExam[examA]?.first.examDate ??
            DateTime(2999);
        final firstDateB = papersByExam[examB]?.first.examTimetableDate ??
            papersByExam[examB]?.first.examDate ??
            DateTime(2999);
        return firstDateA.compareTo(firstDateB);
      });

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.only(bottom: 16, top: 8),
            child: Text(
              'UPCOMING EXAMS',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
            ),
          ),

          // Papers organized by exam
          ...sortedExams.map((examName) {
            final papers = papersByExam[examName]!;
            return _buildExamSection(examName, papers);
          }),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildExamSection(String examName, List<QuestionPaperEntity> papers) {
    final firstPaper = papers.first;
    final examDate = firstPaper.examTimetableDate ?? firstPaper.examDate;
    final formattedDate = examDate != null
        ? '${examDate.day} ${_getMonthName(examDate.month)} ${examDate.year}'
        : 'No date';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exam header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary10,
                  AppColors.secondary10,
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  examName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Paper list
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: papers.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: Colors.grey[200],
              indent: 16,
              endIndent: 16,
            ),
            itemBuilder: (context, index) {
              final paper = papers[index];
              return _buildPaperCard(paper);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPaperCard(QuestionPaperEntity paper) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Status indicator dot
          Container(
            width: 3,
            height: 60,
            decoration: BoxDecoration(
              color: _getStatusColor(paper.status),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),

          // Paper info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paper.title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    PaperStatusBadge(status: paper.status),
                    const SizedBox(width: 12),
                    Text(
                      'By ${paper.createdBy ?? 'Unknown'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // View icon
          Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Colors.grey[400],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(PaperStatus status) {
    switch (status) {
      case PaperStatus.approved:
        return Colors.green;
      case PaperStatus.draft:
        return Colors.orange;
      case PaperStatus.rejected:
        return Colors.red;
      case PaperStatus.submitted:
        return Colors.blue;
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month - 1];
  }
}
