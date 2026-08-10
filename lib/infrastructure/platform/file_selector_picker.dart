import 'package:file_selector/file_selector.dart' as file_selector;

import '../../application/data_transfer_file_picker.dart';

/// Official Flutter file-selector adapter used by Windows data transfer.
class FileSelectorPicker implements DataTransferFilePicker {
  const FileSelectorPicker();

  static const _jsonTypes = <file_selector.XTypeGroup>[
    file_selector.XTypeGroup(
      label: 'JSON',
      extensions: <String>['json'],
      mimeTypes: <String>['application/json'],
    ),
  ];

  @override
  Future<String?> pickImportFile() async {
    final selected = await file_selector.openFile(
      acceptedTypeGroups: _jsonTypes,
      confirmButtonText: '导入',
    );
    return selected?.path;
  }

  @override
  Future<String?> pickExportFile() async {
    final selected = await file_selector.getSaveLocation(
      acceptedTypeGroups: _jsonTypes,
      suggestedName: 'litetodo-data.json',
      confirmButtonText: '导出',
      canCreateDirectories: true,
    );
    return selected?.path;
  }
}
