import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides/features/canvas/slide_canvas_controller.dart';
import 'package:wonky_slides/features/clipboard/system_clipboard.dart';
import 'package:wonky_slides/features/elements/table/table_cells.dart';
import 'package:wonky_slides/features/navigator/navigator_clipboard.dart';
import 'package:wonky_slides/features/stage/slide_renderer.dart';
import 'package:wonky_slides/features/text_editing/text_editing_host.dart';
import 'package:wonky_slides_core/clipboard.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/testing.dart';

import '../../features/stage/stage_fixture.dart' show RecordingFontRegistry;
import '../../harness/deck_harness.dart';

List<Map<String, Object?>> _ops(String? json) => [
  for (final op in SlidesText.parse(json).operations)
    {'insert': op.data, ...?op.attributes},
];

String _plain(String? json) => SlidesText.plainText(json).trim();

void main() {
  late MemorySlidesClipboard sys;
  late DeckHarness d;
  late SlideCanvasController canvas;
  late String slide, a, b, table;
  late List<String> rows, cols;

  setUp(() {
    sys = MemorySlidesClipboard();
    SlidesSystemClipboard.instance = sys;
    SlidesSlideClipboard.debugClear();
    final f = DeckBuilder(title: 'Targets');
    slide = f.slide(layoutKey: 'blank');
    a = f.textBox(slide, 'Hello world', x: 100, y: 100, width: 800);
    b = f.textBox(slide, 'Other', x: 100, y: 400, width: 800);
    final t = f.table(slide, rows: 3, cols: 3, y: 600);
    table = t.$1;
    rows = t.$2;
    cols = t.$3;
    f.cell(table, rows[0], cols[0], 'x');
    d = DeckHarness.open(fixture: f);
    d.editor.setCurrentSlide(slide);
    canvas = SlideCanvasController.attach(
      d.editor,
      renderer: SlideRenderer(
        model: d.session.model,
        fonts: RecordingFontRegistry(),
      ),
    );
  });

  tearDown(() async {
    textEditingOf(d.editor).dispose();
    final r = canvas.renderer;
    canvas.dispose();
    r.dispose();
    await d.dispose();
  });

  group('Given a text box being edited (03 §12.3 "Text editing")', () {
    testWidgets('when a formatted range is copied and pasted into another '
        'body then the formatting arrives at the caret in one step', (
      tester,
    ) async {
      final host = textEditingOf(d.editor);
      await host.begin(a);
      host.active!.selectRange(0, 5);
      await d.run('slides.format.bold');
      final copied = await d.run('slides.edit.copy');
      expect((copied.data! as Map)['kind'], 'text');
      expect(SlidesSlideClipboard.current!['kind'], 'text');
      expect(sys.data!.html, contains('<b>Hello</b>'));

      await host.begin(b, caretOffset: 0);
      final r = await d.run('slides.edit.paste');
      expect(r.isOk, isTrue, reason: '${r.message}');
      expect(_ops(d.model.element(b)!.text), [
        {'insert': 'Hello', 'bold': true},
        {'insert': 'Other\n'},
      ]);
      expect(host.active!.selectionRange, (5, 5));
      expect(
        d.undoLabels,
        containsAll(['slides.format.bold', 'slides.edit.paste']),
      );
      await d.undo();
      expect(_plain(d.model.element(b)!.text), 'Other');
    });

    testWidgets('when Wonky Write content is pasted then headings and lists '
        'map to the schema and embeds are dropped', (tester) async {
      final write = [
        {'insert': 'Head'},
        {
          'insert': '\n',
          'attributes': {'header': 2},
        },
        {
          'insert': {
            'image': {'id': 'i', 'src': 'wonky-file://x', 'alt': ''},
          },
        },
        {'insert': 'item'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        },
      ];
      sys.data = SlidesClipboardData(
        plainText: '## Head',
        html:
            '<div data-wonky-delta="'
            '${base64Url.encode(utf8.encode(jsonEncode(write)))}"></div>',
      );
      final host = textEditingOf(d.editor);
      await host.begin(b, caretOffset: 5);
      await d.run('slides.edit.paste');
      final ops = _ops(d.model.element(b)!.text);
      expect(ops, [
        {'insert': 'OtherHead'},
        {'insert': '\n', 'style': 'heading'},
        {'insert': 'item\n'},
      ]);
    });

    testWidgets('when text is cut then it is removed in one step', (
      tester,
    ) async {
      final host = textEditingOf(d.editor);
      await host.begin(a);
      host.active!.selectRange(5, 11);
      await d.run('slides.edit.cut');
      expect(_plain(d.model.element(a)!.text), 'Hello');
      expect(
        SlidesClipboardCodec.plainText(SlidesSlideClipboard.current!).trim(),
        'world',
      );
      expect(d.undoLabels, ['slides.edit.cut']);
    });
  });

  group('Given selected table cells (03 §12.3 "Table cell range")', () {
    testWidgets('when a 2 × 2 TSV is pasted then it fills from the anchor in '
        'one step and selects the pasted range', (tester) async {
      d.editor.selectElements([table]);
      TableCellSelection.of(
        d.editor,
      ).select(table, (rowId: rows[1], columnId: cols[1]));
      sys.data = const SlidesClipboardData(plainText: 'a\tb\nc\td');
      final r = await d.run('slides.edit.paste');
      expect(r.isOk, isTrue, reason: '${r.message}');
      String cell(int r, int c) => _plain(
        d.model
            .cellsOf(table)
            .where((x) => x.rowId == rows[r] && x.columnId == cols[c])
            .firstOrNull
            ?.text,
      );
      expect(
        [cell(1, 1), cell(1, 2), cell(2, 1), cell(2, 2)],
        ['a', 'b', 'c', 'd'],
      );
      expect(TableCellSelection.of(d.editor).range!.rows, 2);
      expect(d.undoLabels, ['slides.edit.paste']);
      expect((r.data! as Map)['clipped'], isFalse);
    });

    testWidgets('when a larger grid is pasted then it is clipped to the '
        'table', (tester) async {
      d.editor.selectElements([table]);
      TableCellSelection.of(
        d.editor,
      ).select(table, (rowId: rows[2], columnId: cols[2]));
      sys.data = const SlidesClipboardData(plainText: 'a\tb\nc\td');
      final r = await d.run('slides.edit.paste');
      expect((r.data! as Map)['cells'], 1);
      expect((r.data! as Map)['clipped'], isTrue);
    });

    testWidgets('when cells are copied then TSV and an HTML table are on the '
        'clipboard', (tester) async {
      d.editor.selectElements([table]);
      TableCellSelection.of(d.editor).select(
        table,
        (rowId: rows[0], columnId: cols[0]),
        (rowId: rows[0], columnId: cols[1]),
      );
      final r = await d.run('slides.edit.copy');
      expect(r.isOk, isTrue, reason: '${r.message}');
      expect(sys.data!.plainText, 'x\t');
      expect(sys.data!.html, contains('<table><tbody><tr><td>x</td><td></td>'));
      expect(CommandStatus.ok, r.status);
    });
  });
}
