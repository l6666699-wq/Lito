/// Theme choices deliberately do not depend on Flutter's [ThemeMode].
enum AppThemeMode { light, dark, system }

/// Window mode values persisted by the settings model.
enum AppWindowMode { full, compact, quickAdd }

/// Stable modifier names used by the settings file.  The platform layer maps
/// these values to the hotkey plugin's modifier enum.
enum AppHotkeyModifier { control, alt, shift, meta, capsLock, fn }

typedef SettingsThemeMode = AppThemeMode;
typedef SettingsWindowMode = AppWindowMode;
typedef DefaultWindowMode = AppWindowMode;

/// A persisted desktop window rectangle.  This model deliberately uses only
/// primitive values so settings can be loaded before Flutter's window plugin
/// is initialized (and so unit tests stay platform independent).
class AppWindowGeometry {
  const AppWindowGeometry({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  bool get isValid =>
      x.isFinite &&
      y.isFinite &&
      width.isFinite &&
      height.isFinite &&
      width > 0 &&
      height > 0;

  AppWindowGeometry copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
  }) {
    return AppWindowGeometry(
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  factory AppWindowGeometry.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('window geometry must be an object');
    }
    final map = Map<Object?, Object?>.from(value);
    final geometry = AppWindowGeometry(
      x: _readGeometryDouble(map['x'], 'x'),
      y: _readGeometryDouble(map['y'], 'y'),
      width: _readGeometryDouble(map['width'], 'width'),
      height: _readGeometryDouble(map['height'], 'height'),
    );
    if (!geometry.isValid) {
      throw const FormatException(
        'window geometry width and height must be positive',
      );
    }
    return geometry;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };

  @override
  bool operator ==(Object other) =>
      other is AppWindowGeometry &&
      other.x == x &&
      other.y == y &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(x, y, width, height);
}

/// A serializable global hotkey independent of Flutter keyboard classes.
class AppHotkeyConfig {
  AppHotkeyConfig({
    required Iterable<AppHotkeyModifier> modifiers,
    required String key,
  }) : modifiers = List.unmodifiable(_normalizeModifiers(modifiers)),
       key = _normalizeKey(key) {
    if (this.modifiers.isEmpty) {
      throw const FormatException(
        'globalHotkey must include at least one modifier',
      );
    }
    if (this.key.isEmpty) {
      throw const FormatException('globalHotkey.key must not be empty');
    }
  }

  const AppHotkeyConfig.defaultValue()
    : modifiers = const <AppHotkeyModifier>[
        AppHotkeyModifier.control,
        AppHotkeyModifier.alt,
      ],
      key = 'Space';

  final List<AppHotkeyModifier> modifiers;
  final String key;

  AppHotkeyConfig copyWith({
    Iterable<AppHotkeyModifier>? modifiers,
    String? key,
  }) {
    return AppHotkeyConfig(
      modifiers: modifiers ?? this.modifiers,
      key: key ?? this.key,
    );
  }

  String get displayString {
    final parts = <String>[...modifiers.map(_modifierLabel), key];
    return parts.join('+');
  }

  Map<String, dynamic> toJsonObject() => <String, dynamic>{
    'modifiers': modifiers.map((modifier) => modifier.name).toList(),
    'key': key,
  };

  /// Parses both the v1 object form and the legacy human-readable string.
  factory AppHotkeyConfig.fromJson(Object? value) {
    if (value is String) return AppHotkeyConfig.parse(value);
    if (value is Map) {
      final key = value['key'];
      final modifiers = value['modifiers'];
      if (key is! String || modifiers is! List) {
        throw const FormatException('globalHotkey must contain key/modifiers');
      }
      return AppHotkeyConfig(
        key: key,
        modifiers: modifiers.map((entry) => _modifierFromName(entry)),
      );
    }
    throw const FormatException('globalHotkey must be a string or object');
  }

