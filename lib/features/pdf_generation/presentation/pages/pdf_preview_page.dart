import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:printing/printing.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';

/// PDF layout density options for question papers
/// Based on typography standards and teacher feedback
enum PdfLayoutDensity {
  compact,      // Maximum questions per page (formerly "normal")
  standard,     // Balanced spacing - recommended (formerly "spacious")
  spacious,     // Extra breathing room (formerly "extraSpacious")
}

class PdfPreviewPage extends StatefulWidget {
  final Uint8List pdfBytes;
  final String paperTitle;
  final String layoutType;
  final Future<Uint8List> Function(double fontMultiplier, double spacingMultiplier)? onRegeneratePdf;

  const PdfPreviewPage({
    super.key,
    required this.pdfBytes,
    required this.paperTitle,
    required this.layoutType,
    this.onRegeneratePdf,
  });

  @override
  State<PdfPreviewPage> createState() => _PdfPreviewPageState();
}

class _PdfPreviewPageState extends State<PdfPreviewPage> {
  late Uint8List _currentPdfBytes;
  PdfLayoutDensity _selectedDensity = PdfLayoutDensity.standard; // Default to Standard (recommended)
  bool _isRegenerating = false;
  bool _showAdvancedSettings = false;

  // Custom slider values (initialized to Standard preset values)
  double _customFontMultiplier = 1.0;
  double _customSpacingMultiplier = 1.5;

  // Debounce timer for slider changes
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _currentPdfBytes = widget.pdfBytes;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Get font and spacing multipliers based on layout density
  /// Returns (fontMultiplier, spacingMultiplier)
  ///
  /// These multipliers are applied on top of PdfLayoutConfig base values
  /// to create the three density presets teachers can choose from
  (double, double) _getMultipliersForDensity(PdfLayoutDensity density) {
    switch (density) {
      case PdfLayoutDensity.compact:
        // Compact: Minimal spacing, max questions per page
        return (1.0, 1.0);  // Base config values as-is

      case PdfLayoutDensity.standard:
        // Standard (Recommended): Balanced professional appearance
        return (1.0, 1.5);  // 50% more spacing than compact

      case PdfLayoutDensity.spacious:
        // Spacious: Extra breathing room for short exams
        return (1.1, 2.0);  // 110% font, double spacing
    }
  }

