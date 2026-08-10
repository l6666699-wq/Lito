import '../domain/models/app_data.dart';

/// Stable transfer errors shared by the application controller and its
/// infrastructure implementation.
enum DataTransferErrorCode {
  pickerFailed,
  flushFailed,
  sourceUnavailable,
  invalidUtf8,
  invalidJson,
  invalidRoot,
  missingSchemaVersion,
  unsupportedSchemaVersion,
  invalidData,
  invalidTarget,
  targetWriteFailed,
  backupFailed,
  migrationBackupFailed,
}

class DataTransferException implements Exception {
  const DataTransferException(this.code);

  final DataTransferErrorCode code;

  @override
  String toString() => 'DataTransferException($code)';
}

/// A validated import document.  [raw] is retained only long enough to make a
/// migration safety copy when the source is schema v1.
class DataTransferDocument {
  const DataTransferDocument({
    required this.raw,
    required this.data,
    required this.schemaVersion,
  });

  final String raw;
  final AppData data;
  final int schemaVersion;
}

/// Application port for persistence-backed data transfer.
abstract interface class DataTransferGateway {
  Future<DataTransferDocument> readImportFile(String path);

  Future<void> exportData(AppData snapshot, String path);

  Future<void> createManualBackup();

  Future<void> createMigrationBackup(String raw);
}
