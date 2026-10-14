import 'package:clock/clock.dart';
import 'package:serverpod/serverpod.dart';
import 'package:wonky_sheets_core/wonky_sheets_core.dart'
    hide ActorKind, CellInput;

import '../headless/headless_workbook.dart';

/// One mutating tool call recorded in a [SheetsShadow] (AI Suggest mode,
/// Sheets 12 §6.3).
class ShadowCall {
  ShadowCall({
    required this.callId,
    required this.toolName,
    required this.label,
    required this.changes,
    required this.ranges,
    required this.cellsAffected,
    required this.kinds,
    this.structural,
  });

  final String callId;
  final String toolName;
  final String label;

  /// The planned row changes (against the shadow state before the call).
  final List<RowChange> changes;

  /// A1 ranges the call wrote.
  final List<String> ranges;
  final int cellsAffected;
  final Set<String> kinds;

  /// A text description of structure changes ("Inserted 3 rows").
  final String? structural;
}

/// A copy-on-write overlay of a spreadsheet for the assistant's Suggest
/// mode (Sheets 12 §6.3): mutating tool calls are planned against [model]
/// (a private copy of the headless workbook) and recorded instead of
/// committed, so multi-step plans see their own results. The client shows
/// the recorded calls in the AI changes preview and applies the selected
/// ones.
class SheetsShadow {
  SheetsShadow._(this.previewId, this.space, this.userId, this.wb, this.base);

  /// Creates a shadow of [source] for [userId].
  factory SheetsShadow.of(
    HeadlessWorkbook source, {
    required String previewId,
    required int userId,
  }) {
    final copy = WorkbookModel.fromRows(
      source.model.spreadsheetId,
      source.model.allRows().toList(),
    );
    final wb = HeadlessWorkbook(
      space: source.space,
      model: copy,
      watermark: source.watermark,
      estimatedBytes: source.estimatedBytes,
    );
    final base = HeadlessWorkbook(
      space: source.space,
      model: WorkbookModel.fromRows(
        source.model.spreadsheetId,
        source.model.allRows().toList(),
      ),
      watermark: source.watermark,
      estimatedBytes: source.estimatedBytes,
    );
    return SheetsShadow._(previewId, source.space, userId, wb, base);
  }

  final String previewId;
  final UuidValue space;
  final int userId;

  /// The shadow state (all recorded calls applied).
  final HeadlessWorkbook wb;

  /// The state when the shadow was created (before → after previews).
  final HeadlessWorkbook base;

  final DateTime createdAt = clock.now();
  final List<ShadowCall> calls = [];

  /// The id of the next recorded call.
  String nextCallId() => 'c${calls.length + 1}';

  void dispose() {
    wb.dispose();
    base.dispose();
  }
}

/// The open shadows by assistant run (`ToolContext.groupId`) and by
/// preview id (Sheets 12 §6.3: plans expire after 30 min).
abstract final class SheetsShadows {
  static Duration lifetime = const Duration(minutes: 30);

  static final Map<String, SheetsShadow> _byGroup = {};
  static final Map<String, SheetsShadow> _byPreview = {};

  /// Starts recording the Suggest-mode run [groupId] on [source].
  static SheetsShadow begin(
    String groupId,
    HeadlessWorkbook source, {
    required int userId,
  }) {
    _expire();
    final shadow = SheetsShadow.of(source, previewId: groupId, userId: userId);
    _byGroup[groupId] = shadow;
    _byPreview[shadow.previewId] = shadow;
    return shadow;
  }

  /// The shadow mutating tool calls of run [groupId] write into, or null
  /// (Edit mode, MCP).
  static SheetsShadow? forGroup(String? groupId) =>
      groupId == null ? null : _byGroup[groupId];

  /// Ends recording for [groupId]; the shadow stays available as a preview
  /// until it is applied, discarded or expires. Returns it when it has
  /// recorded calls (else it is discarded).
  static SheetsShadow? end(String groupId) {
    final s = _byGroup.remove(groupId);
    if (s == null) return null;
    if (s.calls.isEmpty) {
      _byPreview.remove(s.previewId);
      s.dispose();
      return null;
    }
    return s;
  }

  /// The preview [previewId] (null when unknown or expired).
  static SheetsShadow? preview(String previewId) {
    _expire();
    return _byPreview[previewId];
  }

  /// Discards a preview.
  static void discard(String previewId) {
    final s = _byPreview.remove(previewId);
    if (s == null) return;
    _byGroup.removeWhere((_, v) => identical(v, s));
    s.dispose();
  }

  static void _expire() {
    final now = clock.now();
    for (final s in _byPreview.values.toList()) {
      if (now.difference(s.createdAt) > lifetime) discard(s.previewId);
    }
  }

  /// Drops everything (tests).
  static void clear() {
    for (final id in _byPreview.keys.toList()) {
      discard(id);
    }
    _byGroup.clear();
  }
}
