#!/usr/bin/env python3
"""Generates packages/wonky_app/assets/unicode/special_chars.json (Write 04 §20.2,
the shared special characters dialog of `package:wonky_app/special_chars.dart`).

Source: the Unicode Character Database as shipped in Python's `unicodedata`
module (offline; the UCD version is recorded in the output). Unicode data is
under the Unicode License v3 (https://www.unicode.org/license.txt).

Usage (from wonky_write/):

    python3 -I tool/unicode/gen_special_chars.py

Unicode blocks are mapped to the dialog's categories below. Unassigned,
control, surrogate, private-use and combining-only code points are skipped.
Output format (see lib/features/special_chars/special_chars_catalog.dart):

    {"unicode": "16.0.0", "categories": ["Punctuation", ...],
     "chars": [[codePoint, "UNICODE NAME", categoryIndex], ...]}

A code point is listed once, in the first category that claims it.
"""

import argparse
import json
import os
import unicodedata

CATEGORIES = [
    'Punctuation', 'Arrows', 'Math', 'Currency', 'Latin', 'Greek',
    'Cyrillic', 'Symbols', 'Technical', 'Box drawing',
]

P, A, M, C, L, G, CY, S, T, B = range(10)


def gc(cp):
    return unicodedata.category(chr(cp))


def name(cp):
    return unicodedata.name(chr(cp), '')


# (first, last, category, predicate or None). Order matters: the first rule
# that accepts a code point wins.
RULES = [
    # Currency first so ¢ £ ¥ and the Currency Symbols block land there.
    (0x0024, 0x0024, C, None),
    (0x00A0, 0x00FF, C, lambda cp: gc(cp) == 'Sc'),
    (0x20A0, 0x20CF, C, None),
    # Math before letterlike/Latin-1 so ± × ÷ ¬ ℘ ⅀ are math.
    (0x00A0, 0x00FF, M, lambda cp: gc(cp) == 'Sm'),
    (0x2100, 0x214F, M, lambda cp: gc(cp) == 'Sm'),
    (0x2200, 0x22FF, M, None),
    (0x27C0, 0x27EF, M, None),
    (0x2980, 0x29FF, M, None),
    (0x2A00, 0x2AFF, M, None),
    (0x1D400, 0x1D7FF, M, None),  # Mathematical Alphanumeric Symbols
    # Arrows.
    (0x2190, 0x21FF, A, None),
    (0x27F0, 0x27FF, A, None),
    (0x2900, 0x297F, A, None),
    (0x2B00, 0x2BFF, A, lambda cp: 'ARROW' in name(cp)),
    (0x1F800, 0x1F8FF, A, None),
    # Punctuation.
    (0x00A0, 0x00BF, P, lambda cp: gc(cp)[0] in 'PZ' or cp == 0x00AD),
    (0x2000, 0x206F, P, None),
    (0x2E00, 0x2E7F, P, None),
    # Latin.
    (0x00C0, 0x00FF, L, lambda cp: gc(cp)[0] == 'L'),
    (0x0100, 0x017F, L, None),
    (0x0180, 0x024F, L, None),
    (0x0250, 0x02AF, L, None),
    (0x1E00, 0x1EFF, L, None),
    (0x2C60, 0x2C7F, L, None),
    (0xA720, 0xA7FF, L, None),
    (0x02B0, 0x02FF, L, None),  # Spacing Modifier Letters
    (0x1D00, 0x1DBF, L, None),  # Phonetic Extensions (+ Supplement)
    (0xAB30, 0xAB6F, L, None),  # Latin Extended-E
    (0xFB00, 0xFB06, L, None),  # Latin ligatures
    # Greek.
    (0x0370, 0x03FF, G, None),
    (0x1F00, 0x1FFF, G, None),
    # Cyrillic.
    (0x0400, 0x04FF, CY, None),
    (0x0500, 0x052F, CY, None),
    (0xA640, 0xA69F, CY, None),  # Cyrillic Extended-B
    (0x1C80, 0x1C8F, CY, None),  # Cyrillic Extended-C
    # Box drawing (before Symbols: block elements are in 2580..259F).
    (0x2500, 0x257F, B, None),
    (0x2580, 0x259F, B, None),
    # Technical.
    (0x2300, 0x23FF, T, None),
    (0x2400, 0x243F, T, None),
    (0x2440, 0x245F, T, None),
    # Symbols.
    (0x00A0, 0x00BF, S, None),
    (0x2070, 0x209F, S, None),
    (0x2100, 0x214F, S, None),
    (0x2150, 0x218F, S, None),
    (0x2460, 0x24FF, S, None),
    (0x25A0, 0x25FF, S, None),
    (0x2600, 0x26FF, S, None),
    (0x2700, 0x27BF, S, None),
    (0x2B00, 0x2BFF, S, None),
    (0x1F100, 0x1F1E5, S, None),  # Enclosed Alphanumeric Supplement
    (0x1F650, 0x1F67F, S, None),  # Ornamental Dingbats
    (0x1F780, 0x1F7FF, S, None),  # Geometric Shapes Extended
]

SKIP_GC = {'Cn', 'Cc', 'Co', 'Cs', 'Mn', 'Mc', 'Me'}
# Invisible format characters worth offering in a word processor.
KEEP_CF = {0x00AD, 0x200B, 0x200C, 0x200D, 0x200E, 0x200F, 0x2060}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument(
        '--out',
        default=os.path.join(
            os.path.dirname(__file__), '..', '..', '..', 'packages',
            'wonky_app', 'assets', 'unicode', 'special_chars.json'),
    )
    args = ap.parse_args()

    seen = set()
    chars = []
    for first, last, cat, pred in RULES:
        for cp in range(first, last + 1):
            if cp in seen:
                continue
            g = gc(cp)
            if g in SKIP_GC or (g == 'Cf' and cp not in KEEP_CF):
                continue
            n = name(cp)
            if not n:
                continue
            if pred is not None and not pred(cp):
                continue
            seen.add(cp)
            chars.append([cp, n, cat])
    chars.sort(key=lambda r: (r[2], r[0]))

    out = {
        'unicode': unicodedata.unidata_version,
        'categories': CATEGORIES,
        'chars': chars,
    }
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, separators=(',', ':'))
        f.write('\n')
    counts = [0] * len(CATEGORIES)
    for _, _, c in chars:
        counts[c] += 1
    print(f'{len(chars)} characters, {os.path.getsize(args.out)} bytes')
    for c, n in zip(CATEGORIES, counts):
        print(f'  {c}: {n}')


if __name__ == '__main__':
    main()
