import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_ui/testing.dart';
import 'package:wonky_ui/wonky_ui.dart';

void main() {
  const segments = [
    WonkyStackedBarSegment(
      id: 'documents',
      label: 'Documents',
      value: 4,
      valueLabel: '4 MB',
      color: Color(0xff2563eb),
    ),
    WonkyStackedBarSegment(
      id: 'files',
      label: 'Files',
      value: 0.001,
      valueLabel: '1 KB',
      color: Color(0xff7c3aed),
    ),
    WonkyStackedBarSegment(
      id: 'free',
      label: 'Free',
      value: 6,
      valueLabel: '6 MB',
      color: Color(0x00000000),
      hollow: true,
      inBar: false,
    ),
  ];

  for (final b in Brightness.values) {
    group('Given a stacked bar in ${b.name}', () {
      testWidgets('when it shows then the parts take their share, tiny parts '
          'stay visible and screen readers get one label', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpWonky(
          tester,
          const SizedBox(
            width: 400,
            child: WonkyStackedBar(segments: segments, total: 10),
          ),
          brightness: b,
          center: true,
        );

        final parts = tester
            .widgetList<Positioned>(find.byType(Positioned))
            .toList();
        expect(parts.map((p) => p.width), [160, 2]);
        expect(find.byKey(const ValueKey('stackedBar.free')), findsOneWidget);
        expect(
          find.bySemanticsLabel('Documents 4 MB, Files 1 KB, Free 6 MB'),
          findsOneWidget,
        );
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantics.dispose();
      });

      testWidgets('when the parts exceed the total then they are scaled to '
          'fit without overflowing', (tester) async {
        await pumpWonky(
          tester,
          const SizedBox(
            width: 300,
            child: WonkyStackedBar(
              total: 1,
              segments: [
                WonkyStackedBarSegment(
                  label: 'A',
                  value: 3,
                  color: Color(0xffdc2626),
                ),
                WonkyStackedBarSegment(
                  label: 'B',
                  value: 1,
                  color: Color(0xff2563eb),
                ),
              ],
            ),
          ),
          brightness: b,
          center: true,
        );

        final parts = tester
            .widgetList<Positioned>(find.byType(Positioned))
            .toList();
        expect(parts.map((p) => p.width), [225, 75]);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
