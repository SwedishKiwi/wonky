import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/src/board/screenshot/screenshot_annotations.dart';
import 'package:wonky_app/src/board/screenshot/screenshot_editor.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_ui/testing.dart';
import 'package:wonky_ui/wonky_ui.dart' show InkStroke, InkTool;

import '../report/support/report_fakes.dart';

/// A noisy image (no two neighbouring pixels alike), so covered pixels
/// stand out.
Future<ui.Image> _noise(int w, int h) async {
  final pixels = Uint8List(w * h * 4);
  var seed = 11;
  for (var i = 0; i < pixels.length; i++) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    pixels[i] = i % 4 == 3 ? 255 : 40 + (seed >> 16 & 0x7f);
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: w,
    height: h,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await descriptor.instantiateCodec();
  return (await codec.getNextFrame()).image;
}

Future<ByteData> _decodeRgba(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final image = (await codec.getNextFrame()).image;
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!;
}

final _encoded = EncodedScreenshot(
  bytes: Uint8List.fromList([1, 2, 3]),
  mimeType: 'image/png',
  width: 400,
  height: 200,
);

Future<ui.Image> _solid(int w, int h) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..color = const Color(0xff808080),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  picture.dispose();
  return image;
}

void main() {
  group('Given the flattening of a screenshot', () {
    testWidgets('when an area is covered then every pixel in it is opaque '
        'black and the rest is unchanged', (tester) async {
      final r = await tester.runAsync(() async {
        final source = await _noise(200, 100);
        final before = (await source.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final shot = await flattenAndEncodeScreenshot(source, const [
          // Fractional edges: the edge pixels are covered as well.
          CoverAnnotation('c', Rect.fromLTRB(20.4, 10.6, 80.2, 50.5)),
        ]);
        source.dispose();
        return (before, shot, await _decodeRgba(shot.bytes));
      });
      final (before, shot, after) = r!;
      expect(shot.mimeType, 'image/png');
      expect([shot.width, shot.height], [200, 100]);
      int px(ByteData d, int x, int y) => d.getUint32((y * 200 + x) * 4);
      for (var y = 10; y <= 50; y++) {
        for (var x = 20; x <= 80; x++) {
          expect(px(after, x, y), 0x000000ff, reason: 'covered ($x, $y)');
        }
      }
      for (final (x, y) in const [(0, 0), (19, 30), (81, 30), (100, 60)]) {
        expect(px(after, x, y), px(before, x, y), reason: 'kept ($x, $y)');
      }
    });

    testWidgets('when there are accent annotations then they are painted in '
        'their colors at the source resolution', (tester) async {
      final r = await tester.runAsync(() async {
        final source = await _solid(300, 200);
        final flat = await flattenScreenshot(source, [
          HighlightAnnotation(
            'h',
            const Rect.fromLTWH(50, 50, 100, 60),
            ScreenshotColor.red.color,
          ),
          PenAnnotation(
            InkStroke(
              id: 'p',
              tool: InkTool.pen,
              color: ScreenshotColor.blue.color.toARGB32(),
              width: 6,
              points: const [Offset(200, 20), Offset(260, 20)],
            ),
          ),
        ]);
        final data = await flat.toByteData(format: ui.ImageByteFormat.rawRgba);
        final size = [flat.width, flat.height];
        flat.dispose();
        source.dispose();
        return (data!, size);
      });
      final (data, size) = r!;
      expect(size, [300, 200]);
      int px(int x, int y) => data.getUint32((y * 300 + x) * 4);
      expect(px(50, 80), 0xef4444ff, reason: 'highlight edge');
      expect(px(100, 80), isNot(0xef4444ff), reason: 'highlight is hollow');
      expect(px(230, 20), 0x3b82f6ff, reason: 'pen stroke');
    });
  });

  group('Given the screenshot editor', () {
    late CommandTestHarness h;
    late ui.Image image;
    AnnotatedScreenshot? result;
    var closed = false;
    final finished = <List<ScreenshotAnnotation>>[];

    setUp(() {
      h = reportHarness();
      result = null;
      closed = false;
      finished.clear();
    });
    tearDown(() async {
      image.dispose();
      await h.dispose();
    });

    Future<void> open(
      WidgetTester tester, {
      List<ScreenshotAnnotation> initial = const [],
      Brightness brightness = Brightness.light,
      Size size = const Size(1280, 800),
    }) async {
      image = await solidImage(tester, 400, 200);
      await pumpReportShell(
        tester,
        h,
        Builder(
          builder: (context) => Center(
            child: GestureDetector(
              key: const ValueKey<String>('test.open'),
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                result = await showScreenshotEditor(
                  context,
                  image,
                  initial: initial,
                  finish: (source, annotations) async {
                    finished.add(annotations);
                    return _encoded;
                  },
                );
                closed = true;
              },
              child: const SizedBox(width: 80, height: 40),
            ),
          ),
        ),
        brightness: brightness,
        size: size,
      );
      await tester.tap(key('test.open'));
      await tester.pumpAndSettle();
    }

    ScreenshotEditorState editor(WidgetTester tester) =>
        tester.state<ScreenshotEditorState>(find.byType(ScreenshotEditor));

    /// Drags on the canvas from image point [from] to [to] (the canvas is
    /// shown at scale 1 in a 1280×800 window).
    Future<void> drag(WidgetTester tester, Offset from, Offset to) async {
      final origin = tester.getTopLeft(key(ScreenshotEditorKeys.canvas));
      final g = await tester.startGesture(origin + from);
      await tester.pump();
      for (var i = 1; i <= 4; i++) {
        await g.moveTo(origin + Offset.lerp(from, to, i / 4)!);
        await tester.pump();
      }
      await g.up();
      await tester.pump();
    }

    Future<void> click(WidgetTester tester, Offset at) async {
      final origin = tester.getTopLeft(key(ScreenshotEditorKeys.canvas));
      await tester.tapAt(origin + at);
      await tester.pump();
    }

    Future<void> mod(
      WidgetTester tester,
      LogicalKeyboardKey k, {
      bool shift = false,
    }) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(k);
      if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pump();
    }

    testWidgets('when it opens then the warning shows, Cover is the tool and '
        'the canvas fits the image', (tester) async {
      await open(tester);

      expect(key(ScreenshotEditorKeys.dialog), findsOneWidget);
      expect(key(ScreenshotEditorKeys.warning), findsOneWidget);
      expect(
        find.textContaining('This screenshot will be public'),
        findsOneWidget,
      );
      expect(editor(tester).tool, ScreenshotTool.cover);
      expect(
        tester.getSize(key(ScreenshotEditorKeys.canvas)),
        const Size(400, 200),
      );
      // The banner has no close button.
      expect(
        find.descendant(
          of: key(ScreenshotEditorKeys.warning),
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
    });

    testWidgets('when dragging with each tool then the matching annotation '
        'is added in image pixels', (tester) async {
      await open(tester);

      await drag(tester, const Offset(10, 10), const Offset(60, 40));
      await tester.tap(
        key(ScreenshotEditorKeys.tool(ScreenshotTool.highlight)),
      );
      await tester.pump();
      await drag(tester, const Offset(100, 20), const Offset(180, 90));
      await tester.tap(key(ScreenshotEditorKeys.tool(ScreenshotTool.arrow)));
      await tester.pump();
      await drag(tester, const Offset(200, 150), const Offset(300, 100));
      await tester.tap(key(ScreenshotEditorKeys.tool(ScreenshotTool.pen)));
      await tester.pump();
      await drag(tester, const Offset(320, 20), const Offset(380, 60));

      final items = editor(tester).annotations;
      expect(
        [for (final a in items) a.tool],
        [
          ScreenshotTool.cover,
          ScreenshotTool.highlight,
          ScreenshotTool.arrow,
          ScreenshotTool.pen,
        ],
      );
      expect(
        (items[0] as CoverAnnotation).rect,
        const Rect.fromLTRB(10, 10, 60, 40),
      );
      expect(
        (items[1] as HighlightAnnotation).color,
        ScreenshotColor.red.color,
      );
      final arrow = items[2] as ArrowAnnotation;
      expect(
        [arrow.from, arrow.to],
        const [Offset(200, 150), Offset(300, 100)],
      );
      expect((items[3] as PenAnnotation).stroke.points.length, greaterThan(2));
      await settleTooltips(tester);
    });

    testWidgets('when pressing C, H, A, P and 1–3 then the tool and the '
        'accent color change', (tester) async {
      await open(tester);
      final e = editor(tester);

      for (final (k, t) in [
        (LogicalKeyboardKey.keyH, ScreenshotTool.highlight),
        (LogicalKeyboardKey.keyA, ScreenshotTool.arrow),
        (LogicalKeyboardKey.keyP, ScreenshotTool.pen),
        (LogicalKeyboardKey.keyC, ScreenshotTool.cover),
      ]) {
        await tester.sendKeyEvent(k);
        await tester.pump();
        expect(e.tool, t);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.pump();
      expect(e.color, ScreenshotColor.yellow);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.pump();
      expect(e.color, ScreenshotColor.blue);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.pump();
      expect(e.color, ScreenshotColor.red);
    });

    testWidgets('when undoing and redoing with Mod+Z and Mod+Shift+Z then '
        'the editor\'s own stack changes and the shell\'s is untouched', (
      tester,
    ) async {
      await open(tester);
      final e = editor(tester);
      await drag(tester, const Offset(10, 10), const Offset(60, 40));
      await drag(tester, const Offset(100, 10), const Offset(160, 40));
      expect(e.annotations, hasLength(2));

      await mod(tester, LogicalKeyboardKey.keyZ);
      expect(e.annotations, hasLength(1));
      await mod(tester, LogicalKeyboardKey.keyZ);
      expect(e.annotations, isEmpty);
      await mod(tester, LogicalKeyboardKey.keyZ, shift: true);
      expect(e.annotations, hasLength(1));
      await tester.tap(key(ScreenshotEditorKeys.redo));
      await tester.pump();
      expect(e.annotations, hasLength(2));
      await tester.tap(key(ScreenshotEditorKeys.undo));
      await tester.pump();
      expect(e.annotations, hasLength(1));

      expect(h.undoLabels, isEmpty);
      await settleTooltips(tester);
    });

    testWidgets('when clicking an annotation then it is selected, dragging '
        'moves it and Delete removes it (undoably)', (tester) async {
      await open(tester);
      final e = editor(tester);
      await drag(tester, const Offset(10, 10), const Offset(60, 40));
      final id = e.annotations.single.id;

      await click(tester, const Offset(30, 25));
      expect(e.selectedId, id);
      await drag(tester, const Offset(30, 25), const Offset(130, 75));
      expect(
        (e.annotations.single as CoverAnnotation).rect,
        const Rect.fromLTRB(110, 60, 160, 90),
      );
      await mod(tester, LogicalKeyboardKey.keyZ);
      expect(
        (e.annotations.single as CoverAnnotation).rect,
        const Rect.fromLTRB(10, 10, 60, 40),
      );

      await click(tester, const Offset(30, 25));
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();
      expect(e.annotations, isEmpty);
      await mod(tester, LogicalKeyboardKey.keyZ);
      expect(e.annotations, hasLength(1));

      // A click on empty space clears the selection.
      await click(tester, const Offset(30, 25));
      await click(tester, const Offset(300, 150));
      expect(e.selectedId, isNull);
    });

    testWidgets('when selecting a highlight and pressing 3 then it turns '
        'blue', (tester) async {
      await open(tester);
      final e = editor(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
      await drag(tester, const Offset(10, 10), const Offset(90, 60));
      await click(tester, const Offset(10, 30));
      expect(e.selectedId, isNotNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.pump();

      expect(
        (e.annotations.single as HighlightAnnotation).color,
        ScreenshotColor.blue.color,
      );
    });

    testWidgets('when clearing then everything goes, and undo brings it '
        'back', (tester) async {
      await open(tester);
      final e = editor(tester);
      await drag(tester, const Offset(10, 10), const Offset(60, 40));
      await drag(tester, const Offset(100, 10), const Offset(160, 40));

      await tester.tap(key(ScreenshotEditorKeys.clear));
      await tester.pump();
      expect(e.annotations, isEmpty);
      await mod(tester, LogicalKeyboardKey.keyZ);
      expect(e.annotations, hasLength(2));
    });

    testWidgets('when pressing Done then the annotations are flattened and '
        'returned', (tester) async {
      await open(tester);
      await drag(tester, const Offset(10, 10), const Offset(60, 40));

      await tester.tap(key(ScreenshotEditorKeys.done));
      await tester.pumpAndSettle();

      expect(closed, isTrue);
      expect(finished.single, hasLength(1));
      expect(result!.annotations.single, isA<CoverAnnotation>());
      expect(result!.encoded, same(_encoded));
      expect(key(ScreenshotEditorKeys.dialog), findsNothing);
    });

    testWidgets('when pressing Mod+Enter then it is Done', (tester) async {
      await open(tester);
      await drag(tester, const Offset(10, 10), const Offset(60, 40));

      await mod(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(result, isNotNull);
    });

    testWidgets('when cancelling with Esc then nothing is returned', (
      tester,
    ) async {
      await open(tester);
      await drag(tester, const Offset(10, 10), const Offset(60, 40));

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(closed, isTrue);
      expect(result, isNull);
      expect(finished, isEmpty);
    });

    testWidgets('when reopened with annotations then they stay editable', (
      tester,
    ) async {
      await open(
        tester,
        initial: const [CoverAnnotation('old', Rect.fromLTWH(5, 5, 40, 20))],
      );
      final e = editor(tester);
      expect(e.annotations.single.id, 'old');

      await click(tester, const Offset(20, 15));
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(e.annotations, isEmpty);
    });

    for (final b in Brightness.values) {
      testWidgets('when shown in ${b.name} then the tools are labeled and '
          'nothing overflows at 360 px', (tester) async {
        final semantics = tester.ensureSemantics();
        await open(tester, brightness: b, size: const Size(360, 720));

        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        for (final t in ScreenshotTool.values) {
          expect(key(ScreenshotEditorKeys.tool(t)), findsOneWidget);
        }
        semantics.dispose();
      });
    }
  });
}