  factory AppHotkeyConfig.parse(String value) {
    final pieces = value
        .split('+')
        .map((piece) => piece.trim())
        .where((piece) => piece.isNotEmpty)
        .toList(growable: false);
    if (pieces.length < 2) {
      throw const FormatException(
        'globalHotkey must include at least one modifier and a key',
      );
    }
    final modifiers = <AppHotkeyModifier>[];
    for (final piece in pieces.take(pieces.length - 1)) {
      final modifier = _modifierFromName(piece);
      if (modifiers.contains(modifier)) {
        throw const FormatException(
          'globalHotkey contains duplicate modifiers',
        );
      }
      modifiers.add(modifier);
    }
    return AppHotkeyConfig(modifiers: modifiers, key: pieces.last);
  }

  @override
  String toString() => displayString;

  @override
  bool operator ==(Object other) =>
      other is AppHotkeyConfig &&
      other.key == key &&
      _listEquals(other.modifiers, modifiers);

  @override
  int get hashCode => Object.hash(key, Object.hashAll(modifiers));
}

/// Alias used by platform/application code that refers to a generic hotkey.
typedef HotkeyConfig = AppHotkeyConfig;
typedef GlobalHotkeyConfig = AppHotkeyConfig;
typedef GlobalHotKeyConfig = AppHotkeyConfig;

/// Immutable settings persisted in `settings.json`.
class AppSettings {
  AppSettings({
    this.schemaVersion = currentSchemaVersion,
    this.revision = 0,
    this.themeMode = AppThemeMode.system,
    this.accentColorKey = defaultAccentColorKey,
    this.fontFamilyKey = defaultFontFamilyKey,
    this.fontScale = 1.0,
    this.defaultWindowMode = AppWindowMode.full,
    this.closeToTray = true,
    this.rememberWindowPosition = true,
    this.autoBackup = true,
    this.globalHotkeyEnabled = true,
    this.globalHotkey = const AppHotkeyConfig.defaultValue(),
    this.launchAtStartup = false,
    this.startHidden = true,
    this.compactAlwaysOnTop = true,
    this.compactSkipTaskbar = false,
    this.lockCompactPosition = false,
    this.fullGeometry,
    this.compactGeometry,
    this.lastProjectId,
  }) {
    _validateSchemaVersion(schemaVersion);
    _validateRevision(revision);
    _validateAccentColorKey(accentColorKey);
    _validateFontFamilyKey(fontFamilyKey);
    _validateFontScale(fontScale);
    if (fullGeometry != null && !fullGeometry!.isValid) {
      throw ArgumentError('fullGeometry is invalid');
    }
    if (compactGeometry != null && !compactGeometry!.isValid) {
      throw ArgumentError('compactGeometry is invalid');
    }
  }

  static const int currentSchemaVersion = 1;
  static const String defaultAccentColorKey = 'blue';
  static const String defaultFontFamilyKey = 'system';
  static const double minFontScale = 0.9;
  static const double maxFontScale = 1.15;

  static const Set<String> validAccentColorKeys = <String>{
    'red',
    'orange',
    'amber',
    'green',
    'teal',
    'cyan',
    'blue',
    'indigo',
    'violet',
    'purple',
    'pink',
    'gray',
  };

  static const Set<String> validFontFamilyKeys = <String>{
    'system',
    'segoeUi',
    'geist',
  };

  final int schemaVersion;
  final int revision;
  final AppThemeMode themeMode;
  final String accentColorKey;
  final String fontFamilyKey;
  final double fontScale;
  final AppWindowMode defaultWindowMode;
  final bool closeToTray;
  final bool rememberWindowPosition;
  final bool autoBackup;
  final bool globalHotkeyEnabled;
  final AppHotkeyConfig globalHotkey;
  final bool launchAtStartup;
  final bool startHidden;
  final bool compactAlwaysOnTop;
  final bool compactSkipTaskbar;
  final bool lockCompactPosition;
  final AppWindowGeometry? fullGeometry;
  final AppWindowGeometry? compactGeometry;
  final String? lastProjectId;

