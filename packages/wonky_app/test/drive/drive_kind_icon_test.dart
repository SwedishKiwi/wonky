import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_ui/testing.dart';

/// Uploaded files show their category glyph and color in the drive lists
/// (Drive 04 §10–11), not one plain file glyph for every file (found in
/// the D-18 browser walk-through).
void main() {
  final drive = FakeDriveRepository();

  Icon iconOf(WidgetTester tester) =>
      tester.widget<Icon>(find.byType(Icon).first);

  for (final b in Brightness.values) {
    testWidgets('file categories have their own glyphs (${b.name})', (
      tester,
    ) async {
      final cases = {
        drive.seed(
          name: 'photo.png',
          kind: DriveItemKind.file,
          fileCategory: FileCategory.image,
        ): LucideIcons.fileImage,
        drive.seed(
          name: 'manual.pdf',
          kind: DriveItemKind.file,
          fileCategory: FileCategory.pdf,
        ): LucideIcons.fileText,
        drive.seed(
          name: 'main.dart',
          kind: DriveItemKind.file,
          fileCategory: FileCategory.text,
        ): LucideIcons.fileCode,
        drive.seed(
          name: 'notes.txt',
          kind: DriveItemKind.file,
          fileCategory: FileCategory.text,
        ): LucideIcons.fileText,
        drive.seed(name: 'blob.bin', kind: DriveItemKind.file):
            LucideIcons.file,
        drive.seed(name: 'Plan'): LucideIcons.fileText,
      };
      for (final MapEntry(key: item, value: glyph) in cases.entries) {
        await pumpWonky(tester, DriveKindIcon.item(item), brightness: b);
        expect(iconOf(tester).icon, glyph, reason: item.name);
      }

      await pumpWonky(
        tester,
        DriveKindIcon.item(cases.keys.first),
        brightness: b,
      );
      final context = tester.element(find.byType(Icon).first);
      final theme = ShadTheme.of(context);
      expect(
        iconOf(tester).color,
        fileCategoryColor(FileCategory.image, theme.colorScheme, b),
      );
      expect(
        iconOf(tester).color,
        isNot(theme.colorScheme.mutedForeground),
        reason: 'images are violet, not muted',
      );
    });
  }

  testWidgets('a category on a non-file kind is ignored', (tester) async {
    await pumpWonky(
      tester,
      const DriveKindIcon(DriveItemKind.folder, category: FileCategory.image),
    );
    expect(iconOf(tester).icon, LucideIcons.folder);
  });
}
