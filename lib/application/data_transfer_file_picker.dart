/// Application-facing port for the native data import/export dialogs.
///
/// The application layer only deals in user-selected paths.  The concrete
/// Windows implementation lives under infrastructure and can be replaced by
/// a deterministic fake in tests.
abstract interface class DataTransferFilePicker {
  Future<String?> pickImportFile();

  Future<String?> pickExportFile();
}
