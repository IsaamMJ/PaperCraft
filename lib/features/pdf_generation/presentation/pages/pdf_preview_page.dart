import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:printing/printing.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';

class PdfPreviewPage extends StatelessWidget {
  final Uint8List pdfBytes;
  final String paperTitle;
  final String layoutType;
  final VoidCallback onDownload;

  const PdfPreviewPage({
    super.key,
    required this.pdfBytes,
    required this.paperTitle,
    required this.layoutType,
    required this.onDownload,
  });

  void _handleDownload(BuildContext context) {
    onDownload();
    Navigator.pop(context);
  }

  Future<void> _handlePrint(BuildContext context) async {
    try {
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: paperTitle,
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
          IconButton(
            onPressed: () => _handleDownload(context),
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Download PDF',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPaperInfoHeader(),
          _buildPdfViewer(),
          _buildBottomActionBar(context),
        ],
      ),
    );
  }

  Widget _buildPaperInfoHeader() {
    final layoutName = layoutType == 'single' ? 'Single Page Layout' : 'Side-by-Side Layout';

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
                  paperTitle,
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
            pdfBytes,
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
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handlePrint(context),
                    icon: Icon(Icons.print_rounded, color: AppColors.primary),
                    label: Text(
                      'Print',
                      style: TextStyle(color: AppColors.primary),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: UIConstants.spacing12,
                      ),
                      side: BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: UIConstants.spacing12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleDownload(context),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Download'),
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
              ],
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

