import 'dart:convert';

import 'package:wonky_write/features/special_chars/special_chars_catalog.dart';

/// A small table in the asset format of `assets/unicode/special_chars.json`.
final specialCharsFixtureJson = jsonEncode({
  'unicode': '16.0.0',
  'categories': ['Punctuation', 'Arrows', 'Latin'],
  'chars': [
    [0x2014, 'EM DASH', 0],
    [0x2026, 'HORIZONTAL ELLIPSIS', 0],
    [0x200B, 'ZERO WIDTH SPACE', 0],
    [0x2190, 'LEFTWARDS ARROW', 1],
    [0x2192, 'RIGHTWARDS ARROW', 1],
    [0x21D2, 'RIGHTWARDS DOUBLE ARROW', 1],
    [0x2933, 'WAVE ARROW POINTING DIRECTLY RIGHT', 1],
    [0x00C9, 'LATIN CAPITAL LETTER E WITH ACUTE', 2],
    [0x00E9, 'LATIN SMALL LETTER E WITH ACUTE', 2],
  ],
});

SpecialCharsCatalog specialCharsFixture() =>
    SpecialCharsCatalog.fromJson(specialCharsFixtureJson);
