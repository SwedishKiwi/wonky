import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_ui/testing.dart';
import 'package:wonky_ui/wonky_ui.dart';

void main() {
  group('Given WonkyColor', () {
    test('when parsing short and long hex then it normalizes', () {
      expect(WonkyColor.tryParse('#ABC')!.hex, '#aabbcc');
      expect(WonkyColor.tryParse('11223344')!.hex, '#11223344');
      expect(WonkyColor.tryParse('#112233ff')!.hex, '#112233');
      expect(WonkyColor.tryParse('xyz'), isNull);
    });
    test('when converting to and from Color then it round-trips', () {
      const c = Color(0x80ff0000);
      expect(WonkyColor.fromColor(c).toColor(), c);
      expect(
        WonkyColor.fromJson(
          const WonkyColor('#ff0000', themeRef: 'accent1').toJson(),
        ),
        const WonkyColor('#ff0000', themeRef: 'accent1'),
      );
    });
  });

  for (final b in Brightness.values) {
    group('Given a color picker in ${b.name}', () {
      testWidgets('when tapping a swatch then its color is reported and it has '
          'an accessible name', (tester) async {
        WonkyColor? picked;
        await pumpWonky(
          tester,
          WonkyColorPicker(
            resetLabel: 'Automatic',
            onChanged: (c) => picked = c,
          ),
          brightness: b,
          center: true,
        );
        expect(find.bySemanticsLabel('light red 2'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('colorPicker.swatch.1.1')));
        expect(picked, const WonkyColor('#ff0000'));
      });

      testWidgets('when pressing reset then null is reported', (tester) async {
        var called = false;
        WonkyColor? picked = const WonkyColor('#000000');
        await pumpWonky(
          tester,
          WonkyColorPicker(
            resetLabel: 'None',
            value: const WonkyColor('#000000'),
            onChanged: (c) {
              called = true;
              picked = c;
            },
          ),
          brightness: b,
          center: true,
        );
        await tester.tap(find.byKey(const ValueKey('colorPicker.reset')));
        expect((called, picked), (true, null));
      });
    });
  }

  testWidgets('Given the picker when navigating with arrows and Enter then the '
      'highlighted swatch is chosen', (tester) async {
    WonkyColor? picked;
    await pumpWonky(
      tester,
      WonkyColorPicker(onChanged: (c) => picked = c),
      center: true,
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown); // row 1 col 0
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight); // col 1 → red
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(picked, const WonkyColor('#ff0000'));
  });

  testWidgets(
    'Given the custom panel when entering a hex and applying then the '
    'custom color is reported and added',
    (tester) async {
      WonkyColor? picked;
      WonkyColor? added;
      await pumpWonky(
        tester,
        WonkyColorPicker(
          onChanged: (c) => picked = c,
          onCustomColorAdded: (c) => added = c,
        ),
        center: true,
      );
      await tester.tap(find.byKey(const ValueKey('colorPicker.custom')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('colorPicker.hex')).first,
        '336699',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('colorPicker.apply')));
      await tester.pumpAndSettle();
      expect(picked, const WonkyColor('#336699'));
      expect(added, const WonkyColor('#336699'));
    },
  );

  testWidgets('Given theme and recent colors when shown then they appear as '
      'extra rows', (tester) async {
    await pumpWonky(
      tester,
      WonkyColorPicker(
        onChanged: (_) {},
        themeColors: const [
          WonkyThemeSwatch(
            color: WonkyColor('#123456', themeRef: 'accent1'),
            name: 'Accent 1',
          ),
        ],
        recentColors: const [WonkyColor('#abcdef')],
      ),
      center: true,
    );
    expect(find.text('Theme colors'), findsOneWidget);
    expect(find.bySemanticsLabel('Accent 1'), findsOneWidget);
    expect(find.bySemanticsLabel('#ABCDEF'), findsOneWidget);
  });
}
