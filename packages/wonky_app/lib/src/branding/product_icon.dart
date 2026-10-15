import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart' show DriveItemKind;

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
/// their kind colors). Files keep plain glyphs; product icons stand for the
/// apps only.
class DriveKindIcon extends StatelessWidget {
  const DriveKindIcon(this.kind, {super.key, this.size = 20, this.folderColor});

  final DriveItemKind kind;
  final double size;

  /// Color of the folder glyph (defaults to the muted foreground).
  final Color? folderColor;

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    return Icon(
      kindIcon(kind),
      size: size,
      color: kind == DriveItemKind.folder && folderColor != null
          ? folderColor
          : kindColor(kind, colors),
    );
  }
}
