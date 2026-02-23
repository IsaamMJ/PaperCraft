import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../domain/entities/admin_setup_grade.dart';
import '../bloc/admin_setup_bloc.dart';
import '../bloc/admin_setup_event.dart';

/// Step 2: Add sections for each selected grade
class AdminSetupStep2Sections extends StatefulWidget {
  final List<AdminSetupGrade> selectedGrades;
  final Map<int, List<String>> sectionsPerGrade;

  const AdminSetupStep2Sections({
    super.key,
    required this.selectedGrades,
    required this.sectionsPerGrade,
  });

  @override
  State<AdminSetupStep2Sections> createState() =>
      _AdminSetupStep2SectionsState();
}

class _AdminSetupStep2SectionsState extends State<AdminSetupStep2Sections>
    with TickerProviderStateMixin {
  // Per-grade text controllers
  final Map<int, TextEditingController> _controllers = {};

  // Per-grade expand state — all start expanded
  final Map<int, bool> _expanded = {};

  // Staggered entrance animation controller
  late AnimationController _entranceController;

  // Per-grade chevron rotation controllers
  final Map<int, AnimationController> _chevronControllers = {};

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

  List<Color> _gradientForGrade(int gradeNumber) {
    final index = (gradeNumber - 1).clamp(0, _gradeGradients.length - 1);
    return _gradeGradients[index];
  }

  @override
  void initState() {
    super.initState();

    // Entrance animation
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    for (final grade in widget.selectedGrades) {
      final g = grade.gradeNumber;
      _controllers[g] = TextEditingController();
      _expanded[g] = true;

      _chevronControllers[g] = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
        value: 1.0, // starts expanded (0.5 turn = pointing up)
      );
    }

    // Start staggered entrance after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entranceController.forward();
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final c in _chevronControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _toggleExpanded(int gradeNumber) {
    HapticFeedback.selectionClick();
    setState(() {
      _expanded[gradeNumber] = !(_expanded[gradeNumber] ?? true);
    });
    final ctrl = _chevronControllers[gradeNumber];
    if (ctrl != null) {
      if (_expanded[gradeNumber] == true) {
        ctrl.forward();
      } else {
        ctrl.reverse();
      }
    }
  }

  void _addSection(int gradeNumber, String sectionName) {
    final trimmed = sectionName.trim();
    if (trimmed.isEmpty) return;
    HapticFeedback.lightImpact();
    context.read<AdminSetupBloc>().add(
          AddSectionEvent(
            gradeNumber: gradeNumber,
            sectionName: trimmed.toUpperCase(),
          ),
        );
    _controllers[gradeNumber]?.clear();
  }

  void _removeSection(int gradeNumber, String sectionName) {
    context.read<AdminSetupBloc>().add(
          RemoveSectionEvent(
            gradeNumber: gradeNumber,
            sectionName: sectionName,
          ),
        );
  }

  void _applyPatternToAllGrades(List<String> sections) {
    HapticFeedback.lightImpact();
    for (final grade in widget.selectedGrades) {
      final existing = widget.sectionsPerGrade[grade.gradeNumber] ?? [];
      for (final s in sections) {
        if (!existing.contains(s)) {
          context.read<AdminSetupBloc>().add(
                AddSectionEvent(
                  gradeNumber: grade.gradeNumber,
                  sectionName: s,
                ),
              );
        }
      }
    }
  }

  void _applyPatternToGrade(int gradeNumber, List<String> sections) {
    HapticFeedback.lightImpact();
    final existing = widget.sectionsPerGrade[gradeNumber] ?? [];
    for (final s in sections) {
      if (!existing.contains(s)) {
        context.read<AdminSetupBloc>().add(
              AddSectionEvent(
                gradeNumber: gradeNumber,
                sectionName: s,
              ),
            );
      }
    }
  }

  int get _totalSections {
    int count = 0;
    for (final grade in widget.selectedGrades) {
      count += (widget.sectionsPerGrade[grade.gradeNumber] ?? []).length;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero card
          _buildHeroCard(),
          const SizedBox(height: 24),

          // Global quick action bar
          _buildGlobalQuickActionBar(),
          const SizedBox(height: 24),

          // Per-grade cards with staggered entrance
          ...widget.selectedGrades.asMap().entries.map((entry) {
            final index = entry.key;
            final grade = entry.value;
            return _buildStaggeredCard(index, grade);
          }),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    final total = _totalSections;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF11998e).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.white20,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.grid_view_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),

            // Title + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create Sections',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add sections (A, B, C…) for each grade.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.white20,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$total section${total == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalQuickActionBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Apply to all grades',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildGlobalPatternChip('A, B, C', ['A', 'B', 'C']),
              _buildGlobalPatternChip('A, B, C, D', ['A', 'B', 'C', 'D']),
              _buildGlobalPatternChip('A – E', ['A', 'B', 'C', 'D', 'E']),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalPatternChip(String label, List<String> sections) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _applyPatternToAllGrades(sections),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.black04,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStaggeredCard(int index, AdminSetupGrade grade) {
    // Each card staggers by 80ms
    final start = (index * 0.08).clamp(0.0, 0.7);
    final end = (start + 0.4).clamp(0.0, 1.0);

    final slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      ),
    );

    final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      ),
    );

    return AnimatedBuilder(
      animation: _entranceController,
      builder: (context, child) {
        return FadeTransition(
          opacity: fadeAnimation,
          child: SlideTransition(
            position: slideAnimation,
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _buildGradeCard(grade),
      ),
    );
  }

  Widget _buildGradeCard(AdminSetupGrade grade) {
    final gradeNum = grade.gradeNumber;
    final sections = widget.sectionsPerGrade[gradeNum] ?? [];
    final isExpanded = _expanded[gradeNum] ?? true;
    final gradientColors = _gradientForGrade(gradeNum);
    final chevronCtrl = _chevronControllers[gradeNum]!;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.black08,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gradient header strip
          GestureDetector(
            onTap: () => _toggleExpanded(gradeNum),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: gradientColors,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  // Grade badge
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.white20,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        '$gradeNum',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Title + count
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Grade $gradeNum',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${sections.length} section${sections.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Circular progress ring
                  _buildProgressRing(sections.length, gradientColors),
                  const SizedBox(width: 12),

                  // Animated chevron
                  AnimatedBuilder(
                    animation: chevronCtrl,
                    builder: (context, child) {
                      return AnimatedRotation(
                        turns: chevronCtrl.value * 0.5,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        child: child,
                      );
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.white20,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.expand_more_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Animated expandable body
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: isExpanded
                ? _buildGradeCardBody(gradeNum, sections, gradientColors)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRing(int count, List<Color> gradientColors) {
    // Show up to 8 sections in the ring; clamp progress
    final progress = count == 0 ? 0.0 : (count / 8.0).clamp(0.0, 1.0);
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 3,
            backgroundColor: AppColors.white20,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeCardBody(
    int gradeNum,
    List<String> sections,
    List<Color> gradientColors,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section chips
          if (sections.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sections.map((s) => _buildSectionChip(gradeNum, s)).toList(),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'No sections yet — add one below',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Add section row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controllers[gradeNum],
                  decoration: InputDecoration(
                    hintText: 'Section name (e.g. A)',
                    hintStyle: TextStyle(color: AppColors.textPlaceholder),
                    filled: true,
                    fillColor: AppColors.backgroundSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: gradientColors.first,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  onSubmitted: (val) => _addSection(gradeNum, val),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  final val = _controllers[gradeNum]?.text ?? '';
                  _addSection(gradeNum, val);
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: gradientColors.first.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Per-grade quick add buttons
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildGradePatternChip(gradeNum, 'A, B, C', ['A', 'B', 'C'], gradientColors),
              _buildGradePatternChip(
                  gradeNum, 'A, B, C, D', ['A', 'B', 'C', 'D'], gradientColors),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionChip(int gradeNum, String section) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {}, // tappable — no-op for display; delete via icon
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.secondary10,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.secondary.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                section,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _removeSection(gradeNum, section),
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradePatternChip(
    int gradeNum,
    String label,
    List<String> sections,
    List<Color> gradientColors,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _applyPatternToGrade(gradeNum, sections),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
