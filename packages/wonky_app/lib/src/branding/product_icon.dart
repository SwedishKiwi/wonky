import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart' show DriveItemKind;
import 'package:wonky_ui/wonky_ui.dart' show WonkyMenuItem;

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

  /// Wonky Slides (not built yet).
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

/// The icon of a drive item kind: the product icon for files, a folder glyph
/// for folders.
class DriveKindIcon extends StatelessWidget {
  const DriveKindIcon(this.kind, {super.key, this.size = 20, this.folderColor});

  final DriveItemKind kind;
  final double size;

  /// Color of the folder glyph (defaults to the muted foreground).
  final Color? folderColor;

  @override
  Widget build(BuildContext context) => switch (kind) {
    DriveItemKind.folder => Icon(
      LucideIcons.folder,
      size: size,
      color: folderColor ?? ShadTheme.of(context).colorScheme.mutedForeground,
    ),
    DriveItemKind.document => WonkyProductIcon(
      WonkyProduct.write,
      size: size,
      semanticLabel: '',
    ),
    DriveItemKind.spreadsheet => WonkyProductIcon(
      WonkyProduct.sheets,
      size: size,
      semanticLabel: '',
    ),
  };
}

/// [item] with [product]'s icon in place of its glyph (menus).
WonkyMenuItem? withProductIcon(WonkyMenuItem? item, WonkyProduct product) =>
    item == null
    ? null
    : WonkyMenuItem(
        key: item.key,
        label: item.label,
        leading: WonkyProductIcon(product, size: 16, semanticLabel: ''),
        shortcut: item.shortcut,
        enabled: item.enabled,
        disabledReason: item.disabledReason,
        onSelected: item.onSelected,
        destructive: item.destructive,
        semanticLabel: item.semanticLabel,
      );
