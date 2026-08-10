import 'dart:async';
import 'dart:io';

typedef JsonFileValidator = FutureOr<void> Function(String contents);

/// Writes a JSON snapshot through a sibling temp file and a previous-version
/// copy.  The sequence deliberately does not claim POSIX atomic guarantees on
/// Windows: a valid previous file is retained before replacing the target.
class SafeFileWriter {
  const SafeFileWriter();

  Future<void> writeJson(
    File target,
    String contents, {
    JsonFileValidator? validator,
  }) async {
    final parent = target.parent;
    await parent.create(recursive: true);
    final temp = File(_temporaryPath(target));
    final previous = File(_previousPath(target));
    var replaced = false;
    try {
      await temp.writeAsString(contents, flush: true);
      if (validator != null) {
        final encoded = await temp.readAsString();
        await validator(encoded);
      }

      if (await target.exists() && await _isValid(target, validator)) {
        await target.copy(previous.path);
      }

      // Windows does not support replacing an existing file through rename in
      // every filesystem provider.  Delete only after the previous copy has
      // been preserved; a failed replacement can therefore still recover.
      if (Platform.isWindows && await target.exists()) {
        await target.delete();
      }
      await temp.rename(target.path);
      replaced = true;
    } finally {
      if (!replaced && await temp.exists()) {
        await temp.delete();
      }
    }
  }

  static String _temporaryPath(File target) {
    final path = target.path;
    return path.toLowerCase().endsWith('.json')
        ? '${path.substring(0, path.length - 5)}.tmp'
        : '$path.tmp';
  }

  static String _previousPath(File target) {
    final path = target.path;
    return path.toLowerCase().endsWith('.json')
        ? '${path.substring(0, path.length - 5)}.prev.json'
        : '$path.prev';
  }

  static Future<bool> _isValid(File file, JsonFileValidator? validator) async {
    if (validator == null) return true;
    try {
      await validator(await file.readAsString());
      return true;
    } catch (_) {
      return false;
    }
  }
}
