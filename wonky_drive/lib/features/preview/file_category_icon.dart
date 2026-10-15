import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart'
    show fileCategoryColor, fileCategoryIcon;
import 'package:wonky_client/wonky_client.dart';

import '../../l10n/drive_l10n.dart';

/// The glyph of a file category (Drive 02 §6.7, Drive 04 §11): Lucide
/// file icons in the category colors (image violet, PDF red, text slate,
/// audio amber, video pink, archive brown, other muted).
class FileCategoryIcon extends StatelessWidget {
  const FileCategoryIcon(
    this.category, {
    super.key,
    this.size = 20,
    this.code = false,
  });

  final FileCategory category;
  final double size;

  /// Text files with a highlighting language show the code glyph.
  final bool code;

  static IconData iconOf(FileCategory c, {bool code = false}) =>
      fileCategoryIcon(c, code: code);

  /// Category colors, slightly lighter in dark mode for contrast (the
  /// shell's table, shared with the drive lists).
  static Color colorOf(FileCategory c, ShadColorScheme cs, Brightness b) =>
      fileCategoryColor(c, cs, b);

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Icon(
      iconOf(category, code: code),
      size: size,
      color: colorOf(category, theme.colorScheme, theme.brightness),
    );
  }
}

/// "PNG image", "PDF document", "ZIP archive", "File" (Drive 02 §6.7).
String fileTypeLabel(
  DriveLocalizations l,
  FileCategory category,
  String extension,
) {
  if (extension.isEmpty && category == FileCategory.other) {
    return l.fileTypeGeneric;
  }
  final ext = extension.isEmpty ? l.fileTypeGeneric : extension.toUpperCase();
  return l.fileTypeLabel(category.name, ext);
}
