import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides/features/canvas/slide_canvas_controller.dart';
import 'package:wonky_slides/features/stage/slide_renderer.dart';
import 'package:wonky_slides/features/text_editing/text_editing_host.dart';
import 'package:wonky_slides/features/text_editing/text_format.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/testing.dart';
import 'package:wonky_slides_core/themes.dart' show SlidePlaceholderType;

import '../features/stage/stage_fixture.dart' show RecordingFontRegistry;
import '../harness/deck_harness.dart';

/// A blank slide with text boxes `a` ("Hello world") and `b` ("Other"), a
/// plain shape, and a `titleBody` slide with filled placeholders.
class _Fixture {
  _Fixture() {
    slide = b.slide(layoutKey: 'blank');
    a = b.textBox(slide, 'Hello world', x: 100, y: 100, width: 800);
    other = b.textBox(slide, 'Other', x: 100, y: 400, width: 800);
    shape = b.shape(slide, x: 1200, y: 100);
    second = b.slide(layoutKey: 'titleBody', title: 'Title', body: 'Item');
  }

  final DeckBuilder b = DeckBuilder(title: 'Text');
  late final String slide, a, other, shape, second;
}

class _Locks extends TextEditLocks {
  _Locks(this.held, {this.allow = true});
  final String held;
  final bool allow;
  final claims = <String>[];

  @override
  Future<bool> request(String elementId) async => allow;

  @override
  void claim(String elementId) => claims.add(elementId);

  @override
  String? heldBy(String elementId) => elementId == held ? 'Anna' : null;
}

/// The stored text and box style of [id] (one comparable state).
(String?, String?) _state(DeckHarness d, String id) {
  final e = d.model.element(id)!;
  return (e.text, e.textStyleJson);
}

List<Map<String, Object?>> _ops(DeckHarness d, String id) => [
  for (final op in SlidesText.parse(d.model.element(id)!.text).operations)
    {'insert': op.data, ...?op.attributes},
];

Map<String, Object?> _box(DeckHarness d, String id) {
  final j = d.model.element(id)!.textStyleJson;
  return j == null ? const {} : (jsonDecode(j) as Map).cast();
}

