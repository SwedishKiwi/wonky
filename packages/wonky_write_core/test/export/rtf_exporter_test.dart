import 'dart:convert';

import 'package:image/image.dart' as img;
import 'package:test/test.dart';
import 'package:wonky_write_core/wonky_write_core.dart';

import 'export_support.dart';

/// `\uN?` for code unit [n] (signed 16-bit).
String u(int n) => '\\u${n > 0x7FFF ? n - 0x10000 : n}?';

Future<String> rtf(
  String markdown, {
  Map<String, ResolvedImage> images = const {},
  PageSetup pageSetup = const PageSetup(),
  ThemeVariant variant = ThemeVariant.light,
  String theme = 'wonky-default',
}) async {
  final a = await const RtfExporter().export(
    input(
      md(markdown),
      images: images,
      pageSetup: pageSetup,
      variant: variant,
      theme: theme,
    ),
    const RtfExportOptions(),
  );
  return ascii.decode(a.bytes);
}

/// Whether the groups of [rtf] are balanced.
bool balanced(String rtf) {
  var depth = 0;
  for (final t in RtfTokenizer(ascii.encode(rtf)).tokenize()) {
    if (t is RtfGroupStart) depth++;
    if (t is RtfGroupEnd && --depth < 0) return false;
  }
  return depth == 0;
}