  Future<void> _handleDensityChange(PdfLayoutDensity density) async {
    if (_isRegenerating || widget.onRegeneratePdf == null || density == _selectedDensity) return;

    final (fontMultiplier, spacingMultiplier) = _getMultipliersForDensity(density);

    setState(() {
      _isRegenerating = true;
      _selectedDensity = density;
      // Sync slider values with preset
      _customFontMultiplier = fontMultiplier;
      _customSpacingMultiplier = spacingMultiplier;
    });

    try {
      final newPdfBytes = await widget.onRegeneratePdf!(fontMultiplier, spacingMultiplier);

      if (mounted) {
        setState(() {
          _currentPdfBytes = newPdfBytes;
          _isRegenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRegenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to regenerate PDF. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Handle custom slider changes with debouncing (500ms delay)
  void _handleCustomSliderChange(double fontMultiplier, double spacingMultiplier) {
    if (_isRegenerating || widget.onRegeneratePdf == null) return;

    setState(() {
      _customFontMultiplier = fontMultiplier;
      _customSpacingMultiplier = spacingMultiplier;
    });

    // Cancel previous timer
    _debounceTimer?.cancel();

    // Start new timer for regeneration (500ms delay)
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted || _isRegenerating) return;

      setState(() => _isRegenerating = true);

      try {
        final newPdfBytes = await widget.onRegeneratePdf!(fontMultiplier, spacingMultiplier);

        if (mounted) {
          setState(() {
            _currentPdfBytes = newPdfBytes;
            _isRegenerating = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isRegenerating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to regenerate PDF. Please try again.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    });
  }

  Future<void> _handlePrint(BuildContext context) async {
    try {
      await Printing.layoutPdf(
        onLayout: (format) async => _currentPdfBytes,
        name: widget.paperTitle,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to print. Please check if a printer is available.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('PDF Preview'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _handlePrint(context),
            icon: const Icon(Icons.print_rounded),
            tooltip: 'Print PDF',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPaperInfoHeader(),
          if (widget.onRegeneratePdf != null) _buildLayoutControls(),
          _buildPdfViewer(),
          _buildBottomActionBar(context),
        ],
      ),
    );
  }

  Widget _buildPaperInfoHeader() {
    final layoutName = widget.layoutType == 'single' ? 'Single Page Layout' : 'Side-by-Side Layout';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(UIConstants.paddingMedium),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.paperTitle,
                  style: TextStyle(
                    fontSize: UIConstants.fontSizeLarge,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Text(
                  layoutName,
                  style: TextStyle(
                    fontSize: UIConstants.fontSizeSmall,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: UIConstants.spacing4),
          Text(
            'Preview how your paper will look when printed',
            style: TextStyle(
              fontSize: UIConstants.fontSizeMedium,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLayoutControls() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: UIConstants.paddingMedium,
        vertical: UIConstants.spacing8,
      ),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Layout Density',
            style: TextStyle(
              fontSize: UIConstants.fontSizeMedium,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: UIConstants.spacing8),
          Row(
            children: [
              _buildDensityOption(
                PdfLayoutDensity.compact,
                'Compact',
                'Max questions per page',
                Icons.compress_rounded,
              ),
              SizedBox(width: 8),
              _buildDensityOption(
                PdfLayoutDensity.standard,
                'Standard',
                'Balanced (Recommended)',
                Icons.view_agenda_rounded,
              ),
              SizedBox(width: 8),
              _buildDensityOption(
                PdfLayoutDensity.spacious,
                'Spacious',
                'Extra breathing room',
                Icons.open_in_full_rounded,
              ),
            ],
          ),
          if (_isRegenerating) ...[
            SizedBox(height: UIConstants.spacing8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Regenerating PDF...',
                  style: TextStyle(
                    fontSize: UIConstants.fontSizeSmall,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: UIConstants.spacing12),
          _buildAdvancedSettings(),
        ],
      ),
    );
  }

  Widget _buildDensityOption(
    PdfLayoutDensity density,
    String label,
    String description,
    IconData icon,
  ) {
    final isSelected = _selectedDensity == density;
    final isDisabled = _isRegenerating;

    return Expanded(
      child: GestureDetector(
        onTap: isDisabled ? null : () => _handleDensityChange(density),
        child: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.1)
                : AppColors.background,
            borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.border.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textSecondary,
                size: 20,
              ),
              SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdvancedSettings() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          childrenPadding: EdgeInsets.only(left: 12, right: 12, bottom: 12),
          initiallyExpanded: _showAdvancedSettings,
          onExpansionChanged: (expanded) {
            setState(() => _showAdvancedSettings = expanded);
          },
          leading: Icon(
            Icons.tune_rounded,
            color: _showAdvancedSettings ? AppColors.primary : AppColors.textSecondary,
            size: 20,
          ),
          title: Text(
            'Advanced Settings',
            style: TextStyle(
              fontSize: UIConstants.fontSizeSmall,
              fontWeight: FontWeight.w600,
              color: _showAdvancedSettings ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            'Fine-tune font size and spacing',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
          children: [
            // Font Size Slider
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Font Size',
                      style: TextStyle(
                        fontSize: UIConstants.fontSizeSmall,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${(_customFontMultiplier * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _customFontMultiplier,
                  min: 0.8,
                  max: 1.3,
                  divisions: 10,
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.border,
                  onChanged: _isRegenerating
                      ? null
                      : (value) {
                          _handleCustomSliderChange(value, _customSpacingMultiplier);
                        },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Smaller', style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                    Text('Larger', style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16),
            // Spacing Slider
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Spacing',
                      style: TextStyle(
                        fontSize: UIConstants.fontSizeSmall,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${_customSpacingMultiplier.toStringAsFixed(1)}×',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _customSpacingMultiplier,
                  min: 0.5,
                  max: 3.0,
                  divisions: 10,
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.border,
                  onChanged: _isRegenerating
                      ? null
                      : (value) {
                          _handleCustomSliderChange(_customFontMultiplier, value);
                        },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Compact', style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                    Text('Spacious', style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12),
            // Reset button
            TextButton.icon(
              onPressed: _isRegenerating
                  ? null
                  : () {
                      // Reset to Standard preset
                      _handleCustomSliderChange(1.0, 1.5);
                    },
              icon: Icon(Icons.restart_alt_rounded, size: 16),
              label: Text('Reset to Standard'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfViewer() {
    return Expanded(
      child: Container(
        margin: EdgeInsets.all(UIConstants.paddingMedium),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
          child: SfPdfViewer.memory(
            _currentPdfBytes,
            key: ValueKey(_currentPdfBytes.hashCode),
            enableDoubleTapZooming: true,
            enableTextSelection: false,
            canShowScrollHead: true,
            canShowScrollStatus: true,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(UIConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(UIConstants.radiusXLarge),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _handlePrint(context),
                icon: Icon(Icons.print_rounded),
                label: Text('Print PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    vertical: UIConstants.spacing12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                  ),
                ),
              ),
            ),
            SizedBox(height: UIConstants.spacing8),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back, color: AppColors.textSecondary, size: 18),
              label: Text(
                'Back to Paper Details',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  vertical: UIConstants.spacing8,
                ),
                side: BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

