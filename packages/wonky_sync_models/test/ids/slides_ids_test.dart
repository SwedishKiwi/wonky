import 'package:test/test.dart';
import 'package:uuid/uuid.dart';
import 'package:wonky_sync_models/ids.dart';

void main() {
  const deck = '0190f6a0-0000-7000-8000-0000000000d1';
  const slide = '0190f6a0-0000-7000-8000-0000000000a1';
  const element = '0190f6a0-0000-7000-8000-0000000000e1';
  const row = '0190f6a0-0000-7000-8000-0000000000b1';
  const col = '0190f6a0-0000-7000-8000-0000000000c1';
  const theme = '0190f6a0-0000-7000-8000-0000000000f1';
  const layoutPh = '0190f6a0-0000-7000-8000-0000000000f2';
  final v5 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  const uuid = Uuid();

  group('Given the Slides deterministic id helpers', () {
    final ids = <String, String Function()>{
      'tableCellId': () => SlidesIds.tableCellId(element, row, col),
      'placeholderInstanceId': () =>
          SlidesIds.placeholderInstanceId(slide, layoutPh),
      'themeCopyId': () => SlidesIds.themeCopyId(
        deck,
        SlidesIds.builtinThemeSourceKey('wonky', 1),
      ),
      'themePartId': () => SlidesIds.themePartId(theme, 'layout:titleBody'),
      'chartLinkId': () => SlidesIds.chartLinkId(element),
    };

    for (final e in ids.entries) {
      test('when computing ${e.key} twice then it is the same version-5 '
          'UUID', () {
        final id = e.value();
        expect(id, e.value());
        expect(id, matches(v5));
      });
    }

    test('when computing every helper over the same ids then all ids '
        'differ (separate namespaces)', () {
      final all = {for (final f in ids.values) f()};
      expect(all, hasLength(ids.length));
    });

    test('when hashing then the ids equal UUIDv5 over the documented '
        'namespaces and name strings (02 §2.1)', () {
      expect(
        SlidesIds.tableCellId(element, row, col),
        uuid.v5(SlidesIds.tableCellNamespace, 'cell:$element:$row:$col'),
      );
      expect(
        SlidesIds.placeholderInstanceId(slide, layoutPh),
        uuid.v5(SlidesIds.placeholderInstanceNamespace, 'ph:$slide:$layoutPh'),
      );
      expect(
        SlidesIds.themeCopyId(deck, 'builtin:wonky@1'),
        uuid.v5(SlidesIds.themeCopyNamespace, 'theme:$deck:builtin:wonky@1'),
      );
      expect(
        SlidesIds.themePartId(theme, 'el:titleBody/title'),
        uuid.v5(SlidesIds.themePartNamespace, 'part:$theme:el:titleBody/title'),
      );
      expect(
        SlidesIds.chartLinkId(element),
        uuid.v5(SlidesIds.chartLinkNamespace, 'chartLink:$element'),
      );
    });

    test('when hashing fixed inputs then the ids are the recorded ones '
        '(namespaces never change)', () {
      expect(
        SlidesIds.tableCellId(element, row, col),
        '0767eea0-143d-57df-8a2d-5c0744bd5cc2',
      );
      expect(
        SlidesIds.placeholderInstanceId(slide, layoutPh),
        '5c0c6345-eb3d-527a-87b9-3293f1f7fac1',
      );
      expect(
        SlidesIds.themeCopyId(deck, 'builtin:wonky@1'),
        '09e38b2a-4b26-5708-bb18-11e23f784fdb',
      );
      expect(
        SlidesIds.themePartId(theme, 'master:default'),
        '4483d48f-de16-5494-91b8-b838068f9e07',
      );
      expect(
        SlidesIds.chartLinkId(element),
        'c48325af-28ae-5b13-a119-0e71258a2585',
      );
    });

    test('when the UUID inputs differ in case then the ids are the same', () {
      final up = deck.toUpperCase();
      expect(
        SlidesIds.tableCellId(element.toUpperCase(), row, col.toUpperCase()),
        SlidesIds.tableCellId(element, row, col),
      );
      expect(
        SlidesIds.placeholderInstanceId(slide.toUpperCase(), layoutPh),
        SlidesIds.placeholderInstanceId(slide, layoutPh),
      );
      expect(
        SlidesIds.themeCopyId(up, 'builtin:wonky@1'),
        SlidesIds.themeCopyId(deck, 'builtin:wonky@1'),
      );
      expect(
        SlidesIds.chartLinkId(element.toUpperCase()),
        SlidesIds.chartLinkId(element),
      );
    });

    test('when a source or part key holds a UUID in upper case then it is '
        'normalized, other key text is kept', () {
      expect(
        SlidesIds.themeCopyId(deck, 'deck:${deck.toUpperCase()}:$theme'),
        SlidesIds.themeCopyId(deck, 'deck:$deck:$theme'),
      );
      expect(
        SlidesIds.themePartId(theme, element.toUpperCase()),
        SlidesIds.themePartId(theme, element),
      );
      expect(
        SlidesIds.themePartId(theme, 'layout:titleBody'),
        isNot(SlidesIds.themePartId(theme, 'layout:titlebody')),
      );
    });

    test('when row and column axes are swapped then the cell ids differ', () {
      expect(
        SlidesIds.tableCellId(element, row, col),
        isNot(SlidesIds.tableCellId(element, col, row)),
      );
    });

    test('when the deck differs then the theme copy and its parts differ '
        '(copies rewrite deterministic ids, 02 §9.3)', () {
      const other = '0190f6a0-0000-7000-8000-0000000000d2';
      final a = SlidesIds.themeCopyId(deck, 'builtin:wonky@1');
      final b = SlidesIds.themeCopyId(other, 'builtin:wonky@1');
      expect(a, isNot(b));
      expect(
        SlidesIds.themePartId(a, 'master:default'),
        isNot(SlidesIds.themePartId(b, 'master:default')),
      );
    });

    test('when building source keys then they have the documented form', () {
      expect(SlidesIds.builtinThemeSourceKey('aurora', 3), 'builtin:aurora@3');
      expect(
        SlidesIds.deckThemeSourceKey(deck.toUpperCase(), theme.toUpperCase()),
        'deck:$deck:$theme',
      );
    });

    test('when creating match keys then they are 22-character base-62 keys '
        'of fresh ids', () {
      final gen = SequentialIdGenerator();
      final a = SlidesIds.newMatchKey(gen);
      final b = SlidesIds.newMatchKey(gen);
      expect(a, hasLength(22));
      expect(Base62Uuid.isValid(a), isTrue);
      expect(a, isNot(b));
      expect(Base62Uuid.decode(a), '00000000-0000-4000-8000-000000000001');
    });

    test('when converting a cell id to a UuidValue then it parses', () {
      expect(
        SlidesIds.tableCellUuid(element, row, col).uuid,
        SlidesIds.tableCellId(element, row, col),
      );
    });
  });
}
