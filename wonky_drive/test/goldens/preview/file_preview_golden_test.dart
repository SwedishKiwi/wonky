@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_drive/features/preview/file_preview_screen.dart';

import '../../support/preview_fakes.dart';

/// Golden images of every viewer and the error state in light and dark,
/// wide and at 360 px (Drive 05 D-14, Drive 04 AC-D4.7). Masters are made
/// and compared on CI Linux only (specs/15 §7): run locally with
/// `-x golden`.
void main() {
  late PreviewTestbed t;
  setUp(() => t = PreviewTestbed());
  tearDown(() => t.dispose());

  final files = <String, DriveItemView Function()>{
    'image': () => t.api.addFile(
      'holiday.png',
      mimeType: 'image/png',
      category: FileCategory.image,
      content: PreviewFixtures.png,
    ),
    'text': () => t.api.addFile(
      'main.dart',
      mimeType: 'text/x-dart',
      category: FileCategory.text,
      content: PreviewFixtures.dart,
    ),
    'csv': () => t.api.addFile(
      'scores.csv',
      mimeType: 'text/csv',
      category: FileCategory.spreadsheet,
      content: PreviewFixtures.csv,
    ),
    'other': () => t.api.addFile(
      'backup.zip',
      mimeType: 'application/zip',
      category: FileCategory.archive,
      sizeBytes: 13002342,
    ),
    'broken': () => t.api.addFile(
      'data.txt',
      mimeType: 'text/plain',
      category: FileCategory.text,
      content: PreviewFixtures.binaryText,
    ),
  };

  for (final b in Brightness.values) {
    for (final (variant, size) in [
      ('wide', const Size(1024, 640)),
      ('narrow', const Size(360, 640)),
    ]) {
      for (final e in files.entries) {
        testWidgets('preview ${e.key} $variant ${b.name}', (tester) async {
          await t.pump(tester, e.value(), brightness: b, size: size);

          await expectLater(
            find.byKey(FilePreviewScreen.rootKey),
            matchesGoldenFile('preview_${e.key}_${variant}_${b.name}.png'),
          );
        });
      }
    }
  }
}
