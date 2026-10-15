import 'package:test/test.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/testing.dart';
import 'package:wonky_slides_core/themes.dart';

import '../support/planner_fixture.dart';

const _missing = '00000000-0000-4000-8000-00000000dead';

void main() {
  final f = PlannerFixture();

  group('Given the planner fixture', () {
    final cases = <(String, SlidesOperation, String)>[
      (
        'an empty title',
        const SetDeckProps(title: '  '),
        PlanException.invalidArgument,
      ),
      (
        'a too small custom size',
        const SetDeckProps(
          size: DeckSizeChange(SlideSize(SlideSizeKind.custom, 100, 100)),
        ),
        PlanException.invalidArgument,
      ),
      (
        'an unknown default theme',
        const SetDeckTheme(_missing),
        PlanException.notFound,
      ),
      (
        'a missing layout',
        const AddSlides(layoutId: _missing),
        PlanException.notFound,
      ),
      (
        'a missing anchor slide',
        const AddSlides(target: TopLevel(afterId: _missing)),
        PlanException.notFound,
      ),
      (
        'a missing group target',
        const AddSlides(target: InGroup(_missing)),
        PlanException.notFound,
      ),
      ('zero slides', const AddSlides(count: 0), PlanException.invalidArgument),
      (
        'deleting a missing slide',
        const DeleteSlides([_missing]),
        PlanException.notFound,
      ),
      (
        'invalid notes JSON',
        SetSlideProps([f.s2], notes: const Patch('not json')),
        PlanException.invalidArgument,
      ),
      (
        'an invalid background',
        SetSlideProps([
          f.s2,
        ], backgroundJson: const Patch('{"v":1,"fill":{"type":"nope"}}')),
        PlanException.invalidArgument,
      ),
      (
        'a non-object transition',
        SetSlideProps([f.s2], transitionJson: const Patch('[1]')),
        PlanException.invalidArgument,
      ),
      (
        'an unknown group color',
        CreateGroup([f.s2], color: 'plaid'),
        PlanException.invalidArgument,
      ),
      (
        'a too long group title',
        CreateGroup([f.s2], title: 'x' * 101),
        PlanException.invalidArgument,
      ),
      (
        'grouping no slides',
        const CreateGroup([]),
        PlanException.invalidArgument,
      ),
      (
        'a non-group parent',
        InsertElements(f.s3, const [
          ElementSpec(kind: ElementKind.shape, x: 0, y: 0, width: 1, height: 1),
        ], parentId: f.shape),
        PlanException.invalidArgument,
      ),
      (
        'a planner-owned column',
        InsertElements(f.s3, const [
          ElementSpec(
            kind: ElementKind.shape,
            x: 0,
            y: 0,
            width: 1,
            height: 1,
            columns: {'zKey': 'a0'},
          ),
        ]),
        PlanException.invalidArgument,
      ),
      (
        'a missing owner',
        const InsertElements(_missing, [
          ElementSpec(kind: ElementKind.shape, x: 0, y: 0, width: 1, height: 1),
        ]),
        PlanException.notFound,
      ),
      (
        'an oversized table',
        InsertElements(f.s3, const [
          ElementSpec(
            kind: ElementKind.table,
            x: 0,
            y: 0,
            width: 1,
            height: 1,
            tableRows: 51,
          ),
        ]),
        PlanException.limit,
      ),
      (
        'an empty Magic Move id',
        SetElementProps([f.shape], matchKey: ' '),
        PlanException.invalidArgument,
      ),
      (
        'an invalid reading key',
        SetElementProps([f.shape], readingKey: const Patch('!!')),
        PlanException.invalidArgument,
      ),
      (
        'grouping one element',
        GroupElements([f.shape]),
        PlanException.invalidArgument,
      ),
      (
        'grouping across levels',
        GroupElements([f.shape, f.child1]),
        PlanException.invalidArgument,
      ),
      (
        'ungrouping a shape',
        UngroupElements([f.shape]),
        PlanException.invalidArgument,
      ),
      (
        'replacing a shape\'s image',
        ReplaceImage(
          f.shape,
          src: 'wonky-file://x',
          naturalWidth: 1,
          naturalHeight: 1,
        ),
        PlanException.invalidArgument,
      ),
      (
        'an http image',
        ReplaceImage(
          f.image,
          src: 'http://x',
          naturalWidth: 1,
          naturalHeight: 1,
        ),
        PlanException.invalidArgument,
      ),
      (
        'text on an image',
        SetText(ElementText(f.image), deltaOf('x')),
        PlanException.invalidArgument,
      ),
      (
        'a range over two bodies',
        FormatText(
          [ElementText(f.text), ElementText(f.shape)],
          const {'bold': true},
          start: 0,
          length: 1,
        ),
        PlanException.invalidArgument,
      ),
      (
        'an invalid box style',
        SetTextBoxStyle([f.text], const {'anchor': 'sideways'}),
        PlanException.invalidArgument,
      ),
      (
        'a cell span column via SetCells',
        SetCells(f.table, [
          CellWrite(f.rows[0], f.cols[0], const {'rowSpan': 2}),
        ]),
        PlanException.invalidArgument,
      ),
      (
        'a cell of a missing row',
        SetCells(f.table, [
          CellWrite(_missing, f.cols[0], const {'fill': '#fff'}),
        ]),
        PlanException.notFound,
      ),
      (
        'a merge outside the table',
        MergeCells(
          f.table,
          rowId: f.rows[2],
          columnId: f.cols[2],
          rowSpan: 2,
          colSpan: 1,
        ),
        PlanException.invalidArgument,
      ),
      (
        'deleting every row',
        DeleteTableAxes(f.table, f.rows),
        PlanException.invalidArgument,
      ),
      (
        'moving rows and columns together',
        MoveTableAxes(f.table, [f.rows[0], f.cols[0]], 0),
        PlanException.invalidArgument,
      ),
      (
        'table ops on a shape',
        InsertTableAxes(f.shape, TableAxisDimension.row, 0),
        PlanException.invalidArgument,
      ),
      (
        'a build on another slide',
        AddBuilds(f.s2, [
          BuildSpec(
            elementId: f.shape,
            kind: SlideBuildKind.buildIn,
            effect: 'fade',
            durationMs: 1,
          ),
        ]),
        PlanException.invalidArgument,
      ),
      (
        'an unknown build column',
        UpdateBuilds({
          f.build1: const {'slideId': 'x'},
        }),
        PlanException.invalidArgument,
      ),
      (
        'a negative duration',
        UpdateBuilds({
          f.build1: const {'durationMs': -1},
        }),
        PlanException.invalidArgument,
      ),
      (
        'too many code lines',
        SetCode(f.states.first, '\n' * 1000),
        PlanException.limit,
      ),
      (
        'deleting every code state',
        DeleteCodeStates(f.states),
        PlanException.invalidArgument,
      ),
      (
        'linking a shape',
        LinkChart(
          f.shape,
          spreadsheetItemUuid: 'a',
          chartObjectId: 'b',
          snapshot: PlannerFixture.snapshot('1'),
        ),
        PlanException.invalidArgument,
      ),
      (
        'an unknown built-in theme',
        const ImportTheme(builtInKey: 'nope'),
        PlanException.invalidArgument,
      ),
      (
        'an invalid theme package',
        const ImportTheme(packageJson: {'v': 1}),
        PlanException.invalidArgument,
      ),
      (
        'an unknown theme column',
        UpdateTheme(f.themeId, columns: const {'nopeJson': '{}'}),
        PlanException.invalidArgument,
      ),
      (
        'a layout of another theme in the mapping',
        ApplyThemeToSlides(
          f.theme2,
          [f.s2],
          layoutMapping: {f.layout('titleBody'): f.layout('title')},
        ),
        PlanException.invalidArgument,
      ),
      (
        'a master column on a layout',
        UpdateMasterOrLayout(f.masterId, const {'hidden': true}),
        PlanException.invalidArgument,
      ),
      (
        'an empty layout sort key (SL-28)',
        UpdateMasterOrLayout(f.layout('quote'), const {'sortKey': ''}),
        PlanException.invalidArgument,
      ),
      (
        'deleting the only master',
        DeleteMastersOrLayouts([f.masterId]),
        PlanException.invalidArgument,
      ),
      (
        'a wrong clipboard format',
        const PasteSlides({'format': 'x', 'v': 1, 'kind': 'slides'}),
        PlanException.invalidArgument,
      ),
      (
        'pasting slides as elements',
        PasteElements(const {
          'format': 'wonky-slides-clipboard',
          'v': 1,
          'kind': 'slides',
        }, f.s2),
        PlanException.invalidArgument,
      ),
    ];
    for (final (what, op, code) in cases) {
      test('when planning $what then it is refused with $code and nothing '
          'changes', () {
        final deck = f.session();
        final before = deck.model.dump();

        expect(
          () => deck.execute(op),
          throwsA(isA<PlanException>().having((e) => e.code, 'code', code)),
        );
        expect(deck.model.dump(), before);
      });
    }
  });

  group('Given frame geometry', () {
    test('when a frame is rotated by 90° then its bounds swap width and '
        'height around the center', () {
      const f = ElementFrame(0, 0, 200, 100, rotation: 90);

      final b = f.bounds;

      expect(b.x, closeTo(50, 1e-9));
      expect(b.y, closeTo(-50, 1e-9));
      expect(b.width, closeTo(100, 1e-9));
      expect(b.height, closeTo(200, 1e-9));
    });

    test('when a child of a flipped group is mapped then it mirrors inside '
        'the group and its flip toggles', () {
      const group = ElementFrame(0, 0, 100, 100, flipH: true);
      const child = ElementFrame(0, 0, 10, 10);

      final out = GroupSpace.toParent(
        child,
        group,
        const SuRect(0, 0, 100, 100),
      );

      expect((out.x, out.y, out.flipH), (90.0, 0.0, true));
    });

    test('when rects touch then they do not overlap; union spans both', () {
      const a = SuRect(0, 0, 10, 10), b = SuRect(10, 0, 10, 10);

      expect(rectsOverlap(a, b), isFalse);
      expect(unionRects([a, b]), const SuRect(0, 0, 20, 10));
      expect(normalizeRotation(-725), 355.0);
    });
  });
}
