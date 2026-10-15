import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:wonky_app/wonky_app.dart' show ShellServices;
import 'package:wonky_slides_core/schema.dart' show SlidesTables;
import 'package:wonky_sync_kit_flutter/wonky_sync_kit_flutter.dart'
    show ReplicaRecoveryReader;

import '../../l10n/slides_l10n.dart';
import 'slides_replica.dart';

/// One deck with unsynced local writes read from a replica that can't be
/// opened (suite 12 §2.5 recovery export).
class RecoveredDeck {
  const RecoveredDeck({
    required this.deckId,
    required this.title,
    required this.rows,
  });

  final String deckId;
  final String title;

  /// Every visible model row of the deck (table, column map).
  final List<(String, Map<String, Object?>)> rows;
}

/// The unsynced decks of a broken Slides replica, offered as "Download
/// unsynced changes" before the replica is moved aside (Slides 12 SL-9).
///
/// The engine metadata can't tell which rows the server hasn't
/// acknowledged, so the export holds the whole decks that had local writes
/// since their last complete sync (the dirty marks): one `rows.json`-style
/// JSON file with the raw rows of every such deck (lossless; support can
/// re-import them). The shared kit reads the file read-only on desktop; on
/// the web the replica lives behind the SQLite worker and can't be read
/// once it failed to open, so there is nothing to offer there (as Sheets).
class SlidesReplicaRecovery {
  const SlidesReplicaRecovery(this.decks);

  final List<RecoveredDeck> decks;

  bool get isEmpty => decks.isEmpty;

  /// Reads the replica file [path] (null on the web or when the file can't
  /// be read at all).
  static Future<SlidesReplicaRecovery?> read(String path) async {
    final spaces = await ReplicaRecoveryReader.read(
      path,
      SlidesReplica.slidesTables,
    );
    if (spaces == null) return null;
    return SlidesReplicaRecovery([
      for (final s in spaces)
        RecoveredDeck(
          deckId: s.spaceUuid,
          title: switch (s.valueOf(SlidesTables.deck, 'title')) {
            final String title when title.isNotEmpty => title,
            _ => 'Untitled presentation',
          },
          rows: s.rows,
        ),
    ]);
  }

  /// `Wonky Slides unsynced changes <date>.json`.
  static String fileName(DateTime now) =>
      'Wonky Slides unsynced changes '
      '${now.year}-${_two(now.month)}-${_two(now.day)}.json';

  static String _two(int v) => v.toString().padLeft(2, '0');

  /// The JSON export: `{"decks": [{deckId, title, rows: [{table,
  /// columns}]}]}` (times ISO 8601 UTC, enums by name).
  Uint8List toJsonBytes() {
    final json = {
      'decks': [
        for (final d in decks)
          {
            'deckId': d.deckId,
            'title': d.title,
            'rows': [
              for (final (table, columns) in d.rows)
                {'table': table, 'columns': _jsonColumns(columns)},
            ],
          },
      ],
    };
    return Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(json)),
    );
  }

  static Map<String, Object?> _jsonColumns(Map<String, Object?> c) => {
    for (final e in c.entries)
      e.key: switch (e.value) {
        final DateTime d => d.toUtc().toIso8601String(),
        final Enum v => v.name,
        final v => v,
      },
  };
}

/// Tells the user that the local replica couldn't be opened and offers the
/// unsynced decks as a JSON download ("Download unsynced changes", suite 12
/// §2.5). The toast stays for ten minutes; the file is saved in the same
/// tab on the web (no new tab or window).
void offerSlidesRecoveryDownload(
  ShellServices services,
  SlidesReplicaRecovery recovery,
) {
  final l = slidesL10nOf(services);
  services.toasts.show(
    l.recoveryTitle,
    description: l.recoveryDescription(recovery.decks.length),
    actionLabel: l.recoveryDownload,
    duration: const Duration(minutes: 10),
    onAction: () async {
      try {
        final bytes = recovery.toJsonBytes();
        final name = SlidesReplicaRecovery.fileName(DateTime.now());
        await FilePicker.saveFile(
          fileName: name,
          bytes: bytes,
          dialogTitle: name,
        );
      } catch (e) {
        debugPrint('Recovery download failed: $e');
        services.toasts.error(l.recoveryFailed);
      }
    },
  );
}
