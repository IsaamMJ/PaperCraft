// lib/core/main_scaffold/main_scaffold_screen.dart
import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/authentication/presentation/bloc/auth_bloc.dart';
import '../../features/authentication/presentation/bloc/auth_event.dart';
import '../../features/authentication/presentation/bloc/auth_state.dart';
import '../../features/authentication/domain/entities/user_entity.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/question_papers/presentation/bloc/question_paper_bloc.dart';
import '../../features/question_papers/presentation/pages/question_bank_page.dart';
import '../../features/question_papers/presentation/pages/question_paper_create_page.dart';
import '../../features/question_papers/presentation/admin/admin_dashboard_page.dart';
import '../../core/services/permission_service.dart';
import '../di/injection_container.dart';

class MainScaffoldPage extends StatefulWidget {
  const MainScaffoldPage({super.key});

  @override
  State<MainScaffoldPage> createState() => _MainScaffoldPageState();
}

class _MainScaffoldPageState extends State<MainScaffoldPage> {
  int _selectedIndex = 0;
  bool _isLoggingOut = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  void _checkUserRole() async {
    final isAdmin = await PermissionService.currentUserIsAdmin();
    if (mounted) {
      setState(() => _isAdmin = isAdmin);
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: _isLoggingOut ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isLoggingOut ? null : () {
                setState(() {
                  _isLoggingOut = true;
                });
                Navigator.of(context).pop();
                context.read<AuthBloc>().add(const AuthSignOut());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _isLoggingOut ? Colors.grey : Colors.red,
                foregroundColor: Colors.white,
              ),
              child: _isLoggingOut
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  // Helper method to get role display name
  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.teacher:
        return 'Teacher';
      case UserRole.student:
        return 'Student';
      case UserRole.user:
        return 'User';
      default:
        return 'User';
    }
  }

  List<Widget> _getPages() {
    final List<Widget> pages = [
      const HomePage(),
      const QuestionPaperCreatePage(),
    ];

    // Add question bank for all teachers/admins (index 2)
    pages.add(
      BlocProvider(
        create: (context) => QuestionPaperBloc(
          saveDraftUseCase: sl(),
          submitPaperUseCase: sl(),
          getDraftsUseCase: sl(),
          getUserSubmissionsUseCase: sl(),
          approvePaperUseCase: sl(),
          rejectPaperUseCase: sl(),
          getPapersForReviewUseCase: sl(),
          deleteDraftUseCase: sl(),
          pullForEditingUseCase: sl(),
          getPaperByIdUseCase: sl(),
        ),
        child: const QuestionBankPage(),
      ),
    );

    // Add admin dashboard if user is admin (index 3)
    if (_isAdmin) {
      pages.add(
        BlocProvider(
          create: (context) => QuestionPaperBloc(
            saveDraftUseCase: sl(),
            submitPaperUseCase: sl(),
            getDraftsUseCase: sl(),
            getUserSubmissionsUseCase: sl(),
            approvePaperUseCase: sl(),
            rejectPaperUseCase: sl(),
            getPapersForReviewUseCase: sl(),
            deleteDraftUseCase: sl(),
            pullForEditingUseCase: sl(),
            getPaperByIdUseCase: sl(),
          ),
          child: const AdminDashboardPage(),
        ),
      );
    }

    return pages;
  }

  List<BottomNavigationBarItem> _getNavigationItems() {
    final List<BottomNavigationBarItem> items = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.home),
        label: 'Home',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.quiz),
        label: 'Create',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.library_books),
        label: 'Question Bank',
      ),
    ];

    // Add admin navigation item if user is admin
    if (_isAdmin) {
      items.add(const BottomNavigationBarItem(
        icon: Icon(Icons.admin_panel_settings),
        label: 'Admin',
      ));
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (_isLoggingOut && state is! AuthLoading) {
          setState(() {
            _isLoggingOut = false;
          });
        }

        if (state is AuthError && _isLoggingOut) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Logout failed: ${state.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }

        // Recheck role when auth state changes
        if (state is AuthAuthenticated) {
          _checkUserRole();
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthLoading && !_isLoggingOut) {
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading user data...'),
                  ],
                ),
              ),
            );
          }

          if (state is! AuthAuthenticated) {
            return const Scaffold(
              body: Center(
                child: Text('Authentication required'),
              ),
            );
          }

          final user = state.user;
          final pages = _getPages();
          final navigationItems = _getNavigationItems();

          // Ensure selected index is within bounds
          if (_selectedIndex >= pages.length) {
            _selectedIndex = 0;
          }

          return Scaffold(
            appBar: AppBar(
              title: Text('Paper Craft - ${_getPageTitle(_selectedIndex)}'),
              backgroundColor: _isAdmin ? Colors.deepPurple : Colors.blue,
              foregroundColor: Colors.white,
              actions: [
                // Role indicator
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isAdmin ? Colors.amber.shade700 : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getRoleDisplayName(user.role),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _isAdmin ? Colors.white : Colors.white70,
                    ),
                  ),
                ),

                // User info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Center(
                    child: Text(
                      user.fullName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                // Logout button
                _isLoggingOut
                    ? const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                )
                    : IconButton(
                  onPressed: () => _showLogoutDialog(context),
                  icon: const Icon(Icons.logout),
                  tooltip: 'Logout',
                ),
              ],
            ),
            body: IndexedStack(
              index: _selectedIndex,
              children: pages,
            ),
            bottomNavigationBar: BottomNavigationBar(
              items: navigationItems,
              currentIndex: _selectedIndex,
              selectedItemColor: _isAdmin ? Colors.deepPurple : Colors.blue,
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed,
              onTap: _onItemTapped,
              elevation: 8,
            ),
            // Admin floating action button
            floatingActionButton: _selectedIndex == 0 && _isAdmin
                ? _buildAdminFAB(context)
                : null,
          );
        },
      ),
    );
  }

  Widget? _buildAdminFAB(BuildContext context) {
    if (!_isAdmin) return null;

    return FloatingActionButton.extended(
      onPressed: () {
        // Switch to admin tab (index 3 if admin, otherwise adjust)
        final adminTabIndex = _isAdmin ? 3 : 2;
        setState(() => _selectedIndex = adminTabIndex);
      },
      backgroundColor: Colors.deepPurple,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.admin_panel_settings),
      label: const Text('Admin'),
      tooltip: 'Open Admin Dashboard',
    );
  }

  String _getPageTitle(int index) {
    if (index == 0) return 'Home';
    if (index == 1) return 'Create Paper';
    if (index == 2) return 'Question Bank';
    if (index == 3 && _isAdmin) return 'Admin Dashboard';
    return 'Paper Craft';
  }
}

// Extension to add admin-specific styling
extension AdminTheme on BuildContext {
  bool get isAdminMode {
    // You can access this throughout your app to apply admin-specific styling
    return true; // This would be determined by user role
  }

  Color get primaryColor {
    return isAdminMode ? Colors.deepPurple : Colors.blue;
  }
}