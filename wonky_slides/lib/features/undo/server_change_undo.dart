import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart'
    show RevertResult, UuidValue, WonkyErrorCode, WonkyException;
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides_core/session.dart' show slidesServerChangeDomain;

import '../../l10n/slides_l10n.dart';

export 'package:wonky_slides_core/session.dart' show slidesServerChangeDomain;

/// One change applied on the server (Slides 02 §12.2): an assistant run
/// (SL-43), an applied AI preview, a version restore (SL-39), a template
/// or headless MCP change surfaced in the UI. Undo reverts it
/// (`SlidesEndpoint.revertChange`, per-column skip rule), redo re-applies
/// it (`reapplyChange`). [changeId] is always the latest record (the
/// original, then its revert, then the re-application …).
class SlidesServerChangeEntry extends UndoEntry {
  const SlidesServerChangeEntry({
    required this.changeId,
    this.label = '',
    this.reverted = false,
  });

  final String changeId;

  /// "AI: Make a deck", "Restore version" (diagnostics).
  final String label;

  /// Whether [changeId] is a revert (the next redo re-applies it).
  final bool reverted;

  @override
  String get domain => slidesServerChangeDomain;

  /// Remote edits are handled by the server's skip rule at undo time.
  @override
  UndoEntry? rebase(RemoteChange change) => this;

  @override
  Map<String, Object?> toJson() => {
    'changeId': changeId,
    'label': label,
    if (reverted) 'reverted': true,
  };

  static SlidesServerChangeEntry? fromJson(Map<String, Object?> j) {
    final id = j['changeId'];
    if (id is! String) return null;
    return SlidesServerChangeEntry(
      changeId: id,
      label: j['label'] as String? ?? '',
      reverted: j['reverted'] == true,
    );
  }
}

/// Calls the server for [SlidesServerChangeEntry]s: undo =
/// `slides.revertChange`, redo = `slides.reapplyChange` (both with the
/// per-column skip rule; columns others changed since are kept and a
/// toast says so). Registered with the deck's undo stack
/// (`DeckDocumentController.undoHandlers`).
class SlidesServerChangeHandler extends UndoHandler<SlidesServerChangeEntry> {
  SlidesServerChangeHandler(this.services, {this.revert, this.reapply});

  final ShellServices services;

  /// Override the server calls (tests).
  final Future<RevertResult> Function(String changeId)? revert;
  final Future<RevertResult> Function(String changeId)? reapply;

  @override
  String get domain => slidesServerChangeDomain;

  @override
  UndoEntryDecoder? get decoder => SlidesServerChangeEntry.fromJson;

  Future<RevertResult> _call(String changeId, {required bool redo}) {
    final f = redo ? reapply : revert;
    if (f != null) return f(changeId);
    final client = services.client;
    if (client == null || Api.simulatedOffline) {
      throw const UndoConflict('Offline');
    }
    final id = UuidValue.fromString(changeId);
    return redo
        ? client.slides.reapplyChange(id)
        : client.slides.revertChange(id);
  }

  Future<SlidesServerChangeEntry> _apply(
    SlidesServerChangeEntry e, {
    required bool redo,
  }) async {
    final RevertResult r;
    try {
      r = await _call(e.changeId, redo: redo);
    } on WonkyException catch (err) {
      if (err.code == WonkyErrorCode.notFound ||
          err.code == WonkyErrorCode.expired) {
        throw UndoConflict(err.message);
      }
      rethrow;
    }
    if (r.skipped.isNotEmpty) {
      services.toasts.show(slidesL10nOf(services).toastUndoPartial);
    }
    return SlidesServerChangeEntry(
      changeId: r.changeId.uuid,
      label: e.label,
      reverted: !redo,
    );
  }

  @override
  Future<SlidesServerChangeEntry> undo(SlidesServerChangeEntry entry) =>
      _apply(entry, redo: false);

  @override
  Future<SlidesServerChangeEntry> redo(SlidesServerChangeEntry entry) =>
      _apply(entry, redo: true);
}

/// Pushes one undo step for the server change [changeId] on the open
/// deck's stack ([stack], default: the active document's), labelled
/// [label] ("AI: Make a deck about …", "Restore version"). Returns the
/// step id (`server-<changeId>`).
String pushSlidesServerChangeStep(
  ShellServices services, {
  required String changeId,
  required String label,
  InvocationSource source = InvocationSource.ai,
  UndoStackKey? stack,
}) {
  final id = 'server-$changeId';
  services.undo.push(
    UndoStep(
      id: id,
      label: label,
      entries: [SlidesServerChangeEntry(changeId: changeId, label: label)],
      source: source,
    ),
    stack: stack,
  );
  return id;
}
