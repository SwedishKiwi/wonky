import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_rich_text/wonky_rich_text.dart' show Delta;
import 'package:wonky_slides_core/clipboard.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/planner.dart';
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_slides_core/session.dart';
import 'package:wonky_slides_core/testing.dart';
import 'package:wonky_slides_core/themes.dart';
import 'package:wonky_sync_models/ids.dart';

const _slide = SuRect(0, 0, 1920, 1080);

MemoryDeck _deck() {
  final d = MemoryDeck(
    model: DeckModel(deckId: testDeckId),
    userId: testUserId,
    planner: const SlidesPlanner(),
    ids: SequentialIdGenerator(5000000),
  );
  d.execute(
    const CreateDeck(deckId: testDeckId, title: 'T', firstLayoutKey: 'blank'),
  );
  return d;
}

/// Pastes [r] on the deck's slide (through the codec, as SL-18 does) and
/// returns the pasted top-level elements.
List<SlideElementRec> _paste(MemoryDeck d, PasteMapResult r) {
  final payload = SlidesClipboardCodec.decode(
    SlidesClipboardCodec.encode(r.payload),
  )!;
  final plan = d.execute(PasteElements(payload, d.model.slides.single.id));
  return [
    for (final id in (plan.result['elementIds']! as List).cast<String>())
      d.model.element(id)!,
  ];
}

List<Object?> _ops(String? json) => jsonDecode(json!) as List<Object?>;

