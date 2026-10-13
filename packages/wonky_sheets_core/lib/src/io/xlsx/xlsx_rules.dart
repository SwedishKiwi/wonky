import 'package:xml/xml.dart';

import '../../addressing/grid_geometry.dart';
import '../../content/cell_content.dart';
import '../../format/number_format/number_formatter.dart';
import '../color/excel_colors.dart';
import '../formula/excel_formula_translator.dart';
import '../ir/import_warning.dart';
import '../ir/ir_range.dart';
import '../ir/workbook_document.dart';
import 'ooxml.dart';

/// Parses an XLSX `sqref` (`A1:B2 D4`).
List<IrRange> parseSqref(String? sqref) => [
  for (final part in (sqref ?? '').trim().split(RegExp(r'\s+')))
    if (part.isNotEmpty)
      if (IrRange.parseA1(part) case (_, final IrRange r))
        r.openAt(maxRows: Ooxml.maxRows, maxCols: Ooxml.maxCols),
];

/// Writes ranges as `sqref` (open ranges expanded to the XLSX grid).
String formatSqref(List<IrRange> ranges) => ranges.map(_excelA1).join(' ');

String _excelA1(IrRange r) {
  if (r.isBounded) return r.toA1();
  return IrRange(
    r.r1 ?? 0,
    r.c1 ?? 0,
    r.r2 ?? Ooxml.maxRows - 1,
    r.c2 ?? Ooxml.maxCols - 1,
  ).toA1();
}

String _absA1(IrRange r) {
  final b = IrRange(
    r.r1 ?? 0,
    r.c1 ?? 0,
    r.r2 ?? Ooxml.maxRows - 1,
    r.c2 ?? Ooxml.maxCols - 1,
  );
  return b.toA1(absolute: true);
}

/// Condition value JSON for an Excel formula operand: numbers/strings as
/// literals, everything else as `=formula`.
Map<String, Object?> _operand(String f, ExcelFormulaTranslator tr) {
  final t = f.trim();
  if (double.tryParse(t) != null) return {'v': t};
  if (t.length >= 2 &&
      t.startsWith('"') &&
      t.endsWith('"') &&
      !t.substring(1, t.length - 1).replaceAll('""', '').contains('"')) {
    return {'v': t.substring(1, t.length - 1).replaceAll('""', '"')};
  }
  return {'v': '=${tr.importFormula(t).formula}'};
}

/// Excel operand for a condition value (`{"v": …}`).
String _exportOperand(Object? value, ExcelFormulaTranslator tr) {
  final v = value is Map ? value['v'] : value;
  final s = v?.toString() ?? '';
  if (s.startsWith('=')) return tr.exportFormula(s.substring(1)).formula;
  if (double.tryParse(s) != null) return s;
  final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(s);
  if (iso != null) {
    return 'DATE(${int.parse(iso.group(1)!)},${int.parse(iso.group(2)!)},${int.parse(iso.group(3)!)})';
  }
  return '"${s.replaceAll('"', '""')}"';
}

String _quoted(String s) => '"${s.replaceAll('"', '""')}"';

const Map<String, String> _numOps = {
  'between': 'numberBetween',
  'notBetween': 'numberNotBetween',
  'equal': 'numberEq',
  'notEqual': 'numberNotEq',
  'greaterThan': 'numberGreater',
  'lessThan': 'numberLess',
  'greaterThanOrEqual': 'numberGreaterEq',
  'lessThanOrEqual': 'numberLessEq',
};

const Map<String, String> _dateOps = {
  'between': 'dateBetween',
  'notBetween': 'dateNotBetween',
  'equal': 'dateEq',
  'greaterThan': 'dateAfter',
  'lessThan': 'dateBefore',
  'greaterThanOrEqual': 'dateOnOrAfter',
  'lessThanOrEqual': 'dateOnOrBefore',
};

Map<String, String> _invert(Map<String, String> m) => {
  for (final e in m.entries) e.value: e.key,
};

/// XLSX ⇄ IR mapping of data validation, conditional formatting and
/// autofilters (11 §5.2, §6.2).
final class XlsxRules {
  /// Creates the mapper.
  XlsxRules(this.translator, this.warnings, {this.sheet});

  final ExcelFormulaTranslator translator;
  final ImportWarnings warnings;
  final String? sheet;

  void _warn(String code, String message, {String? range}) =>
      warnings.add(code, message, sheet: sheet, range: range);

  // ---------------------------------------------------------------------------
  // Data validation import.

