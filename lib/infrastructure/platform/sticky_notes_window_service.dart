import 'package:flutter/services.dart';

/// Stable native bridge for desktop sticky-note windows.
///
/// The bridge is deliberately kept behind an application-facing interface so
/// the controller and widgets remain testable without a Windows runner. The
/// Windows implementation is backed by the runner's multi-engine manager;
/// other platforms can use [FakeStickyNotesWindowService] until a native
/// implementation is available.
abstract interface class StickyNotesWindowService {
  Future<void> open({required String key, String? projectId});

  Future<void> close(String key);

  Future<void> setAlwaysOnTop(String key, bool value);

  Future<void> startDragging(String key);

  Future<String?> readSnapshot(String key);

  Future<void> syncSnapshot({required String key, required String snapshot});
}

/// Windows runner bridge. Each method maps to a native method call on the
/// current engine's messenger. The native runner creates one Flutter engine
/// and HWND per stable sticky-note key.
class WindowsStickyNotesWindowService implements StickyNotesWindowService {
  WindowsStickyNotesWindowService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'litetodo/sticky_windows';

  final MethodChannel _channel;

  @override
  Future<void> open({required String key, String? projectId}) async {
    await _channel.invokeMethod<void>('open', <String, Object?>{
      'key': key,
      'projectId': projectId,
    });
  }

  @override
  Future<void> close(String key) async {
    await _channel.invokeMethod<void>('close', <String, Object?>{'key': key});
  }

  @override
  Future<void> setAlwaysOnTop(String key, bool value) async {
    await _channel.invokeMethod<void>('alwaysOnTop', <String, Object?>{
      'key': key,
      'value': value,
    });
  }

  @override
  Future<void> startDragging(String key) async {
    await _channel.invokeMethod<void>('drag', <String, Object?>{'key': key});
  }

  @override
  Future<String?> readSnapshot(String key) async {
    return _channel.invokeMethod<String>('snapshot', <String, Object?>{
      'key': key,
    });
  }

  @override
  Future<void> syncSnapshot({
    required String key,
    required String snapshot,
  }) async {
    await _channel.invokeMethod<void>('sync', <String, Object?>{
      'key': key,
      'snapshot': snapshot,
    });
  }
}

/// Deterministic fake for application and widget tests.
class FakeStickyNotesWindowService implements StickyNotesWindowService {
  final List<String> calls = <String>[];
  final Map<String, String> snapshots = <String, String>{};
  final Set<String> openKeys = <String>{};
  final Set<String> alwaysOnTopKeys = <String>{};

  @override
  Future<void> open({required String key, String? projectId}) async {
    openKeys.add(key);
    calls.add('open:$key:${projectId ?? ''}');
  }

  @override
  Future<void> close(String key) async {
    openKeys.remove(key);
    calls.add('close:$key');
  }

  @override
  Future<void> setAlwaysOnTop(String key, bool value) async {
    if (value) {
      alwaysOnTopKeys.add(key);
    } else {
      alwaysOnTopKeys.remove(key);
    }
    calls.add('alwaysOnTop:$key:$value');
  }

  @override
  Future<void> startDragging(String key) async => calls.add('drag:$key');

  @override
  Future<String?> readSnapshot(String key) async {
    calls.add('snapshot:$key');
    return snapshots[key];
  }

  @override
  Future<void> syncSnapshot({
    required String key,
    required String snapshot,
  }) async {
    snapshots[key] = snapshot;
    calls.add('sync:$key');
  }
}

/// A best-effort wrapper used by non-Windows startup paths. It turns missing
/// native registration into an observable capability error rather than
/// failing the shell during a click or background sync.
class SafeStickyNotesWindowService implements StickyNotesWindowService {
  SafeStickyNotesWindowService(this._delegate);

  final StickyNotesWindowService _delegate;

  @override
  Future<void> open({required String key, String? projectId}) =>
      _guard(() => _delegate.open(key: key, projectId: projectId));

  @override
  Future<void> close(String key) => _guard(() => _delegate.close(key));

  @override
  Future<void> setAlwaysOnTop(String key, bool value) =>
      _guard(() => _delegate.setAlwaysOnTop(key, value));

  @override
  Future<void> startDragging(String key) =>
      _guard(() => _delegate.startDragging(key));

  @override
  Future<String?> readSnapshot(String key) async {
    try {
      return await _delegate.readSnapshot(key);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<void> syncSnapshot({required String key, required String snapshot}) =>
      _guard(() => _delegate.syncSnapshot(key: key, snapshot: snapshot));

  Future<void> _guard(Future<void> Function() operation) async {
    try {
      await operation();
    } on MissingPluginException {
      // The caller's controller exposes its capability warning. Tests and
      // non-Windows builds therefore remain usable without a runner channel.
    } on PlatformException {
      // A native window operation is best effort and must not take down the
      // workspace process. The next open/sync can retry the operation.
    }
  }
}

/// Parsed command-line payload passed by the Windows runner to a sticky
/// secondary engine.
class StickyWindowLaunchArguments {
  const StickyWindowLaunchArguments({
    required this.key,
    required this.projectId,
  });

  final String key;
  final String? projectId;

  static StickyWindowLaunchArguments? parse(List<String> arguments) {
    if (!arguments.contains('--sticky-window')) return null;
    String? key;
    String? projectId;
    for (final argument in arguments) {
      if (argument.startsWith('--sticky-key=')) {
        key = argument.substring('--sticky-key='.length);
      } else if (argument.startsWith('--sticky-project-id=')) {
        final value = argument.substring('--sticky-project-id='.length);
        projectId = value.isEmpty ? null : value;
      }
    }
    if (key == null || key.isEmpty) return null;
    return StickyWindowLaunchArguments(key: key, projectId: projectId);
  }
}

/// Secondary-engine channel endpoint. The native runner invokes `update` on
/// this channel whenever the primary workspace revision changes.
class StickyNotesSecondaryChannel {
  StickyNotesSecondaryChannel({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('litetodo/sticky_windows');

  final MethodChannel _channel;

  Future<String?> readSnapshot(String key) async {
    return _channel.invokeMethod<String>('snapshot', <String, Object?>{
      'key': key,
    });
  }

  void listen({required ValueChanged<String> onSnapshot}) {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'update') return null;
      final value = call.arguments;
      if (value is String) onSnapshot(value);
      return null;
    });
  }

  Future<void> close(String key) async {
    await _channel.invokeMethod<void>('close', <String, Object?>{'key': key});
  }

  Future<void> setAlwaysOnTop(String key, bool value) async {
    await _channel.invokeMethod<void>('alwaysOnTop', <String, Object?>{
      'key': key,
      'value': value,
    });
  }

  Future<void> startDragging(String key) async {
    await _channel.invokeMethod<void>('drag', <String, Object?>{'key': key});
  }

  /// Sends a user mutation from a secondary sticky engine to the primary
  /// workspace owner.  The secondary engine never applies the mutation to its
  /// snapshot controller; the native runner forwards this payload to the
  /// primary engine, which performs the mutation and flushes the JSON source.
  Future<void> mutate({
    required String operation,
    String? todoId,
    String? title,
    String? projectId,
    String? targetId,
    String? position,
  }) async {
    await _channel.invokeMethod<void>('mutate', <String, Object?>{
      'operation': operation,
      'todoId': todoId,
      'title': title,
      'projectId': projectId,
      'targetId': targetId,
      'position': position,
    });
  }
}

typedef ValueChanged<T> = void Function(T value);
