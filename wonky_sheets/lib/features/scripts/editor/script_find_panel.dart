import 'package:flutter/widgets.dart';
import 'package:re_editor/re_editor.dart';
import 'package:shad/shad.dart';

import '../../../l10n/sheets_l10n.dart';
import '../script_widgets.dart';

/// Find/replace bar of the code editor (09 §14.2) built with shad inputs:
/// match case, regex, previous/next, replace / replace all.
class ScriptFindPanel extends StatelessWidget implements PreferredSizeWidget {
  const ScriptFindPanel({
    super.key,
    required this.controller,
    required this.readOnly,
  });

  final CodeFindController controller;
  final bool readOnly;

  static const _row = 40.0;

  @override
  Size get preferredSize {
    final v = controller.value;
    if (v == null) return Size.zero;
    return Size.fromHeight(
      v.replaceMode && !readOnly ? _row * 2 + 8 : _row + 8,
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = controller.value;
    if (v == null) return const SizedBox.shrink();
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final result = v.result;
    final count = result == null
        ? ''
        : result.matches.isEmpty
        ? l.scriptFindNoResults
        : '${result.index + 1}/${result.matches.length}';
    Widget toggle(String label, bool on, VoidCallback onTap, String tip) =>
        ShadTooltip(
          builder: (_) => Text(tip),
          child: ShadButton.ghost(
            size: ShadButtonSize.sm,
            width: 30,
            height: 28,
            padding: EdgeInsets.zero,
            backgroundColor: on ? cs.accent : null,
            onPressed: onTap,
            child: Text(label, style: theme.textTheme.small),
          ),
        );
    return Container(
      key: const ValueKey<String>('script.find'),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: cs.muted,
        border: Border(bottom: BorderSide(color: cs.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: _row,
            child: Row(
              children: [
                Expanded(
                  child: ShadInput(
                    key: const ValueKey<String>('script.find.input'),
                    controller: controller.findInputController,
                    focusNode: controller.findInputFocusNode,
                    placeholder: Text(l.scriptFindPlaceholder),
                    onSubmitted: (_) => controller.nextMatch(),
                  ),
                ),
                const SizedBox(width: 6),
                Text(count, style: theme.textTheme.muted),
                toggle(
                  'Aa',
                  v.option.caseSensitive,
                  controller.toggleCaseSensitive,
                  l.scriptFindMatchCase,
                ),
                toggle(
                  '.*',
                  v.option.regex,
                  controller.toggleRegex,
                  l.scriptFindRegex,
                ),
                scriptIconButton(
                  icon: LucideIcons.arrowUp,
                  tooltip: l.scriptFindPrevious,
                  onPressed: controller.previousMatch,
                ),
                scriptIconButton(
                  icon: LucideIcons.arrowDown,
                  tooltip: l.scriptFindNext,
                  onPressed: controller.nextMatch,
                ),
                if (!readOnly)
                  scriptIconButton(
                    icon: LucideIcons.replace,
                    tooltip: l.scriptFindToggleReplace,
                    onPressed: controller.toggleMode,
                  ),
                scriptIconButton(
                  key: const ValueKey<String>('script.find.close'),
                  icon: LucideIcons.x,
                  tooltip: l.dialogClose,
                  onPressed: controller.close,
                ),
              ],
            ),
          ),
          if (v.replaceMode && !readOnly)
            SizedBox(
              height: _row,
              child: Row(
                children: [
                  Expanded(
                    child: ShadInput(
                      key: const ValueKey<String>('script.replace.input'),
                      controller: controller.replaceInputController,
                      focusNode: controller.replaceInputFocusNode,
                      placeholder: Text(l.scriptReplacePlaceholder),
                      onSubmitted: (_) => controller.replaceMatch(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ShadButton.outline(
                    size: ShadButtonSize.sm,
                    onPressed: controller.replaceMatch,
                    child: Text(l.scriptReplace),
                  ),
                  const SizedBox(width: 4),
                  ShadButton.outline(
                    size: ShadButtonSize.sm,
                    onPressed: controller.replaceAllMatches,
                    child: Text(l.scriptReplaceAll),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
