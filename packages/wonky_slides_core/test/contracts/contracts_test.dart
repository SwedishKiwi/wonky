import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;
import 'package:wonky_fonts/wonky_fonts.dart' show InMemoryFontProvider;
import 'package:wonky_slides_core/interfaces.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_slides_core/session.dart';
import 'package:wonky_slides_core/testing.dart';
import 'package:wonky_slides_core/themes.dart';

/// Monospace layout: every character is `0.5 × size` wide, one line per
/// paragraph.
final class _MonoLayout implements TextLayoutEngine {
  @override
  TextLayoutResult layout(
    TextBody body,
    ResolvedTextStyles styles, {
    required double width,
    double scale = 1,
  }) {
    final size = 40 * scale;
    final lines = <TextLineBox>[];
    var start = 0;
    var top = 0.0;
    for (final p in body.plainText.split('\n')..removeLast()) {
      lines.add(
        TextLineBox(
          top: top,
          baseline: top + size,
          height: size * 1.2,
          left: 0,
          width: p.length * size / 2,
          start: start,
          end: start + p.length,
          runs: [
            TextRunBox(
              text: p,
              start: start,
              x: 0,
              width: p.length * size / 2,
              fontFamily: 'Mono',
              fontSize: size,
              color: 0xff000000,
            ),
          ],
        ),
      );
      start += p.length + 1;
      top += size * 1.2;
    }
    return TextLayoutResult(width: width, height: top, lines: lines);
  }
}

final class _CountingPdf implements SlidesPdfRenderer {
  @override
  Future<SlidesPdfResult> render(
    DeckModel deck,
    SlidesPdfOptions options,
    SlidesExportResources resources,
  ) async => SlidesPdfResult(
    bytes: const [0x25, 0x50, 0x44, 0x46],
    pageCount: deck.slides
        .where((s) => options.includeSkipped || !s.skipped)
        .length,
  );
}

final class _Recorder implements DeckChangeLogConsumer<String> {
  final List<(String, String, int)> seen = [];

  @override
  String get id => 'recorder';

  @override
  Future<void> consume(
    String context,
    String deckId,
    List<DeckChangeLogEntry> rows,
  ) async => seen.add((context, deckId, rows.length));
}

final class _Headless implements HeadlessDeck, HeadlessDeckProvider<String> {
  _Headless(this.deck);

  final MemoryDeck deck;

  @override
  DeckModel get model => deck.model;

  @override
  Future<SlidesPlan> execute(
    SlidesOperation op, {
    String actorKind = 'mcp',
  }) async => deck.execute(op, actorKind: actorKind);

  @override
  Future<HeadlessDeck> open(String context, String deckId) async => this;
}

