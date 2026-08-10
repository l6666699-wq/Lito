import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// The small set of levels used by the local application log.
enum AppLogLevel { debug, info, warning, error }

/// Restores the process-wide Flutter error handlers installed by an
/// [AppLogService].  A binding is intentionally explicit so tests and hosts
/// that install temporary handlers can cleanly return the previous state.
class AppLogHandlerBinding {
  AppLogHandlerBinding._(this._restoreCallback);

  final void Function() _restoreCallback;
  bool _restored = false;

  bool get isRestored => _restored;

  void restore() {
    if (_restored) return;
    _restored = true;
    _restoreCallback();
  }

  void dispose() => restore();
}

/// A bounded, UTF-8, append-only application log.
///
/// The service deliberately has no dependency on a logger package.  Every
/// write is queued on [_writeTail], so rotation and append operations cannot
/// interleave when several error paths report at the same time.  Logging is
/// best effort: a broken or read-only data directory never blocks startup or
/// the operation that caused the log event.
class AppLogService {
  AppLogService({
    Directory? directory,
    Directory? dataDirectory,
    this.maxFileBytes = defaultMaxFileBytes,
    this.maxRotatedFiles = defaultMaxRotatedFiles,
  }) : assert(
         directory == null || dataDirectory == null,
         'Pass either directory or dataDirectory, not both.',
       ),
       assert(maxFileBytes > 0),
       assert(maxRotatedFiles >= 1 && maxRotatedFiles <= 2),
       _dataDirectory = dataDirectory ?? directory ?? Directory.systemTemp;

  static const int defaultMaxFileBytes = 2 * 1024 * 1024;
  static const int defaultMaxRotatedFiles = 2;

  static const String flutterErrorCode = 'flutter.error';
  static const String platformErrorCode = 'platform.error';

  static final RegExp _safeCodePattern = RegExp(r'^[a-z][a-z0-9_.:-]{0,63}$');
  static final RegExp _safeMetadataKeyPattern = RegExp(
    r'^[a-z][a-z0-9_.:-]{0,31}$',
  );
  static final RegExp _safeEnumPattern = RegExp(r'^[a-z][a-z0-9_.:-]{0,31}$');
  static final RegExp _stackFramePattern = RegExp(r'^\s*#(\d+)\s+(.+)$');
  static final RegExp _unsafeStackCharacterPattern = RegExp(
    r'[^A-Za-z0-9_./\\:()<>@+\- ]',
  );

  static const Map<String, Set<String>> _knownEnumValues =
      <String, Set<String>>{
        'action': <String>{
          'append',
          'backup',
          'close',
          'create',
          'delete',
          'flush',
          'initialize',
          'load',
          'migrate',
          'open',
          'read',
          'restore',
          'save',
          'update',
          'write',
        },
        'component': <String>{
          'app',
          'backup',
          'data',
          'flutter',
          'hotkey',
          'platform',
          'repository',
          'settings',
          'tray',
          'window',
          'workspace',
        },
        'event': <String>{
          'error',
          'failure',
          'recovery',
          'startup',
          'shutdown',
          'success',
        },
        'kind': <String>{'data', 'settings', 'window', 'workspace'},
        'mode': <String>{'full', 'compact', 'quick_add'},
        'operation': <String>{
          'append',
          'backup',
          'close',
          'create',
          'delete',
          'flush',
          'initialize',
          'load',
          'migrate',
          'open',
          'read',
          'restore',
          'save',
          'update',
          'write',
        },
        'phase': <String>{'startup', 'runtime', 'shutdown'},
        'platform': <String>{'windows', 'macos', 'linux', 'web'},
        'reason': <String>{
          'corrupt',
          'initialize',
          'invalid',
          'missing',
          'permission',
          'recovery',
          'rotation',
          'shutdown',
          'unsupported',
        },
        'result': <String>{'failed', 'skipped', 'success'},
        'scope': <String>{
          'all',
          'completed',
          'inbox',
          'project',
          'recent',
          'search',
          'today',
        },
        'source': <String>{
          'bootstrap',
          'flutter',
          'hotkey',
          'platform',
          'repository',
          'settings',
          'tray',
          'window',
          'workspace',
        },
        'status': <String>{
          'disabled',
          'failed',
          'initialized',
          'primary',
          'ready',
          'secondary',
          'success',
        },
      };

  final Directory _dataDirectory;
  final int maxFileBytes;
  final int maxRotatedFiles;

  Future<void> _writeTail = Future<void>.value();
  Future<void>? _initialization;
  AppLogHandlerBinding? _handlerBinding;
  Object? _lastError;
  bool _initialized = false;
  bool _disabled = false;
  bool _closing = false;
  bool _closed = false;

  Directory get dataDirectory => _dataDirectory;

  Directory get logsDirectory => Directory(_join(_dataDirectory.path, 'logs'));

  File get logFile => File(_join(logsDirectory.path, 'app.log'));

