// features/assignments/presentation/pages/teacher_assignment_management_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../../core/presentation/routes/app_routes.dart';
import '../../../authentication/domain/entities/user_entity.dart';
import '../../../authentication/domain/entities/user_role.dart';
import '../../../paper_workflow/presentation/bloc/user_management_bloc.dart';

class TeacherAssignmentManagementPage extends StatefulWidget {
  const TeacherAssignmentManagementPage({super.key});

  @override
  State<TeacherAssignmentManagementPage> createState() =>
      _TeacherAssignmentManagementPageState();
}

class _TeacherAssignmentManagementPageState
    extends State<TeacherAssignmentManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadTeachers() {
    context.read<UserManagementBloc>().add(const LoadUsers());
  }

  List<UserEntity> _filterTeachers(List<UserEntity> teachers) {
    if (_searchQuery.isEmpty) return teachers;

    return teachers.where((teacher) {
      final nameLower = teacher.fullName.toLowerCase();
      final emailLower = teacher.email.toLowerCase();
      final queryLower = _searchQuery.toLowerCase();
      return nameLower.contains(queryLower) || emailLower.contains(queryLower);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Teacher Assignments',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Assign grades and subjects to teachers',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: BlocBuilder<UserManagementBloc, UserManagementState>(
        builder: (context, state) {
          // ========== DEBUG LOGGING ==========
          print('🔍 ========== TEACHER ASSIGNMENT PAGE DEBUG ==========');
          print('🔍 UserManagementBloc State Type: ${state.runtimeType}');

          if (state is UserManagementLoading) {
            print('🔍 State: LOADING');
            return _buildLoadingState();
          }

          if (state is UserManagementError) {
            print('🔍 State: ERROR');
            print('🔍 Error Message: ${state.message}');
            return _buildErrorState(state.message);
          }

          if (state is UserManagementLoaded) {
            print('🔍 State: LOADED');
            print('🔍 Total users loaded: ${state.users.length}');
            print('🔍 All user roles: ${state.users.map((u) => '${u.fullName}: ${u.role.value}').toList()}');

            // Filter only teachers and admins
            final teachers = state.users
                .where((user) =>
            user.role == UserRole.teacher || user.role == UserRole.admin)
                .toList();

            print('🔍 Teachers/Admins count after filter: ${teachers.length}');
            print('🔍 Filtered teachers: ${teachers.map((t) => '${t.fullName} (${t.role.value})').toList()}');

            if (teachers.isEmpty) {
              print('🔍 No teachers found - showing empty state');
              return _buildEmptyState();
            }

            final filteredTeachers = _filterTeachers(teachers);
            print('🔍 Search query: "$_searchQuery"');
            print('🔍 Teachers after search filter: ${filteredTeachers.length}');

            return Column(
              children: [
                _buildAssignmentProgress(teachers.length),
                _buildSearchBar(),
                Expanded(
                  child: filteredTeachers.isEmpty
                      ? _buildNoResultsState()
                      : _buildTeacherList(filteredTeachers),
                ),
              ],
            );
          }

          print('🔍 State: UNKNOWN/INITIAL - showing empty state');
          return _buildEmptyState();
        },
      ),
    );
  }

  Widget _buildAssignmentProgress(int totalTeachers) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        UIConstants.paddingMedium,
        UIConstants.paddingMedium,
        UIConstants.paddingMedium,
        0,
      ),
      padding: EdgeInsets.all(UIConstants.paddingMedium),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient.scale(0.1),
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(UIConstants.spacing12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
            ),
            child: Icon(
              Icons.people,
              color: AppColors.primary,
              size: UIConstants.iconLarge,
            ),
          ),
          SizedBox(width: UIConstants.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$totalTeachers ${totalTeachers == 1 ? 'Teacher' : 'Teachers'} in School',
                  style: TextStyle(
                    fontSize: UIConstants.fontSizeLarge,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: UIConstants.spacing4),
                Text(
                  'Tap any teacher to assign grades and subjects',
                  style: TextStyle(
                    fontSize: UIConstants.fontSizeMedium,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.info_outline,
            color: AppColors.primary,
            size: UIConstants.iconMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.all(UIConstants.paddingMedium),
      color: AppColors.surface,
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() => _searchQuery = value);
        },
        decoration: InputDecoration(
          hintText: 'Search teachers by name or email...',
          prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, color: AppColors.textSecondary),
            onPressed: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
          )
              : null,
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: UIConstants.spacing16,
            vertical: UIConstants.spacing12,
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherList(List<UserEntity> teachers) {
    return RefreshIndicator(
      onRefresh: () async => _loadTeachers(),
      child: ListView.builder(
        padding: EdgeInsets.all(UIConstants.paddingMedium),
        itemCount: teachers.length,
        itemBuilder: (context, index) {
          final teacher = teachers[index];
          return _buildTeacherCard(teacher);
        },
      ),
    );
  }

  Widget _buildTeacherCard(UserEntity teacher) {
    return Container(
      margin: EdgeInsets.only(bottom: UIConstants.spacing12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToAssignmentDetail(teacher),
          borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
          child: Padding(
            padding: EdgeInsets.all(UIConstants.paddingMedium),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                  ),
                  child: Center(
                    child: Text(
                      teacher.fullName.isNotEmpty
                          ? teacher.fullName[0].toUpperCase()
                          : 'T',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: UIConstants.spacing16),
                // Teacher info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              teacher.fullName,
                              style: TextStyle(
                                fontSize: UIConstants.fontSizeLarge,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildRoleBadge(teacher.role),
                        ],
                      ),
                      SizedBox(height: UIConstants.spacing4),
                      if (teacher.email != null) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.email_outlined,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(width: UIConstants.spacing4),
                            Expanded(
                              child: Text(
                                teacher.email!,
                                style: TextStyle(
                                  fontSize: UIConstants.fontSizeMedium,
                                  color: AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Arrow icon
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(UserRole role) {
    final isAdmin = role == UserRole.admin;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: UIConstants.spacing8,
        vertical: UIConstants.spacing4,
      ),
      decoration: BoxDecoration(
        gradient: isAdmin ? AppColors.accentGradient : null,
        color: isAdmin ? null : AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        border: isAdmin
            ? null
            : Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Text(
        role.displayName,
        style: TextStyle(
          color: isAdmin ? Colors.white : AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          SizedBox(height: UIConstants.spacing16),
          Text(
            'Loading teachers...',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: UIConstants.fontSizeMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(UIConstants.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: UIConstants.iconHuge,
              color: AppColors.error,
            ),
            SizedBox(height: UIConstants.spacing16),
            Text(
              'Failed to load teachers',
              style: TextStyle(
                fontSize: UIConstants.fontSizeXXLarge,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: UIConstants.spacing8),
            Text(
              message,
              style: TextStyle(
                fontSize: UIConstants.fontSizeMedium,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: UIConstants.spacing24),
            ElevatedButton.icon(
              onPressed: _loadTeachers,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: UIConstants.spacing24,
                  vertical: UIConstants.spacing12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(UIConstants.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline,
              size: UIConstants.iconHuge,
              color: AppColors.textTertiary,
            ),
            SizedBox(height: UIConstants.spacing16),
            Text(
              'No Teachers Found',
              style: TextStyle(
                fontSize: UIConstants.fontSizeXXLarge,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: UIConstants.spacing8),
            Text(
              'There are no teachers in your organization yet.',
              style: TextStyle(
                fontSize: UIConstants.fontSizeMedium,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(UIConstants.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: UIConstants.iconHuge,
              color: AppColors.textTertiary,
            ),
            SizedBox(height: UIConstants.spacing16),
            Text(
              'No Results Found',
              style: TextStyle(
                fontSize: UIConstants.fontSizeXXLarge,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: UIConstants.spacing8),
            Text(
              'No teachers match "$_searchQuery"',
              style: TextStyle(
                fontSize: UIConstants.fontSizeMedium,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToAssignmentDetail(UserEntity teacher) {
    context.push('${AppRoutes.teacherAssignments}/${teacher.id}');
  }
}