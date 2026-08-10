import 'dart:io';

import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../../domain/models/app_settings.dart';

typedef HotkeyPressedHandler = Future<void> Function();

abstract interface class GlobalHotkeyService {
  bool get isRegistered;
  String? get error;

  /// Registers the supplied configuration.  Omitting [config] preserves the
  /// original Ctrl+Alt+Space API and default behavior.
  Future<void> register({
    required HotkeyPressedHandler onPressed,
    AppHotkeyConfig? config,
  });
  Future<void> unregister();
}

/// Global Ctrl+Alt+Space registration through hotkey_manager.
class WindowsGlobalHotkeyService implements GlobalHotkeyService {
  HotKey? _hotKey;
  bool _isRegistered = false;
  String? _error;
  AppHotkeyConfig? _activeConfig;

  @override
  bool get isRegistered => _isRegistered;

  @override
  String? get error => _error;

  AppHotkeyConfig? get activeConfig => _activeConfig;

  @override
  Future<void> register({
    required HotkeyPressedHandler onPressed,
    AppHotkeyConfig? config,
  }) async {
    if (!Platform.isWindows) return;
    await unregister();
    final effectiveConfig = config ?? const AppHotkeyConfig.defaultValue();
    try {
      final hotKey = HotKey(
        key: _resolveLogicalKey(effectiveConfig.key),
        modifiers: effectiveConfig.modifiers
            .map(_toPluginModifier)
            .toList(growable: false),
        scope: HotKeyScope.system,
      );
      await hotKeyManager.register(hotKey, keyDownHandler: (_) => onPressed());
      _hotKey = hotKey;
      _isRegistered = true;
      _activeConfig = effectiveConfig;
      _error = null;
    } on PlatformException catch (error) {
      _hotKey = null;
      _isRegistered = false;
      _activeConfig = null;
      _error = 'Global hotkey registration failed (${error.code}).';
    } catch (error) {
      _hotKey = null;
      _isRegistered = false;
      _activeConfig = null;
      _error = 'Global hotkey registration failed: $error';
    }
  }

  @override
  Future<void> unregister() async {
    final hotKey = _hotKey;
    _hotKey = null;
    _isRegistered = false;
    _activeConfig = null;
    if (hotKey == null) return;
    try {
      await hotKeyManager.unregister(hotKey);
    } catch (error) {
      _error ??= 'Global hotkey cleanup failed: $error';
    }
  }
}

class FakeGlobalHotkeyService implements GlobalHotkeyService {
  FakeGlobalHotkeyService({this.failRegistration = false});

  final bool failRegistration;
  HotkeyPressedHandler? _handler;
  bool _isRegistered = false;
  String? _error;
  AppHotkeyConfig? _activeConfig;
  int registerCount = 0;
  int unregisterCount = 0;
  final List<AppHotkeyConfig> registeredConfigs = <AppHotkeyConfig>[];

  @override
  bool get isRegistered => _isRegistered;

  @override
  String? get error => _error;

  AppHotkeyConfig? get activeConfig => _activeConfig;

  @override
  Future<void> register({
    required HotkeyPressedHandler onPressed,
    AppHotkeyConfig? config,
  }) async {
    registerCount += 1;
    final effectiveConfig = config ?? const AppHotkeyConfig.defaultValue();
    if (failRegistration) {
      _isRegistered = false;
      _activeConfig = null;
      _error = 'Global hotkey registration failed (fake).';
      return;
    }
    _handler = onPressed;
    _isRegistered = true;
    _activeConfig = effectiveConfig;
    registeredConfigs.add(effectiveConfig);
    _error = null;
  }

  @override
  Future<void> unregister() async {
    unregisterCount += 1;
    _handler = null;
    _isRegistered = false;
    _activeConfig = null;
  }

  Future<void> trigger() async => _handler?.call();
}

