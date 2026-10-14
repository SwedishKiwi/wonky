import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/images/image_io.dart';
import 'package:wonky_sheets/features/images/image_service.dart';
import 'package:wonky_sheets/features/objects/objects_controller.dart';
import 'package:wonky_sheets_core/model.dart';

import '../support/sheets_harness.dart';

/// A 4×2 px PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAQAAAACCAYAAAB/qH1jAAAAEklEQVR4nGMQ2Nn4HxkzoAsAACylEkmfixcOAAAAAElFTkSuQmCC',
);

void main() {
  late SheetsHarness s;

  ObjectsController objects() => ObjectsController.of(s.editor);

  setUp(() {
    s = SheetsHarness.open();
    SheetsFileIo.pickImage = (_) async => PickedImage(
      name: 'logo.png',
      bytes: Uint8List.fromList(_png),
      mimeType: 'image/png',
    );
    SheetsImageService.of(s.editor).remoteLoader = (_) async =>
        Uint8List.fromList(_png);
  });
  tearDown(() async {
    ObjectsController.maybeOf(s.editor)?.dispose();
    await s.dispose();
  });

  group('Given an uploaded image', () {
    test(
      'when inserting it over cells then an image object with the natural '
      'size and a locked aspect is added at the active cell (one undo)',
      () async {
        await s.select('C3');
        final r = await s.run('sheets.image.insertOverCells', {
          'source': 'upload',
        });
        expect(r.isOk, isTrue, reason: r.message);
        final id = (r.data! as Map)['objectId']! as String;
        final o = objects().record(id)!;
        expect(o.kind, EmbeddedObjectKind.image);
        final spec = ImageSpec.fromJson(o.specJson);
        expect((spec.naturalWidth, spec.naturalHeight), (4, 2));
        final a = ObjectAnchor.tryParse(o.anchorJson)!;
        expect(a.lockAspect, isTrue);
        expect(objects().anchorCell(o), (2, 2));
        expect(a.width / a.height, closeTo(2, 0.01));
        expect(
          SheetsImageService.of(s.editor).localBytes(spec.fileUuid),
          isNotNull,
        );

        await s.undo();
        expect(objects().activeObjects, isEmpty);
      },
    );

    test('when placing it in a cell and back over cells then the cell gets '
        '=IMAGE() and the object returns', () async {
      await s.select('B2');
      final r = await s.run('sheets.image.insertOverCells', {
        'source': 'upload',
      });
      final id = (r.data! as Map)['objectId']! as String;
      final uuid = ImageSpec.fromJson(objects().record(id)!.specJson).fileUuid;

      await s.select('E5');
      await s.run('sheets.image.placeInCell', {'objectId': id});
      expect(objects().activeObjects, isEmpty);
      expect(s.content('E5'), contains('wonky-file://$uuid'));

      final back = await s.run('sheets.image.placeOverCells', {'cell': 'E5'});
      expect(back.isOk, isTrue, reason: back.message);
      expect(objects().activeObjects, hasLength(1));
      expect(s.content('E5'), isNull);
    });

    test('when resetting the size then the natural size returns', () async {
      final r = await s.run('sheets.image.insertOverCells', {
        'source': 'upload',
      });
      final id = (r.data! as Map)['objectId']! as String;
      await s.run('sheets.object.resize', {
        'objectId': id,
        'width': 300,
        'height': 300,
      });

      await s.run('sheets.image.resetSize', {'objectId': id});

      final rect = objects().rectOf(objects().record(id)!)!;
      expect((rect.width, rect.height), (20.0 * 2, 20.0));
    });
  });

  group('Given an image URL', () {
    test(
      'when inserting it in a cell then the cell holds an IMAGE formula',
      () async {
        await s.select('A1');
        await s.run('sheets.image.insertInCell', {
          'source': 'url',
          'url': 'https://example.com/a.png',
        });
        expect(s.content('A1'), '=IMAGE("https://example.com/a.png")');
      },
    );

    test('when inserting it over cells then a copy is uploaded and the '
        'source URL kept', () async {
      final r = await s.run('sheets.image.insertOverCells', {
        'source': 'url',
        'url': 'https://example.com/a.png',
      });
      final id = (r.data! as Map)['objectId']! as String;
      final spec = ImageSpec.fromJson(objects().record(id)!.specJson);
      expect(spec.sourceUrl, 'https://example.com/a.png');
      expect(spec.fileUuid, isNotEmpty);
    });

    test('when the URL is not https then the insert fails', () async {
      final r = await s.run('sheets.image.insertInCell', {
        'source': 'url',
        'url': 'http://10.0.0.1/a.png',
      });
      expect(r.isOk, isFalse);
    });
  });
}
