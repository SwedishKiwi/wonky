import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_slides_core/themes.dart';

void main() {
  group('Given the built-in theme registry (05 §6)', () {
    test('when listing then the 10 stable keys are in panel order', () {
      expect(BuiltInThemes.keys, [
        'wonky',
        'paper',
        'midnight',
        'swiss',
        'terminal',
        'aurora',
        'studio',
        'classic',
        'mono',
        'botanical',
      ]);
      expect(BuiltInThemes.defaultTheme.key, 'wonky');
    });

    test('when reading default appearances then they match 05 §6', () {
      expect(
        {for (final t in BuiltInThemes.all) t.key: t.defaultAppearance.name},
        {
          'wonky': 'light',
          'paper': 'light',
          'midnight': 'dark',
          'swiss': 'light',
          'terminal': 'dark',
          'aurora': 'dark',
          'studio': 'light',
          'classic': 'light',
          'mono': 'light',
          'botanical': 'light',
        },
      );
    });

    test('when reading code palette pairs then they match 05 §2.9', () {
      expect(
        {
          for (final t in BuiltInThemes.all)
            t.key: '${t.codeLight}/${t.codeDark}',
        },
        {
          'wonky': 'wonky-light/wonky-dark',
          'paper': 'solarized-light/solarized-dark',
          'midnight': 'github-light/one-dark',
          'swiss': 'monochrome-light/monochrome-dark',
          'terminal': 'github-light/github-dark',
          'aurora': 'wonky-light/dracula',
          'studio': 'wonky-light/one-dark',
          'classic': 'github-light/github-dark',
          'mono': 'monochrome-light/monochrome-dark',
          'botanical': 'solarized-light/solarized-dark',
        },
      );
    });

    test('when looking up a source key then the definition is found', () {
      expect(BuiltInThemes.bySourceKey('builtin:paper@1')!.key, 'paper');
      expect(BuiltInThemes.bySourceKey('deck:x:y'), isNull);
      expect(BuiltInThemes.byKey('nope'), isNull);
    });

    test(
      'when building a package twice then the cached package is returned',
      () {
        expect(
          identical(
            BuiltInThemes.package('wonky'),
            BuiltInThemes.package('wonky'),
          ),
          isTrue,
        );
      },
    );
  });

  for (final def in BuiltInThemes.all) {
    group('Given the built-in ${def.name}', () {
      final pkg = BuiltInThemes.package(def.key)!;
      final master = pkg.masters.single;
      final parts = pkg.elementsByPart;

      test('when building then the theme carries builtin:<key>@<version>', () {
        expect(pkg.theme.sourceKey, 'builtin:${def.key}@${def.version}');
        expect(pkg.theme.name, def.name);
        expect(master.partKey, builtInMasterPart);
      });

      test(
        'when building then it has the 16 layouts with stable part keys',
        () {
          expect([for (final l in master.layouts) l.key], builtInLayoutKeys);
          expect(
            [for (final l in master.layouts) l.partKey],
            [for (final k in builtInLayoutKeys) 'layout:$k'],
          );
        },
      );

      test(
        'when building then element part keys are unique and scoped to their owner',
        () {
          final all = [
            ...master.elements,
            for (final l in master.layouts) ...l.elements,
          ];
          expect(all.map((e) => e.partKey).toSet(), hasLength(all.length));
          for (final e in master.elements) {
            expect(e.partKey, startsWith('el:master/'));
          }
          for (final l in master.layouts) {
            for (final e in l.elements) {
              expect(e.partKey, startsWith('el:${l.key}/'));
            }
          }
        },
      );

      test('when building then layout placeholder types match the library', () {
        for (final l in master.layouts) {
          expect(
            [for (final p in l.placeholders) p.placeholderType],
            BuiltInLayouts.byKey(l.key!)!.types,
            reason: l.key,
          );
        }
      });

      test(
        'when building then title and body placeholders refine the master',
        () {
          for (final l in master.layouts) {
            for (final p in l.placeholders) {
              final t = p.placeholderType!;
              if (t == SlidePlaceholderType.title ||
                  t == SlidePlaceholderType.body) {
                expect(
                  p.placeholderOf,
                  'el:master/${t.name}',
                  reason: p.partKey,
                );
                expect(parts[p.placeholderOf], isNotNull);
              } else {
                expect(p.placeholderOf, isNull, reason: p.partKey);
              }
            }
          }
        },
      );

      for (final appearance in SlideAppearance.values) {
        test(
          'when resolving every layout in ${appearance.name} then there are no warnings',
          () {
            final theme = DeckThemeResolver.resolveUncached(
              pkg.theme,
              appearance,
            );
            expect(theme.warnings, isEmpty);
            PlaceholderNode node(ThemeElementSpec e) => PlaceholderNode(
              id: e.partKey,
              placeholderType: e.placeholderType,
              placeholderOf: e.placeholderOf,
              x: e.frame.x,
              y: e.frame.y,
              width: e.frame.width,
              height: e.frame.height,
              textStyle: e.textStyle,
              fill: e.fill?.toJson(),
              data: e.data,
            );
            final resolver = PlaceholderResolver(
              lookup: (id) => parts[id] == null ? null : node(parts[id]!),
              slideBounds: pkg.size.bounds,
            );
            for (final l in master.layouts) {
              for (final p in l.placeholders) {
                final instance = PlaceholderNode(
                  id: 'slide/${p.partKey}',
                  placeholderType: p.placeholderType,
                  placeholderOf: p.partKey,
                );
                final e = resolver.resolve(instance);
                expect(e.dangling, isFalse);
                expect(
                  pkg.size.bounds.containsRect(e.frame),
                  isTrue,
                  reason: p.partKey,
                );
                if (p.placeholderType!.holdsText) {
                  expect(
                    themeTextStyleKeys,
                    contains(e.styleKey),
                    reason: p.partKey,
                  );
                  final style = theme.textStyle(e.styleKey);
                  expect(style.font.isFallback, isFalse);
                  final color = e.textStyle.defaults['color'] as String?;
                  if (color != null) {
                    expect(ColorRef.tryParse(color), isNotNull);
                  }
                }
              }
              final bg = l.background;
              if (bg != null) {
                expect(theme.background(bg).fill, isNot(isA<ResolvedNoFill>()));
              }
            }
          },
        );
      }

      test(
        'when encoding every element then its JSON columns parse cleanly',
        () {
          for (final e in parts.values) {
            final sink = IssueSink();
            final cols = e.toColumns();
            if (cols['textStyleJson'] != null) {
              BoxTextStyle.fromJson(
                jsonDecode(cols['textStyleJson']! as String),
                'textStyleJson',
                sink,
              );
            }
            if (cols['fillJson'] != null) {
              SlideFill.fromJson(
                jsonDecode(cols['fillJson']! as String),
                'fillJson',
                sink,
              );
            }
            if (cols['strokeJson'] != null) {
              SlideStroke.fromJson(
                jsonDecode(cols['strokeJson']! as String),
                'strokeJson',
                sink,
              );
            }
            expect(sink.issues, isEmpty, reason: e.partKey);
            if (e.isPlaceholder && e.placeholderType!.isInstantiated) {
              expect(e.promptText, isNotEmpty, reason: e.partKey);
            }
          }
        },
      );

      test(
        'when encoding the package as JSON then it decodes to the same JSON',
        () {
          final json = jsonDecode(jsonEncode(pkg.toJson()));
          final r = ThemePackage.fromJson(json);
          expect(r.errors, isEmpty);
          expect(r.warnings, isEmpty);
          expect(jsonEquals(r.package!.toJson(), pkg.toJson()), isTrue);
        },
      );
    });
  }

  group('Given a 4:3 deck', () {
    final size = SlideSize.preset(SlideSizeKind.standard4x3);

    test('when building Wonky then layouts are regenerated for the aspect', () {
      final pkg = BuiltInThemes.package('wonky', size: size)!;
      final body = pkg.masters.single.layout('titleBody')!.placeholders[1];
      expect(body.frame, const SuRect(120, 264, 1200, 720));
      expect(pkg.size, size);
      expect(
        pkg.theme.textStyles['title'].size,
        96,
        reason: 'font sizes keep their meaning',
      );
    });
  });

  group('Given a large custom deck', () {
    test('when building then text styles scale with the size unit', () {
      final pkg = BuiltInThemes.package(
        'wonky',
        size: SlideSize.custom(3840, 2160),
      )!;
      expect(pkg.theme.textStyles['body'].size, 80);
    });
  });

  group('Given Studio and Classic band layouts', () {
    test('when reading Studio sections then text sits on accent1 in bg1', () {
      final l = BuiltInThemes.package(
        'studio',
      )!.masters.single.layout('section')!;
      expect(l.background!.fill, const SolidFill(ThemeColor('accent1')));
      expect(
        l.placeholders.every(
          (p) => p.textStyle!.defaults['color'] == 'theme:bg1',
        ),
        isTrue,
      );
    });

    for (final key in ['studio', 'classic']) {
      for (final appearance in SlideAppearance.values) {
        test(
          'when checking $key ${appearance.name} band text then it reaches 4.5:1',
          () {
            final theme = BuiltInThemes.package(key)!.theme;
            final scheme = theme.colors.scheme(appearance);
            expect(
              ThemeContrast.ratio(scheme.bg1, scheme.accent(1)),
              greaterThanOrEqualTo(3),
            );
          },
        );
      }
    }
  });

  group('Given an invalid theme package', () {
    test('when parts are duplicated then it is refused', () {
      final json = BuiltInThemes.package('mono')!.toJson();
      final masters = json['masters']! as List;
      final m = masters.first as Map<String, Object?>;
      final layouts = m['layouts']! as List;
      layouts.add(layouts.first);
      final r = ThemePackage.fromJson(jsonDecode(jsonEncode(json)));
      expect(r.package, isNull);
      expect(r.errors.map((e) => e.code), contains('duplicate_part'));
    });

    test('when the theme is missing then it is refused', () {
      final r = ThemePackage.fromJson({'v': 1, 'masters': <Object?>[]});
      expect(r.package, isNull);
    });
  });
}
