import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

/// A user avatar: the picture when [imageUrl] is set, otherwise initials on
/// [color]. Optionally ringed (presence color).
class WonkyAvatar extends StatelessWidget {
  const WonkyAvatar({
    super.key,
    required this.name,
    required this.color,
    this.imageUrl,
    this.size = 28,
    this.ringColor,
    this.icon,
    this.semanticLabel,
  });

  final String name;

  /// Background for the initials.
  final Color color;
  final String? imageUrl;
  final double size;
  final Color? ringColor;

  /// Replaces the initials (e.g. a bot icon for MCP/AI participants).
  final IconData? icon;
  final String? semanticLabel;

  /// Up to two initials from [name] ("Anna Berg" → "AB", "bo@x.io" → "B").
  static String initialsOf(String name) {
    final clean = name.contains('@') ? name.split('@').first : name;
    final parts = clean
        .split(RegExp(r'[\s._-]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final fg = ShadColorScheme.contrastingForeground(color);
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: icon != null
          ? Icon(icon, size: size * 0.55, color: fg)
          : Text(
              initialsOf(name),
              style: TextStyle(
                color: fg,
                fontSize: size * 0.4,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
    );
    Widget avatar = imageUrl == null || imageUrl!.isEmpty
        ? fallback
        : ShadAvatar(imageUrl, size: Size.square(size), placeholder: fallback);
    if (ringColor != null) {
      avatar = Container(
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: ringColor!, width: 2),
        ),
        child: avatar,
      );
    }
    return Semantics(
      label: semanticLabel ?? name,
      image: true,
      child: ExcludeSemantics(child: avatar),
    );
  }
}
