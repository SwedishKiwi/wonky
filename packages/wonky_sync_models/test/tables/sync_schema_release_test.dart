import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';
import 'package:wonky_sync_models/tables.dart';

/// Lock-step guard of the synced enum values (Slides 02 §14.1): the engine's
/// `syncTablesHash` doesn't see enum values (they are stored by name), so
/// this package records their hash in `SyncSchemaRelease`. Adding a value
/// fails here until the release is bumped and recorded.
void main() {
  group('Given the synced enums', () {
    test('when hashing their values then it is the recorded release '
        '${SyncSchemaRelease.name}', () {
      expect(
        SyncSchemaRelease.computeEnumsHash(SyncSchemaRelease.syncedEnums),
        SyncSchemaRelease.syncEnumsHash,
      );
    });

    test('when listing the generated enums then every one is in the '
        'release', () async {
      final lib = await Isolate.resolvePackageUri(
        Uri.parse('package:wonky_sync_models/tables.dart'),
      );
      final generated = Directory.fromUri(lib!.resolve('src/generated/'));
      final files = [
        for (final f in generated.listSync(recursive: true))
          if (f is File && f.parent.path.endsWith('enums'))
            f.uri.pathSegments.last.replaceAll('.dart', ''),
      ];
      String snake(String name) => name
          .replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}')
          .substring(1);

      expect(files.toSet(), {
        for (final n in SyncSchemaRelease.syncedEnums.keys) snake(n),
      });
    });

    test('when appending a value then the hash changes', () {
      final enums = SyncSchemaRelease.syncedEnums;
      enums['BuildTrigger'] = [...enums['BuildTrigger']!, 'later'];

      expect(
        SyncSchemaRelease.computeEnumsHash(enums),
        isNot(SyncSchemaRelease.syncEnumsHash),
      );
    });

    test('when reading BuildTrigger then S-2 reserves onElementClick', () {
      expect(SyncSchemaRelease.syncedEnums['BuildTrigger'], [
        'onClick',
        'withPrevious',
        'afterPrevious',
        'onElementClick',
      ]);
    });
  });
}
