import 'dart:io';

import 'package:path_provider/path_provider.dart';

abstract interface class DataDirectoryService {
  Future<Directory> resolve();

  Future<bool> open();
}

/// Opens the same LiteTodo directory used by the persistence repositories.
class WindowsDataDirectoryService implements DataDirectoryService {
  WindowsDataDirectoryService({this._directory});

  final Directory? _directory;

  @override
  Future<Directory> resolve() async {
    final directory =
        _directory ??
        Directory(
          '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}LiteTodo',
        );
    await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<bool> open() async {
    final directory = await resolve();
    if (!Platform.isWindows) return false;
    final result = await Process.start('explorer.exe', <String>[
      directory.path,
    ]);
    final exitCode = await result.exitCode;
    return exitCode == 0;
  }
}

class FakeDataDirectoryService implements DataDirectoryService {
  FakeDataDirectoryService({Directory? directory})
    : _directory = directory ?? Directory.systemTemp;

  final Directory _directory;
  int openCount = 0;

  @override
  Future<Directory> resolve() async {
    await _directory.create(recursive: true);
    return _directory;
  }

  @override
  Future<bool> open() async {
    openCount += 1;
    return true;
  }
}
