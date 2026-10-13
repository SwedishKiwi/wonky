import 'dart:convert';

import '../../model/grid_range.dart';
import 'paper_size.dart';

/// Page orientation.
enum PageOrientation { portrait, landscape }

/// Scale modes (11 §7.2).
enum PrintScaleMode { normal, fitWidth, fitHeight, fitPage, custom }

/// Margin presets.
enum MarginPreset { normal, narrow, wide, custom }

/// Page order.
enum PageOrder { downThenOver, overThenDown }

/// Horizontal placement of the content on the page.
enum PrintHAlign { left, center, right }

/// Vertical placement of the content on the page.
enum PrintVAlign { top, middle, bottom }

T _enum<T extends Enum>(List<T> values, Object? name, T fallback) {
  if (name is String) {
    for (final v in values) {
      if (v.name == name) return v;
    }
  }
  return fallback;
}

double? _d(Object? v) => v is num && v.isFinite ? v.toDouble() : null;

/// Custom paper size.
final class CustomPaperSize {
  /// Creates a size.
  const CustomPaperSize(this.width, this.height, {this.unit = 'in'});

  final double width;
  final double height;

  /// `in` or `cm`.
  final String unit;

  /// Width in points.
  double get widthPt => PrintUnits.toPoints(width, unit);

  /// Height in points.
  double get heightPt => PrintUnits.toPoints(height, unit);

  /// JSON.
  Map<String, Object?> toJson() => {'w': width, 'h': height, 'unit': unit};

  /// From JSON (null when invalid).
  static CustomPaperSize? fromJson(Object? m) {
    if (m is! Map) return null;
    final w = _d(m['w']);
    final h = _d(m['h']);
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return CustomPaperSize(w, h, unit: m['unit'] == 'cm' ? 'cm' : 'in');
  }
}

/// Margins (top, bottom, left, right) in [unit].
final class PrintMargins {
  /// Creates margins.
  const PrintMargins({
    this.preset = MarginPreset.normal,
    this.top = 0.75,
    this.bottom = 0.75,
    this.left = 0.7,
    this.right = 0.7,
    this.unit = 'in',
  });

  /// Margins of a preset: normal 0.75/0.7 in, narrow 0.25 in, wide 1 in.
  factory PrintMargins.preset(MarginPreset p) => switch (p) {
    MarginPreset.narrow => const PrintMargins(
      preset: MarginPreset.narrow,
      top: 0.25,
      bottom: 0.25,
      left: 0.25,
      right: 0.25,
    ),
    MarginPreset.wide => const PrintMargins(
      preset: MarginPreset.wide,
      top: 1,
      bottom: 1,
      left: 1,
      right: 1,
    ),
    _ => const PrintMargins(),
  };

  final MarginPreset preset;
  final double top;
  final double bottom;
  final double left;
  final double right;

  /// `in` or `cm`.
  final String unit;

  double get topPt => PrintUnits.toPoints(top, unit);
  double get bottomPt => PrintUnits.toPoints(bottom, unit);
  double get leftPt => PrintUnits.toPoints(left, unit);
  double get rightPt => PrintUnits.toPoints(right, unit);

  /// JSON: `{preset}` for presets, all values for custom.
  Map<String, Object?> toJson() => preset == MarginPreset.custom
      ? {
          'preset': 'custom',
          'top': top,
          'bottom': bottom,
          'left': left,
          'right': right,
          'unit': unit,
        }
      : {'preset': preset.name};

  /// From JSON.
  static PrintMargins fromJson(Object? m) {
    if (m is! Map) return const PrintMargins();
    final p = _enum(MarginPreset.values, m['preset'], MarginPreset.normal);
    if (p != MarginPreset.custom) return PrintMargins.preset(p);
    double v(String k, double def) =>
        (_d(m[k]) ?? def).clamp(0, 100).toDouble();
    return PrintMargins(
      preset: MarginPreset.custom,
      top: v('top', 0.75),
      bottom: v('bottom', 0.75),
      left: v('left', 0.7),
      right: v('right', 0.7),
      unit: m['unit'] == 'cm' ? 'cm' : 'in',
    );
  }
}

/// Left/center/right texts of a header or footer (with tokens `{page}`,
/// `{pages}`, `{title}`, `{sheet}`, `{date}`, `{time}`).
final class HeaderFooterSections {
  /// Creates sections.
  const HeaderFooterSections({
    this.left = '',
    this.center = '',
    this.right = '',
  });

