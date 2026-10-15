import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../commands/slides_command.dart' show SlidesKeyScopes;
import '../../l10n/slides_l10n.dart';
import 'present_controller.dart';
import 'present_ink.dart';

/// Invokes a present command from the UI.
void invokePresent(
  ShellServices s,
  BuildContext context,
  String id, [
  Map<String, Object?> args = const {},
]) => s.dispatcher.invoke(
  id,
  args: args,
  source: InvocationSource.ui,
  context: context,
);

/// The present toolbar (Slides 10 §4.1): a translucent pill at the
/// bottom-left with ◀ · "12 / 40" (opens the picker) · ▶ · laser · pen ·
/// highlighter · eraser · clear · black/white · ⋮ (help, full screen) ·
/// *End*. Shown on pointer movement; it is part of this view only.
class PresentToolbar extends StatelessWidget {
  const PresentToolbar({
    super.key,
    required this.services,
    required this.controller,
    this.compact = false,
  });

  final ShellServices services;
  final PresentController controller;

  /// Fewer buttons (narrow screens).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    final c = controller;
    final (n, total) = c.counter;
    Widget btn(
      String key,
      IconData icon,
      String label,
      String id, [
      Map<String, Object?> args = const {},
      bool active = false,
    ]) => ShadTooltip(
      builder: (_) {
        final sc = services.keymap.labelsFor(id, args);
        return Text(sc == null ? label : '$label (${sc.join()})');
      },
      child: ShadIconButton.ghost(
        key: ValueKey<String>('slides.present.toolbar.$key'),
        width: 32,
        height: 32,
        iconSize: 16,
        semanticLabel: label,
        backgroundColor: active ? theme.colorScheme.accent : null,
        icon: Icon(icon),
        onPressed: () => invokePresent(services, context, id, args),
      ),
    );
    final mirrors = c.mirrors;
    return Semantics(
      container: true,
      label: l.presentToolbarLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.card.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: theme.colorScheme.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              btn(
                'previous',
                LucideIcons.chevronLeft,
                l.cmdPresentPrevious,
                'slides.present.previous',
              ),
              GestureDetector(
                key: const ValueKey<String>('slides.present.toolbar.counter'),
                onTap: () => invokePresent(
                  services,
                  context,
                  'slides.present.picker',
                  const {'open': true},
                ),
                child: Semantics(
                  button: true,
                  label: l.presentCounterLabel(n, total),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: ExcludeSemantics(
                      child: Text('$n / $total', style: theme.textTheme.small),
                    ),
                  ),
                ),
              ),
              btn(
                'next',
                LucideIcons.chevronRight,
                l.cmdPresentNext,
                'slides.present.next',
              ),
              if (!mirrors && !compact) ...[
                const _Divider(),
                btn(
                  'laser',
                  LucideIcons.pointer,
                  l.presentToolLaser,
                  'slides.present.tool',
                  const {'tool': 'laser', 'toggle': true},
                  c.tool == PresentTool.laser,
                ),
                btn(
                  'pen',
                  LucideIcons.pen,
                  l.presentToolPen,
                  'slides.present.tool',
                  const {'tool': 'pen', 'toggle': true},
                  c.tool == PresentTool.pen,
                ),
                btn(
                  'highlighter',
                  LucideIcons.highlighter,
                  l.presentToolHighlighter,
                  'slides.present.tool',
                  const {'tool': 'highlighter', 'toggle': true},
                  c.tool == PresentTool.highlighter,
                ),
                btn(
                  'eraser',
                  LucideIcons.eraser,
                  l.presentToolEraser,
                  'slides.present.tool',
                  const {'tool': 'eraser', 'toggle': true},
                  c.tool == PresentTool.eraser,
                ),
                btn(
                  'clear',
                  LucideIcons.brushCleaning,
                  l.cmdPresentClearInk,
                  'slides.present.clearInk',
                ),
              ],
              const _Divider(),
              btn(
                'black',
                LucideIcons.square,
                l.presentBlackScreen,
                'slides.present.blank',
                const {'color': 'black'},
                c.blank == PresentBlank.black,
              ),
              if (!compact)
                btn(
                  'white',
                  LucideIcons.squareDashed,
                  l.presentWhiteScreen,
                  'slides.present.blank',
                  const {'color': 'white'},
                  c.blank == PresentBlank.white,
                ),
              btn(
                'help',
                LucideIcons.keyboard,
                l.cmdPresentHelp,
                'slides.present.help',
              ),
              if (!compact)
                btn(
                  'fullscreen',
                  LucideIcons.maximize,
                  l.cmdPresentToggleFullscreen,
                  'slides.present.toggleFullscreen',
                ),
              const SizedBox(width: 4),
              ShadButton.ghost(
                key: const ValueKey<String>('slides.present.toolbar.end'),
                height: 32,
                onPressed: () =>
                    invokePresent(services, context, 'slides.present.end'),
                child: Text(l.presentEnd),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 20,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: ShadTheme.of(context).colorScheme.border,
  );
}

