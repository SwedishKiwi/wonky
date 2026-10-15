@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_drive/features/storage/storage_screen.dart';

import '../../support/storage_fakes.dart';

/// Golden images of the Storage page (Drive 05 D-17: usage with
/// suggestions and items, a selection, over quota, empty) in light and
/// dark, wide and at 360 px. Masters are made and compared on CI Linux only
/// (specs/15 §7): run locally with `-x golden`.
void main() {
  late StorageTestbed t;

  setUp(() => t = StorageTestbed());
  tearDown(() => t.dispose());

  final old = storageNow.subtract(const Duration(days: 400));

  void seedItems() {
    final finance = t.seed('Finance', kind: DriveItemKind.folder);
    t.seed(
      'interview.m4a',
      bytes: 18 * mb,
      category: FileCategory.audio,
      createdAt: old,
    );
    t.seed(
      'Sales 2025',
      kind: DriveItemKind.spreadsheet,
      bytes: 6 * mb,
      parent: finance.uuid,
      lastOpenedAt: storageNow.subtract(const Duration(days: 1)),
    );
    t.seed(
      'old-scan.pdf',
      bytes: 4 * mb,
      category: FileCategory.pdf,
      trashed: true,
    );
    t.seed('Q3 deck', kind: DriveItemKind.presentation, bytes: 2 * mb);
    t.seed('Notes', kind: DriveItemKind.document, bytes: 40 * kb);
  }

  final states = <String, void Function()>{
    'usage': () {
      seedItems();
      t.setUsage(
        documents: 4 * mb,
        spreadsheets: 9 * mb,
        presentations: 6 * mb,
        files: 18 * mb,
        trash: 8 * mb,
      );
    },
    'over': () {
      seedItems();
      t.setUsage(documents: 4 * mb, files: 46 * mb, trash: 2 * mb);
    },
    'empty': () => t.setUsage(),
  };

  for (final b in Brightness.values) {
    for (final (variant, size) in [
      ('wide', const Size(1280, 900)),
      ('narrow', const Size(360, 900)),
    ]) {
      for (final e in states.entries) {
        testWidgets('storage page ${e.key} $variant ${b.name}', (tester) async {
          e.value();
          await t.pump(tester, brightness: b, size: size);

          await expectLater(
            find.byType(StorageScreen),
            matchesGoldenFile('storage_page_${e.key}_${variant}_${b.name}.png'),
          );
        });
      }
      testWidgets('storage page selection $variant ${b.name}', (tester) async {
        seedItems();
        t.setUsage(files: 22 * mb, trash: 4 * mb);
        await t.pump(tester, brightness: b, size: size);
        final c = t.page!;
        c.select(c.items[0]);
        c.select(c.items[1], toggle: true);
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(StorageScreen),
          matchesGoldenFile('storage_page_selection_${variant}_${b.name}.png'),
        );
      });
    }
  }
}
