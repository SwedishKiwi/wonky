import '../model/events.dart';
import '../model/grid_range.dart';
import '../model/schema.dart';
import '../model/sheet_model.dart';
import '../model/workbook_model.dart';
import 'attributes.dart';
import 'banding.dart';
import 'borders.dart';
import 'theme.dart';

/// Number format of cells without an explicit format.
const String kAutomaticNumberFormat = 'preset:automatic';

/// Fully resolved display format of one cell (06 §1.2).
final class ResolvedFormat {
  /// Creates a resolved format.
  const ResolvedFormat({
    this.numberFormat = kAutomaticNumberFormat,
    this.fontFamily = 'Inter',
    this.fontSize = 10,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
    this.textColor,
    this.fillColor,
    this.hAlign,
    this.vAlign = VerticalAlign.bottom,
    this.wrap = WrapStrategy.overflow,
    this.rotation = 0,
    this.borderTop,
    this.borderRight,
    this.borderBottom,
    this.borderLeft,
    this.linkUrl,
    this.numberFormatExplicit = false,
  });

  /// Pattern or `preset:*` id.
  final String numberFormat;
  final String fontFamily;
  final double fontSize;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;

  /// Text color string (`#RRGGBB`/`theme:*`); null = automatic.
  final String? textColor;

  /// Fill color string; null = none.
  final String? fillColor;

  /// Horizontal alignment; null = general (06 §9.1).
  final HorizontalAlign? hAlign;
  final VerticalAlign vAlign;
  final WrapStrategy wrap;

  /// −90…90, 255 = stacked.
  final int rotation;

  /// The cell's own edges (shared-edge conflicts: [EffectiveFormatResolver.edge]).
  final BorderSpec? borderTop;
  final BorderSpec? borderRight;
  final BorderSpec? borderBottom;
  final BorderSpec? borderLeft;
  final String? linkUrl;

  /// Whether the number format was set explicitly (cell/row/column/sheet), as
  /// opposed to Automatic (formula format hints apply only when not explicit).
  final bool numberFormatExplicit;

  /// Whether the number format is Automatic.
  bool get isAutomatic => numberFormat == kAutomaticNumberFormat;

  /// Value of [a] in column representation.
  Object? valueOf(FormatAttr a) => switch (a) {
    FormatAttr.numberFormat => numberFormat,
    FormatAttr.fontFamily => fontFamily,
    FormatAttr.fontSize => fontSize,
    FormatAttr.bold => bold,
    FormatAttr.italic => italic,
    FormatAttr.underline => underline,
    FormatAttr.strikethrough => strikethrough,
    FormatAttr.textColor => textColor,
    FormatAttr.fillColor => fillColor,
    FormatAttr.hAlign => hAlign,
    FormatAttr.vAlign => vAlign,
    FormatAttr.wrap => wrap,
    FormatAttr.rotation => rotation,
    FormatAttr.borderTop => borderTop?.encode(),
    FormatAttr.borderRight => borderRight?.encode(),
    FormatAttr.borderBottom => borderBottom?.encode(),
    FormatAttr.borderLeft => borderLeft?.encode(),
    FormatAttr.linkUrl => linkUrl,
  };

  @override
  bool operator ==(Object other) =>
      other is ResolvedFormat &&
      FormatAttr.values.every((a) => valueOf(a) == other.valueOf(a));

  @override
  int get hashCode => Object.hashAll(FormatAttr.values.map(valueOf));

  @override
  String toString() =>
      'ResolvedFormat(${{for (final a in FormatAttr.values) a.column: valueOf(a)}})';
}

/// Resolves effective formats: CF overlay ▸ cell ▸ row ▸ column ▸ sheet ▸
/// banding ▸ theme defaults, per attribute (06 §1.2).
final class EffectiveFormatResolver {
  /// Creates a resolver over [model].
  EffectiveFormatResolver(this.model);

  /// The workbook.
  final WorkbookModel model;

  /// The explicit chain (no banding, no theme) of a cell.
  CellFormat explicit(String sheetId, int row, int col) =>
      model.explicitFormatChain(sheetId, row, col);

