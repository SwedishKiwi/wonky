import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../l10n/sheets_l10n.dart';
import '../../theme/sheets_tokens.dart';
import 'cell_editor_controller.dart';

/// Function autocomplete, signature help and the live parse error under
/// the cell editor (03 §8.7), fed by the core formula services.
class FormulaAssist extends StatelessWidget {
  const FormulaAssist({super.key, required this.editor, required this.tokens});

  final CellEditorController editor;
  final GridPaintTokens tokens;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final l = sheetsL10n(context);
    final children = <Widget>[];
    if (editor.showCompletions) {
      final items = editor.completions.items;
      children.add(
        _Card(
          key: const ValueKey<String>('sheets.formula.autocomplete'),
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < items.length && i < 8; i++)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => editor.acceptCompletion(i),
                  child: Container(
                    key: ValueKey<String>(
                      'sheets.formula.completion.${items[i].name}',
                    ),
                    color: i == editor.completionIndex ? cs.accent : null,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[i].name,
                          style: theme.textTheme.small.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (items[i].summary.isNotEmpty)
                          Text(
                            items[i].summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.muted.copyWith(fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    } else if (editor.signature != null) {
      final sig = editor.signature!;
      final spans = <TextSpan>[TextSpan(text: '${sig.functionName}(')];
      for (var i = 0; i < sig.params.length; i++) {
        if (i > 0) spans.add(const TextSpan(text: ', '));
        spans.add(
          TextSpan(
            text: sig.params[i],
            style: i == sig.activeParam
                ? const TextStyle(fontWeight: FontWeight.w700)
                : null,
          ),
        );
      }
      spans.add(const TextSpan(text: ')'));
      final summary = sig.help?.summary;
      children.add(
        _Card(
          key: const ValueKey<String>('sheets.formula.signature'),
          width: 360,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(
                  TextSpan(children: spans),
                  style: theme.textTheme.small.copyWith(
                    fontFamily: 'GeistMono',
                  ),
                ),
                if (summary != null && summary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    summary,
                    style: theme.textTheme.muted.copyWith(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    final err = editor.parseError;
    if (err != null && editor.isFormula) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _Card(
            key: const ValueKey<String>('sheets.formula.error'),
            width: 320,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                l.formulaParseError(err.message),
                style: theme.textTheme.small.copyWith(
                  color: tokens.formulaError,
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({super.key, required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = ShadTheme.of(context).colorScheme;
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: cs.popover,
        border: Border.all(color: cs.border),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: cs.popoverForeground),
        child: child,
      ),
    );
  }
}
