import 'dart:convert';

import '../../addressing/grid_geometry.dart';
import '../../content/rich_text.dart';
import '../../format/attributes.dart';
import '../../model/schema.dart';
import 'ir_formats.dart';
import 'workbook_document.dart';

/// Normalized JSON of a [WorkbookDocument] for round-trip goldens and
/// developer inspection (11 §6.7, §12).
///
/// Normalization: formats are inlined (table indices don't matter), attribute
/// values equal to the visual defaults are dropped (`bold: false`,
/// `vAlign: bottom`, `rotation: 0`, `wrap: overflow`, Automatic number
/// format, border `none`, reset colors), numbers that are integral become
/// ints, sizes are rounded to 0.01 px, maps have sorted keys and lists are
/// in a canonical order.
abstract final class IrJson {
  /// The normalized JSON map.
  static Map<String, Object?> normalize(
    WorkbookDocument doc, {
    bool includeCachedValues = true,
    bool includeWarnings = false,
    bool includeImages = true,
  }) {
    final out = <String, Object?>{
      if (doc.title != null) 'title': doc.title,
      'sheets': [
        for (final s in doc.sheets)
          _sheet(
            doc,
            s,
            includeCachedValues: includeCachedValues,
            includeImages: includeImages,
          ),
      ],
      if (doc.namedRanges.isNotEmpty)
        'namedRanges': [
          for (final n
              in [...doc.namedRanges]..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              ))
            _sorted({
              'name': n.name,
              if (n.sheet != null) 'sheet': n.sheet,
              if (n.range != null) 'range': n.range!.toA1(),
              if (n.formulaA1 != null) 'formula': n.formulaA1,
              if (n.comment != null && n.comment!.isNotEmpty)
                'comment': n.comment,
              if (n.hidden) 'hidden': true,
            }),
        ],
      if (includeWarnings)
        'warnings': [for (final w in doc.warnings) w.toJson()],
    };
    return _sorted(out);
  }

  /// Pretty-printed normalized JSON.
  static String encode(
    WorkbookDocument doc, {
    bool includeCachedValues = true,
    bool includeWarnings = false,
  }) => const JsonEncoder.withIndent('  ').convert(
    normalize(
      doc,
      includeCachedValues: includeCachedValues,
      includeWarnings: includeWarnings,
    ),
  );

  static Map<String, Object?> _sheet(
    WorkbookDocument doc,
    IrSheet s, {
    required bool includeCachedValues,
    required bool includeImages,
  }) {
    Map<String, Object?> dims(Iterable<MapEntry<int, IrDim>> entries) {
      final m = <String, Object?>{};
      for (final e in entries) {
        final d = e.value;
        final j = <String, Object?>{
          if (d.size != null) 'size': _round(d.size!),
          if (d.hidden) 'hidden': true,
          if (d.outlineLevel > 0) 'outline': d.outlineLevel,
          if (d.collapsed) 'collapsed': true,
        };
        final f = formatJson(doc, doc.formats[d.format]);
        if (f.isNotEmpty) j['fmt'] = f;
        if (j.isNotEmpty) m['${e.key}'] = _sorted(j);
      }
      return m;
    }

    final inherits =
        s.defaultFormat != 0 ||
        s.rows.entries.any((e) => e.value.format != 0) ||
        s.columns.entries.any((e) => e.value.format != 0);
    final cells = <String, Object?>{};
    for (final (r, c, cell) in s.cells.entries) {
      final j = cellJson(
        doc,
        cell,
        includeCachedValue: includeCachedValues,
        effective: inherits ? IrFormats.effective(doc, s, r, c, cell) : null,
      );
      if (j.isNotEmpty) cells[CellPos(r, c).a1] = j;
    }
    final rows = dims(s.rows.entries);
    final cols = dims(s.columns.entries);
    return _sorted({
      'name': s.name,
      if (s.hidden) 'hidden': true,
      if (s.tabColor != null) 'tabColor': s.tabColor,
      if (s.rtl) 'rtl': true,
      if (!s.showGridlines) 'showGridlines': false,
      if (s.frozenRows > 0) 'frozenRows': s.frozenRows,
      if (s.frozenColumns > 0) 'frozenColumns': s.frozenColumns,
      if (s.defaultRowHeight != null)
        'defaultRowHeight': _round(s.defaultRowHeight!),
      if (s.defaultColumnWidth != null)
        'defaultColumnWidth': _round(s.defaultColumnWidth!),
      if (formatJson(doc, doc.formats[s.defaultFormat]).isNotEmpty)
        'defaultFmt': formatJson(doc, doc.formats[s.defaultFormat]),
      if (rows.isNotEmpty) 'rows': rows,
      if (cols.isNotEmpty) 'columns': cols,
      if (cells.isNotEmpty) 'cells': cells,
      if (s.merges.isNotEmpty)
        'merges': ([for (final m in s.merges) m.a1]..sort()),
      if (s.validations.isNotEmpty)
        'validations': [
          for (final v in s.validations)
            _norm({
              'ranges': [for (final r in v.ranges) r.toA1()],
              'criteria': v.criteria,
              'strict': v.strict,
              'showDropdown': v.showDropdown,
              if (v.displayStyle != null) 'displayStyle': v.displayStyle,
              if (v.helpText != null) 'helpText': v.helpText,
            }),
        ]..sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b))),
      if (s.conditionalFormats.isNotEmpty)
        'conditionalFormats': [
          for (final cf in s.conditionalFormats)
            _norm({
              'ranges': [for (final r in cf.ranges) r.toA1()],
              'rule': cf.rule,
              if (!cf.enabled) 'enabled': false,
            }),
        ],
      if (s.autoFilter != null)
        'filter': _norm({
          'range': s.autoFilter!.range.toA1(),
          if (s.autoFilter!.criteria.isNotEmpty)
            'criteria': {
              for (final e in s.autoFilter!.criteria.entries)
                '${e.key}': e.value,
            },
          if (s.autoFilter!.sort.isNotEmpty) 'sort': s.autoFilter!.sort,
        }),
      if (includeImages && s.images.isNotEmpty)
        'images': [
          for (final i in s.images)
            _norm({
              'anchor': _anchor(i.anchor),
              'mimeType': i.mimeType,
              if (i.bytes != null) 'bytes': i.bytes!.length,
              if (i.bytes != null) 'hash': _fnv(i.bytes!),
              if (i.altText != null && i.altText!.isNotEmpty) 'alt': i.altText,
            }),
        ],
      if (s.charts.isNotEmpty)
        'charts': [
          for (final c in s.charts)
            _norm({'anchor': _anchor(c.anchor), 'spec': c.spec}),
        ],
      if (s.print != null && s.print!.isNotEmpty) 'print': _norm(s.print),
    });
  }

  static Map<String, Object?> _anchor(IrAnchor a) => {
    'row': a.row,
    'col': a.col,
    'dx': _round(a.dx),
    'dy': _round(a.dy),
    'width': _round(a.width),
    'height': _round(a.height),
  };

  /// Normalized JSON of one cell. With [effective], `fmt` shows the
  /// effective format (inheritance applied) instead of the cell's own.
  static Map<String, Object?> cellJson(
    WorkbookDocument doc,
    IrCell cell, {
    bool includeCachedValue = true,
    CellFormat? effective,
  }) {
    final j = <String, Object?>{};
    if (cell.formulaA1 != null) {
      j['f'] = cell.formulaA1;
      if (cell.formulaKind != IrFormulaKind.normal) {
        j['kind'] = cell.formulaKind.name;
      }
      if (cell.arrayRef != null) j['ref'] = cell.arrayRef!.a1;
    }
    if (cell.value != null && (cell.formulaA1 == null || includeCachedValue)) {
      j['v'] = valueJson(cell.value!);
    }
    final own = doc.formats[cell.format];
    final f = formatJson(
      doc,
      effective == null ? own : IrFormat(effective, own.extras),
    );
    if (f.isNotEmpty) j['fmt'] = f;
    if (cell.note != null && cell.note!.isNotEmpty) j['note'] = cell.note;
    if (cell.link != null) j['link'] = cell.link;
    if (cell.blockedFormulaA1 != null) j['blocked'] = cell.blockedFormulaA1;
    return _sorted(j);
  }

  /// Normalized JSON of a value.
  static Object? valueJson(IrValue v) => switch (v) {
    IrNumber(:final number) => {'n': _num(number)},
    IrText(:final text) => {'s': text},
    IrBool(:final value) => {'b': value},
    IrError(:final kind) => {'e': kind.literal},
    IrRich(:final rich) => {
      'r': {
        't': rich.text,
        'runs': [
          for (final run in rich.runs)
            {'s': run.start, 'e': run.end, 'f': _norm(run.format)},
        ],
      },
    },
  };

  static const Set<String> _dropDefaults = {
    'bold:false',
    'italic:false',
    'underline:false',
    'strikethrough:false',
    'rotation:0',
    'wrap:overflow',
    'vAlign:bottom',
    'numberFormat:preset:automatic',
    'numberFormat:General',
    'borderTop:none',
    'borderRight:none',
    'borderBottom:none',
    'borderLeft:none',
    'textColor:theme:text',
    'fillColor:theme:background',
  };

  /// Normalized format map (defaults dropped).
  static Map<String, Object?> formatJson(WorkbookDocument doc, IrFormat f) {
    final m = <String, Object?>{};
    for (final a in f.attrs.attrs) {
      if (a == FormatAttr.linkUrl) continue;
      final v = a.toColumnValue(f.attrs[a]);
      if (_dropDefaults.contains('${a.column}:$v')) continue;
      if (a == FormatAttr.fontFamily &&
          doc.defaultFontFamily != null &&
          v == doc.defaultFontFamily) {
        continue;
      }
      if (a == FormatAttr.fontSize &&
          doc.defaultFontSize != null &&
          v == doc.defaultFontSize) {
        continue;
      }
      m[a.column] = v is double ? _num(v) : v;
    }
    if (f.extras.isNotEmpty) m['extras'] = _norm(f.extras);
    return _sorted(m);
  }

  static Object _num(double d) =>
      d == d.truncateToDouble() && d.abs() < 1e15 ? d.toInt() : d;

  static Object _round(double d) => _num((d * 100).roundToDouble() / 100);

  static Object? _norm(Object? v) {
    if (v is Map) {
      final entries = [for (final e in v.entries) MapEntry('${e.key}', e.value)]
        ..sort((a, b) => a.key.compareTo(b.key));
      return <String, Object?>{for (final e in entries) e.key: _norm(e.value)};
    }
    if (v is List) return [for (final e in v) _norm(e)];
    if (v is double) return _num(v);
    if (v is Enum) return v.name;
    if (v is RichText) return v.toJson();
    return v;
  }

  static Map<String, Object?> _sorted(Map<String, Object?> m) =>
      _norm(m) as Map<String, Object?>;

  static int _fnv(List<int> bytes) {
    var h = 0x811c9dc5;
    for (final b in bytes) {
      h = ((h ^ b) * 0x01000193) & 0xffffffff;
    }
    return h;
  }
}

