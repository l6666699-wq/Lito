import 'dart:io';

import 'package:windows_single_instance/windows_single_instance.dart';

typedef SecondInstanceHandler = Future<void> Function(List<String> args);

abstract interface class SingleInstanceService {
  Future<bool> ensureSingleInstance({
    required List<String> arguments,
    required SecondInstanceHandler onSecondInstance,
  });
}

/// Windows named-pipe single-instance gate.  The package forwards startup
/// arguments to the first process and exits the second process before it can
/// create a second Flutter window or write instance data.
class WindowsSingleInstanceService implements SingleInstanceService {
  static const String pipeName = 'litetodo_single_instance';

  @override
  Future<bool> ensureSingleInstance({
    required List<String> arguments,
    required SecondInstanceHandler onSecondInstance,
  }) async {
    if (!Platform.isWindows) return true;
    await WindowsSingleInstance.ensureSingleInstance(
      arguments,
      pipeName,
      onSecondWindow: (args) => onSecondInstance(args),
      bringWindowToFront: true,
    );
    // A secondary process is terminated by windows_single_instance before the
    // Future completes.  Returning true here therefore means the caller is
    // the primary process.
    return true;
  }
}

class FakeSingleInstanceService implements SingleInstanceService {
  FakeSingleInstanceService({this.primary = true});

  final bool primary;
  SecondInstanceHandler? _handler;
  List<String>? lastArguments;

  @override
  Future<bool> ensureSingleInstance({
    required List<String> arguments,
    required SecondInstanceHandler onSecondInstance,
  }) async {
    lastArguments = arguments;
    _handler = onSecondInstance;
    return primary;
  }

  Future<void> emitSecondInstance(List<String> arguments) async {
    await _handler?.call(arguments);
  }
}
