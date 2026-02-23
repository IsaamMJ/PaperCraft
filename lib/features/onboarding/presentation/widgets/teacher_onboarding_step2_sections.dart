import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../admin/domain/entities/admin_setup_grade.dart';
import '../../../admin/domain/entities/admin_setup_section.dart';
import '../../../admin/presentation/bloc/admin_setup_bloc.dart';
import '../../../admin/presentation/bloc/admin_setup_event.dart';

/// Step 2: Beautiful section selection with expandable grade cards
/// Each grade shows its available sections with visual feedback
class TeacherOnboardingStep2Sections extends StatefulWidget {
  /// Grades the teacher chose in step 1
  final List<AdminSetupGrade> selectedGrades;
  /// All sections available per grade number, keyed by grade number
  final Map<int, List<AdminSetupSection>> availableSectionsPerGrade;
  /// Sections the teacher has currently selected, keyed by grade number
  final Map<int, List<String>> sectionsPerGrade;

  const TeacherOnboardingStep2Sections({
    Key? key,
    required this.selectedGrades,
    required this.availableSectionsPerGrade,
    required this.sectionsPerGrade,
  }) : super(key: key);

  @override
  State<TeacherOnboardingStep2Sections> createState() =>
      _TeacherOnboardingStep2SectionsState();
}

