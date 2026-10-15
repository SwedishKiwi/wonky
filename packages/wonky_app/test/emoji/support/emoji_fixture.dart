import 'dart:convert';

import 'package:wonky_app/emoji.dart';

/// A small catalog in the asset format of `assets/emoji/emoji.json`.
final emojiFixtureJson = jsonEncode({
  'version': '15.1',
  'categories': [
    {'id': 'smileys', 'name': 'Smileys & emotion', 'icon': '😀'},
    {'id': 'people', 'name': 'People & body', 'icon': '👋'},
    {'id': 'symbols', 'name': 'Symbols', 'icon': '🔣'},
  ],
  'emoji': [
    [
      '😀',
      'grinning face',
      ['grin', 'smile'],
      0,
      ['grinning', 'grinning_face'],
      0,
    ],
    [
      '😄',
      'grinning face with smiling eyes',
      ['smile', 'happy'],
      0,
      ['smile', 'grinning_face_with_smiling_eyes'],
      0,
    ],
    [
      '🙂',
      'slightly smiling face',
      ['smile'],
      0,
      ['slightly_smiling_face'],
      0,
    ],
    [
      '👋',
      'waving hand',
      ['hello', 'wave'],
      1,
      ['wave', 'waving_hand'],
      1,
    ],
    [
      '\u{1F3CB}️',
      'person lifting weights',
      ['gym'],
      1,
      ['weight_lifter'],
      1,
    ],
    [
      '🧑‍🤝‍🧑',
      'people holding hands',
      ['friends'],
      1,
      ['people_holding_hands'],
      [
        '🧑🏻‍🤝‍🧑🏻',
        '🧑🏼‍🤝‍🧑🏼',
        '🧑🏽‍🤝‍🧑🏽',
        '🧑🏾‍🤝‍🧑🏾',
        '🧑🏿‍🤝‍🧑🏿',
      ],
    ],
    [
      '\u{1F9D4}‍♂️',
      'man: beard',
      ['whiskers'],
      1,
      ['man_beard'],
      1,
    ],
    [
      '👍',
      'thumbs up',
      ['+1', 'good', 'like', 'yes'],
      1,
      ['thumbsup', '+1', 'thumbs_up'],
      1,
    ],
    [
      '❤️',
      'red heart',
      ['love'],
      2,
      ['heart', 'red_heart'],
      0,
    ],
  ],
});

EmojiCatalog emojiFixture() => EmojiCatalog.fromJson(emojiFixtureJson);
