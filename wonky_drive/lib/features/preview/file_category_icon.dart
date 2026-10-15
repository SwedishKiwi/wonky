import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
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

  static IconData iconOf(FileCategory c, {bool code = false}) => switch (c) {
    FileCategory.image => LucideIcons.fileImage,
    FileCategory.pdf => LucideIcons.fileText,
    FileCategory.text => code ? LucideIcons.fileCode : LucideIcons.fileText,
    FileCategory.audio => LucideIcons.fileAudio,
    FileCategory.video => LucideIcons.fileVideo,
    FileCategory.archive => LucideIcons.fileArchive,
    FileCategory.document => LucideIcons.fileText,
    FileCategory.spreadsheet => LucideIcons.fileSpreadsheet,
    FileCategory.presentation => LucideIcons.presentation,
    FileCategory.other => LucideIcons.file,
  };

  /// Category colors, slightly lighter in dark mode for contrast.
  static Color colorOf(FileCategory c, ShadColorScheme cs, Brightness b) {
    final dark = b == Brightness.dark;
    return switch (c) {
      FileCategory.image =>
        dark ? const Color(0xffa78bfa) : const Color(0xff7c3aed),
      FileCategory.pdf =>
        dark ? const Color(0xfff87171) : const Color(0xffdc2626),
      FileCategory.text =>
        dark ? const Color(0xff94a3b8) : const Color(0xff475569),
      FileCategory.audio =>
        dark ? const Color(0xfffbbf24) : const Color(0xffb45309),
      FileCategory.video =>
        dark ? const Color(0xfff472b6) : const Color(0xffdb2777),
      FileCategory.archive =>
        dark ? const Color(0xffd6a77a) : const Color(0xff92400e),
      FileCategory.document =>
        dark ? const Color(0xff60a5fa) : const Color(0xff2563eb),
      FileCategory.spreadsheet =>
        dark ? const Color(0xff4ade80) : const Color(0xff16a34a),
      FileCategory.presentation =>
        dark ? const Color(0xfffb923c) : const Color(0xffea580c),
      FileCategory.other => cs.mutedForeground,
    };
  }

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
