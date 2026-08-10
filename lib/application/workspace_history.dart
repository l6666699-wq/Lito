import '../domain/models/app_data.dart';

/// An immutable before/after pair for one user-visible workspace operation.
///
/// The history deliberately stores only in-memory AppData snapshots. It is not
/// persisted and therefore cannot make undo cross a process restart.
class WorkspaceHistoryEntry {
  const WorkspaceHistoryEntry({required this.before, required this.after});

  final AppData before;
  final AppData after;
}

/// Bounded undo/redo stacks for workspace business mutations.
class WorkspaceHistory {
  WorkspaceHistory({this.maxEntries = 50});

  final int maxEntries;
  final List<WorkspaceHistoryEntry> _undo = <WorkspaceHistoryEntry>[];
  final List<WorkspaceHistoryEntry> _redo = <WorkspaceHistoryEntry>[];
  WorkspaceHistoryEntry? _lastRecordedEntry;
  List<WorkspaceHistoryEntry>? _redoBeforeLastRecord;

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  int get undoCount => _undo.length;
  int get redoCount => _redo.length;

  void record(AppData before, AppData after) {
    final entry = WorkspaceHistoryEntry(before: before, after: after);
    _redoBeforeLastRecord = List<WorkspaceHistoryEntry>.of(_redo);
    _lastRecordedEntry = entry;
    _undo.add(entry);
    _redo.clear();
    _trim(_undo);
  }

  WorkspaceHistoryEntry? takeUndo() {
    if (_undo.isEmpty) return null;
    _clearDiscardState();
    final entry = _undo.removeLast();
    _redo.add(entry);
    _trim(_redo);
    return entry;
  }

  WorkspaceHistoryEntry? takeRedo() {
    if (_redo.isEmpty) return null;
    _clearDiscardState();
    final entry = _redo.removeLast();
    _undo.add(entry);
    _trim(_undo);
    return entry;
  }

  /// Removes a just-recorded mutation when a synchronous flush/transaction
  /// fails and the caller restores its pre-mutation snapshot.
  void discardLatestAfterRevision(int revision) {
    if (_undo.isEmpty) return;
    final latest = _undo.last;
    if (latest.after.revision == revision) {
      _undo.removeLast();
      if (identical(latest, _lastRecordedEntry)) {
        _redo
          ..clear()
          ..addAll(_redoBeforeLastRecord ?? const <WorkspaceHistoryEntry>[]);
        _trim(_redo);
      }
    }
    _clearDiscardState();
  }

  void clear() {
    _undo.clear();
    _redo.clear();
    _clearDiscardState();
  }

  void _trim(List<WorkspaceHistoryEntry> stack) {
    while (stack.length > maxEntries) {
      stack.removeAt(0);
    }
  }

  void _clearDiscardState() {
    _lastRecordedEntry = null;
    _redoBeforeLastRecord = null;
  }
}
