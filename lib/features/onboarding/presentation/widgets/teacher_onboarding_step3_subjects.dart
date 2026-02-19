import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../admin/domain/entities/admin_setup_grade.dart';
import '../../../admin/domain/entities/admin_setup_section.dart';
import '../../../admin/domain/entities/admin_setup_state.dart' as domain;
import '../../../admin/presentation/bloc/admin_setup_bloc.dart';
import '../../../admin/presentation/bloc/admin_setup_event.dart';

/// Step 3: Beautiful subject selection with expandable grade/section cards
/// Teachers select which subjects they teach for each section
class TeacherOnboardingStep3Subjects extends StatefulWidget {
  /// Grades the teacher chose in step 1
  final List<AdminSetupGrade> selectedGrades;
  /// All sections available per grade number, keyed by grade number
  final Map<int, List<AdminSetupSection>> availableSectionsPerGrade;
  /// Fallback subject list per grade when no per-section list is available
  final Map<int, List<String>> availableSubjectsPerGrade;
  /// Subject list per grade and section, keyed by grade number then section name
  final Map<int, Map<String, List<String>>> availableSubjectsPerGradePerSection;
  /// Current setup state holding the teacher's section and subject selections
  final domain.AdminSetupState setupState;

  const TeacherOnboardingStep3Subjects({
    Key? key,
    required this.selectedGrades,
    required this.availableSectionsPerGrade,
    required this.availableSubjectsPerGrade,
    required this.availableSubjectsPerGradePerSection,
    required this.setupState,
  }) : super(key: key);

  @override
  State<TeacherOnboardingStep3Subjects> createState() =>
      _TeacherOnboardingStep3SubjectsState();
}

