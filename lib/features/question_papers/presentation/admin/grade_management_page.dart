// features/question_papers/presentation/admin/pages/grade_management_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:papercraft/features/question_papers/presentation/admin/widgets/grade_management_widget.dart';
import '../../../../../core/infrastructure/di/injection_container.dart';
import '../../../../../core/presentation/constants/app_colors.dart';
import '../bloc/grade_bloc.dart';

class GradeManagementPage extends StatelessWidget {
  const GradeManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manage Grades'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: BlocProvider(
        create: (context) => GradeBloc(repository: sl()),
        child: const GradeManagementWidget(),
      ),
    );
  }
}