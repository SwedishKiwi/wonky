import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shad/shad.dart' show LucideIcons, ShadButton;
import 'package:wonky_slides/features/elements/icon/icon_picker.dart';
import 'package:wonky_slides/features/elements/icon/lucide_icon_source.dart';
import 'package:wonky_slides_core/icons.dart';

import '../../harness/deck_harness.dart';
import '../../support/slides_harness.dart';

final search = find.descendant(
  of: find.byKey(IconPickerKeys.search),
  matching: find.byType(EditableText),
);

void main() {
  group('Given the Lucide icon source', () {
    test('when the font package changes then the code points still match '
        'its IconData constants', () {
      // Drift guard: regenerate `lucide_glyphs.g.dart` after upgrading
      // lucide_icons_flutter (tool/generate_lucide_glyphs.dart).
      for (final (name, data) in [
        ('rocket', LucideIcons.rocket),
        ('cloud-rain', LucideIcons.cloudRain),
        ('circle-alert', LucideIcons.circleAlert),
        ('arrow-up-right', LucideIcons.arrowUpRight),
        ('zap', LucideIcons.zap),
      ]) {
        expect(LucideGlyphs.codePoint(name), data.codePoint, reason: name);
      }
    });

    test('when drawing an icon then the weighted family of its stroke is '
        'used and unknown names fall back', () {
      const source = LucideIconSource.instance;
      final g = source.lucide('rocket', 3)!;
      expect(g.fontFamily, 'packages/lucide_icons_flutter/Lucide600');
      expect(g.text.codeUnitAt(0), LucideIcons.rocket.codePoint);
      expect(source.lucide('no-such', 2), isNull);
      expect(source.emojiFamily, isNull);
    });
  });

  group('Given the icon picker', () {
    late DeckHarness d;
    setUp(() => d = DeckHarness.open());
    tearDown(() => d.dispose());

    Future<Future<IconPickerResult?>> open(
      WidgetTester tester, {
      Size size = const Size(1200, 800),
      Brightness brightness = Brightness.light,
    }) async {
      late BuildContext ctx;
      await pumpSlides(
        tester,
        d.h,
        Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox.expand();
          },
        ),
        size: size,
        brightness: brightness,
      );
      final result = showIconPicker(ctx, services: d.services);
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('when searching then the grid shows the matches and Insert '
        'returns the chosen icon with the stroke width', (tester) async {
      final result = await open(tester);
      expect(find.byKey(IconPickerKeys.dialog), findsOneWidget);

      await tester.enterText(search, 'rocket');
      await tester.pumpAndSettle();
      expect(find.byKey(IconPickerKeys.cell('rocket')), findsOneWidget);
      expect(find.byKey(IconPickerKeys.cell('cloud')), findsNothing);

      await tester.tap(find.byKey(IconPickerKeys.cell('rocket')));
      await tester.tap(find.byKey(IconPickerKeys.stroke(3)));
      await tester.pump();
      await tester.tap(find.byKey(IconPickerKeys.insert));
      await tester.pumpAndSettle();

      final r = await result;
      expect(r!.name, 'rocket');
      expect(r.strokeWidth, 3);
      expect(r.color, isNull);
      // The choice is remembered for *Recently used*.
      expect(await RecentIcons.read(d.services.userStore), ['rocket']);
    });

    testWidgets('when choosing a category then only its icons show', (
      tester,
    ) async {
      final result = await open(tester);
      await tester.tap(find.byKey(IconPickerKeys.category('arrows')));
      await tester.pumpAndSettle();
      await tester.enterText(search, 'arrow-up');
      await tester.pumpAndSettle();
      expect(find.byKey(IconPickerKeys.cell('arrow-up')), findsOneWidget);
      await tester.enterText(search, 'rocket');
      await tester.pumpAndSettle();
      expect(find.byKey(IconPickerKeys.cell('rocket')), findsNothing);
      expect(find.textContaining('No icons match'), findsOneWidget);
      await tester.tap(find.byKey(IconPickerKeys.cancel));
      await tester.pumpAndSettle();
      expect(await result, isNull);
    });

    testWidgets('when an agent fills the dialog then it inserts its choice', (
      tester,
    ) async {
      final result = await open(tester);
      final dialog = d.services.openDialogs.last;
      final desc = dialog.describe();
      expect(desc['title'], 'Insert icon');
      expect((desc['fields'] as List).map((f) => (f as Map)['id']), [
        'query',
        'category',
        'icon',
        'strokeWidth',
        'color',
      ]);
      expect(dialog.setField('query', 'mail'), isTrue);
      expect(dialog.setField('icon', 'not-an-icon'), isFalse);
      expect(dialog.setField('icon', 'mail'), isTrue);
      expect(dialog.setField('color', 'theme:accent2'), isTrue);
      expect(dialog.setField('color', 'reddish'), isFalse);
      expect(dialog.press('insert'), isTrue);
      await tester.pumpAndSettle();

      final r = await result;
      expect((r!.name, r.color), ('mail', 'theme:accent2'));
    });

    testWidgets('when nothing matches then an empty state is shown', (
      tester,
    ) async {
      await open(tester);
      await tester.enterText(search, 'zzqqxx');
      await tester.pumpAndSettle();
      expect(find.textContaining('No icons match'), findsOneWidget);
    });

    for (final brightness in Brightness.values) {
      testWidgets('when shown at 360 px in ${brightness.name} mode then it '
          'lays out without overflow with a category select', (tester) async {
        await open(tester, size: const Size(360, 720), brightness: brightness);
        expect(find.byKey(IconPickerKeys.categorySelect), findsOneWidget);
        expect(find.byKey(IconPickerKeys.category('all')), findsNothing);
        expect(find.byType(ShadButton), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
