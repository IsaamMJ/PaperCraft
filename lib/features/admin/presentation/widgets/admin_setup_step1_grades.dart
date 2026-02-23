import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../domain/entities/admin_setup_grade.dart';
import '../bloc/admin_setup_bloc.dart';
import '../bloc/admin_setup_event.dart';

/// Step 1: School details entry and grade selection with modern animated UI
class AdminSetupStep1Grades extends StatefulWidget {
  final List<AdminSetupGrade> selectedGrades;
  final String schoolName;
  final String schoolAddress;

  const AdminSetupStep1Grades({
    Key? key,
    required this.selectedGrades,
    required this.schoolName,
    required this.schoolAddress,
  }) : super(key: key);

  @override
  State<AdminSetupStep1Grades> createState() => _AdminSetupStep1GradesState();
}

class _AdminSetupStep1GradesState extends State<AdminSetupStep1Grades>
    with TickerProviderStateMixin {
  late TextEditingController _schoolNameController;
  late TextEditingController _schoolAddressController;
  late AnimationController _staggerController;
  late AnimationController _selectionController;

  static const List<int> _availableGrades = [
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12,
  ];

  static const List<List<Color>> _gradeGradients = [
    [Color(0xFF667eea), Color(0xFF764ba2)], // Grade 1
    [Color(0xFF11998e), Color(0xFF38ef7d)], // Grade 2
    [Color(0xFFf093fb), Color(0xFFf5576c)], // Grade 3
    [Color(0xFF4facfe), Color(0xFF00f2fe)], // Grade 4
    [Color(0xFFfa709a), Color(0xFFfee140)], // Grade 5
    [Color(0xFF30cfd0), Color(0xFF330867)], // Grade 6
    [Color(0xFFa8edea), Color(0xFFfed6e3)], // Grade 7
    [Color(0xFF5ee7df), Color(0xFFb490ca)], // Grade 8
    [Color(0xFFd299c2), Color(0xFFfef9d7)], // Grade 9
    [Color(0xFF89f7fe), Color(0xFF66a6ff)], // Grade 10
    [Color(0xFFf6d365), Color(0xFFfda085)], // Grade 11
    [Color(0xFF96fbc4), Color(0xFFf9f586)], // Grade 12
  ];

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
    _schoolNameController = TextEditingController(text: widget.schoolName);
    _schoolAddressController = TextEditingController(text: widget.schoolAddress);

    _schoolNameController.addListener(_onSchoolDetailsChanged);
    _schoolAddressController.addListener(_onSchoolDetailsChanged);

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
    _schoolNameController.removeListener(_onSchoolDetailsChanged);
    _schoolAddressController.removeListener(_onSchoolDetailsChanged);
    _schoolNameController.dispose();
    _schoolAddressController.dispose();
    _staggerController.dispose();
    _selectionController.dispose();
    super.dispose();
  }

  void _onSchoolDetailsChanged() {
    context.read<AdminSetupBloc>().add(
      UpdateSchoolDetailsEvent(
        schoolName: _schoolNameController.text,
        schoolAddress: _schoolAddressController.text,
      ),
    );
  }

  List<Color> _getGradientForGrade(int grade) {
    final index = (grade - 1) % _gradeGradients.length;
    return _gradeGradients[index];
  }

  String _getEmojiForGrade(int grade) {
    final index = (grade - 1) % _gradeEmojis.length;
    return _gradeEmojis[index];
  }

  void _bulkAddGrades(List<int> grades) {
    HapticFeedback.mediumImpact();
    for (final grade in grades) {
      final isSelected = widget.selectedGrades.any((g) => g.gradeNumber == grade);
      if (!isSelected) {
        context.read<AdminSetupBloc>().add(AddGradeEvent(gradeNumber: grade));
      }
    }
  }

  static const double _maxContentWidth = 800;
  static const double _tabletBreakpoint = 600;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth >= _tabletBreakpoint;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        isLargeScreen ? 32 : 20,
        24,
        isLargeScreen ? 32 : 20,
        32,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero card
              _HeroCard(
                schoolName: _schoolNameController.text.isNotEmpty
                    ? _schoolNameController.text
                    : widget.schoolName,
                schoolAddress: _schoolAddressController.text.isNotEmpty
                    ? _schoolAddressController.text
                    : widget.schoolAddress,
              ),

              const SizedBox(height: 24),

              // School details card
              _SchoolDetailsCard(
                nameController: _schoolNameController,
                addressController: _schoolAddressController,
              ),

              const SizedBox(height: 28),

              // Grade selection header with badge
              _GradeSectionHeader(
                selectedCount: widget.selectedGrades.length,
              ),

              const SizedBox(height: 16),

              // Quick-add buttons
              _QuickAddButtons(
                selectedGrades: widget.selectedGrades,
                onBulkAdd: _bulkAddGrades,
              ),

              const SizedBox(height: 20),

              // Grade cards grid
              _buildGradeGrid(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradeGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final int columns;
        final double maxCardWidth;

        if (screenWidth >= 1200) {
          columns = 5;
          maxCardWidth = 180;
        } else if (screenWidth >= 900) {
          columns = 4;
          maxCardWidth = 200;
        } else if (screenWidth >= 600) {
          columns = 3;
          maxCardWidth = 220;
        } else {
          columns = 2;
          maxCardWidth = double.infinity;
        }

        const spacing = 16.0;
        final totalSpacing = spacing * (columns - 1);
        final calculatedWidth = (screenWidth - totalSpacing) / columns;
        final itemWidth = maxCardWidth == double.infinity
            ? calculatedWidth
            : calculatedWidth.clamp(0.0, maxCardWidth);
        final itemHeight = itemWidth * 0.75;

        return Wrap(
          alignment: WrapAlignment.center,
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(_availableGrades.length, (index) {
            final grade = _availableGrades[index];
            final isSelected =
                widget.selectedGrades.any((g) => g.gradeNumber == grade);

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
                  opacity: animation.value.clamp(0.0, 1.0),
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
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (isSelected) {
                      context.read<AdminSetupBloc>().add(
                        RemoveGradeEvent(gradeNumber: grade),
                      );
                    } else {
                      context.read<AdminSetupBloc>().add(
                        AddGradeEvent(gradeNumber: grade),
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
// Hero Card
// =============================================================================

class _HeroCard extends StatelessWidget {
  final String schoolName;
  final String schoolAddress;

  const _HeroCard({
    required this.schoolName,
    required this.schoolAddress,
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
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withValues(alpha: 0.4),
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
                  color: Colors.white.withValues(alpha: 0.2),
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
                      'School Setup',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      schoolName.isNotEmpty ? schoolName : 'Your School',
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
          if (schoolAddress.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      schoolAddress,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
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
// School Details Card
// =============================================================================

class _SchoolDetailsCard extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController addressController;

  const _SchoolDetailsCard({
    required this.nameController,
    required this.addressController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'School Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Enter your school information',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: nameController,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'School Name',
              hintText: 'Enter your school name',
              prefixIcon: const Icon(
                Icons.school_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              filled: true,
              fillColor: AppColors.backgroundSecondary,
              labelStyle: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              hintStyle: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: addressController,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'School Address',
              hintText: 'Enter school address (city, state)',
              prefixIcon: const Icon(
                Icons.location_on_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              filled: true,
              fillColor: AppColors.backgroundSecondary,
              labelStyle: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              hintStyle: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            maxLines: 2,
            minLines: 1,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Grade Section Header with animated selection badge
// =============================================================================

class _GradeSectionHeader extends StatelessWidget {
  final int selectedCount;

  const _GradeSectionHeader({required this.selectedCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select School Grades',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Which grades does your school teach?',
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
                  color: AppColors.primary.withValues(alpha: 0.3),
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
    );
  }
}

// =============================================================================
// Quick-add buttons: Primary / Middle / High / Higher
// =============================================================================

class _QuickAddButtons extends StatelessWidget {
  final List<AdminSetupGrade> selectedGrades;
  final void Function(List<int> grades) onBulkAdd;

  const _QuickAddButtons({
    required this.selectedGrades,
    required this.onBulkAdd,
  });

  static const _groups = [
    _GradeGroup(label: 'Primary\n1-5', grades: [1, 2, 3, 4, 5]),
    _GradeGroup(label: 'Middle\n6-8', grades: [6, 7, 8]),
    _GradeGroup(label: 'High\n9-10', grades: [9, 10]),
    _GradeGroup(label: 'Higher\n11-12', grades: [11, 12]),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Add',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _groups.map((group) {
              final allSelected = group.grades
                  .every((g) => selectedGrades.any((sg) => sg.gradeNumber == g));
              return GestureDetector(
                onTap: () => onBulkAdd(group.grades),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: allSelected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : AppColors.surface,
                    border: Border.all(
                      color: allSelected ? AppColors.primary : AppColors.border,
                      width: allSelected ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: allSelected
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Text(
                    group.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: allSelected ? AppColors.primary : AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _GradeGroup {
  final String label;
  final List<int> grades;

  const _GradeGroup({required this.label, required this.grades});
}

// =============================================================================
// Grade Card - Animated, tappable with press scale
// =============================================================================

class _GradeCard extends StatefulWidget {
  final int grade;
  final bool isSelected;
  final List<Color> gradient;
  final String emoji;
  final VoidCallback onTap;

  const _GradeCard({
    required this.grade,
    required this.isSelected,
    required this.gradient,
    required this.emoji,
    required this.onTap,
  });

  @override
  State<_GradeCard> createState() => _GradeCardState();
}

class _GradeCardState extends State<_GradeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

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

  void _handleTapDown(TapDownDetails details) => _controller.forward();

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _handleTapCancel() => _controller.reverse();

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
          duration: const Duration(milliseconds: 200),
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
              color: widget.isSelected ? Colors.transparent : AppColors.border,
              width: 1.5,
            ),
            boxShadow: [
              if (widget.isSelected)
                BoxShadow(
                  color: widget.gradient[0].withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Stack(
            children: [
              // Background emoji watermark for selected state
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
                    // Emoji and check indicator
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
                                ? Colors.white.withValues(alpha: 0.25)
                                : AppColors.backgroundSecondary,
                            shape: BoxShape.circle,
                            border: widget.isSelected
                                ? null
                                : Border.all(
                                    color: AppColors.border,
                                    width: 2,
                                  ),
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

                    // Grade label
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
                          widget.isSelected ? 'Selected' : 'Tap to select',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: widget.isSelected
                                ? Colors.white.withValues(alpha: 0.85)
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
