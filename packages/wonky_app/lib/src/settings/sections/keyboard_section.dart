import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_core/wonky_core.dart' hide ActorKind;
import 'package:wonky_ui/wonky_ui.dart';

import '../../l10n/wonky_app_localizations.dart';
import '../../shell/dialogs.dart';
import '../../shell/shell_services.dart';

/// Settings › Keyboard shortcuts (suite 08 §1.2): searchable table of all
/// commands; record a binding, conflict detection with Replace / Cancel,
/// reset per row and Reset all.
class KeyboardSection extends StatefulWidget {
  const KeyboardSection({super.key, required this.services});

  final ShellServices services;

  @override
  State<KeyboardSection> createState() => _KeyboardSectionState();
}

class _KeyboardSectionState extends State<KeyboardSection> {
  String _q = '';
  final Map<String, String> _conflicts = {};

  ShellServices get s => widget.services;

  Future<void> _record(String commandId, RecordedChord chord) async {
    final l = WonkyAppLocalizations.of(context);
    final km = s.keymap;
    final binding = ResolvedChord(
      key: chord.key,
      control: chord.control,
      meta: chord.meta,
      alt: chord.alt,
      shift: chord.shift,
    ).toBinding(km.platform);
    if (binding.isBrowserReserved(km.platform)) {
      setState(() => _conflicts[commandId] = l.shortcutReserved);
      return;
    }
    final command = s.registry.byId(commandId);
    final conflicts = km.conflictsFor(
      binding,
      command?.keyScope ?? KeyScope.global,
      exceptCommandId: commandId,
    );
    if (conflicts.isNotEmpty) {
      final names = [
        for (final c in conflicts) s.registry.byId(c)?.title(context) ?? c,
      ].join(', ');
      final replace = await confirmDialog(
        context,
        title: l.shortcutConflictTitle,
        description: l.shortcutConflictBody(binding.format(km.platform), names),
        confirmLabel: l.shortcutReplace,
      );
      if (!replace) return;
      for (final c in conflicts) {
        km.setOverride(c, [
          for (final b in km.bindingsOf(c))
            if (b.resolve(km.platform) != binding.resolve(km.platform)) b,
        ]);
      }
    }
    km.setOverride(commandId, [binding]);
    setState(() => _conflicts.remove(commandId));
  }

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    return ListenableBuilder(
      listenable: s.keymap,
      builder: (context, _) {
        final commands = [
          for (final c in s.registry.all)
            if (c.showInPalette &&
                (_q.isEmpty ||
                    c.title(context).toLowerCase().contains(_q.toLowerCase()) ||
                    c.id.value.contains(_q)))
              c,
        ]..sort((a, b) => a.title(context).compareTo(b.title(context)));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: ShadInput(
                    key: const ValueKey<String>('settings.keyboard.search'),
                    placeholder: Text(l.shortcutsSearch),
                    leading: const Icon(LucideIcons.search, size: 16),
                    onChanged: (v) => setState(() => _q = v),
                  ),
                ),
                const SizedBox(width: 8),
                ShadButton.outline(
                  key: const ValueKey<String>('settings.keyboard.resetAll'),
                  enabled: s.keymap.overrides.isNotEmpty,
                  onPressed: s.keymap.resetAll,
                  child: Text(l.shortcutResetAll),
                ),
                const SizedBox(width: 8),
                ShadButton.ghost(
                  leading: const Icon(LucideIcons.keyboard, size: 16),
                  onPressed: () => s.dispatcher.invoke(
                    'shell.help.shortcuts',
                    context: context,
                  ),
                  child: Text(l.cmdKeyboardShortcuts),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final c in commands)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: theme.colorScheme.border),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.title(context), style: theme.textTheme.small),
                          Text(
                            c.id.value,
                            style: theme.textTheme.muted.copyWith(
                              fontSize: 11,
                              fontFamily: WonkyTheme.monoFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                    KeyboardShortcutRecorder(
                      key: ValueKey<String>('settings.keyboard.${c.id.value}'),
                      labels: s.keymap.labelsOf(c.id.value) ?? const [],
                      conflict: _conflicts[c.id.value],
                      semanticLabel: c.title(context),
                      onRecorded: (chord) => _record(c.id.value, chord),
                      onClear: () => s.keymap.setOverride(c.id.value, const []),
                    ),
                    SizedBox(
                      width: 36,
                      child: s.keymap.overrides.containsKey(c.id.value)
                          ? ShadTooltip(
                              builder: (_) => Text(l.shortcutReset),
                              child: ShadIconButton.ghost(
                                width: 28,
                                height: 28,
                                iconSize: 14,
                                semanticLabel: l.shortcutReset,
                                icon: const Icon(LucideIcons.rotateCcw),
                                onPressed: () =>
                                    s.keymap.resetOverride(c.id.value),
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
