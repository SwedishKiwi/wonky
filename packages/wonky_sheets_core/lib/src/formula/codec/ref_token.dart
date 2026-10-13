import '../../addressing/base62_uuid.dart';

/// One stored reference token `⟦S:…;R:…;C:…;$R;$C;K:…;KC:…;X:…⟧` (02 §2, 05 §3.4).
///
/// Ids are model ids (canonical UUID strings, or opaque ids in tests); [encode] writes UUIDs in
/// the 22-char base-62 form.
final class RefToken {
  static const String open = '⟦';
  static const String close = '⟧';
  static const int openCode = 0x27e6;
  static const int closeCode = 0x27e7;

  final String? sheetId;
  final String? rowId;
  final String? colId;
  final bool absRow;
  final bool absCol;

  /// Row sortKey at encode time (range endpoints only, §5.4).
  final String? rowKey;

  /// Column sortKey at encode time (range endpoints only).
  final String? colKey;

  /// Unbound A1 text (§5.3).
  final String? unbound;

  const RefToken({
    this.sheetId,
    this.rowId,
    this.colId,
    this.absRow = false,
    this.absCol = false,
    this.rowKey,
    this.colKey,
    this.unbound,
  });

  bool get hasRow => rowId != null;
  bool get hasCol => colId != null;
  bool get isUnbound => unbound != null;

  RefToken copyWith({
    Object? sheetId = _keep,
    Object? rowId = _keep,
    Object? colId = _keep,
    bool? absRow,
    bool? absCol,
    Object? rowKey = _keep,
    Object? colKey = _keep,
    Object? unbound = _keep,
  }) => RefToken(
    sheetId: identical(sheetId, _keep) ? this.sheetId : sheetId as String?,
    rowId: identical(rowId, _keep) ? this.rowId : rowId as String?,
    colId: identical(colId, _keep) ? this.colId : colId as String?,
    absRow: absRow ?? this.absRow,
    absCol: absCol ?? this.absCol,
    rowKey: identical(rowKey, _keep) ? this.rowKey : rowKey as String?,
    colKey: identical(colKey, _keep) ? this.colKey : colKey as String?,
    unbound: identical(unbound, _keep) ? this.unbound : unbound as String?,
  );

  static const Object _keep = Object();

  /// `⟦…⟧` text.
  String encode() {
    final b = StringBuffer(open);
    var first = true;
    void field(String f) {
      if (!first) b.write(';');
      b.write(f);
      first = false;
    }

    if (sheetId != null) field('S:${Base62Uuid.toToken(sheetId!)}');
    if (rowId != null) field('R:${Base62Uuid.toToken(rowId!)}');
    if (colId != null) field('C:${Base62Uuid.toToken(colId!)}');
    if (absRow) field(r'$R');
    if (absCol) field(r'$C');
    if (rowKey != null) field('K:$rowKey');
    if (colKey != null) field('KC:$colKey');
    if (unbound != null) field('X:${_escape(unbound!)}');
    b.write(close);
    return b.toString();
  }

  static String _escape(String s) => s
      .replaceAll('%', '%25')
      .replaceAll(';', '%3B')
      .replaceAll(close, '%E2%9F%A7');

  static String _unescape(String s) =>
      s.contains('%') ? Uri.decodeComponent(s) : s;

  /// Decodes the inside of a token (without the brackets). Returns null when malformed.
  static RefToken? decodeBody(String body) {
    String? s, r, c, k, kc, x;
    var ar = false, ac = false;
    if (body.isEmpty) return null;
    for (final f in body.split(';')) {
      if (f.startsWith('S:')) {
        s = Base62Uuid.fromToken(f.substring(2));
      } else if (f.startsWith('R:')) {
        r = Base62Uuid.fromToken(f.substring(2));
      } else if (f.startsWith('C:')) {
        c = Base62Uuid.fromToken(f.substring(2));
      } else if (f == r'$R') {
        ar = true;
      } else if (f == r'$C') {
        ac = true;
      } else if (f.startsWith('KC:')) {
        kc = f.substring(3);
      } else if (f.startsWith('K:')) {
        k = f.substring(2);
      } else if (f.startsWith('X:')) {
        x = _unescape(f.substring(2));
      } else {
        return null;
      }
    }
    if (r == null && c == null && x == null) return null;
    return RefToken(
      sheetId: s,
      rowId: r,
      colId: c,
      absRow: ar,
      absCol: ac,
      rowKey: k,
      colKey: kc,
      unbound: x,
    );
  }

  /// Decodes a full `⟦…⟧` token.
  static RefToken? decode(String text) {
    if (text.length < 2 ||
        text.codeUnitAt(0) != openCode ||
        text.codeUnitAt(text.length - 1) != closeCode) {
      return null;
    }
    return decodeBody(text.substring(1, text.length - 1));
  }

  @override
  bool operator ==(Object other) =>
      other is RefToken &&
      other.sheetId == sheetId &&
      other.rowId == rowId &&
      other.colId == colId &&
      other.absRow == absRow &&
      other.absCol == absCol &&
      other.rowKey == rowKey &&
      other.colKey == colKey &&
      other.unbound == unbound;

  @override
  int get hashCode => Object.hash(
    sheetId,
    rowId,
    colId,
    absRow,
    absCol,
    rowKey,
    colKey,
    unbound,
  );

  @override
  String toString() => encode();
}

/// Shape of an id-based reference.
enum StoredRefKind {
  cell,
  rect,
  columns,
  rows,
  openRows,
  openColumns,
  unbound,
  invalid,
}

/// A stored reference: one token (cell / unbound) or a range `⟦a⟧:⟦b⟧`.
final class StoredRef {
  final RefToken start;
  final RefToken? end;
  const StoredRef(this.start, [this.end]);

  String? get sheetId => start.sheetId;

  StoredRefKind get kind {
    if (start.isUnbound) return StoredRefKind.unbound;
    final e = end;
    if (e == null) {
      return start.hasRow && start.hasCol
          ? StoredRefKind.cell
          : StoredRefKind.invalid;
    }
    if (start.hasRow && start.hasCol) {
      if (e.hasRow && e.hasCol) return StoredRefKind.rect;
      if (e.hasCol) return StoredRefKind.openRows;
      if (e.hasRow) return StoredRefKind.openColumns;
      return StoredRefKind.invalid;
    }
    if (start.hasCol && !start.hasRow && e.hasCol && !e.hasRow) {
      return StoredRefKind.columns;
    }
    if (start.hasRow && !start.hasCol && e.hasRow && !e.hasCol) {
      return StoredRefKind.rows;
    }
    return StoredRefKind.invalid;
  }

  String encode() =>
      end == null ? start.encode() : '${start.encode()}:${end!.encode()}';

  /// Parses `⟦…⟧` or `⟦…⟧:⟦…⟧` (complete text).
  static StoredRef? parse(String text) {
    final close = text.indexOf(RefToken.close);
    if (close < 0) return null;
    final a = RefToken.decode(text.substring(0, close + 1));
    if (a == null) return null;
    if (close + 1 == text.length) return StoredRef(a);
    if (text.codeUnitAt(close + 1) != 0x3a) return null;
    final b = RefToken.decode(text.substring(close + 2));
    if (b == null) return null;
    return StoredRef(a, b);
  }

  @override
  bool operator ==(Object other) =>
      other is StoredRef && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => encode();
}
