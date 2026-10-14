import 'dart:io';

import 'package:test/test.dart';
import 'package:wonky_sheets_script/wonky_sheets_script.dart';

import '../../tool/gen_api_index.dart' as gen;

void main() {
  group('Given the generated API index', () {
    test('when regenerated then the checked-in file is current', () {
      final current = File(
        'lib/src/api/api_index_data.dart',
      ).readAsStringSync();
      expect(
        current,
        gen.apiIndexDataSource(),
        reason:
            'Run `dart run tool/gen_api_index.dart` in wonky_sheets_script.',
      );
    });

    test(
      'when a class is looked up then members carry signatures and docs',
      () {
        final index = ApiIndex.standard;
        final ss = index.classNamed('Spreadsheet')!;
        expect(ss.summary, 'The bound spreadsheet.');
        final getRange = index.member('Spreadsheet', 'getRange')!;
        expect(
          getRange.signature('Spreadsheet'),
          'Range getRange(String a1Notation)',
        );
        expect(getRange.doc, contains('Sheet1!A1:B10'));
        final name = index.member('Spreadsheet', 'name')!;
        expect(name.kind, ApiMemberKind.field);
        expect(name.signature(), 'String name');
        final active = index.member('SpreadsheetApp', 'active')!;
        expect(active.isStatic, isTrue);
        expect(active.signature(), 'static Spreadsheet get active');
        final sort = index.member('Sheet', 'sort')!;
        expect(
          sort.signature(),
          'void sort(int column, {bool ascending = true})',
        );
      },
    );

    test(
      'when an exception class is listed then inherited members resolve',
      () {
        final members = ApiIndex.standard.membersOf('RangeException');
        expect(members.map((m) => m.name), containsAll(['code', 'message']));
      },
    );

    test('when the new object API is indexed then it is listed', () {
      final index = ApiIndex.standard;
      expect(index.member('Sheet', 'newChart')!.type, 'EmbeddedChartBuilder');
      expect(index.member('Range', 'createFilter')!.type, 'Filter');
      expect(index.classNamed('LockService'), isNotNull);
      expect(index.classNamed('_Handle'), isNull);
      expect(index.classNamed('CellError')!.members, hasLength(3));
    });
  });

  group('Given script completion', () {
    final c = ScriptCompletion(
      project: const [ProjectSymbol('archive', signature: 'void archive()')],
    );

    List<String> labels(String text) {
      final at = text.indexOf('|');
      final src = text.replaceFirst('|', '');
      return [
        for (final i in c.complete(src, at)?.items ?? const <CompletionItem>[])
          i.label,
      ];
    }

    test('when a static receiver is typed then static members are listed', () {
      expect(
        labels('void f() { SpreadsheetApp.| }'),
        containsAll(['active', 'ui', 'flush']),
      );
    });

    test('when a getter chain is typed then the return type is used', () {
      final l = labels('void f() { SpreadsheetApp.active.get| }');
      expect(l, containsAll(['getRange', 'getRangeList', 'getRangeByName']));
      expect(l, isNot(contains('active')));
    });

    test('when a local is assigned from a call then its type is inferred', () {
      final l = labels('''
void f() {
  final ss = SpreadsheetApp.active;
  final s = ss.sheetByName('x')!;
  s.|
}''');
      expect(l, containsAll(['getRange', 'lastRow', 'newChart', 'protect']));
    });

    test('when a parameter has an explicit type then it is used', () {
      expect(labels('void onEdit(EditEvent e) { e.ra| }'), ['range']);
    });

    test(
      'when a for-in loop iterates a list then the element type is used',
      () {
        final l = labels('''
void f() {
  for (final sheet in SpreadsheetApp.active.sheets) {
    sheet.hid|
  }
}''');
        expect(l, unorderedEquals(['hideRows', 'hideColumns', 'hide']));
      },
    );

    test('when a call result is chained then the method return type is used', () {
      expect(
        labels(
          "void f() { SpreadsheetApp.activeSheet.getRange('A1').offset(1, 0).val| }",
        ),
        containsAll(['value', 'values']),
      );
    });

    test('when a builder is chained then the builder type is kept', () {
      expect(
        labels(
          'void f() { ConditionalFormatRuleBuilder().whenCellEmpty().setB| }',
        ),
        containsAll(['setBackground', 'setBold']),
      );
    });

    test(
      'when a bare prefix is typed then classes, locals and keywords match',
      () {
        final l = labels('void f() { final total = 1; Spr| }');
        expect(l.first, 'SpreadsheetApp');
        expect(labels('void f() { final total = 1; to| }'), contains('total'));
        expect(labels('void f() { arc| }'), contains('archive'));
        expect(labels('void f() { ret| }'), contains('return'));
      },
    );

    test(
      'when the cursor is in a string or comment then nothing is proposed',
      () {
        expect(c.complete("var x = 'Spr", 12), isNull);
        expect(c.complete('// Spr', 6), isNull);
      },
    );

    test('when the receiver is unknown then file identifiers are proposed', () {
      expect(
        labels('void f() { totalAmount = 1; mystery.tot| }'),
        contains('totalAmount'),
      );
    });

    test(
      'when a method is completed then the cursor lands inside the parens',
      () {
        final r = c.complete(
          'void f() { SpreadsheetApp.active.getRange }',
          41,
        )!;
        final item = r.items.firstWhere((i) => i.label == 'getRange');
        expect(item.insertText, 'getRange()');
        expect(item.cursorOffset, 9);
        expect(item.detail, 'Range getRange(String a1Notation)');
      },
    );

    test('when an API member is hovered then its signature and docs show', () {
      const src =
          "void f() { SpreadsheetApp.active.getRange('A1').clearContent(); }";
      final h = c.hover(src, src.indexOf('getRange') + 2)!;
      expect(h.title, 'Range getRange(String a1Notation)');
      expect(h.className, 'Spreadsheet');
      final h2 = c.hover(src, src.indexOf('clearContent'))!;
      expect(h2.className, 'Range');
      final h3 = c.hover(src, 12)!;
      expect(h3.title, 'class SpreadsheetApp');
    });

    test('when completing or hovering at the very start of a file then '
        'nothing throws', () {
      const src = "import 'package:wonky/wonky.dart';\n";
      expect(c.complete(src, 0), isNull);
      expect(() => c.hover(src, 0), returnsNormally);
    });
  });
}