  /// Converts a `<dataValidation>` (or x14 variant with `xm:f` formulas).
  IrDataValidation? importValidation(XmlElement dv) {
    final ranges = parseSqref(dv.attr('sqref') ?? dv.child('sqref')?.innerText);
    if (ranges.isEmpty) return null;
    String? formula(String name) {
      final e = dv.child(name);
      if (e == null) return null;
      final f = e.child('f');
      final t = (f ?? e).innerText.trim();
      return t.isEmpty ? null : t;
    }

    final f1 = formula('formula1');
    final f2 = formula('formula2');
    final type = dv.attr('type') ?? 'none';
    final op = dv.attr('operator') ?? 'between';
    final anchor = CellPos(ranges.first.top, ranges.first.left).a1;
    final extras = <String, Object?>{
      if (dv.attr('prompt') != null) 'prompt': dv.attr('prompt'),
      if (dv.attr('promptTitle') != null) 'promptTitle': dv.attr('promptTitle'),
      if (dv.attr('errorTitle') != null) 'errorTitle': dv.attr('errorTitle'),
      if (dv.attr('errorStyle') != null && dv.attr('errorStyle') != 'stop')
        'errorStyle': dv.attr('errorStyle'),
      if (dv.boolAttr('allowBlank') == false) 'allowBlank': false,
    };
    Map<String, Object?>? criteria;
    switch (type) {
      case 'list':
        if (f1 == null) return null;
        if (f1.startsWith('"')) {
          final inner = f1
              .substring(1, f1.endsWith('"') ? f1.length - 1 : f1.length)
              .replaceAll('""', '"');
          criteria = {
            'type': 'oneOfList',
            'options': [
              for (final o in inner.split(','))
                if (o.isNotEmpty) {'value': o},
            ],
          };
        } else {
          criteria = {
            'type': 'oneOfRange',
            'range': translator.importFormula(f1).formula,
          };
        }
      case 'whole' || 'decimal' || 'time':
        final t = _numOps[op] ?? 'numberBetween';
        criteria = {
          'type': t,
          'values': [
            if (f1 != null) _operand(f1, translator),
            if (f2 != null && t.contains('Between')) _operand(f2, translator),
          ],
        };
        if (type != 'decimal') extras['xlsxType'] = type;
        if (type == 'whole') {
          _warn(
            'wholeNumberValidation',
            'Whole-number validation imported as number validation',
          );
        }
      case 'date':
        if (op == 'notEqual') {
          criteria = {
            'type': 'dateNotBetween',
            'values': [
              if (f1 != null) _operand(f1, translator),
              if (f1 != null) _operand(f1, translator),
            ],
          };
        } else {
          final t = _dateOps[op] ?? 'dateBetween';
          criteria = {
            'type': t,
            'values': [
              if (f1 != null) _operand(f1, translator),
              if (f2 != null && t.contains('Between')) _operand(f2, translator),
            ],
          };
        }
      case 'textLength':
        final a = f1 == null ? '0' : translator.importFormula(f1).formula;
        final b = f2 == null ? null : translator.importFormula(f2).formula;
        final len = 'LEN($anchor)';
        final expr = switch (op) {
          'notBetween' => 'OR($len<$a,$len>$b)',
          'equal' => '$len=$a',
          'notEqual' => '$len<>$a',
          'greaterThan' => '$len>$a',
          'lessThan' => '$len<$a',
          'greaterThanOrEqual' => '$len>=$a',
          'lessThanOrEqual' => '$len<=$a',
          _ => 'AND($len>=$a,$len<=$b)',
        };
        criteria = {
          'type': 'customFormula',
          'values': [
            {'v': '=$expr'},
          ],
        };
        extras['xlsx'] = {
          'type': 'textLength',
          'operator': op,
          'formula1': ?f1,
          'formula2': ?f2,
        };
      case 'custom':
        if (f1 == null) return null;
        criteria = {
          'type': 'customFormula',
          'values': [
            {'v': '=${translator.importFormula(f1).formula}'},
          ],
        };
      default:
        return null;
    }
    final hideArrow = dv.boolAttr('showDropDown') ?? false;
    final isList = type == 'list';
    final showError = dv.boolAttr('showErrorMessage') ?? false;
    final style = dv.attr('errorStyle') ?? 'stop';
    return IrDataValidation(
      ranges: ranges,
      criteria: criteria,
      strict: showError && style == 'stop',
      showDropdown: isList && !hideArrow,
      displayStyle: isList ? (hideArrow ? 'plainText' : 'arrow') : null,
      helpText: dv.attr('error'),
      extras: extras,
    );
  }

  // ---------------------------------------------------------------------------
  // Data validation export.

