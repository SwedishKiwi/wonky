import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:serverpod/serverpod.dart';
import 'package:wonky_slides_core/model.dart' show DeckModel;
import 'package:wonky_slides_core/ops.dart' show SlidesPlan;
import 'package:wonky_slides_core/schema.dart' show SlidesTables;
import 'package:wonky_sync_kit/rows.dart';

import '../../platform/common/models.dart';
import '../headless/headless_deck.dart';

/// One mutating tool call recorded by a [SlidesShadow].
class SlidesShadowCall {
  SlidesShadowCall({
    required this.callId,
    required this.toolName,
    required this.label,
    required this.changes,
    required this.slideIds,
  });

  final String callId;
  final String toolName;
  final String label;
  final List<RowChange> changes;
  final List<String> slideIds;
}

/// The shadow deck of a Suggest-mode assistant run (Slides 11 §6.3): a
/// copy-on-write overlay over the deck that the run's tool calls read and
/// write ([DeckOverlay]); nothing reaches the deck until the user applies
/// the preview. Each mutating call is recorded with its row changes.
class SlidesShadow implements DeckOverlay {
  SlidesShadow({
    required this.runId,
    required this.userId,
    required this.item,
    required DeckModel base,
  }) : model = copyOf(base),
       previewId = const Uuid().v4(),
       createdAt = clock.now().toUtc();

  final String runId;
  final int userId;
  final DriveItem item;
  final String previewId;
  final DateTime createdAt;

  @override
  final DeckModel model;

  final List<SlidesShadowCall> calls = [];

  UuidValue get space => item.contentRef!;

  /// A detached copy of [m].
  static DeckModel copyOf(DeckModel m) => DeckModel.fromRows(m.deckId, [
    for (final t in SlidesTables.dependencyOrder)
      for (final r in m.records(t)) (t, r.toColumns()),
  ]);

  @override
  void record(SlidesPlan plan, {required String label}) {
    model.applyPlan(plan);
    // "AI: set_text" → slides.set_text.
    final short = label.replaceFirst(RegExp(r'^(AI|MCP): '), '');
    final tool = short.split(' ').first;
    calls.add(
      SlidesShadowCall(
        callId: 'c${calls.length + 1}',
        toolName: tool.contains('.') ? tool : 'slides.$tool',
        label: plan.label.isNotEmpty ? plan.label : short,
        changes: List.of(plan.changes),
        slideIds: [
          for (final id in plan.summary.slides)
            if (!plan.summary.deleted['slides']!.contains(id)) id,
          ...plan.summary.deleted['slides']!,
        ],
      ),
    );
  }
}

/// The shadows of running Suggest-mode runs (by run id).
abstract final class SlidesShadows {
  static final Map<String, SlidesShadow> _byRun = {};

  /// Starts recording run [runId] on [item] from [base].
  static SlidesShadow begin(
    String runId,
    DriveItem item,
    DeckModel base, {
    required int userId,
  }) {
    final s = SlidesShadow(
      runId: runId,
      userId: userId,
      item: item,
      base: base,
    );
    _byRun[runId] = s;
    DeckOverlays.put(runId, s.space, s);
    return s;
  }

  /// Ends run [runId]: its shadow (null when none).
  static SlidesShadow? end(String runId) {
    final s = _byRun.remove(runId);
    if (s != null) DeckOverlays.remove(runId, s.space);
    return s;
  }

  /// Forgets every shadow (tests).
  static void clear() {
    for (final s in _byRun.values) {
      DeckOverlays.remove(s.runId, s.space);
    }
    _byRun.clear();
  }
}

/// A stored Suggest-mode preview: what the dialog shows and the row
/// changes per call.
class StoredSlidesPreview {
  StoredSlidesPreview({
    required this.userId,
    required this.space,
    required this.preview,
    required this.changes,
  });

  final int userId;
  final UuidValue space;
  final SlidesAiPreview preview;
  final Map<String, List<RowChange>> changes;
}

/// Persists Suggest-mode previews (Slides 11 §6.3, A-11-1) so any server
/// instance can show, apply or discard them for 30 minutes. As built, the
/// rows go into Sheets' `sheets_ai_preview_record` table (its
/// `spreadsheetUuid` holds the deck space, like the shared
/// `ServerChangeRecord`), so no new table is needed.
abstract final class SlidesAiPreviewStore {
  static const lifetime = Duration(minutes: 30);

  /// Previews whose encoded changes are larger are not stored.
  static const maxBytes = 8 * 1024 * 1024;

  static String _encode(Map<String, List<RowChange>> changes) => base64Encode(
    gzip.encode(
      utf8.encode(
        jsonEncode({
          for (final e in changes.entries)
            e.key: [for (final c in e.value) c.toJson()],
        }),
      ),
    ),
  );

  /// The preview of [shadow] (calls without their changes).
  static SlidesAiPreview previewOf(SlidesShadow shadow) => SlidesAiPreview(
    previewId: shadow.previewId,
    itemUuid: shadow.item.uuid,
    calls: [
      for (final c in shadow.calls)
        SlidesAiPreviewCall(
          callId: c.callId,
          toolName: c.toolName,
          label: c.label,
          slideIds: c.slideIds,
          changesJson: '',
        ),
    ],
    expiresAt: shadow.createdAt.add(lifetime),
  );

  /// Stores [shadow]'s preview (false when it is too large).
  static Future<bool> save(Session session, SlidesShadow shadow) async {
    final now = clock.now().toUtc();
    await SheetsAiPreviewRecord.db.deleteWhere(
      session,
      where: (t) => t.expiresAt < now,
    );
    final data = _encode({for (final c in shadow.calls) c.callId: c.changes});
    if (data.length > maxBytes) return false;
    final preview = previewOf(shadow);
    await SheetsAiPreviewRecord.db.insertRow(
      session,
      SheetsAiPreviewRecord(
        previewId: shadow.previewId,
        userId: shadow.userId,
        spreadsheetUuid: shadow.space,
        previewJson: jsonEncode(preview.toJson()),
        changesJson: data,
        createdAt: shadow.createdAt,
        expiresAt: preview.expiresAt,
      ),
    );
    return true;
  }

  /// The stored preview [previewId] (null when unknown, expired or not a
  /// presentation preview).
  static Future<StoredSlidesPreview?> load(
    Session session,
    String previewId,
  ) async {
    final row = await SheetsAiPreviewRecord.db.findFirstRow(
      session,
      where: (t) => t.previewId.equals(previewId),
    );
    if (row == null) return null;
    if (row.expiresAt.isBefore(clock.now().toUtc())) {
      await SheetsAiPreviewRecord.db.deleteRow(session, row);
      return null;
    }
    final SlidesAiPreview preview;
    try {
      preview = SlidesAiPreview.fromJson(
        (jsonDecode(row.previewJson) as Map).cast<String, dynamic>(),
      );
    } on Object {
      return null; // A spreadsheet preview.
    }
    final decoded =
        jsonDecode(utf8.decode(gzip.decode(base64Decode(row.changesJson))))
            as Map;
    return StoredSlidesPreview(
      userId: row.userId,
      space: row.spreadsheetUuid,
      preview: preview,
      changes: {
        for (final e in decoded.entries)
          '${e.key}': [
            for (final c in e.value as List)
              RowChange.fromJson((c as Map).cast<String, Object?>()),
          ],
      },
    );
  }

  static Future<void> delete(Session session, String previewId) =>
      SheetsAiPreviewRecord.db.deleteWhere(
        session,
        where: (t) => t.previewId.equals(previewId),
      );
}
