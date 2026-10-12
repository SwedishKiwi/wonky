import 'dart:typed_data';

import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/src/addressing/grid_geometry.dart';
import 'package:wonky_sheets_core/src/io/io.dart';

/// A 1×1 transparent PNG.
final Uint8List kTinyPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4,
  0x89, 0x00, 0x00, 0x00, 0x0a, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0d, 0x0a, 0x2d, 0xb4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae,
  0x42, 0x60, 0x82,
]);

/// Builds IR documents of the round-trip corpus (11 §12 categories).
abstract final class IrCorpus {
  static int _fmt(WorkbookDocument d, Map<FormatAttr, Object?> attrs, [Map<String, Object?> extras = const {}]) =>
      d.formats.intern(IrFormat(CellFormat(attrs), extras));

  /// A sheet with the XLSX default sizes.
  static IrSheet sheet(String name) => IrSheet(name)
    ..defaultRowHeight = 20
    ..defaultColumnWidth = 64;

  static WorkbookDocument _doc() => WorkbookDocument(title: 'Corpus', locale: 'en_US')
    ..defaultFontFamily = 'Calibri'
    ..defaultFontSize = 11;

  /// Types and dates.
  static WorkbookDocument typesAndDates() {
    final d = _doc();
    final s = sheet('Types');
    final date = _fmt(d, {FormatAttr.numberFormat: 'yyyy-mm-dd'});
    final dt = _fmt(d, {FormatAttr.numberFormat: 'preset:date'});
    s.cells
      ..set(0, 0, const IrCell(value: IrNumber(42)))
      ..set(0, 1, const IrCell(value: IrNumber(-3.25)))
      ..set(0, 2, const IrCell(value: IrNumber(1e-7)))
      ..set(0, 3, const IrCell(value: IrNumber(123456789012.5)))
      ..set(1, 0, const IrCell(value: IrText('Hello')))
      ..set(1, 1, const IrCell(value: IrText('  padded  ')))
      ..set(1, 2, const IrCell(value: IrText('Ünïcødé ✓ 漢字')))
      ..set(1, 3, const IrCell(value: IrText('a<b>&"c"')))
      ..set(2, 0, const IrCell(value: IrBool(true)))
      ..set(2, 1, const IrCell(value: IrBool(false)))
      ..set(2, 2, const IrCell(value: IrError(CellErrorKind.na)))
      ..set(2, 3, const IrCell(value: IrError(CellErrorKind.div0)))
      ..set(3, 0, IrCell(value: const IrNumber(46115), format: date))
      ..set(3, 1, IrCell(value: const IrNumber(30), format: date))
      ..set(3, 2, IrCell(value: const IrNumber(46115.75), format: dt))
      ..set(4, 0, const IrCell(value: IrText('line1\nline2')))
      ..set(4, 1, const IrCell(value: IrText('_x0041_ literal')));
    d.sheets.add(s);
    return d;
  }

  /// Number formats, fonts, fills, borders and alignment.
  static WorkbookDocument styles() {
    final d = _doc();
    final s = sheet('Styles');
    final formats = <Map<FormatAttr, Object?>>[
      {FormatAttr.numberFormat: '#,##0.00'},
      {FormatAttr.numberFormat: '0.0%'},
      {FormatAttr.numberFormat: '[Red]#,##0;(#,##0)'},
      {FormatAttr.numberFormat: r'#,##0.00 [$€-407]'},
      {FormatAttr.numberFormat: '@'},
      {FormatAttr.bold: true, FormatAttr.italic: true},
      {FormatAttr.underline: true, FormatAttr.strikethrough: true},
      {FormatAttr.fontFamily: 'Arial', FormatAttr.fontSize: 14.0, FormatAttr.textColor: '#FF0000'},
      {FormatAttr.fillColor: '#FCE8B2'},
      {FormatAttr.fillColor: 'theme:accent1', FormatAttr.textColor: 'theme:accent2'},
      {FormatAttr.borderTop: 'thin|#000000', FormatAttr.borderBottom: 'double|auto', FormatAttr.borderLeft: 'dashed|#00FF00', FormatAttr.borderRight: 'thick|theme:accent3'},
      {FormatAttr.hAlign: HorizontalAlign.center, FormatAttr.vAlign: VerticalAlign.top, FormatAttr.wrap: WrapStrategy.wrap},
      {FormatAttr.hAlign: HorizontalAlign.right, FormatAttr.vAlign: VerticalAlign.middle, FormatAttr.rotation: 45},
      {FormatAttr.rotation: -30},
      {FormatAttr.rotation: 255},
      {FormatAttr.borderTop: 'medium|#123456', FormatAttr.borderBottom: 'dotted|#654321'},
    ];
    for (var i = 0; i < formats.length; i++) {
      s.cells.set(i, 0, IrCell(value: IrNumber(i * 1000.5), format: _fmt(d, formats[i])));
    }
    s.cells.set(0, 1, IrCell(value: const IrText('indented'), format: _fmt(d, {FormatAttr.hAlign: HorizontalAlign.left}, {'indent': 2})));
    d.sheets.add(s);
    return d;
  }