  /// `<dataValidation>` XML of [v], or null when not representable.
  String? exportValidation(IrDataValidation v) {
    if (v.ranges.isEmpty) return null;
    final c = v.criteria;
    final type = c['type'] as String? ?? '';
    final values = (c['values'] as List?) ?? const [];
    final anchor = CellPos(v.ranges.first.top, v.ranges.first.left).a1;
    String? xType;
    String? op;
    String? f1;
    String? f2;
    final x = v.extras['xlsx'];
    if (x is Map && x['type'] == 'textLength') {
      xType = 'textLength';
      op = x['operator'] as String?;
      f1 = x['formula1'] as String?;
      f2 = x['formula2'] as String?;
    } else {
      switch (type) {
        case 'oneOfList':
          xType = 'list';
          final opts = [
            for (final o in (c['options'] as List?) ?? const [])
              if (o is Map) '${o['value']}' else '$o',
          ];
          final joined = opts.join(',');
          if (joined.length > 255) {
            _warn(
              'validationListTooLong',
              'Dropdown list longer than 255 characters was truncated for Excel',
            );
          }
          f1 = _quoted(joined.length > 255 ? joined.substring(0, 255) : joined);
        case 'oneOfRange':
          xType = 'list';
          final r = c['range']?.toString() ?? '';
          f1 = translator
              .exportFormula(r.startsWith('=') ? r.substring(1) : r)
              .formula;
        case 'checkbox':
          xType = 'list';
          final on = c['checked']?.toString();
          final off = c['unchecked']?.toString();
          f1 = _quoted(
            on == null && off == null
                ? 'TRUE,FALSE'
                : '${on ?? 'TRUE'},${off ?? 'FALSE'}',
          );
          _warn(
            'checkboxValidation',
            'Checkboxes were exported as TRUE/FALSE dropdowns',
          );
        case 'customFormula':
          xType = 'custom';
          f1 = _exportOperand(values.firstOrNull, translator);
        case 'textContains':
          xType = 'custom';
          f1 =
              'ISNUMBER(SEARCH(${_exportOperand(values.firstOrNull, translator)},$anchor))';
        case 'textNotContains':
          xType = 'custom';
          f1 =
              'ISERROR(SEARCH(${_exportOperand(values.firstOrNull, translator)},$anchor))';
        case 'textEq':
          xType = 'custom';
          f1 = '$anchor=${_exportOperand(values.firstOrNull, translator)}';
        case 'textIsEmail':
          xType = 'custom';
          f1 = 'ISNUMBER(MATCH("*@*.?*",$anchor,0))';
        case 'textIsUrl':
          xType = 'custom';
          f1 =
              'OR(LEFT($anchor,7)="http://",LEFT($anchor,8)="https://",LEFT($anchor,6)="ftp://",LEFT($anchor,4)="www.")';
        case 'dateIsValid':
          xType = 'date';
          op = 'greaterThan';
          f1 = '0';
        default:
          final num = _invert(_numOps)[type];
          final date = _invert(_dateOps)[type];
          if (num != null) {
            xType = v.extras['xlsxType'] as String? ?? 'decimal';
            op = num;
          } else if (date != null || type == 'dateNotBetween') {
            xType = 'date';
            op = date ?? 'notBetween';
          } else {
            _warn(
              'validationDropped',
              'Validation "$type" cannot be exported to Excel',
            );
            return null;
          }
          if (values.isNotEmpty) f1 = _exportOperand(values[0], translator);
          if (values.length > 1) f2 = _exportOperand(values[1], translator);
      }
    }
    final b = StringBuffer('<dataValidation type="$xType"');
    final style =
        v.extras['errorStyle'] as String? ?? (v.strict ? 'stop' : 'warning');
    if (style != 'stop') b.write(' errorStyle="$style"');
    if (op != null && op != 'between') b.write(' operator="$op"');
    if (v.extras['allowBlank'] != false) b.write(' allowBlank="1"');
    if (xType == 'list' && !v.showDropdown) b.write(' showDropDown="1"');
    final prompt = v.extras['prompt'] as String?;
    if (prompt != null) b.write(' showInputMessage="1"');
    b.write(' showErrorMessage="1"');
    final et = v.extras['errorTitle'] as String?;
    if (et != null) b.write(' errorTitle="${Ooxml.attr(et)}"');
    if (v.helpText != null) b.write(' error="${Ooxml.attr(v.helpText!)}"');
    final pt = v.extras['promptTitle'] as String?;
    if (pt != null) b.write(' promptTitle="${Ooxml.attr(pt)}"');
    if (prompt != null) b.write(' prompt="${Ooxml.attr(prompt)}"');
    b.write(' sqref="${formatSqref(v.ranges)}">');
    if (f1 != null) b.write('<formula1>${Ooxml.esc(f1)}</formula1>');
    if (f2 != null) b.write('<formula2>${Ooxml.esc(f2)}</formula2>');
    b.write('</dataValidation>');
    return b.toString();
  }

  // ---------------------------------------------------------------------------
  // Conditional formatting import.

