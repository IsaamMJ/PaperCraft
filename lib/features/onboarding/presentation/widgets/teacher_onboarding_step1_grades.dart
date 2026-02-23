import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../admin/domain/entities/admin_setup_grade.dart';
import '../../../admin/presentation/bloc/admin_setup_bloc.dart';
import '../../../admin/presentation/bloc/admin_setup_event.dart';

/// Step 1: Beautiful grade selection with large, tappable cards
/// Each grade has a unique color and emoji for visual appeal
class TeacherOnboardingStep1Grades extends StatefulWidget {
  /// Grades the teacher has already selected
  final List<AdminSetupGrade> selectedGrades;
  /// All grades configured for the school that the teacher can choose from
  final List<AdminSetupGrade> availableGrades;
  /// Display name of the school shown in the welcome card
  final String? schoolName;
  /// Physical address of the school shown beneath the school name
  final String? schoolAddress;
  /// Called when the user taps "Check Again" in the empty state
  final VoidCallback? onRefresh;
  /// Whether to highlight the grade grid with an error when no grade is selected
  final bool showValidationError;

  const TeacherOnboardingStep1Grades({
    Key? key,
    required this.selectedGrades,
    required this.availableGrades,
    this.schoolName,
    this.schoolAddress,
    this.onRefresh,
    this.showValidationError = false,
  }) : super(key: key);

  @override
  State<TeacherOnboardingStep1Grades> createState() =>
      _TeacherOnboardingStep1GradesState();
}

