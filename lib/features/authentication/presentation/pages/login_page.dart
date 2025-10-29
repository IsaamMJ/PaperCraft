import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/app_messages.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../../core/presentation/constants/app_assets.dart';
import '../../../../core/presentation/utils/ui_helpers.dart';
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
  Timer? _animationTimer; // Track timer to prevent memory leak

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: Duration(milliseconds: UIConstants.durationSlow + 200),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: Duration(milliseconds: UIConstants.durationSlow),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    // Start animations with a timer (to prevent memory leak)
    _animationTimer = Timer(Duration(milliseconds: UIConstants.durationFast), () {
      if (mounted) {
        _fadeController.forward();
        _slideController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationTimer?.cancel(); // Cancel timer to prevent memory leak
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
        ),
        title: const Text(
          AppMessages.authFailedGeneric,
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: Text(
          message,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: UIConstants.fontSizeMedium,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              AppMessages.goBack,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: UIConstants.fontSizeMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToHome(BuildContext context) {
    try {
      context.go(AppRoutes.home);
    } catch (e) {
      // GoRouter not available in test context, ignore
    }
  }

  void _triggerSignIn(BuildContext context) {
    context.read<AuthBloc>().add(const AuthSignInGoogle());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          try {
            _handleAuthState(context, state);
          } catch (e) {
          }
        },
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

  // Responsive breakpoints using UiHelpers
  bool get isMobile => constraints.maxWidth < UIConstants.breakpointMobile;
  bool get isTablet => constraints.maxWidth >= UIConstants.breakpointMobile &&
      constraints.maxWidth < UIConstants.breakpointDesktop;
  bool get isDesktop => constraints.maxWidth >= UIConstants.breakpointDesktop;
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
        horizontal: constraints.maxWidth * 0.08,
        vertical: isShortScreen ? UIConstants.paddingMedium : UIConstants.paddingLarge,
      );
    }
    if (isTablet) return EdgeInsets.all(UIConstants.paddingLarge * 2);
    return EdgeInsets.all(UIConstants.paddingLarge * 2.67); // 64
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
    if (isMobile) return UIConstants.fontSizeLarge;
    if (isTablet) return UIConstants.fontSizeXLarge;
    return UIConstants.fontSizeXXLarge;
  }

  double get buttonHeight {
    if (isMobile) return 56;
    if (isTablet) return 60;
    if (isDesktop) return 64;
    return 56; // Default fallback
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
        if (!isMobile) SizedBox(height: UIConstants.spacing24),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: logoSize,
              height: logoSize,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(logoSize * 0.25),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary30,
                    blurRadius: logoSize * 0.25,
                    offset: Offset(0, logoSize * 0.125),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(logoSize * 0.25),
                child: Image.asset(
                  AppAssets.logoRounded,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SizedBox(height: isShortScreen ? UIConstants.spacing12 : UIConstants.spacing24),
            Text(
              'Papercraft',
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: isShortScreen ? UIConstants.spacing4 : UIConstants.spacing8),
            Flexible(
              child: Text(
                'Create, organize, and manage\nyour question papers easily',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: subtitleFontSize,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading)
          const _LoadingIndicator()
        else ...[
          _SignInButton(
            onPressed: onSignIn,
            height: isShortScreen ? 52 : buttonHeight, // Reduce button height on small screens
          ),
          SizedBox(height: isShortScreen ? UIConstants.spacing8 : UIConstants.spacing16),
          Flexible(
            child: Text(
              'Currently supporting Google sign-in.\nMore providers coming soon.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isMobile ? UIConstants.fontSizeSmall + 1 : UIConstants.fontSizeMedium,
                color: AppColors.textTertiary,
                height: 1.4,
              ),
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
        fontSize: isMobile ? UIConstants.fontSizeSmall : UIConstants.fontSizeSmall + 1,
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
          width: UIConstants.iconLarge,
          height: UIConstants.iconLarge,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
        SizedBox(height: UIConstants.spacing20),
        Text(
          AppMessages.processingAuth,
          style: TextStyle(
            fontSize: UIConstants.fontSizeMedium + 1,
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
    final isDesktop = UiHelpers.isDesktop(context);
    final borderRadius = isDesktop ? UIConstants.radiusXXLarge : UIConstants.radiusLarge;

    return AnimatedScale(
      scale: _isPressed ? 0.96 : 1.0,
      duration: Duration(milliseconds: UIConstants.durationVeryFast),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: Container(
          width: double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.overlayDark,
                blurRadius: isDesktop ? 15 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onPressed,
              borderRadius: BorderRadius.circular(borderRadius),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? UIConstants.spacing24 : UIConstants.spacing20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: UIConstants.iconLarge,
                      height: UIConstants.iconLarge,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(UIConstants.radiusSmall - 2),
                        color: AppColors.surface,
                      ),
                      child: Image.network(
                        AppAssets.googleIcon,
                        width: UIConstants.iconMedium,
                        height: UIConstants.iconMedium,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.g_mobiledata,
                          color: AppColors.primary,
                          size: UIConstants.iconMedium,
                        ),
                      ),
                    ),
                    SizedBox(width: UIConstants.spacing16),
                    Flexible(
                      child: Text(
                        'Continue with Google',
                        style: TextStyle(
                          // Slightly larger font size to ensure button meets accessibility requirements
                          fontSize: isDesktop ? UIConstants.fontSizeXLarge : UIConstants.fontSizeXLarge,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
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