  /// Converts one `<cfRule>` applying to [ranges]. [dxfs] are the styles'
  /// differential formats; [colors] resolves color scale colors.
  IrConditionalFormat? importConditionalFormat(
    XmlElement rule,
    List<IrRange> ranges,
    List<(Map<String, Object?>, Map<String, Object?>)> dxfs,
    ColorResolver colors,
  ) {
    if (ranges.isEmpty) return null;
    final type = rule.attr('type') ?? '';
    final first = ranges.first;
    final anchor = CellPos(first.top, first.left).a1;
    final abs = _absA1(first);
    final formulas = [
      for (final f in rule.elems('formula')) f.innerText.trim(),
    ];
    String tf(String f) => translator.importFormula(f).formula;
    Map<String, Object?> custom(String expr) => {
      'type': 'customFormula',
      'values': [
        {'v': '=$expr'},
      ],
    };
    final extras = <String, Object?>{};
    Map<String, Object?>? condition;
    Map<String, Object?>? ruleJson;
    final text = rule.attr('text') ?? '';
    switch (type) {
      case 'cellIs':
        final op = rule.attr('operator') ?? 'equal';
        if (formulas.isEmpty) return null;
        final f0 = formulas[0].trim();
        final isString =
            f0.startsWith('"') && f0.endsWith('"') && f0.length >= 2;
        if (isString && op == 'equal') {
          condition = {
            'type': 'textEq',
            'values': [_operand(f0, translator)],
          };
        } else if (isString) {
          condition = custom('$anchor${_cellIsOp(op)}${tf(f0)}');
        } else {
          final t = _numOps[op] ?? 'numberEq';
          condition = {
            'type': t,
            'values': [
              _operand(f0, translator),
              if (formulas.length > 1 && t.contains('Between'))
                _operand(formulas[1], translator),
            ],
          };
        }
      case 'expression':
        if (formulas.isEmpty) return null;
        condition = custom(tf(formulas[0]));
      case 'containsText':
        condition = {
          'type': 'textContains',
          'values': [
            {'v': text},
          ],
        };
      case 'notContainsText':
        condition = {
          'type': 'textNotContains',
          'values': [
            {'v': text},
          ],
        };
      case 'beginsWith':
        condition = {
          'type': 'textStartsWith',
          'values': [
            {'v': text},
          ],
        };
      case 'endsWith':
        condition = {
          'type': 'textEndsWith',
          'values': [
            {'v': text},
          ],
        };
      case 'containsBlanks':
        condition = {'type': 'blank', 'values': <Object?>[]};
      case 'notContainsBlanks':
        condition = {'type': 'notBlank', 'values': <Object?>[]};
      case 'containsErrors':
        condition = custom('ISERROR($anchor)');
      case 'notContainsErrors':
        condition = custom('NOT(ISERROR($anchor))');
      case 'timePeriod':
        final p = rule.attr('timePeriod');
        final rel = switch (p) {
          'today' => 'today',
          'yesterday' => 'yesterday',
          'tomorrow' => 'tomorrow',
          'last7Days' => 'pastWeek',
          _ => null,
        };
        if (rel != null) {
          condition = {
            'type': 'dateEq',
            'values': [
              {'rel': rel},
            ],
          };
        } else if (formulas.isNotEmpty) {
          condition = custom(tf(formulas[0]));
          extras['xlsx'] = {'type': 'timePeriod', 'timePeriod': p};
        } else {
          _warn('cfDropped', 'Conditional format "$type $p" was not imported');
          return null;
        }
      case 'top10':
        final n = rule.intAttr('rank') ?? 10;
        final bottom = rule.boolAttr('bottom') ?? false;
        final percent = rule.boolAttr('percent') ?? false;
        final expr = percent
            ? (bottom
                  ? '$anchor<=PERCENTILE($abs,${n / 100})'
                  : '$anchor>=PERCENTILE($abs,${1 - n / 100})')
            : (bottom
                  ? '$anchor<=SMALL($abs,MIN($n,COUNT($abs)))'
                  : '$anchor>=LARGE($abs,MIN($n,COUNT($abs)))');
        condition = custom(expr);
        extras['xlsx'] = {
          'type': 'top10',
          'rank': n,
          'bottom': bottom,
          'percent': percent,
        };
      case 'aboveAverage':
        final above = rule.boolAttr('aboveAverage') ?? true;
        final eq = rule.boolAttr('equalAverage') ?? false;
        final sd = rule.intAttr('stdDev');
        final avg = sd == null
            ? 'AVERAGE($abs)'
            : 'AVERAGE($abs)${above ? '+' : '-'}$sd*STDEV($abs)';
        final o = above ? (eq ? '>=' : '>') : (eq ? '<=' : '<');
        condition = custom('$anchor$o$avg');
        extras['xlsx'] = {
          'type': 'aboveAverage',
          'aboveAverage': above,
          'equalAverage': eq,
          'stdDev': ?sd,
        };
      case 'duplicateValues':
        condition = custom('COUNTIF($abs,$anchor)>1');
        extras['xlsx'] = {'type': 'duplicateValues'};
      case 'uniqueValues':
        condition = custom('COUNTIF($abs,$anchor)=1');
        extras['xlsx'] = {'type': 'uniqueValues'};
      case 'colorScale':
        final cs = rule.child('colorScale');
        if (cs == null) return null;
        final cfvos = cs.elems('cfvo').toList();
        final cols = cs.elems('color').toList();
        final points = <Map<String, Object?>>[];
        for (var i = 0; i < cfvos.length && i < cols.length; i++) {
          points.add(_cfvo(cfvos[i], tf)..['color'] = _hex(colors, cols[i]));
        }
        if (points.length < 2) return null;
        ruleJson = {'v': 1, 'type': 'colorScale', 'points': points};
      case 'dataBar':
        final db = rule.child('dataBar');
        if (db == null) return null;
        final cfvos = db.elems('cfvo').toList();
        ruleJson = {
          'v': 1,
          'type': 'dataBar',
          'min': cfvos.isNotEmpty ? _cfvo(cfvos[0], tf) : {'kind': 'min'},
          'max': cfvos.length > 1 ? _cfvo(cfvos[1], tf) : {'kind': 'max'},
          'color': _hex(colors, db.child('color')) ?? '#638EC6',
          'gradient': true,
          'axis': 'auto',
          'direction': 'context',
          'showValue': db.boolAttr('showValue') ?? true,
        };
      default:
        _warn(
          'cfDropped',
          'Conditional formats of type "$type" were not imported',
        );
        return null;
    }
    if (ruleJson == null) {
      final dxf = rule.intAttr('dxfId');
      final (fmt, dxfExtras) = dxf != null && dxf >= 0 && dxf < dxfs.length
          ? dxfs[dxf]
          : (const <String, Object?>{}, const <String, Object?>{});
      ruleJson = {
        'v': 1,
        'type': 'boolean',
        'condition': condition,
        'format': Map<String, Object?>.of(fmt),
        if (rule.boolAttr('stopIfTrue') ?? false) 'stopIfTrue': true,
      };
      if (dxfExtras.isNotEmpty) extras['dxf'] = dxfExtras;
    }
    return IrConditionalFormat(ranges: ranges, rule: ruleJson, extras: extras);
  }

