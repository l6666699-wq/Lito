import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/models/app_settings.dart';
import '../infrastructure/platform/global_hotkey_service.dart';
import '../infrastructure/platform/startup_service.dart';
import '../infrastructure/persistence/json_settings_repository.dart';
import '../infrastructure/persistence/settings_repository.dart';

/// Coordinates immutable settings snapshots with persistence and optional
/// desktop capabilities.  Platform services are injected so tests never need
/// to touch the Windows registry or native hotkey manager.
class SettingsController extends ChangeNotifier {
  static const String startupPreferenceFailureMessage =
      'Startup preference could not be applied';

  SettingsController({
    SettingsRepository? repository,
    SettingsRepository? settingsRepository,
    StartupService? startupService,
    GlobalHotkeyService? globalHotkeyService,
    HotkeyPressedHandler? onGlobalHotkeyPressed,
  }) : _repository = repository ?? settingsRepository,
       // The public aliases above keep old call sites source-compatible.
       // ignore: prefer_initializing_formals
       _startupService = startupService,
       // ignore: prefer_initializing_formals
       _globalHotkeyService = globalHotkeyService,
       _onGlobalHotkeyPressed = onGlobalHotkeyPressed ?? _noopHotkeyHandler {
    if (_repository == null) {
      throw ArgumentError('A SettingsRepository is required');
    }
  }

  final SettingsRepository? _repository;
  final StartupService? _startupService;
  final GlobalHotkeyService? _globalHotkeyService;
  final HotkeyPressedHandler _onGlobalHotkeyPressed;
  Future<void> _operationTail = Future<void>.value();
  AppSettings _settings = AppSettings();
  bool _initialized = false;
  bool _disposed = false;
  String? _lastPersistenceError;
  String? _recoveryWarning;

  AppSettings get settings => _settings;
  int get revision => _settings.revision;
  AppThemeMode get themeMode => _settings.themeMode;
  String get accentColorKey => _settings.accentColorKey;
  String get fontFamilyKey => _settings.fontFamilyKey;
  double get fontScale => _settings.fontScale;
  AppWindowMode get defaultWindowMode => _settings.defaultWindowMode;
  bool get closeToTray => _settings.closeToTray;
  bool get rememberWindowPosition => _settings.rememberWindowPosition;
  bool get autoBackup => _settings.autoBackup;
  bool get globalHotkeyEnabled => _settings.globalHotkeyEnabled;
  AppHotkeyConfig get globalHotkey => _settings.globalHotkey;
  bool get launchAtStartup => _settings.launchAtStartup;
  bool get startHidden => _settings.startHidden;
  bool get compactAlwaysOnTop => _settings.compactAlwaysOnTop;
  bool get compactSkipTaskbar => _settings.compactSkipTaskbar;
  bool get lockCompactPosition => _settings.lockCompactPosition;
  AppWindowGeometry? get fullGeometry => _settings.fullGeometry;
  AppWindowGeometry? get compactGeometry => _settings.compactGeometry;
  bool get supportsCrossRestartWindowGeometry => true;
  String? get lastProjectId => _settings.lastProjectId;
  bool get isInitialized => _initialized;
  String? get lastPersistenceError => _lastPersistenceError;
  String? get recoveryWarning => _recoveryWarning;

  Future<void> initialize() => _enqueue<void>(() async {
    if (_initialized) return;
    final result = await _repository!.load();
    _settings = result.settings;
    _recoveryWarning = result.recoveryWarning;
    try {
      await _syncPlatformState(_settings);
    } catch (error) {
      _lastPersistenceError = _stableErrorMessage(error);
      // A native startup or hotkey capability must not prevent the settings
      // page from opening.  The loaded snapshot remains editable, while the
      // error is exposed for a localized, actionable banner and the next
      // mutation can retry the platform operation.
      _initialized = true;
      notifyListeners();
      return;
    }
    _initialized = true;
    notifyListeners();
  });

  Future<void> flushNow() => _enqueue<void>(() async {
    try {
      await _repository!.flushNow();
    } catch (error) {
      _lastPersistenceError = error.toString();
      notifyListeners();
      rethrow;
    }
  });

