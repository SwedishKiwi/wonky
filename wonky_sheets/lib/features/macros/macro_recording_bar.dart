import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_core/wonky_core.dart' show InvocationSource;
import 'package:wonky_sheets_script/wonky_sheets_script.dart';

import '../../l10n/sheets_l10n.dart';
import '../sheet_editor/sheet_editor_controller.dart';
import 'macro_service.dart';

/// The floating recording bar at the bottom center of the grid (09 §15
/// step 1): "● Recording new macro…", absolute/relative references,
/// *Save* and *Cancel*. Shown while [MacroService.recording].
class MacroRecordingOverlay extends StatelessWidget {
  const MacroRecordingOverlay({super.key, required this.editor});

  final SheetEditorController editor;

  @override
  Widget build(BuildContext context) {
    final svc = MacroService.maybeOf(editor);
    if (svc == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) => svc.recording
          ? Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16, left: 8, right: 8),
                child: MacroRecordingBar(editor: editor, service: svc),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class MacroRecordingBar extends StatelessWidget {
  const MacroRecordingBar({
    super.key,
    required this.editor,
    required this.service,
  });

  final SheetEditorController editor;
  final MacroService service;

  void _invoke(String id) =>
      unawaited(editor.invokeCommand(id, const {}, InvocationSource.ui));

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final locked = service.recordedCount > 0;
    Widget mode(MacroReferenceMode m, String label) {
      final selected = service.mode == m;
      final button = selected
          ? ShadButton.secondary(
              size: ShadButtonSize.sm,
              onPressed: () {},
              child: Text(label),
            )
          : ShadButton.ghost(
              size: ShadButtonSize.sm,
              onPressed: locked ? null : () => service.setMode(m),
              child: Text(label),
            );
      return KeyedSubtree(
        key: ValueKey<String>('macro.recording.mode.${m.name}'),
        child: ShadTooltip(
          builder: (_) => Text(
            m == MacroReferenceMode.absolute
                ? l.macroAbsoluteHint
                : l.macroRelativeHint,
          ),
          child: button,
        ),
      );
    }

    return Container(
      key: const ValueKey<String>('macro.recordingBar'),
      constraints: const BoxConstraints(maxWidth: 640),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.popover,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.border),
        boxShadow: [
          BoxShadow(
            color: cs.foreground.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: cs.destructive,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                service.recordedCount == 0
                    ? l.macroRecording
                    : l.macroRecordingCount(service.recordedCount),
                style: theme.textTheme.small,
              ),
            ],
          ),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              mode(MacroReferenceMode.absolute, l.macroAbsolute),
              mode(MacroReferenceMode.relative, l.macroRelative),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShadButton.outline(
                key: const ValueKey<String>('macro.recording.cancel'),
                size: ShadButtonSize.sm,
                onPressed: () => _invoke('sheets.macro.cancelRecording'),
                child: Text(l.macroCancel),
              ),
              const SizedBox(width: 6),
              ShadButton(
                key: const ValueKey<String>('macro.recording.save'),
                size: ShadButtonSize.sm,
                onPressed: () => _invoke('sheets.macro.saveRecording'),
                child: Text(l.dialogSave),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