HotKeyModifier _toPluginModifier(AppHotkeyModifier modifier) {
  switch (modifier) {
    case AppHotkeyModifier.control:
      return HotKeyModifier.control;
    case AppHotkeyModifier.alt:
      return HotKeyModifier.alt;
    case AppHotkeyModifier.shift:
      return HotKeyModifier.shift;
    case AppHotkeyModifier.meta:
      return HotKeyModifier.meta;
    case AppHotkeyModifier.capsLock:
      return HotKeyModifier.capsLock;
    case AppHotkeyModifier.fn:
      return HotKeyModifier.fn;
  }
}

LogicalKeyboardKey _resolveLogicalKey(String value) {
  final key = value.trim().toLowerCase();
  final named = <String, LogicalKeyboardKey>{
    'space': LogicalKeyboardKey.space,
    'enter': LogicalKeyboardKey.enter,
    'return': LogicalKeyboardKey.enter,
    'escape': LogicalKeyboardKey.escape,
    'esc': LogicalKeyboardKey.escape,
    'tab': LogicalKeyboardKey.tab,
    'backspace': LogicalKeyboardKey.backspace,
    'delete': LogicalKeyboardKey.delete,
    'insert': LogicalKeyboardKey.insert,
    'home': LogicalKeyboardKey.home,
    'end': LogicalKeyboardKey.end,
    'pageup': LogicalKeyboardKey.pageUp,
    'pagedown': LogicalKeyboardKey.pageDown,
    'arrowup': LogicalKeyboardKey.arrowUp,
    'arrowdown': LogicalKeyboardKey.arrowDown,
    'arrowleft': LogicalKeyboardKey.arrowLeft,
    'arrowright': LogicalKeyboardKey.arrowRight,
    'f1': LogicalKeyboardKey.f1,
    'f2': LogicalKeyboardKey.f2,
    'f3': LogicalKeyboardKey.f3,
    'f4': LogicalKeyboardKey.f4,
    'f5': LogicalKeyboardKey.f5,
    'f6': LogicalKeyboardKey.f6,
    'f7': LogicalKeyboardKey.f7,
    'f8': LogicalKeyboardKey.f8,
    'f9': LogicalKeyboardKey.f9,
    'f10': LogicalKeyboardKey.f10,
    'f11': LogicalKeyboardKey.f11,
    'f12': LogicalKeyboardKey.f12,
    '0': LogicalKeyboardKey.digit0,
    '1': LogicalKeyboardKey.digit1,
    '2': LogicalKeyboardKey.digit2,
    '3': LogicalKeyboardKey.digit3,
    '4': LogicalKeyboardKey.digit4,
    '5': LogicalKeyboardKey.digit5,
    '6': LogicalKeyboardKey.digit6,
    '7': LogicalKeyboardKey.digit7,
    '8': LogicalKeyboardKey.digit8,
    '9': LogicalKeyboardKey.digit9,
    'a': LogicalKeyboardKey.keyA,
    'b': LogicalKeyboardKey.keyB,
    'c': LogicalKeyboardKey.keyC,
    'd': LogicalKeyboardKey.keyD,
    'e': LogicalKeyboardKey.keyE,
    'f': LogicalKeyboardKey.keyF,
    'g': LogicalKeyboardKey.keyG,
    'h': LogicalKeyboardKey.keyH,
    'i': LogicalKeyboardKey.keyI,
    'j': LogicalKeyboardKey.keyJ,
    'k': LogicalKeyboardKey.keyK,
    'l': LogicalKeyboardKey.keyL,
    'm': LogicalKeyboardKey.keyM,
    'n': LogicalKeyboardKey.keyN,
    'o': LogicalKeyboardKey.keyO,
    'p': LogicalKeyboardKey.keyP,
    'q': LogicalKeyboardKey.keyQ,
    'r': LogicalKeyboardKey.keyR,
    's': LogicalKeyboardKey.keyS,
    't': LogicalKeyboardKey.keyT,
    'u': LogicalKeyboardKey.keyU,
    'v': LogicalKeyboardKey.keyV,
    'w': LogicalKeyboardKey.keyW,
    'x': LogicalKeyboardKey.keyX,
    'y': LogicalKeyboardKey.keyY,
    'z': LogicalKeyboardKey.keyZ,
  };
  final resolved = named[key];
  if (resolved != null) return resolved;
  throw FormatException('Unsupported global hotkey key: $value');
}