  /// Resolves the format of the cell at (row, col). [conditional] is the CF
  /// overlay (bold/italic/underline/strikethrough/textColor/fillColor) that wins
  /// over everything; [includeBanding] applies alternating colors.
  ResolvedFormat resolve(
    String sheetId,
    int row,
    int col, {
    CellFormat? conditional,
    bool includeBanding = true,
  }) {
    final s = model.sheet(sheetId);
    final spreadsheet = model.spreadsheet;
    final theme = model.theme;
    var f = explicit(sheetId, row, col);
    if (includeBanding &&
        s != null &&
        (s.bandings.isNotEmpty || model.bandingPreview != null)) {
      final (fill, bold) = bandingAt(s, row, col);
      if (fill != null && !f.has(FormatAttr.fillColor)) {
        f = f.withValue(FormatAttr.fillColor, fill);
      }
      if (bold && !f.has(FormatAttr.bold)) {
        f = f.withValue(FormatAttr.bold, true);
      }
    }
    if (conditional != null && !conditional.isEmpty) {
      final overlay = <FormatAttr, Object?>{
        for (final a in FormatAttr.conditional)
          if (conditional.has(a)) a: conditional[a],
      };
      f = f.withValues(overlay);
    }
    final defaultFont = theme.textFont.isNotEmpty
        ? theme.textFont
        : spreadsheet.defaultFontFamily;
    return ResolvedFormat(
      numberFormat:
          f[FormatAttr.numberFormat] as String? ?? kAutomaticNumberFormat,
      numberFormatExplicit: f.has(FormatAttr.numberFormat),
      fontFamily: f[FormatAttr.fontFamily] as String? ?? defaultFont,
      fontSize:
          f[FormatAttr.fontSize] as double? ?? spreadsheet.defaultFontSize,
      bold: f[FormatAttr.bold] as bool? ?? false,
      italic: f[FormatAttr.italic] as bool? ?? false,
      underline: f[FormatAttr.underline] as bool? ?? false,
      strikethrough: f[FormatAttr.strikethrough] as bool? ?? false,
      textColor: f[FormatAttr.textColor] as String?,
      fillColor: f[FormatAttr.fillColor] as String?,
      hAlign: f[FormatAttr.hAlign] as HorizontalAlign?,
      vAlign: f[FormatAttr.vAlign] as VerticalAlign? ?? VerticalAlign.bottom,
      wrap: f[FormatAttr.wrap] as WrapStrategy? ?? WrapStrategy.overflow,
      rotation: f[FormatAttr.rotation] as int? ?? 0,
      borderTop: BorderSpec.tryParse(f[FormatAttr.borderTop] as String?),
      borderRight: BorderSpec.tryParse(f[FormatAttr.borderRight] as String?),
      borderBottom: BorderSpec.tryParse(f[FormatAttr.borderBottom] as String?),
      borderLeft: BorderSpec.tryParse(f[FormatAttr.borderLeft] as String?),
      linkUrl: f[FormatAttr.linkUrl] as String?,
    );
  }

  /// Alternating-colors contribution at a cell: `(fillColor, headerBold)`.
  /// Bands alternate over visible rows (06 §14.1).
  (String?, bool) bandingAt(SheetModel s, int row, int col) {
    final preview = model.bandingPreview?.call(s, row, col);
    if (preview != null) return preview;
    final ids = s.rulesAt(RuleKind.banding, row, col);
    if (ids.isEmpty) return (null, false);
    final b = s.bandings[ids.first]!;
    final rr = s.resolve(
      GridRange.tryParse(b.rangeJson) ?? GridRange.sheet(s.id),
    );
    if (rr == null) return (null, false);
    return BandingStyle.parse(
      b.styleJson,
    ).contributionIn(rr.rect, row, col, rows: s.rows, columns: s.columns);
  }

  /// The border drawn on the shared edge below (row, col) — between the cell
  /// and the cell below — resolved per 06 §8.4 (heavier wins, ties: upper).
  BorderSpec? edgeBelow(String sheetId, int row, int col) {
    final a = BorderSpec.tryParse(
      explicit(sheetId, row, col)[FormatAttr.borderBottom] as String?,
    );
    final b = BorderSpec.tryParse(
      explicit(sheetId, row + 1, col)[FormatAttr.borderTop] as String?,
    );
    return BorderSpec.resolveShared(a, b);
  }

  /// The border drawn on the shared edge right of (row, col) (ties: left cell).
  BorderSpec? edgeRight(String sheetId, int row, int col) {
    final a = BorderSpec.tryParse(
      explicit(sheetId, row, col)[FormatAttr.borderRight] as String?,
    );
    final b = BorderSpec.tryParse(
      explicit(sheetId, row, col + 1)[FormatAttr.borderLeft] as String?,
    );
    return BorderSpec.resolveShared(a, b);
  }

  /// The top edge of a cell in row 0 / the left edge of a cell in column 0.
  BorderSpec? outerEdge(String sheetId, int row, int col, FormatAttr edge) {
    final spec = BorderSpec.tryParse(
      explicit(sheetId, row, col)[edge] as String?,
    );
    return spec == null || spec.isNone ? null : spec;
  }

  /// Resolves a color string through the spreadsheet theme.
  String? color(String? c) => model.theme.resolveColor(c);

  /// The theme.
  SpreadsheetTheme get theme => model.theme;
}