class _TeacherOnboardingStep2SectionsState
    extends State<TeacherOnboardingStep2Sections>
    with TickerProviderStateMixin {
  late AnimationController _staggerController;
  late final Map<int, bool> _expandedState;

  // Section emojis for visual variety
  static const List<String> _sectionEmojis = ['📗', '📘', '📙', '📕', '📓', '📔'];

  // Grade gradients matching step 1
  static const List<List<Color>> _gradeGradients = [
    [Color(0xFF667eea), Color(0xFF764ba2)],
    [Color(0xFF11998e), Color(0xFF38ef7d)],
    [Color(0xFFf093fb), Color(0xFFf5576c)],
    [Color(0xFF4facfe), Color(0xFF00f2fe)],
    [Color(0xFFfa709a), Color(0xFFfee140)],
    [Color(0xFF30cfd0), Color(0xFF330867)],
    [Color(0xFFa8edea), Color(0xFFfed6e3)],
    [Color(0xFF5ee7df), Color(0xFFb490ca)],
    [Color(0xFFd299c2), Color(0xFFfef9d7)],
    [Color(0xFF89f7fe), Color(0xFF66a6ff)],
    [Color(0xFFf6d365), Color(0xFFfda085)],
    [Color(0xFF96fbc4), Color(0xFFf9f586)],
  ];

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _expandedState = {
      for (final grade in widget.selectedGrades) grade.gradeNumber: true,
    };
    _staggerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  List<Color> _getGradientForGrade(int grade) {
    final index = (grade - 1) % _gradeGradients.length;
    return _gradeGradients[index];
  }

  String _getSectionEmoji(int index) {
    return _sectionEmojis[index % _sectionEmojis.length];
  }

  void _toggleExpanded(int gradeNumber) {
    HapticFeedback.selectionClick();
    setState(() {
      _expandedState[gradeNumber] = !(_expandedState[gradeNumber] ?? true);
    });
  }

  void _selectAll(BuildContext context, int gradeNumber, List<AdminSetupSection> available) {
    HapticFeedback.mediumImpact();
    for (final section in available) {
      final selected = widget.sectionsPerGrade[gradeNumber] ?? [];
      if (!selected.contains(section.sectionName)) {
        context.read<AdminSetupBloc>().add(
          AddSectionEvent(
            gradeNumber: gradeNumber,
            sectionName: section.sectionName,
          ),
        );
      }
    }
  }

  void _clearAll(BuildContext context, int gradeNumber, List<AdminSetupSection> available) {
    HapticFeedback.mediumImpact();
    for (final section in available) {
      final selected = widget.sectionsPerGrade[gradeNumber] ?? [];
      if (selected.contains(section.sectionName)) {
        context.read<AdminSetupBloc>().add(
          RemoveSectionEvent(
            gradeNumber: gradeNumber,
            sectionName: section.sectionName,
          ),
        );
      }
    }
  }

  int get _totalSelectedCount {
    int count = 0;
    for (final sections in widget.sectionsPerGrade.values) {
      count += sections.length;
    }
    return count;
  }

  // Responsive breakpoints
  static const double _maxContentWidth = 800;
  static const double _tabletBreakpoint = 600;

  @override
  Widget build(BuildContext context) {
    final sortedGrades = widget.selectedGrades.toList()
      ..sort((a, b) => a.gradeNumber.compareTo(b.gradeNumber));

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
              // Hero header
              _HeroHeader(totalSelected: _totalSelectedCount),

              const SizedBox(height: 24),

              // Grade cards
              ...List.generate(sortedGrades.length, (index) {
                final grade = sortedGrades[index];
                final gradeNumber = grade.gradeNumber;
                final available = widget.availableSectionsPerGrade[gradeNumber] ?? [];
                final selected = widget.sectionsPerGrade[gradeNumber] ?? [];
                final isExpanded = _expandedState[gradeNumber] ?? true;

                // Staggered animation
                final delay = index * 0.12;
                final animation = CurvedAnimation(
                  parent: _staggerController,
                  curve: Interval(
                    delay.clamp(0.0, 0.6),
                    (delay + 0.4).clamp(0.0, 1.0),
                    curve: Curves.easeOutCubic,
                  ),
                );

                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, 20 * (1 - animation.value)),
                    child: Opacity(
                      opacity: animation.value,
                      child: child,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(bottom: index < sortedGrades.length - 1 ? 16 : 0),
                    child: _GradeCard(
                      gradeNumber: gradeNumber,
                      gradient: _getGradientForGrade(gradeNumber),
                      availableSections: available,
                      selectedSections: selected,
                      isExpanded: isExpanded,
                      sectionEmojis: _sectionEmojis,
                      onToggleExpanded: () => _toggleExpanded(gradeNumber),
                      onSelectAll: () => _selectAll(context, gradeNumber, available),
                      onClearAll: () => _clearAll(context, gradeNumber, available),
                      onSectionToggle: (sectionName) {
                        HapticFeedback.lightImpact();
                        if (selected.contains(sectionName)) {
                          context.read<AdminSetupBloc>().add(
                            RemoveSectionEvent(
                              gradeNumber: gradeNumber,
                              sectionName: sectionName,
                            ),
                          );
                        } else {
                          context.read<AdminSetupBloc>().add(
                            AddSectionEvent(
                              gradeNumber: gradeNumber,
                              sectionName: sectionName,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                );
              }),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Hero Header
// =============================================================================

class _HeroHeader extends StatelessWidget {
  final int totalSelected;

  const _HeroHeader({required this.totalSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF11998e).withValues(alpha:0.4),
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
                  Icons.grid_view_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose Your Sections',
                      style: TextStyle(
                        fontSize: 22,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select sections for each grade',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha:0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (totalSelected > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '$totalSelected section${totalSelected != 1 ? 's' : ''} selected',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
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
// Grade Card with expandable sections
// =============================================================================

class _GradeCard extends StatelessWidget {
  final int gradeNumber;
  final List<Color> gradient;
  final List<AdminSetupSection> availableSections;
  final List<String> selectedSections;
  final bool isExpanded;
  final List<String> sectionEmojis;
  final VoidCallback onToggleExpanded;
  final VoidCallback onSelectAll;
  final VoidCallback onClearAll;
  final Function(String) onSectionToggle;

  const _GradeCard({
    required this.gradeNumber,
    required this.gradient,
    required this.availableSections,
    required this.selectedSections,
    required this.isExpanded,
    required this.sectionEmojis,
    required this.onToggleExpanded,
    required this.onSelectAll,
    required this.onClearAll,
    required this.onSectionToggle,
  });

  @override
  Widget build(BuildContext context) {
    final allSelected = selectedSections.length == availableSections.length &&
                        availableSections.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header - always visible
          GestureDetector(
            onTap: onToggleExpanded,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                ),
                borderRadius: isExpanded
                    ? const BorderRadius.vertical(top: Radius.circular(20))
                    : BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  // Grade badge
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha:0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        '$gradeNumber',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Grade $gradeNumber',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${selectedSections.length} of ${availableSections.length} sections',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha:0.85),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Progress indicator
                  if (availableSections.isNotEmpty) ...[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha:0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              value: availableSections.isEmpty
                                  ? 0
                                  : selectedSections.length / availableSections.length,
                              strokeWidth: 3,
                              backgroundColor: Colors.white.withValues(alpha:0.3),
                              valueColor: const AlwaysStoppedAnimation(Colors.white),
                            ),
                          ),
                          if (allSelected)
                            const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Expand/collapse icon
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: isExpanded ? 0.5 : 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha:0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expandable content
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: isExpanded
                ? Column(
                    children: [
                      // Quick actions
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundSecondary,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _QuickActionChip(
                                icon: Icons.select_all_rounded,
                                label: 'Select All',
                                isEnabled: !allSelected && availableSections.isNotEmpty,
                                onTap: onSelectAll,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _QuickActionChip(
                                icon: Icons.clear_all_rounded,
                                label: 'Clear',
                                isEnabled: selectedSections.isNotEmpty,
                                onTap: onClearAll,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Section chips
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: availableSections.isEmpty
                            ? _EmptySections()
                            : Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: availableSections.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final section = entry.value;
                                  final isSelected = selectedSections.contains(section.sectionName);
                                  return _SectionChip(
                                    sectionName: section.sectionName,
                                    emoji: sectionEmojis[index % sectionEmojis.length],
                                    isSelected: isSelected,
                                    gradientColors: gradient,
                                    onTap: () => onSectionToggle(section.sectionName),
                                  );
                                }).toList(),
                              ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Section Chip - Large, tappable
// =============================================================================

class _SectionChip extends StatefulWidget {
  final String sectionName;
  final String emoji;
  final bool isSelected;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _SectionChip({
    required this.sectionName,
    required this.emoji,
    required this.isSelected,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  State<_SectionChip> createState() => _SectionChipState();
}

class _SectionChipState extends State<_SectionChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: widget.isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.gradientColors,
                  )
                : null,
            color: widget.isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isSelected
                  ? Colors.transparent
                  : AppColors.border,
              width: 1.5,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: widget.gradientColors[0].withValues(alpha:0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha:0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Text(
                'Section ${widget.sectionName}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: widget.isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? Colors.white.withValues(alpha:0.25)
                      : AppColors.backgroundSecondary,
                  shape: BoxShape.circle,
                  border: widget.isSelected
                      ? null
                      : Border.all(color: AppColors.border, width: 1.5),
                ),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: widget.isSelected ? 1.0 : 0.0,
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
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
// Quick Action Chip
// =============================================================================

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isEnabled;
  final VoidCallback onTap;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.isEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isEnabled ? Colors.white : Colors.white.withValues(alpha:0.5),
          borderRadius: BorderRadius.circular(10),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha:0.04),
                    blurRadius: 4,
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
              size: 16,
              color: isEnabled ? AppColors.primary : AppColors.textTertiary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
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
// Empty Sections State
// =============================================================================

class _EmptySections extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha:0.15),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('📭', style: TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No sections available',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
