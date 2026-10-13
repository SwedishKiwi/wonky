#!/usr/bin/env python3
"""Generates wonky_write/assets/emoji/emoji.json (Write 04 §20.1).

Source: emojibase-data (MIT, https://emojibase.dev, npm `emojibase-data`),
files en/data.json, en/messages.json, en/shortcodes/emojibase.json and
en/shortcodes/cldr.json, fetched from the jsDelivr npm CDN. Only emoji with
Unicode emoji version <= 15.1 are kept; the "component" group (skin tone and
hair swatches) and the bare regional indicators are dropped.

Usage (from wonky_write/):

    python3 -I tool/unicode/gen_emoji.py --cache <empty-or-cache-dir>

Downloads land in --cache (re-used when present). The output format is
documented in lib/features/emoji/emoji_catalog.dart:

    {"version": "15.1", "source": ...,
     "categories": [{"id", "name", "icon"}],
     "emoji": [[char, name, [keywords], category, [shortcodes], skin]]}

`skin` is 0 (no skin tones), 1 (tone N is derived by inserting the modifier
U+1F3FA+N after the first code point and dropping a VS16 that follows it) or a
list of the five explicit variants (ZWJ sequences like "people holding hands"
where the modifier goes on several code points).
"""

import argparse
import json
import os
import re
import urllib.request

EMOJIBASE_VERSION = '16.0.3'
MAX_EMOJI_VERSION = 15.1
BASE = f'https://cdn.jsdelivr.net/npm/emojibase-data@{EMOJIBASE_VERSION}/'
FILES = {
    'data': 'en/data.json',
    'messages': 'en/messages.json',
    'sc_emojibase': 'en/shortcodes/emojibase.json',
    'sc_cldr': 'en/shortcodes/cldr.json',
}

# emojibase group key -> (our id, display name, tab icon)
CATEGORIES = [
    ('smileys-emotion', 'smileys', 'Smileys & emotion', '\U0001F600'),
    ('people-body', 'people', 'People & body', '\U0001F44B'),
    ('animals-nature', 'animals', 'Animals & nature', '\U0001F43B'),
    ('food-drink', 'food', 'Food & drink', '\U0001F354'),
    ('travel-places', 'travel', 'Travel & places', '\U0001F697'),
    ('activities', 'activities', 'Activities', '⚽'),
    ('objects', 'objects', 'Objects', '\U0001F4A1'),
    ('symbols', 'symbols', 'Symbols', '\U0001F523'),
    ('flags', 'flags', 'Flags', '\U0001F3C1'),
]

VS16 = '️'


def fetch(cache, name):
    path = os.path.join(cache, name.replace('/', '_'))
    if not os.path.exists(path):
        with urllib.request.urlopen(BASE + name) as r, open(path, 'wb') as f:
            f.write(r.read())
    with open(path, encoding='utf-8') as f:
        return json.load(f)


def derive(char, tone):
    """Inserts skin tone modifier [tone] (1..5) after the first code point."""
    mod = chr(0x1F3FA + tone)
    rest = char[1:]
    if rest.startswith(VS16):
        rest = rest[1:]
    return char[0] + mod + rest


def normalizer(data):
    """Drops VS16 after code points that already default to emoji
    presentation (emojibase adds it to e.g. U+1F44D), keeping it where it is
    needed: after text-default code points and in keycap sequences."""
    text_default = {
        int(e['hexcode'], 16)
        for e in data
        if '-' not in e['hexcode'] and e.get('type') == 0
    }

    def normalize(s):
        out = []
        for i, ch in enumerate(s):
            if ch == VS16 and out:
                prev = ord(out[-1])
                nxt = s[i + 1] if i + 1 < len(s) else ''
                if not (prev in text_default or prev < 0x80 or
                        nxt == '\u20E3'):
                    continue
            out.append(ch)
        return ''.join(out)

    return normalize


def as_list(v):
    if v is None:
        return []
    return v if isinstance(v, list) else [v]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--cache', required=True)
    ap.add_argument(
        '--out',
        default=os.path.join(
            os.path.dirname(__file__), '..', '..', 'assets', 'emoji',
            'emoji.json'),
    )
    args = ap.parse_args()
    os.makedirs(args.cache, exist_ok=True)

    data = fetch(args.cache, FILES['data'])
    messages = fetch(args.cache, FILES['messages'])
    sc_eb = fetch(args.cache, FILES['sc_emojibase'])
    sc_cldr = fetch(args.cache, FILES['sc_cldr'])

    group_order = {g['order']: g['key'] for g in messages['groups']}
    cat_index = {key: i for i, (key, _, _, _) in enumerate(CATEGORIES)}

    normalize = normalizer(data)
    rows = []
    derived = explicit = 0
    for e in sorted(data, key=lambda e: e.get('order', 1 << 30)):
        group = e.get('group')
        if group is None:
            continue  # regional indicators
        key = group_order[group]
        if key not in cat_index:
            continue  # component
        if e.get('version', 0) > MAX_EMOJI_VERSION:
            continue
        char = normalize(e['emoji'])
        name = e['label']
        name_words = set(re.findall(r"[\w']+", name.lower()))
        keywords = [t for t in e.get('tags', []) if t.lower() not in name_words]
        codes = []
        for c in as_list(sc_eb.get(e['hexcode'])) + as_list(
                sc_cldr.get(e['hexcode'])):
            if c not in codes:
                codes.append(c)
        skin = 0
        skins = [s for s in e.get('skins', [])
                 if s.get('version', 0) <= MAX_EMOJI_VERSION]
        uniform = {}
        for s in skins:
            t = s.get('tone')
            if isinstance(t, int):
                uniform[t] = normalize(s['emoji'])
            elif isinstance(t, list) and len(set(t)) == 1:
                uniform.setdefault(t[0], normalize(s['emoji']))
        if all(t in uniform for t in range(1, 6)):
            variants = [uniform[t] for t in range(1, 6)]
            if all(derive(char, t) == variants[t - 1] for t in range(1, 6)):
                skin = 1
                derived += 1
            else:
                skin = variants
                explicit += 1
        rows.append([char, name, keywords, cat_index[key], codes, skin])

    out = {
        'version': str(MAX_EMOJI_VERSION),
        'source': f'emojibase-data {EMOJIBASE_VERSION} (MIT)',
        'categories': [
            {'id': cid, 'name': n, 'icon': icon}
            for _, cid, n, icon in CATEGORIES
        ],
        'emoji': rows,
    }
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, separators=(',', ':'))
        f.write('\n')
    size = os.path.getsize(args.out)
    print(f'{len(rows)} emoji ({derived} derived + {explicit} explicit '
          f'skin-tone sets), {size} bytes -> {os.path.abspath(args.out)}')


if __name__ == '__main__':
    main()