  static String _cellIsOp(String op) => switch (op) {
    'notEqual' => '<>',
    'greaterThan' => '>',
    'lessThan' => '<',
    'greaterThanOrEqual' => '>=',
    'lessThanOrEqual' => '<=',
    _ => '=',
  };

  static String? _hex(ColorResolver colors, XmlElement? c) {
    if (c == null) return null;
    final noRefs = ColorResolver(
      theme: colors.theme,
      palette: colors.palette,
      themeReferences: false,
    );
    return noRefs.resolve(
      rgb: c.attr('rgb'),
      theme: c.attr('theme'),
      indexed: c.attr('indexed'),
      tint: c.attr('tint'),
    );
  }

  static Map<String, Object?> _cfvo(XmlElement v, String Function(String) tf) {
    final t = v.attr('type') ?? 'min';
    final val = v.attr('val');
    return switch (t) {
      'min' => {'kind': 'min'},
      'max' => {'kind': 'max'},
      'num' => {'kind': 'number', 'value': val ?? '0'},
      'percent' => {'kind': 'percent', 'value': val ?? '50'},
      'percentile' => {'kind': 'percentile', 'value': val ?? '50'},
      'formula' => {'kind': 'formula', 'value': '=${tf(val ?? '0')}'},
      _ => {'kind': t},
    };
  }

  // ---------------------------------------------------------------------------
  // Conditional formatting export.

