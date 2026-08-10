import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/app_settings.dart';
import 'data_directory_resolver.dart';
import 'safe_file_writer.dart';
import 'settings_repository.dart';

/// JSON implementation of [SettingsRepository].
///
/// The repository owns the short debounce window and serializes all writes.
/// A process-level `LITETODO_DATA_DIR` override is deliberately shared with
/// the data repository so tests and portable runs cannot split their files.
class JsonSettingsRepository implements SettingsRepository {
  JsonSettingsRepository({
    Directory? directory,
    this.appDirectoryName = 'LiteTodo',
    SafeFileWriter? writer,
    this.debounceDuration = const Duration(milliseconds: 250),
  }) : _directory = directory, // ignore: prefer_initializing_formals
       _writer = writer ?? const SafeFileWriter();

  final Directory? _directory;
  final String appDirectoryName;
  final SafeFileWriter _writer;
  final Duration debounceDuration;

  Future<void> _writeTail = Future<void>.value();
  Timer? _flushTimer;
  AppSettings? _pending;
  final List<Completer<void>> _waiters = <Completer<void>>[];
  bool _disposed = false;

  Future<Directory> get dataDirectory async {
    final directory =
        _directory ??
        resolveLiteTodoDataDirectoryOverride(
          Platform.environment['LITETODO_DATA_DIR'],
        ) ??
        Directory(
          '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}$appDirectoryName',
        );
    await directory.create(recursive: true);
    return directory;
  }

  Future<Directory> get directory => dataDirectory;

  Future<File> get settingsFile async => File(
    '${(await dataDirectory).path}${Platform.pathSeparator}settings.json',
  );

  Future<File> get previousFile async => File(
    '${(await dataDirectory).path}${Platform.pathSeparator}settings.prev.json',
  );

  Future<File> get temporaryFile async => File(
    '${(await dataDirectory).path}${Platform.pathSeparator}settings.tmp',
  );

  @override
  Future<AppSettingsLoadResult> load() async {
    await flushNow();
    final primary = await _readValid(await settingsFile);
    if (primary != null) {
      return AppSettingsLoadResult(
        settings: primary,
        source: SettingsLoadSource.primary,
      );
    }

    final previous = await _readValid(await previousFile);
    if (previous != null) {
      return AppSettingsLoadResult(
        settings: previous,
        source: SettingsLoadSource.previous,
        recoveryWarning:
            'settings.json is invalid; settings.prev.json was used for recovery.',
      );
    }

    final hasPrimary = await (await settingsFile).exists();
    final hasPrevious = await (await previousFile).exists();
    return AppSettingsLoadResult(
      settings: AppSettings(),
      source: SettingsLoadSource.defaults,
      recoveryWarning: hasPrimary || hasPrevious
          ? 'LiteTodo settings files could not be decoded; defaults were used.'
          : null,
    );
  }

  @override
  Future<void> save(AppSettings snapshot) {
    if (_disposed) {
      return Future<void>.error(StateError('Settings repository is disposed'));
    }
    // Validate before a snapshot enters the queue.  This keeps bad values from
    // replacing a valid pending snapshot.
    final normalized = AppSettings.fromJson(snapshot.toJson());
    final completer = Completer<void>();
    _pending = normalized;
    _waiters.add(completer);
    _flushTimer?.cancel();
    _flushTimer = Timer(debounceDuration, () {
      unawaited(flushNow());
    });
    return completer.future;
  }

  @override
  Future<void> flushNow() {
    _flushTimer?.cancel();
    _flushTimer = null;
    final snapshot = _pending;
    if (snapshot == null) return _writeTail;
    _pending = null;
    final waiters = List<Completer<void>>.from(_waiters);
    _waiters.clear();

    final operation = _writeTail.then<void>((_) => _saveNow(snapshot));
    _writeTail = operation.then<void>((_) {}, onError: (_, _) {});
    operation.then<void>(
      (_) {
        for (final waiter in waiters) {
          if (!waiter.isCompleted) waiter.complete();
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        // Keep the failed snapshot available for an explicit retry while
        // surfacing the failure to every caller that awaited save().
        _pending ??= snapshot;
        for (final waiter in waiters) {
          if (!waiter.isCompleted) waiter.completeError(error, stackTrace);
        }
      },
    );
    return operation;
  }

  /// Stops the debounce timer.  A caller that needs to retain queued changes
  /// should call [flushNow] before disposing the repository.
  void dispose() {
    _disposed = true;
    _flushTimer?.cancel();
    _flushTimer = null;
    final error = StateError('Settings repository is disposed');
    for (final waiter in _waiters) {
      if (!waiter.isCompleted) waiter.completeError(error);
    }
    _waiters.clear();
    _pending = null;
  }

  Future<void> _saveNow(AppSettings snapshot) async {
    final encoded = jsonEncode(snapshot.toJson());
    await _writer.writeJson(
      await settingsFile,
      encoded,
      validator: (contents) {
        final decoded = jsonDecode(contents);
        if (decoded is! Map) throw const FormatException('JSON root must map');
        AppSettings.fromJson(Map<String, dynamic>.from(decoded));
      },
    );
  }

  Future<AppSettings?> _readValid(File file) async {
    try {
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) throw const FormatException('JSON root must map');
      return AppSettings.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }
}

Directory? resolveLiteTodoSettingsDataDirectoryOverride(String? value) =>
    resolveLiteTodoDataDirectoryOverride(value);

Future<JsonSettingsRepository> createDefaultSettingsRepository() async {
  if (Platform.environment['LITETODO_DATA_DIR']?.trim().isNotEmpty == true) {
    return JsonSettingsRepository();
  }
  final support = await getApplicationSupportDirectory();
  return JsonSettingsRepository(
    directory: Directory('${support.path}${Platform.pathSeparator}LiteTodo'),
  );
}
