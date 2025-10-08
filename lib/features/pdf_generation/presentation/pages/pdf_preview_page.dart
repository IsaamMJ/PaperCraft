import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';

class PdfPreviewPage extends StatelessWidget {
  final Uint8List pdfBytes;
  final String paperTitle;
  final VoidCallback onDownload;
  final VoidCallback onGenerateDual;

  const PdfPreviewPage({
    super.key,
    required this.pdfBytes,
    required this.paperTitle,
    required this.onDownload,
    required this.onGenerateDual,
  });

  void _showDownloadOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: EdgeInsets.all(UIConstants.paddingMedium),
        padding: EdgeInsets.all(UIConstants.paddingLarge),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(UIConstants.radiusXXLarge),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Download Options',
              style: TextStyle(
                fontSize: UIConstants.fontSizeXLarge,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: UIConstants.spacing20),
            _DownloadOption(
              title: 'Single Page Layout',
              subtitle: 'Download this preview (one paper per page)',
              icon: Icons.description_rounded,
              color: AppColors.primary,
              onTap: () {
                Navigator.pop(context);
                Navigator.pop(context);
                onDownload();
              },
            ),
            SizedBox(height: UIConstants.spacing12),
            _DownloadOption(
              title: 'Dual Layout',
              subtitle: 'Two identical papers per page (saves paper)',
              icon: Icons.content_copy_rounded,
              color: AppColors.accent,
              onTap: () {
                Navigator.pop(context);
                Navigator.pop(context);
                onGenerateDual();
              },
            ),
            SizedBox(height: UIConstants.spacing16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
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
            onPressed: () => _showDownloadOptions(context),
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Download Options',
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
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(UIConstants.paddingMedium),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            paperTitle,
            style: TextStyle(
              fontSize: UIConstants.fontSizeLarge,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: UIConstants.spacing4),
          Text(
            'PDF Preview - This is how your paper will look when printed',
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
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back, color: AppColors.textSecondary),
                label: Text(
                  'Back',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    vertical: UIConstants.spacing12,
                  ),
                  side: BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                  ),
                ),
              ),
            ),
            SizedBox(width: UIConstants.spacing12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showDownloadOptions(context),
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
      ),
    );
  }
}

class _DownloadOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DownloadOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.all(UIConstants.paddingMedium),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: UIConstants.iconMedium),
            SizedBox(width: UIConstants.spacing16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: UIConstants.fontSizeLarge,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: UIConstants.fontSizeSmall,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}