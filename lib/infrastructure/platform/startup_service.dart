import 'dart:io';

import 'package:launch_at_startup/launch_at_startup.dart';

/// Platform-independent startup preference port.
abstract interface class StartupService {
  Future<bool> enable();

  Future<bool> disable();

  Future<bool> isEnabled();
}

/// Windows implementation backed by launch_at_startup.
class WindowsStartupService implements StartupService {
  WindowsStartupService({
    String appName = 'LiteTodo',
    String? appPath,
    String? packageName,
    List<String> args = const <String>[],
    bool setup = true,
  }) {
    if (setup && Platform.isWindows) {
      launchAtStartup.setup(
        appName: appName,
        appPath: appPath ?? Platform.resolvedExecutable,
        packageName: packageName,
        args: args,
      );
    }
  }

  @override
  Future<bool> enable() async {
    if (!Platform.isWindows) return false;
    return launchAtStartup.enable();
  }

  @override
  Future<bool> disable() async {
    if (!Platform.isWindows) return false;
    return launchAtStartup.disable();
  }

  @override
  Future<bool> isEnabled() async {
    if (!Platform.isWindows) return false;
    return launchAtStartup.isEnabled();
  }
}

/// In-memory implementation for application and unit tests.
class FakeStartupService implements StartupService {
  FakeStartupService({
    this.failEnable = false,
    this.failDisable = false,
    bool enabled = false,
  }) : _enabled = enabled; // ignore: prefer_initializing_formals

  final bool failEnable;
  final bool failDisable;
  bool _enabled;
  int enableCount = 0;
  int disableCount = 0;
  int isEnabledCount = 0;

  @override
  Future<bool> enable() async {
    enableCount += 1;
    if (failEnable) return false;
    _enabled = true;
    return true;
  }

  @override
  Future<bool> disable() async {
    disableCount += 1;
    if (failDisable) return false;
    _enabled = false;
    return true;
  }

  @override
  Future<bool> isEnabled() async {
    isEnabledCount += 1;
    return _enabled;
  }

  bool get enabled => _enabled;
}