/// Counts of an IR document (import summary, 11 §2.3).
final class IrStatistics {
  /// Creates statistics.
  const IrStatistics({
    required this.sheets,
    required this.cells,
    required this.formulas,
    required this.formats,
    required this.merges,
    required this.validations,
    required this.conditionalFormats,
    required this.notes,
    required this.links,
    required this.images,
    required this.charts,
    required this.namedRanges,
    required this.warnings,
    required this.cellsPerSheet,
  });

  /// Computes statistics of [doc].
  factory IrStatistics.of(WorkbookDocument doc) {
    var cells = 0,
        formulas = 0,
        merges = 0,
        dv = 0,
        cf = 0,
        notes = 0,
        links = 0,
        images = 0,
        charts = 0;
    final per = <String, int>{};
    for (final s in doc.sheets) {
      per[s.name] = s.cells.length;
      cells += s.cells.length;
      for (final (_, _, c) in s.cells.entries) {
        if (c.formulaA1 != null) formulas++;
        if (c.note != null) notes++;
        if (c.link != null) links++;
      }
      merges += s.merges.length;
      dv += s.validations.length;
      cf += s.conditionalFormats.length;
      images += s.images.length;
      charts += s.charts.length;
    }
    return IrStatistics(
      sheets: doc.sheets.length,
      cells: cells,
      formulas: formulas,
      formats: doc.formats.length - 1,
      merges: merges,
      validations: dv,
      conditionalFormats: cf,
      notes: notes,
      links: links,
      images: images,
      charts: charts,
      namedRanges: doc.namedRanges.length,
      warnings: doc.warnings.length,
      cellsPerSheet: per,
    );
  }

  final int sheets;
  final int cells;
  final int formulas;
  final int formats;
  final int merges;
  final int validations;
  final int conditionalFormats;
  final int notes;
  final int links;
  final int images;
  final int charts;
  final int namedRanges;
  final int warnings;
  final Map<String, int> cellsPerSheet;

  /// JSON.
  Map<String, Object?> toJson() => {
    'sheets': sheets,
    'cells': cells,
    'formulas': formulas,
    'formats': formats,
    'merges': merges,
    'validations': validations,
    'conditionalFormats': conditionalFormats,
    'notes': notes,
    'links': links,
    'images': images,
    'charts': charts,
    'namedRanges': namedRanges,
    'warnings': warnings,
    'cellsPerSheet': cellsPerSheet,
  };
}

/// Enum name helper for IR JSON readers.
T? irEnum<T extends Enum>(List<T> values, Object? name) =>
    enumByName(values, name);
