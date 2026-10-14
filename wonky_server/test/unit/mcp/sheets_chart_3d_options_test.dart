import 'package:test/test.dart';
import 'package:wonky_server/src/sheets/mcp/sheets_object_handlers.dart';
import 'package:wonky_sheets_core/model.dart';

void main() {
  group('Given the chart options of sheets.create_chart', () {
    test(
      'when threeD options are given then they become the threeD section',
      () {
        final patch = SheetsObjectHandlers.optionsPatch({
          'threeD': {'enabled': true, 'azimuth': 40, 'lighting': 'bright'},
        });

        expect(patch, {
          'threeD': {'enabled': true, 'azimuth': 40, 'lighting': 'bright'},
        });
        expect(const ChartSpec().patch(patch).threeD.azimuth, 40);
      },
    );

    test('when three_d is a boolean then it toggles 3D', () {
      final patch = SheetsObjectHandlers.optionsPatch({'three_d': true});

      expect(const ChartSpec().patch(patch).is3D, isTrue);
    });

    test('when threeD values are out of range then the spec rejects them', () {
      final patch = SheetsObjectHandlers.optionsPatch({
        'threeD': {'elevation': 200},
      });

      expect(
        () => const ChartSpec().patch(patch),
        throwsA(isA<ChartSpecValidationException>()),
      );
    });
  });
}