  final String left;
  final String center;
  final String right;

  /// Whether all sections are empty.
  bool get isEmpty => left.isEmpty && center.isEmpty && right.isEmpty;

  /// JSON.
  Map<String, Object?> toJson() => {
    'left': left,
    'center': center,
    'right': right,
  };

  /// From JSON.
  static HeaderFooterSections fromJson(
    Object? m, {
    HeaderFooterSections fallback = const HeaderFooterSections(),
  }) {
    if (m is! Map) return fallback;
    String s(String k) => m[k] is String ? m[k] as String : '';
    return HeaderFooterSections(
      left: s('left'),
      center: s('center'),
      right: s('right'),
    );
  }
}

/// Header/footer checkboxes of the print panel.
final class HeaderFooterFlags {
  /// Creates flags.
  const HeaderFooterFlags({
    this.pageNumbers = true,
    this.title = false,
    this.sheetName = false,
    this.date = false,
    this.time = false,
  });

  final bool pageNumbers;
  final bool title;
  final bool sheetName;
  final bool date;
  final bool time;

  /// JSON.
  Map<String, Object?> toJson() => {
    'pageNumbers': pageNumbers,
    'title': title,
    'sheetName': sheetName,
    'date': date,
    'time': time,
  };

  /// From JSON.
  static HeaderFooterFlags fromJson(Object? m) {
    if (m is! Map) return const HeaderFooterFlags();
    bool b(String k, bool def) => m[k] is bool ? m[k] as bool : def;
    return HeaderFooterFlags(
      pageNumbers: b('pageNumbers', true),
      title: b('title', false),
      sheetName: b('sheetName', false),
      date: b('date', false),
      time: b('time', false),
    );
  }
}

/// Header and footer.
final class HeaderFooter {
  /// Creates a header/footer configuration.
  const HeaderFooter({
    this.header = const HeaderFooterSections(),
    this.footer = const HeaderFooterSections(right: '{page}'),
    this.flags = const HeaderFooterFlags(),
  });

  final HeaderFooterSections header;
  final HeaderFooterSections footer;
  final HeaderFooterFlags flags;

  /// The header with the flag tokens added where missing: workbook title
  /// (left), sheet name (center), date and time (right).
  HeaderFooterSections get effectiveHeader {
    String add(String text, List<String> tokens) {
      var t = text;
      for (final tok in tokens) {
        if (!t.contains(tok)) t = t.isEmpty ? tok : '$t $tok';
      }
      return t;
    }

    return HeaderFooterSections(
      left: add(header.left, [
        if (flags.title && !_anywhere('{title}')) '{title}',
      ]),
      center: add(header.center, [
        if (flags.sheetName && !_anywhere('{sheet}')) '{sheet}',
      ]),
      right: add(header.right, [
        if (flags.date && !_anywhere('{date}')) '{date}',
        if (flags.time && !_anywhere('{time}')) '{time}',
      ]),
    );
  }

  /// The footer with the page-number token added (right) when the flag is
  /// on and no section contains it.
  HeaderFooterSections get effectiveFooter {
    if (!flags.pageNumbers || _anywhere('{page}')) return footer;
    return HeaderFooterSections(
      left: footer.left,
      center: footer.center,
      right: footer.right.isEmpty ? '{page}' : '${footer.right} {page}',
    );
  }

  bool _anywhere(String token) => [
    header.left,
    header.center,
    header.right,
    footer.left,
    footer.center,
    footer.right,
  ].any((s) => s.contains(token));

  /// JSON.
  Map<String, Object?> toJson() => {
    'header': header.toJson(),
    'footer': footer.toJson(),
    'flags': flags.toJson(),
  };

  /// From JSON.
  static HeaderFooter fromJson(Object? m) {
    if (m is! Map) return const HeaderFooter();
    return HeaderFooter(
      header: HeaderFooterSections.fromJson(m['header']),
      footer: HeaderFooterSections.fromJson(
        m['footer'],
        fallback: const HeaderFooterSections(right: '{page}'),
      ),
      flags: HeaderFooterFlags.fromJson(m['flags']),
    );
  }
}

/// A contiguous id range of rows or columns (`{"start": id, "end": id}`):
/// explicit print titles (XLSX import).
final class IdSpan {
  /// Creates a span.
  const IdSpan(this.start, this.end);

  final String start;
  final String end;

  /// JSON.
  Map<String, Object?> toJson() => {'start': start, 'end': end};

