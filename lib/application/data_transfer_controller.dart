import 'dart:async';

import 'package:flutter/foundation.dart';

import 'data_transfer_gateway.dart';
import 'data_transfer_file_picker.dart';
import 'workspace_controller.dart';

enum DataTransferStatus { success, cancelled, failure }

class DataTransferResult {
  const DataTransferResult._({
    required this.status,
    this.errorCode,
    required this.message,
  });

  const DataTransferResult.success()
    : this._(status: DataTransferStatus.success, message: '操作成功。');

  const DataTransferResult.cancelled()
    : this._(status: DataTransferStatus.cancelled, message: '已取消。');

  DataTransferResult.failure(DataTransferErrorCode code)
    : this._(
        status: DataTransferStatus.failure,
        errorCode: code,
        message: _messageFor(code),
      );

  final DataTransferStatus status;
  final DataTransferErrorCode? errorCode;
  final String message;

  bool get isSuccess => status == DataTransferStatus.success;
  bool get isCancelled => status == DataTransferStatus.cancelled;
}

/// Serializes user-triggered import/export operations and owns their order.
class DataTransferController {
  DataTransferController({
    required this.workspace,
    required this.service,
    required this.filePicker,
  });

  final WorkspaceController workspace;
  final DataTransferGateway service;
  final DataTransferFilePicker filePicker;
  Future<void> _tail = Future<void>.value();
  final ValueNotifier<bool> _busy = ValueNotifier<bool>(false);
  int _queuedOperations = 0;

  bool get isBusy => _busy.value;
  ValueListenable<bool> get busyListenable => _busy;

  Future<DataTransferResult> exportData() => _enqueue(() async {
    late final String? path;
    try {
      path = await _pickExportPath();
    } on DataTransferException catch (error) {
      return DataTransferResult.failure(error.code);
    }
    if (path == null) return const DataTransferResult.cancelled();
    return _exportPath(path);
  });

  Future<DataTransferResult> exportToPath(String path) =>
      _enqueue(() => _exportPath(path));

  Future<DataTransferResult> importData() => _enqueue(() async {
    late final String? path;
    try {
      path = await _pickImportPath();
    } on DataTransferException catch (error) {
      return DataTransferResult.failure(error.code);
    }
    if (path == null) return const DataTransferResult.cancelled();
    return _importPath(path);
  });

  Future<DataTransferResult> importFromPath(String path) =>
      _enqueue(() => _importPath(path));

  Future<DataTransferResult> _exportPath(String path) async {
    try {
      await workspace.flushNow();
    } catch (_) {
      return DataTransferResult.failure(DataTransferErrorCode.flushFailed);
    }
    try {
      await service.exportData(workspace.appData, path);
      return const DataTransferResult.success();
    } on DataTransferException catch (error) {
      return DataTransferResult.failure(error.code);
    } catch (_) {
      return DataTransferResult.failure(
        DataTransferErrorCode.targetWriteFailed,
      );
    }
  }

  Future<DataTransferResult> _importPath(String path) async {
    late final DataTransferDocument candidate;
    try {
      candidate = await service.readImportFile(path);
    } on DataTransferException catch (error) {
      return DataTransferResult.failure(error.code);
    } catch (_) {
      return DataTransferResult.failure(
        DataTransferErrorCode.sourceUnavailable,
      );
    }
    try {
      await workspace.flushNow();
    } catch (_) {
      return DataTransferResult.failure(DataTransferErrorCode.flushFailed);
    }
    try {
      await service.createManualBackup();
      if (candidate.schemaVersion == 1) {
        await service.createMigrationBackup(candidate.raw);
      }
    } on DataTransferException catch (error) {
      return DataTransferResult.failure(error.code);
    } catch (_) {
      return DataTransferResult.failure(DataTransferErrorCode.backupFailed);
    }
    try {
      await workspace.replaceDataTransactional(candidate.data);
      return const DataTransferResult.success();
    } catch (_) {
      return DataTransferResult.failure(
        DataTransferErrorCode.targetWriteFailed,
      );
    }
  }

  Future<String?> _pickImportPath() async {
    try {
      return await filePicker.pickImportFile();
    } catch (_) {
      throw const DataTransferException(DataTransferErrorCode.pickerFailed);
    }
  }

  Future<String?> _pickExportPath() async {
    try {
      return await filePicker.pickExportFile();
    } catch (_) {
      throw const DataTransferException(DataTransferErrorCode.pickerFailed);
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    _queuedOperations += 1;
    if (_queuedOperations == 1) _busy.value = true;
    final next = _tail.then<T>((_) => operation());
    _tail = next.then<void>(
      (_) => _finishOperation(),
      onError: (Object error, StackTrace stackTrace) => _finishOperation(),
    );
    return next;
  }

  void _finishOperation() {
    _queuedOperations -= 1;
    if (_queuedOperations <= 0) {
      _queuedOperations = 0;
      _busy.value = false;
    }
  }

  void dispose() => _busy.dispose();
}

String _messageFor(DataTransferErrorCode code) {
  switch (code) {
    case DataTransferErrorCode.pickerFailed:
      return '文件选择器暂时不可用。';
    case DataTransferErrorCode.flushFailed:
      return '当前修改保存失败，导入或导出未开始。';
    case DataTransferErrorCode.sourceUnavailable:
      return '无法读取所选数据文件。';
    case DataTransferErrorCode.invalidUtf8:
      return '数据文件不是有效的 UTF-8。';
    case DataTransferErrorCode.invalidJson:
      return '数据文件不是有效的 JSON。';
    case DataTransferErrorCode.invalidRoot:
      return '数据文件根节点必须是对象。';
    case DataTransferErrorCode.missingSchemaVersion:
      return '数据文件缺少 schemaVersion。';
    case DataTransferErrorCode.unsupportedSchemaVersion:
      return '数据文件版本不受支持。';
    case DataTransferErrorCode.invalidData:
      return '数据文件结构无效。';
    case DataTransferErrorCode.invalidTarget:
      return '导出目标不可用。';
    case DataTransferErrorCode.targetWriteFailed:
      return '数据导入或导出未完成，原数据保持不变。';
    case DataTransferErrorCode.backupFailed:
      return '当前数据备份失败，导入未开始。';
    case DataTransferErrorCode.migrationBackupFailed:
      return '旧版本数据备份失败，导入未开始。';
  }
}
