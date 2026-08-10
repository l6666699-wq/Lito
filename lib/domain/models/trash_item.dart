/// A typed entry in the local recycle bin.
///
/// Payload is a recursively frozen JSON-compatible map so recovery cannot be
/// affected by a caller mutating the source list after deletion.
class TrashItem {
  TrashItem({
    required this.id,
    required this.kind,
    required Map<String, dynamic> payload,
  }) : payload = _freezeJsonMap(payload);

  final String id;
  final String kind;
  final Map<String, dynamic> payload;

  factory TrashItem.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['payload'];
    final payload = rawPayload is Map
        ? Map<String, dynamic>.from(rawPayload)
        : <String, dynamic>{};
    return TrashItem(
      id: json['id'] as String? ?? '',
      kind: json['kind'] as String? ?? 'todo',
      payload: payload,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'id': id, 'kind': kind, 'payload': payload};
  }

  @override
  bool operator ==(Object other) {
    if (other is! TrashItem ||
        other.id != id ||
        other.kind != kind ||
        !_deepJsonEquals(other.payload, payload)) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(id, kind, _deepJsonHash(payload));
}

Map<String, dynamic> _freezeJsonMap(Map<String, dynamic> source) {
  return Map.unmodifiable(<String, dynamic>{
    for (final entry in source.entries)
      entry.key: _freezeJsonValue(entry.value),
  });
}

Object? _freezeJsonValue(Object? value) {
  if (value is Map) {
    return _freezeJsonMap(<String, dynamic>{
      for (final entry in value.entries) '${entry.key}': entry.value,
    });
  }
  if (value is List) {
    return List.unmodifiable(value.map(_freezeJsonValue));
  }
  return value;
}

bool _deepJsonEquals(Object? left, Object? right) {
  if (identical(left, right)) return true;
  if (left is Map && right is Map) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key) ||
          !_deepJsonEquals(entry.value, right[entry.key])) {
        return false;
      }
    }
    return true;
  }
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (!_deepJsonEquals(left[i], right[i])) return false;
    }
    return true;
  }
  return left == right;
}

int _deepJsonHash(Object? value) {
  if (value is Map) {
    final entries = value.entries.toList()
      ..sort((a, b) => '${a.key}'.compareTo('${b.key}'));
    return Object.hashAll(<Object?>[
      for (final entry in entries)
        Object.hash(entry.key, _deepJsonHash(entry.value)),
    ]);
  }
  if (value is List) {
    return Object.hashAll(value.map(_deepJsonHash));
  }
  return value.hashCode;
}
