import 'dart:convert';

import 'package:wonky_sheets_core/wonky_sheets_core.dart';

/// Reference mode of the macro recorder (09 §15).
enum MacroReferenceMode {
  /// Ranges are recorded as A1 notation (`sheet.getRange('B2:C5')`).
  absolute,

  /// Ranges are recorded relative to the active range at the start
  /// (`active.offset(0, 0, 1, 5)`).
  relative,
}

/// Context of one recording (09 §15 `MacroContext`).
final class MacroContext {
  /// Creates a context; [anchor] is the active range when recording started.
  const MacroContext({
    required this.mode,
    required this.sheetId,
    required this.anchor,
  });

  /// Reference mode.
  final MacroReferenceMode mode;

  /// Active sheet when recording started.
  final String sheetId;

  /// Active range when recording started (relative mode origin).
  final GridRect anchor;

  /// The script expression of [rect] on [sheetId] (model state before the
  /// recorded operation).
  String rangeExpr(WorkbookModel model, String sheetId, GridRect rect) {
    if (mode == MacroReferenceMode.relative && sheetId == this.sheetId) {
      return 'active.offset(${rect.top - anchor.top}, '
          '${rect.left - anchor.left}, ${rect.rowCount}, ${rect.colCount})';
    }
    return '${sheetExpr(model, sheetId)}.getRange(${_str(rect.a1)})';
  }

  /// The script expression of the sheet [sheetId].
  String sheetExpr(WorkbookModel model, String sheetId) {
    if (sheetId == this.sheetId) return 'sheet';
    final name = model.sheet(sheetId)?.name ?? sheetId;
    return 'SpreadsheetApp.active.sheetByName(${_str(name)})!';
  }
}

String _str(String s) => jsonEncode(s).replaceAll(r'$', r'\$');

String _literal(Object? v) => switch (v) {
  null => 'null',
  String s => _str(s),
  bool b => '$b',
  int i => '$i',
  double d when d == d.truncateToDouble() && d.abs() < 1e15 => '${d.toInt()}',
  double d => '$d',
  _ => _str('$v'),
};

