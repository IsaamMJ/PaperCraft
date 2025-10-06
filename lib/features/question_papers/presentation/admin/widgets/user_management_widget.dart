// features/settings/presentation/widgets/user_management_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/presentation/constants/app_colors.dart';
import '../../../../../core/presentation/utils/date_utils.dart';
import '../../../../authentication/domain/entities/user_entity.dart';
import '../../../../authentication/domain/entities/user_role.dart';

import '../../../../../core/presentation/constants/ui_constants.dart';
import '../../bloc/user_management_bloc.dart';

class UserManagementWidget extends StatefulWidget {
  const UserManagementWidget({super.key});

  @override
  State<UserManagementWidget> createState() => _UserManagementWidgetState();
}

class _UserManagementWidgetState extends State<UserManagementWidget> {
  @override
  void initState() {
    super.initState();
    // Load users on init
    context.read<UserManagementBloc>().add(const LoadTenantUsers());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<UserManagementBloc, UserManagementState>(
      listener: _handleStateChanges,
      child: Padding(
        padding: const EdgeInsets.all(UIConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with info
            _buildHeader(),
            SizedBox(height: UIConstants.spacing20),
            const Divider(),
            SizedBox(height: UIConstants.spacing20),

            // Users List
            Expanded(
              child: BlocBuilder<UserManagementBloc, UserManagementState>(
                builder: (context, state) {
                  if (state is UserManagementLoading) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          SizedBox(height: UIConstants.spacing16),
                          Text(
                            state.message ?? 'Loading users...',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    );
                  }

                  if (state is UserManagementError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              size: 48,
                              color: AppColors.error),
                          SizedBox(height: UIConstants.spacing16),
                          Text(state.message,
                              style: TextStyle(color: AppColors.error),
                              textAlign: TextAlign.center),
                          SizedBox(height: UIConstants.spacing16),
                          ElevatedButton(
                            onPressed: () {
                              context.read<UserManagementBloc>().add(const LoadTenantUsers());
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (state is TenantUsersLoaded) {
                    if (state.users.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline,
                                size: 48,
                                color: AppColors.textTertiary),
                            SizedBox(height: UIConstants.spacing16),
                            Text('No users in tenant',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                )),
                            SizedBox(height: UIConstants.spacing8),
                            Text('Users will appear here once they sign up',
                                style: TextStyle(color: AppColors.textTertiary),
                                textAlign: TextAlign.center),
                          ],
                        ),
                      );
                    }

                    // Group users by role for better organization
                    final usersByRole = <UserRole, List<UserEntity>>{};
                    for (final user in state.users) {
                      usersByRole.putIfAbsent(user.role, () => []).add(user);
                    }

                    return ListView.builder(
                      itemCount: usersByRole.keys.length,
                      itemBuilder: (context, index) {
                        final role = usersByRole.keys.elementAt(index);
                        final usersForRole = usersByRole[role]!;
                        return _buildRoleSection(role, usersForRole);
                      },
                    );
                  }

                  return const Center(child: Text('User management not available'));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(UIConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User Management',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: UIConstants.spacing4),
                Text(
                  'Manage users within your tenant. You can change roles, activate/deactivate accounts, and remove users.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSection(UserRole role, List<UserEntity> users) {
    // Sort users by name
    users.sort((a, b) => a.displayName.compareTo(b.displayName));

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(UIConstants.paddingMedium),
            decoration: BoxDecoration(
              color: _getRoleColor(role).withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(
                  _getRoleIcon(role),
                  color: _getRoleColor(role),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${role.displayName}s (${users.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _getRoleColor(role),
                  ),
                ),
              ],
            ),
          ),
          ...users.map((user) => _buildUserCard(user)).toList(),
        ],
      ),
    );
  }