  /// From JSON (null when invalid).
  static IdSpan? fromJson(Object? m) {
    if (m is! Map) return null;
    final s = m['start'];
    final e = m['end'] ?? s;
    if (s is! String || e is! String) return null;
    return IdSpan(s, e);
  }
}

/// Print settings of a sheet (`Sheet.printSettingsJson`, 11 §7.2).
final class PrintSettings {
  /// Creates settings (defaults per 11 §7.2 with Letter paper).
  const PrintSettings({
    this.paper = PaperSize.letter,
    this.customSize,
    this.orientation = PageOrientation.portrait,
    this.scaleMode = PrintScaleMode.normal,
    this.scalePercent = 100,
    this.margins = const PrintMargins(),
    this.gridlines = false,
    this.notes = false,
    this.pageOrder = PageOrder.downThenOver,
    this.hAlign = PrintHAlign.left,
    this.vAlign = PrintVAlign.top,
    this.repeatFrozen = true,
    this.headings = false,
    this.repeatRows,
    this.repeatCols,
    this.headerFooter = const HeaderFooter(),
    this.rowBreaks = const [],
    this.colBreaks = const [],
    this.printArea,
  });

  /// Defaults for a spreadsheet [locale] (Letter or A4).
  factory PrintSettings.defaults(String locale) =>
      PrintSettings(paper: PaperSize.defaultFor(locale));

  final PaperSize paper;
  final CustomPaperSize? customSize;
  final PageOrientation orientation;
  final PrintScaleMode scaleMode;

  /// Percent for [PrintScaleMode.custom] (10–400).
  final double scalePercent;
  final PrintMargins margins;
  final bool gridlines;
  final bool notes;
  final PageOrder pageOrder;
  final PrintHAlign hAlign;
  final PrintVAlign vAlign;
  final bool repeatFrozen;
  final bool headings;
  final IdSpan? repeatRows;
  final IdSpan? repeatCols;
  final HeaderFooter headerFooter;

  /// Custom page breaks: break *before* these row / column ids.
  final List<String> rowBreaks;
  final List<String> colBreaks;
  final GridRange? printArea;

  /// Page width in points (orientation applied).
  double get pageWidthPt {
    final (w, h) = _portrait;
    return orientation == PageOrientation.portrait ? w : h;
  }

  /// Page height in points (orientation applied).
  double get pageHeightPt {
    final (w, h) = _portrait;
    return orientation == PageOrientation.portrait ? h : w;
  }

  (double, double) get _portrait {
    if (paper == PaperSize.custom && customSize != null) {
      final w = customSize!.widthPt;
      final h = customSize!.heightPt;
      return w <= h ? (w, h) : (h, w);
    }
    return (paper.widthPt, paper.heightPt);
  }

  /// Parses `printSettingsJson`; null/invalid → defaults for [locale].
  /// Unknown or invalid fields fall back to their defaults.
  static PrintSettings parse(String? json, {String locale = 'en_US'}) {
    if (json == null || json.trim().isEmpty) {
      return PrintSettings.defaults(locale);
    }
    Object? m;
    try {
      m = jsonDecode(json);
    } on FormatException {
      return PrintSettings.defaults(locale);
    }
    if (m is! Map) return PrintSettings.defaults(locale);
    return fromJson(m.cast<String, Object?>(), locale: locale);
  }

  /// From a decoded JSON map.
  static PrintSettings fromJson(
    Map<String, Object?> m, {
    String locale = 'en_US',
  }) {
    final scale = m['scale'];
    final align = m['align'];
    final breaks = m['pageBreaks'];
    List<String> ids(Object? l) => [
      if (l is List)
        for (final e in l)
          if (e is String && e.isNotEmpty) e,
    ];
    return PrintSettings(
      paper: PaperSize.tryParse(m['paper']) ?? PaperSize.defaultFor(locale),
      customSize: CustomPaperSize.fromJson(m['customSize']),
      orientation: _enum(
        PageOrientation.values,
        m['orientation'],
        PageOrientation.portrait,
      ),
      scaleMode: scale is Map
          ? _enum(PrintScaleMode.values, scale['mode'], PrintScaleMode.normal)
          : PrintScaleMode.normal,
      scalePercent: scale is Map
          ? (_d(scale['percent']) ?? 100).clamp(10, 400).toDouble()
          : 100,
      margins: PrintMargins.fromJson(m['margins']),
      gridlines: m['gridlines'] == true,
      notes: m['notes'] == true,
      pageOrder: _enum(
        PageOrder.values,
        m['pageOrder'],
        PageOrder.downThenOver,
      ),
      hAlign: align is Map
          ? _enum(PrintHAlign.values, align['h'], PrintHAlign.left)
          : PrintHAlign.left,
      vAlign: align is Map
          ? _enum(PrintVAlign.values, align['v'], PrintVAlign.top)
          : PrintVAlign.top,
      repeatFrozen: m['repeatFrozen'] is bool
          ? m['repeatFrozen'] as bool
          : true,
      headings: m['headings'] == true,
      repeatRows: IdSpan.fromJson(m['repeatRows']),
      repeatCols: IdSpan.fromJson(m['repeatCols']),
      headerFooter: HeaderFooter.fromJson(m['headerFooter']),
      rowBreaks: breaks is Map ? ids(breaks['rows']) : const [],
      colBreaks: breaks is Map ? ids(breaks['cols']) : const [],
      printArea: GridRange.tryParse(m['printArea']),
    );
  }

