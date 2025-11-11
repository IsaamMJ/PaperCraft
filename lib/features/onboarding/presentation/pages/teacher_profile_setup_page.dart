import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../../core/infrastructure/logging/app_logger.dart';
import '../../../../core/infrastructure/network/api_client.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../../core/presentation/routes/app_routes.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../../authentication/presentation/bloc/auth_bloc.dart';
import '../../../authentication/presentation/bloc/auth_event.dart';
import '../../../catalog/presentation/bloc/grade_bloc.dart';
import '../../../catalog/presentation/bloc/subject_bloc.dart';

class TeacherProfileSetupPage extends StatefulWidget {
  const TeacherProfileSetupPage({super.key});

  @override
  State<TeacherProfileSetupPage> createState() => _TeacherProfileSetupPageState();
}

class _TeacherProfileSetupPageState extends State<TeacherProfileSetupPage> {
  final Set<String> _selectedGradeIds = {};
  final Set<String> _selectedSubjectIds = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadGradesAndSubjects();
  }

  void _loadGradesAndSubjects() {
    context.read<GradeBloc>().add(const LoadGrades());
    context.read<SubjectBloc>().add(const LoadSubjects());
  }

  Future<void> _submitAssignments() async {
    setState(() => _isSubmitting = true);

    try {
      final userStateService = sl<UserStateService>();
      final userId = userStateService.currentUserId;

      if (userId == null) {
        throw Exception('User information not available');
      }


      // Update last login timestamp to mark onboarding as complete
      await _updateLastLoginAt(userId);

      if (mounted) {
        AppLogger.info('Teacher onboarding completed',
            category: LogCategory.auth,
            context: {'userId': userId});


        // Refresh auth state to update isFirstLogin flag
        context.read<AuthBloc>().add(AuthCheckStatus());

        // Navigate to home
        context.go(AppRoutes.home);
      }
    } catch (e) {
      AppLogger.warning('Error during teacher onboarding: ${e.toString()}',
          category: LogCategory.auth,
          context: {'error': e.toString()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _updateLastLoginAt(String userId) async {
    try {
      final apiClient = sl<ApiClient>();
      await apiClient.update<void>(
        table: 'profiles',
        data: {'last_login_at': DateTime.now().toIso8601String()},
        filters: {'id': userId},
        fromJson: (_) => null,
      );
      AppLogger.info('Last login timestamp updated after onboarding',
          category: LogCategory.auth,
          context: {'userId': userId});
    } catch (e) {
      AppLogger.warning('Failed to update last login timestamp',
          category: LogCategory.auth,
          context: {'userId': userId, 'error': e.toString()});
      // Don't fail the onboarding if this fails - it's not critical
    }
  }

  @override
  Widget build(BuildContext context) {
    final userStateService = sl<UserStateService>();
    final tenantName = userStateService.currentTenant?.name ?? 'School';
    final academicYear = userStateService.currentAcademicYear ?? '2024-2025';

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(UIConstants.paddingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Set Up Your Profile',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You\'re teaching at $tenantName. Select the grades and subjects you teach this year ($academicYear)',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: UIConstants.spacing24),

                // Grades Section - FilterChips
                Text(
                  'Select Grades',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildGradesFilterChips(),
                const SizedBox(height: UIConstants.spacing24),

                // Subjects Section - FilterChips
                Text(
                  'Select Subjects',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSubjectsFilterChips(),
                const SizedBox(height: UIConstants.spacing32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitAssignments,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                      ),
                      disabledBackgroundColor: AppColors.primary30,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Text(
                            'Continue to Dashboard',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradesFilterChips() {
    return BlocBuilder<GradeBloc, GradeState>(
      builder: (context, state) {
        if (state is GradeLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is GradeError) {
          return Center(child: Text('Error: ${state.message}'));
        }

        if (state is GradesLoaded) {
          final grades = state.grades;

          if (grades.isEmpty) {
            return Center(
              child: Text(
                'No grades available',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: grades.map((grade) {
              final isSelected = _selectedGradeIds.contains(grade.id);
              return FilterChip(
                label: Text(grade.displayName),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedGradeIds.add(grade.id);
                    } else {
                      _selectedGradeIds.remove(grade.id);
                    }
                  });
                },
                backgroundColor: Colors.transparent,
                selectedColor: AppColors.primary.withOpacity(0.2),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
              );
            }).toList(),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSubjectsFilterChips() {
    return BlocBuilder<SubjectBloc, SubjectState>(
      builder: (context, state) {
        if (state is SubjectLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is SubjectError) {
          return Center(child: Text('Error: ${state.message}'));
        }

        if (state is SubjectsLoaded) {
          final subjects = state.subjects;

          if (subjects.isEmpty) {
            return Center(
              child: Text(
                'No subjects available',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: subjects.map((subject) {
              final isSelected = _selectedSubjectIds.contains(subject.id);
              return FilterChip(
                label: Text(subject.name),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedSubjectIds.add(subject.id);
                    } else {
                      _selectedSubjectIds.remove(subject.id);
                    }
                  });
                },
                backgroundColor: Colors.transparent,
                selectedColor: AppColors.success.withOpacity(0.2),
                side: BorderSide(
                  color: isSelected ? AppColors.success : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
              );
            }).toList(),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
