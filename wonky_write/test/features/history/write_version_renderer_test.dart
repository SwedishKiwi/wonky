import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_ui/testing.dart';
import 'package:wonky_write/features/history/write_version_renderer.dart';
import 'package:wonky_write_core/wonky_write_core.dart';

import '../document/support/session_harness.dart';
import '../sync/support/fake_document_server.dart';

const _anna = '00000000-0000-7000-8000-000000000001';
const _bo = '00000000-0000-7000-8000-000000000002';

WriteDiffView _diff() => WriteDiffView(
  fromRevision: 1,
  toRevision: 4,
  exact: true,
  deltaJson: jsonEncode(
    (Delta()
          ..insert('Hello ')
          ..insert('brave ', {
            'diff_ins': {'by': _anna},
          })
          ..insert('old ', {
            'diff_del': {'by': _bo},
          })
          ..insert('world\n'))
        .toJson(),
  ),
  authors: [
    WriteDiffAuthor(
      userUuid: UuidValue.fromString(_anna),
      name: 'Anna',
      colorIndex: 1,
      actorKind: ActorKind.user,
      inserted: 6,
      deleted: 0,
      formatted: 0,
    ),
    WriteDiffAuthor(
      userUuid: UuidValue.fromString(_bo),
      name: 'Bo',
      colorIndex: 2,
      actorKind: ActorKind.user,
      inserted: 0,
      deleted: 4,
      formatted: 0,
    ),
  ],
  changeCount: 1,
);

class _HistoryApi extends FakeWriteApi {
  _HistoryApi(super.server);

  final copies = <(int, String)>[];

  @override
  Future<WriteDiffView> diff(UuidValue documentUuid, int from, int to) async =>
      _diff();

  @override
  Future<WriteVersionDocument> getVersionDocument(
    UuidValue documentUuid,
    int revision,
  ) async => WriteVersionDocument(
    revision: revision,
    deltaJson: jsonEncode((Delta()..insert('Hello world\n')).toJson()),
  );

  @override
  Future<DriveItemView> copyVersion(
    UuidValue documentUuid,
    int versionId,
    String name, {
    UuidValue? parentUuid,
  }) async {
    copies.add((versionId, name));
    return item;
  }
}

ItemVersionView _version(int id, int revision, {String? name}) =>
    ItemVersionView(
      id: id,
      itemUuid: UuidValue.fromString(itemUuid),
      kind: name == null ? VersionKind.auto : VersionKind.named,
      name: name,
      createdAt: DateTime.utc(2026),
      authors: const [],
      storageKind: VersionStorage.writeRevision,
      revision: revision,
      sizeBytes: 0,
    );

void main() {
  group('Given an attributed diff', () {
    test(
      'when converted then insertions and deletions become marks by author',
      () {
        final content = VersionContent.fromDiff(_diff());

        final suggestions = SuggestionIndex.list(content.delta);
        expect(suggestions, hasLength(2));
        expect(suggestions.first.by, _anna);
        expect(suggestions.first.parts.single.kind, SuggestionPartKind.insert);
        expect(suggestions.last.by, _bo);
        expect(suggestions.last.parts.single.kind, SuggestionPartKind.delete);
        expect(content.changes, [(6, 16)]);
        expect(DeltaUtils.text(content.delta), 'Hello brave old world\n');
      },
    );

    test('when an author is hidden then their changes render plain', () {
      final content = VersionContent.fromDiff(_diff(), hidden: {_bo});

      final suggestions = SuggestionIndex.list(content.delta);
      expect(suggestions.single.by, _anna);
    });
  });

  group('Given the history route showing a version', () {
    testWidgets(
      'when changes are shown then the legend lists the authors and a copy can be made',
      (tester) async {
        final server = FakeDocumentServer();
        final h = SessionHarness(server);
        final api = _HistoryApi(server);
        addTearDown(() => tester.runAsync(h.dispose));

        await pumpWonky(
          tester,
          WriteVersionView(
            services: h.services,
            api: api,
            itemUuid: UuidValue.fromString(itemUuid),
            version: _version(2, 4, name: 'Draft'),
            previous: _version(1, 1),
            showChanges: true,
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Anna'), findsOneWidget);
        expect(find.text('Bo'), findsOneWidget);
        expect(find.text('1 change'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('write.history.copy')));
        await tester.pump();
        expect(api.copies.single, (2, 'Copy of Draft'));
      },
    );
  });
}