  /// JSON map (11 §7.2 schema).
  Map<String, Object?> toJson() => {
    'v': 1,
    'paper': paper.id,
    'customSize': customSize?.toJson(),
    'orientation': orientation.name,
    'scale': scaleMode == PrintScaleMode.custom
        ? {'mode': 'custom', 'percent': scalePercent}
        : {'mode': scaleMode.name},
    'margins': margins.toJson(),
    'gridlines': gridlines,
    'notes': notes,
    'pageOrder': pageOrder.name,
    'align': {'h': hAlign.name, 'v': vAlign.name},
    'repeatFrozen': repeatFrozen,
    'headings': headings,
    'repeatRows': repeatRows?.toJson(),
    'repeatCols': repeatCols?.toJson(),
    'headerFooter': headerFooter.toJson(),
    'pageBreaks': {'rows': rowBreaks, 'cols': colBreaks},
    'printArea': printArea?.toJson(),
  };

  /// `printSettingsJson`.
  String encode() => jsonEncode(toJson());

  /// Applies a JSON merge patch (RFC 7396; `sheets.print.updateSettings`).
  PrintSettings mergePatch(
    Map<String, Object?> patch, {
    String locale = 'en_US',
  }) {
    Object? merge(Object? target, Object? p) {
      if (p is! Map) return p;
      final t = target is Map
          ? Map<String, Object?>.from(target)
          : <String, Object?>{};
      p.forEach((k, v) {
        if (v == null) {
          t.remove(k);
        } else {
          t[k as String] = merge(t[k], v);
        }
      });
      return t;
    }

    final merged = merge(toJson(), patch) as Map<String, Object?>;
    return fromJson(merged, locale: locale);
  }

  /// A copy with changes.
  PrintSettings copyWith({
    PaperSize? paper,
    PageOrientation? orientation,
    PrintScaleMode? scaleMode,
    double? scalePercent,
    PrintMargins? margins,
    bool? gridlines,
    bool? notes,
    PageOrder? pageOrder,
    PrintHAlign? hAlign,
    PrintVAlign? vAlign,
    bool? repeatFrozen,
    bool? headings,
    HeaderFooter? headerFooter,
    List<String>? rowBreaks,
    List<String>? colBreaks,
    GridRange? printArea,
  }) => PrintSettings(
    paper: paper ?? this.paper,
    customSize: customSize,
    orientation: orientation ?? this.orientation,
    scaleMode: scaleMode ?? this.scaleMode,
    scalePercent: scalePercent ?? this.scalePercent,
    margins: margins ?? this.margins,
    gridlines: gridlines ?? this.gridlines,
    notes: notes ?? this.notes,
    pageOrder: pageOrder ?? this.pageOrder,
    hAlign: hAlign ?? this.hAlign,
    vAlign: vAlign ?? this.vAlign,
    repeatFrozen: repeatFrozen ?? this.repeatFrozen,
    headings: headings ?? this.headings,
    repeatRows: repeatRows,
    repeatCols: repeatCols,
    headerFooter: headerFooter ?? this.headerFooter,
    rowBreaks: rowBreaks ?? this.rowBreaks,
    colBreaks: colBreaks ?? this.colBreaks,
    printArea: printArea ?? this.printArea,
  );

  @override
  bool operator ==(Object other) =>
      other is PrintSettings && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;

  @override
  String toString() => 'PrintSettings(${encode()})';
}
