// features/catalog/presentation/pages/exam_type_management_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../bloc/exam_type_bloc.dart';
import '../bloc/subject_bloc.dart';
import '../widgets/exam_type_management_widget.dart';

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
      body: MultiBlocProvider(
        providers: [
          BlocProvider(create: (context) => sl<ExamTypeBloc>()),
          BlocProvider(create: (context) => sl<SubjectBloc>()),
        ],
        child: const ExamTypeManagementWidget(),
      ),
    );
  }
}