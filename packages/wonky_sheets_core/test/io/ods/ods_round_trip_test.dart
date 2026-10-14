import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/io/io.dart';

import 'support/ods_fixtures.dart';

void main() {
  final modified = DateTime.utc(2026, 10, 14, 9, 30);
  for (final (name, build) in [
    ('values', OdsDocs.values),
    ('full', OdsDocs.full),
  ]) {
    group('Given the "$name" IR document', () {
      test(
        'when exporting to ODS and importing again then the IR is equal',
        () {
          final doc = build();
          final bytes = OdsExporter.export(
            doc,
            OdsExportOptions(modified: modified),
          );
          final back = OdsImporter.import(bytes);
          expect(IrJson.normalize(back), equals(IrJson.normalize(doc)));
        },
      );
    });
  }
}
