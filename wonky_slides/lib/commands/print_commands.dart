import 'dart:typed_data';

import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides_core/interfaces.dart';
import 'package:wonky_slides_core/pdf.dart';

import '../features/editor_screen/deck_editor_controller.dart';
import '../features/print/print_preview_screen.dart';
import '../features/print/slides_client_export.dart';
import '../l10n/slides_l10n.dart';
import 'slides_command.dart';

/// The print and PDF export commands (Slides 10 §11.6, §12, §14; SL-20):
/// `slides.print.open` (`Mod+P`) opens the print preview route,
/// `slides.file.download {format: pdf}` opens it too unless `immediate`
/// (Shift-click, MCP) exports right away with `options` (10 §11.1 keys) or
/// the last-used options, and `slides.print.print` prints the previewed PDF.
/// None of them changes the deck. Viewers and commenters may export only
/// when the owner allows it (`nonEditorsCanExport`).
List<Command<CommandArgs>> printCommands(ShellServices s) => [
  SlidesCommand(
    'slides.print.open',
    label: (l) => l.cmdPrintOpen,
    icon: LucideIcons.printer,
    categoryOf: SlidesCategory.file,
    defaultBindings: const [KeyBinding('P', mod: true)],
    argsSchema: JsonSchema.object(
      properties: {
        'layout': JsonSchema.string(
          enumValues: [for (final v in SlidesPdfLayout.values) v.name],
        ),
      },
    ),
    run: (ctx, ed, a) {
      _openPreview(s, ed, layout: a.string('layout'));
      return ok();
    },
  ),
  SlidesCommand(
    'slides.file.download',
    label: (l) => l.cmdFileDownload,
    icon: LucideIcons.download,
    categoryOf: SlidesCategory.file,
    argsSchema: JsonSchema.object(
      properties: {
        'format': const JsonSchema.string(
          enumValues: ['pdf', 'png', 'pngZip', 'markdown'],
        ),
        'options': const JsonSchema.object(
          additionalProperties: true,
          description: 'PDF options (Slides 10 §11.1)',
        ),
        'immediate': const JsonSchema.boolean(),
      },
      required: const ['format'],
    ),
    // PNG (P1) and Markdown (P2) come later (10 §13, 04 §10).
    enabled: (ed, a) => (a.string('format') ?? 'pdf') == 'pdf',
    reason: (l, ed) => l.reasonNotAvailableYet,
    run: (ctx, ed, a) async {
      final l = slidesL10nOf(s);
      if (a.string('format') != 'pdf') {
        return CommandResult.failed(l.exportFormatUnavailable);
      }
      final raw = a.values['options'];
      final immediate = a.boolean('immediate') ?? false;
      if (!immediate) {
        final open = activeSlidesPrint.value;
        if (open != null) {
          return await open.download()
              ? ok()
              : CommandResult.failed(l.exportFailed);
        }
        _openPreview(s, ed);
        return ok();
      }
      return _exportNow(
        s,
        ed,
        raw is Map ? raw.cast<String, Object?>() : const {},
      );
    },
  ),
  SlidesCommand(
    'slides.print.print',
    label: (l) => l.cmdPrintPrint,
    icon: LucideIcons.printer,
    categoryOf: SlidesCategory.file,
    enabled: (ed, a) => activeSlidesPrint.value?.controller?.pdf != null,
    reason: (l, ed) => l.printUpdatingPreview,
    run: (ctx, ed, a) async {
      final open = activeSlidesPrint.value;
      if (open == null) return const CommandResult.failed('No preview');
      return await open.print()
          ? ok()
          : CommandResult.failed(slidesL10nOf(s).printUnavailableTitle);
    },
  ),
];

void _openPreview(ShellServices s, DeckEditorController ed, {String? layout}) {
  final path = '${s.config.itemPath(ed.session.itemUuid.uuid)}/print';
  s.router.go(layout == null ? path : '$path?layout=$layout');
}

Future<CommandResult> _exportNow(
  ShellServices s,
  DeckEditorController ed,
  Map<String, Object?> options,
) async {
  final l = slidesL10nOf(s);
  try {
    final item = await s.drive.get(ed.session.itemUuid);
    if (!item.canDownload) {
      return CommandResult.failed(l.printDownloadsDisabledTitle);
    }
  } on Object {
    // Offline: the deck is local, exporting needs no server.
  }
  final last = SlidesPdfOptionsCodec.toJson(SlidesClientExport.lastUsed(s));
  final o = SlidesPdfOptionsCodec.fromJson({...last, ...options});
  final effective = switch (o.range) {
    'current' => o.copyWith(slideIds: [?ed.currentSlideId]),
    'selection' => o.copyWith(slideIds: ed.selectedSlideIds.toList()),
    _ => o,
  };
  final title = ed.model.deck?.title ?? '';
  final name =
      '${o.fileName ?? SlidesPdfOptionsCodec.sanitizeFileName(title.isEmpty ? l.pdfUntitledPresentation : title)}.pdf';
  try {
    final r = await SlidesClientExport.render(
      ed.model,
      effective,
      images: ed.session.images,
      l: l,
      info: SlidesPdfDocumentInfo(title: title.isEmpty ? null : title),
    );
    final saved = await SlidesClientExport.save(
      _bytes(r.bytes),
      fileName: name,
    );
    if (!saved) return const CommandResult.failed('Cancelled');
    await SlidesClientExport.remember(s, o);
    final warnings = {
      for (final w in r.warnings) SlidesClientExport.warning(l, w),
    };
    s.toasts.show(
      l.exportedToast(name),
      description: warnings.isEmpty ? null : warnings.join('\n'),
    );
    return CommandResult.ok({
      'fileName': name,
      'pageCount': r.pageCount,
      'warnings': r.warnings,
    });
  } on Object catch (e) {
    s.toasts.show(
      l.exportFailed,
      description: errorMessage(e),
      destructive: true,
    );
    return CommandResult.failed(l.exportFailed);
  }
}

Uint8List _bytes(List<int> bytes) =>
    bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