/// "Go to 12" while digits are typed (10 §2.1).
class GoToNumberOverlay extends StatelessWidget {
  const GoToNumberOverlay({super.key, required this.number});

  final String number;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        key: const ValueKey<String>('slides.present.goToNumber'),
        decoration: BoxDecoration(
          color: theme.colorScheme.popover.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            slidesL10n(context).presentGoToNumber(number),
            style: theme.textTheme.large,
          ),
        ),
      ),
    );
  }
}

/// The shortcut help (10 §4.6): generated from the `present` keymap scope
/// (user overrides included).
class PresentHelpOverlay extends StatelessWidget {
  const PresentHelpOverlay({
    super.key,
    required this.services,
    required this.onClose,
  });

  final ShellServices services;
  final VoidCallback onClose;

  static String _argsLabel(
    SlidesLocalizations l,
    String id,
    Map<String, Object?> a,
  ) => switch ((id, a['color'] ?? a['tool'] ?? a['action'] ?? a['delta'])) {
    ('slides.present.blank', 'black') => l.presentBlackScreen,
    ('slides.present.blank', 'white') => l.presentWhiteScreen,
    ('slides.present.tool', 'laser') => l.presentToolLaser,
    ('slides.present.tool', 'pen') => l.presentToolPen,
    ('slides.present.tool', 'highlighter') => l.presentToolHighlighter,
    ('slides.present.tool', 'eraser') => l.presentToolEraser,
    ('slides.present.timer', 'toggle') => l.presentTimerPause,
    ('slides.present.timer', 'reset') => l.presentTimerReset,
    ('slides.present.notesSize', 2) => l.presentNotesLarger,
    ('slides.present.notesSize', -2) => l.presentNotesSmaller,
    ('slides.present.fromCurrent', _) => l.presentResume,
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    final keymap = services.keymap;
    final rows = <(String, List<String>)>[];
    final index = <String, int>{};
    for (final e in keymap.entries) {
      if (e.scope != SlidesKeyScopes.present) continue;
      final key = '${e.commandId}|${e.args}';
      final keys = e.binding.labels(keymap.platform).join();
      final i = index[key];
      if (i != null) {
        rows[i].$2.add(keys);
        continue;
      }
      var label = _argsLabel(l, e.commandId, e.args);
      if (label.isEmpty) {
        label =
            services.registry.byId(e.commandId)?.title(context) ?? e.commandId;
      }
      index[key] = rows.length;
      rows.add((label, [keys]));
    }
    rows.addAll([
      (l.presentHelpGoToNumber, [l.presentHelpDigits]),
      (l.cmdPresentHelp, ['?']),
      (l.presentHelpTemporaryLaser, [keymap.platform.isMac ? '⌘' : 'Ctrl']),
    ]);
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: l.presentHelpTitle,
      child: GestureDetector(
        onTap: onClose,
        child: ColoredBox(
          key: const ValueKey<String>('slides.present.help'),
          color: const Color(0x99000000),
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 560,
                  maxHeight: 640,
                ),
                child: ShadCard(
                  title: Text(l.presentHelpTitle),
                  child: SizedBox(
                    height: 480,
                    child: ListView(
                      children: [
                        for (final r in rows)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    r.$1,
                                    style: theme.textTheme.small,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Wrap(
                                    alignment: WrapAlignment.end,
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: [
                                      for (final k in r.$2) _KeyCap(k),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyCap extends StatelessWidget {
  const _KeyCap(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.muted,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.colorScheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Text(text, style: theme.textTheme.small),
      ),
    );
  }
}

/// "Press F11 (⌃⌘F on Mac) for full screen" with a *Full screen* button,
/// shown for 4 s when the browser refused full screen (10 §1.3).
class FullscreenHint extends StatelessWidget {
  const FullscreenHint({super.key, required this.onFullscreen});

  final VoidCallback onFullscreen;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        key: const ValueKey<String>('slides.present.fullscreenHint'),
        decoration: BoxDecoration(
          color: theme.colorScheme.popover.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.border),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  l.presentFullscreenHint,
                  style: theme.textTheme.small,
                ),
              ),
              const SizedBox(width: 8),
              ShadButton.outline(
                key: const ValueKey<String>('slides.present.fullscreenHint.go'),
                height: 28,
                onPressed: onFullscreen,
                child: Text(l.presentFullscreenButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The audience view's start card (another device or browser, 10 §5.2):
/// full screen needs a click on this device.
class AudienceStartCard extends StatelessWidget {
  const AudienceStartCard({
    super.key,
    required this.presenterDevice,
    required this.onFullscreen,
    required this.onStay,
  });

  final String? presenterDevice;
  final VoidCallback onFullscreen;
  final VoidCallback onStay;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ShadCard(
            key: const ValueKey<String>('slides.present.audienceStart'),
            title: Text(l.presentAudienceTitle),
            description: Text(
              presenterDevice == null || presenterDevice!.isEmpty
                  ? l.presentAudienceBody
                  : l.presentAudienceBodyFrom(presenterDevice!),
            ),
            footer: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                ShadButton.ghost(
                  key: const ValueKey<String>(
                    'slides.present.audienceStart.stay',
                  ),
                  onPressed: onStay,
                  child: Text(l.presentAudienceStay),
                ),
                ShadButton(
                  key: const ValueKey<String>(
                    'slides.present.audienceStart.fullscreen',
                  ),
                  leading: const Icon(LucideIcons.maximize, size: 16),
                  onPressed: onFullscreen,
                  child: Text(l.presentFullscreenButton),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(l.presentAudienceKeys, style: theme.textTheme.muted),
            ),
          ),
        ),
      ),
    );
  }
}

/// The present context menu (right-click / two-finger tap, 10 §2.1).
List<WonkyMenuEntry> presentContextMenu(
  BuildContext context,
  ShellServices s,
  PresentController c,
) {
  final l = slidesL10n(context);
  final r = MenuResolver(s);
  WonkyMenuItem? cmd(
    String id, {
    Map<String, Object?> args = const {},
    String? label,
    String? key,
  }) => r.commandEntry(
    context,
    id,
    args: args,
    label: label,
    key: key ?? 'present.context.$id',
  );
  return [
    ?cmd('slides.present.next'),
    ?cmd('slides.present.previous'),
    ?cmd(
      'slides.present.picker',
      args: const {'open': true},
      label: l.presentGoToSlideMenu,
    ),
    const WonkyMenuSeparator(),
    ?cmd(
      'slides.present.blank',
      args: const {'color': 'black'},
      label: l.presentBlackScreen,
      key: 'present.context.black',
    ),
    ?cmd(
      'slides.present.blank',
      args: const {'color': 'white'},
      label: l.presentWhiteScreen,
      key: 'present.context.white',
    ),
    if (!c.mirrors) ...[
      const WonkyMenuSeparator(),
      ?cmd(
        'slides.present.tool',
        args: const {'tool': 'laser', 'toggle': true},
        label: l.presentToolLaser,
        key: 'present.context.laser',
      ),
      ?cmd(
        'slides.present.tool',
        args: const {'tool': 'pen', 'toggle': true},
        label: l.presentToolPen,
        key: 'present.context.pen',
      ),
      ?cmd(
        'slides.present.tool',
        args: const {'tool': 'highlighter', 'toggle': true},
        label: l.presentToolHighlighter,
        key: 'present.context.highlighter',
      ),
      ?cmd(
        'slides.present.tool',
        args: const {'tool': 'eraser', 'toggle': true},
        label: l.presentToolEraser,
        key: 'present.context.eraser',
      ),
      ?cmd('slides.present.clearInk'),
    ],
    const WonkyMenuSeparator(),
    ?cmd('slides.present.help'),
    ?cmd('slides.present.end'),
  ];
}