  File rotatedFile(int index) =>
      File(_join(logsDirectory.path, 'app.log.$index'));

  bool get isInitialized => _initialized;
  bool get isDisabled => _disabled;
  Object? get lastError => _lastError;
  AppLogHandlerBinding? get handlerBinding => _handlerBinding;

  /// Creates the log directory.  Any filesystem failure is retained in
  /// [lastError] but intentionally does not escape this method.
  Future<void> initialize() {
    if (_initialized || _disabled || _closed) return Future<void>.value();
    final pending = _initialization;
    if (pending != null) return pending;
    final operation = _initialize();
    _initialization = operation;
    return operation;
  }

  Future<void> _initialize() async {
    try {
      await logsDirectory.create(recursive: true);
      final current = logFile;
      if (await current.exists() && await current.length() > maxFileBytes) {
        await _rotate();
      }
      _initialized = true;
    } catch (error) {
      _lastError = error;
      _disabled = true;
    }
  }

  /// Records a bounded event with only allowlisted metadata values.
  ///
  /// Numeric and boolean values are accepted for any stable key.  String
  /// values are accepted only when the key and enum value are in the catalog
  /// above; free-form text (including Todo titles) is discarded.
  Future<void> logEvent(
    String code, {
    AppLogLevel level = AppLogLevel.info,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    return _enqueue(() async {
      final safeCode = _safeCode(code);
      await _writeRecord(
        level: level,
        code: safeCode,
        metadata: _sanitizeMetadata(metadata),
      );
    });
  }

  /// Records an error without calling [Object.toString] on the error object.
  /// Only its runtime type and filtered stack frames are retained.
  Future<void> logError({
    required String code,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    return _enqueue(() async {
      final safeType = error == null ? null : _safeToken(error.runtimeType);
      await _writeRecord(
        level: AppLogLevel.error,
        code: _safeCode(code),
        metadata: _sanitizeMetadata(metadata),
        errorType: safeType,
        stack: _sanitizeStack(stackTrace),
      );
    });
  }

  Future<void> logFlutterError(FlutterErrorDetails details) {
    return logError(
      code: flutterErrorCode,
      error: details.exception,
      stackTrace: details.stack,
      metadata: const <String, Object?>{'source': 'flutter'},
    );
  }

  Future<void> logPlatformError(Object error, StackTrace stackTrace) {
    return logError(
      code: platformErrorCode,
      error: error,
      stackTrace: stackTrace,
      metadata: const <String, Object?>{'source': 'platform'},
    );
  }

  /// Installs and chains both process-wide Flutter error boundaries.
  ///
  /// Flutter's default [FlutterError.presentError] is preserved whenever no
  /// previous custom handler exists.  The platform handler always returns
  /// `true` after forwarding to any previous handler, preventing an uncaught
  /// platform exception from terminating the host because logging failed.
  AppLogHandlerBinding installGlobalErrorHandlers() {
    final existing = _handlerBinding;
    if (existing != null && !existing.isRestored) return existing;

    final previousFlutter = FlutterError.onError;
    final previousPlatform = PlatformDispatcher.instance.onError;
    late FlutterExceptionHandler flutterHandler;
    late bool Function(Object, StackTrace) platformHandler;

    flutterHandler = (details) {
      unawaited(logFlutterError(details));
      try {
        (previousFlutter ?? FlutterError.presentError)(details);
      } catch (error, stackTrace) {
        unawaited(
          logError(
            code: 'flutter.handler_failed',
            error: error,
            stackTrace: stackTrace,
            metadata: const <String, Object?>{'source': 'flutter'},
          ),
        );
      }
    };

    platformHandler = (error, stackTrace) {
      unawaited(logPlatformError(error, stackTrace));
      final previous = previousPlatform;
      if (previous != null) {
        try {
          previous(error, stackTrace);
        } catch (forwardError, forwardStack) {
          unawaited(
            logError(
              code: 'platform.handler_failed',
              error: forwardError,
              stackTrace: forwardStack,
              metadata: const <String, Object?>{'source': 'platform'},
            ),
          );
        }
      }
      return true;
    };

    FlutterError.onError = flutterHandler;
    PlatformDispatcher.instance.onError = platformHandler;

    late final AppLogHandlerBinding binding;
    binding = AppLogHandlerBinding._(() {
      if (FlutterError.onError == flutterHandler) {
        FlutterError.onError = previousFlutter;
      }
      if (PlatformDispatcher.instance.onError == platformHandler) {
        PlatformDispatcher.instance.onError = previousPlatform;
      }
      if (identical(_handlerBinding, binding)) _handlerBinding = null;
    });
    _handlerBinding = binding;
    return binding;
  }

  void restoreGlobalErrorHandlers() => _handlerBinding?.restore();

  /// Waits for all queued writes.  Flush is best effort and never throws.
  Future<void> flush() async {
    try {
      await _writeTail;
    } catch (error) {
      _lastError = error;
    }
  }

  /// Flushes pending writes and restores any process-wide handlers.
  Future<void> close() async {
    if (_closed) return;
    _closing = true;
    await flush();
    _closed = true;
    _handlerBinding?.restore();
  }

  Future<void> dispose() => close();

  Future<void> _writeRecord({
    required AppLogLevel level,
    required String code,
    required Map<String, Object> metadata,
    String? errorType,
    String? stack,
  }) async {
    if (_closed || _disabled) return;
    await initialize();
    if (!_initialized || _disabled || _closed) return;

    final fields = <String>[
      'utc=${DateTime.now().toUtc().toIso8601String()}',
      'local=${DateTime.now().toLocal().toIso8601String()}',
      'level=${level.name}',
      'code=$code',
      if (errorType != null) 'errorType=$errorType',
      for (final entry in metadata.entries) '${entry.key}=${entry.value}',
      if (stack != null && stack.isNotEmpty)
        'stack=${stack.replaceAll('\n', '|')}',
    ];
    await _appendLine('${fields.join(' ')}\n');
  }

  Future<void> _appendLine(String line) async {
    final encoded = _truncateUtf8(line, maxFileBytes);
    if (encoded.isEmpty) return;
    await logsDirectory.create(recursive: true);
    final current = logFile;
    final currentLength = await current.exists() ? await current.length() : 0;
    if (currentLength > 0 && currentLength + encoded.length > maxFileBytes ||
        currentLength > maxFileBytes) {
      await _rotate();
    }
    await current.writeAsBytes(encoded, mode: FileMode.append, flush: true);
  }

  Future<void> _rotate() async {
    await logsDirectory.create(recursive: true);
    for (var index = maxRotatedFiles; index >= 1; index -= 1) {
      final source = index == 1 ? logFile : rotatedFile(index - 1);
      final target = rotatedFile(index);
      if (!await source.exists()) continue;
      if (await target.exists()) await target.delete();
      await source.rename(target.path);
    }
  }

  Future<void> _enqueue(Future<void> Function() action) {
    if (_closed || _closing) return Future<void>.value();
    final operation = _writeTail.then<void>((_) async {
      try {
        await action();
      } catch (error) {
        _lastError = error;
      }
    });
    _writeTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
  }

  Map<String, Object> _sanitizeMetadata(Map<String, Object?> metadata) {
    final safe = <String, Object>{};
    final keys = metadata.keys.toList(growable: false)..sort();
    for (final key in keys) {
      if (!_safeMetadataKeyPattern.hasMatch(key)) continue;
      final value = metadata[key];
      if (value is num && value.isFinite) {
        safe[key] = value;
        continue;
      }
      if (value is bool) {
        safe[key] = value;
        continue;
      }
      if (value is String && _isAllowedEnumValue(key, value)) {
        safe[key] = value;
      }
    }
    return safe;
  }

  bool _isAllowedEnumValue(String key, String value) {
    if (!_safeEnumPattern.hasMatch(value)) return false;
    final allowed = _knownEnumValues[key];
    return allowed != null && allowed.contains(value);
  }

  static String _safeCode(String code) =>
      _safeCodePattern.hasMatch(code) ? code : 'invalid_event_code';

  static String _safeToken(Type type) => _safeTokenString(type.toString());

  static String _safeTokenString(String value) {
    final token = value.replaceAll(RegExp(r'[^A-Za-z0-9_.:-]'), '_');
    if (token.isEmpty) return 'unknown';
    final end = token.length > 64 ? 64 : token.length;
    return token.substring(0, end);
  }

  static String _sanitizeStack(StackTrace? stackTrace) {
    if (stackTrace == null) return '';
    final frames = <String>[];
    for (final line in stackTrace.toString().split(RegExp(r'\r?\n'))) {
      final match = _stackFramePattern.firstMatch(line);
      if (match == null) continue;
      final index = match.group(1)!;
      final payload = match
          .group(2)!
          .replaceAll(_unsafeStackCharacterPattern, '_')
          .trim();
      if (payload.isEmpty) continue;
      frames.add('#$index $payload');
      if (frames.length == 24) break;
    }
    final result = frames.join('\n');
    final end = result.length > 4096 ? 4096 : result.length;
    return result.substring(0, end);
  }

  static List<int> _truncateUtf8(String value, int maxBytes) {
    final bytes = utf8.encode(value);
    if (bytes.length <= maxBytes) return bytes;
    var end = maxBytes;
    while (end > 0) {
      final candidate = utf8.decode(
        bytes.sublist(0, end),
        allowMalformed: true,
      );
      final encoded = utf8.encode(candidate);
      if (encoded.length <= maxBytes) return encoded;
      end -= 1;
    }
    return const <int>[];
  }

  static String _join(String parent, String child) =>
      '$parent${Platform.pathSeparator}$child';
}