  Future<bool> setThemeMode(AppThemeMode value) =>
      _update((current) => current.copyWith(themeMode: value));

  Future<bool> updateThemeMode(AppThemeMode value) => setThemeMode(value);

  Future<bool> setTheme(AppThemeMode value) => setThemeMode(value);

  Future<bool> setAccentColorKey(String value) =>
      _update((current) => current.copyWith(accentColorKey: value));

  Future<bool> updateAccentColorKey(String value) => setAccentColorKey(value);

  Future<bool> setAccentColor(String value) => setAccentColorKey(value);

  Future<bool> setFontFamilyKey(String value) =>
      _update((current) => current.copyWith(fontFamilyKey: value));

  Future<bool> updateFontFamilyKey(String value) => setFontFamilyKey(value);

  Future<bool> setFontFamily(String value) => setFontFamilyKey(value);

  Future<bool> setFontScale(double value) =>
      _update((current) => current.copyWith(fontScale: value));

  Future<bool> updateFontScale(double value) => setFontScale(value);

  Future<bool> setDefaultWindowMode(AppWindowMode value) =>
      _update((current) => current.copyWith(defaultWindowMode: value));

  Future<bool> updateDefaultWindowMode(AppWindowMode value) =>
      setDefaultWindowMode(value);

  Future<bool> setWindowMode(AppWindowMode value) =>
      setDefaultWindowMode(value);

  Future<bool> setCloseToTray(bool value) =>
      _update((current) => current.copyWith(closeToTray: value));

  Future<bool> updateCloseToTray(bool value) => setCloseToTray(value);

  Future<bool> setRememberWindowPosition(bool value) =>
      _update((current) => current.copyWith(rememberWindowPosition: value));

  Future<bool> updateRememberWindowPosition(bool value) =>
      setRememberWindowPosition(value);

  Future<bool> setAutoBackup(bool value) =>
      _update((current) => current.copyWith(autoBackup: value));

  Future<bool> updateAutoBackup(bool value) => setAutoBackup(value);

  Future<bool> setGlobalHotkeyEnabled(bool value) =>
      _update((current) => current.copyWith(globalHotkeyEnabled: value));

  Future<bool> updateGlobalHotkeyEnabled(bool value) =>
      setGlobalHotkeyEnabled(value);

  Future<bool> setGlobalHotkey(Object value) {
    return _update((current) {
      final config = value is AppHotkeyConfig
          ? value
          : AppHotkeyConfig.fromJson(value);
      return current.copyWith(globalHotkey: config);
    });
  }

  Future<bool> updateGlobalHotkey(Object value) => setGlobalHotkey(value);

  Future<bool> setHotkey(Object value) => setGlobalHotkey(value);

  Future<bool> setLaunchAtStartup(bool value) =>
      _update((current) => current.copyWith(launchAtStartup: value));

  Future<bool> updateLaunchAtStartup(bool value) => setLaunchAtStartup(value);

  Future<bool> setStartHidden(bool value) =>
      _update((current) => current.copyWith(startHidden: value));

  Future<bool> updateStartHidden(bool value) => setStartHidden(value);

  Future<bool> setCompactAlwaysOnTop(bool value) =>
      _update((current) => current.copyWith(compactAlwaysOnTop: value));

  Future<bool> updateCompactAlwaysOnTop(bool value) =>
      setCompactAlwaysOnTop(value);

  Future<bool> setCompactSkipTaskbar(bool value) =>
      _update((current) => current.copyWith(compactSkipTaskbar: value));

  Future<bool> updateCompactSkipTaskbar(bool value) =>
      setCompactSkipTaskbar(value);

  Future<bool> setLockCompactPosition(bool value) =>
      _update((current) => current.copyWith(lockCompactPosition: value));

  Future<bool> updateLockCompactPosition(bool value) =>
      setLockCompactPosition(value);

  Future<bool> setFullGeometry(AppWindowGeometry? value) =>
      _update((current) => current.copyWith(fullGeometry: value));

