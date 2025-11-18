import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../authentication/domain/entities/user_entity.dart';
import '../../../authentication/domain/entities/user_role.dart';
import '../../../paper_workflow/presentation/bloc/reviewer_assignment_bloc.dart';

class ReviewerGradeAssignmentWidget extends StatefulWidget {
  final String tenantId;
  final List<UserEntity> allUsers;

  const ReviewerGradeAssignmentWidget({
    super.key,
    required this.tenantId,
    required this.allUsers,
  });

  @override
  State<ReviewerGradeAssignmentWidget> createState() =>
      _ReviewerGradeAssignmentWidgetState();
}

class _ReviewerGradeAssignmentWidgetState
    extends State<ReviewerGradeAssignmentWidget> {
  @override
  void initState() {
    super.initState();
    context.read<ReviewerAssignmentBloc>().add(LoadReviewerAssignments(widget.tenantId));
  }

  @override
  Widget build(BuildContext context) {
    // Filter only reviewers
    final reviewers = widget.allUsers
        .where((u) =>
            u.role == UserRole.primary_reviewer ||
            u.role == UserRole.secondary_reviewer)
        .toList();

    if (reviewers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(UIConstants.paddingMedium),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_outline,
                  size: 48, color: AppColors.textTertiary),
              SizedBox(height: UIConstants.spacing16),
              Text('No reviewers in tenant',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  )),
            ],
          ),
        ),
      );
    }

    return BlocListener<ReviewerAssignmentBloc, ReviewerAssignmentState>(
      listener: _handleStateChanges,
      child: Padding(
        padding: const EdgeInsets.all(UIConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            SizedBox(height: UIConstants.spacing20),
            const Divider(),
            SizedBox(height: UIConstants.spacing20),
            Expanded(
              child: BlocBuilder<ReviewerAssignmentBloc, ReviewerAssignmentState>(
                builder: (context, state) {
                  if (state is ReviewerAssignmentLoading) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          SizedBox(height: UIConstants.spacing16),
                          Text(
                            state.message ?? 'Loading assignments...',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    );
                  }

                  if (state is ReviewerAssignmentError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              size: 48, color: AppColors.error),
                          SizedBox(height: UIConstants.spacing16),
                          Text(state.message,
                              style: TextStyle(color: AppColors.error),
                              textAlign: TextAlign.center),
                        ],
                      ),
                    );
                  }

                  if (state is ReviewerAssignmentLoaded) {
                    return ListView.builder(
                      itemCount: reviewers.length,
                      itemBuilder: (context, index) {
                        final reviewer = reviewers[index];
                        final assignment = state.assignments
                            .firstWhere(
                              (a) => a.reviewerId == reviewer.id,
                              orElse: () => null,
                            );

                        return _buildReviewerCard(reviewer, assignment);
                      },
                    );
                  }

                  return const Center(child: Text('Loading...'));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(UIConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.primary10,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        border: Border.all(color: AppColors.primary20),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Grade Assignment',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: UIConstants.spacing4),
                Text(
                  'Assign grade ranges (1-12) to reviewers. They will only see papers for their assigned grades.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewerCard(UserEntity reviewer, dynamic assignment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(reviewer.role).withValues(alpha: 0.2),
          child: Text(
            reviewer.displayName.isNotEmpty
                ? reviewer.displayName[0].toUpperCase()
                : 'R',
            style: TextStyle(
              color: _getRoleColor(reviewer.role),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          reviewer.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reviewer.role.displayName,
                style: TextStyle(color: _getRoleColor(reviewer.role))),
            if (assignment != null)
              Text(
                'Grades ${assignment.gradeMin}-${assignment.gradeMax}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.success,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        trailing: ElevatedButton.icon(
          onPressed: () => _showGradeAssignmentDialog(reviewer, assignment),
          icon: const Icon(Icons.edit, size: 16),
          label: Text(assignment == null ? 'Assign' : 'Edit'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
        isThreeLine: assignment != null,
      ),
    );
  }

  void _showGradeAssignmentDialog(UserEntity reviewer, dynamic assignment) {
    final minController = TextEditingController(
      text: assignment?.gradeMin.toString() ?? '1',
    );
    final maxController = TextEditingController(
      text: assignment?.gradeMax.toString() ?? '12',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assign Grades to ${reviewer.displayName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: minController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Grade Min (1-12)',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: UIConstants.spacing16),
            TextField(
              controller: maxController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Grade Max (1-12)',
                border: OutlineInputBorder(),
              ),
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
              final gradeMin = int.tryParse(minController.text) ?? 1;
              final gradeMax = int.tryParse(maxController.text) ?? 12;

              if (gradeMin < 1 || gradeMax > 12 || gradeMin > gradeMax) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invalid grade range'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);

              if (assignment == null) {
                context.read<ReviewerAssignmentBloc>().add(
                      CreateReviewerAssignment(
                        tenantId: widget.tenantId,
                        reviewerId: reviewer.id,
                        gradeMin: gradeMin,
                        gradeMax: gradeMax,
                      ),
                    );
              } else {
                context.read<ReviewerAssignmentBloc>().add(
                      UpdateReviewerAssignment(
                        assignmentId: assignment.id,
                        gradeMin: gradeMin,
                        gradeMax: gradeMax,
                      ),
                    );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _handleStateChanges(BuildContext context, ReviewerAssignmentState state) {
    if (state is ReviewerAssignmentSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.primary_reviewer:
        return AppColors.primary;
      case UserRole.secondary_reviewer:
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }
}
