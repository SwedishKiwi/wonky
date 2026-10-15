import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart'
    show DriveItemKind, DriveItemView, FileCategory;
import 'package:wonky_core/files.dart' show FileTypes;

import '../drive/drive_format.dart';

/// The products of the suite, each with its own icon (suite 02 §5).
enum WonkyProduct {
  /// Wonky Work, the suite.
  work('Wonky Work'),

  /// Wonky Drive, the file home.
  drive('Wonky Drive'),

  /// Wonky Write.
  write('Wonky Write'),

  /// Wonky Sheets.
  sheets('Wonky Sheets'),

  /// Wonky Slides.
  slides('Wonky Slides');

  const WonkyProduct(this.label);

  /// Product name (semantics label; not translated).
  final String label;

  /// The icon's asset path in `wonky_app`.
  String get asset => 'assets/icons/$name.webp';
}

/// A product icon (rounded app tile). Use it wherever the UI stands for a
/// product or one of its files, instead of generic glyphs.
class WonkyProductIcon extends StatelessWidget {
  const WonkyProductIcon(
    this.product, {
    super.key,
    this.size = 24,
    this.semanticLabel,
  });

  final WonkyProduct product;
  final double size;

  /// Defaults to the product name; pass '' for decorative icons.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final label = semanticLabel ?? product.label;
    final image = Image.asset(
      product.asset,
      package: 'wonky_app',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
      // Keeps the layout stable if the asset can't be decoded.
      errorBuilder: (context, _, _) => SizedBox.square(dimension: size),
    );
    if (label.isEmpty) return image;
    // Labeled here, not by the image, so the label holds while it loads.
    return Semantics(image: true, label: label, child: image);
  }
}

/// The icon of a drive item kind (folder, document, spreadsheet glyphs in
/// their kind colors). Uploaded files show their category glyph in the
/// category color when [category] is given (`DriveKindIcon.item`, Drive 04
/// §11); product icons stand for the apps only.
class DriveKindIcon extends StatelessWidget {
  const DriveKindIcon(
    this.kind, {
    super.key,
    this.size = 20,
    this.folderColor,
    this.category,
    this.code = false,
  });

  /// The icon of [item]: its kind, or its file category for uploaded files
  /// (text files with a highlighting language get the code glyph).
  DriveKindIcon.item(
    DriveItemView item, {
    Key? key,
    double size = 20,
    Color? folderColor,
  }) : this(
         item.kind,
         key: key,
         size: size,
         folderColor: folderColor,
         category: item.kind == DriveItemKind.file
             ? item.fileCategory ?? FileCategory.other
             : null,
         code:
             item.kind == DriveItemKind.file &&
             FileTypes.languageOf(item.name) != null,
       );

  final DriveItemKind kind;
  final double size;

  /// Color of the folder glyph (defaults to the muted foreground).
  final Color? folderColor;

  /// The category of an uploaded file ([DriveItemKind.file] only).
  final FileCategory? category;

  /// Whether a text file shows the code glyph.
  final bool code;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colors = theme.colorScheme;
    final category = kind == DriveItemKind.file ? this.category : null;
    if (category != null) {
      return Icon(
        fileCategoryIcon(category, code: code),
        size: size,
        color: fileCategoryColor(category, colors, theme.brightness),
      );
    }
    return Icon(
      kindIcon(kind),
      size: size,
      color: kind == DriveItemKind.folder && folderColor != null
          ? folderColor
          : kindColor(kind, colors),
    );
  }
}