  /// Structure: merges, sizes, hidden, outline, frozen, view flags.
  static WorkbookDocument structure() {
    final d = _doc();
    final s = IrSheet('Structure')
      ..frozenRows = 2
      ..frozenColumns = 1
      ..showGridlines = false
      ..tabColor = '#FF6D01'
      ..defaultRowHeight = 21
      ..defaultColumnWidth = 100;
    s.cells.set(0, 0, const IrCell(value: IrText('Merged')));
    s.cells.set(5, 5, const IrCell(value: IrNumber(1)));
    s.merges.add(const GridRect(0, 0, 1, 2));
    s.rows[3] = const IrDim(size: 40);
    s.rows[4] = const IrDim(hidden: true);
    s.rows[6] = const IrDim(outlineLevel: 1);
    s.rows[7] = const IrDim(outlineLevel: 2);
    s.columns[1] = const IrDim(size: 150);
    s.columns[2] = const IrDim(hidden: true);
    s.columns[3] = IrDim(format: _fmt(d, {FormatAttr.bold: true}));
    s.rows[8] = IrDim(format: _fmt(d, {FormatAttr.fillColor: '#EEEEEE'}));
    final rtl = sheet('رتل')..rtl = true;
    rtl.cells.set(0, 0, const IrCell(value: IrText('يمين')));
    final hidden = sheet('Hidden calc')..hidden = true;
    hidden.cells.set(0, 0, const IrCell(value: IrNumber(7)));
    d.sheets.addAll([s, rtl, hidden]);
    return d;
  }

  /// Formulas incl. cross-sheet, array and dynamic array, names.
  static WorkbookDocument formulas() {
    final d = _doc();
    final a = sheet('Data');
    final b = sheet('Q3 plan');
    for (var r = 0; r < 5; r++) {
      a.cells.set(r, 0, IrCell(value: IrNumber(r + 1.0)));
      a.cells.set(r, 1, IrCell(formulaA1: 'A${r + 1}*2', value: IrNumber((r + 1) * 2.0)));
    }
    a.cells.set(5, 0, const IrCell(formulaA1: 'SUM(A1:A5)', value: IrNumber(15)));
    a.cells.set(5, 1, const IrCell(formulaA1: "'Q3 plan'!A1&\"x\"", value: IrText('hix')));
    a.cells.set(6, 0, const IrCell(formulaA1: 'IFS(A1>0,"pos",TRUE,"neg")', value: IrText('pos')));
    a.cells.set(6, 1, const IrCell(formulaA1: 'XLOOKUP(3,A1:A5,B1:B5)', value: IrNumber(6)));
    a.cells.set(7, 0, const IrCell(formulaA1: 'LET(x,A1,y,2,x*y)', value: IrNumber(2)));
    a.cells.set(7, 1, const IrCell(formulaA1: 'ISERROR(1/0)', value: IrBool(true)));
    a.cells.set(8, 0, const IrCell(formulaA1: 'ARRAYFORMULA(A1:A3*10)', formulaKind: IrFormulaKind.array, arrayRef: GridRect(8, 0, 10, 0), value: IrNumber(10)));
    a.cells.set(8, 2, const IrCell(formulaA1: 'SEQUENCE(3)', formulaKind: IrFormulaKind.dynamicArray, arrayRef: GridRect(8, 2, 10, 2), value: IrNumber(1)));
    a.cells.set(11, 0, const IrCell(formulaA1: 'SUM(Total)', value: IrNumber(15)));
    a.cells.set(11, 1, const IrCell(formulaA1: 'SUM(\$A\$1:A2)', value: IrNumber(3)));
    a.cells.set(12, 0, const IrCell(formulaA1: '1/0', value: IrError(CellErrorKind.div0)));
    b.cells.set(0, 0, const IrCell(value: IrText('hi')));
    d.sheets.addAll([a, b]);
    d.namedRanges
      ..add(IrNamedRange(name: 'Total', sheet: 'Data', range: IrRange(0, 0, 4, 0)))
      ..add(IrNamedRange(name: 'Plan', sheet: 'Q3 plan', range: IrRange.columns(0, 1), comment: 'whole columns'))
      ..add(const IrNamedRange(name: 'Rate', formulaA1: '0.19'));
    return d;
  }

