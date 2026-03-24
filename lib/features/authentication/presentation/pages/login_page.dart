import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/app_messages.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../../core/presentation/constants/app_assets.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _staggerController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _fadeController.forward();
        _staggerController.forward();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _staggerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleAuthState(BuildContext context, AuthState state) {
    if (state is AuthError) {
      _showErrorDialog(context, state.message);
    }
    // Navigation after authentication is handled by GoRouter's refreshListenable.
    // Do NOT call context.go() here — it races with GoRouter's redirect chain
    // and can bypass onboarding/initialization gates.
  }

  void _showErrorDialog(BuildContext context, String message) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        icon: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.error10,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 28,
          ),
        ),
        title: const Text(
          AppMessages.authFailedGeneric,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 15,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Try Again',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _triggerSignIn(BuildContext context) {
    HapticFeedback.mediumImpact();
    context.read<AuthBloc>().add(const AuthSignInGoogle());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          try {
            _handleAuthState(context, state);
          } catch (_) {}
        },
        child: BlocBuilder<AuthBloc, AuthState>(
          buildWhen: (previous, current) {
            final wasLoading = previous is AuthLoading;
            final isLoading = current is AuthLoading;
            return wasLoading != isLoading;
          },
          builder: (context, state) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop =
                    constraints.maxWidth >= UIConstants.breakpointDesktop;
                if (isDesktop) {
                  return _DesktopLayout(
                    fadeController: _fadeController,
                    staggerController: _staggerController,
                    isLoading: state is AuthLoading,
                    onSignIn: () => _triggerSignIn(context),
                  );
                }
                return _MobileLayout(
                  fadeController: _fadeController,
                  staggerController: _staggerController,
                  pulseController: _pulseController,
                  isLoading: state is AuthLoading,
                  onSignIn: () => _triggerSignIn(context),
                  isCompact: constraints.maxHeight < 680,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MOBILE LAYOUT
// ---------------------------------------------------------------------------
class _MobileLayout extends StatelessWidget {
  final AnimationController fadeController;
  final AnimationController staggerController;
  final AnimationController pulseController;
  final bool isLoading;
  final VoidCallback onSignIn;
  final bool isCompact;

  const _MobileLayout({
    required this.fadeController,
    required this.staggerController,
    required this.pulseController,
    required this.isLoading,
    required this.onSignIn,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: 28,
            vertical: isCompact ? 20 : 32,
          ),
          child: Column(
            children: [
              SizedBox(height: isCompact ? 32 : 60),
              // Logo + Title
              _buildStaggered(
                index: 0,
                child: _buildLogo(context),
              ),
              SizedBox(height: isCompact ? 12 : 20),
              _buildStaggered(
                index: 1,
                child: _buildTitle(),
              ),
              SizedBox(height: isCompact ? 8 : 12),
              _buildStaggered(
                index: 2,
                child: _buildSubtitle(),
              ),
              SizedBox(height: isCompact ? 36 : 56),
              // Sign-in button or loading
              _buildStaggered(
                index: 3,
                child: isLoading
                    ? _buildLoadingState()
                    : _GoogleSignInButton(
                        onPressed: onSignIn,
                        height: 56,
                      ),
              ),
              SizedBox(height: isCompact ? 24 : 40),
              // Feature highlights
              _buildStaggered(
                index: 4,
                child: _buildFeatureHighlights(),
              ),
              SizedBox(height: isCompact ? 24 : 40),
              // Footer
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: staggerController,
                  curve: const Interval(0.8, 1.0, curve: Curves.easeOut),
                ),
                child: _buildFooter(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStaggered({required int index, required Widget child}) {
    final start = (0.1 + index * 0.12).clamp(0.0, 0.8);
    final end = (start + 0.3).clamp(0.0, 1.0);
    final interval = Interval(start, end, curve: Curves.easeOutCubic);

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.12),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: staggerController, curve: interval)),
      child: FadeTransition(
        opacity:
            CurvedAnimation(parent: staggerController, curve: interval),
        child: child,
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        final glowOpacity = 0.20 + (pulseController.value * 0.12);
        return Container(
          width: isCompact ? 80 : 96,
          height: isCompact ? 80 : 96,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(glowOpacity),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.asset(
              AppAssets.logoRounded,
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTitle() {
    return Text(
      'Papercraft',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: isCompact ? 32 : 38,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.8,
        height: 1.1,
      ),
    );
  }

  Widget _buildSubtitle() {
    return Text(
      'Create and manage question papers\nwith ease',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 16,
        color: AppColors.textSecondary,
        height: 1.5,
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            AppMessages.processingAuth,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureHighlights() {
    return Column(
      children: [
        _FeatureRow(
          icon: Icons.auto_stories_rounded,
          text: 'Smart question paper creation',
          color: AppColors.primary,
        ),
        const SizedBox(height: 14),
        _FeatureRow(
          icon: Icons.groups_rounded,
          text: 'Collaborate with your team',
          color: AppColors.secondary,
        ),
        const SizedBox(height: 14),
        _FeatureRow(
          icon: Icons.lock_rounded,
          text: 'Secure & private',
          color: AppColors.success,
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Text(
      'By continuing, you agree to our Terms of Service\nand Privacy Policy',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12,
        color: AppColors.textTertiary,
        height: 1.4,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FEATURE ROW
// ---------------------------------------------------------------------------
class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _FeatureRow({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// DESKTOP LAYOUT
// ---------------------------------------------------------------------------
class _DesktopLayout extends StatelessWidget {
  final AnimationController fadeController;
  final AnimationController staggerController;
  final bool isLoading;
  final VoidCallback onSignIn;

  const _DesktopLayout({
    required this.fadeController,
    required this.staggerController,
    required this.isLoading,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // LEFT: Hero section
        Expanded(
          flex: 1,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF007AFF),
                  Color(0xFF5856D6),
                  Color(0xFF4B3FCC),
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(72),
                child: FadeTransition(
                  opacity: fadeController,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset(
                            AppAssets.logoRounded,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),
                      const Text(
                        'Manage Question\nPapers with Ease',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.2,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Create, organize, and distribute question papers\nin minutes. Trusted by educational institutions.',
                        style: TextStyle(
                          fontSize: 17,
                          color: Colors.white.withOpacity(0.85),
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 40),
                      _buildDesktopFeature(
                        Icons.auto_stories_rounded,
                        'Smart paper creation with templates',
                      ),
                      const SizedBox(height: 18),
                      _buildDesktopFeature(
                        Icons.groups_rounded,
                        'Multi-teacher collaboration & review',
                      ),
                      const SizedBox(height: 18),
                      _buildDesktopFeature(
                        Icons.verified_user_rounded,
                        'Secure & GDPR compliant',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // RIGHT: Sign-in form
        Expanded(
          flex: 1,
          child: Container(
            color: AppColors.background,
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.05, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: staggerController,
                        curve: const Interval(0.2, 0.7,
                            curve: Curves.easeOutCubic),
                      )),
                      child: FadeTransition(
                        opacity: CurvedAnimation(
                          parent: staggerController,
                          curve: const Interval(0.2, 0.7,
                              curve: Curves.easeOut),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Welcome back',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Sign in to continue to Papercraft',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 40),
                            isLoading
                                ? _buildDesktopLoading()
                                : _GoogleSignInButton(
                                    onPressed: onSignIn,
                                    height: 60,
                                  ),
                            const SizedBox(height: 32),
                            Text(
                              'By continuing, you agree to our\nTerms of Service and Privacy Policy',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textTertiary,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopFeature(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLoading() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Signing you in...',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// GOOGLE SIGN-IN BUTTON
// ---------------------------------------------------------------------------
class _GoogleSignInButton extends StatefulWidget {
  final VoidCallback onPressed;
  final double height;

  const _GoogleSignInButton({
    required this.onPressed,
    required this.height,
  });

  @override
  State<_GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<_GoogleSignInButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  bool _isClickDisabled = false;
  Timer? _debounceTimer;

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
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    if (_isClickDisabled) return;
    _isClickDisabled = true;
    HapticFeedback.mediumImpact();
    widget.onPressed();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isClickDisabled = false);
    });
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
        onTapDown: (_) {
          if (!_isClickDisabled) _pressController.forward();
        },
        onTapUp: (_) {
          _pressController.reverse();
          if (!_isClickDisabled) _handleTap();
        },
        onTapCancel: () => _pressController.reverse(),
        child: Container(
          width: double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(widget.height / 2),
            border: Border.all(
              color: AppColors.border,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
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
          child: Semantics(
            label: 'Sign in with Google account',
            button: true,
            enabled: !_isClickDisabled,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.white,
                  ),
                  child: Image.network(
                    AppAssets.googleIcon,
                    width: 22,
                    height: 22,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.g_mobiledata,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  'Continue with Google',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
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
