import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../data/template/school_templates.dart';
import '../bloc/onboarding_bloc.dart';
import '../bloc/onboarding_event.dart';
import '../bloc/onboarding_state.dart';

class DataPreviewScreen extends StatelessWidget {
  final SchoolType schoolType;
  final VoidCallback onBack;

  const DataPreviewScreen({
    super.key,
    required this.schoolType,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final subjects = SchoolTemplates.getSubjects(schoolType);
    final grades = SchoolTemplates.getGrades(schoolType);
    final examTypes = SchoolTemplates.getExamTypes(schoolType);
    final totalItems = subjects.length + grades.length + examTypes.length;

    return BlocProvider(
      create: (context) => OnboardingBloc(
        seedTenantUseCase: sl(),
        tenantRepository: sl(),
        logger: sl(),
      ),
      child: BlocConsumer<OnboardingBloc, OnboardingState>(
        listener: (context, state) {
          if (state is OnboardingSuccess) {
            // Reload tenant data to pick up is_initialized flag
            final userStateService = sl<UserStateService>();
            userStateService.reloadTenantData().then((_) {
              // Navigate using GoRouter
              if (context.mounted) {
                context.go('/');  // Use GoRouter instead of Navigator
              }
            });
          } else if (state is OnboardingError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
                action: SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: () {
                    context.read<OnboardingBloc>().add(
                      StartSeeding(schoolType: schoolType),
                    );
                  },
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          final isSeeding = state is OnboardingSeeding;
          final progress = state is OnboardingSeeding ? state.progress : 0.0;
          final currentItem = state is OnboardingSeeding ? state.currentItem : '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(UIConstants.paddingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // Back button
                if (!isSeeding)
                  IconButton(
                    onPressed: onBack,
                    icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
                  ),

                const SizedBox(height: 20),

                // Header
                Text(
                  isSeeding ? 'Setting up your school...' : 'Review Setup',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  isSeeding
                      ? 'Please wait while we create your data'
                      : 'We\'ll create the following data for ${SchoolTemplates.getDisplayName(schoolType)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 32),

                // Progress indicator (only show when seeding)
                if (isSeeding) ...[
                  Container(
                    padding: const EdgeInsets.all(UIConstants.paddingLarge),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.black04,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              currentItem,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: AppColors.primary10,
                            valueColor: AlwaysStoppedAnimation(AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                // Data preview cards
                _buildDataCard(
                  icon: Icons.subject,
                  title: 'Subjects',
                  count: subjects.length,
                  color: AppColors.primary,
                  items: subjects.map((s) => s.name).take(5).toList(),
                  hasMore: subjects.length > 5,
                ),

                const SizedBox(height: 16),

                _buildDataCard(
                  icon: Icons.school,
                  title: 'Grades',
                  count: grades.length,
                  color: AppColors.accent,
                  items: grades.take(5).map((g) => 'Grade $g').toList(),
                  hasMore: grades.length > 5,
                ),

                const SizedBox(height: 16),

                _buildDataCard(
                  icon: Icons.quiz,
                  title: 'Exam Types',
                  count: examTypes.length,
                  color: AppColors.success,
                  items: examTypes.map((e) => e.name).toList(),
                  hasMore: false,
                ),

                const SizedBox(height: 32),

                // Confirm button
                if (!isSeeding)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        context.read<OnboardingBloc>().add(
                          StartSeeding(schoolType: schoolType),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Create $totalItems Items',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDataCard({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
    required List<String> items,
    required bool hasMore,
  }) {
    return Container(
      padding: const EdgeInsets.all(UIConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.black04,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '$count items',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          )),
          if (hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+ ${count - 5} more',
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}