  Future<bool> setCompactGeometry(AppWindowGeometry? value) =>
      _update((current) => current.copyWith(compactGeometry: value));

  /// Clears both saved desktop rectangles in one persisted revision so a
  /// reset cannot leave Full and Compact out of sync after a write failure.
  Future<bool> resetWindowGeometries() => _update(
    (current) => current.copyWith(fullGeometry: null, compactGeometry: null),
  );

  Future<bool> setWindowGeometry(AppWindowMode mode, AppWindowGeometry? value) {
    if (mode == AppWindowMode.quickAdd) {
      return _enqueue<bool>(
        () async => _initialized
            ? true
            : _fail('SettingsController must be initialized before updating'),
      );
    }
    return mode == AppWindowMode.compact
        ? setCompactGeometry(value)
        : setFullGeometry(value);
  }

  /// Persists the last successful Quick Add project.  Passing `null` is an
  /// explicit clear rather than a request to retain the previous value.
  Future<bool> setLastProjectId(String? value) =>
      _update((current) => current.copyWith(lastProjectId: value));

  Future<bool> updateLastProjectId(String? value) => setLastProjectId(value);

  /// Atomically applies several settings when a caller needs to coordinate
  /// platform capabilities (for example startup plus global hotkey).
  Future<bool> updateSettings({
    AppThemeMode? themeMode,
    String? accentColorKey,
    String? fontFamilyKey,
    double? fontScale,
    AppWindowMode? defaultWindowMode,
    bool? closeToTray,
    bool? rememberWindowPosition,
    bool? autoBackup,
    bool? globalHotkeyEnabled,
    AppHotkeyConfig? globalHotkey,
    bool? launchAtStartup,
    bool? startHidden,
    bool? compactAlwaysOnTop,
    bool? compactSkipTaskbar,
    bool? lockCompactPosition,
    Object? fullGeometry = _settingsUpdateSentinel,
    Object? compactGeometry = _settingsUpdateSentinel,
  }) => _update((current) {
    var next = current.copyWith(
      themeMode: themeMode,
      accentColorKey: accentColorKey,
      fontFamilyKey: fontFamilyKey,
      fontScale: fontScale,
      defaultWindowMode: defaultWindowMode,
      closeToTray: closeToTray,
      rememberWindowPosition: rememberWindowPosition,
      autoBackup: autoBackup,
      globalHotkeyEnabled: globalHotkeyEnabled,
      globalHotkey: globalHotkey,
      launchAtStartup: launchAtStartup,
      startHidden: startHidden,
      compactAlwaysOnTop: compactAlwaysOnTop,
      compactSkipTaskbar: compactSkipTaskbar,
      lockCompactPosition: lockCompactPosition,
    );
    if (!identical(fullGeometry, _settingsUpdateSentinel)) {
      next = next.copyWith(fullGeometry: fullGeometry as AppWindowGeometry?);
    }
    if (!identical(compactGeometry, _settingsUpdateSentinel)) {
      next = next.copyWith(
        compactGeometry: compactGeometry as AppWindowGeometry?,
      );
    }
    return next;
  });

  Future<bool> _update(AppSettings Function(AppSettings current) build) {
    return _enqueue<bool>(() async {
      if (!_initialized) {
        return _fail('SettingsController must be initialized before updating');
      }
      final previous = _settings;
      late AppSettings candidate;
      try {
        candidate = build(previous.copyWith(revision: previous.revision + 1));
      } catch (error) {
        return _fail(error.toString());
      }

      var platformChanged = false;
      try {
        platformChanged = await _applyPlatformChange(previous, candidate);
        await _repository!.save(candidate);
      } catch (error) {
        if (platformChanged) {
          await _restorePlatformState(previous);
        }
        return _fail(_stableErrorMessage(error));
      }

      _settings = candidate;
      _lastPersistenceError = null;
      notifyListeners();
      return true;
    });
  }

