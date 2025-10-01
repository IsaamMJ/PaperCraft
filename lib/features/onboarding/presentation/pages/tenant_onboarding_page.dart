import 'package:flutter/material.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../data/template/school_templates.dart';
import '../widgets/school_type_selector.dart';
import 'data_preview_screen.dart';

class TenantOnboardingPage extends StatefulWidget {
  const TenantOnboardingPage({super.key});

  @override
  State<TenantOnboardingPage> createState() => _TenantOnboardingPageState();
}

class _TenantOnboardingPageState extends State<TenantOnboardingPage> {
  int _currentStep = 0;
  SchoolType? _selectedSchoolType;

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