  AppSettings copyWith({
    int? schemaVersion,
    int? revision,
    AppThemeMode? themeMode,
    String? accentColorKey,
    String? fontFamilyKey,
    double? fontScale,
    AppWindowMode? defaultWindowMode,
    bool? closeToTray,
    bool? rememberWindowPosition,
    bool? autoBackup,
    bool? globalHotkeyEnabled,
    AppHotkeyConfig? globalHotkey,
    bool? launchAtStartup,
    bool? startHidden,
    bool? compactAlwaysOnTop,
    bool? compactSkipTaskbar,
    bool? lockCompactPosition,
    Object? fullGeometry = _appSettingsCopyWithSentinel,
    Object? compactGeometry = _appSettingsCopyWithSentinel,
    Object? lastProjectId = _appSettingsCopyWithSentinel,
  }) {
    return AppSettings(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      revision: revision ?? this.revision,
      themeMode: themeMode ?? this.themeMode,
      accentColorKey: accentColorKey ?? this.accentColorKey,
      fontFamilyKey: fontFamilyKey ?? this.fontFamilyKey,
      fontScale: fontScale ?? this.fontScale,
      defaultWindowMode: defaultWindowMode ?? this.defaultWindowMode,
      closeToTray: closeToTray ?? this.closeToTray,
      rememberWindowPosition:
          rememberWindowPosition ?? this.rememberWindowPosition,
      autoBackup: autoBackup ?? this.autoBackup,
      globalHotkeyEnabled: globalHotkeyEnabled ?? this.globalHotkeyEnabled,
      globalHotkey: globalHotkey ?? this.globalHotkey,
      launchAtStartup: launchAtStartup ?? this.launchAtStartup,
      startHidden: startHidden ?? this.startHidden,
      compactAlwaysOnTop: compactAlwaysOnTop ?? this.compactAlwaysOnTop,
      compactSkipTaskbar: compactSkipTaskbar ?? this.compactSkipTaskbar,
      lockCompactPosition: lockCompactPosition ?? this.lockCompactPosition,
      fullGeometry: identical(fullGeometry, _appSettingsCopyWithSentinel)
          ? this.fullGeometry
          : fullGeometry as AppWindowGeometry?,
      compactGeometry: identical(compactGeometry, _appSettingsCopyWithSentinel)
          ? this.compactGeometry
          : compactGeometry as AppWindowGeometry?,
      lastProjectId: identical(lastProjectId, _appSettingsCopyWithSentinel)
          ? this.lastProjectId
          : lastProjectId as String?,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final schemaVersion = _readInt(json['schemaVersion'], 'schemaVersion');
    if (schemaVersion != currentSchemaVersion) {
      throw FormatException(
        'Unsupported settings schemaVersion: $schemaVersion',
      );
    }
    final revision = _readInt(json['revision'], 'revision');
    if (revision < 0) {
      throw const FormatException('revision must be non-negative');
    }

    final themeMode = _enumFromName(
      json['themeMode'] ?? AppThemeMode.system.name,
      AppThemeMode.values,
      'themeMode',
    );
    final defaultWindowMode = _enumFromName(
      json['defaultWindowMode'] ??
          json['windowMode'] ??
          AppWindowMode.full.name,
      AppWindowMode.values,
      'defaultWindowMode',
    );
    final accentColorKey = _readString(
      json['accentColorKey'],
      'accentColorKey',
      defaultValue: defaultAccentColorKey,
    );
    final fontFamilyKey = _readString(
      json['fontFamilyKey'],
      'fontFamilyKey',
      defaultValue: defaultFontFamilyKey,
    );
    final fontScale = _readDouble(json['fontScale'], 'fontScale', 1.0);
    final globalHotkeyValue =
        json['globalHotkey'] ?? AppHotkeyConfig.defaultValue().displayString;
    return AppSettings(
      schemaVersion: schemaVersion,
      revision: revision,
      themeMode: themeMode,
      accentColorKey: accentColorKey,
      fontFamilyKey: fontFamilyKey,
      fontScale: fontScale,
      defaultWindowMode: defaultWindowMode,
      closeToTray: _readBool(json['closeToTray'], 'closeToTray', true),
      rememberWindowPosition: _readBool(
        json['rememberWindowPosition'],
        'rememberWindowPosition',
        true,
      ),
      autoBackup: _readBool(json['autoBackup'], 'autoBackup', true),
      globalHotkeyEnabled: _readBool(
        json['globalHotkeyEnabled'],
        'globalHotkeyEnabled',
        true,
      ),
      globalHotkey: AppHotkeyConfig.fromJson(globalHotkeyValue),
      launchAtStartup: _readBool(
        json['launchAtStartup'],
        'launchAtStartup',
        false,
      ),
      startHidden: _readBool(json['startHidden'], 'startHidden', true),
      compactAlwaysOnTop: _readBool(
        json['compactAlwaysOnTop'] ?? json['alwaysOnTop'],
        'compactAlwaysOnTop',
        true,
      ),
      compactSkipTaskbar: _readBool(
        json['compactSkipTaskbar'] ?? json['skipTaskbarInCompact'],
        'compactSkipTaskbar',
        false,
      ),
      lockCompactPosition: _readBool(
        json['lockCompactPosition'] ?? json['lockPosition'],
        'lockCompactPosition',
        false,
      ),
      fullGeometry: _readOptionalGeometry(json['fullGeometry'], 'fullGeometry'),
      compactGeometry: _readOptionalGeometry(
        json['compactGeometry'],
        'compactGeometry',
      ),
      lastProjectId: _readNullableString(
        json['lastProjectId'],
        'lastProjectId',
      ),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'revision': revision,
    'themeMode': themeMode.name,
    'accentColorKey': accentColorKey,
    'fontFamilyKey': fontFamilyKey,
    'fontScale': fontScale,
    'defaultWindowMode': defaultWindowMode.name,
    'closeToTray': closeToTray,
    'rememberWindowPosition': rememberWindowPosition,
    'autoBackup': autoBackup,
    'globalHotkeyEnabled': globalHotkeyEnabled,
    'globalHotkey': globalHotkey.displayString,
    'launchAtStartup': launchAtStartup,
    'startHidden': startHidden,
    'compactAlwaysOnTop': compactAlwaysOnTop,
    'compactSkipTaskbar': compactSkipTaskbar,
    'lockCompactPosition': lockCompactPosition,
    'fullGeometry': fullGeometry?.toJson(),
    'compactGeometry': compactGeometry?.toJson(),
    'lastProjectId': lastProjectId,
  };

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.schemaVersion == schemaVersion &&
      other.revision == revision &&
      other.themeMode == themeMode &&
      other.accentColorKey == accentColorKey &&
      other.fontFamilyKey == fontFamilyKey &&
      other.fontScale == fontScale &&
      other.defaultWindowMode == defaultWindowMode &&
      other.closeToTray == closeToTray &&
      other.rememberWindowPosition == rememberWindowPosition &&
      other.autoBackup == autoBackup &&
      other.globalHotkeyEnabled == globalHotkeyEnabled &&
      other.globalHotkey == globalHotkey &&
      other.launchAtStartup == launchAtStartup &&
      other.startHidden == startHidden &&
      other.compactAlwaysOnTop == compactAlwaysOnTop &&
      other.compactSkipTaskbar == compactSkipTaskbar &&
      other.lockCompactPosition == lockCompactPosition &&
      other.fullGeometry == fullGeometry &&
      other.compactGeometry == compactGeometry &&
      other.lastProjectId == lastProjectId;

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    revision,
    themeMode,
    accentColorKey,
    fontFamilyKey,
    fontScale,
    defaultWindowMode,
    closeToTray,
    rememberWindowPosition,
    autoBackup,
    globalHotkeyEnabled,
    globalHotkey,
    launchAtStartup,
    startHidden,
    compactAlwaysOnTop,
    compactSkipTaskbar,
    lockCompactPosition,
    fullGeometry,
    compactGeometry,
    lastProjectId,
  );
}

const Object _appSettingsCopyWithSentinel = Object();

AppWindowGeometry? _readOptionalGeometry(Object? value, String field) {
  if (value == null) return null;
  try {
    return AppWindowGeometry.fromJson(value);
  } on ArgumentError catch (error) {
    throw FormatException('$field is invalid: $error');
  }
}

double _readGeometryDouble(Object? value, String field) {
  if (value is num) {
    final number = value.toDouble();
    if (number.isFinite) return number;
  }
  throw FormatException('window geometry $field must be a finite number');
}

T _enumFromName<T extends Enum>(Object? value, List<T> values, String field) {
  if (value is! String) throw FormatException('$field must be a string');
  for (final item in values) {
    if (item.name == value) return item;
  }
  throw FormatException('Unsupported $field: $value');
}

int _readInt(Object? value, String field) {
  if (value is int) return value;
  if (value is num && value == value.toInt()) return value.toInt();
  throw FormatException('$field must be an integer');
}

String _readString(
  Object? value,
  String field, {
  required String defaultValue,
}) {
  if (value == null) return defaultValue;
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw FormatException('$field must be a non-empty string');
}

String? _readNullableString(Object? value, String field) {
  if (value == null) return null;
  if (value is String) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
  throw FormatException('$field must be a non-empty string or null');
}

double _readDouble(Object? value, String field, double defaultValue) {
  if (value == null) return defaultValue;
  if (value is num) return value.toDouble();
  throw FormatException('$field must be a number');
}

bool _readBool(Object? value, String field, bool defaultValue) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  throw FormatException('$field must be a boolean');
}

