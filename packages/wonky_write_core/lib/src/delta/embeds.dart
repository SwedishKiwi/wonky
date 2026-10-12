/// Block embed models of the Wonky Delta Schema v1
/// (specs/wonky_write/02-document-model.md §1.3).
library;

import 'package:collection/collection.dart';

/// Column alignment of a table embed.
enum CellAlign {
  /// Left aligned (`:---`).
  left('left'),

  /// Centered (`:---:`).
  center('center'),

  /// Right aligned (`---:`).
  right('right');

  const CellAlign(this.value);

  /// JSON value.
  final String value;

  /// Parses a JSON value; `null` for "default" or unknown values.
  static CellAlign? tryParse(Object? value) =>
      CellAlign.values.firstWhereOrNull((a) => a.value == value);
}

/// A block embed: the `insert` value of an embed op is `{<type>: <data>}`.
///
/// Embeds are always on their own line (preceded by `"\n"` or the document
/// start and followed by a plain `"\n"`) and have a stable [id] (UUIDv7).
sealed class WonkyEmbed {
  const WonkyEmbed();

  /// Embed type key (`image`, `divider`, `table`).
  String get type;

  /// Stable embed id.
  String get id;

  /// The embed payload (value under [type]).
  Map<String, dynamic> toData();

  /// The full `insert` value (`{type: data}`).
  Map<String, dynamic> toInsert() => {type: toData()};

  /// Known embed type keys.
  static const types = {
    ImageEmbed.typeKey,
    DividerEmbed.typeKey,
    TableEmbed.typeKey,
  };

  /// Parses an `insert` value. Returns `null` when [insert] is not a valid
  /// embed of a known type.
  static WonkyEmbed? tryParse(Object? insert) {
    if (insert is! Map || insert.length != 1) return null;
    final type = insert.keys.first;
    final data = insert.values.first;
    if (data is! Map) return null;
    return switch (type) {
      ImageEmbed.typeKey => ImageEmbed.tryParse(data),
      DividerEmbed.typeKey => DividerEmbed.tryParse(data),
      TableEmbed.typeKey => TableEmbed.tryParse(data),
      _ => null,
    };
  }

  /// The embed type key of an `insert` value, or `null` if it is not a map.
  static String? typeOf(Object? insert) =>
      insert is Map && insert.length == 1 ? '${insert.keys.first}' : null;

  /// The embed id of an `insert` value (valid or not), or `null`.
  static String? idOf(Object? insert) {
    if (insert is! Map || insert.length != 1) return null;
    final data = insert.values.first;
    if (data is! Map) return null;
    final id = data['id'];
    return id is String ? id : null;
  }
}

/// An image: `{"image": {"id", "src", "alt", "title"?}}`.
///
/// `src` is `wonky-file://<fileUuid>` (uploaded), an `https://` (or `http://`)
/// URL, or `import-image://<tempId>` while an import is being post-processed.
final class ImageEmbed extends WonkyEmbed {
  /// Creates an image embed.
  const ImageEmbed({
    required this.id,
    required this.src,
    this.alt = '',
    this.title,
  });

  /// Type key.
  static const typeKey = 'image';

  @override
  String get type => typeKey;

  @override
  final String id;

  /// Image source.
  final String src;

  /// Alternative text (single line).
  final String alt;

  /// Optional title (used as caption).
  final String? title;

  /// Parses the embed payload; `null` when invalid.
  static ImageEmbed? tryParse(Map<dynamic, dynamic> data) {
    final id = data['id'];
    final src = data['src'];
    final alt = data['alt'] ?? '';
    final title = data['title'];
    if (id is! String || id.isEmpty || src is! String || alt is! String) {
      return null;
    }
    if (title != null && title is! String) return null;
    return ImageEmbed(id: id, src: src, alt: alt, title: title as String?);
  }

  /// `wonky-file://` scheme prefix.
  static const wonkyFileScheme = 'wonky-file://';

  /// Temporary import scheme prefix (see 07 §2.2).
  static const importImageScheme = 'import-image://';

  /// The file UUID for a `wonky-file://` source, else `null`.
  String? get fileUuid => src.startsWith(wonkyFileScheme)
      ? src.substring(wonkyFileScheme.length)
      : null;

  @override
  Map<String, dynamic> toData() => {
    'id': id,
    'src': src,
    'alt': alt,
    if (title != null) 'title': title,
  };

