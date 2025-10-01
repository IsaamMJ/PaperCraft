// features/question_papers/presentation/admin/pages/exam_type_management_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:papercraft/features/question_papers/presentation/admin/widgets/exam_type_management_widget.dart';
import '../../../../../core/infrastructure/di/injection_container.dart';
import '../../../../../core/presentation/constants/app_colors.dart';
import '../bloc/exam_type_bloc.dart';

class ExamTypeManagementPage extends StatelessWidget {
  const ExamTypeManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manage Exam Types'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: BlocProvider(
        create: (context) => sl<ExamTypeBloc>(),
        child: const ExamTypeManagementWidget(),
      ),
    );
  }
}