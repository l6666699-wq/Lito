import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/infrastructure/logging/app_log_service.dart';

void main() {
  Directory createTestDirectory(String name) {
    return Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}litetodo-$name-${DateTime.now().microsecondsSinceEpoch}',
    );
  }

  Future<void> closeAndDelete(AppLogService service) async {
    final directory = service.dataDirectory;
    await service.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  test('rotates at the byte boundary and keeps only two files', () async {
    final directory = createTestDirectory('log-rotation');
    final service = AppLogService(
      directory: directory,
      maxFileBytes: 256,
      maxRotatedFiles: 2,
    );
    addTearDown(() => closeAndDelete(service));

    await service.initialize();
    for (var index = 0; index < 20; index += 1) {
      await service.logEvent(
        'rotation.event',
        metadata: <String, Object?>{'count': index},
      );
    }
    await service.flush();

    expect(await service.logFile.length(), lessThanOrEqualTo(256));
    expect(await service.rotatedFile(1).exists(), isTrue);
    expect(await service.rotatedFile(2).exists(), isTrue);
    expect(await service.rotatedFile(3).exists(), isFalse);
    expect(AppLogService.defaultMaxFileBytes, 2 * 1024 * 1024);
  });

  test(
    'serializes concurrent writes in call order and appends after restart',
    () async {
      final directory = createTestDirectory('log-order');
      final first = AppLogService(
        directory: directory,
        maxFileBytes: 64 * 1024,
      );
      addTearDown(() => closeAndDelete(first));

      await Future.wait([
        for (var index = 0; index < 40; index += 1)
          first.logEvent(
            'concurrent.event',
            metadata: <String, Object?>{'count': index},
          ),
      ]);
      await first.close();

      final second = AppLogService(
        directory: directory,
        maxFileBytes: 64 * 1024,
      );
      addTearDown(() => closeAndDelete(second));
      await second.logEvent(
        'restart.event',
        metadata: const <String, Object?>{'count': 40},
      );
      final content = await second.logFile.readAsString(encoding: utf8);
      final counts = RegExp(r'count=(\d+)')
          .allMatches(content)
          .map((match) => int.parse(match.group(1)!))
          .toList(growable: false);

      expect(counts, <int>[...List<int>.generate(40, (index) => index), 40]);
      expect(content, contains('restart.event'));
      expect(() => utf8.decode(utf8.encode(content)), returnsNormally);
    },
  );

  test('close flushes events queued immediately before it', () async {
    final directory = createTestDirectory('log-close');
    final service = AppLogService(directory: directory);
    addTearDown(() => closeAndDelete(service));

    final writes = <Future<void>>[
      for (var index = 0; index < 12; index += 1)
        service.logEvent(
          'close.event',
          metadata: <String, Object?>{'count': index},
        ),
    ];
    await service.close();
    await Future.wait(writes);
    final content = await service.logFile.readAsString(encoding: utf8);
    expect(RegExp(r'code=close\.event').allMatches(content), hasLength(12));
  });

  test('filters error details and does not persist Todo text', () async {
    final directory = createTestDirectory('log-sensitive');
    final service = AppLogService(directory: directory);
    addTearDown(() => closeAndDelete(service));

    await service.logError(
      code: 'todo.failure',
      error: StateError('Todo secret title must not be logged'),
      stackTrace: StackTrace.fromString('Todo secret title must not be logged'),
      metadata: const <String, Object?>{
        'title': 'Todo secret title must not be logged',
        'source': 'workspace',
      },
    );
    final content = await service.logFile.readAsString(encoding: utf8);

    expect(content, contains('errorType=StateError'));
    expect(content, contains('source=workspace'));
    expect(content, isNot(contains('Todo secret title')));
    expect(content, isNot(contains('must not be logged')));
  });

  test(
    'global handlers chain and restore without swallowing platform errors',
    () async {
      final directory = createTestDirectory('log-handlers');
      final service = AppLogService(directory: directory);
      addTearDown(() => closeAndDelete(service));

      final originalFlutterHandler = FlutterError.onError;
      final originalPlatformHandler = PlatformDispatcher.instance.onError;
      var flutterForwarded = 0;
      var platformForwarded = 0;
      void forwardedFlutterHandler(FlutterErrorDetails _) {
        flutterForwarded += 1;
      }

      bool forwardedPlatformHandler(Object _, StackTrace _) {
        platformForwarded += 1;
        return false;
      }

      FlutterError.onError = forwardedFlutterHandler;
      PlatformDispatcher.instance.onError = forwardedPlatformHandler;
      addTearDown(() {
        FlutterError.onError = originalFlutterHandler;
        PlatformDispatcher.instance.onError = originalPlatformHandler;
      });

      final binding = service.installGlobalErrorHandlers();
      FlutterError.onError!(
        FlutterErrorDetails(
          exception: StateError('Todo title handler failure'),
          stack: StackTrace.current,
        ),
      );
      final handled = PlatformDispatcher.instance.onError!(
        StateError('Todo title platform failure'),
        StackTrace.current,
      );
      await service.flush();

      expect(handled, isTrue);
      expect(flutterForwarded, 1);
      expect(platformForwarded, 1);
      final content = await service.logFile.readAsString(encoding: utf8);
      expect(content, contains('flutter.error'));
      expect(content, contains('platform.error'));
      expect(content, isNot(contains('Todo title')));

      binding.restore();
      expect(FlutterError.onError, same(forwardedFlutterHandler));
      expect(
        PlatformDispatcher.instance.onError,
        same(forwardedPlatformHandler),
      );
      expect(binding.isRestored, isTrue);
    },
  );

  test('initialization and write failures are non-blocking', () async {
    final parent = createTestDirectory('log-failure');
    await parent.create(recursive: true);
    final blocker = File(
      '${parent.path}${Platform.pathSeparator}not-a-directory',
    );
    await blocker.writeAsString('occupied', flush: true);
    final service = AppLogService(directory: Directory(blocker.path));
    addTearDown(() async {
      await service.close();
      if (await parent.exists()) await parent.delete(recursive: true);
    });

    await expectLater(service.initialize(), completes);
    await expectLater(service.logEvent('write.failure'), completes);
    expect(service.isDisabled, isTrue);
  });
}