  /// `<cfRule>` XML of [cf] with [priority]; [dxfId] maps a CF format (+dxf
  /// extras) to a dxf index. Null when not representable.
  String? exportConditionalFormat(
    IrConditionalFormat cf,
    int priority,
    int Function(Map<String, Object?> format, Map<String, Object?> extras)
    dxfId,
  ) {
    if (cf.ranges.isEmpty) return null;
    final r = cf.rule;
    final type = r['type'];
    final first = cf.ranges.first;
    final anchor = CellPos(first.top, first.left).a1;
    if (type == 'colorScale') {
      final points = (r['points'] as List?) ?? const [];
      final b = StringBuffer(
        '<cfRule type="colorScale" priority="$priority"><colorScale>',
      );
      for (final p in points) {
        b.write(_exportCfvo(p as Map));
      }
      for (final p in points) {
        b.write(
          '<color rgb="${ExcelColors.toArgb(_solid((p as Map)['color']?.toString()))}"/>',
        );
      }
      b.write('</colorScale></cfRule>');
      return b.toString();
    }
    if (type == 'dataBar') {
      return '<cfRule type="dataBar" priority="$priority"><dataBar${r['showValue'] == false ? ' showValue="0"' : ''}>'
          '${_exportCfvo(r['min'] as Map? ?? const {'kind': 'min'})}${_exportCfvo(r['max'] as Map? ?? const {'kind': 'max'})}'
          '<color rgb="${ExcelColors.toArgb(_solid(r['color']?.toString()))}"/></dataBar></cfRule>';
    }
    if (type != 'boolean') {
      _warn(
        'cfDropped',
        'Conditional formats of type "$type" were not exported',
      );
      return null;
    }
    final cond = (r['condition'] as Map?) ?? const {};
    final values = (cond['values'] as List?) ?? const [];
    final dxfExtras =
        (cf.extras['dxf'] as Map?)?.cast<String, Object?>() ?? const {};
    final dxf = dxfId(
      (r['format'] as Map?)?.cast<String, Object?>() ?? const {},
      dxfExtras,
    );
    final stop = r['stopIfTrue'] == true ? ' stopIfTrue="1"' : '';
    final head = 'dxfId="$dxf" priority="$priority"$stop';
    String op(Object? v) => _exportOperand(v, translator);
    String text(Object? v) {
      final m = v is Map ? v['v'] : v;
      return m?.toString() ?? '';
    }

    final x = cf.extras['xlsx'];
    if (x is Map) {
      final xt = x['type'];
      if (xt == 'top10') {
        return '<cfRule type="top10" $head${x['percent'] == true ? ' percent="1"' : ''}${x['bottom'] == true ? ' bottom="1"' : ''} rank="${x['rank']}"/>';
      }
      if (xt == 'aboveAverage') {
        return '<cfRule type="aboveAverage" $head${x['aboveAverage'] == false ? ' aboveAverage="0"' : ''}'
            '${x['equalAverage'] == true ? ' equalAverage="1"' : ''}${x['stdDev'] != null ? ' stdDev="${x['stdDev']}"' : ''}/>';
      }
      if (xt == 'duplicateValues' || xt == 'uniqueValues') {
        return '<cfRule type="$xt" $head/>';
      }
      if (xt == 'timePeriod') {
        return '<cfRule type="timePeriod" $head timePeriod="${x['timePeriod']}"><formula>${Ooxml.esc(op(values.firstOrNull))}</formula></cfRule>';
      }
    }
    String expr(String f) =>
        '<cfRule type="expression" $head><formula>${Ooxml.esc(f)}</formula></cfRule>';
    String textRule(String t, String opAttr, String f) {
      final s = text(values.firstOrNull);
      return '<cfRule type="$t" $head operator="$opAttr" text="${Ooxml.attr(s)}"><formula>${Ooxml.esc(f.replaceAll('#T#', _quoted(s)))}</formula></cfRule>';
    }

    final ct = cond['type'];
    switch (ct) {
      case 'customFormula':
        return expr(op(values.firstOrNull));
      case 'textContains':
        return textRule(
          'containsText',
          'containsText',
          'NOT(ISERROR(SEARCH(#T#,$anchor)))',
        );
      case 'textNotContains':
        return textRule(
          'notContainsText',
          'notContains',
          'ISERROR(SEARCH(#T#,$anchor))',
        );
      case 'textStartsWith':
        return textRule(
          'beginsWith',
          'beginsWith',
          'LEFT($anchor,LEN(#T#))=#T#',
        );
      case 'textEndsWith':
        return textRule('endsWith', 'endsWith', 'RIGHT($anchor,LEN(#T#))=#T#');
      case 'textEq':
        return '<cfRule type="cellIs" $head operator="equal"><formula>${Ooxml.esc(_quoted(text(values.firstOrNull)))}</formula></cfRule>';
      case 'blank':
        return '<cfRule type="containsBlanks" $head><formula>LEN(TRIM($anchor))=0</formula></cfRule>';
      case 'notBlank':
        return '<cfRule type="notContainsBlanks" $head><formula>LEN(TRIM($anchor))&gt;0</formula></cfRule>';
      case 'dateEq' || 'dateBefore' || 'dateAfter':
        final v0 = values.firstOrNull;
        final rel = v0 is Map ? v0['rel'] : null;
        if (rel != null) {
          final today = 'TODAY()';
          final d = 'FLOOR($anchor,1)';
          if (ct == 'dateEq') {
            final period = switch (rel) {
              'today' => ('today', '$d=$today'),
              'yesterday' => ('yesterday', '$d=$today-1'),
              'tomorrow' => ('tomorrow', '$d=$today+1'),
              'pastWeek' => ('last7Days', 'AND($today-$d<=6,$d<=$today)'),
              _ => (
                null,
                rel == 'pastMonth'
                    ? 'AND($d>=EDATE($today,-1),$d<=$today)'
                    : 'AND($d>=EDATE($today,-12),$d<=$today)',
              ),
            };
            if (period.$1 != null) {
              return '<cfRule type="timePeriod" $head timePeriod="${period.$1}"><formula>${Ooxml.esc(period.$2)}</formula></cfRule>';
            }
            return expr(period.$2);
          }
          final ref = switch (rel) {
            'today' => today,
            'yesterday' => '$today-1',
            'tomorrow' => '$today+1',
            'pastWeek' => '$today-7',
            'pastMonth' => 'EDATE($today,-1)',
            _ => 'EDATE($today,-12)',
          };
          return expr('$d${ct == 'dateBefore' ? '<' : '>'}$ref');
        }
        final opAttr = ct == 'dateEq'
            ? 'equal'
            : (ct == 'dateBefore' ? 'lessThan' : 'greaterThan');
        return '<cfRule type="cellIs" $head operator="$opAttr"><formula>${Ooxml.esc(op(v0))}</formula></cfRule>';
      default:
        final xop = _invert(_numOps)[ct];
        if (xop == null) {
          _warn(
            'cfDropped',
            'Conditional format condition "$ct" was not exported',
          );
          return null;
        }
        final b = StringBuffer('<cfRule type="cellIs" $head operator="$xop">');
        for (final v in values.take(xop.contains('etween') ? 2 : 1)) {
          b.write('<formula>${Ooxml.esc(op(v))}</formula>');
        }
        b.write('</cfRule>');
        return b.toString();
    }
  }

