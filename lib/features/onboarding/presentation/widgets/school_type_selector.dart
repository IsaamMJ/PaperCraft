import 'package:flutter/material.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../data/template/school_templates.dart';

class SchoolTypeSelector extends StatelessWidget {
  final Function(SchoolType) onSchoolTypeSelected;

  const SchoolTypeSelector({
    super.key,
    required this.onSchoolTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(UIConstants.paddingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),

          // Welcome header
          Container(
            padding: const EdgeInsets.all(UIConstants.paddingLarge),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                  ),
                  child: const Icon(
                    Icons.school,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome to Papercraft!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Let\'s set up your school in just 2 steps',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          Text(
            'Choose Your School Type',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'We\'ll create subjects, grades, and exam types based on your selection',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 24),

          // School type cards
          _buildSchoolTypeCard(
            context,
            schoolType: SchoolType.cbse,
            icon: Icons.school_outlined,
            title: SchoolTemplates.getDisplayName(SchoolType.cbse),
            description: SchoolTemplates.getDescription(SchoolType.cbse),
            color: AppColors.primary,
          ),

          const SizedBox(height: 16),

          _buildSchoolTypeCard(
            context,
            schoolType: SchoolType.stateBoard,
            icon: Icons.business_outlined,
            title: SchoolTemplates.getDisplayName(SchoolType.stateBoard),
            description: SchoolTemplates.getDescription(SchoolType.stateBoard),
            color: AppColors.accent,
          ),

          const SizedBox(height: 32),

          // Info box
          Container(
            padding: const EdgeInsets.all(UIConstants.paddingMedium),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You can add, edit, or remove any data later from Settings',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolTypeCard(
      BuildContext context, {
        required SchoolType schoolType,
        required IconData icon,
        required String title,
        required String description,
        required Color color,
      }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSchoolTypeSelected(schoolType),
        borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
        child: Container(
          padding: const EdgeInsets.all(UIConstants.paddingLarge),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
            border: Border.all(color: color.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: color,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}