void main() {
  final logo = ResolvedImage(
    bytes: pngBytes(),
    mime: 'image/png',
    widthPx: 4,
    heightPx: 2,
  );
  final images = {'https://img.example.com/logo.png': logo};

  group('Given the sample document', () {
    late String out;
    setUp(() async => out = await rtf(sample, images: images));

    test('when exporting then the header and the font, color and style '
        'tables are written', () {
      expect(out, startsWith(r'{\rtf1\ansi\ansicpg1252\deff0\uc1'));
      expect(out, contains(r'{\fonttbl{\f0\fswiss\fcharset0\fprq2 Inter;}'));
      expect(out, contains(r'\fmodern\fcharset0\fprq1 JetBrains Mono;}'));
      expect(out, contains(r'{\colortbl;\red'));
      expect(out, contains(r'{\stylesheet'));
      expect(out, contains(r'\snext0 Normal;}'));
      expect(
        out,
        matches(RegExp(r'\{\\s1\\ql\\keepn\\outlinelevel0[^}]*heading 1;\}')),
      );
      expect(out, contains(r'\outlinelevel5'));
      expect(out, contains(r'Quote;}'));
      expect(out, contains(r'Code Block;}'));
      expect(out, contains(r'{\*\cs16\additive '));
      expect(out, contains(r'Hyperlink;}'));
      expect(out, endsWith('}\n'));
      expect(balanced(out), isTrue);
    });

    test('when exporting then metadata and page geometry are written', () {
      expect(
        out,
        contains(
          r'{\info{\title Q3 planning}{\author Anna}'
          r'{\creatim\yr2026\mo10\dy1\hr12\min0}',
        ),
      );
      expect(out, contains(r'\paperw12240\paperh15840\margl1440'));
      expect(out, contains(r'\headery720\footery720\pgnstarts1\pgndec'));
    });

    test('when exporting then the list table has 9-level bullets and '
        'numbers', () {
      expect(out, contains(r'{\*\listtable'));
      expect(RegExp(r'\\levelnfc23\\').allMatches(out).length, 9);
      expect(out, contains("{\\leveltext\\'02\\'00.;}{\\levelnumbers\\'01;}"));
      expect(out, contains(r'\levelnfc4\levelnfcn4'));
      expect(out, contains(r'\levelnfc2\levelnfcn2'));
      expect(out, contains(r'{\*\listoverridetable'));
      expect(out, contains('{\\listtext\\pard\\plain\\f0\\fs22\\cf1 1.\\tab}'));
    });

    test('when exporting then tasks start with a glyph and a tab', () {
      expect(out, contains('${u(0x2612)}\\tab{\\strike done}'));
      expect(out, contains('${u(0x2610)}\\tab todo'));
    });

    test('when exporting then links are HYPERLINK fields', () {
      expect(
        out,
        contains(
          r'{\field{\*\fldinst HYPERLINK "https://example.com"}'
          r'{\fldrslt {\cs17',
        ),
      );
    });

    test('when exporting then the image is a hex PNG picture with its '
        'caption', () {
      expect(out, contains(r'\pngblip\picw4\pich2\picwgoal60\pichgoal30'));
      expect(out, contains('89504e470d0a1a0a'));
      expect(out, contains(r'{\sv Logo}'));
      expect(out, contains(r'\s9'));
      expect(out, contains(' The logo'));
    });

    test('when exporting then the table has a repeated header row and '
        'aligned cells', () {
      expect(out, contains(r'\trowd\trgaph108\trleft0\trhdr'));
      expect(RegExp(r'\\row\n').allMatches(out).length, 2);
      expect(RegExp(r'\\cellx').allMatches(out).length, 4);
      expect(out, contains(r'\intbl\s12\qr'));
      expect(out, contains(r' Value\cell'));
    });

    test('when exporting then code lines carry token colors', () {
      expect(out, contains(r'{\*\wonkycodelang dart}{\cf'));
    });

    test('when exporting then the default header and footer have the '
        'title and a PAGE field', () {
      expect(out, contains(r'{\header\pard\plain\s14'));
      expect(out, contains(r'\tab\tab Q3 planning\par}'));
      expect(out, contains(r'{\footer\pard\plain\s15'));
      expect(out, contains(r'{\field{\*\fldinst PAGE}{\fldrslt 1}}'));
    });

    test('when exporting twice then the bytes are identical', () async {
      final again = await rtf(sample, images: images);

      expect(again, out);
    });
  });

  group('Given text with special characters', () {
    test('when exporting then it is escaped to ASCII', () async {
      final out = await rtf('Café {x} \\\\y 😀\n\n```\n\tz\n```');

      expect(
        out,
        contains('Caf${u(0xE9)} \\{x\\} \\\\y ${u(0xD83D)}${u(0xDE00)}\\par'),
      );
      expect(out, contains('\\tab z'));
      expect(out.codeUnits.every((c) => c < 0x80), isTrue);
    });
  });

  group('Given two separate ordered lists', () {
    test('when exporting then each gets its own restarting override', () async {
      final out = await rtf('1. a\n2. b\n\npara\n\n1. c');

      expect(out, contains(r'\ls1\ilvl0'));
      expect(out, contains(r'\ls2\ilvl0'));
      expect(
        RegExp(
          r'\\listoverride\\listid2\\listoverridecount9',
        ).allMatches(out).length,
        2,
      );
    });
  });

  group('Given a page setup', () {
    test('when it is landscape A4 with a roman first-page footer then the '
        'section has the geometry, title page and fields', () async {
      final out = await rtf(
        'Hello',
        pageSetup: const PageSetup(
          paper: PaperSize.a4,
          orientation: PageOrientation.landscape,
          margins: PageMargins.all(36),
          header: HeaderFooterSpec(center: '{page} / {pages}'),
          differentFirstPage: true,
          firstPageFooter: HeaderFooterSpec(right: '{title}'),
          pageNumberStart: 3,
          pageNumberFormat: PageNumberFormat.lowerRoman,
        ),
      );

      expect(out, contains(r'\paperw16838\paperh11906\margl720'));
      expect(out, contains(r'\landscape'));
      expect(out, contains(r'\titlepg\pgnstarts3\pgnrestart\pgnlcrm'));
      expect(
        out,
        contains(
          r'\tab{\field{\*\fldinst PAGE \\* roman}{\fldrslt iii}} / '
          r'{\field{\*\fldinst NUMPAGES}{\fldrslt 1}}\tab\par}',
        ),
      );
      expect(out, contains(r'{\footerf'));
      expect(out, contains(r'\tab\tab Q3 planning\par}'));
    });
  });

  group('Given images', () {
    test('when the image is a JPEG then it is a jpegblip', () async {
      final jpeg = img.encodeJpg(img.Image(width: 8, height: 8));
      final out = await rtf(
        '![Photo](https://x.org/p.jpg)',
        images: {
          'https://x.org/p.jpg': ResolvedImage(
            bytes: jpeg,
            mime: 'image/jpeg',
            widthPx: 8,
            heightPx: 8,
          ),
        },
      );

      expect(out, contains(r'\jpegblip\picw8\pich8\picwgoal120\pichgoal120'));
      expect(out, contains('ffd8ff'));
    });

    test('when the image is missing then a placeholder and a warning are '
        'produced', () async {
      final a = await const RtfExporter().export(
        input(md('![Logo](https://img.example.com/missing.png)')),
        const RtfExportOptions(),
      );

      expect(ascii.decode(a.bytes), contains('[Image: Logo]'));
      expect(a.warnings.map((w) => w.code), ['image_unavailable']);
    });
  });

  group('Given the dark variant', () {
    test('when exporting then light colors are used and a warning is '
        'added', () async {
      final light = await rtf(sample, images: images);
      final a = await const RtfExporter().export(
        input(md(sample), images: images, variant: ThemeVariant.dark),
        const RtfExportOptions(),
      );

      expect(ascii.decode(a.bytes), light);
      expect(a.warnings.map((w) => w.code), ['variant_unsupported']);
      expect(a.fileName, 'Q3 planning.rtf');
      expect(a.mimeType, 'application/rtf');
    });
  });

  group('Given every built-in theme', () {
    for (final theme in BuiltinThemes.all) {
      test('when exporting the sample with ${theme.key} then balanced ASCII '
          'RTF is produced that imports back', () async {
        final out = await rtf(sample, images: images, theme: theme.key);

        final r = const RtfImporter().importSync(
          ascii.encode(out),
          ImportOptions(idGenerator: () => 'id'),
        );
        expect(balanced(out), isTrue);
        expect(out.codeUnits.every((c) => c < 0x80), isTrue);
        expect(
          r.delta.toJson().map((o) => o['insert']),
          containsAll(['Intro with ', 'bold', 'First']),
        );
        expect(r.images, hasLength(1));
      });
    }

    test('when the theme numbers headings then the label is a text '
        'prefix', () async {
      final out = await rtf(sample, theme: 'technical');

      expect(out, contains(r'\outlinelevel0'));
      expect(out, contains(' 1 Q3 planning'));
    });
  });
}
