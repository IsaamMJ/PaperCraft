// features/question_papers/pages/admin/pages/subject_management_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/infrastructure/di/injection_container.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../bloc/subject_bloc.dart';
import '../widgets/subject_management_widget.dart';

class SubjectManagementPage extends StatelessWidget {
  const SubjectManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manage Subjects'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: BlocProvider(
        create: (context) => sl<SubjectBloc>(),
        child: const SubjectManagementWidget(),
      ),
    );
  }
}