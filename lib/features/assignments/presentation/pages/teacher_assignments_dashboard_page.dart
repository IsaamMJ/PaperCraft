// features/assignments/presentation/pages/teacher_assignments_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../authentication/domain/entities/user_entity.dart';
import '../../../authentication/domain/entities/user_role.dart';
import '../../../authentication/presentation/bloc/auth_bloc.dart';
import '../../../authentication/presentation/bloc/auth_state.dart';
import '../bloc/teacher_assignment_bloc.dart';
import '../bloc/teacher_assignment_event.dart';
import '../bloc/teacher_assignment_state.dart';

class TeacherAssignmentsDashboardPage extends StatefulWidget {
  const TeacherAssignmentsDashboardPage({super.key});

  @override
  State<TeacherAssignmentsDashboardPage> createState() =>
      _TeacherAssignmentsDashboardPageState();
}

class _TeacherAssignmentsDashboardPageState
    extends State<TeacherAssignmentsDashboardPage> {
  late TextEditingController _searchController;
  List<UserEntity> _allTenantTeachers = [];
  bool _isLoadingTeachers = true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadAssignments();
    _loadAllTeachers();
  }

  void _loadAssignments() {
    final authBloc = context.read<AuthBloc>();
    if (authBloc.state is AuthAuthenticated) {
      final user = (authBloc.state as AuthAuthenticated).user;
      if (user.tenantId != null) {
        context.read<TeacherAssignmentBloc>().add(
              LoadTeacherAssignmentsEvent(tenantId: user.tenantId!),
            );
      }
    }
  }

  Future<void> _loadAllTeachers() async {
    final authBloc = context.read<AuthBloc>();
    if (authBloc.state is! AuthAuthenticated) return;
    final user = (authBloc.state as AuthAuthenticated).user;
    if (user.tenantId == null) return;

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('id, full_name, email, role, tenant_id, is_active, created_at')
          .eq('tenant_id', user.tenantId!)
          .eq('role', 'teacher');

      final teachers = (response as List).map((json) {
        return UserEntity(
          id: json['id'] as String,
          email: json['email'] as String? ?? '',
          fullName: json['full_name'] as String? ?? 'Unknown',
          role: UserRole.teacher,
          tenantId: json['tenant_id'] as String?,
          isActive: json['is_active'] as bool? ?? true,
          createdAt: json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : DateTime.now(),
        );
      }).toList();

      if (mounted) {
        setState(() {
          _allTenantTeachers = teachers;
          _isLoadingTeachers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTeachers = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load all teachers: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TeacherAssignmentBloc, TeacherAssignmentState>(
      listener: _handleStateChanges,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        body: BlocBuilder<TeacherAssignmentBloc, TeacherAssignmentState>(
          builder: (context, state) {
            if (state is TeacherAssignmentsLoading || _isLoadingTeachers) {
              return _buildLoadingState();
            }

            if (state is TeacherAssignmentError) {
              return _buildErrorState(state.errorMessage);
            }

            if (state is TeacherAssignmentsLoaded) {
              return _buildContent(state);
            }

            return _buildLoadingState();
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Manage Assignments'),
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
    );
  }

  Widget _buildContent(TeacherAssignmentsLoaded state) {
    // Build assigned teachers — prefer profile data over denormalized assignment fields
    final profileMap = {for (final t in _allTenantTeachers) t.id: t};
    final assignedTeachersMap = state.assignments
        .fold<Map<String, UserEntity>>({}, (map, assignment) {
      if (!map.containsKey(assignment.teacherId)) {
        map[assignment.teacherId] = profileMap[assignment.teacherId] ??
            UserEntity(
              id: assignment.teacherId,
              email: assignment.teacherEmail ?? '',
              fullName: assignment.teacherName ?? 'Unknown',
              role: UserRole.teacher,
              tenantId: assignment.tenantId,
              isActive: true,
              createdAt: assignment.createdAt,
            );
      }
      return map;
    });

    final assignedTeachers = assignedTeachersMap.values.toList();
    final assignedIds = assignedTeachersMap.keys.toSet();

    // Unassigned = all tenant teachers minus those with assignments
    final unassignedTeachers = _allTenantTeachers
        .where((t) => !assignedIds.contains(t.id))
        .toList();

    // Apply search filter
    final filteredAssigned = _filterTeachers(assignedTeachers);
    final filteredUnassigned = _filterTeachers(unassignedTeachers);

    final hasAnyTeachers =
        filteredAssigned.isNotEmpty || filteredUnassigned.isNotEmpty;

    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: !hasAnyTeachers
              ? _buildEmptyState()
              : _buildTeachersListView(
                  filteredAssigned, filteredUnassigned, state),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.all(UIConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search teachers...',
          prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: UIConstants.paddingMedium,
            vertical: UIConstants.paddingSmall,
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: AppColors.error,
          ),
          SizedBox(height: UIConstants.spacing16),
          Text(message),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: UIConstants.iconXLarge,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: UIConstants.spacing16),
          Text(
            'No teachers found',
            style: TextStyle(
              fontSize: UIConstants.fontSizeLarge,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: UIConstants.spacing8),
          Text(
            _searchController.text.isEmpty
                ? 'No teachers available'
                : 'No teachers match your search',
            style: TextStyle(
              fontSize: UIConstants.fontSizeMedium,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeachersListView(
    List<UserEntity> assignedTeachers,
    List<UserEntity> unassignedTeachers,
    TeacherAssignmentsLoaded state,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        _loadAssignments();
        await _loadAllTeachers();
      },
      child: ListView(
        padding: EdgeInsets.all(UIConstants.paddingMedium),
        children: [
          // Assigned teachers section
          if (assignedTeachers.isNotEmpty) ...[
            ...assignedTeachers.map((teacher) {
              final teacherAssignments = state.assignments
                  .where((a) => a.teacherId == teacher.id)
                  .toList();
              final gradeCount = teacherAssignments
                  .fold<Set<String>>({}, (set, a) {
                    set.add(a.gradeId);
                    return set;
                  })
                  .length;
              final subjectCount = teacherAssignments
                  .fold<Set<String>>({}, (set, a) {
                    set.add(a.subjectId);
                    return set;
                  })
                  .length;

              return _buildTeacherCard(teacher, gradeCount, subjectCount);
            }),
          ],

          // Unassigned teachers section
          if (unassignedTeachers.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.only(
                top: assignedTeachers.isNotEmpty ? UIConstants.spacing16 : 0,
                bottom: UIConstants.spacing12,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person_add_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: UIConstants.spacing8),
                  Text(
                    'No assignments yet',
                    style: TextStyle(
                      fontSize: UIConstants.fontSizeMedium,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(width: UIConstants.spacing8),
                  Expanded(
                    child: Divider(color: AppColors.border),
                  ),
                ],
              ),
            ),
            ...unassignedTeachers.map((teacher) {
              return _buildUnassignedTeacherCard(teacher);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildTeacherCard(
    UserEntity teacher,
    int gradeCount,
    int subjectCount,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: UIConstants.spacing12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.black04,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToDetail(teacher),
          borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
          child: Padding(
            padding: EdgeInsets.all(UIConstants.paddingMedium),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      (teacher.fullName.isNotEmpty ? teacher.fullName[0] : '?').toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: UIConstants.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacher.fullName,
                        style: TextStyle(
                          fontSize: UIConstants.fontSizeLarge,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: UIConstants.spacing4),
                      Text(
                        teacher.email,
                        style: TextStyle(
                          fontSize: UIConstants.fontSizeSmall,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: UIConstants.spacing12),
                _buildStatsPill(gradeCount, subjectCount),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnassignedTeacherCard(UserEntity teacher) {
    return Container(
      margin: EdgeInsets.only(bottom: UIConstants.spacing12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        border: Border.all(
          color: AppColors.border,
          style: BorderStyle.solid,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToDetail(teacher),
          borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
          child: Padding(
            padding: EdgeInsets.all(UIConstants.paddingMedium),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      (teacher.fullName.isNotEmpty ? teacher.fullName[0] : '?').toUpperCase(),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: UIConstants.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacher.fullName,
                        style: TextStyle(
                          fontSize: UIConstants.fontSizeLarge,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: UIConstants.spacing4),
                      Text(
                        teacher.email,
                        style: TextStyle(
                          fontSize: UIConstants.fontSizeSmall,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: UIConstants.spacing12),
                Icon(
                  Icons.add_circle_outline,
                  color: AppColors.primary,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsPill(int gradeCount, int subjectCount) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: UIConstants.spacing12,
        vertical: UIConstants.spacing8,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary10,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$gradeCount',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          Text(
            'grades',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  List<UserEntity> _filterTeachers(List<UserEntity> teachers) {
    if (_searchController.text.isEmpty) {
      return teachers;
    }

    final query = _searchController.text.toLowerCase();
    return teachers
        .where((teacher) =>
            (teacher.fullName.toLowerCase().contains(query)) ||
            (teacher.email.toLowerCase().contains(query)))
        .toList();
  }

  void _navigateToDetail(UserEntity teacher) {
    context.push(
      '/settings/teacher-assignments/${teacher.id}',
    );
  }

  void _handleStateChanges(BuildContext context, TeacherAssignmentState state) {
    if (state is AssignmentSaved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: UIConstants.spacing8),
              const Expanded(child: Text('Assignment saved successfully')),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    if (state is AssignmentDeleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: UIConstants.spacing8),
              const Expanded(child: Text('Assignment deleted successfully')),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    if (state is TeacherAssignmentError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: UIConstants.spacing8),
              Expanded(child: Text(state.errorMessage)),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
          ),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }
}