List<AppHotkeyModifier> _normalizeModifiers(
  Iterable<AppHotkeyModifier> modifiers,
) {
  final values = modifiers.toSet().toList();
  values.sort((a, b) => _modifierOrder(a).compareTo(_modifierOrder(b)));
  return values;
}

int _modifierOrder(AppHotkeyModifier modifier) =>
    AppHotkeyModifier.values.indexOf(modifier);

String _normalizeKey(String value) {
  final key = value.trim();
  if (key.isEmpty) return key;
  if (key.toLowerCase() == 'space') return 'Space';
  if (key.toLowerCase() == 'esc') return 'Escape';
  if (key.length == 1) return key.toUpperCase();
  return key[0].toUpperCase() + key.substring(1);
}

String _modifierLabel(AppHotkeyModifier modifier) {
  switch (modifier) {
    case AppHotkeyModifier.control:
      return 'Ctrl';
    case AppHotkeyModifier.alt:
      return 'Alt';
    case AppHotkeyModifier.shift:
      return 'Shift';
    case AppHotkeyModifier.meta:
      return 'Meta';
    case AppHotkeyModifier.capsLock:
      return 'CapsLock';
    case AppHotkeyModifier.fn:
      return 'Fn';
  }
}

AppHotkeyModifier _modifierFromName(Object? value) {
  if (value is! String) {
    throw const FormatException('hotkey modifier must be a string');
  }
  final normalized = value
      .replaceAll('-', '')
      .replaceAll('_', '')
      .toLowerCase();
  switch (normalized) {
    case 'ctrl':
    case 'control':
      return AppHotkeyModifier.control;
    case 'alt':
      return AppHotkeyModifier.alt;
    case 'shift':
      return AppHotkeyModifier.shift;
    case 'meta':
    case 'win':
    case 'windows':
    case 'command':
      return AppHotkeyModifier.meta;
    case 'capslock':
      return AppHotkeyModifier.capsLock;
    case 'fn':
      return AppHotkeyModifier.fn;
    default:
      throw FormatException('Unsupported hotkey modifier: $value');
  }
}

void _validateSchemaVersion(int value) {
  if (value != AppSettings.currentSchemaVersion) {
    throw StateError('Unsupported settings schemaVersion: $value');
  }
}

void _validateRevision(int value) {
  if (value < 0) throw StateError('revision must be non-negative');
}

void _validateAccentColorKey(String value) {
  if (!AppSettings.validAccentColorKeys.contains(value)) {
    throw ArgumentError.value(value, 'accentColorKey');
  }
}

void _validateFontFamilyKey(String value) {
  if (!AppSettings.validFontFamilyKeys.contains(value)) {
    throw ArgumentError.value(value, 'fontFamilyKey');
  }
}

void _validateFontScale(double value) {
  if (!value.isFinite ||
      value < AppSettings.minFontScale ||
      value > AppSettings.maxFontScale) {
    throw ArgumentError.value(value, 'fontScale');
  }
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
