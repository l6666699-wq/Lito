import 'package:flutter/foundation.dart';

import 'window_controller.dart';

typedef QuickAddSubmitHandler = Future<void> Function(String title);

/// Holds the transient QuickAdd draft.  The controller intentionally does not
/// own a second workspace or window; submission is delegated to the caller's
/// in-memory workspace hook and then the existing window is restored.
class QuickAddController extends ChangeNotifier {
  QuickAddController({required this.windowController, this.onSubmit});

  final WindowController windowController;
  final QuickAddSubmitHandler? onSubmit;

  String _draft = '';
  String? _error;
  bool _submitting = false;
  int _submittedCount = 0;

  String get draft => _draft;
  String? get error => _error;
  bool get isSubmitting => _submitting;
  int get submittedCount => _submittedCount;

  void setDraft(String value) {
    if (_draft == value) return;
    _draft = value;
    if (_error != null && value.trim().isNotEmpty) _error = null;
    notifyListeners();
  }

  Future<bool> submit([String? value]) async {
    if (_submitting) return false;
    final title = (value ?? _draft).trim();
    if (title.isEmpty) {
      _error = '请输入待办内容';
      notifyListeners();
      return false;
    }
    _submitting = true;
    _error = null;
    notifyListeners();
    try {
      await onSubmit?.call(title);
      _submittedCount += 1;
      _draft = '';
      await windowController.completeQuickAdd();
      return true;
    } catch (error) {
      _error = '添加失败：$error';
      return false;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  Future<void> cancel() async {
    _error = null;
    _draft = '';
    notifyListeners();
    await windowController.cancelQuickAdd();
  }
}