  String _exportCfvo(Map<Object?, Object?> p) {
    final kind = p['kind'];
    final value = p['value']?.toString();
    final t = switch (kind) {
      'number' => 'num',
      'percent' => 'percent',
      'percentile' => 'percentile',
      'formula' => 'formula',
      'max' => 'max',
      _ => 'min',
    };
    if (value == null || t == 'min' || t == 'max') return '<cfvo type="$t"/>';
    final v = value.startsWith('=')
        ? translator.exportFormula(value.substring(1)).formula
        : value;
    return '<cfvo type="$t" val="${Ooxml.attr(v)}"/>';
  }

  static String _solid(String? c) =>
      c != null && RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(c) ? c : '#000000';

  // ---------------------------------------------------------------------------
  // AutoFilter.

  /// Converts `<autoFilter>`; [displayText] renders a data cell of the sheet
  /// as displayed (for values criteria) and [dataRows] lists the data row
  /// indices of the filter range.
  IrFilter? importFilter(
    XmlElement af,
    String Function(int row, int col) displayText,
  ) {
    final ranges = parseSqref(af.attr('ref'));
    if (ranges.isEmpty) return null;
    final range = ranges.first;
    final filter = IrFilter(range: range);
    for (final fc in af.elems('filterColumn')) {
      final colId = fc.intAttr('colId') ?? 0;
      final filters = fc.child('filters');
      if (filters != null) {
        if (filters.elems('dateGroupItem').isNotEmpty) {
          _warn(
            'filterDropped',
            'Date-group filter criteria were not imported',
          );
          continue;
        }
        final shown = <String>{
          for (final f in filters.elems('filter'))
            if (f.attr('val') != null) f.attr('val')!,
        };
        if (filters.boolAttr('blank') ?? false) shown.add('');
        final all = <String>{};
        final col = range.left + colId;
        if (range.isBounded) {
          for (var r = range.top + 1; r <= range.r2!; r++) {
            all.add(displayText(r, col));
          }
        }
        final hidden = [
          for (final v in all)
            if (!shown.contains(v)) v,
        ]..sort();
        filter.criteria[colId] = {'hiddenValues': hidden};
        continue;
      }
      final cfs = fc.child('customFilters');
      if (cfs != null) {
        final conds = cfs.elems('customFilter').toList();
        final and = cfs.boolAttr('and') ?? false;
        final c = _customFilter(conds, and);
        if (c == null) {
          _warn('filterDropped', 'Custom filter criteria were simplified away');
        } else {
          filter.criteria[colId] = {'condition': c};
        }
        continue;
      }
      _warn(
        'filterDropped',
        'Top-10, dynamic and color filter criteria were not imported',
      );
    }
    return filter;
  }

  Map<String, Object?>? _customFilter(List<XmlElement> conds, bool and) {
    (String, String)? one(XmlElement e) =>
        (e.attr('operator') ?? 'equal', e.attr('val') ?? '');
    if (conds.length == 1) {
      final (op, val) = one(conds.first)!;
      return _filterCondition(op, val);
    }
    if (conds.length == 2 && and) {
      final a = one(conds[0])!, b = one(conds[1])!;
      if (a.$1 == 'greaterThanOrEqual' && b.$1 == 'lessThanOrEqual') {
        return {
          'type': 'numberBetween',
          'values': [
            {'v': a.$2},
            {'v': b.$2},
          ],
        };
      }
    }
    if (conds.length == 2 && !and) {
      final a = one(conds[0])!, b = one(conds[1])!;
      if (a.$1 == 'lessThan' && b.$1 == 'greaterThan') {
        return {
          'type': 'numberNotBetween',
          'values': [
            {'v': a.$2},
            {'v': b.$2},
          ],
        };
      }
    }
    return null;
  }