  /// Copy with changed fields.
  ImageEmbed copyWith({String? id, String? src, String? alt, String? title}) =>
      ImageEmbed(
        id: id ?? this.id,
        src: src ?? this.src,
        alt: alt ?? this.alt,
        title: title ?? this.title,
      );

  @override
  bool operator ==(Object other) =>
      other is ImageEmbed &&
      other.id == id &&
      other.src == src &&
      other.alt == alt &&
      other.title == title;

  @override
  int get hashCode => Object.hash(id, src, alt, title);

  @override
  String toString() => 'ImageEmbed(${toData()})';
}

/// A horizontal rule: `{"divider": {"id"}}`.
final class DividerEmbed extends WonkyEmbed {
  /// Creates a divider embed.
  const DividerEmbed({required this.id});

  /// Type key.
  static const typeKey = 'divider';

  @override
  String get type => typeKey;

  @override
  final String id;

  /// Parses the embed payload; `null` when invalid.
  static DividerEmbed? tryParse(Map<dynamic, dynamic> data) {
    final id = data['id'];
    if (id is! String || id.isEmpty) return null;
    return DividerEmbed(id: id);
  }

  @override
  Map<String, dynamic> toData() => {'id': id};

  @override
  bool operator ==(Object other) => other is DividerEmbed && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'DividerEmbed($id)';
}

/// A GFM table: `{"table": {"id", "align": [..], "rows": [[cellMarkdown]]}}`.
///
/// Row 0 is the header row; cells are **inline Markdown** strings.
final class TableEmbed extends WonkyEmbed {
  /// Creates a table embed.
  const TableEmbed({required this.id, required this.align, required this.rows});

  /// Type key.
  static const typeKey = 'table';

  @override
  String get type => typeKey;

  @override
  final String id;

  /// Per-column alignment (`null` = default).
  final List<CellAlign?> align;

  /// Rows of inline-Markdown cells; row 0 is the header.
  final List<List<String>> rows;

  /// Number of columns (widest row).
  int get columnCount =>
      rows.fold(align.length, (m, r) => r.length > m ? r.length : m);

  /// Parses the embed payload; `null` when invalid.
  static TableEmbed? tryParse(Map<dynamic, dynamic> data) {
    final id = data['id'];
    final rawRows = data['rows'];
    final rawAlign = data['align'] ?? const <Object?>[];
    if (id is! String || id.isEmpty || rawRows is! List || rawAlign is! List) {
      return null;
    }
    final rows = <List<String>>[];
    for (final row in rawRows) {
      if (row is! List) return null;
      final cells = <String>[];
      for (final cell in row) {
        if (cell is! String) return null;
        cells.add(cell);
      }
      rows.add(cells);
    }
    if (rows.isEmpty) return null;
    final align = <CellAlign?>[];
    for (final a in rawAlign) {
      if (a != null && CellAlign.tryParse(a) == null) return null;
      align.add(CellAlign.tryParse(a));
    }
    return TableEmbed(id: id, align: align, rows: rows);
  }

  @override
  Map<String, dynamic> toData() => {
    'id': id,
    'align': [for (final a in align) a?.value],
    'rows': [
      for (final r in rows) [...r],
    ],
  };

  /// Copy with changed fields.
  TableEmbed copyWith({
    String? id,
    List<CellAlign?>? align,
    List<List<String>>? rows,
  }) => TableEmbed(
    id: id ?? this.id,
    align: align ?? this.align,
    rows: rows ?? this.rows,
  );

  /// A rectangular copy: all rows padded with `""` to [columnCount] and
  /// [align] sized to [columnCount].
  TableEmbed padded() {
    final n = columnCount;
    return TableEmbed(
      id: id,
      align: [for (var i = 0; i < n; i++) i < align.length ? align[i] : null],
      rows: [
        for (final r in rows) [...r, for (var i = r.length; i < n; i++) ''],
      ],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TableEmbed &&
      other.id == id &&
      const ListEquality<CellAlign?>().equals(other.align, align) &&
      const DeepCollectionEquality().equals(other.rows, rows);

  @override
  int get hashCode => Object.hash(
    id,
    const ListEquality<CellAlign?>().hash(align),
    const DeepCollectionEquality().hash(rows),
  );

  @override
  String toString() => 'TableEmbed(${toData()})';
}
