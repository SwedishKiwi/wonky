import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../l10n/wonky_ui_localizations.dart';

/// Font family select (suite 02 §4.11): searchable, each font rendered in its
/// own face, sections "Recent", "Theme fonts", "All fonts".
class FontPicker extends StatefulWidget {
  const FontPicker({
    super.key,
    required this.value,
    required this.fonts,
    required this.onChanged,
    this.themeFonts = const [],
    this.recentFonts = const [],
    this.minWidth = 140,
    this.enabled = true,
    this.fontPackage,
  });

  /// Selected family (null = mixed).
  final String? value;
  final List<String> fonts;
  final List<String> themeFonts;
  final List<String> recentFonts;
  final ValueChanged<String> onChanged;
  final double minWidth;
  final bool enabled;

  /// Package that bundles the font assets, if not the app.
  final String? fontPackage;

  @override
  State<FontPicker> createState() => _FontPickerState();
}

class _FontPickerState extends State<FontPicker> {
  String _query = '';

  bool _matches(String f) =>
      _query.isEmpty || f.toLowerCase().contains(_query.toLowerCase());

  TextStyle _face(String family) =>
      TextStyle(fontFamily: family, package: widget.fontPackage);

  @override
  Widget build(BuildContext context) {
    final l10n = WonkyUiLocalizations.of(context);
    final theme = ShadTheme.of(context);
    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Text(
        text,
        style: theme.textTheme.muted.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
    final sections = <(String, List<String>)>[
      if (widget.recentFonts.isNotEmpty) (l10n.fontRecent, widget.recentFonts),
      if (widget.themeFonts.isNotEmpty) (l10n.fontTheme, widget.themeFonts),
      (l10n.fontAll, widget.fonts),
    ];
    final anyMatch = widget.fonts.any(_matches);
    // Each family is a selectable option exactly once (the first section it
    // appears in); later duplicates render as plain rows that select too.
    final seen = <String>{};
    return ShadSelect<String>.withSearch(
      key: const ValueKey<String>('fontPicker.select'),
      minWidth: widget.minWidth,
      enabled: widget.enabled,
      initialValue: widget.value,
      searchPlaceholder: Text(l10n.fontSearch),
      onSearchChanged: (q) => setState(() => _query = q),
      placeholder: Text(widget.value ?? ''),
      selectedOptionBuilder: (context, v) =>
          Text(v, style: _face(v), overflow: TextOverflow.ellipsis),
      onChanged: (v) {
        if (v != null) widget.onChanged(v);
      },
      options: [
        if (!anyMatch)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text(l10n.fontNone, style: theme.textTheme.muted)),
          ),
        for (final (title, fonts) in sections) ...[
          if (_query.isEmpty) header(title),
          for (final f in fonts)
            if (seen.add(f))
              Offstage(
                offstage: !_matches(f),
                child: ShadOption<String>(
                  value: f,
                  child: Text(f, style: _face(f)),
                ),
              ),
        ],
      ],
    );
  }
}
