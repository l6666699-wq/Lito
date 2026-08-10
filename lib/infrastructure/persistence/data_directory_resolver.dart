import 'dart:io';

bool _isAbsolutePath(String path) {
  if (path.startsWith('/') || path.startsWith('\\')) return true;
  return path.length >= 3 && RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path);
}

/// Resolves the optional process-only data directory override.
///
/// The resolver is kept independent from either JSON repository so platform
/// persistence services can share the same path policy without introducing a
/// repository import cycle.
Directory? resolveLiteTodoDataDirectoryOverride(String? value) {
  final override = value?.trim();
  if (override == null || override.isEmpty) return null;
  if (!_isAbsolutePath(override)) {
    throw StateError('LITETODO_DATA_DIR must be an absolute path');
  }
  return Directory(override);
}
