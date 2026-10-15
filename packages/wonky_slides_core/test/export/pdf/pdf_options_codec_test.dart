import 'package:test/test.dart';
import 'package:wonky_slides_core/interfaces.dart';
import 'package:wonky_slides_core/pdf.dart';

void main() {
  group('Given no stored options', () {
    test('when decoding an empty object then the slides defaults of 10 §11.1 '
        'apply', () {
      final o = SlidesPdfOptionsCodec.fromJson(const {});

      expect(o.layout, SlidesPdfLayout.slides);
      expect(o.pageSize, SlidesPdfPageSize.slide);
      expect(o.margins, SlidesPdfMargins.none);
      expect(o.frameSlides, isFalse);
      expect(o.includeSkipped, isFalse);
      expect(o.bookmarks, isTrue);
      expect(o.links, isTrue);
      expect(o.handoutsPerPage, 6);
    });

    test('when decoding notes for en-US then the paper is Letter with normal '
        'margins', () {
      final o = SlidesPdfOptionsCodec.fromJson(const {
        'layout': 'notes',
      }, locale: 'en-US');

      expect(o.pageSize, SlidesPdfPageSize.letter);
      expect(o.margins, SlidesPdfMargins.normal);
    });

    test('when decoding handouts for de-DE then the paper is A4 and slides '
        'are framed', () {
      final o = SlidesPdfOptionsCodec.fromJson(const {
        'layout': 'handouts',
      }, locale: 'de-DE');

      expect(o.pageSize, SlidesPdfPageSize.a4);
      expect(o.frameSlides, isTrue);
    });
  });

  group('Given options with every field set', () {
    const options = SlidesPdfOptions(
      layout: SlidesPdfLayout.handouts,
      handoutsPerPage: 3,
      handoutOrderVertical: true,
      includeBuilds: true,
      includeSkipped: true,
      groupIds: ['g1'],
      pageSize: SlidesPdfPageSize.a3,
      orientation: SlidesPdfOrientation.landscape,
      margins: SlidesPdfMargins.narrow,
      frameSlides: true,
      omitBackground: true,
      headerDate: false,
      headerTitle: true,
      pageNumbers: false,
      slideNumbers: false,
      bookmarks: false,
      links: false,
      compact: true,
      finalAnimationState: true,
      fileName: 'Q3 Review',
    );

    test('when encoding and decoding then the JSON round-trips', () {
      final json = SlidesPdfOptionsCodec.toJson(options);
      final back = SlidesPdfOptionsCodec.fromJson(json);

      expect(SlidesPdfOptionsCodec.toJson(back), json);
      expect(json['range'], {
        'groupIds': ['g1'],
      });
      expect(json['handoutOrder'], 'vertical');
      expect(json['quality'], 'compact');
      expect(json['background'], 'omit');
    });

    test(
      'when storing as preferences then per-deck selections are dropped',
      () {
        final prefs = SlidesPdfOptionsCodec.toPreferences(options);

        expect(prefs.containsKey('range'), isFalse);
        expect(prefs.containsKey('fileName'), isFalse);
        expect(prefs['layout'], 'handouts');
      },
    );

    test('when switching to slides then the slide page and no frame apply', () {
      final o = options.withLayout(SlidesPdfLayout.slides);

      expect(o.pageSize, SlidesPdfPageSize.slide);
      expect(o.margins, SlidesPdfMargins.none);
      expect(o.frameSlides, isFalse);
      expect(o.handoutsPerPage, 3);
    });
  });

  group('Given invalid values', () {
    test('when decoding then they are ignored', () {
      final o = SlidesPdfOptionsCodec.fromJson(const {
        'layout': 'poster',
        'handoutsPerPage': 5,
        'range': '1-x',
        'pageSize': 'b5',
        'bookmarks': 'yes',
      });

      expect(o.layout, SlidesPdfLayout.slides);
      expect(o.handoutsPerPage, 6);
      expect(o.range, 'all');
      expect(o.pageSize, SlidesPdfPageSize.slide);
      expect(o.bookmarks, isTrue);
    });
  });

  group('Given deck position ranges', () {
    for (final (range, count, expected) in [
      ('1-3,7', 10, [0, 1, 2, 6]),
      ('3-1', 10, [0, 1, 2]),
      ('2, 2, 4', 3, [1]),
      ('8-12', 9, [7, 8]),
    ]) {
      test('when resolving "$range" of $count slides then $expected', () {
        expect(SlidesPdfOptionsCodec.positions(range, count), expected);
      });
    }

    test('when resolving all then there are no positions', () {
      expect(SlidesPdfOptionsCodec.positions('all', 3), isNull);
      expect(SlidesPdfOptionsCodec.isValidRange('current'), isTrue);
      expect(SlidesPdfOptionsCodec.isValidRange('1-'), isFalse);
    });
  });

  group('Given file names', () {
    for (final (name, expected) in [
      ('Q3 Review.pdf', 'Q3 Review'),
      ('a/b\\c:d', 'a b c d'),
      ('   ', 'Presentation'),
    ]) {
      test('when sanitizing "$name" then "$expected"', () {
        expect(SlidesPdfOptionsCodec.sanitizeFileName(name), expected);
      });
    }

    test('when a name is longer than 120 characters then it is cut', () {
      expect(SlidesPdfOptionsCodec.sanitizeFileName('x' * 200), hasLength(120));
    });
  });
}
