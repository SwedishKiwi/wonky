import 'package:flutter/foundation.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart' show DriveItemKind, UuidValue;
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides_core/session.dart' show SlidesRowsUndoHandler;
import 'package:wonky_ui/wonky_ui.dart' show SyncStatus;

import '../../l10n/slides_l10n.dart';
import 'deck_editor_controller.dart';

/// The shell's view of an open presentation (suite 03 §5, Slides 04 §2):
/// title, role, the undo stack with the `slides.rows` handler, selection
/// snapshots, zoom, sync status and MCP state. The [editor] is attached
/// once the deck session is ready.
class DeckDocumentController extends DocumentController {
  DeckDocumentController({
    required this.services,
    required this.itemUuid,
    this.title = '',
    this._role = Role.viewer,
    this.persistUndo = true,
  }) {
    undo = SlidesRowsUndoHandler(
      () => editor!.session,
      onPartial: () {
        partialUndos++;
        services.toasts.show(slidesL10nOf(services).toastUndoPartial);
      },
    );
  }

  final ShellServices services;

  @override
  final UuidValue itemUuid;

  @override
  String title;

  @override
  final bool persistUndo;

  Role _role;

  /// The `slides.rows` undo handler (02 §12.2).
  late final SlidesRowsUndoHandler undo;

  /// How often an undo skipped columns a collaborator changed (tests).
  int partialUndos = 0;

  DeckEditorController? _editor;

  /// The editor (null while the deck opens).
  DeckEditorController? get editor => _editor;

  @override
  DriveItemKind get kind => DriveItemKind.presentation;

  @override
  Role get role => _editor?.role ?? _role;

  @override
  bool get isLoaded => _editor != null;

  @override
  List<UndoHandler<UndoEntry>> get undoHandlers => [undo];

  /// Attaches the editor of the opened deck.
  void attach(DeckEditorController editor) {
    _editor?.removeListener(notifyListeners);
    _editor = editor;
    editor.itemRole = _role;
    editor.addListener(notifyListeners);
    notifyListeners();
  }

  void update({String? title, Role? role}) {
    if (title != null) this.title = title;
    if (role != null) {
      _role = role;
      _editor?.itemRole = role;
    }
    notifyListeners();
  }

  // ---- Selection ----

  @override
  SelectionSnapshot? captureSelection() => _editor?.captureSelection();

  @override
  void restoreSelection(SelectionSnapshot selection) =>
      _editor?.restoreSelection(selection);

  @override
  String? get selectionSummary => _editor?.describeSelection();

  // ---- Edit menu (cut/copy/paste come with SL-18's clipboard) ----

  @override
  bool get canCut => false;

  @override
  bool get canCopy => false;

  @override
  bool get canPaste => false;

  @override
  bool get canSelectAll => false;

  // ---- View ----

  @override
  String get mode =>
      (_editor?.viewMode ?? !role.canEdit) ? 'viewing' : 'editing';

  @override
  double get zoom => _editor?.zoom ?? 1;

  @override
  void setZoom(double zoom) => _editor?.setZoom(zoom);

  @override
  void focusEditor() => _editor?.canvasFocus.requestFocus();

  // ---- Sync ----

  @override
  ValueListenable<SyncStatus> get syncStatus =>
      _editor?.session.syncStatus ?? super.syncStatus;

  @override
  Map<String, Object?> describeState() =>
      _editor?.describeState() ?? const {'loading': true};

  @override
  void onRoleChanged(Role role) {
    _role = role;
    _editor?.itemRole = role;
    notifyListeners();
  }

  @override
  void dispose() {
    _editor?.removeListener(notifyListeners);
    super.dispose();
  }
}
