import 'package:flutter/foundation.dart';

import '../sheet_editor/sheet_editor_controller.dart';
import 'protection_controller.dart';

/// Panel id (04 §10).
const protectionPanelId = 'sheets.panel.protected';

/// What a draft protects.
enum ProtectionTarget { range, sheet }

/// The protection being added or edited in the panel (07 §10.2).
@immutable
class ProtectionDraft {
  const ProtectionDraft({
    this.id,
    this.target = ProtectionTarget.range,
    this.description = '',
    this.rangeText = '',
    required this.sheetId,
    this.exceptEnabled = false,
    this.exceptText = '',
    this.warningOnly = false,
    this.editors = const [],
  });

  /// The edited protection; null for a new one.
  final String? id;
  final ProtectionTarget target;
  final String description;

  /// A1 of the range (range target).
  final String rangeText;

  /// The protected sheet (sheet target) / the sheet of the range.
  final String sheetId;
  final bool exceptEnabled;

  /// A1 list of the exceptions (sheet target).
  final String exceptText;
  final bool warningOnly;
  final List<String> editors;

  bool get isNew => id == null;

  ProtectionDraft copyWith({
    ProtectionTarget? target,
    String? description,
    String? rangeText,
    String? sheetId,
    bool? exceptEnabled,
    String? exceptText,
  }) => ProtectionDraft(
    id: id,
    target: target ?? this.target,
    description: description ?? this.description,
    rangeText: rangeText ?? this.rangeText,
    sheetId: sheetId ?? this.sheetId,
    exceptEnabled: exceptEnabled ?? this.exceptEnabled,
    exceptText: exceptText ?? this.exceptText,
    warningOnly: warningOnly,
    editors: editors,
  );
}

/// The protection panel's state: the list, or a draft being edited.
class ProtectionPanelState extends ChangeNotifier {
  ProtectionPanelState._(this.editor);

  static ProtectionPanelState of(SheetEditorController editor) =>
      editor.extension(ProtectionPanelState, () {
        final s = ProtectionPanelState._(editor);
        editor.onDispose(s.dispose);
        return s;
      });

  final SheetEditorController editor;

  ProtectionDraft? _draft;
  ProtectionDraft? get draft => _draft;

  /// Bumped whenever a new draft starts (resets the editor's fields).
  int generation = 0;

  set draft(ProtectionDraft? d) {
    _draft = d;
    notifyListeners();
  }

  /// Starts a new draft for [rangeText] (default: the selection) or the
  /// sheet [sheetId].
  void startNew({String? rangeText, String? sheetId, bool sheet = false}) {
    generation++;
    draft = ProtectionDraft(
      target: sheet ? ProtectionTarget.sheet : ProtectionTarget.range,
      rangeText: rangeText ?? '',
      sheetId: sheetId ?? editor.activeSheetId,
    );
  }

  /// Edits the existing protection [e].
  void edit(ProtectionEntry e) {
    generation++;
    final rect = e.rects.isEmpty ? null : e.rects.first;
    draft = ProtectionDraft(
      id: e.id,
      target: e.isSheet ? ProtectionTarget.sheet : ProtectionTarget.range,
      description: e.record.description ?? '',
      rangeText: rect == null ? '' : _a1(e.sheet.name, rect.a1),
      sheetId: e.sheet.id,
      exceptEnabled: e.except.isNotEmpty,
      exceptText: e.except.map((r) => r.a1).join(', '),
      warningOnly: e.record.warningOnly,
      editors: e.editors.toList(),
    );
  }

  static String _a1(String sheet, String body) {
    final plain = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(sheet);
    return plain ? '$sheet!$body' : "'${sheet.replaceAll("'", "''")}'!$body";
  }

  /// Back to the list.
  void close() => draft = null;
}
