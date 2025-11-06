import 'dart:core';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/interfaces/i_logger.dart';
import '../../../core/infrastructure/logging/app_logger.dart';
import '../../../../../core/presentation/constants/ui_constants.dart';

import '../../../core/presentation/constants/app_colors.dart';
import '../../../core/presentation/routes/app_routes.dart';
import '../../authentication/domain/entities/user_role.dart';
import '../../authentication/domain/services/user_state_service.dart';
import '../../authentication/presentation/bloc/auth_bloc.dart';
import '../../authentication/presentation/bloc/auth_event.dart';
import '../../authentication/presentation/bloc/auth_state.dart';

class MainScaffoldPage extends StatefulWidget {
  final UserStateService userStateService;
  final List<Widget> adminPages;
  final List<Widget> teacherPages;

  const MainScaffoldPage({
    super.key,
    required this.userStateService,
    required this.adminPages,
    required this.teacherPages,
  });

  @override
  State<MainScaffoldPage> createState() => _MainScaffoldPageState();
}

class _MainScaffoldPageState extends State<MainScaffoldPage>
    with TickerProviderStateMixin {

  // State variables
  int _selectedIndex = 0;
  bool _isLoggingOut = false;
  bool _isAdmin = false;

  // Animation controllers
  late AnimationController _tabAnimationController;
  late AnimationController _logoutAnimationController;
  late Animation<double> _tabAnimation;

  // User state subscription
  StreamSubscription<void>? _userStateSubscription;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkUserRole();
    _subscribeToUserStateChanges();
  }

  @override
  void dispose() {
    _tabAnimationController.dispose();
    _logoutAnimationController.dispose();
    _userStateSubscription?.cancel();
    super.dispose();
  }



  void _initializeAnimations() {
    _tabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _logoutAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _tabAnimation = CurvedAnimation(
      parent: _tabAnimationController,
      curve: Curves.easeInOut,
    );

    _tabAnimationController.forward();
  }

  void _subscribeToUserStateChanges() {
    _userStateSubscription = widget.userStateService.addListener(() {
      if (mounted) {
        final newAdminStatus = widget.userStateService.isAdmin;
        if (_isAdmin != newAdminStatus) {
          setState(() {
            _isAdmin = newAdminStatus;
            _selectedIndex = _getDefaultScreenIndex();
          });
        }
      }
    }) as StreamSubscription<void>?;
  }

  void _checkUserRole() {
    final isAdmin = widget.userStateService.isAdmin;
    if (mounted && _isAdmin != isAdmin) {
      setState(() {
        _isAdmin = isAdmin;
        _selectedIndex = _getDefaultScreenIndex();
      });
    }
  }

  // NEW METHOD: Get default screen index based on user role
  int _getDefaultScreenIndex() {
    if (_isAdmin) {
      return 0; // Admin Dashboard (index 0) for admin users - now first position
    } else {
      return 0; // Home Page (index 0) for teacher users
    }
  }

  void _onItemTapped(int index) {
    if (index != _selectedIndex && index < _getPages().length) {
      _tabAnimationController.reset();
      _tabAnimationController.forward();
      setState(() => _selectedIndex = index);
    }
  }

  void _showLogoutDialog(BuildContext context, dynamic user) {
    showDialog(
      context: context,
      barrierDismissible: !_isLoggingOut,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UIConstants.radiusXLarge)),
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                  child: Image.asset(
                    'assets/images/roundedlogo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(  // Changed from nothing to Flexible
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sign Out',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      user.fullName,
                      style: TextStyle(
                        fontSize: UIConstants.fontSizeMedium,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to sign out?',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              SizedBox(height: UIConstants.spacing8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning10,
                  borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                  border: Border.all(color: AppColors.warning),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You will need to sign in again to access your papers.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: UIConstants.fontSizeSmall,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _isLoggingOut ? null : () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: _isLoggingOut ? null : () => _handleLogout(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isLoggingOut ? AppColors.textTertiary : AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                ),
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
                  : const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  void _handleLogout(BuildContext context) {
    // Prevent multiple logout attempts
    if (_isLoggingOut) {
      return;
    }

    setState(() => _isLoggingOut = true);
    _logoutAnimationController.repeat();
    Navigator.of(context).pop();

    // Check if AuthBloc is available
    try {
      final authBloc = context.read<AuthBloc>();

      if (authBloc.isClosed) {
        AppLogger.error('AuthBloc is closed during logout', category: LogCategory.auth);
        setState(() => _isLoggingOut = false);
        _logoutAnimationController.stop();
        return;
      }

      authBloc.add(const AuthSignOut());

    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to get AuthBloc during logout',
        category: LogCategory.auth,
        error: e,
        stackTrace: stackTrace,
      );
      setState(() => _isLoggingOut = false);
      _logoutAnimationController.stop();
    }
  }

  String _getRoleDisplayName(UserRole role) {
    return role.displayName;
  }

  List<Widget> _getPages() {
    return _isAdmin ? widget.adminPages : widget.teacherPages;
  }

  List<_NavItem> _getNavigationItems() {
    if (_isAdmin) {
      // Admin navigation: Admin Dashboard, Question Bank, Settings
      return [
        _NavItem(
          icon: Icons.admin_panel_settings_outlined,
          activeIcon: Icons.admin_panel_settings,
          label: 'Admin',
          semanticLabel: 'Admin dashboard',
        ),
        _NavItem(
          icon: Icons.library_books_outlined,
          activeIcon: Icons.library_books,
          label: 'Bank',
          semanticLabel: 'Question bank',
        ),
        _NavItem(
          icon: Icons.settings_outlined,
          activeIcon: Icons.settings,
          label: 'Settings',
          semanticLabel: 'Settings and preferences',
        ),
      ];
    } else {
      // Teacher navigation: Home, Question Bank ONLY (no Settings)
      return [
        _NavItem(
          icon: Icons.home_rounded,
          activeIcon: Icons.home,
          label: 'Home',
          semanticLabel: 'Home page',
        ),
        _NavItem(
          icon: Icons.library_books_outlined,
          activeIcon: Icons.library_books,
          label: 'Bank',
          semanticLabel: 'Question bank',
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: _handleAuthStateChanges,
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthLoading && !_isLoggingOut) {
            return _buildLoadingScaffold();
          }

          if (state is! AuthAuthenticated) {
            return _buildUnauthenticatedScaffold();
          }

          final user = state.user;
          final pages = _getPages();
          final navigationItems = _getNavigationItems();

          // Ensure selected index is within bounds and set to default if needed
          if (_selectedIndex >= pages.length) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() => _selectedIndex = _getDefaultScreenIndex());
            });
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 768;

              return Scaffold(
                backgroundColor: AppColors.background,
                appBar: _buildAppBar(context, user, isMobile),
                body: AnimatedBuilder(
                  animation: _tabAnimation,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _tabAnimation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.05, 0),
                          end: Offset.zero,
                        ).animate(_tabAnimation),
                        child: IndexedStack(
                          index: _selectedIndex.clamp(0, pages.length - 1),
                          children: pages,
                        ),
                      ),
                    );
                  },
                ),
                bottomNavigationBar: isMobile ? _buildBottomNav(navigationItems) : null,
                drawer: !isMobile ? _buildDrawer(context, user, navigationItems) : null,
              );
            },
          );
        },
      ),
    );
  }

  void _handleAuthStateChanges(BuildContext context, AuthState state) {
    // Handle logout errors first, before resetting the flag
    if (state is AuthError && _isLoggingOut) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign out failed: ${state.message}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
          ),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _handleLogout(context),
          ),
        ),
      );
    }

    // Then reset the logging out flag for any non-loading state
    if (_isLoggingOut && state is! AuthLoading) {
      setState(() => _isLoggingOut = false);
      _logoutAnimationController.stop();
      _logoutAnimationController.reset();
    }

    if (state is AuthAuthenticated) {
      _checkUserRole();
    }
  }

  Widget _buildLoadingScaffold() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.asset(
                  'assets/images/roundedlogo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SizedBox(height: UIConstants.spacing24),
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            SizedBox(height: UIConstants.spacing16),
            Text(
              'Loading your workspace...',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnauthenticatedScaffold() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 64,
              color: AppColors.textTertiary,
            ),
            SizedBox(height: UIConstants.spacing16),
            Text(
              'Authentication Required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: UIConstants.spacing8),
            Text(
              'Please sign in to access your papers',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, dynamic user, bool isMobile) {
    return AppBar(
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              child: Image.asset(
                'assets/images/roundedlogo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getPageTitle(_selectedIndex),  // Dynamic page title
                style: TextStyle(
                  fontSize: isMobile ? 18 : 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (_getPageSubtitle(_selectedIndex).isNotEmpty)
                Text(
                  _getPageSubtitle(_selectedIndex),  // Dynamic subtitle
                  style: TextStyle(
                    fontSize: UIConstants.fontSizeSmall,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          if (!isMobile) ...[
            const Spacer(),
            // Removed the old page title badge since title is now in main area
          ],
        ],
      ),
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
      actions: [
        // User info section for mobile - properly aligned
        if (isMobile) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildRoleBadge(user.role, true),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showLogoutDialog(context, user),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary30,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: UIConstants.fontSizeMedium,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ],
      leading: !isMobile ? Builder(
        builder: (context) => IconButton(
          icon: Icon(Icons.menu_rounded, color: AppColors.textPrimary),
          onPressed: () => Scaffold.of(context).openDrawer(),
          tooltip: 'Open navigation menu',
        ),
      ) : null,
    );
  }

  Widget _buildRoleBadge(UserRole role, bool isMobile) {
    final isAdminRole = role == UserRole.admin || role == UserRole.teacher;
    return Container(
      height: isMobile ? 24 : 28, // Fixed height for better alignment
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        gradient: isAdminRole ? AppColors.accentGradient : null,
        color: isAdminRole ? null : AppColors.primary10,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        border: isAdminRole ? null : Border.all(
          color: AppColors.primary20,
        ),
      ),
      child: Center(
        child: Text(
          _getRoleDisplayName(role),
          style: TextStyle(
            color: isAdminRole ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.w700,
            fontSize: isMobile ? 10 : 11,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildBottomNav(List<_NavItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: AppColors.black08,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,  // Changed from spaceAround
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = _selectedIndex == index;

              return Semantics(
                label: item.semanticLabel,
                button: true,
                selected: isSelected,
                child: GestureDetector(
                  onTap: () => _onItemTapped(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isSelected ? AppColors.primaryGradient : null,
                      borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected ? item.activeIcon : item.icon,
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          size: 24,
                        ),
                        SizedBox(height: UIConstants.spacing4),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: UIConstants.fontSizeSmall,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, dynamic user, List<_NavItem> items) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(UIConstants.paddingLarge),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.white20,
                      borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                    ),
                    child: Center(
                      child: Text(
                        user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: UIConstants.spacing16),
                  Text(
                    user.fullName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: UIConstants.spacing4),
                  Text(
                    user.email ?? '',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: UIConstants.fontSizeMedium,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: UIConstants.spacing12),
                  _buildRoleBadge(user.role, false),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final isSelected = _selectedIndex == index;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: isSelected ? AppColors.primaryGradient : null,
                        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                      ),
                      child: Semantics(  // Removed Flexible, added child
                        label: item.semanticLabel,
                        button: true,
                        selected: isSelected,
                        child: ListTile(
                          leading: Icon(
                            isSelected ? item.activeIcon : item.icon,
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                          ),
                          title: Text(
                            item.label,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                          onTap: () {
                            _onItemTapped(index);
                            Navigator.pop(context);
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(12),
              child: Semantics(
                label: 'Sign out of your account',
                button: true,
                child: ListTile(
                  leading: AnimatedBuilder(
                    animation: _logoutAnimationController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _logoutAnimationController.value * 2 * 3.141592653589793,
                        child: _isLoggingOut
                            ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.error),
                          ),
                        )
                            : Icon(Icons.logout_rounded, color: AppColors.error),
                      );
                    },
                  ),
                  title: Text(
                    'Sign Out',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: _isLoggingOut ? null : () {
                    Navigator.pop(context);
                    _showLogoutDialog(context, user);
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPageTitle(int index) {
    if (_isAdmin) {
      switch (index) {
        case 0: return 'Admin Dashboard';
        case 1: return 'Question Bank';
        case 2: return 'Settings';
        default: return 'Papercraft';
      }
    } else {
      switch (index) {
        case 0: return 'Home';
        case 1: return 'Question Bank';
        default: return 'Papercraft';
      }
    }
  }

  // Add this helper method to get subtitles
  String _getPageSubtitle(int index) {
    if (_isAdmin) {
      switch (index) {
        case 0: return 'Manage papers and users';
        case 1: return 'Approved question papers';
        case 2: return 'Preferences and account';
        default: return '';
      }
    } else {
      switch (index) {
        case 0: return 'Create and manage papers';
        case 1: return 'Approved question papers';
        default: return '';
      }
    }
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String semanticLabel;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.semanticLabel,
  });
}