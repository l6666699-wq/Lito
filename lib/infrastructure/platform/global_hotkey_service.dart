import 'dart:io';

import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

typedef HotkeyPressedHandler = Future<void> Function();

abstract interface class GlobalHotkeyService {
  bool get isRegistered;
  String? get error;

  Future<void> register({required HotkeyPressedHandler onPressed});
  Future<void> unregister();
}

/// Global Ctrl+Alt+Space registration through hotkey_manager.
class WindowsGlobalHotkeyService implements GlobalHotkeyService {
  HotKey? _hotKey;
  bool _isRegistered = false;
  String? _error;

  @override
  bool get isRegistered => _isRegistered;

  @override
  String? get error => _error;

  @override
  Future<void> register({required HotkeyPressedHandler onPressed}) async {
    if (!Platform.isWindows) return;
    await unregister();
    final hotKey = HotKey(
      key: LogicalKeyboardKey.space,
      modifiers: const <HotKeyModifier>[
        HotKeyModifier.control,
        HotKeyModifier.alt,
      ],
      scope: HotKeyScope.system,
    );
    try {
      await hotKeyManager.register(hotKey, keyDownHandler: (_) => onPressed());
      _hotKey = hotKey;
      _isRegistered = true;
      _error = null;
    } on PlatformException catch (error) {
      _hotKey = null;
      _isRegistered = false;
      _error = 'Global hotkey registration failed (${error.code}).';
    } catch (error) {
      _hotKey = null;
      _isRegistered = false;
      _error = 'Global hotkey registration failed: $error';
    }
  }

  @override
  Future<void> unregister() async {
    final hotKey = _hotKey;
    _hotKey = null;
    _isRegistered = false;
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
  int registerCount = 0;
  int unregisterCount = 0;

  @override
  bool get isRegistered => _isRegistered;

  @override
  String? get error => _error;

  @override
  Future<void> register({required HotkeyPressedHandler onPressed}) async {
    registerCount += 1;
    if (failRegistration) {
      _isRegistered = false;
      _error = 'Global hotkey registration failed (fake).';
      return;
    }
    _handler = onPressed;
    _isRegistered = true;
    _error = null;
  }

  @override
  Future<void> unregister() async {
    unregisterCount += 1;
    _handler = null;
    _isRegistered = false;
  }

  Future<void> trigger() async => _handler?.call();
}
