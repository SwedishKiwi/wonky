import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' show CommandDisabled;

import '../../support/preview_fakes.dart';

/// `drive.file.download` without arguments outside a preview downloads the
/// selected files (Drive 04 §9, `Mod+Shift+D`).
void main() {
  late PreviewTestbed t;

  setUp(() => t = PreviewTestbed());
  tearDown(() => t.dispose());

  DriveItemView file(String name) => t.api.addFile(
    name,
    mimeType: 'application/octet-stream',
    category: FileCategory.other,
    sizeBytes: 10,
  );

  test('Given two selected files when Download runs without arguments then '
      'both download', () async {
    final a = file('a.bin');
    final b = file('b.bin');
    t.services.driveSelection.value = [a, b];

    await t.h.invoke('drive.file.download');

    expect(t.downloader.downloads.map((d) => d.$2), ['a.bin', 'b.bin']);
  });

  test('Given a selection with a document when Download runs then it is '
      'disabled', () async {
    final a = file('a.bin');
    final doc = t.h.drive.seed(name: 'Plan');
    t.services.driveSelection.value = [a, doc];

    await expectLater(
      t.h.invoke('drive.file.download'),
      throwsA(isA<CommandDisabled>()),
    );
  });
}
