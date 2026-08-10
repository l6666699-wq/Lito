import '../../domain/models/app_settings.dart';

/// Application-facing settings persistence port.
abstract interface class SettingsRepository {
  Future<AppSettingsLoadResult> load();

  /// Queues a snapshot for debounced persistence.
  Future<void> save(AppSettings snapshot);

  /// Persists the latest queued snapshot immediately.
  Future<void> flushNow();
}

enum AppSettingsLoadSource { primary, previous, defaults }

typedef SettingsLoadSource = AppSettingsLoadSource;

class AppSettingsLoadResult {
  const AppSettingsLoadResult({
    required this.settings,
    required this.source,
    this.recoveryWarning,
  });

  final AppSettings settings;
  final SettingsLoadSource source;
  final String? recoveryWarning;

  bool get recovered => source == SettingsLoadSource.previous;
  bool get isInitial => source == SettingsLoadSource.defaults;
  String? get warning => recoveryWarning;
}
