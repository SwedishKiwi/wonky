import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../sheet_editor/sheet_editor_controller.dart';
import '../toolbar/command_ui.dart';
import 'sheets_ai_controller.dart';

/// The formula bar's AI buttons (04 §2, Sheets 12 §6.4–6.5): *Explain
/// formula* when the active cell holds a formula and ✨ *Suggest a
/// formula*. Hidden when AI is switched off; disabled with the reason
/// ("AI isn't configured …") while it can't be used.
class FormulaBarAiButtons extends StatelessWidget {
  const FormulaBarAiButtons({super.key, required this.controller});

  final SheetEditorController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final ai = SheetsAiController.of(c);
    return ListenableBuilder(
      listenable: Listenable.merge([
        c.services.registry,
        c.selection,
        ai.popover,
        ?ai.assistant?.status,
      ]),
      builder: (context, _) {
        if (!ai.shown) return const SizedBox.shrink();
        final ui = CommandUi(context, c.services);
        final formula = c.activeDisplay()?.isFormula ?? false;
        Widget button(String id, IconData icon, String key) {
          final st = ui.state(id);
          final tip = st.enabled
              ? ui.title(id)
              : (st.disabledReason ?? ui.title(id));
          return ShadTooltip(
            builder: (_) => Text(tip),
            child: ShadIconButton.ghost(
              key: ValueKey<String>(key),
              width: 28,
              height: 28,
              iconSize: 14,
              enabled: st.enabled,
              semanticLabel: ui.title(id),
              icon: Icon(icon),
              onPressed: () => ui.run(id),
            ),
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (formula)
              button(
                'sheets.ai.explainFormula',
                LucideIcons.messageCircleQuestion,
                'sheets.formulaBar.explain',
              ),
            button(
              'sheets.ai.suggestFormula',
              LucideIcons.sparkles,
              'sheets.formulaBar.ai',
            ),
          ],
        );
      },
    );
  }
}
