// features/question_papers/presentation/admin/pages/user_management_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:papercraft/features/question_papers/presentation/admin/widgets/user_management_widget.dart';

import '../../../../../core/presentation/constants/app_colors.dart';
import '../bloc/user_management_bloc.dart';

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