import 'package:test/test.dart';
import 'package:wonky_slides_core/icons.dart';

void main() {
  group('Given the Lucide glyph map', () {
    test('when looking up names and aliases then both give the same code '
        'point', () {
      expect(LucideGlyphs.codePoint('rocket'), isNotNull);
      expect(
        LucideGlyphs.codePoint('alert-circle'),
        LucideGlyphs.codePoint('circle-alert'),
      );
      expect(LucideGlyphs.codePoint('no-such-icon'), isNull);
      expect(LucideGlyphs.glyph('rocket')!.length, 1);
    });

    test('when mapping stroke widths then the nearest weighted family is '
        'used', () {
      expect(LucideGlyphs.fontFamilyFor(1), 'Lucide200');
      expect(LucideGlyphs.fontFamilyFor(1.5), 'Lucide300');
      expect(LucideGlyphs.fontFamilyFor(null), 'Lucide400');
      expect(LucideGlyphs.fontFamilyFor(2.4), 'Lucide500');
      expect(LucideGlyphs.fontFamilyFor(9), 'Lucide600');
      expect(LucideGlyphs.fontFamilyFor(double.nan), 'Lucide400');
      expect(
        LucideGlyphs.assetFamilyFor(2),
        'packages/lucide_icons_flutter/Lucide400',
      );
    });
  });

  group('Given the icon catalog', () {
    test('when building then each glyph is listed once with its aliases', () {
      final icons = LucideCatalog.icons;
      expect(icons.length, greaterThan(1500));
      expect(icons.map((i) => i.codePoint).toSet().length, icons.length);
      final alert = LucideCatalog.of('alert-circle')!;
      expect(LucideCatalog.of('circle-alert'), same(alert));
      expect({alert.name, ...alert.aliases}, {'alert-circle', 'circle-alert'});
      expect(alert.label, startsWith(alert.name[0].toUpperCase()));
    });

    test('when searching by name then exact and prefix matches rank first', () {
      final r = LucideCatalog.search('rocket');
      expect(r.first.name, 'rocket');
      final arrows = LucideCatalog.search('arrow up');
      expect(arrows.first.name, 'arrow-up');
      bool has(LucideIcon i, String w) => [
        i.name,
        ...i.aliases,
      ].any((n) => n.split('-').any((x) => x.startsWith(w)));
      expect(
        arrows.take(10).every((i) => has(i, 'arrow') && has(i, 'up')),
        isTrue,
      );
    });

    test('when searching by a synonym then matching icons are found', () {
      final r = LucideCatalog.search('email');
      expect(r.map((i) => i.name), contains('mail'));
      expect(
        LucideCatalog.search('settings').map((i) => i.name),
        contains('cog'),
      );
    });

    test('when searching for nothing then every icon of the category is '
        'returned', () {
      expect(LucideCatalog.search('  ').length, LucideCatalog.icons.length);
      final weather = LucideCatalog.search(
        '',
        category: LucideCategory.weather,
      );
      expect(weather.map((i) => i.name), contains('cloud-rain'));
      expect(
        weather.every((i) => i.categories.contains(LucideCategory.weather)),
        isTrue,
      );
    });

    test('when a word matches nothing then the search is empty', () {
      expect(LucideCatalog.search('rocket zzzzqq'), isEmpty);
    });

    test('when listing categories then every category has icons', () {
      for (final c in LucideCategory.values) {
        expect(LucideCatalog.inCategory(c), isNotEmpty, reason: c.name);
      }
    });
  });
}
