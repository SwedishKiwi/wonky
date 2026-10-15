import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_slides/features/canvas/slide_canvas_controller.dart';
import 'package:wonky_slides/features/editor_screen/deck_editor_controller.dart';
import 'package:wonky_slides/features/inspector/deck_inspector.dart';
import 'package:wonky_slides/features/toolbar/slides_toolbar.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/schema.dart';

import '../../harness/deck_harness.dart';
import '../../support/slides_harness.dart';
import '../canvas/canvas_rig.dart' show CanvasFixture;

/// The inspector's Format sections and the contextual toolbar of shapes,
/// lines, icons and groups (Slides 04 §6.2, §7.2; SL-14).
void main() {
  late CanvasFixture f;
  late DeckHarness d;
  late String icon;

  setUp(() {
    f = CanvasFixture();
    icon = f.b.element(
      f.slide,
      ElementKind.icon,
      x: 1500,
      y: 900,
      width: 160,
      height: 160,
      columns: {
        ElementCols.dataJson: jsonEncode({
          'v': 1,
          'set': 'lucide',
          'name': 'rocket',
          'strokeWidth': 2,
        }),
      },
    );
    d = DeckHarness.open(fixture: f.b);
    d.editor.setCurrentSlide(f.slide);
    d.editor.openInspector(InspectorTab.format);
  });
  tearDown(() => d.dispose());

  Future<void> pumpInspector(
    WidgetTester tester, {
    double width = 300,
    Brightness brightness = Brightness.light,
  }) => pumpSlides(
    tester,
    d.h,
    Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        height: 1400,
        child: DeckInspector(services: d.services, editor: d.editor),
      ),
    ),
    size: Size(width, 1400),
    brightness: brightness,
  );

  Finder section(String id) =>
      find.byKey(ValueKey<String>('slides.inspector.section.$id'));

  for (final brightness in Brightness.values) {
    for (final width in [300.0, 360.0]) {
      testWidgets('when a shape, a line, an icon, a group or several objects '
          'are selected at ${width.toInt()} px in ${brightness.name} mode '
          'then their sections show without overflow', (tester) async {
        final cases = <List<String>, List<String>>{
          [f.a]: ['text', 'fill', 'border', 'effects', 'arrange'],
          [f.line]: ['line', 'effects', 'arrange'],
          [icon]: ['icon', 'arrange', 'accessibility'],
          [f.g]: ['effects', 'arrange', 'accessibility'],
          [f.a, f.c]: ['fill', 'border', 'effects', 'arrange'],
        };
        for (final MapEntry(key: ids, value: sections) in cases.entries) {
          selectionOf(d.editor).select(ids);
          await pumpInspector(tester, width: width, brightness: brightness);
          for (final s in sections) {
            expect(section(s), findsOneWidget, reason: '$ids $s');
          }
          expect(find.text('Not available yet'), findsNothing);
          expect(tester.takeException(), isNull, reason: '$ids');
        }
      });
    }
  }

  testWidgets('when pressing No fill then the shape gets no fill in one step', (
    tester,
  ) async {
    selectionOf(d.editor).select([f.a]);
    await pumpInspector(tester);

    await tester.tap(find.byKey(const ValueKey('slides.style.fill.none')));
    await tester.pumpAndSettle();

    expect(jsonDecode(d.model.element(f.a)!.str(ElementCols.fillJson)!), {
      'v': 1,
      'type': 'none',
    });
    expect(d.undoLabels.length, 1);
  });

  testWidgets('when toggling the shadow and Decorative then the effects and '
      'the flag are written', (tester) async {
    selectionOf(d.editor).select([icon]);
    await pumpInspector(tester);
    await tester.tap(find.byKey(const ValueKey('slides.a11y.decorative')));
    await tester.pumpAndSettle();
    expect(d.model.element(icon)!.decorative, isTrue);

    selectionOf(d.editor).select([f.a]);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('slides.style.effects.shadow')),
    );
    await tester.tap(find.byKey(const ValueKey('slides.style.effects.shadow')));
    await tester.pumpAndSettle();
    expect(
      jsonDecode(d.model.element(f.a)!.str(ElementCols.effectsJson)!),
      contains('shadow'),
    );
  });

  testWidgets('when renaming in the Arrange section then the name is written '
      'on Enter', (tester) async {
    selectionOf(d.editor).select([f.a]);
    await pumpInspector(tester);
    final field = find.descendant(
      of: find.byKey(const ValueKey('slides.arrange.name')),
      matching: find.byType(EditableText),
    );
    await tester.ensureVisible(field);
    await tester.enterText(field, 'Hero box');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(d.model.element(f.a)!.name, 'Hero box');
  });

  for (final (name, ids, keys) in [
    (
      'shape',
      () => [f.a],
      ['fill', 'border', 'strokeWeight', 'quickStyles', 'changeShape'],
    ),
    (
      'line',
      () => [f.line],
      ['lineColor', 'strokeWeight', 'startArrow', 'endArrow', 'routing'],
    ),
    ('icon', () => [icon], ['iconColor', 'iconStroke', 'icon.replace']),
  ]) {
    testWidgets('when a $name is selected then the toolbar shows its '
        'controls', (tester) async {
      selectionOf(d.editor).select(ids());
      await pumpSlides(
        tester,
        d.h,
        SlidesToolbar(services: d.services, editor: d.editor),
        size: const Size(2400, 200),
      );
      for (final k in keys) {
        expect(
          find.byKey(ValueKey<String>('slides.toolbar.$k')),
          findsOneWidget,
          reason: k,
        );
      }
    });
  }
}
