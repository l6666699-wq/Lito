import '../../domain/models/app_data.dart';

/// Application-facing persistence port.  The application layer only knows
/// about immutable snapshots and never imports dart:io or path_provider.
abstract interface class AppDataRepository {
  Future<AppDataLoadResult> load();

  Future<void> save(AppData snapshot);
}

enum AppDataLoadSource { primary, previous, empty }

/// Result of startup recovery.  A warning is intentionally data rather than a
/// UI concern so callers can expose it as a non-blocking notification.
class AppDataLoadResult {
  const AppDataLoadResult({
    required this.data,
    required this.source,
    this.recoveryWarning,
  });

  final AppData data;
  final AppDataLoadSource source;
  final String? recoveryWarning;

  String? get warning => recoveryWarning;
  bool get recovered => source == AppDataLoadSource.previous;
  bool get isInitial => source == AppDataLoadSource.empty;
}
