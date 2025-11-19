import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../../core/presentation/utils/ui_helpers.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../../pdf_generation/presentation/pages/pdf_preview_page.dart';
import '../../../paper_workflow/domain/entities/question_paper_entity.dart';
import '../../../paper_workflow/presentation/bloc/question_paper_bloc.dart';
import '../../../pdf_generation/domain/services/pdf_generation_service.dart';

/// Direct PDF preview page for office staff
/// This page generates the PDF and navigates directly to the preview
/// without showing the paper details page first
class OfficeStaffPdfPreviewPage extends StatefulWidget {
  final String paperId;

  const OfficeStaffPdfPreviewPage({
    super.key,
    required this.paperId,
  });

  @override
  State<OfficeStaffPdfPreviewPage> createState() => _OfficeStaffPdfPreviewPageState();
}

class _OfficeStaffPdfPreviewPageState extends State<OfficeStaffPdfPreviewPage> {
  bool _isGeneratingPdf = false;
  bool _cancelPdfGeneration = false;
  Uint8List? _pdfBytes;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadPaperAndGeneratePdf();
  }

  Future<void> _loadPaperAndGeneratePdf() async {
    try {
      // Load the paper first
      context.read<QuestionPaperBloc>().add(LoadPaperById(widget.paperId));

      // Wait for paper to be loaded
      final state = await _waitForPaperLoaded();
      if (state == null) {
        if (mounted) {
          setState(() => _errorMessage = 'Failed to load paper');
        }
        return;
      }

      // Generate PDF
      if (mounted) {
        setState(() => _isGeneratingPdf = true);
      }

      final pdfService = SimplePdfService();
      final userStateService = sl<UserStateService>();
      final schoolName = userStateService.schoolName;

      final pdfBytes = await pdfService.generateStudentPdf(
        paper: state,
        schoolName: schoolName,
        fontSizeMultiplier: 1.3,
        spacingMultiplier: 1.0,
      );

      // Check if cancelled
      if (_cancelPdfGeneration) {
        return;
      }

      if (mounted) {
        setState(() {
          _pdfBytes = pdfBytes;
          _isGeneratingPdf = false;
        });

        // Automatically show preview
        _showPdfPreview(state, pdfBytes);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error generating PDF: $e';
          _isGeneratingPdf = false;
        });
      }
    }
  }

  Future<QuestionPaperEntity?> _waitForPaperLoaded() async {
    final completer = Completer<QuestionPaperEntity?>();
    late StreamSubscription subscription;

    subscription = context.read<QuestionPaperBloc>().stream.listen((state) {
      if (state is QuestionPaperLoaded && state.currentPaper != null) {
        subscription.cancel();
        completer.complete(state.currentPaper);
      } else if (state is QuestionPaperError) {
        subscription.cancel();
        completer.complete(null);
      }
    });

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        subscription.cancel();
        return null;
      },
    );
  }

  void _showPdfPreview(QuestionPaperEntity paper, Uint8List pdfBytes) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PdfPreviewPage(
          pdfBytes: pdfBytes,
          paperTitle: paper.title,
          layoutType: 'single',
          onRegeneratePdf: (fontMultiplier, spacingMultiplier) async {
            final pdfService = SimplePdfService();
            final userStateService = sl<UserStateService>();
            final schoolName = userStateService.schoolName;
            return await pdfService.generateStudentPdf(
              paper: paper,
              schoolName: schoolName,
              fontSizeMultiplier: fontMultiplier,
              spacingMultiplier: spacingMultiplier,
            );
          },
        ),
      ),
    ).then((_) {
      // When returning from PDF preview, go back to office dashboard
      if (mounted) {
        context.pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(UIConstants.paddingLarge),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.error,
                ),
                const SizedBox(height: UIConstants.spacing16),
                Text(
                  'Failed to Generate PDF',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: UIConstants.spacing8),
                Text(
                  _errorMessage,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: UIConstants.spacing24),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Generating PDF...'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() => _cancelPdfGeneration = true);
            context.pop();
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(UIConstants.paddingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: UIConstants.spacing16),
              Text(
                'Generating PDF...',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: UIConstants.spacing8),
              Text(
                'This may take a few seconds',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: UIConstants.fontSizeSmall,
                ),
              ),
              const SizedBox(height: UIConstants.spacing24),
              TextButton(
                onPressed: () {
                  setState(() => _cancelPdfGeneration = true);
                  context.pop();
                },
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