class _TeacherOnboardingStep1GradesState
    extends State<TeacherOnboardingStep1Grades>
    with TickerProviderStateMixin {
  late AnimationController _staggerController;
  late AnimationController _selectionController;
  bool _isRefreshing = false;

  // Beautiful gradient colors for each grade
  static const List<List<Color>> _gradeGradients = [
    [Color(0xFF667eea), Color(0xFF764ba2)], // Grade 1 - Purple
    [Color(0xFF11998e), Color(0xFF38ef7d)], // Grade 2 - Teal-Green
    [Color(0xFFf093fb), Color(0xFFf5576c)], // Grade 3 - Pink
    [Color(0xFF4facfe), Color(0xFF00f2fe)], // Grade 4 - Blue-Cyan
    [Color(0xFFfa709a), Color(0xFFfee140)], // Grade 5 - Pink-Yellow
    [Color(0xFF30cfd0), Color(0xFF330867)], // Grade 6 - Cyan-Purple
    [Color(0xFFa8edea), Color(0xFFfed6e3)], // Grade 7 - Mint-Pink
    [Color(0xFF5ee7df), Color(0xFFb490ca)], // Grade 8 - Teal-Lavender
    [Color(0xFFd299c2), Color(0xFFfef9d7)], // Grade 9 - Rose-Cream
    [Color(0xFF89f7fe), Color(0xFF66a6ff)], // Grade 10 - Sky Blue
    [Color(0xFFf6d365), Color(0xFFfda085)], // Grade 11 - Orange
    [Color(0xFF96fbc4), Color(0xFFf9f586)], // Grade 12 - Green-Yellow
  ];

  // Emojis for each grade to make them fun and memorable
  static const List<String> _gradeEmojis = [
    '🌟', // Grade 1
    '🚀', // Grade 2
    '🎨', // Grade 3
    '🔬', // Grade 4
    '📚', // Grade 5
    '🎯', // Grade 6
    '💡', // Grade 7
    '🏆', // Grade 8
    '🎓', // Grade 9
    '⭐', // Grade 10
    '🔥', // Grade 11
    '👑', // Grade 12
  ];

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _selectionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _staggerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _selectionController.dispose();
    super.dispose();
  }

  List<Color> _getGradientForGrade(int grade) {
    final index = (grade - 1) % _gradeGradients.length;
    return _gradeGradients[index];
  }

  String _getEmojiForGrade(int grade) {
    final index = (grade - 1) % _gradeEmojis.length;
    return _gradeEmojis[index];
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    HapticFeedback.mediumImpact();
    widget.onRefresh?.call();
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) setState(() => _isRefreshing = false);
  }

  // Responsive breakpoints
  static const double _maxContentWidth = 800; // Max content width for large screens
  static const double _tabletBreakpoint = 600;

  @override
  Widget build(BuildContext context) {
    final gradeNumbers = widget.availableGrades
        .map((g) => g.gradeNumber)
        .toList()
      ..sort();

    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth >= _tabletBreakpoint;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        isLargeScreen ? 32 : 20,
        24,
        isLargeScreen ? 32 : 20,
        8,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome hero card
              if (widget.schoolName != null) _WelcomeCard(
                schoolName: widget.schoolName!,
                schoolAddress: widget.schoolAddress,
              ),

              const SizedBox(height: 28),

              // Section title with selection count
              _SectionTitle(
                selectedCount: widget.selectedGrades.length,
                totalCount: gradeNumbers.length,
                showError: widget.showValidationError && widget.selectedGrades.isEmpty,
              ),

              const SizedBox(height: 16),

              // Grade grid - 2 columns for larger, more tappable cards
              if (gradeNumbers.isEmpty)
                _EmptyState(
                  isRefreshing: _isRefreshing,
                  onRefresh: widget.onRefresh != null ? _handleRefresh : null,
                )
              else
                _buildGradeGrid(gradeNumbers),

              // Quick actions
              if (gradeNumbers.isNotEmpty) ...[
                const SizedBox(height: 20),
                _QuickActions(
                  selectedCount: widget.selectedGrades.length,
                  totalCount: gradeNumbers.length,
                  onSelectAll: () {
                    HapticFeedback.mediumImpact();
                    for (final grade in widget.availableGrades) {
                      if (!widget.selectedGrades.any((g) => g.gradeNumber == grade.gradeNumber)) {
                        context.read<AdminSetupBloc>().add(
                          AddGradeEvent(
                            gradeNumber: grade.gradeNumber,
                            gradeId: grade.gradeId,
                          ),
                        );
                      }
                    }
                  },
                  onClearAll: () {
                    HapticFeedback.mediumImpact();
                    for (final grade in widget.selectedGrades) {
                      context.read<AdminSetupBloc>().add(
                        RemoveGradeEvent(gradeNumber: grade.gradeNumber),
                      );
                    }
                  },
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradeGrid(List<int> gradeNumbers) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive columns based on screen width
        final screenWidth = constraints.maxWidth;
        final int columns;
        final double maxCardWidth;

        if (screenWidth >= 1200) {
          // Large desktop: 5 columns, max card width 180
          columns = 5;
          maxCardWidth = 180;
        } else if (screenWidth >= 900) {
          // Desktop: 4 columns, max card width 200
          columns = 4;
          maxCardWidth = 200;
        } else if (screenWidth >= 600) {
          // Tablet: 3 columns, max card width 220
          columns = 3;
          maxCardWidth = 220;
        } else {
          // Mobile: 2 columns, no max (fill available space)
          columns = 2;
          maxCardWidth = double.infinity;
        }

        const spacing = 16.0;
        final totalSpacing = spacing * (columns - 1);
        final calculatedWidth = (screenWidth - totalSpacing) / columns;
        final itemWidth = maxCardWidth == double.infinity
            ? calculatedWidth
            : calculatedWidth.clamp(0.0, maxCardWidth);
        final itemHeight = itemWidth * 0.75; // Maintain aspect ratio

        return Wrap(
          alignment: WrapAlignment.center, // Center cards on larger screens
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(gradeNumbers.length, (index) {
            final grade = gradeNumbers[index];
            final isSelected = widget.selectedGrades.any((g) => g.gradeNumber == grade);

            // Staggered animation
            final delay = index * 0.08;
            final animation = CurvedAnimation(
              parent: _staggerController,
              curve: Interval(
                delay.clamp(0.0, 0.6),
                (delay + 0.4).clamp(0.0, 1.0),
                curve: Curves.easeOutBack,
              ),
            );

            return AnimatedBuilder(
              animation: animation,
              builder: (context, child) => Transform.scale(
                scale: animation.value,
                child: Opacity(
                  opacity: animation.value,
                  child: child,
                ),
              ),
              child: SizedBox(
                width: itemWidth,
                height: itemHeight,
                child: _GradeCard(
                  grade: grade,
                  isSelected: isSelected,
                  gradient: _getGradientForGrade(grade),
                  emoji: _getEmojiForGrade(grade),
                  showError: widget.showValidationError && widget.selectedGrades.isEmpty,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    final gradeMatches = widget.availableGrades.where(
                      (g) => g.gradeNumber == grade,
                    );
                    if (gradeMatches.isEmpty) return;
                    final gradeObject = gradeMatches.first;
                    if (isSelected) {
                      context.read<AdminSetupBloc>().add(
                        RemoveGradeEvent(gradeNumber: grade),
                      );
                    } else {
                      context.read<AdminSetupBloc>().add(
                        AddGradeEvent(
                          gradeNumber: grade,
                          gradeId: gradeObject.gradeId,
                        ),
                      );
                    }
                  },
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// =============================================================================
// Welcome Card - Hero section with school info
// =============================================================================

class _WelcomeCard extends StatelessWidget {
  final String schoolName;
  final String? schoolAddress;

  const _WelcomeCard({
    required this.schoolName,
    this.schoolAddress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF667eea),
            Color(0xFF764ba2),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withValues(alpha:0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha:0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha:0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      schoolName,
                      style: const TextStyle(
                        fontSize: 22,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (schoolAddress != null && schoolAddress!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    color: Colors.white.withValues(alpha:0.9),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      schoolAddress!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha:0.9),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// Section Title with count badge
// =============================================================================

class _SectionTitle extends StatelessWidget {
  final int selectedCount;
  final int totalCount;
  final bool showError;

  const _SectionTitle({
    required this.selectedCount,
    required this.totalCount,
    required this.showError,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Your Grades',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap the grades you\'ll be teaching',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (selectedCount > 0)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha:0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  '$selectedCount selected',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        if (showError) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withValues(alpha:0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Please select at least one grade to continue',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// Grade Card - Large, beautiful, tappable
// =============================================================================

class _GradeCard extends StatefulWidget {
  final int grade;
  final bool isSelected;
  final List<Color> gradient;
  final String emoji;
  final bool showError;
  final VoidCallback onTap;

  const _GradeCard({
    required this.grade,
    required this.isSelected,
    required this.gradient,
    required this.emoji,
    required this.showError,
    required this.onTap,
  });

  @override
  State<_GradeCard> createState() => _GradeCardState();
}

class _GradeCardState extends State<_GradeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: widget.isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.gradient,
                  )
                : null,
            color: widget.isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isSelected
                  ? Colors.transparent
                  : widget.showError
                      ? AppColors.error.withValues(alpha:0.5)
                      : AppColors.border,
              width: widget.showError ? 2 : 1.5,
            ),
            boxShadow: [
              if (widget.isSelected)
                BoxShadow(
                  color: widget.gradient[0].withValues(alpha:0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha:0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Stack(
            children: [
              // Background pattern for selected state
              if (widget.isSelected)
                Positioned(
                  right: -20,
                  bottom: -20,
                  child: Opacity(
                    opacity: 0.15,
                    child: Text(
                      widget.emoji,
                      style: const TextStyle(fontSize: 80),
                    ),
                  ),
                ),

              // Main content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Emoji and check mark row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.emoji,
                          style: const TextStyle(fontSize: 32),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: widget.isSelected
                                ? Colors.white.withValues(alpha:0.25)
                                : AppColors.backgroundSecondary,
                            shape: BoxShape.circle,
                            border: widget.isSelected
                                ? null
                                : Border.all(color: AppColors.border, width: 2),
                          ),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: widget.isSelected ? 1.0 : 0.0,
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Grade number and label
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Grade ${widget.grade}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: widget.isSelected
                                ? Colors.white
                                : AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.isSelected ? 'Selected ✓' : 'Tap to select',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: widget.isSelected
                                ? Colors.white.withValues(alpha:0.85)
                                : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Quick Actions - Select All / Clear All
// =============================================================================

class _QuickActions extends StatelessWidget {
  final int selectedCount;
  final int totalCount;
  final VoidCallback onSelectAll;
  final VoidCallback onClearAll;

  const _QuickActions({
    required this.selectedCount,
    required this.totalCount,
    required this.onSelectAll,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final allSelected = selectedCount == totalCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: Icons.select_all_rounded,
              label: 'Select All',
              isEnabled: !allSelected,
              onTap: allSelected ? null : onSelectAll,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionButton(
              icon: Icons.clear_all_rounded,
              label: 'Clear All',
              isEnabled: selectedCount > 0,
              onTap: selectedCount > 0 ? onClearAll : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isEnabled;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.isEnabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isEnabled ? Colors.white : Colors.white.withValues(alpha:0.5),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha:0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isEnabled ? AppColors.primary : AppColors.textTertiary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isEnabled ? AppColors.textPrimary : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Empty State
// =============================================================================

class _EmptyState extends StatelessWidget {
  final bool isRefreshing;
  final VoidCallback? onRefresh;

  const _EmptyState({
    required this.isRefreshing,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha:0.15),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('📚', style: TextStyle(fontSize: 36)),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Grades Available',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your school administrator hasn\'t set up any grades yet. '
            'Please contact them to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          if (onRefresh != null) ...[
            const SizedBox(height: 24),
            GestureDetector(
              onTap: isRefreshing ? null : onRefresh,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha:0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isRefreshing)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    else
                      const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      isRefreshing ? 'Checking...' : 'Check Again',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
