import 'package:image/image.dart' as img;
import 'package:test/test.dart';
import 'package:wonky_server/src/platform/files/file_preview_service.dart';

import '../../support/file_fixtures.dart';

void main() {
  group('Given images to preview', () {
    test('when rendering a wide PNG then the preview is at most 2048 px', () {
      final r = FilePreviews.render(
        FileFixtures.bytes('wide.png'),
        'image/png',
      )!;
      final preview = img.decodeImage(r.preview!)!;

      expect((r.width, r.height), (2400, 1000));
      expect((preview.width, preview.height), (2048, 853));
    });

    test('when rendering then the thumbnail is 400 × 300', () {
      final r = FilePreviews.render(
        FileFixtures.bytes('wide.png'),
        'image/png',
      )!;
      final thumb = img.decodeImage(r.thumbnail!)!;

      expect((thumb.width, thumb.height), (400, 300));
    });

    test(
      'when rendering a JPEG with EXIF orientation then it is rotated and the EXIF is stripped',
      () {
        final r = FilePreviews.render(
          FileFixtures.bytes('photo.jpg'),
          'image/jpeg',
        )!;
        final preview = img.decodeJpg(r.preview!)!;

        expect((r.width, r.height), (12, 16));
        expect(r.previewMime, 'image/jpeg');
        expect(preview.exif.imageIfd.hasOrientation, isFalse);
        expect(preview.exif.gpsIfd.isEmpty, isTrue);
      },
    );

    test('when rendering a transparent PNG then the preview stays PNG', () {
      final r = FilePreviews.render(
        FileFixtures.bytes('image.png'),
        'image/png',
      )!;

      expect(r.previewMime, 'image/png');
    });

    test('when the bytes are not an image then nothing is rendered', () {
      expect(
        FilePreviews.render(FileFixtures.bytes('notes.md'), 'image/png'),
        isNull,
      );
    });

    test('when the type is not previewed then nothing is rendered', () {
      expect(
        FilePreviews.render(FileFixtures.bytes('scan.tif'), 'image/tiff'),
        isNull,
      );
    });
  });
}
