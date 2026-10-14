import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:wonky_server/src/sheets/exports/sheets_pdf_fonts.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/model_testing.dart';

void main() {
  group('Given cells in the theme preset families', () {
    late WorkbookModel m;
    setUp(() {
      final b = WorkbookBuilder()..sheet('Sheet1', rows: 10, cols: 3);
      b.value(
        'A1',
        'Ocean',
        format: {FormatAttr.fontFamily: 'Montserrat', FormatAttr.bold: true},
      );
      b.value(
        'A2',
        'Marina',
        format: {FormatAttr.fontFamily: 'Source Sans 3'},
      );
      b.value(
        'A3',
        'Retro',
        format: {FormatAttr.fontFamily: 'Courier Prime'},
      );
      m = b.build();
    });

    test('when exporting a PDF on the server then the bundled static faces '
        'from web/fonts are embedded', () async {
      final fonts = await SheetsPdfFonts.load(
        directory: Directory('web/fonts'),
      );

      final pdf = latin1.decode(
        await SheetsPdfRenderer.render(
          m,
          ModelCellSource(m),
          Paginator.paginate(m, const PrintJob()),
          now: DateTime.utc(2026, 10, 14),
          fonts: fonts,
          compress: false,
        ),
      );

      expect(pdf, contains('Montserrat-Bold'));
      expect(pdf, contains('WonkySansThree-Regular'));
      expect(pdf, contains('JetBrainsMono-Regular'));
    });
  });
}
