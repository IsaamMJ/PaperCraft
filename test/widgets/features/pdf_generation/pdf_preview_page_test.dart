import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papercraft/features/pdf_generation/presentation/pages/pdf_preview_page.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

void main() {
  late Uint8List mockPdfBytes;
  late Uint8List regeneratedPdfBytes;
  late Uint8List emptyPdfBytes;

  setUp(() {
    mockPdfBytes = Uint8List.fromList([1, 2, 3, 4]);
    regeneratedPdfBytes = Uint8List.fromList([5, 6, 7, 8]);
    emptyPdfBytes = Uint8List(0);
  });

  Widget createWidget({
    Uint8List? pdfBytes,
    String paperTitle = 'Test Paper',
    String layoutType = 'single',
    Future<Uint8List> Function(double, double)? onRegeneratePdf,
  }) {
    return MaterialApp(
      home: PdfPreviewPage(
        pdfBytes: pdfBytes ?? mockPdfBytes,
        paperTitle: paperTitle,
        layoutType: layoutType,
        onRegeneratePdf: onRegeneratePdf,
      ),
    );
  }

  /// Helper to find density button
  Finder getDensityButton(String label) => find.descendant(
    of: find.byType(GestureDetector),
    matching: find.text(label),
  ).first;

  /// Helper to wait for SfPdfViewer timer
  Future<void> waitForPdfTimer(WidgetTester tester) =>
      tester.pump(Duration(milliseconds: 600));

  // ============================================================================
  // CORE FUNCTIONALITY TESTS (Must-Have)
  // ============================================================================

  group('PdfPreviewPage - Core Initialization', () {
    testWidgets('renders all required UI elements', (tester) async {
      await tester.pumpWidget(createWidget());

      expect(find.text('PDF Preview'), findsOneWidget);
      expect(find.text('Test Paper'), findsOneWidget);
      expect(find.text('Single Page Layout'), findsOneWidget);
      expect(find.byType(SfPdfViewer), findsOneWidget);
      expect(find.byIcon(Icons.print_rounded), findsNWidgets(2));
    });

    testWidgets('supports different layout types', (tester) async {
      await tester.pumpWidget(createWidget(layoutType: 'side-by-side'));
      expect(find.text('Side-by-Side Layout'), findsOneWidget);

      await tester.pumpWidget(createWidget(layoutType: 'single'));
      expect(find.text('Single Page Layout'), findsOneWidget);
    });

    testWidgets('handles very long paper titles', (tester) async {
      final longTitle = 'A' * 200;
      await tester.pumpWidget(createWidget(paperTitle: longTitle));
      expect(find.textContaining('A'), findsWidgets);
    });

    testWidgets('handles empty PDF bytes gracefully', (tester) async {
      await tester.pumpWidget(createWidget(pdfBytes: emptyPdfBytes));
      expect(find.byType(SfPdfViewer), findsOneWidget);
    });
  });

  group('Density Controls - Core Functionality', () {
    testWidgets('shows density controls only when callback provided', (tester) async {
      // Without callback
      await tester.pumpWidget(createWidget(onRegeneratePdf: null));
      expect(find.text('Layout Density'), findsNothing);

      // With callback
      await tester.pumpWidget(createWidget(onRegeneratePdf: (f, s) async => mockPdfBytes));
      expect(find.text('Layout Density'), findsOneWidget);
      expect(find.text('Compact'), findsOneWidget);
      expect(find.text('Standard'), findsOneWidget);
      expect(find.text('Spacious'), findsOneWidget);
    });

    testWidgets('density changes trigger regeneration with correct multipliers', (tester) async {
      final results = <(double, double)>[];

      await tester.pumpWidget(createWidget(
        onRegeneratePdf: (f, s) async {
          results.add((f, s));
          return regeneratedPdfBytes;
        },
      ));

      // Test Compact
      await tester.tap(getDensityButton('Compact'));
      await waitForPdfTimer(tester);
      expect(results.last, (1.0, 1.0));

      // Test Standard
      await tester.tap(getDensityButton('Standard'));
      await waitForPdfTimer(tester);
      expect(results.last, (1.0, 1.5));

      // Test Spacious
      await tester.tap(getDensityButton('Spacious'));
      await waitForPdfTimer(tester);
      expect(results.last, (1.1, 2.0));
    });

    testWidgets('prevents regeneration when already regenerating', (tester) async {
      int callCount = 0;
      final completer = Completer<Uint8List>();

      await tester.pumpWidget(createWidget(
        onRegeneratePdf: (f, s) async {
          callCount++;
          return completer.future;
        },
      ));

      // Trigger first regeneration
      await tester.tap(getDensityButton('Compact'));
      await tester.pump();
      expect(callCount, 1);

      // Try to trigger second while first is in progress
      await tester.tap(getDensityButton('Spacious'));
      await tester.pump();
      expect(callCount, 1); // Still 1, second was blocked

      // Complete first regeneration
      completer.complete(regeneratedPdfBytes);
      await tester.pump();
    });

    testWidgets('skips regeneration for same density selection', (tester) async {
      int callCount = 0;

      await tester.pumpWidget(createWidget(
        onRegeneratePdf: (f, s) async {
          callCount++;
          return regeneratedPdfBytes;
        },
      ));

      // Standard is already selected by default
      await tester.tap(getDensityButton('Standard'));
      await waitForPdfTimer(tester);
      expect(callCount, 0);
    });
  });

  group('PDF Viewer - Updates & State', () {
    testWidgets('updates PDF viewer when PDF changes', (tester) async {
      await tester.pumpWidget(createWidget(onRegeneratePdf: (f, s) async => regeneratedPdfBytes));

      final initialKey = tester.widget<SfPdfViewer>(find.byType(SfPdfViewer)).key;

      await tester.tap(getDensityButton('Compact'));
      await waitForPdfTimer(tester);

      final newKey = tester.widget<SfPdfViewer>(find.byType(SfPdfViewer)).key;
      expect(initialKey, isNot(equals(newKey)));
    });

    testWidgets('uses original PDF bytes on init', (tester) async {
      final customBytes = Uint8List.fromList([9, 10, 11, 12]);
      await tester.pumpWidget(createWidget(pdfBytes: customBytes));

      final viewer = tester.widget<SfPdfViewer>(find.byType(SfPdfViewer));
      expect(viewer.key, isNotNull);
    });

    testWidgets('viewer has correct accessibility settings', (tester) async {
      await tester.pumpWidget(createWidget());

      final viewer = tester.widget<SfPdfViewer>(find.byType(SfPdfViewer));
      expect(viewer.enableDoubleTapZooming, true);
      expect(viewer.enableTextSelection, false);
      expect(viewer.canShowScrollHead, true);
      expect(viewer.canShowScrollStatus, true);
    });
  });

  // ============================================================================
  // ERROR HANDLING & RECOVERY (Critical)
  // ============================================================================

  group('Error Handling & Recovery', () {
    testWidgets('handles regeneration errors gracefully', (tester) async {
      await tester.pumpWidget(createWidget(
        onRegeneratePdf: (f, s) async => throw Exception('Generation failed'),
      ));

      await tester.tap(getDensityButton('Compact'));
      await waitForPdfTimer(tester);

      expect(find.text('Failed to regenerate PDF. Please try again.'), findsOneWidget);
      // UI should be responsive after error
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('allows retry after error', (tester) async {
      bool shouldFail = true;

      await tester.pumpWidget(createWidget(
        onRegeneratePdf: (f, s) async {
          if (shouldFail) throw Exception('Failed');
          return regeneratedPdfBytes;
        },
      ));

      // First attempt fails
      await tester.tap(getDensityButton('Compact'));
      await waitForPdfTimer(tester);
      expect(find.text('Failed to regenerate PDF. Please try again.'), findsOneWidget);

      // Dismiss snackbar
      await tester.pumpAndSettle();

      // Second attempt succeeds
      shouldFail = false;
      await tester.tap(getDensityButton('Spacious'));
      await waitForPdfTimer(tester);

      expect(find.text('Failed to regenerate PDF. Please try again.'), findsNothing);
    });

    testWidgets('error state clears on successful regeneration', (tester) async {
      bool shouldFail = true;

      await tester.pumpWidget(createWidget(
        onRegeneratePdf: (f, s) async {
          if (shouldFail) throw Exception('Failed');
          return regeneratedPdfBytes;
        },
      ));

      await tester.tap(getDensityButton('Compact'));
      await waitForPdfTimer(tester);
      await tester.pumpAndSettle();

      shouldFail = false;
      await tester.tap(getDensityButton('Spacious'));
      await waitForPdfTimer(tester);

      // Error message should be gone
      expect(find.text('Failed to regenerate PDF. Please try again.'), findsNothing);
    });

    testWidgets('handles unmounting during regeneration', (tester) async {
      await tester.pumpWidget(createWidget(
        onRegeneratePdf: (f, s) async {
          await Future.delayed(Duration(milliseconds: 100));
          return regeneratedPdfBytes;
        },
      ));

      await tester.tap(getDensityButton('Compact'));
      await tester.pump(Duration(milliseconds: 50));

      // Unmount widget
      await tester.pumpWidget(Container());
      // Should not crash
      await tester.pump(Duration(milliseconds: 100));
    });
  });

  // ============================================================================
  // ADVANCED SETTINGS (Slider Management)
  // ============================================================================

  group('Advanced Settings - Expansion', () {
    testWidgets('expands and collapses advanced settings', (tester) async {
      await tester.pumpWidget(createWidget(onRegeneratePdf: (f, s) async => mockPdfBytes));

      expect(find.text('Font Size'), findsNothing);

      await tester.tap(find.text('Advanced Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Font Size'), findsOneWidget);
      expect(find.text('Spacing'), findsOneWidget);

      await tester.tap(find.text('Advanced Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Font Size'), findsNothing);
    });

    testWidgets('hides advanced settings when no callback', (tester) async {
      await tester.pumpWidget(createWidget(onRegeneratePdf: null));
      expect(find.text('Advanced Settings'), findsNothing);
    });
  });

  group('Advanced Settings - Slider Bounds', () {
    testWidgets('font slider respects min/max bounds', (tester) async {
      await tester.pumpWidget(createWidget(onRegeneratePdf: (f, s) async => mockPdfBytes));
      await tester.tap(find.text('Advanced Settings'));
      await tester.pumpAndSettle();

      final slider = tester.widget<Slider>(find.byType(Slider).first);
      expect(slider.min, 0.8);
      expect(slider.max, 1.3);
      expect(slider.divisions, 10);
    });

    testWidgets('spacing slider respects min/max bounds', (tester) async {
      await tester.pumpWidget(createWidget(onRegeneratePdf: (f, s) async => mockPdfBytes));
      await tester.tap(find.text('Advanced Settings'));
      await tester.pumpAndSettle();

      final slider = tester.widget<Slider>(find.byType(Slider).last);
      expect(slider.min, 0.5);
      expect(slider.max, 3.0);
      expect(slider.divisions, 10);
    });
  });

  group('Advanced Settings - Debounce', () {
    testWidgets('debounces font slider changes', (tester) async {
      final calls = <double>[];

      await tester.pumpWidget(createWidget(
        onRegeneratePdf: (f, s) async {
          calls.add(f);
          return regeneratedPdfBytes;
        },
      ));

      await tester.tap(find.text('Advanced Settings'));
      await tester.pumpAndSettle();

      final slider = find.byType(Slider).first;

      // Rapid changes
      await tester.drag(slider, Offset(10, 0));
      await tester.pump(Duration(milliseconds: 100));
      await tester.drag(slider, Offset(10, 0));
      await tester.pump(Duration(milliseconds: 100));

      expect(calls.length, 0); // Not called yet

      await tester.pump(Duration(milliseconds: 500));
      expect(calls.length, 1); // Only last change triggered
    });

    testWidgets('cancels previous debounce timer on new change', (tester) async {
      final calls = <double>[];

      await tester.pumpWidget(createWidget(
        onRegeneratePdf: (f, s) async {
          calls.add(f);
          return regeneratedPdfBytes;
        },
      ));

      await tester.tap(find.text('Advanced Settings'));
      await tester.pumpAndSettle();

      final slider = find.byType(Slider).first;

      await tester.drag(slider, Offset(10, 0));
      await tester.pump(Duration(milliseconds: 250));
      await tester.drag(slider, Offset(10, 0));
      await tester.pump(Duration(milliseconds: 250));
      await tester.drag(slider, Offset(10, 0));
      await tester.pump(Duration(milliseconds: 500));

      expect(calls.length, 1); // Only final state regenerated
    });
  });

  group('Advanced Settings - Value Syncing', () {
    testWidgets('syncs slider values when density preset changes', (tester) async {
      await tester.pumpWidget(createWidget(onRegeneratePdf: (f, s) async => regeneratedPdfBytes));

      await tester.tap(find.text('Advanced Settings'));
      await tester.pumpAndSettle();

      expect(find.text('100%'), findsOneWidget);
      expect(find.text('1.5×'), findsOneWidget);

      // Change to Spacious
      await tester.tap(getDensityButton('Spacious'));
      await waitForPdfTimer(tester);

      expect(find.text('110%'), findsOneWidget);
      expect(find.text('2.0×'), findsOneWidget);
    });

    testWidgets('reset button restores to current preset values', (tester) async {
      double? lastFont;

      await tester.pumpWidget(createWidget(
        onRegeneratePdf: (f, s) async {
          lastFont = f;
          return regeneratedPdfBytes;
        },
      ));

      await tester.tap(find.text('Advanced Settings'));
      await tester.pumpAndSettle();

      // Modify slider
      await tester.drag(find.byType(Slider).first, Offset(30, 0));
      await tester.pump(Duration(milliseconds: 500));

      // Reset
      await tester.tap(find.byIcon(Icons.restart_alt_rounded));
      await tester.pump(Duration(milliseconds: 500));

      // Should be back to Standard preset (1.0)
      expect(lastFont, 1.0);
    });
  });

  group('Advanced Settings - Disable During Regen', () {
    testWidgets('disables sliders while regenerating', (tester) async {
      await tester.pumpWidget(createWidget(
        onRegeneratePdf: (f, s) async {
          await Future.delayed(Duration(milliseconds: 300));
          return regeneratedPdfBytes;
        },
      ));

      await tester.tap(find.text('Advanced Settings'));
      await tester.pumpAndSettle();

      await tester.tap(getDensityButton('Compact'));
      await tester.pump(Duration(milliseconds: 100));

      final sliders = tester.widgetList<Slider>(find.byType(Slider));
      expect(sliders.every((s) => s.onChanged == null), true);
    });

    testWidgets('re-enables sliders after regeneration', (tester) async {
      await tester.pumpWidget(createWidget(
        onRegeneratePdf: (f, s) async {
          await Future.delayed(Duration(milliseconds: 100));
          return regeneratedPdfBytes;
        },
      ));

      await tester.tap(find.text('Advanced Settings'));
      await tester.pumpAndSettle();

      await tester.tap(getDensityButton('Compact'));
      await tester.pump(Duration(milliseconds: 150));

      final sliders = tester.widgetList<Slider>(find.byType(Slider));
      expect(sliders.every((s) => s.onChanged != null), true);
    });
  });

  // ============================================================================
  // NAVIGATION & UI STATE
  // ============================================================================

  group('Navigation', () {
    testWidgets('back button in bottom bar navigates', (tester) async {
      await tester.pumpWidget(createWidget());
      expect(find.byType(PdfPreviewPage), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Back to Paper Details'));
      await tester.pumpAndSettle();

      expect(find.byType(PdfPreviewPage), findsNothing);
    });

    testWidgets('appbar back button navigates', (tester) async {
      await tester.pumpWidget(createWidget());

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(PdfPreviewPage), findsNothing);
    });

    testWidgets('allows navigation during regeneration', (tester) async {
      await tester.pumpWidget(createWidget(
        onRegeneratePdf: (f, s) async {
          await Future.delayed(Duration(milliseconds: 500));
          return regeneratedPdfBytes;
        },
      ));

      await tester.tap(getDensityButton('Compact'));
      await tester.pump(Duration(milliseconds: 100));

      // Navigate while regenerating
      await tester.tap(find.widgetWithText(OutlinedButton, 'Back to Paper Details'));
      await tester.pumpAndSettle();

      expect(find.byType(PdfPreviewPage), findsNothing);
    });
  });

  group('Print Functionality', () {
    testWidgets('displays print buttons', (tester) async {
      await tester.pumpWidget(createWidget());

      expect(find.byIcon(Icons.print_rounded), findsNWidgets(2));
      expect(find.widgetWithText(ElevatedButton, 'Print PDF'), findsOneWidget);
    });
  });

  // ============================================================================
  // EDGE CASES & BOUNDARY CONDITIONS
  // ============================================================================

  group('Rapid Interactions', () {
    testWidgets('handles rapid density changes', (tester) async {
      int callCount = 0;

      await tester.pumpWidget(createWidget(
        onRegeneratePdf: (f, s) async {
          callCount++;
          return regeneratedPdfBytes;
        },
      ));

      // Rapid clicks
      await tester.tap(getDensityButton('Compact'));
      await tester.tap(getDensityButton('Spacious'));
      await tester.tap(getDensityButton('Compact'));
      await waitForPdfTimer(tester);

      // Only last valid call should succeed
      expect(callCount, 1);
    });

    testWidgets('handles slider drag at min/max boundaries', (tester) async {
      await tester.pumpWidget(createWidget(onRegeneratePdf: (f, s) async => regeneratedPdfBytes));

      await tester.tap(find.text('Advanced Settings'));
      await tester.pumpAndSettle();

      final slider = find.byType(Slider).first;

      // Drag to min (left edge)
      await tester.drag(slider, Offset(-200, 0));
      await tester.pump(Duration(milliseconds: 500));

      // Drag to max (right edge)
      await tester.drag(slider, Offset(200, 0));
      await tester.pump(Duration(milliseconds: 500));

      // Should not crash
      expect(find.byType(PdfPreviewPage), findsOneWidget);
    });
  });

  group('Special Characters & Encoding', () {
    testWidgets('handles special characters in paper title', (tester) async {
      await tester.pumpWidget(createWidget(
        paperTitle: 'Test 📄 Paper™ — Über çöur§e',
      ));

      expect(find.byType(PdfPreviewPage), findsOneWidget);
    });

    testWidgets('handles RTL text in paper title', (tester) async {
      await tester.pumpWidget(createWidget(
        paperTitle: 'اختبار الورقة',
      ));

      expect(find.byType(PdfPreviewPage), findsOneWidget);
    });
  });

  group('State Persistence', () {
    testWidgets('remembers advanced settings expansion state', (tester) async {
      await tester.pumpWidget(createWidget(onRegeneratePdf: (f, s) async => mockPdfBytes));

      await tester.tap(find.text('Advanced Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Font Size'), findsOneWidget);

      await tester.tap(find.text('Advanced Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Font Size'), findsNothing);

      // State should persist in widget
      await tester.tap(find.text('Advanced Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Font Size'), findsOneWidget);
    });
  });
}