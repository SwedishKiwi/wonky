import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';

import '../features/clipboard/deck_clipboard.dart';
import '../features/clipboard/paste_options.dart';
import '../features/clipboard/rehome_queue.dart';
import 'slides_command.dart';

/// The clipboard commands of SL-18 (Slides 03 §12, 04 §5.8, §13.12): copy,
/// cut and paste of elements, text selections, table cells and (through
/// the navigator) slides and groups, *Paste without formatting* and
/// *Paste special*. The shell's `shell.edit.cut|copy|paste|
/// pasteWithoutFormatting` reach them through `DeckDocumentController`;
/// while a body is edited the text layer runs them for Mod+C/X/V. Each
/// paste or cut is one undo step; re-homed file copies complete later
/// without a step.
List<Command<CommandArgs>> clipboardCommands(ShellServices s) {
  if (s.client != null) SlidesRehomeQueue.install(s);
  return [
    SlidesCommand(
      'slides.edit.copy',
      label: (l) => l.cmdEditCopy,
      icon: LucideIcons.copy,
      categoryOf: SlidesCategory.edit,
      showInPalette: false,
      enabled: (ed, a) => DeckClipboard.canCopy(ed),
      reason: (l, ed) => DeckClipboard.copyAllowed(ed)
          ? l.reasonSelectObject
          : l.reasonCopyNotAllowed,
      run: (ctx, ed, a) => DeckClipboard.copy(ctx, ed),
    ),
    SlidesCommand(
      'slides.edit.cut',
      label: (l) => l.cmdEditCut,
      icon: LucideIcons.scissors,
      categoryOf: SlidesCategory.edit,
      showInPalette: false,
      mutates: true,
      enabled: (ed, a) => DeckClipboard.canCut(ed),
      reason: (l, ed) => l.reasonSelectObject,
      run: (ctx, ed, a) => DeckClipboard.copy(ctx, ed, cut: true),
    ),
    SlidesCommand(
      'slides.edit.paste',
      label: (l) => l.cmdEditPaste,
      icon: LucideIcons.clipboardPaste,
      categoryOf: SlidesCategory.edit,
      showInPalette: false,
      mutates: true,
      argsSchema: _pasteSchema,
      run: (ctx, ed, a) => DeckClipboard.paste(
        ctx,
        ed,
        plain: a.boolean('plainText') ?? false,
        data: DeckClipboard.dataOf(a),
      ),
    ),
    SlidesCommand(
      'slides.edit.pasteSpecial',
      label: (l) => l.cmdEditPasteSpecial,
      icon: LucideIcons.clipboardPaste,
      categoryOf: SlidesCategory.edit,
      mutates: true,
      argsSchema: const JsonSchema.object(
        properties: {
          'mode': JsonSchema.string(
            enumValues: [
              PasteModes.useDestination,
              PasteModes.keepSource,
              PasteModes.unlinked,
              PasteModes.linked,
            ],
            description:
                'keepSource: bring the source theme (slides from another '
                'deck); useDestination: map to this deck\'s theme; '
                'unlinked/linked: a Sheets chart as a static or linked '
                'chart. Re-runs the last paste when it is the newest undo '
                'step, else pastes the clipboard.',
          ),
        },
        required: ['mode'],
      ),
      run: (ctx, ed, a) =>
          DeckClipboard.pasteSpecial(ctx, ed, a.requireString('mode')),
    ),
  ];
}

const _pasteSchema = JsonSchema.object(
  properties: {
    'plainText': JsonSchema.boolean(
      description: 'Paste without formatting (plain text only).',
    ),
    'text': JsonSchema.string(
      description:
          'Paste this text instead of the clipboard (agents): TSV becomes '
          'a table, a URL a link.',
    ),
    'html': JsonSchema.string(
      description:
          'Paste this HTML instead of the clipboard (agents): Wonky Write '
          'and Slides copies, tables and rich text.',
    ),
    'imageBase64': JsonSchema.string(
      description: 'Paste this image (base64) instead of the clipboard.',
    ),
    'imageType': JsonSchema.string(description: 'MIME type of imageBase64.'),
  },
);
