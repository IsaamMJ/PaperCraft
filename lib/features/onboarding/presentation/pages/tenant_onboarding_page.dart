import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../../core/presentation/routes/app_routes.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../data/template/school_templates.dart';
import '../widgets/school_type_selector.dart';
import 'data_preview_screen.dart';

class TenantOnboardingPage extends StatefulWidget {
  final bool isTeacherOnboarding;

  const TenantOnboardingPage({super.key, this.isTeacherOnboarding = false});

  @override
  State<TenantOnboardingPage> createState() => _TenantOnboardingPageState();
}

class _TenantOnboardingPageState extends State<TenantOnboardingPage> {
  int _currentStep = 0;
  SchoolType? _selectedSchoolType;

  @override
  void initState() {
    super.initState();
    _checkAndRedirectIfNeeded();
  }

  /// Check if this user should be redirected to admin setup or teacher onboarding
  void _checkAndRedirectIfNeeded() {
    try {
      final userStateService = sl<UserStateService>();
      final currentUser = userStateService.currentUser;
      final currentTenant = userStateService.currentTenant;

      if (currentUser == null || currentTenant == null) {
        return; // Can't redirect without user/tenant info
      }

      // Check if this is a school admin (first user from domain)
      final isSchoolAdmin = currentUser.isAdmin &&
          currentTenant.domain != null &&
          currentTenant.domain!.isNotEmpty;

      if (isSchoolAdmin) {
        // Redirect to Admin Setup Wizard
        Future.microtask(() {
          if (mounted) {
            context.replace(AppRoutes.adminSetupWizard);
          }
        });
      }
    } catch (e) {
      // Silently fail - let them continue with normal onboarding
    }
  }

  void _onSchoolTypeSelected(SchoolType type) {
    setState(() {
      _selectedSchoolType = type;
      _currentStep = 1;
    });
  }

  void _onBack() {
    setState(() {
      _currentStep = 0;
      _selectedSchoolType = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back navigation
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildCurrentStep(),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return SchoolTypeSelector(
          key: const ValueKey('step_0'),
          onSchoolTypeSelected: _onSchoolTypeSelected,
        );
      case 1:
        return DataPreviewScreen(
          key: const ValueKey('step_1'),
          schoolType: _selectedSchoolType!,
          onBack: _onBack,
        );
      default:
        return SchoolTypeSelector(
          key: const ValueKey('step_0'),
          onSchoolTypeSelected: _onSchoolTypeSelected,
        );
    }
  }
}