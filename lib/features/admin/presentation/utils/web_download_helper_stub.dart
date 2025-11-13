// Stub version of web download helper for non-web platforms
// This file is used on mobile/desktop platforms where dart:html is not available

/// Stub class for downloading files on non-web platforms
class WebDownloadHelper {
  /// Stub implementation - does nothing on non-web platforms
  static void downloadCsvFile(String csvContent, String filename) {
    print('Web download helper not available on this platform');
  }
}