void main() {
  late _Fixture f;
  late DeckHarness d;
  late SlideCanvasController canvas;

  setUp(() {
    f = _Fixture();
    d = DeckHarness.open(fixture: f.b);
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

  group('Given a selected text box', () {
    final cases = <(String, String, Map<String, Object?>, bool Function())>[];
    void add(
      String name,
      String id,
      Map<String, Object?> args,
      bool Function() check,
    ) => cases.add((name, id, args, check));

    Map<String, Object?> first() => _ops(d, f.a).first;
    Map<String, Object?> para() => _ops(d, f.a).last;
    add('bold', 'slides.format.bold', {}, () => first()['bold'] == true);
    add('italic', 'slides.format.italic', {}, () => first()['italic'] == true);
    add(
      'underline',
      'slides.format.underline',
      {},
      () => first()['underline'] == true,
    );
    add(
      'strikethrough',
      'slides.format.strikethrough',
      {},
      () => first()['strike'] == true,
    );
    add('superscript', 'slides.format.script', {
      'value': 'super',
    }, () => first()['script'] == 'super');
    add('caps', 'slides.format.caps', {
      'value': 'upper',
    }, () => first()['caps'] == 'all');
    add('text style', 'slides.format.textStyle', {
      'key': 'heading',
    }, () => para()['style'] == 'heading');
    add('font', 'slides.format.font', {
      'family': 'Lato',
    }, () => first()['font'] == 'Lato');
    add('font size', 'slides.format.fontSize', {
      'size': 40,
    }, () => first()['size'] == 40);
    add(
      'bigger font',
      'slides.format.increaseFontSize',
      {},
      () => (first()['size'] as num) > 0,
    );
    add('text color', 'slides.format.textColor', {
      'color': '#FF0000',
    }, () => first()['color'] == '#FF0000');
    add('highlight', 'slides.format.highlight', {
      'color': 'theme:accent2',
    }, () => first()['highlight'] == 'theme:accent2');
    add('letter spacing', 'slides.format.letterSpacing', {
      'value': 0.1,
    }, () => first()['letterSpacing'] == 0.1);
    add('align', 'slides.format.align', {
      'value': 'center',
    }, () => para()['align'] == 'center');
    add('anchor', 'slides.format.anchor', {
      'value': 'bottom',
    }, () => _box(d, f.a)['anchor'] == 'bottom');
    add('indent', 'slides.format.indent', {}, () => para()['indent'] == 1);
    add('line spacing', 'slides.format.lineHeight', {
      'value': 1.5,
    }, () => para()['lineHeight'] == 1.5);
    add('space before', 'slides.format.paragraphSpacing', {
      'before': true,
    }, () => para()['spaceBefore'] == 12);
    add('bullets', 'slides.format.list', {
      'type': 'bullet',
    }, () => para()['list'] == 'bullet');
    add('checklist', 'slides.format.list', {
      'type': 'check',
    }, () => para()['list'] == 'unchecked');
    add(
      'numbering style',
      'slides.format.listStyle',
      {'style': 'upperRoman'},
      () => para()['listStyle'] == 'upperRoman' && para()['list'] == 'ordered',
    );
    add('list start', 'slides.format.listStart', {
      'n': 3,
    }, () => para()['listStart'] == 3);
    add('autofit', 'slides.format.autofit', {
      'mode': 'shrink',
    }, () => _box(d, f.a)['autofit'] == 'shrink');
    add('insets', 'slides.format.insets', {
      't': 20,
    }, () => (_box(d, f.a)['insets'] as List).first == 20);
    add(
      'element link',
      'slides.element.setLink',
      {'url': 'example.com'},
      () =>
          d.model.element(f.a)!.linkJson?.contains('https://example.com') ??
          false,
    );

    for (final (name, id, args, check) in cases) {
      testWidgets('when "$name" ($id) runs then the whole body changes in one '
          'step that undo and redo replay', (tester) async {
        d.editor.selectElements([f.a]);
        final before = (_state(d, f.a), d.model.element(f.a)!.linkJson);

        final r = await d.run(id, args);
        final after = (_state(d, f.a), d.model.element(f.a)!.linkJson);

        expect(r.status, CommandStatus.ok, reason: r.message);
        expect(check(), isTrue, reason: '$after');
        expect(d.undoLabels, hasLength(1));
        await d.undo();
        expect((_state(d, f.a), d.model.element(f.a)!.linkJson), before);
        await d.redo();
        expect((_state(d, f.a), d.model.element(f.a)!.linkJson), after);
      });
    }

    testWidgets('when bold runs twice then it toggles off, and Clear '
        'formatting removes inline attributes but keeps the link', (
      tester,
    ) async {
      d.editor.selectElements([f.a]);
      await d.run('slides.format.bold');
      expect(d.services.dispatcher.stateOf('slides.format.bold').checked, true);
      await d.run('slides.format.bold');
      expect(_ops(d, f.a).first['bold'], isNull);

      await d.run('slides.format.italic');
      await d.run('slides.format.fontSize', {'size': 50});
      await d.run('slides.insert.link', {'url': 'https://a.example'});
      d.editor.selectElements([f.a]);
      textEditingOf(d.editor).end(select: false);
      await d.run('slides.format.clear');

      expect(_ops(d, f.a).first.keys, isNot(contains('italic')));
      expect(_ops(d, f.a).first.keys, isNot(contains('size')));
    });

    testWidgets('when two boxes are selected and one is edited by someone else '
        'then formatting skips it', (tester) async {
      textEditingOf(d.editor).locks = _Locks(f.other);
      d.editor.selectElements([f.a, f.other]);

      await d.run('slides.format.underline');

      expect(_ops(d, f.a).first['underline'], isTrue);
      expect(_ops(d, f.other).first['underline'], isNull);
    });
  });

  group('Given a text box being edited', () {
    testWidgets('when a range is formatted then only the range changes and '
        'editing goes on', (tester) async {
      final host = textEditingOf(d.editor);
      expect(await host.begin(f.a), isTrue);
      host.active!.selectRange(0, 5);

      await d.run('slides.format.bold');

      final ops = _ops(d, f.a);
      expect(ops.first, {'insert': 'Hello', 'bold': true});
      expect(ops[1]['bold'], isNull);
      expect(host.elementId, f.a);
      expect(d.undoLabels, hasLength(1));
      await d.undo();
      expect(_ops(d, f.a).first['bold'], isNull);
      expect(host.active!.selectionRange, (0, 5));
    });

    testWidgets('when the caret is collapsed then bold sets the typing '
        'attributes without an undo step', (tester) async {
      final host = textEditingOf(d.editor);
      await host.begin(f.a);

      await d.run('slides.format.bold');

      expect(d.undoLabels, isEmpty);
      expect(
        d.services.dispatcher.stateOf('slides.format.bold').checked,
        isTrue,
      );
      host.active!.insertText('!');
      host.commit();
      expect(_ops(d, f.a)[1], {'insert': '!', 'bold': true});
    });

    testWidgets('when typing is pending and a format command runs then the '
        'typing is written first as its own step', (tester) async {
      final host = textEditingOf(d.editor);
      await host.begin(f.a, caretOffset: 0);
      host.active!.insertText('X');
      expect(host.active!.hasPendingEdits, isTrue);
      host.active!.selectRange(0, 1);

      await d.run('slides.format.italic');

      expect(d.undoLabels.length, 2);
      expect(_ops(d, f.a).first, {'insert': 'X', 'italic': true});
    });

    testWidgets('when Mod+K inserts a link at the caret then the address is '
        'inserted as linked text in one step', (tester) async {
      final host = textEditingOf(d.editor);
      await host.begin(f.a);

      await d.run('slides.insert.link', {'url': 'https://wonky.example'});

      expect(_ops(d, f.a)[1], {
        'insert': 'https://wonky.example',
        'link': 'https://wonky.example',
      });
      expect(d.undoLabels, hasLength(1));
      expect(host.active!.selectionRange, (32, 32));
    });

    testWidgets('when exit editing runs then the box is selected and nothing '
        'is edited', (tester) async {
      final host = textEditingOf(d.editor);
      await host.begin(f.a);

      await d.run('slides.text.exitEditing');

      expect(host.isEditing, isFalse);
      expect(d.editor.textEditing, isFalse);
      expect(d.editor.selectedElementIds, [f.a]);
    });

    testWidgets('when another element is selected then editing ends and '
        'pending typing is written', (tester) async {
      final host = textEditingOf(d.editor);
      await host.begin(f.a);
      host.active!.insertText('?');

      d.editor.selectElements([f.shape]);
      d.editor.textEditing = false;
      d.editor.selectElements([f.shape]);

      expect(host.isEditing, isFalse);
      expect(
        SlidesText.plainText(d.model.element(f.a)!.text),
        'Hello world?\n',
      );
    });
  });

  group('Given the soft-lock hook (SL-21)', () {
    testWidgets('when the hook refuses then editing does not start; when it '
        'allows then the body is claimed', (tester) async {
      final host = textEditingOf(d.editor);
      host.locks = _Locks(f.a, allow: false);
      expect(await host.begin(f.a), isFalse);
      expect(host.isEditing, isFalse);

      final locks = _Locks(f.a);
      host.locks = locks;
      expect(await host.begin(f.a), isTrue);
      expect(locks.claims, [f.a]);
    });
  });

  group('Given an auto-width text box', () {
    testWidgets('when it is resized by hand then it wraps from now on, in the '
        'same step', (tester) async {
      d.editor.selectElements([f.a]);
      await d.run('slides.format.autofit', {'mode': 'resize'});
      d.editor.selectElements([f.a]);
      final h = await d.run('slides.element.resize', {
        'frames': [
          {
            'id': f.a,
            'x': 100,
            'y': 100,
            'width': 500,
            'height': 80,
            'wrap': true,
          },
        ],
      });

      expect(h.status, CommandStatus.ok);
      expect(_box(d, f.a)['wrap'], isTrue);
      expect(d.model.element(f.a)!.width, 500);
      await d.undo();
      expect(_box(d, f.a)['wrap'], isNull);
      expect(d.model.element(f.a)!.width, 800);
    });
  });

  group('Given activation and insertion', () {
    testWidgets('when Enter activates a selected text box then editing starts '
        'with the caret at the end', (tester) async {
      d.editor.selectElements([f.a]);

      final r = await d.run('slides.element.activate');

      expect(r.status, CommandStatus.ok);
      expect(textEditingOf(d.editor).active!.selectionRange, (11, 11));
    });

    testWidgets('when a shape without text is selected then activation is '
        'enabled (typing adds text), and without a selection it is disabled', (
      tester,
    ) async {
      d.editor.selectElements([f.shape]);
      expect(
        d.services.dispatcher.stateOf('slides.element.activate').enabled,
        isTrue,
      );
      d.editor.selectElements(const []);
      expect(
        d.services.dispatcher.stateOf('slides.element.activate').enabled,
        isFalse,
      );
    });

    testWidgets('when Insert › Text box runs from the menu then the tool is '
        'armed, and from the palette a 960 × 120 box is centered', (
      tester,
    ) async {
      await d.h.invoke(
        'slides.insert.textBox',
        const {},
        InvocationSource.menu,
      );
      expect(d.editor.armedTool, 'text');

      await d.h.invoke(
        'slides.insert.textBox',
        const {},
        InvocationSource.palette,
      );

      final id = textEditingOf(d.editor).elementId!;
      final e = d.model.element(id)!;
      expect((e.x, e.y, e.width, e.height), (480.0, 480.0, 960.0, 120.0));
      expect(d.editor.armedTool, isNull);
      expect(d.undoLabels, hasLength(1));
      await d.undo();
      expect(d.model.element(id), isNull);
    });

    testWidgets('when an agent inserts a box with text then it is selected, '
        'not edited', (tester) async {
      final r = await d.h.invoke('slides.insert.textBox', const {
        'x': 10,
        'y': 20,
        'text': 'From MCP',
      }, InvocationSource.mcp);

      final id = (r.data as Map)['elementId'] as String;
      expect(textEditingOf(d.editor).isEditing, isFalse);
      expect(d.editor.selectedElementIds, [id]);
      expect(SlidesText.plainText(d.model.element(id)!.text), 'From MCP\n');
    });
  });

  group('Given placeholders', () {
    String placeholder(SlidePlaceholderType t) {
      d.editor.setCurrentSlide(f.second);
      return canvas.slide!.elements
          .firstWhere((e) => e.placeholderType == t)
          .id;
    }

    testWidgets('when a moved title is reset to the layout then its frame '
        'inherits again; undo restores the move', (tester) async {
      final title = placeholder(SlidePlaceholderType.title);
      d.editor.selectElements([title]);
      await d.run('slides.element.move', {
        'ids': [title],
        'dx': 50,
        'dy': 40,
      });
      final moved = d.model.element(title)!.x;
      expect(moved, isNotNull);

      await d.run('slides.element.resetPlaceholder');
      expect(d.model.element(title)!.x, isNull);
      expect(d.undoLabels, contains('slides.element.resetPlaceholder'));

      await d.undo();
      expect(d.model.element(title)!.x, moved);
    });

    testWidgets('when bullets are toggled in a body placeholder (bulleted by '
        'the layout) then the default list is turned off and on again', (
      tester,
    ) async {
      final body = placeholder(SlidePlaceholderType.body);
      d.editor.selectElements([body]);
      bool checked() => d.services.dispatcher.stateOf('slides.format.list', {
        'type': 'bullet',
      }).checked!;
      expect(checked(), isTrue);

      await d.run('slides.format.list', {'type': 'bullet'});
      expect(_ops(d, body).last['listStyle'], 'none');
      expect(checked(), isFalse);

      await d.run('slides.format.list', {'type': 'bullet'});
      expect(_ops(d, body).last['listStyle'], isNull);
      expect(_ops(d, body).last['list'], 'bullet');
      expect(checked(), isTrue);
    });

    testWidgets('when the format state is read then the placeholder style and '
        'the theme values show', (tester) async {
      final title = placeholder(SlidePlaceholderType.title);
      d.editor.selectElements([title]);

      final st = TextFormatState.of(TextFormatScope.of(d.editor));

      expect(st.styleKey, 'heading');
      expect(st.size, greaterThan(0));
      expect(st.anchor, isNotNull);
    });
  });
}
