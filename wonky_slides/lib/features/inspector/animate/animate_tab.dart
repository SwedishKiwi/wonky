import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart' show InvocationSource;
import 'package:wonky_ui/wonky_ui.dart';

import '../../../l10n/slides_l10n.dart';
import '../../builds/animate_view.dart';
import '../../editor_screen/deck_editor_controller.dart';
import '../../toolbar/command_ui.dart';
import 'build_tab.dart';
import 'order_tab.dart';
import 'transition_tab.dart';

/// Inspector › **Animate** (Slides 04 §7.3, 06 §5): the sub-tabs
/// *Transition* · *Build* · *Order*, the *Reduce motion* banner (06 §13)
/// and the sub-tab's body. Viewers see it read-only (every control is a
/// command, disabled with its reason).
class AnimateTab extends StatelessWidget {
  const AnimateTab({super.key, required this.services, required this.editor});

  final ShellServices services;
  final DeckEditorController editor;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    final ui = SlidesCommandUi(context, services);
    final view = AnimateView.of(editor)
      ..systemReducedMotion = WonkyThemeScope.of(context).reduceMotion;
    Widget sub(String tab, String label) {
      final selected = editor.animateTab == tab;
      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          child: ShadButton.ghost(
            key: ValueKey<String>('slides.inspector.animate.$tab'),
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            backgroundColor: selected ? theme.colorScheme.muted : null,
            onPressed: () => ui.run('slides.panel.animate', {
              'tab': tab,
            }, InvocationSource.ui),
            child: Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.small.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: view,
      builder: (context, _) => Column(
        key: const ValueKey<String>('slides.inspector.animateBody'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              sub('transition', l.animateTabTransition),
              sub('build', l.animateTabBuild),
              sub('order', l.animateTabOrder),
            ],
          ),
          if (view.reduceMotionOn)
            Container(
              key: const ValueKey<String>('slides.animate.reducedBanner'),
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.muted,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.animateReducedMotionOn, style: theme.textTheme.small),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: [
                      ShadButton.link(
                        size: ShadButtonSize.sm,
                        padding: EdgeInsets.zero,
                        onPressed: () => ui.run('shell.settings.open', const {
                          'section': 'appearance',
                        }, InvocationSource.ui),
                        child: Flexible(
                          child: Text(l.animateReducedMotionSettings),
                        ),
                      ),
                      ShadButton.link(
                        key: const ValueKey<String>(
                          'slides.animate.fullMotion',
                        ),
                        size: ShadButtonSize.sm,
                        padding: EdgeInsets.zero,
                        onPressed: () => ui.run(
                          'slides.animate.togglePreviewOption',
                          const {'option': AnimateView.optionFullMotion},
                          InvocationSource.ui,
                        ),
                        child: Flexible(
                          child: Text(
                            view.option(AnimateView.optionFullMotion)
                                ? l.animatePreviewReduced
                                : l.animatePreviewFullMotion,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          switch (editor.animateTab) {
            'build' => BuildTab(services: services, editor: editor),
            'order' => OrderTab(services: services, editor: editor),
            _ => TransitionTab(services: services, editor: editor),
          },
        ],
      ),
    );
  }
}
