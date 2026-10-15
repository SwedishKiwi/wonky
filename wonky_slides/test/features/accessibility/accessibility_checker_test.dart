import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_slides/features/accessibility/accessibility_checker.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/planner.dart';
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_slides_core/session.dart';
import 'package:wonky_slides_core/testing.dart';
import 'package:wonky_slides_core/themes.dart';
import 'package:wonky_sync_models/ids.dart' show SequentialIdGenerator;

String _text(String text, Map<String, Object?> attrs) => jsonEncode([
  {'insert': text, 'attributes': attrs},
  {'insert': '\n'},
]);

/// The accessibility checker's rules and quick fixes (Slides 03 §17.4;
/// SL-34).
void main() {
  late DeckBuilder b;

  setUp(() => b = DeckBuilder(title: 'A11y'));

  MemoryDeck deckOf() => MemoryDeck(
    model: b.build(),
    userId: b.userId,
    planner: const SlidesPlanner(),
    ids: SequentialIdGenerator(9000),
  );

  List<A11yIssue> check(DeckModel m) => AccessibilityChecker.check(m).issues;

  List<(A11yRule, String?)> rules(DeckModel m, String slide) => [
    for (final i in check(m))
      if (i.slideId == slide) (i.rule, i.elementId),
  ];

  String textBox(String slide, String text, Map<String, Object?> attrs) =>
      b.element(
        slide,
        ElementKind.text,
        x: 200,
        y: 400,
        width: 800,
        height: 200,
        columns: {SlidesCols.text: _text(text, attrs)},
      );

  group('Given images, icons and charts', () {
    test('when they have no alt text then each is an error unless it is '
        'decorative or described', () {
      final s = b.slide(layoutKey: 'blank');
      final image = b.element(s, ElementKind.image);
      b.element(s, ElementKind.image, columns: {ElementCols.decorative: true});
      b.element(s, ElementKind.icon, columns: {ElementCols.altText: 'Star'});
      final chart = b.element(s, ElementKind.chart);
      final m = b.build();

      final issues = check(m).where((i) => i.rule == A11yRule.missingAltText);

      expect({for (final i in issues) i.elementId}, {image, chart});
      expect(issues.first.severity, A11ySeverity.error);
    });
  });

  group('Given text colors on the slide background', () {
    test('when light gray text is on a light slide then it is low contrast '
        'with its ratio', () {
      final s = b.slide(title: 'Contrast');
      final pale = textBox(s, 'Pale', {'color': '#EEEEEE', 'size': 24});
      final dark = textBox(s, 'Dark', {'color': '#111111'});
      final m = b.build();

      final low = check(m).where((i) => i.rule == A11yRule.lowContrast);

      expect([for (final i in low) i.elementId], [pale]);
      expect(low.single.ratio, lessThan(1.5));
      expect(low.single.required, 4.5);
      expect(rules(m, s), isNot(contains((A11yRule.lowContrast, dark))));
    });

    test('when mid gray is large (≥ 40) then 3:1 is enough, when smaller '
        'then 4.5:1 is needed', () {
      final s = b.slide(title: 'Sizes');
      final big = textBox(s, 'Big', {'color': '#888888', 'size': 48});
      final normal = textBox(s, 'Normal', {'color': '#888888', 'size': 24});
      final m = b.build();

      final low = {
        for (final i in check(m))
          if (i.rule == A11yRule.lowContrast) i.elementId,
      };

      expect(low, contains(normal));
      expect(low, isNot(contains(big)));
    });

    test('when the deck is dark then theme colors resolve for dark and '
        'near-black text is low contrast', () {
      final s = b.slide(title: 'Dark');
      final black = textBox(s, 'Black', {'color': '#111111'});
      final themed = textBox(s, 'Themed', {'color': 'theme:text1'});
      final d = deckOf();

      final light = {
        for (final i in check(d.model))
          if (i.rule == A11yRule.lowContrast) i.elementId,
      };
      d.execute(const SetDeckProps(appearance: SlideAppearance.dark));
      final dark = {
        for (final i in check(d.model))
          if (i.rule == A11yRule.lowContrast) i.elementId,
      };

      expect(light, isEmpty);
      expect(dark, {black});
      expect(dark, isNot(contains(themed)));
    });

    test('when text sits on a filled shape then the shape is its '
        'background', () {
      final s = b.slide(layoutKey: 'blank');
      b.shape(
        s,
        x: 0,
        y: 0,
        width: 1920,
        height: 1080,
        fillJson: jsonEncode({'v': 1, 'type': 'solid', 'color': '#000000'}),
      );
      final onBlack = textBox(s, 'On black', {'color': '#222222'});
      final m = b.build();

      expect(rules(m, s), contains((A11yRule.lowContrast, onBlack)));
    });

    test('when text sits inside an ellipse\'s frame but outside the '
        'ellipse then the ellipse is not its background (SL-36 '
        'regression: the Pitch deck\'s orb)', () {
      final s = b.slide(layoutKey: 'blank');
      // A black circle whose frame corner reaches the text box's center
      // (600, 500): the corner of the frame is outside the circle.
      b.shape(
        s,
        x: 560,
        y: 460,
        width: 1000,
        height: 1000,
        geometry: 'ellipse',
        fillJson: jsonEncode({'v': 1, 'type': 'solid', 'color': '#000000'}),
      );
      final outside = textBox(s, 'Dark on white', {'color': '#222222'});
      // Inside the circle the same text is low contrast.
      final inside = b.element(
        s,
        ElementKind.text,
        x: 860,
        y: 860,
        width: 400,
        height: 200,
        columns: {
          SlidesCols.text: _text('Dark on black', {'color': '#222222'}),
        },
      );
      final m = b.build();

      final low = [
        for (final i in check(m))
          if (i.rule == A11yRule.lowContrast) i.elementId,
      ];
      expect(low, isNot(contains(outside)));
      expect(low, contains(inside));
    });

    test('when text sits on an image then its contrast is a warning to '
        'check by eye', () {
      final s = b.slide(layoutKey: 'blank');
      b.element(
        s,
        ElementKind.image,
        x: 0,
        y: 0,
        width: 1920,
        height: 1080,
        columns: {ElementCols.altText: 'Photo'},
      );
      final caption = textBox(s, 'Caption', {'color': '#FFFFFF'});
      final m = b.build();

      final issue = check(m).firstWhere((i) => i.elementId == caption);
      expect(issue.rule, A11yRule.contrastOverImage);
      expect(issue.severity, A11ySeverity.warning);
    });
  });

  group('Given slide titles', () {
    test('when a slide has no title text or heading then it is flagged; a '
        'heading paragraph counts as a title', () {
      final none = b.slide(layoutKey: 'blank');
      final heading = b.slide(layoutKey: 'blank');
      b.element(
        heading,
        ElementKind.text,
        columns: {
          SlidesCols.text: jsonEncode([
            {'insert': 'Results'},
            {
              'insert': '\n',
              'attributes': {'style': 'heading'},
            },
          ]),
        },
      );
      final m = b.build();

      expect(rules(m, none), contains((A11yRule.missingTitle, null)));
      expect(rules(m, heading), isNot(contains((A11yRule.missingTitle, null))));
      expect(AccessibilityChecker.slideTitle(m, heading), 'Results');
    });

    test('when two slides share a title then both are flagged and skipped '
        'slides are not checked', () {
      final a = b.slide(title: 'Same');
      final c = b.slide(title: ' same ');
      final skipped = b.slide(title: 'Same', skipped: true);
      final m = b.build();

      final dup = check(m).where((i) => i.rule == A11yRule.duplicateTitle);

      expect({for (final i in dup) i.slideId}, {a, c});
      expect(check(m).where((i) => i.slideId == skipped), isEmpty);
    });
  });

  group('Given small text, tables and placeholders', () {
    test('when text is under 18 then it is flagged with its size and the '
        'fix enlarges only the small runs', () {
      final s = b.slide(title: 'Small');
      final small = b.element(
        s,
        ElementKind.text,
        columns: {
          SlidesCols.text: jsonEncode([
            {
              'insert': 'Tiny',
              'attributes': {'size': 12},
            },
            {
              'insert': ' big',
              'attributes': {'size': 30},
            },
            {'insert': '\n'},
          ]),
        },
      );
      final d = deckOf();

      final issue = check(
        d.model,
      ).firstWhere((i) => i.rule == A11yRule.smallText);
      expect((issue.elementId, issue.size), (small, 12));
      expect(AccessibilityChecker.minTextSize, 18);

      final ops = A11yFixes.opsFor(d.model, issue)!;
      expect(ops, hasLength(1));
      expect((ops.single as FormatText).start, 0);
      expect((ops.single as FormatText).length, 4);
      for (final op in ops) {
        d.execute(op);
      }
      expect(
        check(d.model).where((i) => i.rule == A11yRule.smallText),
        isEmpty,
      );
    });

    test('when a table has no header row then it is flagged and the fix '
        'turns the header row on', () {
      final s = b.slide(title: 'Table');
      final t = b.table(s).$1;
      final d = deckOf();
      d.execute(
        SetTableOptions(t, const {
          'options': {'headerRow': false},
        }),
      );

      final issue = check(
        d.model,
      ).firstWhere((i) => i.rule == A11yRule.tableHeader);
      expect(issue.elementId, t);
      for (final op in A11yFixes.opsFor(d.model, issue)!) {
        d.execute(op);
      }

      expect(
        check(d.model).where((i) => i.rule == A11yRule.tableHeader),
        isEmpty,
      );
    });

    test('when a body placeholder is empty then it is a tip whose fix '
        'removes it', () {
      final s = b.slide(title: 'Only a title');
      final d = deckOf();

      final issue = check(
        d.model,
      ).firstWhere((i) => i.rule == A11yRule.emptyPlaceholder);
      expect(issue.slideId, s);
      expect(issue.severity, A11ySeverity.info);
      final id = issue.elementId!;
      for (final op in A11yFixes.opsFor(d.model, issue)!) {
        d.execute(op);
      }

      expect(d.model.element(id), isNull);
    });
  });

  group('Given a custom reading order', () {
    test('when the title is no longer read first then it is flagged and '
        'the fix resets it', () {
      final s = b.slide(title: 'Order', body: 'Body');
      final box = textBox(s, 'Note', {'color': '#000000'});
      final d = deckOf();
      final title = d.model
          .elementsOf(s)
          .firstWhere((e) => e.placeholderType == SlidePlaceholderType.title);
      d.execute(SetReadingOrder(s, [box, title.id]));

      final issue = check(
        d.model,
      ).firstWhere((i) => i.rule == A11yRule.readingOrder);
      for (final op in A11yFixes.opsFor(d.model, issue)!) {
        d.execute(op);
      }

      expect(
        check(d.model).where((i) => i.rule == A11yRule.readingOrder),
        isEmpty,
      );
    });
  });

  group('Given low contrast text', () {
    test('when the contrast fix runs then the text gets a theme color that '
        'passes, in light and dark', () {
      final s = b.slide(title: 'Fix');
      final pale = textBox(s, 'Pale', {'color': '#F0F0F0'});
      final d = deckOf();

      for (final appearance in SlideAppearance.values) {
        d.execute(SetDeckProps(appearance: appearance));
        if (appearance == SlideAppearance.dark) {
          d.execute(
            FormatText([ElementText(pale)], const {'color': '#101010'}),
          );
        }
        final issue = check(
          d.model,
        ).firstWhere((i) => i.rule == A11yRule.lowContrast);
        final color = A11yFixes.contrastColor(d.model, s, pale);
        expect(color, startsWith('theme:'), reason: appearance.name);
        for (final op in A11yFixes.opsFor(d.model, issue)!) {
          d.execute(op);
        }
        expect(
          check(d.model).where((i) => i.rule == A11yRule.lowContrast),
          isEmpty,
          reason: appearance.name,
        );
      }
    });

    test('when the report is serialized then it lists counts and issues', () {
      final s = b.slide(layoutKey: 'blank');
      b.element(s, ElementKind.image);
      final json = AccessibilityChecker.check(b.build()).toJson();

      expect(json['errors'], 1);
      final issues = json['issues']! as List;
      expect(issues.map((i) => (i as Map)['rule']), contains('missingAltText'));
      expect((issues.first as Map)['fixable'], isA<bool>());
    });
  });
}