/// Turns recorded operations into Dart statements (09 §15 `ScriptCodegen`).
///
/// Every command of the app ends in [SheetsOperation]s, so the recorder works
/// on operations: the app forwards each operation of a recordable command
/// (sources `menu`, `toolbar`, `shortcut`, `contextMenu`, `palette`, cell
/// editor, paste, fill) **before** applying it, together with the model.
abstract final class MacroCodegen {
  /// Statements reproducing [op], or null when it is not recordable.
  static List<String>? toScript(
    SheetsOperation op,
    WorkbookModel model,
    MacroContext ctx,
  ) {
    String range(String sheetId, GridRect r) =>
        ctx.rangeExpr(model, sheetId, r);
    switch (op) {
      case SetCellInputs():
        final rows = op.inputs.length;
        final cols = rows == 0 ? 0 : op.inputs.first.length;
        if (rows == 0 || cols == 0) return const [];
        final values = <List<Object?>>[];
        for (final row in op.inputs) {
          final out = <Object?>[];
          for (final input in row) {
            switch (input) {
              case UserCellInput(:final text):
                out.add(text);
              case RawCellInput(:final value):
                if (value != null &&
                    value is! String &&
                    value is! num &&
                    value is! bool) {
                  return null;
                }
                out.add(value);
              case ContentCellInput(:final content):
                if (content == null) {
                  out.add(null);
                } else if (content is FormulaContent) {
                  return null; // stored formulas need the source position
                } else {
                  out.add(content.literalValue.dartValue);
                }
            }
          }
          values.add(out);
        }
        final rect = GridRect(
          op.row,
          op.col,
          op.row + rows - 1,
          op.col + cols - 1,
        );
        if (rows == 1 && cols == 1) {
          final v = values.first.first;
          if (v is String && v.startsWith('=')) {
            return ['${range(op.sheetId, rect)}.formula = ${_literal(v)};'];
          }
          return ['${range(op.sheetId, rect)}.value = ${_literal(v)};'];
        }
        final grid = values
            .map((r) => '[${r.map(_literal).join(', ')}]')
            .join(', ');
        return ['${range(op.sheetId, rect)}.values = [$grid];'];
      case SetFormat():
        final out = <String>[];
        for (final r in op.ranges) {
          for (final e in op.values.entries) {
            final s = _formatStatement(
              range(r.sheetId, r.rect),
              e.key,
              e.value,
            );
            if (s == null) return null;
            out.add(s);
          }
        }
        return out;
      case ToggleFormat():
        return null; // depends on the current state; the app records SetFormat
      case SetBorders():
        final side = switch (op.preset) {
          BorderPreset.all =>
            'top: true, left: true, bottom: true, right: true, vertical: true, horizontal: true',
          BorderPreset.outer =>
            'top: true, left: true, bottom: true, right: true',
          BorderPreset.inner => 'vertical: true, horizontal: true',
          BorderPreset.top => 'top: true',
          BorderPreset.bottom => 'bottom: true',
          BorderPreset.left => 'left: true',
          BorderPreset.right => 'right: true',
          BorderPreset.vertical => 'vertical: true',
          BorderPreset.horizontal => 'horizontal: true',
          BorderPreset.clear =>
            'top: false, left: false, bottom: false, right: false, vertical: false, horizontal: false',
        };
        final color = op.color == 'auto'
            ? ''
            : ', color: ${_literal(op.color)}';
        final style = op.style == BorderStyle.thin
            ? ''
            : ', style: ${_literal(op.style.name)}';
        return [
          for (final r in op.ranges)
            '${range(r.sheetId, r.rect)}.setBorder($side$color$style);',
        ];
      case ClearRanges():
        final args = switch (op.what) {
          ClearWhat.contents => 'contentsOnly: true',
          ClearWhat.formats => 'formatsOnly: true',
          ClearWhat.notes => 'notesOnly: true',
          ClearWhat.all => '',
          _ => null,
        };
        if (args == null) return null;
        return [
          for (final r in op.ranges)
            '${range(r.sheetId, r.rect)}.clear($args);',
        ];
      case SetNote():
        return [
          '${range(op.sheetId, GridRect.cell(op.row, op.col))}.note = ${_literal(op.note)};',
        ];
      case MergeCells():
        final m = switch (op.mode) {
          MergeMode.all => 'merge',
          MergeMode.horizontal => 'mergeAcross',
          MergeMode.vertical => 'mergeVertically',
        };
        return [for (final r in op.ranges) '${range(r.sheetId, r.rect)}.$m();'];
      case UnmergeCells():
        return [
          for (final r in op.ranges)
            '${range(r.sheetId, r.rect)}.breakApart();',
        ];
      case InsertDimension():
        final sheet = ctx.sheetExpr(model, op.sheetId);
        final what = op.dimension == Dimension.rows ? 'Rows' : 'Columns';
        return ['$sheet.insert${what}Before(${op.at + 1}, ${op.count});'];
      case DeleteDimension():
        final s = model.sheet(op.sheetId);
        if (s == null || op.ids.isEmpty) return null;
        final axis = s.axis(op.dimension);
        final idx = [for (final id in op.ids) axis.indexOf(id)]..sort();
        if (idx.first < 0 || idx.last - idx.first + 1 != idx.length) {
          return null;
        }
        final sheet = ctx.sheetExpr(model, op.sheetId);
        final what = op.dimension == Dimension.rows ? 'Rows' : 'Columns';
        return ['$sheet.delete$what(${idx.first + 1}, ${idx.length});'];
      case SetDimensionHidden():
        final s = model.sheet(op.sheetId);
        if (s == null || op.ids.isEmpty) return null;
        final axis = s.axis(op.dimension);
        final idx = [for (final id in op.ids) axis.indexOf(id)]..sort();
        if (idx.first < 0 || idx.last - idx.first + 1 != idx.length) {
          return null;
        }
        final sheet = ctx.sheetExpr(model, op.sheetId);
        final what = op.dimension == Dimension.rows ? 'Rows' : 'Columns';
        final verb = op.hidden ? 'hide' : 'show';
        return ['$sheet.$verb$what(${idx.first + 1}, ${idx.length});'];
      case ResizeDimension():
        final s = model.sheet(op.sheetId);
        if (s == null || op.ids.isEmpty) return null;
        final axis = s.axis(op.dimension);
        final sheet = ctx.sheetExpr(model, op.sheetId);
        final size = op.size;
        if (size == null) {
          if (op.dimension == Dimension.rows) return null;
          final idx = [for (final id in op.ids) axis.indexOf(id)]..sort();
          return ['$sheet.autoResizeColumns(${idx.first + 1}, ${idx.length});'];
        }
        return [
          for (final id in op.ids)
            op.dimension == Dimension.rows
                ? '$sheet.setRowHeight(${axis.indexOf(id) + 1}, ${_literal(size)});'
                : '$sheet.setColumnWidth(${axis.indexOf(id) + 1}, ${_literal(size)});',
        ];
      case SetFrozen():
        final sheet = ctx.sheetExpr(model, op.sheetId);
        return [
          if (op.rows != null) '$sheet.frozenRows = ${op.rows};',
          if (op.columns != null) '$sheet.frozenColumns = ${op.columns};',
        ];
      case AddSheet():
        return [
          'SpreadsheetApp.active.insertSheet(${op.name == null ? '' : 'name: ${_literal(op.name)}'});',
        ];
      case RenameSheet():
        return [
          '${ctx.sheetExpr(model, op.sheetId)}.name = ${_literal(op.name)};',
        ];
      case DeleteSheet():
        return [
          'SpreadsheetApp.active.deleteSheet(${ctx.sheetExpr(model, op.sheetId)});',
        ];
      case InsertCheckboxes():
        return [
          for (final r in op.ranges)
            '${range(op.sheetId, r)}.insertCheckboxes();',
        ];
      case SortRange():
        final s = model.sheet(op.range.sheetId);
        if (s == null || op.hasHeader) return null;
        final specs = [
          for (final k in op.specs)
            'SortSpec(column: ${s.columns.indexOf(k.colId) + 1}'
                '${k.ascending ? '' : ', ascending: false'})',
        ];
        return [
          '${range(op.range.sheetId, op.range.rect)}.sort([${specs.join(', ')}]);',
        ];
      default:
        return null;
    }
  }

