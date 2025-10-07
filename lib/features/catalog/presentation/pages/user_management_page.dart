// features/question_papers/pages/admin/pages/user_management_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/constants/app_colors.dart';
import '../../../paper_workflow/presentation/bloc/user_management_bloc.dart';
import '../widgets/user_management_widget.dart';

class UserManagementPage extends StatelessWidget {
  const UserManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manage Users'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: BlocProvider(
        create: (context) => UserManagementBloc(),
        child: const UserManagementWidget(),
      ),
    );
  }
}