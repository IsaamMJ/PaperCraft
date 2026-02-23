import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/routes/app_routes.dart';

/// Choice screen shown to admins of un-initialized tenants.
/// Lets them pick between full school setup or quick solo-teacher setup.
class OnboardingChoicePage extends StatefulWidget {
  const OnboardingChoicePage({Key? key}) : super(key: key);

  @override
  State<OnboardingChoicePage> createState() => _OnboardingChoicePageState();
}

class _OnboardingChoicePageState extends State<OnboardingChoicePage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeController.forward();
    _staggerController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isCompact = size.height < 700;

    return PopScope(
      canPop: false,
      child: Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withOpacity(0.10),
              AppColors.background,
              AppColors.background,
            ],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: 24,
              vertical: isCompact ? 24 : 40,
            ),
            child: Column(
              children: [
                SizedBox(height: isCompact ? 16 : 40),
                // Header
                FadeTransition(
                  opacity: _fadeController,
                  child: _buildHeader(isCompact),
                ),
                SizedBox(height: isCompact ? 32 : 48),
                // Choice cards
                _buildCard(
                  index: 0,
                  icon: Icons.apartment_rounded,
                  title: 'Set up my school',
                  subtitle:
                      'Configure grades, sections, and subjects for your entire school. Invite teachers later.',
                  gradient: const [Color(0xFF007AFF), Color(0xFF5856D6)],
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    context.go(AppRoutes.adminSetupWizard);
                  },
                ),
                const SizedBox(height: 20),
                _buildCard(
                  index: 1,
                  icon: Icons.person_rounded,
                  title: "I'm a solo teacher",
                  subtitle:
                      'Quick setup to start creating question papers. Just tell us what you teach.',
                  gradient: const [Color(0xFF11998e), Color(0xFF38ef7d)],
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    context.go(AppRoutes.soloTeacherSetup);
                  },
                ),
                SizedBox(height: isCompact ? 24 : 40),
                // Footer hint
                FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _staggerController,
                    curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
                  ),
                  child: Text(
                    'You can always change this later in Settings',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildHeader(bool isCompact) {
    return Column(
      children: [
        // App icon
        Container(
          width: isCompact ? 64 : 76,
          height: isCompact ? 64 : 76,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.30),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(
            Icons.auto_stories_rounded,
            color: Colors.white,
            size: isCompact ? 32 : 38,
          ),
        ),
        SizedBox(height: isCompact ? 20 : 28),
        Text(
          'Welcome to Papercraft',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isCompact ? 26 : 30,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'How would you like to get started?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    final staggerInterval = Interval(
      0.2 + index * 0.2,
      0.6 + index * 0.2,
      curve: Curves.easeOutCubic,
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.15),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _staggerController,
        curve: staggerInterval,
      )),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _staggerController,
          curve: staggerInterval,
        ),
        child: _ChoiceCard(
          icon: icon,
          title: title,
          subtitle: subtitle,
          gradient: gradient,
          onTap: onTap,
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_ChoiceCard> createState() => _ChoiceCardState();
}

class _ChoiceCardState extends State<_ChoiceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pressController,
      builder: (context, child) {
        final scale = 1.0 - (_pressController.value * 0.03);
        return Transform.scale(scale: scale, child: child);
      },
      child: GestureDetector(
        onTapDown: (_) => _pressController.forward(),
        onTapUp: (_) {
          _pressController.reverse();
          widget.onTap();
        },
        onTapCancel: () => _pressController.reverse(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: widget.gradient[0].withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon circle
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.gradient,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: widget.gradient[0].withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  widget.icon,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 20),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Arrow
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.gradient[0].withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: widget.gradient[0],
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
