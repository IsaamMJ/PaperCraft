// features/question_papers/pages/admin/pages/user_management_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../../paper_workflow/presentation/bloc/user_management_bloc.dart';
import '../../../paper_workflow/presentation/bloc/reviewer_assignment_bloc.dart';
import '../widgets/user_management_widget.dart';
import '../widgets/reviewer_grade_assignment_widget.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manage Users'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Users'),
            Tab(text: 'Reviewer Assignments'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Users tab
          BlocProvider(
            create: (context) => UserManagementBloc(),
            child: const UserManagementWidget(),
          ),
          // Reviewer Assignments tab
          BlocProvider(
            create: (context) => sl<ReviewerAssignmentBloc>(),
            child: _buildReviewerAssignmentTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewerAssignmentTab() {
    // Get the tenant ID from the user state service
    final userStateService = sl<UserStateService>();
    final tenantId = userStateService.currentTenantId;

    if (tenantId == null) {
      return Center(
        child: Text(
          'Tenant information not available',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    // Get users to pass to the reviewer assignment widget
    return BlocBuilder<UserManagementBloc, UserManagementState>(
      builder: (context, state) {
        if (state is UserManagementLoaded) {
          return ReviewerGradeAssignmentWidget(
            tenantId: tenantId,
            allUsers: state.users,
          );
        }

        // If users haven't been loaded yet, load them
        if (state is UserManagementInitial) {
          context.read<UserManagementBloc>().add(const LoadUsers());
          return const Center(child: CircularProgressIndicator());
        }

        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}