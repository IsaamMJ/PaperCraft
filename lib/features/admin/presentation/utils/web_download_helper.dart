// Web-specific download helper for CSV files
// This file is only used on Flutter web platform
import 'dart:html' as html;
import 'dart:convert' show base64Encode, utf8;

/// Helper class for downloading files on Flutter web
class WebDownloadHelper {
  /// Downloads CSV content as a file on web platform
  /// Creates a data URI and triggers browser download
  static void downloadCsvFile(String csvContent, String filename) {
    try {
      // Encode content to bytes then to base64
      final bytes = utf8.encode(csvContent);
      final base64Data = base64Encode(bytes);
      final dataUri = 'data:text/csv;base64,$base64Data';

      // Create anchor element for download
      final link = html.AnchorElement(href: dataUri)
        ..setAttribute('download', filename)
        ..style.display = 'none';

      // Append to body, click, and remove to trigger download
      html.document.body?.append(link);
      link.click();
      link.remove();
    } catch (e) {
      rethrow;
    }
  }
}
