import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../../../core/presentation/routes/app_routes.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    // Start animations
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _fadeController.forward();
        _slideController.forward();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _handleAuthState(BuildContext context, AuthState state) {
    if (state is AuthError) {
      _showErrorDialog(context, state.message);
    }
    if (state is AuthAuthenticated) {
      _navigateToHome(context);
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign In Failed', style: TextStyle(fontWeight: FontWeight.w600)),
        content: Text(message, style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Try Again', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _navigateToHome(BuildContext context) {
    context.go(AppRoutes.home);
  }

  void _triggerSignIn(BuildContext context) {
    context.read<AuthBloc>().add(const AuthSignInGoogle());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocListener<AuthBloc, AuthState>(
        listener: _handleAuthState,
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            return LayoutBuilder(
              builder: (context, constraints) {
                return _ResponsiveLoginLayout(
                  constraints: constraints,
                  fadeAnimation: _fadeAnimation,
                  slideAnimation: _slideAnimation,
                  isLoading: state is AuthLoading,
                  onSignIn: () => _triggerSignIn(context),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ResponsiveLoginLayout extends StatelessWidget {
  final BoxConstraints constraints;
  final Animation<double> fadeAnimation;
  final Animation<Offset> slideAnimation;
  final bool isLoading;
  final VoidCallback onSignIn;

  const _ResponsiveLoginLayout({
    required this.constraints,
    required this.fadeAnimation,
    required this.slideAnimation,
    required this.isLoading,
    required this.onSignIn,
  });

  // Responsive breakpoints
  bool get isMobile => constraints.maxWidth < 600;
  bool get isTablet => constraints.maxWidth >= 600 && constraints.maxWidth < 1024;
  bool get isDesktop => constraints.maxWidth >= 1024;
  bool get isVeryWide => constraints.maxWidth >= 1440;
  bool get isShortScreen => constraints.maxHeight < 600;

  // Dynamic sizing based on screen size
  double get maxContentWidth {
    if (isMobile) return double.infinity;
    if (isTablet) return 480;
    if (isDesktop) return 420;
    return 400;
  }

  EdgeInsets get padding {
    if (isMobile) {
      return EdgeInsets.symmetric(
        horizontal: constraints.maxWidth * 0.08, // 8% of screen width
        vertical: isShortScreen ? 16 : 24,
      );
    }
    if (isTablet) return const EdgeInsets.all(48);
    return const EdgeInsets.all(64);
  }

  double get logoSize {
    if (isMobile) return isShortScreen ? 60 : 80;
    if (isTablet) return 90;
    return 100;
  }

  double get titleFontSize {
    if (isMobile) return isShortScreen ? 28 : 32;
    if (isTablet) return 36;
    return 40;
  }

  double get subtitleFontSize {
    if (isMobile) return 16;
    if (isTablet) return 18;
    return 20;
  }

  double get buttonHeight {
    if (isMobile) return 56;
    if (isTablet) return 60;
    return 64;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: Padding(
            padding: padding,
            child: isShortScreen
                ? _buildCompactLayout()
                : _buildStandardLayout(),
          ),
        ),
      ),
    );
  }

  Widget _buildStandardLayout() {
    return Column(
      children: [
        Expanded(
          flex: isDesktop ? 3 : 2,
          child: _buildHeader(),
        ),
        Expanded(
          child: _buildActionSection(),
        ),
        if (!isMobile) const SizedBox(height: 24),
        _buildFooter(),
      ],
    );
  }

  Widget _buildCompactLayout() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: constraints.maxHeight * 0.1),
          _buildHeader(),
          SizedBox(height: constraints.maxHeight * 0.08),
          _buildActionSection(),
          SizedBox(height: constraints.maxHeight * 0.06),
          _buildFooter(),
          SizedBox(height: constraints.maxHeight * 0.04),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: logoSize,
              height: logoSize,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(logoSize * 0.25),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: logoSize * 0.25,
                    offset: Offset(0, logoSize * 0.125),
                  ),
                ],
              ),
              child: Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: logoSize * 0.5,
              ),
            ),
            SizedBox(height: isShortScreen ? 20 : 32),
            Text(
              'Papercraft',
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: isShortScreen ? 8 : 12),
            Text(
              'Create, organize, and manage\nyour question papers easily',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: subtitleFontSize,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSection() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          const _LoadingIndicator()
        else ...[
          _SignInButton(
            onPressed: onSignIn,
            height: buttonHeight,
          ),
          SizedBox(height: isShortScreen ? 16 : 24),
          Text(
            'Currently supporting Google sign-in.\nMore providers coming soon.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
              color: AppColors.textTertiary,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFooter() {
    return Text(
      'By continuing, you agree to our Terms of Service\nand Privacy Policy',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: isMobile ? 12 : 13,
        color: AppColors.textTertiary,
        height: 1.3,
      ),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Signing you in...',
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SignInButton extends StatefulWidget {
  final VoidCallback onPressed;
  final double height;

  const _SignInButton({
    required this.onPressed,
    required this.height,
  });

  @override
  State<_SignInButton> createState() => _SignInButtonState();
}

class _SignInButtonState extends State<_SignInButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return AnimatedScale(
      scale: _isPressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: Container(
          width: double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: isDesktop ? 15 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onPressed,
              borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.white,
                      ),
                      child: Image.network(
                        'https://cdn.jsdelivr.net/gh/devicons/devicon/icons/google/google-original.svg',
                        width: 20,
                        height: 20,
                        errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.g_mobiledata, color: Colors.blue, size: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Continue with Google',
                      style: TextStyle(
                        fontSize: isDesktop ? 17 : 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}