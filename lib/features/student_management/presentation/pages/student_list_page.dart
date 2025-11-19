import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:papercraft/core/presentation/constants/app_colors.dart';
import 'package:papercraft/core/presentation/constants/ui_constants.dart';
import 'package:papercraft/features/student_management/presentation/bloc/student_management_bloc.dart';

/// Student List Page
///
/// Displays all students in a grade section with:
/// - Search/filter by roll number or name
/// - Add single student button
/// - Bulk upload button
/// - Delete student option (soft delete)
class StudentListPage extends StatefulWidget {
  const StudentListPage({super.key});

  @override
  State<StudentListPage> createState() => _StudentListPageState();
}

class _StudentListPageState extends State<StudentListPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Don't auto-load on init - let user click refresh button
    // This prevents infinite loading issues
    print('[DEBUG STUDENT LIST] initState called');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manage Students'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              print('[DEBUG STUDENT LIST] Refresh button clicked');
              context.read<StudentManagementBloc>().add(
                    const RefreshStudentList(),
                  );
            },
          ),
        ],
      ),
      floatingActionButton: _buildFAB(context),
      body: BlocBuilder<StudentManagementBloc, StudentManagementState>(
        builder: (context, state) {
          print('[DEBUG STUDENT LIST] BlocBuilder state: ${state.runtimeType}');

          if (state is StudentManagementLoading) {
            print('[DEBUG STUDENT LIST] Loading students...');
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (state is StudentManagementError) {
            print('[DEBUG STUDENT LIST] Error loading students: ${state.message}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  SizedBox(height: UIConstants.spacing16),
                  Text(
                    state.message,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: UIConstants.spacing16),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          if (state is StudentsLoaded) {
            print('[DEBUG STUDENT LIST] Students loaded: ${state.students.length} total, ${state.filteredStudents.length} filtered');
            return SingleChildScrollView(
              padding: EdgeInsets.all(UIConstants.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(state),
                  SizedBox(height: UIConstants.spacing24),

                  // Search bar
                  _buildSearchBar(context, state),
                  SizedBox(height: UIConstants.spacing16),

                  // Students list
                  _buildStudentsList(state),
                  SizedBox(height: UIConstants.spacing24),
                ],
              ),
            );
          }

          print('[DEBUG STUDENT LIST] Unknown state type: ${state.runtimeType}');
          return const Center(
            child: Text('Unknown state'),
          );
        },
      ),
    );
  }

  Widget _buildHeader(StudentsLoaded state) {
    print('[DEBUG STUDENT LIST] Building header with ${state.students.length} total students');
    return Container(
      padding: EdgeInsets.all(UIConstants.paddingLarge),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.people,
                color: Colors.white,
                size: UIConstants.iconLarge,
              ),
              SizedBox(width: UIConstants.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Students',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    SizedBox(height: UIConstants.spacing4),
                    Text(
                      'Total: ${state.students.length} students',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, StudentsLoaded state) {
    print('[DEBUG STUDENT LIST] Building search bar');
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search by roll number or name...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  print('[DEBUG STUDENT LIST] Clear search button clicked');
                  _searchController.clear();
                  context.read<StudentManagementBloc>().add(
                        const SearchStudents(searchTerm: ''),
                      );
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: UIConstants.paddingMedium,
          vertical: UIConstants.paddingSmall,
        ),
      ),
      onChanged: (value) {
        print('[DEBUG STUDENT LIST] Search term changed: "$value"');
        setState(() {}); // Update suffix icon
        context.read<StudentManagementBloc>().add(
              SearchStudents(searchTerm: value),
            );
      },
    );
  }

  Widget _buildStudentsList(StudentsLoaded state) {
    final students = state.filteredStudents;
    print('[DEBUG STUDENT LIST] Building students list with ${students.length} students');

    if (students.isEmpty) {
      print('[DEBUG STUDENT LIST] No students to display');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: UIConstants.spacing16),
            Text(
              'No students found',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            SizedBox(height: UIConstants.spacing24),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add First Student'),
              onPressed: () {
                print('[DEBUG STUDENT LIST] Add First Student button clicked - no students in list');
                context.pushNamed(
                  'add_student',
                  pathParameters: {'gradeSectionId': state.gradeSectionId},
                );
              },
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: students.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final student = students[index];
          return ListTile(
            leading: CircleAvatar(
              child: Text(student.rollNumber),
            ),
            title: Text(student.fullName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: UIConstants.spacing4),
                Text(
                  'Roll No: ${student.rollNumber}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (student.email != null) ...[
                  SizedBox(height: UIConstants.spacing4),
                  Text(
                    student.email!,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                print('[DEBUG STUDENT LIST] Menu selected: $value for student ${student.id}');
                if (value == 'edit') {
                  // TODO: Implement edit functionality
                  print('[DEBUG STUDENT LIST] Edit clicked for student: ${student.fullName}');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Edit not yet implemented')),
                  );
                } else if (value == 'delete') {
                  print('[DEBUG STUDENT LIST] Delete clicked for student: ${student.fullName}');
                  _confirmDelete(context, student.id, student.fullName);
                }
              },
            ),
            onTap: () {
              print('[DEBUG STUDENT LIST] Student tapped: ${student.fullName}');
              // Show student details or allow editing
            },
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, String studentId, String studentName) {
    print('[DEBUG STUDENT LIST] Showing delete confirmation dialog for student: $studentName (ID: $studentId)');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text('Are you sure you want to delete $studentName?'),
        actions: [
          TextButton(
            onPressed: () {
              print('[DEBUG STUDENT LIST] Delete dialog cancelled');
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              print('[DEBUG STUDENT LIST] Delete confirmed for student: $studentName (ID: $studentId)');
              Navigator.pop(context);
              // TODO: Implement delete functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Delete not yet implemented')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return BlocBuilder<StudentManagementBloc, StudentManagementState>(
      builder: (context, state) {
        if (state is StudentsLoaded) {
          print('[DEBUG STUDENT LIST] Building FAB');
          return FloatingActionButton(
            onPressed: () {
              print('[DEBUG STUDENT LIST] FAB clicked - showing menu');
              showMenu(
                context: context,
                position: RelativeRect.fromLTRB(
                  MediaQuery.of(context).size.width - 100,
                  MediaQuery.of(context).size.height - 100,
                  20,
                  20,
                ),
                items: [
                  const PopupMenuItem(
                    value: 'single',
                    child: Row(
                      children: [
                        Icon(Icons.person_add),
                        SizedBox(width: 8),
                        Text('Add Student'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'bulk',
                    child: Row(
                      children: [
                        Icon(Icons.upload_file),
                        SizedBox(width: 8),
                        Text('Bulk Upload'),
                      ],
                    ),
                  ),
                ],
              ).then((value) {
                if (value == 'single') {
                  print('[DEBUG STUDENT LIST] FAB menu: Add Student selected');
                  if (mounted) {
                    context.pushNamed(
                      'add_student',
                      pathParameters: {'gradeSectionId': state.gradeSectionId},
                    );
                  }
                } else if (value == 'bulk') {
                  print('[DEBUG STUDENT LIST] FAB menu: Bulk Upload selected');
                  if (mounted) {
                    context.pushNamed(
                      'bulk_upload_students',
                      pathParameters: {'gradeSectionId': state.gradeSectionId},
                    );
                  }
                } else {
                  print('[DEBUG STUDENT LIST] FAB menu closed without selection');
                }
              });
            },
            child: const Icon(Icons.add),
          );
        }
        print('[DEBUG STUDENT LIST] FAB not visible - state is not StudentsLoaded');
        return const SizedBox.shrink();
      },
    );
  }
}
