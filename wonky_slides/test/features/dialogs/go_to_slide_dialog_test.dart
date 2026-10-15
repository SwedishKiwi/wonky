import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart' show InvocationSource;
import 'package:wonky_ui/testing.dart';

import '../../support/deck_screen.dart';

/// Go to slide (Slides 04 §13.10) is a describable dialog: MCP reads it
/// with `ui.get_dialog`, fills it and presses Go (04 AC-9).
void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Given the editor (${brightness.name}) when Go to slide opens '
        'then the dialog lists the slides and MCP can pick one', (
      tester,
    ) async {
      final r = await pumpDeckScreen(tester, brightness: brightness);
      final third = r.editor.order.entries[2].id;

      final done = r.services.dispatcher.invoke(
        'slides.nav.goToSlide',
        source: InvocationSource.menu,
        context: tester.element(find.byKey(const ValueKey('slides.canvas'))),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final dialog = r.services.openDialogs
          .whereType<McpDescribableDialog>()
          .last;
      final desc = dialog.describe();
      final fields = (desc['fields']! as List).cast<Map<Object?, Object?>>();
      final slide = fields.single;
      expect(slide['id'], 'slide');
      final options = slide['options']! as List;
      expect(options, hasLength(4));
      final labels = slide['optionLabels']! as Map;
      expect(labels[options[1]], '2 · Our mission — Intro');
      expect(labels[options[0]], '1 · Q3 review');
      expect(tester.takeException(), isNull);

      expect(dialog.setField('slide', third), isTrue);
      await tester.pump();
      expect(dialog.press('go'), isTrue);
      await tester.pump(const Duration(milliseconds: 300));
      final result = await done;

      expect(result.isOk, isTrue);
      expect(r.editor.currentSlideId, third);
      await settleTooltips(tester);
      await r.close(tester);
    });
  }
}
