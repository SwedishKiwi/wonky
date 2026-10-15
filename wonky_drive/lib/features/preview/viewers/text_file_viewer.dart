import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/fonts.dart';
import 'package:wonky_code_flutter/wonky_code_flutter.dart';

import '../../../l10n/drive_l10n.dart';
import '../file_preview_controller.dart';

/// Text and code viewer (Drive 02 §6.4): read-only `CodeView` with line
/// numbers, soft wrap (`Alt+Z`), syntax highlighting by extension and the
/// light/dark code palette. HTML, SVG and XML are shown as source, never
/// rendered.
///
/// The code font (JetBrains Mono, a `wonky_fonts` asset) is registered with
/// the engine on first use: the web has no system monospace font, so the
/// `CodeTextStyler` fallbacks (Menlo, Consolas) never apply there (D-18:
/// code previews rendered in a proportional font).
class TextFileViewer extends StatelessWidget {
  const TextFileViewer({super.key, required this.controller, this.fonts});

  final FilePreviewController controller;

  /// Registers the code font (default [AssetFontRegistry.instance]).
  final AssetFontRegistry? fonts;

  /// The family of the code text.
  static final String codeFontFamily =
      CodeTextStyler.defaultBaseStyle.fontFamily!;

  static const codeKey = ValueKey<String>('drive.preview.text');

  /// The code palette of the ambient shad theme.
  static SyntaxPalette paletteOf(BuildContext context) =>
      BuiltInPalettes.forBrightness(
        ShadTheme.of(context).brightness == Brightness.dark
            ? PaletteBrightness.dark
            : PaletteBrightness.light,
      );

  @override
  Widget build(BuildContext context) {
    final registry = fonts ?? AssetFontRegistry.instance;
    unawaited(registry.ensure(codeFontFamily));
    // Lays the code out again once the font is registered.
    return ValueListenableBuilder<int>(
      valueListenable: registry.generation,
      builder: (context, _, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final t = controller.text!;
    final palette = paletteOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PreviewNotices(controller: controller),
        Expanded(
          child: ColoredBox(
            color: Color(palette.background),
            child: CodeView(
              key: codeKey,
              code: t.text,
              language: controller.type?.language ?? '',
              palette: palette,
              wrap: controller.wrap,
              tokenizer: PreviewTokenizer.instance,
              maxHighlightLength: PreviewTokenizer.maxHighlightLength,
              semanticsLabel: controller.item?.name,
            ),
          ),
        ),
      ],
    );
  }
}

/// "Shown as Latin-1" and "Showing the first 1 MB…" above a text view.
class PreviewNotices extends StatelessWidget {
  const PreviewNotices({super.key, required this.controller});

  final FilePreviewController controller;

  static const latin1Key = ValueKey<String>('drive.preview.notice.latin1');
  static const truncatedKey = ValueKey<String>(
    'drive.preview.notice.truncated',
  );

  @override
  Widget build(BuildContext context) {
    final t = controller.text;
    if (t == null || (!t.latin1 && !t.truncated)) {
      return const SizedBox.shrink();
    }
    final l = driveL10n(context);
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.muted,
        border: Border(bottom: BorderSide(color: cs.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            if (t.latin1)
              _notice(latin1Key, LucideIcons.languages, l.previewLatin1, theme),
            if (t.truncated)
              _notice(
                truncatedKey,
                LucideIcons.info,
                l.previewTextTruncated,
                theme,
              ),
          ],
        ),
      ),
    );
  }

  Widget _notice(Key key, IconData icon, String text, ShadThemeData theme) =>
      Row(
        key: key,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.mutedForeground),
          const SizedBox(width: 6),
          Flexible(child: Text(text, style: theme.textTheme.small)),
        ],
      );
}

/// The tokenizer of the text preview: the shared default (TextMate, then
/// highlight.js) for files up to [textMateLimit] characters, and
/// highlight.js beyond — the copied TextMate engine is superlinear on
/// large inputs (≈ 0.7 s for 100 K characters, ≈ 19 s for 500 K on the
/// VM), highlight.js stays linear (≈ 0.1 s per 100 K). Only the first
/// [maxHighlightLength] characters are highlighted (≈ 5,000 lines; the rest
/// stays plain), which keeps "1 MB text file highlighted < 300 ms"
/// (suite 11 §2).
class PreviewTokenizer implements CodeTokenizer {
  const PreviewTokenizer._();

  static const PreviewTokenizer instance = PreviewTokenizer._();

  /// Longer code is highlighted with highlight.js.
  static const textMateLimit = 50000;

  /// Characters of a file that get highlighted.
  static const maxHighlightLength = 250000;

  static const _hljs = HighlightJsTokenizer(maxLength: maxHighlightLength);

  @override
  bool supports(String language) =>
      DefaultCodeTokenizer.instance.supports(language);

  @override
  List<CodeToken> tokenize(String code, String language) {
    if (code.length > textMateLimit && _hljs.supports(language)) {
      return _hljs.tokenize(code, language);
    }
    return DefaultCodeTokenizer.instance.tokenize(code, language);
  }
}
