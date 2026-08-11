import 'package:flutter/foundation.dart';

import 'window_controller.dart';

typedef QuickAddSubmitHandler = Future<void> Function(String title);
typedef QuickAddTargetSubmitHandler =
    Future<void> Function(String title, String? projectId);
typedef QuickAddLastProjectWriter = Future<bool> Function(String? projectId);

/// Restores an embedding-owned controller after an app-level binding is
/// removed.  The binding is idempotent and safe to dispose more than once.
class QuickAddControllerBinding {
  QuickAddControllerBinding(this._onDispose);

  final VoidCallback _onDispose;
  bool _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _onDispose();
  }
}

/// A stable, presentation-friendly Quick Add destination.
///
/// The inbox is represented by a `null` [projectId].  Project targets contain
/// only persisted identity/display keys; the controller never retains a
/// [Project] instance, so a workspace refresh can replace the target list
/// without leaving stale mutable state behind.
class QuickAddTarget {
  const QuickAddTarget({
    required this.name,
    this.projectId,
    this.iconKey = 'folder',
    this.colorKey = 'gray',
    this.groupId,
    this.groupName,
  });

  const QuickAddTarget.inbox()
    : name = '收集箱',
      projectId = null,
      iconKey = 'inbox',
      colorKey = 'gray',
      groupId = null,
      groupName = null;

  const QuickAddTarget.project({
    required String id,
    required this.name,
    this.iconKey = 'folder',
    this.colorKey = 'gray',
    this.groupId,
    this.groupName,
  }) : projectId = id;

  final String name;
  final String? projectId;
  final String iconKey;
  final String colorKey;
  final String? groupId;
  final String? groupName;

  bool get isInbox => projectId == null;
  bool get isProject => projectId != null;

  @override
  bool operator ==(Object other) =>
      other is QuickAddTarget &&
      other.name == name &&
      other.projectId == projectId &&
      other.iconKey == iconKey &&
      other.colorKey == colorKey &&
      other.groupId == groupId &&
      other.groupName == groupName;

  @override
  int get hashCode =>
      Object.hash(name, projectId, iconKey, colorKey, groupId, groupName);
}

/// Holds the transient QuickAdd draft and its target selection.  The
/// controller intentionally does not own a second workspace or window;
/// submission is delegated to the caller's in-memory workspace hook and then
/// the existing window is restored.
class QuickAddController extends ChangeNotifier {
  QuickAddController({
    required this.windowController,
    this.onSubmit,
    QuickAddTargetSubmitHandler? onSubmitWithTarget,
    Iterable<QuickAddTarget> availableTargets = const <QuickAddTarget>[
      QuickAddTarget.inbox(),
    ],
    String? lastProjectId,
    QuickAddLastProjectWriter? onLastProjectChanged,
  }) : _availableTargets = _normalizeTargets(availableTargets),
       // ignore: prefer_initializing_formals
       _onSubmitWithTarget = onSubmitWithTarget,
       _lastProjectId = lastProjectId, // ignore: prefer_initializing_formals
       // ignore: prefer_initializing_formals
       _onLastProjectChanged = onLastProjectChanged;

  final WindowController windowController;
  final QuickAddSubmitHandler? onSubmit;
  QuickAddTargetSubmitHandler? _onSubmitWithTarget;
  QuickAddLastProjectWriter? _onLastProjectChanged;

  String _draft = '';
  String? _error;
  bool _submitting = false;
  int _submittedCount = 0;
  List<QuickAddTarget> _availableTargets;
  String? _lastProjectId;
  String? _selectedProjectId;
  bool _hasExplicitSelection = false;
  QuickAddControllerBinding? _activeBinding;
  bool _disposed = false;

  String get draft => _draft;
  String? get error => _error;
  bool get isSubmitting => _submitting;
  int get submittedCount => _submittedCount;
  String? get lastProjectId => _lastProjectId;
  List<QuickAddTarget> get availableTargets => _availableTargets;
  List<QuickAddTarget> get targets => _availableTargets;
  QuickAddTarget get selectedTarget => _resolveSelectedTarget();
  String? get selectedProjectId => selectedTarget.projectId;