void main() {
  group('Given plain text from the OS', () {
    test('when pasted then one text box holds a paragraph per line and '
        'list markers become lists', () {
      final r = SlidesPasteMappers.plainText(
        'Plan\r\n- one\n  * two\n1. first\n',
        slide: _slide,
      );
      final d = _deck();
      final e = _paste(d, r).single;

      expect(e.kind, ElementKind.text);
      expect(_ops(e.columns[SlidesCols.text] as String?), isNotEmpty);
      final delta = Delta.fromJson(_ops(e.columns[SlidesCols.text] as String?));
      final lines = [
        for (final op in delta.operations)
          for (final ch in (op.data! as String).split(''))
            if (ch == '\n') op.attributes,
      ];
      expect(lines, [
        null,
        {'list': 'bullet'},
        {'list': 'bullet', 'indent': 1},
        {'list': 'ordered'},
      ]);
      expect(e.frame!.width, 1920 * 0.8);
    });

    test('when the text is blank then nothing is pasted', () {
      expect(
        SlidesPasteMappers.plainText('  \n ', slide: _slide).elements,
        isEmpty,
      );
    });
  });

  group('Given grids from Sheets or TSV', () {
    test(
      'when parsing TSV then quoted cells keep tabs, newlines and quotes',
      () {
        expect(
          SlidesPasteMappers.parseTsv('a\t"b\tc"\n"x\ny"\t"say ""hi"""\r\n'),
          [
            ['a', 'b\tc'],
            ['x\ny', 'say "hi"'],
          ],
        );
        expect(SlidesPasteMappers.parseTsv('one'), [
          ['one'],
        ]);
      },
    );

    test('when a 10 x 5 range is pasted then a table element with formatted '
        'cells, header row and merges arrives', () {
      final rows = [
        for (var r = 0; r < 10; r++)
          [
            for (var c = 0; c < 5; c++)
              GridCell(
                'R${r}C$c',
                bold: r == 0,
                color: c == 1 ? '#FF0000' : null,
                fill: r == 1 && c == 0 ? '#00FF00' : null,
                align: c == 4 ? 'right' : null,
                colSpan: r == 2 && c == 0 ? 2 : null,
              ),
          ],
      ];
      final d = _deck();
      final table = _paste(
        d,
        SlidesPasteMappers.grid(rows, slide: _slide, header: true),
      ).single;

      expect(table.kind, ElementKind.table);
      final rowAxes = d.model.axesOf(table.id, TableAxisDimension.row);
      final colAxes = d.model.axesOf(table.id, TableAxisDimension.column);
      expect((rowAxes.length, colAxes.length), (10, 5));
      expect(rowAxes.first.columns[TableAxisCols.header], isTrue);
      final cells = {
        for (final c in d.model.cellsOf(table.id))
          (
            rowAxes.indexWhere((a) => a.id == c.columns[TableCellCols.rowId]),
            colAxes.indexWhere(
              (a) => a.id == c.columns[TableCellCols.columnId],
            ),
          ): c,
      };
      expect(cells, hasLength(50));
      expect(_ops(cells[(0, 0)]!.columns[SlidesCols.text] as String?).first, {
        'insert': 'R0C0',
        'attributes': {'bold': true},
      });
      expect(cells[(1, 0)]!.columns[TableCellCols.fill], '#00FF00');
      expect(cells[(2, 0)]!.columns[TableCellCols.colSpan], 2);
      expect(_ops(cells[(3, 4)]!.columns[SlidesCols.text] as String?).last, {
        'insert': '\n',
        'attributes': {'align': 'right'},
      });
    });

    test('when more than 50 rows or 20 columns are pasted then the rest is '
        'cut with a warning', () {
      final r = SlidesPasteMappers.tsv(
        [
          for (var i = 0; i < 60; i++) List.filled(25, 'x').join('\t'),
        ].join('\n'),
        slide: _slide,
      );
      expect(r.warnings, [PasteMapResult.truncated]);
      expect(r.payload['tableAxes'], hasLength(50 + 20));
      expect(r.payload['tableCells'], hasLength(50 * 20));
      expect(_paste(_deck(), r), hasLength(1));
    });
  });

  group('Given a Sheets chart object', () {
    const item = {
      'kind': 'chart',
      'spec': {'v': 1, 'type': 'column'},
      'title': 'Revenue',
      'altText': 'Revenue by quarter',
      'spreadsheetItemUuid': '00000000-0000-4000-8000-0000000000E1',
      'objectId': '00000000-0000-4000-8000-0000000000e2',
      'sheetId': '00000000-0000-4000-8000-0000000000e3',
    };

    test('when it names its spreadsheet then a linked chart arrives with a '
        'chart link of the new element', () {
      final d = _deck();
      final e = _paste(
        d,
        SlidesPasteMappers.sheetsObject(
          item,
          slide: _slide,
          userId: testUserId,
          now: DateTime.utc(2026),
        ),
      ).single;

      expect(e.kind, ElementKind.chart);
      expect(
        jsonDecode(e.columns[ElementCols.dataJson]! as String)['source'],
        'linked',
      );
      expect(e.columns[ElementCols.altText], 'Revenue by quarter');
      final link = d.model.chartLinkOf(e.id)!;
      expect(link.id, SlidesIds.chartLinkId(e.id));
      expect(
        link.columns[ChartLinkCols.spreadsheetItemUuid],
        '00000000-0000-4000-8000-0000000000e1',
      );
      expect(
        link.columns[ChartLinkCols.chartObjectId],
        '00000000-0000-4000-8000-0000000000e2',
      );
    });

    test('when pasted unlinked (or without a source) then a static chart '
        'holds the spec', () {
      for (final r in [
        SlidesPasteMappers.sheetsObject(
          item,
          slide: _slide,
          userId: testUserId,
          now: DateTime.utc(2026),
          unlinked: true,
        ),
        SlidesPasteMappers.sheetsObject(
          {...item}..remove('objectId'),
          slide: _slide,
          userId: testUserId,
          now: DateTime.utc(2026),
        ),
      ]) {
        final d = _deck();
        final e = _paste(d, r).single;
        final data = jsonDecode(e.columns[ElementCols.dataJson]! as String);
        expect(data['source'], 'static');
        expect(data['spec'], {'v': 1, 'type': 'column'});
        expect(d.model.chartLinkOf(e.id), isNull);
      }
    });

    test('when it is an image object then an image element arrives', () {
      final r = SlidesPasteMappers.sheetsObject(
        {
          'kind': 'image',
          'spec': {'src': 'wonky-file://00000000-0000-4000-8000-0000000000f1'},
        },
        slide: _slide,
        userId: testUserId,
        now: DateTime.utc(2026),
      );
      expect(_paste(_deck(), r).single.kind, ElementKind.image);
    });
  });

  group('Given images', () {
    test('when an uploaded image is pasted then it is fitted, centered and '
        'listed for re-homing', () {
      final r = SlidesPasteMappers.image(
        src: 'wonky-file://00000000-0000-4000-8000-0000000000f1',
        naturalWidth: 4000,
        naturalHeight: 2000,
        slide: _slide,
        sourceItemUuid: testDeckId,
      );
      final e = r.elements.single;
      expect(e[ElementCols.width], 1920 * 0.8);
      expect(e[ElementCols.height], 1920 * 0.8 / 2);
      expect(e[ElementCols.x], 1920 * 0.1);
      expect(r.payload['files'], [
        {
          'fileUuid': '00000000-0000-4000-8000-0000000000f1',
          'itemUuid': testDeckId,
        },
      ]);
      expect(r.warnings, isEmpty);
    });

    test('when the image is remote then the proxy warning is raised', () {
      final r = SlidesPasteMappers.image(
        src: 'https://example.com/a.png',
        slide: _slide,
      );
      expect(r.warnings, [PasteMapResult.remoteImages]);
      expect(r.payload['files'], isEmpty);
    });
  });

  group('Given Wonky Write rich text', () {
    test('when pasted then text, code blocks, images and tables become '
        'separate elements in order', () {
      final write = Delta()
        ..insert('Title')
        ..insert('\n', {'header': 1})
        ..insert('Bold', {'bold': true, 'cmt_1': true})
        ..insert(' and ')
        ..insert('link', {'link': 'https://wonky.dev'})
        ..insert('\n')
        ..insert('Task')
        ..insert('\n', {'list': 'checked', 'indent': 1})
        ..insert('Quote')
        ..insert('\n', {'blockquote': true})
        ..insert('void main() {')
        ..insert('\n', {'code-block': 'dart'})
        ..insert('}')
        ..insert('\n', {'code-block': 'dart'})
        ..insert({
          'image': {
            'id': 'i',
            'src': 'wonky-file://00000000-0000-4000-8000-0000000000f1',
            'alt': 'Cat',
          },
        })
        ..insert('\n')
        ..insert({
          'table': {
            'id': 't',
            'rows': [
              ['**A**', 'B'],
              ['1', '`2`'],
            ],
          },
        })
        ..insert('\n')
        ..insert('After')
        ..insert('\n', {'header': 3});

      final r = SlidesPasteMappers.writeDelta(
        write,
        slide: _slide,
        sourceItemUuid: 'w',
      );
      final d = _deck();
      final pasted = _paste(d, r);

      expect(
        [for (final e in pasted) e.kind],
        [
          ElementKind.text,
          ElementKind.code,
          ElementKind.image,
          ElementKind.table,
          ElementKind.text,
        ],
      );
      final text = Delta.fromJson(
        _ops(pasted.first.columns[SlidesCols.text] as String?),
      );
      expect(text.toJson(), [
        {'insert': 'Title'},
        {
          'insert': '\n',
          'attributes': {'style': 'title'},
        },
        {
          'insert': 'Bold',
          'attributes': {'bold': true},
        },
        {'insert': ' and '},
        {
          'insert': 'link',
          'attributes': {'link': 'https://wonky.dev'},
        },
        {'insert': '\nTask'},
        {
          'insert': '\n',
          'attributes': {'list': 'check', 'indent': 1},
        },
        {'insert': 'Quote'},
        {
          'insert': '\n',
          'attributes': {'style': 'quote'},
        },
      ]);
      final states = d.model.codeStatesOf(pasted[1].id);
      expect(states.single.columns['code'], 'void main() {\n}');
      expect(
        jsonDecode(
          pasted[1].columns[ElementCols.dataJson]! as String,
        )['language'],
        'dart',
      );
      expect(pasted[2].columns[ElementCols.altText], 'Cat');
      final cells = d.model.cellsOf(pasted[3].id).toList();
      expect(cells, hasLength(4));
      expect(
        [
          for (final c in cells)
            _ops(c.columns[SlidesCols.text] as String?).first,
        ],
        containsAll([
          {
            'insert': 'A',
            'attributes': {'bold': true},
          },
          {
            'insert': '2',
            'attributes': {'code': true},
          },
        ]),
      );
      expect(_ops(pasted[4].columns[SlidesCols.text] as String?).last, {
        'insert': '\n',
        'attributes': {'style': 'heading'},
      });
      expect(r.payload['files'], hasLength(1));
      // Stacked top to bottom.
      for (var i = 1; i < pasted.length; i++) {
        expect(pasted[i].frame!.y, greaterThan(pasted[i - 1].frame!.y));
      }
    });
  });
}
