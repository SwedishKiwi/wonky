import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';

import 'support/io_support.dart';
import 'support/ir_corpus.dart';

/// [doc] in the form a spreadsheet model can hold: array formulas are
/// dynamic arrays whose cached elements are plain values, format extras of
/// the file (indent, …) are dropped.
WorkbookDocument _modelShape(WorkbookDocument doc) {
  for (final s in doc.sheets) {
    final arrays = [
      for (final (r, c, cell) in s.cells.entries)
        if (cell.formulaKind != IrFormulaKind.normal) (r, c, cell),
    ];
    for (final (r, c, cell) in arrays) {
      s.cells.set(
        r,
        c,
        IrCell(
          value: cell.value,
          formulaA1: cell.formulaA1,
          formulaKind: IrFormulaKind.dynamicArray,
          arrayRef: cell.arrayRef,
          format: cell.format,
          note: cell.note,
          link: cell.link,
        ),
      );
    }
    for (final (r, c, cell) in s.cells.entries.toList()) {
      final f = doc.formats[cell.format];
      if (f.extras.isEmpty) continue;
      s.cells.set(
        r,
        c,
        cell.copyWith(format: doc.formats.intern(IrFormat(f.attrs))),
      );
    }
  }
  return doc;
}

/// Spilled values computed by the engine for the corpus' array formulas.
void _addSpills(WorkbookDocument doc) {
  final s = doc.sheetByName('Data');
  if (s == null) return;
  s.cells
    ..set(9, 0, const IrCell(value: IrNumber(20)))
    ..set(10, 0, const IrCell(value: IrNumber(30)))
    ..set(9, 2, const IrCell(value: IrNumber(2)))
    ..set(10, 2, const IrCell(value: IrNumber(3)));
}

void main() {
  for (final MapEntry(key: name, value: build) in IrCorpus.all.entries) {
    group('Given the "$name" corpus document', () {
      test(
        'when exporting to XLSX and importing again then the IR is the same',
        () {
          final doc = build();
          final bytes = XlsxExporter.export(
            doc,
            XlsxExportOptions(modified: DateTime.utc(2026)),
          );
          final back = XlsxImporter.import(bytes);
          expect(IrJson.encode(back), IrJson.encode(doc));
        },
      );

      test('when importing into a model and converting back then the IR is the '
          'same', () {
        final r = importNew(build());
        final images = {
          for (final u in r.result.imageUploads) u.fileUuid: u.bytes,
        };
        final back = irOf(r.model, images: images);
        final expected = _modelShape(build());
        _addSpills(expected);
        expect(IrJson.encode(back), IrJson.encode(expected));
      });

      test(
        'when a model goes through XLSX into a new model then both convert to '
        'the same IR',
        () {
          final m1 = importNew(build());
          final ir1 = irOf(
            m1.model,
            images: {
              for (final u in m1.result.imageUploads) u.fileUuid: u.bytes,
            },
          );
          final bytes = XlsxExporter.export(
            ir1,
            XlsxExportOptions(modified: DateTime.utc(2026)),
          );
          final ir2 = XlsxImporter.import(bytes, const ImportOptions().xlsx());
          final m2 = importNew(ir2);
          final ir3 = irOf(
            m2.model,
            images: {
              for (final u in m2.result.imageUploads) u.fileUuid: u.bytes,
            },
          );
          expect(IrJson.encode(ir3), IrJson.encode(ir1));
        },
      );
    });
  }
}