class _TeacherOnboardingStep3SubjectsState
    extends State<TeacherOnboardingStep3Subjects>
    with TickerProviderStateMixin {
  late AnimationController _staggerController;
  late final Map<String, bool> _expandedState; // "grade-section" -> expanded

  // Subject emojis for visual variety
  static const Map<String, String> _subjectEmojis = {
    'math': '🔢',
    'mathematics': '🔢',
    'english': '📖',
    'science': '🔬',
    'history': '📜',
    'geography': '🌍',
    'physics': '⚛️',
    'chemistry': '🧪',
    'biology': '🧬',
    'computer': '💻',
    'art': '🎨',
    'music': '🎵',
    'pe': '⚽',
    'physical education': '⚽',
    'hindi': '📝',
    'social': '🌐',
    'evs': '🌱',
    'default': '📚',
  };

  // Grade gradients matching previous steps
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
    _expandedState = {};
    // Expand first section by default
    _initializeExpandedState();
    _staggerController.forward();
  }

  void _initializeExpandedState() {
    final sortedGrades = widget.selectedGrades.toList()
      ..sort((a, b) => a.gradeNumber.compareTo(b.gradeNumber));

    bool firstSet = false;
    for (final grade in sortedGrades) {
      final sections = widget.setupState.sectionsPerGrade[grade.gradeNumber] ?? [];
      for (final section in sections) {
        final key = '${grade.gradeNumber}-$section';
        if (!firstSet) {
          _expandedState[key] = true;
          firstSet = true;
        } else {
          _expandedState[key] = false;
        }
      }
    }
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

  String _getSubjectEmoji(String subject) {
    final lower = subject.toLowerCase();
    for (final entry in _subjectEmojis.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }
    return _subjectEmojis['default']!;
  }

  void _toggleExpanded(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      _expandedState[key] = !(_expandedState[key] ?? false);
    });
  }

  int get _totalSelectedCount {
    int count = 0;
    for (final subjects in widget.setupState.subjectsPerGradeSection.values) {
      count += subjects.length;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final sortedGrades = widget.selectedGrades.toList()
      ..sort((a, b) => a.gradeNumber.compareTo(b.gradeNumber));

    // Build a flat list of grade-section pairs for display
    final List<_GradeSectionPair> pairs = [];
    for (final grade in sortedGrades) {
      final sections = widget.setupState.sectionsPerGrade[grade.gradeNumber] ?? [];
      final sortedSections = sections.toList()..sort();
      for (final section in sortedSections) {
        pairs.add(_GradeSectionPair(
          gradeNumber: grade.gradeNumber,
          sectionName: section,
        ));
      }
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8), // More top padding for professional look
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero header
          _HeroHeader(totalSelected: _totalSelectedCount),

          const SizedBox(height: 24),

          // Section cards
          ...List.generate(pairs.length, (index) {
            final pair = pairs[index];
            final key = '${pair.gradeNumber}-${pair.sectionName}';
            final isExpanded = _expandedState[key] ?? false;

            // Get available subjects for this grade-section
            final availableSubjects = widget.availableSubjectsPerGradePerSection[pair.gradeNumber]?[pair.sectionName] ??
                                      widget.availableSubjectsPerGrade[pair.gradeNumber] ?? [];

            // Get selected subjects using the key format "grade:section"
            final selectedSubjects = widget.setupState.getSubjectsForGradeSection(pair.gradeNumber, pair.sectionName);

            // Staggered animation
            final delay = index * 0.1;
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
                padding: EdgeInsets.only(bottom: index < pairs.length - 1 ? 16 : 0),
                child: _SectionCard(
                  gradeNumber: pair.gradeNumber,
                  sectionName: pair.sectionName,
                  gradient: _getGradientForGrade(pair.gradeNumber),
                  availableSubjects: availableSubjects,
                  selectedSubjects: selectedSubjects,
                  isExpanded: isExpanded,
                  getSubjectEmoji: _getSubjectEmoji,
                  onToggleExpanded: () => _toggleExpanded(key),
                  onSelectAll: () {
                    HapticFeedback.mediumImpact();
                    for (final subject in availableSubjects) {
                      if (!selectedSubjects.contains(subject)) {
                        context.read<AdminSetupBloc>().add(
                          AddSubjectToGradeSectionEvent(
                            gradeNumber: pair.gradeNumber,
                            section: pair.sectionName,
                            subjectName: subject,
                          ),
                        );
                      }
                    }
                  },
                  onClearAll: () {
                    HapticFeedback.mediumImpact();
                    for (final subject in selectedSubjects) {
                      context.read<AdminSetupBloc>().add(
                        RemoveSubjectFromGradeSectionEvent(
                          gradeNumber: pair.gradeNumber,
                          section: pair.sectionName,
                          subjectName: subject,
                        ),
                      );
                    }
                  },
                  onSubjectToggle: (subjectName) {
                    HapticFeedback.lightImpact();
                    if (selectedSubjects.contains(subjectName)) {
                      context.read<AdminSetupBloc>().add(
                        RemoveSubjectFromGradeSectionEvent(
                          gradeNumber: pair.gradeNumber,
                          section: pair.sectionName,
                          subjectName: subjectName,
                        ),
                      );
                    } else {
                      context.read<AdminSetupBloc>().add(
                        AddSubjectToGradeSectionEvent(
                          gradeNumber: pair.gradeNumber,
                          section: pair.sectionName,
                          subjectName: subjectName,
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
    );
  }
}

// Helper class to pair grade and section
class _GradeSectionPair {
  final int gradeNumber;
  final String sectionName;

  _GradeSectionPair({required this.gradeNumber, required this.sectionName});
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
          colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFf093fb).withValues(alpha:0.4),
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
                  Icons.menu_book_rounded,
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
                      'Pick Your Subjects',
                      style: TextStyle(
                        fontSize: 22,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choose subjects for each section',
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
                    '$totalSelected subject${totalSelected != 1 ? 's' : ''} selected',
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
// Section Card with expandable subjects
// =============================================================================

class _SectionCard extends StatelessWidget {
  final int gradeNumber;
  final String sectionName;
  final List<Color> gradient;
  final List<String> availableSubjects;
  final List<String> selectedSubjects;
  final bool isExpanded;
  final String Function(String) getSubjectEmoji;
  final VoidCallback onToggleExpanded;
  final VoidCallback onSelectAll;
  final VoidCallback onClearAll;
  final Function(String) onSubjectToggle;

  const _SectionCard({
    required this.gradeNumber,
    required this.sectionName,
    required this.gradient,
    required this.availableSubjects,
    required this.selectedSubjects,
    required this.isExpanded,
    required this.getSubjectEmoji,
    required this.onToggleExpanded,
    required this.onSelectAll,
    required this.onClearAll,
    required this.onSubjectToggle,
  });

  @override
  Widget build(BuildContext context) {
    final allSelected = selectedSubjects.length == availableSubjects.length &&
                        availableSubjects.isNotEmpty;

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
                  // Grade-Section badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha:0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$gradeNumber',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: 1,
                          height: 20,
                          color: Colors.white.withValues(alpha:0.4),
                        ),
                        Text(
                          sectionName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Grade $gradeNumber - $sectionName',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${selectedSubjects.length} of ${availableSubjects.length} subjects',
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
                  if (availableSubjects.isNotEmpty) ...[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha:0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              value: availableSubjects.isEmpty
                                  ? 0
                                  : selectedSubjects.length / availableSubjects.length,
                              strokeWidth: 3,
                              backgroundColor: Colors.white.withValues(alpha:0.3),
                              valueColor: const AlwaysStoppedAnimation(Colors.white),
                            ),
                          ),
                          if (allSelected)
                            const Icon(Icons.check_rounded, color: Colors.white, size: 16),
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
                        decoration: const BoxDecoration(
                          color: AppColors.backgroundSecondary,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _QuickActionChip(
                                icon: Icons.select_all_rounded,
                                label: 'Select All',
                                isEnabled: !allSelected && availableSubjects.isNotEmpty,
                                onTap: onSelectAll,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _QuickActionChip(
                                icon: Icons.clear_all_rounded,
                                label: 'Clear',
                                isEnabled: selectedSubjects.isNotEmpty,
                                onTap: onClearAll,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Subject chips
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: availableSubjects.isEmpty
                            ? _EmptySubjects()
                            : Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: availableSubjects.map((subject) {
                                  final isSelected = selectedSubjects.contains(subject);
                                  return _SubjectChip(
                                    subjectName: subject,
                                    emoji: getSubjectEmoji(subject),
                                    isSelected: isSelected,
                                    gradientColors: gradient,
                                    onTap: () => onSubjectToggle(subject),
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
// Subject Chip - Large, tappable
// =============================================================================

class _SubjectChip extends StatefulWidget {
  final String subjectName;
  final String emoji;
  final bool isSelected;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _SubjectChip({
    required this.subjectName,
    required this.emoji,
    required this.isSelected,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  State<_SubjectChip> createState() => _SubjectChipState();
}

class _SubjectChipState extends State<_SubjectChip>
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            gradient: widget.isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.gradientColors,
                  )
                : null,
            color: widget.isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(14),
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
              Text(widget.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                widget.subjectName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: widget.isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
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
                    size: 12,
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
// Empty Subjects State
// =============================================================================

class _EmptySubjects extends StatelessWidget {
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
          const Text(
            'No subjects available',
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
