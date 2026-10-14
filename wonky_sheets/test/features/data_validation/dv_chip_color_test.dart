import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/data_validation/dv_panel.dart';
import 'package:wonky_sheets/features/in_cell/cell_features.dart';
import 'package:wonky_sheets_core/model.dart';

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';

void main() {
  test('Given a palette background then its pair is kept; any other '
      'background gets a readable text color of its hue', () {
    expect(chipColorsFor('#bfe1f6'), DvChipPalette.colors[3]);
    final light = chipColorsFor('#FFF3B0');
    expect(light.bg, '#FFF3B0');
    final dark = chipColorsFor('#202124');
    Color c(String hex) => Color(int.parse('FF${hex.substring(1)}', radix: 16));
    double contrast(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      return (la > lb ? la + 0.05 : lb + 0.05) /
          (la > lb ? lb + 0.05 : la + 0.05);
    }

    expect(contrast(c(light.bg!), c(light.fg!)), greaterThan(4.5));
    expect(contrast(c(dark.bg!), c(dark.fg!)), greaterThan(4.5));
  });

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('Given a dropdown item in the DV panel at 360 px ($mode), '
        'when its color button opens the color picker and a custom color '
        'is chosen, then the rule saves that chip color', (tester) async {
      final s = SheetsHarness.open();
      attachCellFeatures(s.editor);
      await s.select('A2:A9');
      await s.run('sheets.dv.openPanel');
      await pumpSheets(
        tester,
        s,
        dark: dark,
        size: const Size(420, 900),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 360,
            height: 880,
            child: DvPanel(services: s.services, editor: s.editor),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('dv.option.0')),
        'Open',
      );
      await tester.tap(find.byKey(const ValueKey<String>('dv.option.0.color')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('dv.option.0.color.picker')),
        findsOne,
      );
      expect(find.text('Chip colors'), findsOne);
      expect(tester.takeException(), isNull);
      // Palette row 1 (hues), column 7: a blue that is no chip pair.
      await tester.tap(
        find.byKey(const ValueKey<String>('colorPicker.swatch.1.7')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('dv.done')));
      await tester.pumpAndSettle();

      final rule = s.sheet.dvRules.values.single;
      final c = DvCriteria.tryParse(rule.criteriaJson)! as DvListCriteria;
      final colors = c.options.first.colors;
      expect(colors.bg, isNotNull);
      expect(DvChipPalette.colors.map((p) => p.bg), isNot(contains(colors.bg)));
      expect(colors.fg, chipTextColorFor(colors.bg!));
      await tester.pump(const Duration(seconds: 2));
      await s.dispose();
    });
  }
}
