import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/presentation/constants/app_colors.dart';
import '../../../admin/domain/entities/admin_setup_grade.dart';

/// A draggable confirmation bottom sheet shown before finalizing onboarding.
/// Displays a full summary of selected grades, sections, and subjects,
/// with stat cards, per-section edit shortcuts, and a sticky action row.
class OnboardingConfirmationSheet extends StatefulWidget {
  const OnboardingConfirmationSheet({
    super.key,
    required this.selectedGrades,
    required this.sectionsPerGrade,
    required this.subjectsPerGradeSection,
    required this.onConfirm,
    required this.onGoBack,
    required this.onEditStep,
  });

  final List<AdminSetupGrade> selectedGrades;

  /// gradeNumber -> list of section names
  final Map<int, List<String>> sectionsPerGrade;

  /// "gradeNumber-sectionName" -> list of subject strings
  final Map<String, List<String>> subjectsPerGradeSection;

  final VoidCallback onConfirm;
  final VoidCallback onGoBack;
  final void Function(int step) onEditStep;

  // ---------------------------------------------------------------------------
  // Factory show method
  // ---------------------------------------------------------------------------

  /// Opens the sheet. Returns `true` when the user taps "Confirm & Complete",
  /// `false` / `null` otherwise.
  static Future<bool?> show(
    BuildContext context, {
    required List<AdminSetupGrade> selectedGrades,
    required Map<int, List<String>> sectionsPerGrade,
    required Map<String, List<String>> subjectsPerGradeSection,
    required VoidCallback onConfirm,
    required VoidCallback onGoBack,
    required void Function(int step) onEditStep,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.overlayDark,
      builder: (_) => OnboardingConfirmationSheet(
        selectedGrades: selectedGrades,
        sectionsPerGrade: sectionsPerGrade,
        subjectsPerGradeSection: subjectsPerGradeSection,
        onConfirm: onConfirm,
        onGoBack: onGoBack,
        onEditStep: onEditStep,
      ),
    );
  }

  @override
  State<OnboardingConfirmationSheet> createState() =>
      _OnboardingConfirmationSheetState();
}

