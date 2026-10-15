import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:wonky_code/src/grammars/grammars.dart';

/// The grammar sources (`grammars/*.json`, run from the package root).
Map<String, String> _sources() => {
  for (final f in Directory('grammars').listSync().whereType<File>())
    if (f.path.endsWith('.json'))
      f.uri.pathSegments.last.replaceAll('.json', ''): f.readAsStringSync(),
};

void main() {
  group('Given the grammar sources in grammars/', () {
    final sources = _sources();

    test('when listing the embedded grammars then there is one per source', () {
      expect(embeddedGrammars.keys.toSet(), sources.keys.toSet());
    });

    for (final MapEntry(key: id, value: json) in sources.entries) {
      test('when comparing $id then the embedded copy is up to date '
          '(else run `dart run tool/embed_grammars.dart`)', () {
        expect(jsonDecode(embeddedGrammars[id]!), jsonDecode(json));
      });
    }
  });
}