  /// Rules: DV, CF, filter, hyperlinks, notes, rich text, image, print.
  static WorkbookDocument rules() {
    final d = _doc();
    final s = sheet('Rules');
    final lists = sheet('Lists');
    for (var r = 0; r < 6; r++) {
      s.cells.set(r, 0, IrCell(value: r == 0 ? const IrText('Status') : IrText(r.isEven ? 'Open' : 'Closed')));
      s.cells.set(r, 1, IrCell(value: r == 0 ? const IrText('Amount') : IrNumber(r * 50.0)));
    }
    lists.cells.set(0, 0, const IrCell(value: IrText('Open')));
    lists.cells.set(1, 0, const IrCell(value: IrText('Closed')));
    s.validations
      ..add(IrDataValidation(
        ranges: [IrRange(1, 0, 5, 0)],
        criteria: {
          'type': 'oneOfList',
          'options': [
            {'value': 'Open'},
            {'value': 'Closed'},
          ],
        },
        strict: true,
        displayStyle: 'arrow',
        helpText: 'Pick one',
      ))
      ..add(IrDataValidation(
        ranges: [IrRange(1, 1, 5, 1)],
        criteria: {
          'type': 'numberBetween',
          'values': [
            {'v': '0'},
            {'v': '1000'},
          ],
        },
        showDropdown: false,
      ))
      ..add(IrDataValidation(
        ranges: [IrRange(1, 2, 5, 2)],
        criteria: {'type': 'oneOfRange', 'range': r'Lists!$A$1:$A$2'},
        displayStyle: 'arrow',
      ))
      ..add(IrDataValidation(
        ranges: [IrRange(1, 3, 5, 3)],
        criteria: {
          'type': 'customFormula',
          'values': [
            {'v': '=D2>B2'},
          ],
        },
        strict: true,
        showDropdown: false,
      ));
    s.conditionalFormats
      ..add(IrConditionalFormat(ranges: [IrRange(1, 1, 5, 1)], rule: {
        'v': 1,
        'type': 'boolean',
        'condition': {
          'type': 'numberGreater',
          'values': [
            {'v': '100'},
          ],
        },
        'format': {'bold': true, 'fillColor': '#FCE8E6', 'textColor': '#B31412'},
        'stopIfTrue': true,
      }))
      ..add(IrConditionalFormat(ranges: [IrRange(1, 0, 5, 0)], rule: {
        'v': 1,
        'type': 'boolean',
        'condition': {
          'type': 'textContains',
          'values': [
            {'v': 'Op'},
          ],
        },
        'format': {'italic': true},
      }))
      ..add(IrConditionalFormat(ranges: [IrRange(1, 0, 5, 1)], rule: {
        'v': 1,
        'type': 'boolean',
        'condition': {
          'type': 'customFormula',
          'values': [
            {'v': r'=$B2>200'},
          ],
        },
        'format': {'strikethrough': true},
      }))
      ..add(IrConditionalFormat(ranges: [IrRange(1, 1, 5, 1)], rule: {
        'v': 1,
        'type': 'colorScale',
        'points': [
          {'kind': 'min', 'color': '#FFFFFF'},
          {'kind': 'percentile', 'value': '50', 'color': '#FFD666'},
          {'kind': 'max', 'color': '#57BB8A'},
        ],
      }))
      ..add(IrConditionalFormat(ranges: [IrRange(1, 0, 5, 0)], rule: {
        'v': 1,
        'type': 'boolean',
        'condition': {'type': 'blank', 'values': <Object?>[]},
        'format': {'fillColor': '#EEEEEE'},
      }));
    s.autoFilter = IrFilter(range: IrRange(0, 0, 5, 1), criteria: {
      1: {
        'condition': {
          'type': 'numberGreater',
          'values': [
            {'v': '60'},
          ],
        },
      },
    });
    s.cells.set(7, 0, const IrCell(value: IrText('Wonky'), link: 'https://example.com/a?b=1&c=2'));
    s.cells.set(7, 1, const IrCell(value: IrText('Go'), link: "#'Lists'!A1"));
    s.cells.set(8, 0, const IrCell(value: IrNumber(1), note: 'A note\nwith two lines'));
    s.cells.set(
      9,
      0,
      IrCell(
        value: IrRich(RichText('Total revenue', [
          const RichRun(0, 5, {'bold': true}),
          const RichRun(6, 13, {'textColor': '#D93025', 'italic': true}),
        ])),
      ),
    );
    s.images.add(IrImage(bytes: kTinyPng, anchor: const IrAnchor(row: 10, col: 1, dx: 4, dy: 2, width: 32, height: 16), altText: 'dot'));
    s.print = {
      'paper': 'a4',
      'orientation': 'landscape',
      'scale': {'mode': 'fitWidth'},
      'gridlines': true,
      'margins': {'preset': 'custom', 'top': 1.0, 'bottom': 1.0, 'left': 0.5, 'right': 0.5, 'unit': 'in'},
      'headerFooter': {
        'header': {'left': '{sheet}', 'center': '', 'right': ''},
        'footer': {'left': '', 'center': 'Page {page} of {pages}', 'right': ''},
        'flags': {'pageNumbers': false, 'title': false, 'sheetName': false, 'date': false, 'time': false},
      },
      'pageBreaks': {
        'rows': [3],
        'cols': <int>[],
      },
      'repeatRows': {'start': 0, 'end': 0},
      'printArea': 'A1:B6',
    };
    d.sheets.addAll([s, lists]);
    return d;
  }

  /// All corpus documents by name.
  static Map<String, WorkbookDocument Function()> get all => {
    'typesAndDates': typesAndDates,
    'styles': styles,
    'structure': structure,
    'formulas': formulas,
    'rules': rules,
  };
}
