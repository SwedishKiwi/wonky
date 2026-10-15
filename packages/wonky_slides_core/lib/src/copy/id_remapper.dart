import 'dart:convert';

import 'package:wonky_sync_models/ids.dart';

/// A file reference to copy into the target item (02 §9.3, 03 §12.3):
/// `wonky-file://<sourceFileUuid>` becomes `wonky-file://<newFileUuid>` in
/// the copied rows, and the server copies the stored file
/// (`FileEndpoint.copyToItem(sourceFileUuid, newFileUuid, targetItemUuid)`,
/// idempotent on [newFileUuid], quota-checked).
final class FileRehome {
  /// Creates a re-homing entry.
  const FileRehome(this.sourceFileUuid, this.newFileUuid);

  /// The uploaded file the source references.
  final String sourceFileUuid;

  /// The uuid of the copy (already written into the copied rows).
  final String newFileUuid;

  /// JSON form.
  Map<String, Object?> toJson() => {
    'sourceFileUuid': sourceFileUuid,
    'newFileUuid': newFileUuid,
  };

  @override
  bool operator ==(Object other) =>
      other is FileRehome &&
      other.sourceFileUuid == sourceFileUuid &&
      other.newFileUuid == newFileUuid;

  @override
  int get hashCode => Object.hash(sourceFileUuid, newFileUuid);

  @override
  String toString() => 'FileRehome($sourceFileUuid → $newFileUuid)';
}

/// Rewrites ids inside copied Slides rows (02 §9.3): row ids in the
/// dashed form (columns, JSON values) and the 22-char base-62 form (JSON
/// values, `slide:<b62>` text links, match keys), and uploaded files
/// (`wonky-file://<uuid>`, `fileUuid` keys). Values not in the maps stay as
/// they are; JSON is walked structurally, so only whole string values
/// match (text content never changes).
final class SlidesIdRemapper {
  /// Creates a remapper over [ids] (old → new row ids, dashed lower case)
  /// and [files] (old → new file uuids).
  SlidesIdRemapper(this.ids, {Map<String, String>? files})
    : files = files ?? {};

  /// Old → new row ids.
  final Map<String, String> ids;

  /// Old → new file uuids.
  final Map<String, String> files;

  Map<String, String>? _b62;

  /// Old → new ids in the base-62 form.
  Map<String, String> get base62 => _b62 ??= {
    for (final e in ids.entries)
      Base62Uuid.encode(e.key): Base62Uuid.encode(e.value),
  };

  /// Prefix of uploaded-file references.
  static const filePrefix = 'wonky-file://';

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{12}$',
  );

  /// Whether [s] is a dashed UUID.
  static bool isUuid(String s) => _uuid.hasMatch(s);

  /// The new id of [id] (dashed), or [id] when not mapped.
  String id(String id) => ids[id.toLowerCase()] ?? id;

  /// The new id of [id], or null when [id] is null or not mapped (a
  /// reference that leaves the copy).
  String? mapped(Object? id) => id == null ? null : ids['$id'.toLowerCase()];

  /// A string value: a mapped dashed or base-62 id, a mapped `slide:<b62>`
  /// link or a mapped `wonky-file://` reference.
  String string(String s) {
    if (s.length == 36) {
      final m = ids[s.toLowerCase()] ?? files[s.toLowerCase()];
      if (m != null) return m;
    }
    if (s.length == 22) {
      final m = base62[s];
      if (m != null) return m;
    }
    if (s.startsWith('slide:') && s.length == 28) {
      final m = base62[s.substring(6)];
      if (m != null) return 'slide:$m';
    }
    if (s.startsWith(filePrefix)) {
      final f = files[s.substring(filePrefix.length).toLowerCase()];
      if (f != null) return '$filePrefix$f';
    }
    return s;
  }

  /// A decoded JSON value with every string remapped.
  Object? value(Object? v) => switch (v) {
    final String s => string(s),
    final List<Object?> l => [for (final x in l) value(x)],
    final Map<Object?, Object?> m => {
      for (final e in m.entries) '${e.key}': value(e.value),
    },
    _ => v,
  };

  /// A JSON column remapped (invalid JSON is returned unchanged).
  String? json(String? json) {
    if (json == null || (ids.isEmpty && files.isEmpty)) return json;
    try {
      return jsonEncode(value(jsonDecode(json)));
    } on FormatException {
      return json;
    }
  }

  /// A Delta text body with its attribute values remapped (slide links);
  /// inserted text is never touched.
  String? text(String? json) {
    if (json == null || ids.isEmpty) return json;
    try {
      final ops = jsonDecode(json);
      if (ops is! List) return json;
      return jsonEncode([
        for (final op in ops)
          if (op is Map && op['attributes'] is Map)
            {...op, 'attributes': value(op['attributes'])}
          else
            op,
      ]);
    } on FormatException {
      return json;
    }
  }

  /// The uploaded files a JSON column references: `wonky-file://<uuid>`
  /// strings and `fileUuid` values, lower case.
  static Set<String> fileRefs(String? json) {
    final out = <String>{};
    if (json == null ||
        !(json.contains(filePrefix) || json.contains('fileUuid'))) {
      return out;
    }
    void walk(Object? v, [String? key]) {
      switch (v) {
        case final String s:
          if (s.startsWith(filePrefix)) {
            final id = s.substring(filePrefix.length);
            if (isUuid(id)) out.add(id.toLowerCase());
          } else if (key == 'fileUuid' && isUuid(s)) {
            out.add(s.toLowerCase());
          }
        case final List<Object?> l:
          for (final x in l) {
            walk(x);
          }
        case final Map<Object?, Object?> m:
          for (final e in m.entries) {
            walk(e.value, '${e.key}');
          }
      }
    }

    try {
      walk(jsonDecode(json));
    } on FormatException {
      // Not JSON: no references.
    }
    return out;
  }
}
