import 'package:flutter/material.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../domain/entities/admin_setup_state.dart' as domain;

/// Step 4: Review and confirm the setup — modernized with stats cards and expandable sections
class AdminSetupStep4Review extends StatefulWidget {
  final domain.AdminSetupState setupState;

  const AdminSetupStep4Review({
    Key? key,
    required this.setupState,
  }) : super(key: key);

  @override
  State<AdminSetupStep4Review> createState() => _AdminSetupStep4ReviewState();
}

class _AdminSetupStep4ReviewState extends State<AdminSetupStep4Review>
    with TickerProviderStateMixin {
  late AnimationController _staggerController;
  final Set<int> _expandedGrades = {};

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    // Expand first grade by default
    if (widget.setupState.selectedGrades.isNotEmpty) {
      _expandedGrades.add(widget.setupState.selectedGrades.first.gradeNumber);
    }
    _staggerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  int get _totalSections {
    int count = 0;
    for (final sections in widget.setupState.sectionsPerGrade.values) {
      count += sections.length;
    }
    return count;
  }

  int get _totalSubjects {
    int count = 0;
    for (final grade in widget.setupState.selectedGrades) {
      // FIX: Use getAllSubjectsForGrade which reads from subjectsPerGradeSection
      count += widget.setupState.getAllSubjectsForGrade(grade.gradeNumber).length;
    }
    return count;
  }

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

  List<Color> _getGradientForGrade(int grade) {
    final index = (grade - 1) % _gradeGradients.length;
    return _gradeGradients[index];
  }

  @override
  Widget build(BuildContext context) {
    final sortedGrades = widget.setupState.selectedGrades.toList()
      ..sort((a, b) => a.gradeNumber.compareTo(b.gradeNumber));

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero header
          _buildHeroCard(),

          const SizedBox(height: 20),

          // Stats row
          _buildStatsRow(),

          const SizedBox(height: 24),

          // School details (if provided)
          if (widget.setupState.schoolName.isNotEmpty) ...[
            _buildSchoolInfoCard(),
            const SizedBox(height: 16),
          ],

          // Per-grade expandable review cards
          ...List.generate(sortedGrades.length, (index) {
            final grade = sortedGrades[index];
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
                padding: EdgeInsets.only(
                  bottom: index < sortedGrades.length - 1 ? 16 : 0,
                ),
                child: _buildGradeReviewCard(grade.gradeNumber),
              ),
            );
          }),

          const SizedBox(height: 20),

          // Info box
          _buildInfoBox(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
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
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
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
                  'Review Your Setup',
                  style: TextStyle(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Confirm before completing',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _StatCard(
          icon: Icons.school_rounded,
          label: 'Grades',
          value: widget.setupState.selectedGrades.length,
          color: AppColors.primary,
        ),
        const SizedBox(width: 10),
        _StatCard(
          icon: Icons.meeting_room_rounded,
          label: 'Sections',
          value: _totalSections,
          color: AppColors.secondary,
        ),
        const SizedBox(width: 10),
        _StatCard(
          icon: Icons.menu_book_rounded,
          label: 'Subjects',
          value: _totalSubjects,
          color: AppColors.accent,
        ),
      ],
    );
  }

  Widget _buildSchoolInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.setupState.schoolName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (widget.setupState.schoolAddress.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.setupState.schoolAddress,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeReviewCard(int gradeNumber) {
    final sections = widget.setupState.getSectionsForGrade(gradeNumber);
    // FIX: Use getAllSubjectsForGrade instead of getSubjectsForGrade
    final subjects = widget.setupState.getAllSubjectsForGrade(gradeNumber);
    final isExpanded = _expandedGrades.contains(gradeNumber);
    final gradient = _getGradientForGrade(gradeNumber);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          GestureDetector(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedGrades.remove(gradeNumber);
                } else {
                  _expandedGrades.add(gradeNumber);
                }
              });
            },
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
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '$gradeNumber',
                        style: const TextStyle(
                          fontSize: 20,
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
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${sections.length} section${sections.length != 1 ? 's' : ''} · ${subjects.length} subject${subjects.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: isExpanded ? 0.5 : 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
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
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sections
                        const Text(
                          'SECTIONS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textTertiary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: sections.map((s) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.secondary.withValues(alpha: 0.28),
                                ),
                              ),
                              child: Text(
                                'Section $s',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.secondary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 16),

                        // Subjects
                        const Text(
                          'SUBJECTS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textTertiary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (subjects.isEmpty)
                          Text(
                            'No subjects selected',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textTertiary,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: subjects.map((s) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.09),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.accent.withValues(alpha: 0.28),
                                  ),
                                ),
                                child: Text(
                                  s,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.accent,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.info_rounded,
              color: AppColors.primary,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'You can edit these settings later from the admin dashboard. Tap "Complete Setup" when ready.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Stat Card
// =============================================================================

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
