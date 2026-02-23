import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/routes/app_routes.dart';
import '../../../authentication/presentation/bloc/auth_bloc.dart';
import '../../../authentication/presentation/bloc/auth_event.dart';
import '../../domain/entities/admin_setup_state.dart' as domain;
import '../bloc/admin_setup_bloc.dart';
import '../bloc/admin_setup_event.dart';
import '../bloc/admin_setup_state.dart';

/// Compact 2-step onboarding for solo teachers.
/// Reuses [AdminSetupBloc] but with friendlier framing and fewer steps.
class SoloTeacherSetupPage extends StatefulWidget {
  final String tenantId;

  const SoloTeacherSetupPage({Key? key, required this.tenantId})
      : super(key: key);

  @override
  State<SoloTeacherSetupPage> createState() => _SoloTeacherSetupPageState();
}

class _SoloTeacherSetupPageState extends State<SoloTeacherSetupPage>
    with TickerProviderStateMixin {
  late AdminSetupBloc _bloc;
  int _currentStep = 1; // 1: About You, 2: Your Classes

  late TextEditingController _nameController;
  late TextEditingController _addressController;

  late AnimationController _fadeController;
  late AnimationController _staggerController;
  late AnimationController _pulseController;
  late AnimationController _contentTransitionController;

  // Track expanded grade cards in step 2
  final Set<int> _expandedGrades = {};

  // Subject emoji map for visual appeal
  static const Map<String, String> _subjectEmojis = {
    'Mathematics': '🔢',
    'Math': '🔢',
    'English': '📖',
    'Science': '🔬',
    'Physics': '⚡',
    'Chemistry': '🧪',
    'Biology': '🧬',
    'History': '📜',
    'Geography': '🌍',
    'Computer Science': '💻',
    'Art': '🎨',
    'Music': '🎵',
    'Physical Education': '⚽',
    'Economics': '📊',
    'Hindi': '🇮🇳',
    'Social Studies': '🏛️',
    'Social Science': '🏛️',
    'Environmental Studies': '🌱',
    'EVS': '🌱',
    'General Knowledge': '💡',
    'GK': '💡',
    'Moral Science': '🕊️',
    'Sanskrit': '📿',
  };

  static const List<int> _availableGrades = [
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12,
  ];

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

  static const List<String> _gradeEmojis = [
    '🌟', '🚀', '🎨', '🔬', '📚', '🎯',
    '💡', '🏆', '🎓', '⭐', '🔥', '👑',
  ];

  List<Color> _gradientForGrade(int grade) {
    final index = (grade - 1) % _gradeGradients.length;
    return _gradeGradients[index];
  }

  String _emojiForGrade(int grade) {
    final index = (grade - 1) % _gradeEmojis.length;
    return _gradeEmojis[index];
  }

  @override
  void initState() {
    super.initState();
    _bloc = context.read<AdminSetupBloc>();
    _bloc.add(InitializeAdminSetupEvent(tenantId: widget.tenantId));

    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _nameController.addListener(_onDetailsChanged);
    _addressController.addListener(_onDetailsChanged);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _contentTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    )..forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _fadeController.dispose();
    _staggerController.dispose();
    _pulseController.dispose();
    _contentTransitionController.dispose();
    super.dispose();
  }

  void _onDetailsChanged() {
    _bloc.add(UpdateSchoolDetailsEvent(
      schoolName: _nameController.text.trim(),
      schoolAddress: _addressController.text.trim(),
    ));
  }

  void _goToStep2() {
    final setupState = _bloc.setupState;
    if (setupState.selectedGrades.isEmpty) {
      _showError('Please select at least one grade you teach');
      return;
    }
    if (_nameController.text.trim().isEmpty) {
      _showError('Please enter your school or institution name');
      return;
    }

    // Load subject suggestions for each selected grade
    for (final grade in setupState.selectedGrades) {
      _bloc.add(LoadSubjectSuggestionsEvent(gradeNumber: grade.gradeNumber));
      // Auto-add section "A" if no sections yet
      if (setupState.getSectionsForGrade(grade.gradeNumber).isEmpty) {
        _bloc.add(AddSectionEvent(
          gradeNumber: grade.gradeNumber,
          sectionName: 'A',
        ));
      }
    }

    // Auto-expand first grade
    if (setupState.selectedGrades.isNotEmpty) {
      _expandedGrades.add(setupState.selectedGrades.first.gradeNumber);
    }

    _contentTransitionController.reset();
    _contentTransitionController.forward();
    _staggerController.reset();
    _staggerController.forward();
    setState(() => _currentStep = 2);
    HapticFeedback.lightImpact();
  }

  void _goToStep1() {
    _contentTransitionController.reset();
    _contentTransitionController.forward();
    _staggerController.reset();
    _staggerController.forward();
    setState(() => _currentStep = 1);
    HapticFeedback.lightImpact();
  }

  void _onSave() {
    final setupState = _bloc.setupState;

    // Local validation before dispatching save
    if (setupState.selectedGrades.isEmpty) {
      _showError('Please select at least one grade');
      return;
    }
    for (final grade in setupState.selectedGrades) {
      if (setupState.getSectionsForGrade(grade.gradeNumber).isEmpty) {
        _showError('Please add sections for Grade ${grade.gradeNumber}');
        return;
      }
      if (!setupState.gradeHasSubjects(grade.gradeNumber)) {
        _showError('Please add subjects for Grade ${grade.gradeNumber}');
        return;
      }
    }

    _bloc.add(const SaveAdminSetupEvent());
  }

  void _showError(String message) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _toggleGrade(int gradeNumber) {
    HapticFeedback.lightImpact();
    final selected =
        _bloc.setupState.selectedGrades.any((g) => g.gradeNumber == gradeNumber);
    if (selected) {
      _bloc.add(RemoveGradeEvent(gradeNumber: gradeNumber));
    } else {
      _bloc.add(AddGradeEvent(gradeNumber: gradeNumber));
    }
  }

  /// Toggle a subject for a grade — applies to ALL sections of that grade.
  void _toggleSubject(int gradeNumber, String subjectName) {
    HapticFeedback.selectionClick();
    final sections = _bloc.setupState.getSectionsForGrade(gradeNumber);
    if (sections.isEmpty) return;

    // Check if subject is selected in the first section
    final isSelected = _bloc.setupState
        .getSubjectsForGradeSection(gradeNumber, sections.first)
        .contains(subjectName);

    for (final section in sections) {
      if (isSelected) {
        _bloc.add(RemoveSubjectFromGradeSectionEvent(
          gradeNumber: gradeNumber,
          section: section,
          subjectName: subjectName,
        ));
      } else {
        _bloc.add(AddSubjectToGradeSectionEvent(
          gradeNumber: gradeNumber,
          section: section,
          subjectName: subjectName,
        ));
      }
    }
  }

  /// Apply a section preset to a grade (e.g., A / A,B / A,B,C).
  void _applySectionPreset(int gradeNumber, List<String> sections) {
    HapticFeedback.lightImpact();
    // Clear existing sections and add new ones
    _bloc.add(UpdateSectionsEvent(
      gradeNumber: gradeNumber,
      sections: sections,
    ));
    // Copy existing subjects to any new sections
    final existingSubjects =
        _bloc.setupState.getAllSubjectsForGrade(gradeNumber);
    for (final section in sections) {
      for (final subject in existingSubjects) {
        _bloc.add(AddSubjectToGradeSectionEvent(
          gradeNumber: gradeNumber,
          section: section,
          subjectName: subject,
        ));
      }
    }
  }

  /// Select all suggested subjects for a grade.
  void _selectAllSubjects(int gradeNumber) {
    HapticFeedback.mediumImpact();
    final suggestions = _bloc.subjectSuggestions[gradeNumber] ?? [];
    final sections = _bloc.setupState.getSectionsForGrade(gradeNumber);
    for (final section in sections) {
      for (final subject in suggestions) {
        _bloc.add(AddSubjectToGradeSectionEvent(
          gradeNumber: gradeNumber,
          section: section,
          subjectName: subject,
        ));
      }
    }
  }

  /// Clear all subjects for a grade.
  void _clearAllSubjects(int gradeNumber) {
    HapticFeedback.lightImpact();
    final sections = _bloc.setupState.getSectionsForGrade(gradeNumber);
    for (final section in sections) {
      final subjects = _bloc.setupState
          .getSubjectsForGradeSection(gradeNumber, section)
          .toList();
      for (final subject in subjects) {
        _bloc.add(RemoveSubjectFromGradeSectionEvent(
          gradeNumber: gradeNumber,
          section: section,
          subjectName: subject,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentStep == 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentStep == 2) {
          _goToStep1();
        }
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primary.withOpacity(0.08),
                AppColors.background,
                AppColors.background,
              ],
              stops: const [0.0, 0.40, 1.0],
            ),
          ),
          child: SafeArea(
            child: BlocConsumer<AdminSetupBloc, AdminSetupUIState>(
              buildWhen: (prev, curr) =>
                  curr is AdminSetupUpdated ||
                  curr is AdminSetupInitial ||
                  curr is SavingAdminSetup,
              listenWhen: (prev, curr) =>
                  curr is AdminSetupSaved ||
                  curr is AdminSetupError ||
                  curr is StepValidationFailed,
              listener: (context, state) {
                if (state is AdminSetupSaved) {
                  _handleSetupComplete(context);
                } else if (state is AdminSetupError) {
                  _showError(state.errorMessage);
                } else if (state is StepValidationFailed) {
                  _showError(state.errorMessage);
                }
              },
              builder: (context, state) {
                if (state is SavingAdminSetup) {
                  return _buildSavingOverlay();
                }

                final setupState = _bloc.setupState;
                return Column(
                  children: [
                    // Stepper header
                    _buildStepperHeader(),
                    // Content
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 340),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.04, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: _currentStep == 1
                            ? _buildStep1(setupState)
                            : _buildStep2(setupState),
                      ),
                    ),
                    // Bottom navigation
                    _buildBottomNav(setupState),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepperHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          _buildStepCircle(1, 'About You'),
          Expanded(child: _buildStepConnector(1)),
          _buildStepCircle(2, 'Your Classes'),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int step, String label) {
    final isCompleted = _currentStep > step;
    final isCurrent = _currentStep == step;

    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final scale = isCurrent
                ? 1.0 + (_pulseController.value * 0.10)
                : 1.0;
            return Transform.scale(scale: scale, child: child);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: (isCompleted || isCurrent)
                  ? AppColors.primaryGradient
                  : null,
              color: (!isCompleted && !isCurrent)
                  ? AppColors.background
                  : null,
              shape: BoxShape.circle,
              border: (!isCompleted && !isCurrent)
                  ? Border.all(color: AppColors.border, width: 2)
                  : null,
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 22)
                  : Text(
                      '$step',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isCurrent
                            ? Colors.white
                            : AppColors.textTertiary,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: TextStyle(
            fontSize: 12,
            fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
            color: isCurrent ? AppColors.textPrimary : AppColors.textTertiary,
          ),
          child: Text(label),
        ),
      ],
    );
  }

  Widget _buildStepConnector(int beforeStep) {
    final isCompleted = _currentStep > beforeStep;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          gradient: isCompleted ? AppColors.primaryGradient : null,
          color: isCompleted ? null : AppColors.border,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  // ─── STEP 1: About You ───────────────────────────────────────

  Widget _buildStep1(domain.AdminSetupState setupState) {
    return SingleChildScrollView(
      key: const ValueKey('step1'),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // Hero card
          _buildHeroCard(
            icon: Icons.waving_hand_rounded,
            title: "Let's get you started",
            subtitle: "Tell us a bit about yourself and what you teach.",
            gradient: const [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
          const SizedBox(height: 24),
          // School name
          _buildSectionLabel('School / Institution Name'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _nameController,
            hint: 'e.g. Springfield High School',
            icon: Icons.school_outlined,
          ),
          const SizedBox(height: 16),
          // Address (optional)
          _buildSectionLabel('Address', isOptional: true),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _addressController,
            hint: 'e.g. 123 Main Street, City',
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 28),
          // Grades
          _buildSectionLabel('What grades do you teach?'),
          const SizedBox(height: 12),
          _buildQuickSelectRow(setupState),
          const SizedBox(height: 16),
          _buildGradeGrid(setupState),
          const SizedBox(height: 16),
          // Selection count
          if (setupState.selectedGrades.isNotEmpty)
            _buildSelectionBadge(
              '${setupState.selectedGrades.length} grade${setupState.selectedGrades.length == 1 ? '' : 's'} selected',
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeroCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.85),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label, {bool isOptional = false}) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        if (isOptional) ...[
          const SizedBox(width: 6),
          Text(
            '(Optional)',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
          prefixIcon: Icon(icon, color: AppColors.textTertiary, size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildQuickSelectRow(domain.AdminSetupState setupState) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _buildQuickSelectButton('Primary', [1, 2, 3, 4, 5], setupState),
          const SizedBox(width: 8),
          _buildQuickSelectButton('Middle', [6, 7, 8], setupState),
          const SizedBox(width: 8),
          _buildQuickSelectButton('High', [9, 10], setupState),
          const SizedBox(width: 8),
          _buildQuickSelectButton('Senior', [11, 12], setupState),
        ],
      ),
    );
  }

  Widget _buildQuickSelectButton(
    String label,
    List<int> grades,
    domain.AdminSetupState setupState,
  ) {
    final allSelected = grades.every((g) =>
        setupState.selectedGrades.any((sg) => sg.gradeNumber == g));

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          if (allSelected) {
            for (final g in grades) {
              _bloc.add(RemoveGradeEvent(gradeNumber: g));
            }
          } else {
            for (final g in grades) {
              if (!setupState.selectedGrades.any((sg) => sg.gradeNumber == g)) {
                _bloc.add(AddGradeEvent(gradeNumber: g));
              }
            }
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: allSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: allSelected
                ? Border.all(color: AppColors.primary.withOpacity(0.3))
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: allSelected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradeGrid(domain.AdminSetupState setupState) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _availableGrades.map((grade) {
        final isSelected =
            setupState.selectedGrades.any((g) => g.gradeNumber == grade);
        return _buildGradeCard(grade, isSelected);
      }).toList(),
    );
  }

  Widget _buildGradeCard(int grade, bool isSelected) {
    final gradient = _gradientForGrade(grade);
    final emoji = _emojiForGrade(grade);
    final width = (MediaQuery.of(context).size.width - 40 - 36) / 4;

    return GestureDetector(
      onTap: () => _toggleGrade(grade),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? null
              : Border.all(color: AppColors.border),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: gradient[0].withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              '$grade',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionBadge(String text) {
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ─── STEP 2: Your Classes ────────────────────────────────────

  Widget _buildStep2(domain.AdminSetupState setupState) {
    final grades = setupState.selectedGrades;

    return SingleChildScrollView(
      key: const ValueKey('step2'),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _buildHeroCard(
            icon: Icons.menu_book_rounded,
            title: 'Almost there!',
            subtitle: 'Set up sections and pick the subjects you teach.',
            gradient: const [Color(0xFF11998e), Color(0xFF38ef7d)],
          ),
          const SizedBox(height: 20),
          ...grades.asMap().entries.map((entry) {
            final index = entry.key;
            final grade = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildGradeClassCard(grade.gradeNumber, setupState, index),
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildGradeClassCard(
    int gradeNumber,
    domain.AdminSetupState setupState,
    int index,
  ) {
    final gradient = _gradientForGrade(gradeNumber);
    final emoji = _emojiForGrade(gradeNumber);
    final isExpanded = _expandedGrades.contains(gradeNumber);
    final sections = setupState.getSectionsForGrade(gradeNumber);
    final subjectCount = setupState.getAllSubjectsForGrade(gradeNumber).length;
    final suggestions = _bloc.subjectSuggestions[gradeNumber] ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                if (isExpanded) {
                  _expandedGrades.remove(gradeNumber);
                } else {
                  _expandedGrades.add(gradeNumber);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    gradient[0].withOpacity(0.12),
                    gradient[1].withOpacity(0.06),
                  ],
                ),
                borderRadius: isExpanded
                    ? const BorderRadius.vertical(top: Radius.circular(20))
                    : BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Grade $gradeNumber',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${sections.length} section${sections.length == 1 ? '' : 's'} · $subjectCount subject${subjectCount == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (subjectCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: gradient[0].withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$subjectCount',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: gradient[0],
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Expandable body
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: isExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section presets
                        _buildSectionLabel('Sections'),
                        const SizedBox(height: 8),
                        _buildSectionPresets(gradeNumber, sections),
                        const SizedBox(height: 20),
                        // Subject selection
                        Row(
                          children: [
                            Expanded(
                              child: _buildSectionLabel('Subjects'),
                            ),
                            if (suggestions.isNotEmpty) ...[
                              GestureDetector(
                                onTap: () => _selectAllSubjects(gradeNumber),
                                child: Text(
                                  'Select All',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () => _clearAllSubjects(gradeNumber),
                                child: Text(
                                  'Clear',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (suggestions.isEmpty)
                          _buildLoadingSuggestions()
                        else
                          _buildSubjectChips(
                              gradeNumber, suggestions, setupState),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionPresets(int gradeNumber, List<String> currentSections) {
    final presets = [
      ('A', ['A']),
      ('A, B', ['A', 'B']),
      ('A, B, C', ['A', 'B', 'C']),
      ('A – D', ['A', 'B', 'C', 'D']),
    ];

    return Row(
      children: presets.map((preset) {
        final label = preset.$1;
        final sections = preset.$2;
        final isActive = _listsEqual(currentSections, sections);

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: preset != presets.last ? 8 : 0,
            ),
            child: GestureDetector(
              onTap: () => _applySectionPreset(gradeNumber, sections),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary.withOpacity(0.10)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: isActive
                      ? Border.all(
                          color: AppColors.primary.withOpacity(0.3))
                      : Border.all(color: Colors.transparent),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Widget _buildLoadingSuggestions() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectChips(
    int gradeNumber,
    List<String> suggestions,
    domain.AdminSetupState setupState,
  ) {
    // Get subjects selected for first section (they're mirrored across all)
    final sections = setupState.getSectionsForGrade(gradeNumber);
    final selectedSubjects = sections.isNotEmpty
        ? setupState.getSubjectsForGradeSection(gradeNumber, sections.first)
        : <String>[];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: suggestions.map((subject) {
        final isSelected = selectedSubjects.contains(subject);
        final emoji = _subjectEmojis[subject] ?? '📘';
        final gradient = _gradientForGrade(gradeNumber);

        return GestureDetector(
          onTap: () => _toggleSubject(gradeNumber, subject),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(colors: gradient)
                  : null,
              color: isSelected ? null : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? null
                  : Border.all(color: AppColors.border),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: gradient[0].withOpacity(0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  subject,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Bottom Navigation ───────────────────────────────────────

  Widget _buildBottomNav(domain.AdminSetupState setupState) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep == 2) ...[
            Expanded(
              child: _PillOutlinedButton(
                label: 'Previous',
                onTap: _goToStep1,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: _currentStep == 2 ? 2 : 1,
            child: _PillGradientButton(
              label: _currentStep == 1 ? 'Next' : 'Complete Setup',
              icon: _currentStep == 2 ? Icons.check_rounded : null,
              onTap: _currentStep == 1 ? _goToStep2 : _onSave,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Overlays ────────────────────────────────────────────────

  Widget _buildSavingOverlay() {
    return Center(
      child: Container(
        width: 144,
        height: 144,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Setting up...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSetupComplete(BuildContext ctx) {
    // Dispatch auth refresh first
    ctx.read<AuthBloc>().add(const AuthCheckStatus());
    // Navigate directly after a brief delay to let auth state settle
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        context.go(AppRoutes.home);
      }
    });
  }
}

// ─── Reusable Pill Buttons ───────────────────────────────────

class _PillGradientButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  const _PillGradientButton({
    required this.label,
    this.icon,
    required this.onTap,
  });

  @override
  State<_PillGradientButton> createState() => _PillGradientButtonState();
}

class _PillGradientButtonState extends State<_PillGradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 180),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1.0 - (_controller.value * 0.05);
        return Transform.scale(scale: scale, child: child);
      },
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        onTapCancel: () => _controller.reverse(),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PillOutlinedButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _PillOutlinedButton({
    required this.label,
    required this.onTap,
  });

  @override
  State<_PillOutlinedButton> createState() => _PillOutlinedButtonState();
}

class _PillOutlinedButtonState extends State<_PillOutlinedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 180),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1.0 - (_controller.value * 0.05);
        return Transform.scale(scale: scale, child: child);
      },
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        onTapCancel: () => _controller.reverse(),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
