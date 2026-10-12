import 'dart:io';
import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/io/io.dart';
import '../support/ir_corpus.dart';

void main() {
  for (final e in IrCorpus.all.entries) {
    test('roundtrip ${e.key}', () {
      final doc = e.value();
      final bytes = XlsxExporter.export(doc);
      File('/private/tmp/claude-501/-Users-viktor-Projects-wonky/40d5797f-04bb-48b0-9c66-8b08c3cae389/scratchpad/${e.key}.xlsx').writeAsBytesSync(bytes);
      final back = XlsxImporter.import(bytes);
      final a = IrJson.encode(doc);
      final b = IrJson.encode(back);
      File('/private/tmp/claude-501/-Users-viktor-Projects-wonky/40d5797f-04bb-48b0-9c66-8b08c3cae389/scratchpad/${e.key}.a.json').writeAsStringSync(a);
      File('/private/tmp/claude-501/-Users-viktor-Projects-wonky/40d5797f-04bb-48b0-9c66-8b08c3cae389/scratchpad/${e.key}.b.json').writeAsStringSync(b);
      File('/private/tmp/claude-501/-Users-viktor-Projects-wonky/40d5797f-04bb-48b0-9c66-8b08c3cae389/scratchpad/${e.key}.w.txt').writeAsStringSync(back.warnings.join('\n'));
      expect(b, a);
    });
  }
}
