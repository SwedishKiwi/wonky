import 'package:flutter/widgets.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:shad/shad.dart';
import 'package:wonky_ui/wonky_ui.dart';

/// Code colors of the script editor (09 §14.2): `re_highlight` token
/// classes mapped to theme tokens, so the editor follows light/dark live.
abstract final class ScriptCodeTheme {
  /// Token class → style for [cs].
  static Map<String, TextStyle> tokens(ShadColorScheme cs) {
    final keyword = TextStyle(color: cs.primary, fontWeight: FontWeight.w600);
    final string = TextStyle(color: cs.success);
    final comment = TextStyle(
      color: cs.mutedForeground,
      fontStyle: FontStyle.italic,
    );
    final number = TextStyle(color: cs.info);
    final type = TextStyle(color: cs.warning);
    return {
      'root': TextStyle(color: cs.foreground),
      'keyword': keyword,
      'built_in': type,
      'type': type,
      'title.class_': type,
      'class-title': type,
      'literal': number,
      'number': number,
      'string': string,
      'subst': TextStyle(color: cs.foreground),
      'comment': comment,
      'doctag': comment.copyWith(fontWeight: FontWeight.w600),
      'meta': TextStyle(color: cs.info),
      'title': TextStyle(color: cs.foreground, fontWeight: FontWeight.w600),
      'title.function_': TextStyle(
        color: cs.foreground,
        fontWeight: FontWeight.w600,
      ),
      'params': TextStyle(color: cs.foreground),
      'symbol': number,
    };
  }

  /// The editor style: GeistMono 13 px, line height 1.5, card background,
  /// selection and current line from the theme.
  static CodeEditorStyle style(ShadColorScheme cs) => CodeEditorStyle(
    fontSize: 13,
    fontFamily: WonkyTheme.monoFamily,
    fontHeight: 1.5,
    textColor: cs.foreground,
    hintTextColor: cs.mutedForeground,
    backgroundColor: cs.card,
    selectionColor: cs.selectionFill,
    cursorColor: cs.foreground,
    cursorLineColor: cs.accent.withValues(alpha: 0.4),
    chunkIndicatorColor: cs.mutedForeground,
    codeTheme: CodeHighlightTheme(
      languages: {'dart': CodeHighlightThemeMode(mode: langDart)},
      theme: tokens(cs),
    ),
  );
}
