import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides/commands/code_commands.dart';
import 'package:wonky_slides/features/clipboard/system_clipboard.dart';
import 'package:wonky_slides/features/elements/code/code_blocks.dart';
import 'package:wonky_slides_core/code.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/testing.dart';

import '../harness/deck_harness.dart';

const _v1 = 'void main() {\n  print(1);\n}';

void main() {
  late DeckBuilder b;
  late String slide, code, text;
  late List<String> states;
  late DeckHarness d;

  setUp(() {
    CodeBlockView.recentLanguages.clear();
    b = DeckBuilder(title: 'Code');
    slide = b.slide(layoutKey: 'blank');
    (code, states) = b.codeBlock(
      slide,
      states: [_v1, 'void main() {\n  final x = 2;\n  print(x);\n}'],
      highlights: ['1|2'],
    );
    text = b.textBox(slide, 'int a = 1;\nint b = 2;', y: 900, height: 120);
    d = DeckHarness.open(fixture: b);
    d.editor.setCurrentSlide(slide);
    d.editor.selectElements([code]);
  });
  tearDown(() => d.dispose());

  Future<CommandResult> agent(
    String id, [
    Map<String, Object?> args = const {},
  ]) => d.h.invoke(id, args, InvocationSource.mcp);

  /// 07 §15 #12: execute → undo → redo, one undo step.
  Future<CommandResult> roundTrip(
    String id,
    Map<String, Object?> args, {
    InvocationSource source = InvocationSource.mcp,
  }) async {
    final before = d.model.dump();
    final steps = d.undoLabels.length;
    final r = await d.h.invoke(id, args, source);
    expect(r.status, CommandStatus.ok, reason: '$id: ${r.message}');
    final after = d.model.dump();
    expect(after, isNot(equals(before)), reason: '$id changed nothing');
    expect(d.undoLabels.length, steps + 1, reason: '$id: one undo step');
    await d.undo();
    expect(d.model.dump(), before, reason: '$id undo');
    await d.redo();
    expect(d.model.dump(), after, reason: '$id redo');
    return r;
  }

  CodeElementData data([String? id]) => CodeElementData.fromJson(
    jsonDecode(d.model.element(id ?? code)!.dataJson!),
  );

  List<CodeStateRec> statesOf([String? id]) => d.model.codeStatesOf(id ?? code);

  group('Given Insert › Code block', () {
    test('when an agent inserts Python code then a code block with one '
        'state is centered at 60 % × 50 % and selected', () async {
      final r = await roundTrip('slides.insert.code', {
        'language': 'py',
        'code': 'print("hi")',
      });
      final id = (r.data! as Map)['elementId'] as String;
      final e = d.model.element(id)!;
      expect(e.kind, ElementKind.code);
      expect((e.x, e.y, e.width, e.height), (384.0, 270.0, 1152.0, 540.0));
      expect(data(id).language, 'python');
      expect(statesOf(id).single.code, 'print("hi")');
      expect(d.editor.selectedElementIds, [id]);
    });

    test('when no language is given then the default language and the '
        'largest font size come from the Code settings', () async {
      final r = await roundTrip('slides.insert.code', {});
      final id = (r.data! as Map)['elementId'] as String;
      expect(data(id).language, 'dart');
      expect(data(id).fontSizeMax, 24);
    });

    test('when the language is "plaintext" then the block is plain text', () {
      expect(normalizeCodeLanguage('plaintext'), '');
      expect(normalizeCodeLanguage('TS'), 'typescript');
    });
  });

  group('Given a code block', () {
    test('when setting the language, palette and options then each is one '
        'undo step', () async {
      await roundTrip('slides.code.setLanguage', {'language': 'kotlin'});
      expect(data().language, 'kotlin');
      await roundTrip('slides.code.setPalette', {'palette': 'dracula'});
      expect(data().palette, 'dracula');
      await roundTrip('slides.code.updateOptions', {
        'patch': {
          'fontSize': 30,
          'title': 'lib/main.dart',
          'highlightStyle': {'style': 'bar'},
        },
      });
      expect(data().fontSize, 30);
      expect(data().title, 'lib/main.dart');
      expect(data().highlightStyle.style, CodeHighlightStyleKind.bar);
      // The rest of highlightStyle is kept (merge patch).
      expect(data().highlightStyle.dimOpacity, 0.3);
    });

    test('when line numbers are toggled then the menu item is checked '
        'accordingly', () async {
      final st = d.services.dispatcher.stateOf('slides.code.updateOptions', {
        'toggle': 'lineNumbers',
      });
      expect(st.checked, isTrue);
      await roundTrip('slides.code.updateOptions', {'toggle': 'lineNumbers'});
      expect(data().lineNumbers, isFalse);
    });

    test('when an unknown palette is set then it is refused', () async {
      final r = await agent('slides.code.setPalette', {'palette': 'neon'});
      expect(r.status, CommandStatus.failed);
    });

    test(
      'when the code of a state is replaced then undo restores it',
      () async {
        await roundTrip('slides.code.setText', {
          'stateId': states[0],
          'code': 'fun main() {}',
        });
        expect(statesOf().first.code, 'fun main() {}');
      },
    );
  });

  group('Given the state strip', () {
    test('when a state is added then it duplicates the edit state after it '
        'and becomes the edit state', () async {
      final r = await roundTrip('slides.code.addState', {});
      final id = (r.data! as Map)['stateId'] as String;
      expect(statesOf().map((s) => s.id), [states[0], id, states[1]]);
      expect(statesOf()[1].code, _v1);
      expect(CodeBlockView.of(d.editor).stateOf(code)!.id, id);
    });

    test('when a state is duplicated, moved and deleted then each is one '
        'undo step', () async {
      final dup = await roundTrip('slides.code.duplicateState', {
        'stateId': states[1],
      });
      final id = (dup.data! as Map)['stateId'] as String;
      expect(statesOf().last.id, id);
      await roundTrip('slides.code.moveState', {
        'stateId': id,
        'to': {'index': 0},
      });
      expect(statesOf().first.id, id);
      await roundTrip('slides.code.deleteState', {'stateId': id});
      expect(statesOf().map((s) => s.id), states);
    });

    test('when only one state is left then delete is disabled with a '
        'reason', () async {
      await d.run('slides.code.deleteState', {'stateId': states[1]});
      final st = d.services.dispatcher.stateOf('slides.code.deleteState', {
        'stateId': states[0],
      });
      expect(st.enabled, isFalse);
      expect(st.disabledReason, isNotNull);
    });

    test('when the next state is selected then the canvas shows it and '
        'nothing is undoable', () async {
      final steps = d.undoLabels.length;
      final r = await d.run('slides.code.selectState', {'delta': 1});
      expect(r.status, CommandStatus.ok);
      expect(CodeBlockView.of(d.editor).stateIndexOf(code), 1);
      expect(CodeBlockView.of(d.editor).stateMap, {code: 1});
      expect(d.undoLabels.length, steps);
    });

    test('when Alt+Shift+arrows are bound then they select states on the '
        'canvas', () {
      final cmd = d.services.registry.byId('slides.code.selectState')!;
      expect(cmd.argBindings.map((b) => b.args['delta']), [-1, 1]);
    });

    test('when a state is renamed then its label is stored', () async {
      await roundTrip('slides.code.setStateLabel', {
        'stateId': states[1],
        'label': 'Add x',
      });
      expect(statesOf()[1].label, 'Add x');
    });
  });

  group('Given arrival settings', () {
    test('when a state arrives by morph at 40 cps then the transition JSON '
        'is merged', () async {
      await roundTrip('slides.code.setStateTransition', {
        'stateId': states[1],
        'transition': {'mode': 'morph', 'cps': 40},
      });
      await roundTrip('slides.code.setStateTransition', {
        'stateId': states[1],
        'transition': {'cps': null, 'jitter': 0.1},
      });
      expect((jsonDecode(statesOf()[1].transitionJson!) as Map)..remove('v'), {
        'mode': 'morph',
        'jitter': 0.1,
      });
    });
  });

  group('Given line steps and callouts', () {
    test('when steps are set with normalize then the normalized form is '
        'stored', () async {
      await roundTrip('slides.code.setHighlightSteps', {
        'stateId': states[1],
        'steps': ' 1 - 2 |  3 | ',
        'normalize': true,
      });
      expect(statesOf()[1].highlight, '1-2|3|*');
    });

    test('when steps are cleared then the column is null', () async {
      await roundTrip('slides.code.setHighlightSteps', {
        'stateId': states[0],
        'steps': '',
      });
      expect(statesOf()[0].highlight, isNull);
    });

    test('when picked lines become a step then they are compacted', () async {
      await roundTrip('slides.code.addStepFromLines', {
        'stateId': states[1],
        'lines': [4, 1, 2, 3],
      });
      expect(statesOf()[1].highlight, '1-4');
      expect(compactLineRanges([1, 2, 3, 5, 7, 8]), '1-3,5,7-8');
    });

    test(
      'when a callout is set and removed then the annotations follow',
      () async {
        await roundTrip('slides.code.setCallout', {
          'stateId': states[0],
          'step': 2,
          'callout': {'text': '**Null-safe**', 'side': 'right'},
        });
        final ann = CodeAnnotations.fromJson(
          jsonDecode(statesOf()[0].annotationsJson!),
        );
        expect(ann[1]!.text, '**Null-safe**');
        expect(ann[1]!.side, 'right');
        await roundTrip('slides.code.setCallout', {
          'stateId': states[0],
          'step': 2,
          'callout': null,
        });
        expect(statesOf()[0].annotationsJson, isNull);
      },
    );
  });

  group('Given in-place editing', () {
    test('when typing is committed then it is one "Typing" step that undo '
        'reverts', () async {
      final r = await d.run('slides.code.edit', {});
      expect(r.status, CommandStatus.ok);
      final session = CodeBlockView.of(d.editor).editing!;
      session.edit('$_v1\n// done');
      session.commit();
      expect(statesOf().first.code, '$_v1\n// done');
      expect(d.undoLabels.first, 'Typing');
      await d.undo();
      expect(statesOf().first.code, _v1);
      CodeBlockView.of(d.editor).endEdit();
    });

    test('when undo runs while typing is pending then the burst is written '
        'first', () async {
      await d.run('slides.code.edit', {});
      CodeBlockView.of(d.editor).editing!.edit('x');
      await d.undo();
      expect(statesOf().first.code, _v1);
      CodeBlockView.of(d.editor).endEdit();
    });
  });

  group('Given view commands', () {
    test(
      'when the code is copied then the edit state is on the clipboard',
      () async {
        final clip = MemorySlidesClipboard();
        final saved = SlidesSystemClipboard.instance;
        SlidesSystemClipboard.instance = clip;
        addTearDown(() => SlidesSystemClipboard.instance = saved);
        await d.run('slides.code.selectState', {'index': 1});
        await d.run('slides.code.copy', {});
        expect(clip.writes.single.plainText, statesOf()[1].code);
      },
    );

    test('when the diff gutter and a step preview are toggled then the view '
        'follows', () async {
      await d.run('slides.code.toggleDiffGutter');
      expect(CodeBlockView.of(d.editor).diffGutter, isTrue);
      await d.run('slides.code.previewStep', {'step': 2});
      expect(CodeBlockView.of(d.editor).stepMap, {code: 1});
      await d.run('slides.code.preview', {'index': 1});
      expect(CodeBlockView.of(d.editor).preview?.to, 1);
    });
  });

  group('Given a text box with code', () {
    test('when converted then a code block takes its frame and text, and '
        'one undo brings the text box back', () async {
      d.editor.selectElements([text]);
      final r = await roundTrip('slides.code.convertFromText', {
        'language': 'dart',
      });
      final id = (r.data! as Map)['elementId'] as String;
      expect(d.model.element(text), isNull);
      final e = d.model.element(id)!;
      expect((e.y, e.height), (900.0, 120.0));
      expect(statesOf(id).single.code, 'int a = 1;\nint b = 2;');
    });
  });

  group('Given every code command', () {
    test('when mergePatch applies RFC 7386 then nulls remove and maps '
        'merge', () {
      expect(
        mergePatch(
          {
            'a': 1,
            'b': {'c': 2, 'd': 3},
          },
          {
            'a': null,
            'b': {'d': null, 'e': 4},
          },
        ),
        {
          'b': {'c': 2, 'e': 4},
        },
      );
    });
  });
}
