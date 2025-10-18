import 'package:flutter/material.dart';
// Add this import

/// App-wide color palette following Apple's design principles
/// Supports both light and dark themes with semantic color naming
class AppColors {
  AppColors._();

  // MARK: - Primary Colors
  static const Color primary = Color(0xFF007AFF); // Apple blue
  static const Color primaryDark = Color(0xFF0056CC);
  static const Color primaryLight = Color(0xFF4DA2FF);

  // Primary color opacity variants (pre-computed for performance)
  static const Color primary05 = Color(0x0D007AFF); // 5% opacity
  static const Color primary10 = Color(0x1A007AFF); // 10% opacity
  static const Color primary20 = Color(0x33007AFF); // 20% opacity
  static const Color primary30 = Color(0x4D007AFF); // 30% opacity
  static const Color primary40 = Color(0x66007AFF); // 40% opacity
  static const Color primary50 = Color(0x80007AFF); // 50% opacity

  // MARK: - Secondary Colors
  static const Color secondary = Color(0xFF5856D6); // Apple purple
  static const Color accent = Color(0xFFFF9500); // Apple orange
  static const Color success = Color(0xFF30D158); // Apple green
  static const Color warning = Color(0xFFFF9F0A); // Apple yellow
  static const Color error = Color(0xFFFF3B30); // Apple red

  // Secondary color opacity variants
  static const Color secondary10 = Color(0x1A5856D6); // 10% opacity
  static const Color success10 = Color(0x1A30D158); // 10% opacity
  static const Color warning10 = Color(0x1AFF9F0A); // 10% opacity
  static const Color error10 = Color(0x1AFF3B30); // 10% opacity

  // MARK: - Neutral Colors
  static const Color textPrimary = Color(0xFF1D1D1F);
  static const Color textSecondary = Color(0xFF6E6E73);
  static const Color textTertiary = Color(0xFF8E8E93);
  static const Color textPlaceholder = Color(0xFFC7C7CC);

  static const Color background = Color(0xFFFAFAFC);
  static const Color backgroundSecondary = Color(0xFFF2F2F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSecondary = Color(0xFFF8F8F8);

  static const Color border = Color(0xFFE5E5EA);
  static const Color borderSecondary = Color(0xFFD1D1D6);
  static const Color separator = Color(0xFFE5E5EA);

  // MARK: - Dark Theme Colors
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkBackgroundSecondary = Color(0xFF1C1C1E);
  static const Color darkSurface = Color(0xFF2C2C2E);
  static const Color darkSurfaceSecondary = Color(0xFF3A3A3C);

  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF98989D);
  static const Color darkTextTertiary = Color(0xFF636366);

  static const Color darkBorder = Color(0xFF38383A);
  static const Color darkBorderSecondary = Color(0xFF48484A);
  static const Color darkSeparator = Color(0xFF38383A);

  // MARK: - Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF007AFF),
      Color(0xFF5856D6),
    ],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFF9500),
      Color(0xFFFF6B35),
    ],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF30D158),
      Color(0xFF28CD41),
    ],
  );

  // MARK: - Semantic Colors with Context
  static const Color cardBackground = surface;
  static const Color inputBackground = Color(0xFFF7F7F7);
  static const Color inputBorder = Color(0xFFE0E0E0);
  static const Color inputFocusedBorder = primary;

  static const Color buttonPrimary = primary;
  static const Color buttonSecondary = Color(0xFFF2F2F7);
  static const Color buttonDestructive = error;

  static const Color overlayLight = Color(0x1A000000); // 10% black
  static const Color overlayMedium = Color(0x33000000); // 20% black
  static const Color overlayDark = Color(0x4D000000); // 30% black
  static const Color shimmer = Color(0xFFF0F0F0);

  // White opacity variants (for overlays on colored backgrounds)
  static const Color white05 = Color(0x0DFFFFFF); // 5% white
  static const Color white10 = Color(0x1AFFFFFF); // 10% white
  static const Color white20 = Color(0x33FFFFFF); // 20% white
  static const Color white30 = Color(0x4DFFFFFF); // 30% white

  // Additional opacity variants for common use cases
  static const Color black04 = Color(0x0A000000); // 4% black (for subtle shadows)
  static const Color black08 = Color(0x14000000); // 8% black
  static const Color primary08 = Color(0x14007AFF); // 8% primary
  static const Color secondary08 = Color(0x145856D6); // 8% secondary
  static const Color error05 = Color(0x0DFF3B30); // 5% error
  static const Color error20 = Color(0x33FF3B30); // 20% error
  static const Color error30 = Color(0x4DFF3B30); // 30% error
  static const Color error80 = Color(0xCCFF3B30); // 80% error
  static const Color success05 = Color(0x0D30D158); // 5% success (not 10)
  static const Color textSecondary70 = Color(0xB36E6E73); // 70% text secondary

  // MARK: - Status Colors
  static const Color online = Color(0xFF30D158);
  static const Color offline = Color(0xFF8E8E93);
  static const Color away = Color(0xFFFF9500);
  static const Color busy = Color(0xFFFF3B30);

  // MARK: - Helper Methods

  /// Returns appropriate text color based on background brightness
  static Color getTextColorForBackground(Color backgroundColor) {
    return backgroundColor.computeLuminance() > 0.5
        ? textPrimary
        : darkTextPrimary;
  }

  /// Returns a color with specified opacity
  static Color withOpacity(Color color, double opacity) {
    return color.withValues(alpha: opacity);
  }

  /// Lightens a color by a given amount (0.0 to 1.0)
  static Color lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

  /// Darkens a color by a given amount (0.0 to 1.0)
  static Color darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

  // MARK: - Theme Data Helpers

  /// Returns light theme color scheme
  static ColorScheme get lightColorScheme => const ColorScheme.light(
    primary: primary,
    primaryContainer: primaryLight,
    secondary: secondary,
    surface: surface,
    surfaceContainer: surfaceSecondary,
    error: error,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: textPrimary,
    onError: Colors.white,
    outline: border,
    shadow: Color(0x1A000000),
  );

  /// Returns dark theme color scheme
  static ColorScheme get darkColorScheme => const ColorScheme.dark(
    primary: primary,
    primaryContainer: primaryDark,
    secondary: secondary,
    surface: darkSurface,
    surfaceContainer: darkSurfaceSecondary,
    error: error,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: darkTextPrimary,
    onError: Colors.white,
    outline: darkBorder,
    shadow: Color(0x3D000000),
  );
}

// MARK: - Extension Methods for Gradient Utilities
extension GradientExtensions on LinearGradient {
  /// Scale gradient opacity
  LinearGradient scale(double opacity) {
    return LinearGradient(
      begin: begin,
      end: end,
      colors: colors.map((color) => color.withValues(alpha: opacity)).toList(),
      stops: stops,
    );
  }
}