  static String? _formatStatement(String target, FormatAttr attr, Object? v) {
    switch (attr) {
      case FormatAttr.bold:
        return "$target.fontWeight = '${v == true ? 'bold' : 'normal'}';";
      case FormatAttr.italic:
        return "$target.fontStyle = '${v == true ? 'italic' : 'normal'}';";
      case FormatAttr.underline:
        return "$target.textDecoration = '${v == true ? 'underline' : 'none'}';";
      case FormatAttr.strikethrough:
        return "$target.textDecoration = '${v == true ? 'lineThrough' : 'none'}';";
      case FormatAttr.textColor:
        if (v is String && v.startsWith('theme:')) return null;
        return '$target.fontColor = ${_literal(v)};';
      case FormatAttr.fillColor:
        if (v is String && v.startsWith('theme:')) return null;
        return '$target.background = ${_literal(v)};';
      case FormatAttr.numberFormat:
        return '$target.numberFormat = ${_literal(v ?? 'preset:automatic')};';
      case FormatAttr.fontFamily:
        if (v == null) return null;
        return '$target.fontFamily = ${_literal(v)};';
      case FormatAttr.fontSize:
        if (v == null) return null;
        return '$target.fontSize = ${_literal(v)};';
      case FormatAttr.hAlign:
        final name = v is HorizontalAlign
            ? v.name
            : (v as String?) ?? 'general';
        return "$target.horizontalAlignment = '$name';";
      case FormatAttr.vAlign:
        final name = v is VerticalAlign ? v.name : (v as String?) ?? 'bottom';
        return "$target.verticalAlignment = '$name';";
      case FormatAttr.wrap:
        final name = v is WrapStrategy ? v.name : (v as String?) ?? 'overflow';
        return "$target.wrapStrategy = '$name';";
      default:
        return null;
    }
  }
}

/// Records operations and produces the macro function (09 §15).
final class MacroRecorder {
  /// Starts a recording.
  MacroRecorder({required this.context});

  /// Recording context.
  final MacroContext context;

  final _lines = <String>[];
  var _usesSheet = false;
  var _usesActive = false;

  /// Statements recorded so far.
  List<String> get statements => List.unmodifiable(_lines);

  /// Records [op] (call before applying it to [model]). [label] names
  /// operations that are not recordable in the comment.
  void record(SheetsOperation op, WorkbookModel model, {String? label}) {
    final code = MacroCodegen.toScript(op, model, context);
    if (code == null) {
      _lines.add('// Not recorded: ${label ?? op.runtimeType}');
      return;
    }
    for (final line in code) {
      if (line.contains('sheet.') || line.contains('(sheet)')) {
        _usesSheet = true;
      }
      if (line.contains('active.offset')) _usesActive = true;
      _lines.add(line);
    }
  }

  /// Records a comment for a command that is not recordable.
  void notRecorded(String commandTitle) =>
      _lines.add('// Not recorded: $commandTitle');

  /// The function source for the macro [name] (`/// Macro "…" (recorded …)`).
  String functionSource(String functionName, String name, DateTime recordedAt) {
    final date = recordedAt.toUtc().toIso8601String().substring(0, 10);
    final b = StringBuffer()
      ..writeln('/// Macro ${jsonEncode(name)} (recorded $date).')
      ..writeln('void $functionName() {');
    if (_usesSheet) b.writeln('  final sheet = SpreadsheetApp.activeSheet;');
    if (_usesActive) b.writeln('  final active = SpreadsheetApp.activeRange;');
    for (final l in _lines) {
      b.writeln('  $l');
    }
    b.writeln('}');
    return b.toString();
  }

  /// A valid, unused Dart function name for the macro [name].
  static String functionNameFor(String name, Set<String> existing) {
    final words = name
        .replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    var base = words.isEmpty
        ? 'macro'
        : words.first.toLowerCase() +
              words
                  .skip(1)
                  .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
                  .join();
    if (RegExp(r'^[0-9]').hasMatch(base)) base = 'macro$base';
    var candidate = base;
    var n = 2;
    while (existing.contains(candidate) || _reserved.contains(candidate)) {
      candidate = '$base${n++}';
    }
    return candidate;
  }

  static const _reserved = {
    'onOpen',
    'onEdit',
    'onChange',
    'onSelectionChange',
    'wonkyInvoke',
    'wonkyEvent',
  };

  /// [fileSource] (`macros.dart`, created when null) with the macro appended.
  static String appendTo(String? fileSource, String function) {
    final base = (fileSource == null || fileSource.trim().isEmpty)
        ? "import 'package:wonky/wonky.dart';\n"
        : fileSource.trimRight();
    return '$base\n\n$function';
  }
}
