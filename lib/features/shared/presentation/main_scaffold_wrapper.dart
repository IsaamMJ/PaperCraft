import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../admin/presentation/pages/admin_dashboard_page.dart';
import '../../admin/presentation/pages/exams_dashboard_page.dart';
import '../../admin/presentation/pages/settings_screen.dart';
import '../../authentication/domain/services/user_state_service.dart';
import '../../home/presentation/pages/home_page.dart';
import '../../paper_workflow/presentation/bloc/shared_bloc_provider.dart';
import '../../question_bank/presentation/pages/question_bank_page.dart';
import '../../timetable/presentation/bloc/exam_timetable_bloc.dart';
import '../../../core/infrastructure/di/injection_container.dart';
import 'main_scaffold_screen.dart';

class MainScaffoldWrapper extends StatefulWidget {
  const MainScaffoldWrapper({super.key});

  @override
  State<MainScaffoldWrapper> createState() => _MainScaffoldWrapperState();
}

class _MainScaffoldWrapperState extends State<MainScaffoldWrapper> {
  @override
  void initState() {
    super.initState();
    // Initialization check moved to AppRouter.redirect() for clean architecture
    // No widget-level redirect logic needed anymore
  }

  @override
  Widget build(BuildContext context) {
    final userStateService = GetIt.instance<UserStateService>();
    final tenantId = userStateService.currentTenantId ?? '';
    final isReviewer = userStateService.isReviewer;

    print('[DEBUG SCAFFOLD WRAPPER] Building scaffold - isReviewer: $isReviewer');

    // Reviewers only see papers for review (admin dashboard)
    // Admins see full admin pages
    final adminPages = isReviewer
        ? [
            SharedBlocProvider(child: const AdminDashboardPage()),
          ]
        : [
            SharedBlocProvider(child: const AdminDashboardPage()),
            SharedBlocProvider(child: const QuestionBankPage()),
            ExamsDashboardPage(tenantId: tenantId),
            SharedBlocProvider(child: const SettingsPage()),
          ];

    final teacherPages = [
      SharedBlocProvider(child: const HomePage()),
      SharedBlocProvider(child: const QuestionBankPage()),
    ];

    return MainScaffoldPage(
      userStateService: userStateService,
      adminPages: adminPages,
      teacherPages: teacherPages,
      isReviewer: isReviewer,
    );
  }
}
