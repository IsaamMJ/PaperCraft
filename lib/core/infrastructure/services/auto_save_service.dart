import 'dart:async';

class AutoSaveService {
  Timer? _autoSaveTimer;
  static const Duration autoSaveInterval = Duration(seconds: 30);
  bool _hasUnsavedChanges = false;

  void markAsModified() {
    _hasUnsavedChanges = true;
  }

  void markAsSaved() {
    _hasUnsavedChanges = false;
  }

  void startAutoSave({
    required Future<void> Function() onSave,
    required bool Function() shouldSave,
  }) {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(autoSaveInterval, (_) async {
      if (_hasUnsavedChanges && shouldSave()) {
        try {
          await onSave();
          _hasUnsavedChanges = false;
        } catch (e) {
          // Log error but don't interrupt user
        }
      }
    });
  }

  void stopAutoSave() {
    _autoSaveTimer?.cancel();
  }

  void dispose() {
    stopAutoSave();
  }
}