  Future<bool> _applyPlatformChange(
    AppSettings previous,
    AppSettings candidate,
  ) async {
    var changed = false;
    try {
      final startup = _startupService;
      if (previous.launchAtStartup != candidate.launchAtStartup &&
          startup != null) {
        changed = true;
        final result = await _applyStartupPreference(
          startup,
          candidate.launchAtStartup,
        );
        if (!result) {
          throw StateError(startupPreferenceFailureMessage);
        }
      }

      final hotkey = _globalHotkeyService;
      if (hotkey != null &&
          (previous.globalHotkeyEnabled != candidate.globalHotkeyEnabled ||
              previous.globalHotkey != candidate.globalHotkey)) {
        if (candidate.globalHotkeyEnabled) {
          changed = true;
          await hotkey.register(
            onPressed: _onGlobalHotkeyPressed,
            config: candidate.globalHotkey,
          );
          // A successful native register can still expose a plugin error
          // asynchronously, so consider the platform changed before reading
          // the error property.
          if (hotkey.error != null) {
            throw StateError(hotkey.error!);
          }
        } else {
          changed = true;
          await hotkey.unregister();
        }
      }
      return changed;
    } catch (_) {
      // Apply the previous snapshot as a transaction rollback.  This is
      // needed when startup succeeds but hotkey registration fails afterward.
      if (changed) await _restorePlatformState(previous);
      rethrow;
    }
  }

  Future<void> _syncPlatformState(AppSettings value) async {
    final startup = _startupService;
    if (startup != null) {
      final bool current;
      try {
        current = await startup.isEnabled();
      } catch (_) {
        throw StateError(startupPreferenceFailureMessage);
      }
      if (current != value.launchAtStartup) {
        final result = await _applyStartupPreference(
          startup,
          value.launchAtStartup,
        );
        if (!result) {
          throw StateError(startupPreferenceFailureMessage);
        }
      }
    }
    final hotkey = _globalHotkeyService;
    if (hotkey != null) {
      if (value.globalHotkeyEnabled) {
        await hotkey.register(
          onPressed: _onGlobalHotkeyPressed,
          config: value.globalHotkey,
        );
        if (hotkey.error != null) {
          throw StateError(hotkey.error!);
        }
      } else {
        await hotkey.unregister();
      }
    }
  }

  Future<bool> _applyStartupPreference(
    StartupService startup,
    bool enabled,
  ) async {
    try {
      return enabled ? await startup.enable() : await startup.disable();
    } catch (_) {
      // The platform plugin can expose registry/permission details that are
      // unstable across Windows versions.  Keep the application-facing error
      // deterministic while retaining the previous settings snapshot.
      throw StateError(startupPreferenceFailureMessage);
    }
  }

  Future<void> _restorePlatformState(AppSettings value) async {
    try {
      final startup = _startupService;
      if (startup != null) {
        final result = value.launchAtStartup
            ? await startup.enable()
            : await startup.disable();
        if (!result) {
          // Continue restoring the hotkey even if the startup plugin could
          // not report a successful rollback.
        }
      }
      final hotkey = _globalHotkeyService;
      if (hotkey != null) {
        if (value.globalHotkeyEnabled) {
          await hotkey.register(
            onPressed: _onGlobalHotkeyPressed,
            config: value.globalHotkey,
          );
        } else {
          await hotkey.unregister();
        }
      }
    } catch (_) {
      // The original persistence error remains the actionable failure.  The
      // next initialize() call will reconcile platform state from disk.
    }
  }

  bool _fail(String message) {
    _lastPersistenceError = message;
    notifyListeners();
    return false;
  }

  String _stableErrorMessage(Object error) {
    if (error is StateError &&
        error.message == startupPreferenceFailureMessage) {
      return startupPreferenceFailureMessage;
    }
    return error.toString();
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    if (_disposed) {
      return Future<T>.error(StateError('SettingsController is disposed'));
    }
    final next = _operationTail.then<T>((_) => operation());
    _operationTail = next.then<void>((_) {}, onError: (_, _) {});
    return next;
  }

  @override
  void dispose() {
    _disposed = true;
    final repository = _repository;
    if (repository is JsonSettingsRepository) {
      repository.dispose();
    }
    super.dispose();
  }
}

Future<void> _noopHotkeyHandler() async {}

const Object _settingsUpdateSentinel = Object();
