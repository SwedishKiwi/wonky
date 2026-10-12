import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shad/shad.dart';

/// Illustrations for empty states (suite 02 §4.17).
enum EmptyIllustration {
  folder,
  documents,
  spreadsheets,
  starred,
  shared,
  trash,
  search,
  offline,
  comments,
  history,
  notifications,
  noAccess,
  error,
}

/// A light/dark-aware SVG illustration drawn in theme colors.
class EmptyStateIllustration extends StatelessWidget {
  const EmptyStateIllustration(this.kind, {super.key, this.size = 120});

  final EmptyIllustration kind;
  final double size;

  static String _hex(Color c) {
    String h(double v) => (v * 255).round().toRadixString(16).padLeft(2, '0');
    return '#${h(c.r)}${h(c.g)}${h(c.b)}';
  }

  /// The SVG source for [kind] in the given colors (exposed for tests).
  static String svgFor(
    EmptyIllustration kind, {
    required Color surface,
    required Color stroke,
    required Color accent,
    required Color muted,
  }) {
    final s = _hex(surface),
        k = _hex(stroke),
        a = _hex(accent),
        m = _hex(muted);
    final glyph = switch (kind) {
      EmptyIllustration.folder =>
        '<path d="M34 46h22l6 7h30a4 4 0 0 1 4 4v32a4 4 0 0 1-4 4H34a4 4 0 0 1-4-4V50a4 4 0 0 1 4-4z" fill="$s" stroke="$k" stroke-width="2.5"/>'
            '<path d="M30 60h66" stroke="$k" stroke-width="2.5"/>',
      EmptyIllustration.documents =>
        '<path d="M42 30h28l14 14v46a4 4 0 0 1-4 4H42a4 4 0 0 1-4-4V34a4 4 0 0 1 4-4z" fill="$s" stroke="$k" stroke-width="2.5"/>'
            '<path d="M70 30v14h14" fill="none" stroke="$k" stroke-width="2.5"/>'
            '<path d="M48 58h26M48 66h26M48 74h18" stroke="$a" stroke-width="2.5" stroke-linecap="round"/>',
      EmptyIllustration.spreadsheets =>
        '<rect x="34" y="34" width="56" height="56" rx="5" fill="$s" stroke="$k" stroke-width="2.5"/>'
            '<path d="M34 50h56M34 66h56M52 34v56M70 34v56" stroke="$k" stroke-width="2"/>'
            '<rect x="53" y="51" width="16" height="14" fill="$a" opacity="0.6"/>',
      EmptyIllustration.starred =>
        '<path d="M62 30l9.4 19 21 3-15.2 14.8 3.6 20.9L62 77.9l-18.8 9.8 3.6-20.9L31.6 52l21-3z" fill="$s" stroke="$k" stroke-width="2.5" stroke-linejoin="round"/>'
            '<circle cx="62" cy="60" r="5" fill="$a"/>',
      EmptyIllustration.shared =>
        '<circle cx="50" cy="52" r="10" fill="$s" stroke="$k" stroke-width="2.5"/>'
            '<circle cx="76" cy="52" r="10" fill="$s" stroke="$k" stroke-width="2.5"/>'
            '<path d="M32 86c2-12 9-18 18-18s16 6 18 18M58 86c2-12 9-18 18-18s16 6 18 18" fill="none" stroke="$k" stroke-width="2.5" stroke-linecap="round"/>'
            '<circle cx="76" cy="52" r="3" fill="$a"/>',
      EmptyIllustration.trash =>
        '<path d="M40 44h44l-4 46a4 4 0 0 1-4 4H48a4 4 0 0 1-4-4z" fill="$s" stroke="$k" stroke-width="2.5"/>'
            '<path d="M36 44h52M54 36h16" stroke="$k" stroke-width="2.5" stroke-linecap="round"/>'
            '<path d="M55 56v26M69 56v26" stroke="$a" stroke-width="2.5" stroke-linecap="round"/>',
      EmptyIllustration.search =>
        '<circle cx="56" cy="56" r="20" fill="$s" stroke="$k" stroke-width="2.5"/>'
            '<path d="M71 71l17 17" stroke="$k" stroke-width="4" stroke-linecap="round"/>'
            '<path d="M48 56h16" stroke="$a" stroke-width="2.5" stroke-linecap="round"/>',
      EmptyIllustration.offline =>
        '<path d="M44 82h40a14 14 0 0 0 0-28 20 20 0 0 0-38-4 12 12 0 0 0-2 32z" fill="$s" stroke="$k" stroke-width="2.5"/>'
            '<path d="M36 36l52 52" stroke="$a" stroke-width="3" stroke-linecap="round"/>',
      EmptyIllustration.comments =>
        '<path d="M34 38h56a4 4 0 0 1 4 4v32a4 4 0 0 1-4 4H58l-14 12V78H34a4 4 0 0 1-4-4V42a4 4 0 0 1 4-4z" fill="$s" stroke="$k" stroke-width="2.5" stroke-linejoin="round"/>'
            '<path d="M42 52h40M42 62h26" stroke="$a" stroke-width="2.5" stroke-linecap="round"/>',
      EmptyIllustration.history =>
        '<circle cx="62" cy="62" r="28" fill="$s" stroke="$k" stroke-width="2.5"/>'
            '<path d="M62 46v16l11 8" fill="none" stroke="$a" stroke-width="3" stroke-linecap="round"/>',
      EmptyIllustration.notifications =>
        '<path d="M46 76V58a16 16 0 0 1 32 0v18l6 6H40z" fill="$s" stroke="$k" stroke-width="2.5" stroke-linejoin="round"/>'
            '<path d="M56 88a6 6 0 0 0 12 0" fill="none" stroke="$k" stroke-width="2.5"/>'
            '<circle cx="76" cy="44" r="5" fill="$a"/>',
      EmptyIllustration.noAccess =>
        '<rect x="40" y="56" width="44" height="34" rx="5" fill="$s" stroke="$k" stroke-width="2.5"/>'
            '<path d="M50 56V46a12 12 0 0 1 24 0v10" fill="none" stroke="$k" stroke-width="2.5"/>'
            '<circle cx="62" cy="72" r="4" fill="$a"/>',
      EmptyIllustration.error =>
        '<path d="M62 32l30 52H32z" fill="$s" stroke="$k" stroke-width="2.5" stroke-linejoin="round"/>'
            '<path d="M62 52v14" stroke="$a" stroke-width="3" stroke-linecap="round"/><circle cx="62" cy="74" r="2.5" fill="$a"/>',
    };
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 124 124">'
        '<circle cx="62" cy="62" r="54" fill="$m"/>'
        '$glyph</svg>';
  }

  @override
  Widget build(BuildContext context) {
    final c = ShadTheme.of(context).colorScheme;
    final svg = svgFor(
      kind,
      surface: c.background,
      stroke: c.mutedForeground,
      accent: c.primary,
      muted: c.muted,
    );
    return ExcludeSemantics(
      child: SvgPicture.string(svg, width: size, height: size),
    );
  }
}

/// Illustrated empty state: illustration, title, description and actions.
class WonkyEmptyState extends StatelessWidget {
  const WonkyEmptyState({
    super.key,
    required this.illustration,
    required this.title,
    this.description,
    this.actions = const [],
    this.size = 120,
  });

  final EmptyIllustration illustration;
  final String title;
  final String? description;
  final List<Widget> actions;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmptyStateIllustration(illustration, size: size),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: theme.textTheme.large,
                  textAlign: TextAlign.center,
                ),
              ),
              if (description != null) ...[
                const SizedBox(height: 6),
                Text(
                  description!,
                  style: theme.textTheme.muted,
                  textAlign: TextAlign.center,
                ),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