  /// Rebinds the persistence side of the selection when the app-level
  /// settings controller becomes available.  Existing widget tests can keep
  /// constructing this controller with only the original arguments.
  void bindLastProject({
    required String? lastProjectId,
    QuickAddLastProjectWriter? onChanged,
  }) {
    if (_disposed) return;
    _lastProjectId = lastProjectId;
    _onLastProjectChanged = onChanged;
    if (!_hasExplicitSelection) notifyListeners();
  }

  /// Lets the app bind its authoritative workspace write even when a test or
  /// embedding supplied this controller through the legacy constructor.
  void bindTargetSubmit(QuickAddTargetSubmitHandler handler) {
    if (_disposed) return;
    _onSubmitWithTarget = handler;
  }

  /// Binds app-owned workspace/settings callbacks while preserving the
  /// embedding's original callbacks, target list and selection for reuse after
  /// the app is disposed.
  QuickAddControllerBinding bindApp({
    required QuickAddTargetSubmitHandler onSubmitWithTarget,
    required String? lastProjectId,
    QuickAddLastProjectWriter? onLastProjectChanged,
  }) {
    if (_disposed) return QuickAddControllerBinding(() {});
    _activeBinding?.dispose();
    final previousSubmit = _onSubmitWithTarget;
    final previousPersist = _onLastProjectChanged;
    final previousLastProjectId = _lastProjectId;
    final previousTargets = _availableTargets;
    final previousSelection = _selectedProjectId;
    final previousExplicitSelection = _hasExplicitSelection;

    _onSubmitWithTarget = onSubmitWithTarget;
    _onLastProjectChanged = onLastProjectChanged;
    _lastProjectId = lastProjectId;
    _hasExplicitSelection = false;
    _selectedProjectId = null;
    notifyListeners();

    late final QuickAddControllerBinding binding;
    binding = QuickAddControllerBinding(() {
      if (!identical(_activeBinding, binding)) return;
      _onSubmitWithTarget = previousSubmit;
      _onLastProjectChanged = previousPersist;
      _lastProjectId = previousLastProjectId;
      _availableTargets = previousTargets;
      _selectedProjectId = previousSelection;
      _hasExplicitSelection = previousExplicitSelection;
      _activeBinding = null;
      notifyListeners();
    });
    _activeBinding = binding;
    return binding;
  }

  void setLastProjectId(String? value) {
    if (_disposed) return;
    if (_lastProjectId == value) return;
    _lastProjectId = value;
    if (!_hasExplicitSelection) notifyListeners();
  }

  void updateLastProjectId(String? value) => setLastProjectId(value);

  /// Replaces the available active targets from a read-only workspace
  /// snapshot.  The inbox is always inserted first and duplicate project IDs
  /// are removed deterministically.
  void setAvailableTargets(Iterable<QuickAddTarget> values) {
    if (_disposed) return;
    final next = _normalizeTargets(values);
    if (_listEquals(_availableTargets, next)) return;
    _availableTargets = next;
    if (_hasExplicitSelection &&
        _selectedProjectId != null &&
        _targetFor(_selectedProjectId) == null) {
      _selectedProjectId = null;
    }
    notifyListeners();
  }

  void updateAvailableTargets(Iterable<QuickAddTarget> values) =>
      setAvailableTargets(values);

  /// Selects a project by stable ID.  Passing `null` selects the inbox.
  /// Unknown IDs are treated as inbox and are never sent to the workspace.
  void setTarget(String? projectId) {
    if (_disposed) return;
    final normalized = projectId == null
        ? null
        : _targetFor(projectId)?.projectId;
    if (_hasExplicitSelection && _selectedProjectId == normalized) return;
    _selectedProjectId = normalized;
    _hasExplicitSelection = true;
    notifyListeners();
  }