void main() {
  group('Given fakes of the core contracts', () {
    test('when laying out text through the engine contract then lines and '
        'line breaks are reported', () {
      final r = _MonoLayout().layout(
        TextBody.plain('Hello\nWorld'),
        const ResolvedTextStyles(styles: {}, defaultStyle: 'body'),
        width: 800,
      );

      expect(r.lines, hasLength(2));
      expect(r.lineBreaks, [5, 11]);
    });

    test('when rendering a PDF through the renderer contract then skipped '
        'slides follow the options', () async {
      final b = DeckBuilder();
      b.slide();
      b.slide(skipped: true);
      final model = b.build();
      final resources = SlidesExportResources(
        fonts: InMemoryFontProvider(const []),
        images: MemorySlideImageResolver({
          'wonky-file://f': Uint8List.fromList([1]),
        }),
      );

      final r1 = await _CountingPdf().render(
        model,
        const SlidesPdfOptions(),
        resources,
      );
      final r2 = await _CountingPdf().render(
        model,
        const SlidesPdfOptions(includeSkipped: true),
        resources,
      );

      expect((r1.pageCount, r2.pageCount), (1, 2));
      expect(
        await resources.images.bytes(const SlideImageRef('wonky-file://f')),
        [1],
      );
    });

    test('when the server binds the generic consumer and headless contracts '
        'then they run over a memory deck', () async {
      final b = DeckBuilder();
      b.slide();
      final headless = _Headless(
        MemoryDeck(
          model: b.build(),
          userId: testUserId,
          planner: const FakeSlidesPlanner(),
        ),
      );
      final consumer = _Recorder();

      final deck = await headless.open('session', testDeckId);
      final plan = await deck.execute(const SetDeckProps(title: 'MCP'));
      await consumer.consume('session', testDeckId, [
        DeckChangeLogEntry(
          id: 'c1',
          deckId: testDeckId,
          userId: testUserId,
          actorKind: 'mcp',
          sessionId: 's',
          label: plan.label,
          summaryJson: plan.summaryJson,
          at: testNow,
        ),
      ]);

      expect(deck.model.deck!.title, 'MCP');
      expect(headless.deck.writes.single.actorKind, 'mcp');
      expect(consumer.seen, [('session', testDeckId, 1)]);
    });

    test('when building a scene then element nodes are found by id at any '
        'depth', () {
      final path = ScenePath([const PMoveTo(0, 0), const PLineTo(10, 0)]);
      final scene = SlideScene(
        slideId: 's',
        width: 1920,
        height: 1080,
        background: const ResolvedBackground(ResolvedNoFill(), null),
        nodes: [
          GroupNode(
            elementId: 'g',
            transform: Matrix4.translationValues(10, 0, 0),
            children: [
              PathNode(
                elementId: 'p',
                path: path,
                stroke: const NodeStroke(width: 2, color: 0xff000000),
              ),
              ChartNode(
                elementId: 'c',
                scene: const ChartScene(
                  width: 10,
                  height: 10,
                  background: 0,
                  primitives: [],
                ),
                dst: const SuRect(0, 0, 10, 10),
              ),
            ],
          ),
          const PromptNode(text: 'Click to add title', box: SuRect(0, 0, 1, 1)),
        ],
      );

      expect(scene.nodesOf('p').single, isA<PathNode>());
      expect(scene.nodesOf('c').single, isA<ChartNode>());
      expect(scene.nodesOf('g').single, isA<GroupNode>());
    });

    test('when switching over every operation then the sealed family is '
        'exhaustive and names are unique', () {
      String area(SlidesOperation op) => switch (op) {
        CreateDeck() || SetDeckProps() || SetDeckTheme() => 'deck',
        AddSlides() ||
        DuplicateSlides() ||
        DeleteSlides() ||
        MoveSlides() ||
        SetSlideProps() ||
        ResetSlideToLayout() => 'slides',
        CreateGroup() ||
        Ungroup() ||
        MoveGroups() ||
        SetGroupProps() ||
        DeleteGroups() ||
        DuplicateGroups() => 'groups',
        PasteSlides() || PasteElements() => 'clipboard',
        InsertElements() ||
        UpdateFrames() ||
        SetElementProps() ||
        DeleteElements() ||
        ReorderZ() ||
        AlignDistribute() ||
        GroupElements() ||
        UngroupElements() ||
        ReplaceImage() ||
        SetElementData() => 'elements',
        SetText() || FormatText() || SetTextBoxStyle() => 'text',
        InsertTableAxes() ||
        DeleteTableAxes() ||
        MoveTableAxes() ||
        ResizeTableAxes() ||
        SetCells() ||
        MergeCells() ||
        UnmergeCells() ||
        SetTableOptions() => 'tables',
        AddBuilds() ||
        UpdateBuilds() ||
        MoveBuilds() ||
        DeleteBuilds() => 'builds',
        SetCode() ||
        AddCodeStates() ||
        UpdateCodeState() ||
        MoveCodeStates() ||
        DeleteCodeStates() => 'code',
        LinkChart() ||
        UpdateChartLink() ||
        SetChartAutoUpdate() ||
        UnlinkChart() ||
        SetChartStyle() => 'charts',
        ImportTheme() ||
        UpdateTheme() ||
        ApplyThemeToSlides() ||
        DeleteTheme() ||
        AddMaster() ||
        AddLayout() ||
        UpdateMasterOrLayout() ||
        DeleteMastersOrLayouts() => 'themes',
        RepairDeck() => 'maintenance',
      };
      const snap = ChartSnapshot(
        sourceSpecJson: '{}',
        dataSnapshotJson: '{}',
        sourceVersion: '1',
      );
      final ops = <SlidesOperation>[
        const SetDeckTheme('t'),
        const DuplicateSlides(['s']),
        const ResetSlideToLayout(['s']),
        const Ungroup('g'),
        const MoveGroups(['g']),
        const SetGroupProps(['g'], color: Patch(null)),
        const DeleteGroups(['g']),
        const DuplicateGroups(['g']),
        const PasteSlides({}),
        const PasteElements({}, 's'),
        const ReorderZ(['e'], ZOrderOp.toFront),
        const AlignDistribute(['e'], AlignMode.left),
        const GroupElements(['e']),
        const UngroupElements(['g']),
        const ReplaceImage(
          'e',
          src: 'wonky-file://x',
          naturalWidth: 1,
          naturalHeight: 1,
        ),
        const SetElementData('e', '{}'),
        const FormatText([ElementText('e')], {'bold': true}),
        const SetTextBoxStyle(['e'], {}),
        const InsertTableAxes('t', TableAxisDimension.row, 0),
        const DeleteTableAxes('t', []),
        const MoveTableAxes('t', [], 0),
        const ResizeTableAxes('t', {}),
        const MergeCells(
          't',
          rowId: 'r',
          columnId: 'c',
          rowSpan: 2,
          colSpan: 1,
        ),
        const UnmergeCells('t', []),
        const SetTableOptions('t', {}),
        const AddBuilds('s', [
          BuildSpec(
            elementId: 'e',
            kind: SlideBuildKind.buildIn,
            effect: 'fade',
            durationMs: 1,
          ),
        ]),
        const UpdateBuilds({}),
        const MoveBuilds([]),
        const DeleteBuilds([]),
        const SetCode('st', ''),
        const AddCodeStates('e', []),
        const UpdateCodeState('st', {}),
        const MoveCodeStates([]),
        const DeleteCodeStates([]),
        const LinkChart(
          'e',
          spreadsheetItemUuid: 'x',
          chartObjectId: 'y',
          snapshot: snap,
        ),
        const UpdateChartLink('e', snap),
        const SetChartAutoUpdate('e', true),
        const UnlinkChart('e'),
        const SetChartStyle('e', {}),
        const ImportTheme(builtInKey: 'wonky'),
        const UpdateTheme('t'),
        const ApplyThemeToSlides('t', []),
        const DeleteTheme('t'),
        const AddMaster('t'),
        const AddLayout('m'),
        const UpdateMasterOrLayout('m', {}),
        const DeleteMastersOrLayouts([]),
        const RepairDeck([DeckViolation('orphanSlide', 'slide', 's')]),
      ];

      expect(ops.map((o) => o.name).toSet(), hasLength(ops.length));
      expect(ops.map(area).toSet(), hasLength(12));
    });
  });
}
