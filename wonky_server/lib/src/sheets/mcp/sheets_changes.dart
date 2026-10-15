import 'package:clock/clock.dart';
import 'package:serverpod/serverpod.dart';
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_sheets_core/model.dart'
    show CellRecord, RowChange, SheetsTables, WorkbookModel;

import '../../platform/common/actor.dart';
import '../../platform/common/models.dart';
import '../../platform/mcp/tool_support.dart';
import '../headless/headless_workbook_provider.dart';
import '../../platform/spaces/space_service.dart';
import 'sheets_bulk_writer.dart';
import 'sheets_mcp_support.dart';
import 'sheets_writes.dart';

/// `changes.revert` for spreadsheet changes (Sheets 12 §2.5) and the
/// composite records of assistant runs (§6.2: one undo step "AI: …").
abstract final class SheetsChanges {
  /// Reverts the spreadsheet change [changeId] when it is one (returns null
  /// otherwise, so `changes.revert` can try Write changes). Only the
  /// caller's own changes can be reverted.
  static Future<Map<String, Object?>?> tryRevert(
    ToolContext ctx,
    String changeId,
  ) async {
    UuidValue id;
    try {
      id = UuidValue.withValidation(changeId);
    } on FormatException {
      return null;
    }
    final record = await ServerChangeRecord.db.findFirstRow(
      ctx.session,
      where: (t) => t.changeId.equals(id),
    );
    if (record == null) return null;
    if (record.userId != ctx.actor.userId) {
      throw McpToolException(
        McpErrorCode.notFound,
        'Change not found. Only your own changes of the last 24 hours can '
        'be reverted.',
      );
    }
    if (record.revertedAt != null) {
      throw McpToolException(
        McpErrorCode.conflict,
        'This change was already reverted.',
      );
    }
    if (record.expiresAt.isBefore(clock.now().toUtc())) {
      throw McpToolException(
        McpErrorCode.expired,
        'Changes can only be reverted within 24 hours.',
      );
    }
    final (item, _) = await SheetsMcp.resolveItem(
      ctx.session,
      ctx,
      record.spreadsheetUuid.uuid,
      min: Role.editor,
    );
    final inverse = await SheetsChangeRecords.inverse(ctx.session, record);
    if (inverse.isEmpty) {
      throw McpToolException(
        McpErrorCode.expired,
        'The change can no longer be reverted.',
      );
    }
    await SpaceService.ensureWriter(ctx.session, ctx.actor, item);
    final label = 'Undo ${record.label}';
    final result = await HeadlessWorkbookProvider.withWriteLock(
      item.contentRef!,
      () async {
        final applied = await SheetsBulkWriter.apply(
          ctx.session,
          actor: ctx.actor,
          spaceUuid: item.contentRef!,
          changes: inverse,
          label: label,
          plans: const [],
          skipChanged: true,
        );
        final revertId = await SheetsChangeRecords.store(
          ctx.session,
          actor: ctx.actor,
          item: item,
          label: label,
          applied: applied.applied,
        );
        await ServerChangeRecord.db.updateRow(
          ctx.session,
          record.copyWith(
            revertedAt: clock.now().toUtc(),
            revertChangeId: revertId,
          ),
        );
        return RevertResult(
          changeId: revertId,
          revertedCells: applied.cellsAffected,
          skipped: applied.skipped,
        );
      },
    );
    HeadlessWorkbookProvider.markStale(item.contentRef!);
    await SheetsWrites.afterCommit(ctx.session, item.contentRef!);
    final wb = await HeadlessWorkbookProvider.open(
      ctx.session,
      item.contentRef!,
    );
    final skipped = [
      for (final s in result.skipped)
        {
          if (s.table == SheetsTables.cell)
            if (_cellA1(wb.model, s.rowId.uuid) case final String a1) 'a1': a1,
          'table': s.table,
          'column': s.column,
          'reason': s.reason,
          'by': ?s.byUserUuid?.uuid,
        },
    ];
    return {
      'change_id': result.changeId.uuid,
      'reverted_change_id': changeId,
      'spreadsheet': item.uuid.uuid,
      'reverted_cells': result.revertedCells,
      'skipped': skipped,
      'summary':
          'Reverted "${record.label}"'
          '${skipped.isEmpty ? '' : ' (${skipped.length} value(s) changed by others were kept)'}',
    };
  }

  static String? _cellA1(WorkbookModel model, String cellId) {
    final rec = model.record(SheetsTables.cell, cellId);
    if (rec is! CellRecord) return null;
    final s = model.sheet(rec.sheetId);
    if (s == null) return null;
    final r = s.rows.indexOf(rec.rowId);
    final c = s.columns.indexOf(rec.columnId);
    if (r < 0 || c < 0) return null;
    return SheetsMcp.cellA1(model, s.id, r, c);
  }

  // ------------------------------------------------------------ composite

  /// Combines the records [changeIds] (in order) of one assistant run into
  /// one [ServerChangeRecord] labeled [label]: reverting it reverts all of
  /// them in reverse order with the per-column skip rule (Sheets 12 §6.2).
  /// One record is returned as is; null without records.
  static Future<UuidValue?> composite(
    Session session, {
    required Actor actor,
    required DriveItem item,
    required List<String> changeIds,
    required String label,
  }) async {
    final ids = <UuidValue>[
      for (final c in changeIds)
        if (UuidValue.withValidation(c) case final UuidValue u) u,
    ];
    if (ids.length < 2) return ids.isEmpty ? null : ids.first;
    final records = await ServerChangeRecord.db.find(
      session,
      where: (t) => t.changeId.inSet(ids.toSet()),
    );
    final byId = {for (final r in records) r.changeId.uuid: r};
    final forward = <RowChange>[];
    var cells = 0;
    for (final id in ids) {
      final r = byId[id.uuid];
      if (r == null) continue;
      forward.addAll(await SheetsChangeRecords.forward(session, r));
      cells += r.cellsAffected;
    }
    if (forward.isEmpty) return null;
    return SheetsChangeRecords.store(
      session,
      actor: actor,
      item: item,
      label: label,
      applied: forward,
      cellsAffected: cells,
    );
  }
}