  static Map<String, Object?>? _filterCondition(String op, String val) {
    final starts = val.startsWith('*');
    final ends = val.endsWith('*') && val.length > 1;
    final core = val.replaceAll(RegExp(r'^\*|\*$'), '');
    Map<String, Object?> c(String t, [String? v]) => {
      'type': t,
      'values': [
        if (v != null) {'v': v},
      ],
    };
    if (op == 'equal' || op == 'notEqual') {
      final neg = op == 'notEqual';
      if (starts && ends) {
        return c(neg ? 'textNotContains' : 'textContains', core);
      }
      if (!neg && ends) return c('textStartsWith', core);
      if (!neg && starts) return c('textEndsWith', core);
      if (val == '' && !neg) return c('blank');
      if (val == '' && neg) return c('notBlank');
      if (double.tryParse(val) != null) {
        return c(neg ? 'numberNotEq' : 'numberEq', val);
      }
      return neg ? null : c('textEq', val);
    }
    final t = _numOps[op];
    return t == null ? null : c(t, val);
  }

  /// `<autoFilter>` XML of [f]; [displayText] renders data cells.
  String exportFilter(
    IrFilter f,
    String Function(int row, int col) displayText, {
    required int lastRow,
  }) {
    final range = f.range.isBounded
        ? f.range
        : IrRange(
            f.range.r1 ?? 0,
            f.range.c1 ?? 0,
            f.range.r2 ?? lastRow,
            f.range.c2 ?? f.range.c1 ?? 0,
          );
    final b = StringBuffer('<autoFilter ref="${range.toA1()}"');
    if (f.criteria.isEmpty) {
      b.write('/>');
      return b.toString();
    }
    b.write('>');
    final keys = f.criteria.keys.toList()..sort();
    for (final k in keys) {
      final c = f.criteria[k]!;
      final hidden = ((c['hiddenValues'] as List?) ?? const [])
          .map((e) => '$e')
          .toSet();
      final cond = c['condition'] as Map?;
      if (hidden.isNotEmpty) {
        final all = <String>{};
        for (var r = range.top + 1; r <= range.r2!; r++) {
          all.add(displayText(r, range.left + k));
        }
        final shown = [
          for (final v in all)
            if (!hidden.contains(v)) v,
        ]..sort();
        b.write(
          '<filterColumn colId="$k"><filters${shown.contains('') ? ' blank="1"' : ''}>',
        );
        for (final v in shown) {
          if (v.isNotEmpty) b.write('<filter val="${Ooxml.attr(v)}"/>');
        }
        b.write('</filters></filterColumn>');
      } else if (cond != null) {
        final xml = _exportFilterCondition(cond);
        if (xml == null) {
          _warn(
            'filterDropped',
            'Filter condition "${cond['type']}" was not exported',
          );
          continue;
        }
        b.write('<filterColumn colId="$k">$xml</filterColumn>');
      }
    }
    b.write('</autoFilter>');
    return b.toString();
  }

  static String? _exportFilterCondition(Map<Object?, Object?> cond) {
    final values = [
      for (final v in (cond['values'] as List?) ?? const [])
        (v is Map ? v['v'] : v)?.toString() ?? '',
    ];
    String one(String op, String val) =>
        '<customFilters><customFilter operator="$op" val="${Ooxml.attr(val)}"/></customFilters>';
    final v0 = values.firstOrNull ?? '';
    switch (cond['type']) {
      case 'textContains':
        return one('equal', '*$v0*');
      case 'textNotContains':
        return one('notEqual', '*$v0*');
      case 'textStartsWith':
        return one('equal', '$v0*');
      case 'textEndsWith':
        return one('equal', '*$v0');
      case 'textEq':
        return one('equal', v0);
      case 'blank':
        return '<filters blank="1"/>';
      case 'notBlank':
        return one('notEqual', ' ');
      case 'numberBetween':
        if (values.length < 2) return null;
        return '<customFilters and="1"><customFilter operator="greaterThanOrEqual" val="${values[0]}"/>'
            '<customFilter operator="lessThanOrEqual" val="${values[1]}"/></customFilters>';
      case 'numberNotBetween':
        if (values.length < 2) return null;
        return '<customFilters><customFilter operator="lessThan" val="${values[0]}"/>'
            '<customFilter operator="greaterThan" val="${values[1]}"/></customFilters>';
      default:
        final op = _invert(_numOps)[cond['type']];
        if (op == null || v0.startsWith('=')) return null;
        return one(op, v0);
    }
  }
}

/// Display text of an IR cell (filter values, CSV) using the number
/// formatter.
String irDisplayText(
  WorkbookDocument doc,
  IrCell? cell, {
  String locale = 'en_US',
}) {
  final v = cell?.value;
  if (v == null) return '';
  final cv = v.toCellValue();
  if (cv is NumberValue) {
    final pattern =
        doc.formats[cell!.format].attrs.toMap()['numberFormat'] as String?;
    return NumberFormatter.instance.formatText(cv, pattern, locale: locale);
  }
  return v.plainText;
}