class _OnboardingConfirmationSheetState
    extends State<OnboardingConfirmationSheet>
    with TickerProviderStateMixin {
  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  bool _isLoading = false;
  bool _showSuccess = false;

  /// Which grade sections are expanded to reveal subject lists.
  final Set<String> _expandedKeys = {};

  // ---------------------------------------------------------------------------
  // Animation controllers
  // ---------------------------------------------------------------------------

  late final AnimationController _sheetEntryCtrl;
  late final Animation<double> _sheetEntry;

  late final AnimationController _successCtrl;
  late final Animation<double> _successScale;
  late final Animation<double> _successFade;

  // Confetti particles
  late final AnimationController _confettiCtrl;
  final List<_ConfettiParticle> _particles = [];

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    _sheetEntryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _sheetEntry = CurvedAnimation(
      parent: _sheetEntryCtrl,
      curve: Curves.easeOutCubic,
    );
    _sheetEntryCtrl.forward();

    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _successScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut),
    );
    _successFade = CurvedAnimation(
      parent: _successCtrl,
      curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
    );

    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _generateParticles();
  }

  @override
  void dispose() {
    _sheetEntryCtrl.dispose();
    _successCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _generateParticles() {
    final rng = math.Random(42);
    final colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.success,
      AppColors.accent,
      AppColors.warning,
    ];
    _particles.clear();
    for (var i = 0; i < 48; i++) {
      _particles.add(
        _ConfettiParticle(
          color: colors[rng.nextInt(colors.length)],
          x: rng.nextDouble(),
          delay: rng.nextDouble() * 0.6,
          speedY: 0.4 + rng.nextDouble() * 0.6,
          size: 5.0 + rng.nextDouble() * 6.0,
          rotation: rng.nextDouble() * math.pi * 2,
          isSquare: rng.nextBool(),
        ),
      );
    }
  }

  int get _totalGrades => widget.selectedGrades.length;

  int get _totalSections {
    var count = 0;
    for (final sections in widget.sectionsPerGrade.values) {
      count += sections.length;
    }
    return count;
  }

  int get _totalSubjects {
    var count = 0;
    for (final subjects in widget.subjectsPerGradeSection.values) {
      count += subjects.length;
    }
    return count;
  }

  String _sectionKey(int grade, String section) => '$grade:$section';

  Future<void> _handleConfirm() async {
    setState(() => _isLoading = true);

    // Give the caller a chance to persist; we observe via the loading flag.
    // The actual async work happens outside; we just trigger and then animate.
    widget.onConfirm();

    // Brief artificial delay so the loading indicator is visible even for fast
    // saves, then show the success state.
    await Future<void>.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _showSuccess = true;
    });

    _successCtrl.forward();
    _confettiCtrl.forward();

    await Future<void>.delayed(const Duration(milliseconds: 2400));
    if (mounted) Navigator.of(context).pop(true);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final maxH = mq.size.height * 0.82;

    return AnimatedBuilder(
      animation: _sheetEntry,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, (1 - _sheetEntry.value) * 80),
        child: Opacity(opacity: _sheetEntry.value, child: child),
      ),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxH),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 32,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: _showSuccess ? _buildSuccess() : _buildContent(mq),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Success overlay
  // ---------------------------------------------------------------------------

  Widget _buildSuccess() {
    return SizedBox(
      height: 380,
      child: Stack(
        children: [
          // Confetti
          AnimatedBuilder(
            animation: _confettiCtrl,
            builder: (context, _) => CustomPaint(
              size: Size.infinite,
              painter: _ConfettiPainter(
                particles: _particles,
                progress: _confettiCtrl.value,
              ),
            ),
          ),

          // Centre content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _successScale,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.successGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withValues(alpha: 0.38),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 52,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FadeTransition(
                  opacity: _successFade,
                  child: Column(
                    children: [
                      const Text(
                        'Setup Complete!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your teaching assignments have been saved.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Main sheet content
  // ---------------------------------------------------------------------------

  Widget _buildContent(MediaQueryData mq) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 4),

        // Header row
        _buildHeader(),

        // Scrollable body
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                _buildStatsRow(),
                const SizedBox(height: 24),
                _buildGradesSection(),
                const SizedBox(height: 20),
                _buildSectionsSection(),
                const SizedBox(height: 20),
                _buildSubjectsSection(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),

        // Sticky action bar
        _buildActionBar(mq),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Review Your Setup',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Please confirm your teaching assignments',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 22),
            color: AppColors.textTertiary,
            splashRadius: 20,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Stats row
  // ---------------------------------------------------------------------------

  Widget _buildStatsRow() {
    return Row(
      children: [
        _StatCard(
          icon: Icons.school_rounded,
          label: 'Grades',
          value: _totalGrades,
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

  // ---------------------------------------------------------------------------
  // Section builders
  // ---------------------------------------------------------------------------

  Widget _buildGradesSection() {
    return _SectionCard(
      title: 'Grades',
      icon: Icons.school_rounded,
      iconColor: AppColors.primary,
      onEdit: () {
        Navigator.of(context).pop(false);
        widget.onEditStep(1);
      },
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: widget.selectedGrades
            .map(
              (g) => _GradeChip(label: 'Grade ${g.gradeNumber}'),
            )
            .toList(),
      ),
    );
  }

  Widget _buildSectionsSection() {
    return _SectionCard(
      title: 'Sections',
      icon: Icons.meeting_room_rounded,
      iconColor: AppColors.secondary,
      onEdit: () {
        Navigator.of(context).pop(false);
        widget.onEditStep(2);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widget.selectedGrades.map((grade) {
          final sections =
              widget.sectionsPerGrade[grade.gradeNumber] ?? [];
          if (sections.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Grade ${grade.gradeNumber}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: sections
                      .map((s) => _SectionChip(label: s))
                      .toList(),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSubjectsSection() {
    return _SectionCard(
      title: 'Subjects',
      icon: Icons.menu_book_rounded,
      iconColor: AppColors.accent,
      onEdit: () {
        Navigator.of(context).pop(false);
        widget.onEditStep(3);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widget.selectedGrades.expand((grade) {
          final sections =
              widget.sectionsPerGrade[grade.gradeNumber] ?? [];
          return sections.map((section) {
            final key = _sectionKey(grade.gradeNumber, section);
            final subjects = widget.subjectsPerGradeSection[key] ?? [];
            if (subjects.isEmpty) return const SizedBox.shrink();

            final isExpanded = _expandedKeys.contains(key);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row with label + expand toggle
                  InkWell(
                    onTap: () => setState(() {
                      if (isExpanded) {
                        _expandedKeys.remove(key);
                      } else {
                        _expandedKeys.add(key);
                      }
                    }),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Grade ${grade.gradeNumber} · Section $section',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textTertiary,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${subjects.length} subject${subjects.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          AnimatedRotation(
                            turns: isExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 220),
                            child: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Expandable subject chips
                  AnimatedCrossFade(
                    firstChild: const SizedBox(width: double.infinity),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: subjects
                            .map((s) => _SubjectChip(label: s))
                            .toList(),
                      ),
                    ),
                    crossFadeState: isExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 240),
                    sizeCurve: Curves.easeInOut,
                  ),
                ],
              ),
            );
          });
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sticky action bar
  // ---------------------------------------------------------------------------

  Widget _buildActionBar(MediaQueryData mq) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + mq.padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Go Back
          Expanded(
            child: OutlinedButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      Navigator.of(context).pop(false);
                      widget.onGoBack();
                    },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Go Back',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Confirm & Complete
          Expanded(
            flex: 2,
            child: _GradientButton(
              onPressed: _isLoading ? null : _handleConfirm,
              isLoading: _isLoading,
              label: 'Confirm & Complete',
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Reusable sub-widgets
// =============================================================================

/// A horizontal statistics card showing icon + count + label.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
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

/// A card with a section header, optional edit button, and child content.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.onEdit,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onEdit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 13),
                  label: Text('Edit'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Container(height: 1, color: AppColors.border),

          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Grade number chip — solid primary tint.
class _GradeChip extends StatelessWidget {
  const _GradeChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Section name chip — purple secondary tint.
class _SectionChip extends StatelessWidget {
  const _SectionChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.28),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.secondary,
        ),
      ),
    );
  }
}

/// Subject name chip — orange accent tint.
class _SubjectChip extends StatelessWidget {
  const _SubjectChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.28),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

/// Gradient-filled confirm button with integrated loading indicator.
class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.isLoading,
    this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 50,
        decoration: BoxDecoration(
          gradient: onPressed == null
              ? const LinearGradient(
                  colors: [Color(0xFFBBBBBB), Color(0xFF999999)],
                )
              : AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: onPressed == null
              ? []
              : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.36),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
        ),
      ),
    );
  }
}

// =============================================================================
// Confetti
// =============================================================================

class _ConfettiParticle {
  _ConfettiParticle({
    required this.color,
    required this.x,
    required this.delay,
    required this.speedY,
    required this.size,
    required this.rotation,
    required this.isSquare,
  });

  final Color color;
  final double x;
  final double delay;
  final double speedY;
  final double size;
  final double rotation;
  final bool isSquare;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.particles,
    required this.progress,
  });

  final List<_ConfettiParticle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = (progress - p.delay).clamp(0.0, 1.0);
      if (t == 0) continue;

      final y = -20.0 + t * p.speedY * (size.height + 40);
      final x = p.x * size.width;
      final opacity = (1.0 - (t * t)).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + t * math.pi * 3);

      if (p.isSquare) {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
