import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';
import 'package:wonky_server/src/platform/common/models.dart';
import 'package:wonky_server/src/platform/drive/kind_masks.dart';
import 'package:wonky_server/src/platform/spaces/space_kinds.dart';

import '../../support/test_drive.dart';
import '../../support/test_files.dart';
import '../../support/test_users.dart';
import '../../support/wonky_serverpod.dart';

Matcher _wonky(WonkyErrorCode code) =>
    throwsA(isA<WonkyException>().having((e) => e.code, 'code', code));

void main() {
  withWonkyServerpod('Given a reserved deck space', (
    sessionBuilder,
    endpoints,
  ) {
    late TestUser anna;
    late UuidValue space;

    Future<UuidValue> reserve(TestUser user, SpaceKind kind) async {
      final uuid = const Uuid().v7obj();
      await SpaceReservation.db.insertRow(
        user.session,
        SpaceReservation(
          userId: user.id,
          spaceUuid: uuid,
          kind: kind,
          createdAt: DateTime.now().toUtc(),
        ),
      );
      return uuid;
    }

    setUp(() async {
      anna = await TestUsers.create(sessionBuilder, name: 'Anna');
      space = await reserve(anna, SpaceKind.deck);
    });

    test(
      'when registering then a presentation item with the space uuid is created',
      () async {
        final item = await endpoints.drive.registerPresentation(
          anna.endpointSession,
          space,
          null,
          'Pitch',
        );

        expect(item.kind, DriveItemKind.presentation);
        expect(item.uuid, space);
        expect(item.contentRef, space);
        expect(item.name, 'Pitch');
        final reservation = await SpaceReservation.db.findFirstRow(
          anna.session,
          where: (t) => t.spaceUuid.equals(space),
        );
        expect(reservation?.usedAt, isNotNull);
        final subscription = await SpaceSubscription.db.findFirstRow(
          anna.session,
          where: (t) => t.spaceUuid.equals(space),
        );
        expect(subscription?.kind, SpaceKind.deck);
      },
    );

    test('when registered then the space is recorded as a deck', () async {
      await endpoints.drive.registerPresentation(
        anna.endpointSession,
        space,
        null,
        'Pitch',
      );

      expect(await SpaceKinds.of(anna.session, space), SpaceKind.deck);
    });

    test('when registering twice then the same item is returned', () async {
      final first = await endpoints.drive.registerPresentation(
        anna.endpointSession,
        space,
        null,
        'Pitch',
      );

      final again = await endpoints.drive.registerPresentation(
        anna.endpointSession,
        space,
        null,
        'Pitch again',
      );

      expect(again.uuid, first.uuid);
      expect(again.name, 'Pitch');
    });

    test(
      'when registering into a folder then its mask has presentations',
      () async {
        final folder = await TestDrive.folder(endpoints, anna);

        await endpoints.drive.registerPresentation(
          anna.endpointSession,
          space,
          folder.uuid,
          'Pitch',
        );

        final row = await TestFiles.row(anna.session, folder.uuid);
        expect(KindMasks.has(row.kindMask, DriveItemKind.presentation), isTrue);
      },
    );

    test('when the folder is gone then the deck lands in My Drive', () async {
      final item = await endpoints.drive.registerPresentation(
        anna.endpointSession,
        space,
        const Uuid().v7obj(),
        'Pitch',
      );

      expect(item.parentUuid, isNull);
    });

    test(
      'when the space is reserved for a spreadsheet then it is invalid',
      () async {
        final sheetSpace = await reserve(anna, SpaceKind.spreadsheet);

        await expectLater(
          endpoints.drive.registerPresentation(
            anna.endpointSession,
            sheetSpace,
            null,
            'Pitch',
          ),
          _wonky(WonkyErrorCode.invalidArgument),
        );
      },
    );

    test('when someone else registers the space then it is refused', () async {
      final bo = await TestUsers.create(sessionBuilder, name: 'Bo');

      await expectLater(
        endpoints.drive.registerPresentation(
          bo.endpointSession,
          space,
          null,
          'Pitch',
        ),
        _wonky(WonkyErrorCode.forbidden),
      );
    });

    test('when the space was never reserved then it is refused', () async {
      await expectLater(
        endpoints.drive.registerPresentation(
          anna.endpointSession,
          const Uuid().v7obj(),
          null,
          'Pitch',
        ),
        _wonky(WonkyErrorCode.forbidden),
      );
    });

    test('when the deck is listed then it shows as a presentation', () async {
      await endpoints.drive.registerPresentation(
        anna.endpointSession,
        space,
        null,
        'Pitch',
      );

      final page = await endpoints.drive.list(
        anna.endpointSession,
        null,
        DriveListFilter(kinds: [DriveItemKind.presentation]),
        DriveSort(),
        null,
        10,
      );

      expect(page.items.map((i) => i.uuid), [space]);
    });
  });
}