  Widget _buildUserCard(UserEntity user) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getRoleColor(user.role).withOpacity(0.2),
        child: Text(
          user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U',
          style: TextStyle(
            color: _getRoleColor(user.role),
            fontWeight: FontWeight.bold,
            fontSize: UIConstants.fontSizeMedium,
          ),
        ),
      ),
      title: Text(
        user.displayName,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: user.isActive ? AppColors.textPrimary : AppColors.textTertiary,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user.email,
            style: TextStyle(
              color: user.isActive ? AppColors.textSecondary : AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              _buildStatusBadge(user.isActive),
              const SizedBox(width: 8),
              Text(
                'Joined ${AppDateUtils.formatShortDate(user.createdAt)}',
                style: TextStyle(
                  fontSize: UIConstants.fontSizeSmall,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Role change button
          PopupMenuButton<UserRole>(
            icon: Icon(
              Icons.admin_panel_settings,
              color: AppColors.primary,
            ),
            tooltip: 'Change role',
            onSelected: (newRole) => _showRoleChangeDialog(user, newRole),
            itemBuilder: (context) => UserRole.values
                .where((role) => role != user.role && role != UserRole.blocked)
                .map((role) => PopupMenuItem(
              value: role,
              child: Row(
                children: [
                  Icon(_getRoleIcon(role), size: 18),
                  const SizedBox(width: 8),
                  Text(role.displayName),
                ],
              ),
            ))
                .toList(),
          ),

          // Status toggle button
          IconButton(
            onPressed: () => _showStatusToggleDialog(user),
            icon: Icon(
              user.isActive ? Icons.toggle_on : Icons.toggle_off,
              color: user.isActive ? AppColors.success : AppColors.textTertiary,
            ),
            tooltip: user.isActive ? 'Deactivate user' : 'Activate user',
          ),

          // Delete button (only for non-admin users)
          if (user.role != UserRole.admin)
            IconButton(
              onPressed: () => _showDeleteDialog(user),
              icon: Icon(Icons.delete, color: AppColors.error),
              tooltip: 'Delete user',
            ),
        ],
      ),
      isThreeLine: true,
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isActive ? AppColors.success : AppColors.error,
        ),
      ),
    );
  }

  void _handleStateChanges(BuildContext context, UserManagementState state) {
    if (state is UserRoleUpdated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${state.user.displayName}\'s role updated to ${state.user.role.displayName}'),
          backgroundColor: AppColors.success,
        ),
      );
      context.read<UserManagementBloc>().add(const LoadTenantUsers());
    } else if (state is UserStatusToggled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${state.user.displayName} ${state.user.isActive ? 'activated' : 'deactivated'}'),
          backgroundColor: AppColors.success,
        ),
      );
      context.read<UserManagementBloc>().add(const LoadTenantUsers());
    } else if (state is UserDeleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User deleted successfully'),
          backgroundColor: Colors.orange,
        ),
      );
      context.read<UserManagementBloc>().add(const LoadTenantUsers());
    }
  }

  void _showRoleChangeDialog(UserEntity user, UserRole newRole) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Change User Role'),
          content: Text('Change ${user.displayName}\'s role from ${user.role.displayName} to ${newRole.displayName}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.read<UserManagementBloc>().add(UpdateUserRole(user.id, newRole));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  void _showStatusToggleDialog(UserEntity user) {
    final action = user.isActive ? 'deactivate' : 'activate';
    final actionCapitalized = user.isActive ? 'Deactivate' : 'Activate';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$actionCapitalized User'),
          content: Text('Are you sure you want to $action ${user.displayName}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.read<UserManagementBloc>().add(ToggleUserStatus(user.id, !user.isActive));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: user.isActive ? AppColors.error : AppColors.success,
                foregroundColor: Colors.white,
              ),
              child: Text(actionCapitalized),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteDialog(UserEntity user) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete User'),
          content: Text('Are you sure you want to delete ${user.displayName}?\n\nThis action cannot be undone and will remove all their data.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.read<UserManagementBloc>().add(DeleteUser(user.id));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return AppColors.error;
      case UserRole.teacher:
        return AppColors.primary;
      case UserRole.student:
        return AppColors.success;
      case UserRole.user:
        return AppColors.textSecondary;
      case UserRole.blocked:
        return AppColors.textTertiary;
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.teacher:
        return Icons.school;
      case UserRole.student:
        return Icons.person;
      case UserRole.user:
        return Icons.person_outline;
      case UserRole.blocked:
        return Icons.block;
    }
  }


}