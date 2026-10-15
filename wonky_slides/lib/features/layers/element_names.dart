import 'package:flutter/widgets.dart' show IconData;
import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_slides_core/model.dart';

import '../../config/menus/slides_menu_spec.dart' show placeholderTypeLabel;
import '../../l10n/slides_l10n.dart';

/// Names and icons of elements in the Layers panel and the accessibility
/// checker (03 §8.1, §17.4): the element's own name (`SlideElement.name`),
/// else "Title", "Text box: Our mission", "Image: alt text" or the kind.
abstract final class ElementNames {
  /// The kind label ("Text box", "Image", …).
  static String kind(SlidesLocalizations l, ElementKind kind) => switch (kind) {
    ElementKind.text => l.elementKindText,
    ElementKind.shape => l.elementKindShape,
    ElementKind.line => l.elementKindLine,
    ElementKind.image => l.elementKindImage,
    ElementKind.table => l.elementKindTable,
    ElementKind.code => l.elementKindCode,
    ElementKind.chart => l.elementKindChart,
    ElementKind.icon => l.elementKindIcon,
    ElementKind.group => l.elementKindGroup,
  };

  /// The display name of [e] (≤ 60 characters of text or alt text).
  static String of(SlidesLocalizations l, SlideElementRec e) {
    final name = e.name;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    final p = e.placeholderType;
    final text = e.text == null
        ? ''
        : SlidesText.plainText(e.text).trim().replaceAll('\n', ' ');
    if (p != null) {
      final label = placeholderTypeLabel(l, p);
      return text.isEmpty ? label : '$label: ${_short(text)}';
    }
    final k = kind(l, e.kind);
    if (text.isNotEmpty) return '$k: ${_short(text)}';
    final alt = e.altText?.trim() ?? '';
    return alt.isEmpty ? k : '$k: ${_short(alt)}';
  }

  static String _short(String s) =>
      s.length > 60 ? '${s.substring(0, 60)}…' : s;

  /// The Lucide icon of [e]'s kind.
  static IconData icon(SlideElementRec e) {
    if (e.placeholderType != null && e.kind == ElementKind.text) {
      return LucideIcons.textCursorInput;
    }
    return switch (e.kind) {
      ElementKind.text => LucideIcons.type,
      ElementKind.shape => LucideIcons.square,
      ElementKind.line => LucideIcons.minus,
      ElementKind.image => LucideIcons.image,
      ElementKind.table => LucideIcons.table,
      ElementKind.code => LucideIcons.code,
      ElementKind.chart => LucideIcons.chartColumn,
      ElementKind.icon => LucideIcons.star,
      ElementKind.group => LucideIcons.group,
    };
  }
}