  void selectTarget(String? projectId) => setTarget(projectId);

  void setSelectedTarget(String? projectId) => setTarget(projectId);

  void selectTargetEntry(QuickAddTarget target) => setTarget(target.projectId);

  void setDraft(String value) {
    if (_disposed) return;
    if (_draft == value) return;
    _draft = value;
    if (_error != null && value.trim().isNotEmpty) _error = null;
    notifyListeners();
  }

  Future<bool> submit([String? value]) async {
    if (_disposed) return false;
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
      final target = _resolveSelectedTarget();
      final projectId = target.projectId;
      final submitWithTarget = _onSubmitWithTarget;
      if (submitWithTarget != null) {
        await submitWithTarget(title, projectId);
      } else {
        await onSubmit?.call(title);
      }

      // The Todo write is authoritative.  Persisting this preference happens
      // only after it succeeds, so a failed retry keeps both the draft and the
      // previous lastProjectId intact.
      final persist = _onLastProjectChanged;
      if (persist != null) {
        var persisted = false;
        try {
          persisted = await persist(projectId);
        } catch (error) {
          _error = '上次项目偏好未能保存：$error';
        }
        if (persisted) {
          _lastProjectId = projectId;
        } else {
          _error ??= '上次项目偏好未能保存。';
        }
      } else {
        _lastProjectId = projectId;
      }
      _hasExplicitSelection = false;
      _selectedProjectId = null;
      _submittedCount += 1;
      _draft = '';
      try {
        await windowController.completeQuickAdd();
      } catch (error) {
        // The Todo and preference are already authoritative.  A native window
        // restore failure must not turn a successful write into a retryable
        // submission, otherwise the same Todo could be added twice.
        _error = '已添加，但窗口恢复失败：$error';
      }
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
    if (_disposed) return;
    _error = null;
    _draft = '';
    _hasExplicitSelection = false;
    _selectedProjectId = null;
    notifyListeners();
    try {
      await windowController.cancelQuickAdd();
    } catch (error) {
      // Escape/cancel is frequently dispatched through an unawaited keyboard
      // callback. Keep native restore failures inside the controller so they
      // cannot become an uncaught zone error or leave a dead window process.
      _error = 'Quick Add cancel failed: $error';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _activeBinding?.dispose();
    _activeBinding = null;
    super.dispose();
  }

  /// A submission may still be awaiting persistence while the Quick Add view
  /// is removed during a window-mode transition. Ignore late notifications
  /// instead of calling ChangeNotifier after disposal and taking down the
  /// Flutter isolate.
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  QuickAddTarget _resolveSelectedTarget() {
    final requested = _hasExplicitSelection
        ? _selectedProjectId
        : _lastProjectId;
    if (requested == null) return _inboxTarget;
    return _targetFor(requested) ?? _inboxTarget;
  }

  QuickAddTarget? _targetFor(String? projectId) {
    if (projectId == null) return _inboxTarget;
    for (final target in _availableTargets) {
      if (target.projectId == projectId) return target;
    }
    return null;
  }

  QuickAddTarget get _inboxTarget => _availableTargets.firstWhere(
    (target) => target.isInbox,
    orElse: () => const QuickAddTarget.inbox(),
  );

  static List<QuickAddTarget> _normalizeTargets(
    Iterable<QuickAddTarget> values,
  ) {
    final projects = <String, QuickAddTarget>{};
    QuickAddTarget? inbox;
    for (final target in values) {
      if (target.isInbox) {
        inbox ??= target;
      } else if (target.projectId != null) {
        projects[target.projectId!] = target;
      }
    }
    return List<QuickAddTarget>.unmodifiable(<QuickAddTarget>[
      inbox ?? const QuickAddTarget.inbox(),
      ...projects.values,
    ]);
  }

  static bool _listEquals(
    List<QuickAddTarget> left,
    List<QuickAddTarget> right,
  ) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}
