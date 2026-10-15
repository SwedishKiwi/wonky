/// The Lucide icon set of `icon` elements (Slides 02 §6.6, 03 §6.7): the
/// name → glyph map shared by the app's icon font source, the icon picker,
/// MCP and the PDF painter, and the picker's catalog (unique glyphs,
/// aliases, categories, search).
library;

import 'dart:math' as math;

part 'lucide_glyphs.g.dart';

/// Name → code point of the Lucide icon fonts (`lucide_icons_flutter`).
///
/// The fonts come in stroke weights: [fontFamilyFor] maps an icon's
/// `strokeWidth` (02 §6.6, 1–3) to the family whose outlines were drawn
/// with that stroke (`Lucide200` = 1, `Lucide300` = 1.5, `Lucide400` = 2,
/// `Lucide500` = 2.5, `Lucide600` = 3). Every family has the same code
/// points.
abstract final class LucideGlyphs {
  /// The stroke widths offered by the picker (04 §13.6).
  static const strokeWidths = <double>[1, 1.5, 2, 2.5, 3];

  /// The default stroke width.
  static const defaultStrokeWidth = 2.0;

  /// The font asset package of the families.
  static const fontPackage = 'lucide_icons_flutter';

  /// The code point of icon [name] (any alias), or null.
  static int? codePoint(String name) => _lucideCodePoints[name];

  /// Whether [name] is a Lucide icon.
  static bool contains(String name) => _lucideCodePoints.containsKey(name);

  /// Every name (aliases included), sorted.
  static Iterable<String> get names => _lucideCodePoints.keys;

  /// The glyph text of [name] (one UTF-16 code unit), or null.
  static String? glyph(String name) {
    final cp = codePoint(name);
    return cp == null ? null : String.fromCharCode(cp);
  }

  /// [width] snapped to the nearest offered stroke width.
  static double snapStrokeWidth(num? width) {
    final w = (width ?? defaultStrokeWidth).toDouble();
    if (!w.isFinite) return defaultStrokeWidth;
    var best = strokeWidths.first;
    for (final s in strokeWidths) {
      if ((s - w).abs() < (best - w).abs()) best = s;
    }
    return best;
  }

  /// The font family (without the package prefix) drawing [strokeWidth].
  static String fontFamilyFor(num? strokeWidth) =>
      switch (snapStrokeWidth(strokeWidth)) {
        1 => 'Lucide200',
        1.5 => 'Lucide300',
        2.5 => 'Lucide500',
        3 => 'Lucide600',
        _ => 'Lucide400',
      };

  /// The Flutter asset family (`packages/lucide_icons_flutter/Lucide400`).
  static String assetFamilyFor(num? strokeWidth) =>
      'packages/$fontPackage/${fontFamilyFor(strokeWidth)}';
}

/// Categories of the icon picker's sidebar (04 §13.6). Lucide's own tag
/// data is not shipped with the font package, so categories come from name
/// keywords ([LucideCatalog]).
enum LucideCategory {
  arrows,
  business,
  charts,
  communication,
  devices,
  development,
  files,
  food,
  media,
  nature,
  people,
  security,
  shapes,
  text,
  time,
  tools,
  travel,
  weather,
}

/// One glyph of the catalog: its display [name], the other names of the
/// same glyph ([aliases]) and its categories.
final class LucideIcon {
  const LucideIcon(this.name, this.codePoint, this.aliases, this.categories);

  /// The name stored in new elements (`dataJson.name`).
  final String name;
  final int codePoint;

  /// Other names of the same glyph (renamed icons keep their old names).
  final List<String> aliases;
  final Set<LucideCategory> categories;

  /// The words of the name ("arrow-up-right" → arrow, up, right).
  List<String> get words => name.split('-');

  /// "Arrow up right" (picker tooltips, MCP).
  String get label {
    final w = name.replaceAll('-', ' ');
    return w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}';
  }

  @override
  String toString() => 'LucideIcon($name)';
}

/// The icon picker's catalog (04 §13.6): one entry per glyph (~1,900),
/// keyword categories and a ranked [search] over names, aliases, category
/// names and common synonyms.
abstract final class LucideCatalog {
  /// Every glyph, sorted by name.
  static final List<LucideIcon> icons = _build();

  static final Map<String, LucideIcon> _byName = {
    for (final i in icons) ...{i.name: i, for (final a in i.aliases) a: i},
  };

  /// The catalog entry of [name] (any alias), or null.
  static LucideIcon? of(String name) => _byName[name];

  /// The icons of [category].
  static List<LucideIcon> inCategory(LucideCategory category) => [
    for (final i in icons)
      if (i.categories.contains(category)) i,
  ];

  /// Icons matching [query] (best first; all icons for a blank query),
  /// optionally limited to [category]. Every word of the query must match
  /// (a prefix of a name word, part of the name, an alias, a category or a
  /// synonym).
  static List<LucideIcon> search(String query, {LucideCategory? category}) {
    final pool = category == null ? icons : inCategory(category);
    final words = query
        .toLowerCase()
        .split(RegExp(r'[\s,]+'))
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return pool;
    final scored = <(LucideIcon, int)>[];
    for (final icon in pool) {
      var total = 0;
      for (final w in words) {
        final s = _score(icon, w);
        if (s == 0) {
          total = 0;
          break;
        }
        total += s;
      }
      if (total > 0) scored.add((icon, total));
    }
    scored.sort((a, b) {
      final c = b.$2.compareTo(a.$2);
      if (c != 0) return c;
      final l = a.$1.name.length.compareTo(b.$1.name.length);
      return l != 0 ? l : a.$1.name.compareTo(b.$1.name);
    });
    return [for (final s in scored) s.$1];
  }

  static int _score(LucideIcon icon, String w) {
    final q = w.replaceAll(' ', '-');
    if (icon.name == q) return 100;
    if (icon.aliases.contains(q)) return 90;
    if (icon.name.startsWith(q)) return 70;
    var best = 0;
    for (final word in icon.words) {
      if (word == q) best = math.max(best, 60);
      if (word.startsWith(q)) best = math.max(best, 50);
    }
    if (best == 0 && q.length >= 3 && icon.name.contains(q)) best = 30;
    for (final a in icon.aliases) {
      if (best >= 40) break;
      if (a.split('-').any((x) => x.startsWith(q))) best = 40;
    }
    final syn = _synonyms[q];
    if (best == 0 && syn != null) {
      if (icon.words.any(syn.contains)) best = 25;
    }
    if (best == 0) {
      for (final c in icon.categories) {
        if (c.name.startsWith(q)) {
          best = 10;
          break;
        }
      }
    }
    return best;
  }

  static List<LucideIcon> _build() {
    final byCode = <int, List<String>>{};
    for (final MapEntry(:key, :value) in _lucideCodePoints.entries) {
      (byCode[value] ??= []).add(key);
    }
    final out = <LucideIcon>[];
    for (final MapEntry(key: cp, value: names) in byCode.entries) {
      names.sort();
      // Renamed icons keep their old names as aliases; the newer names put
      // the base shape first (`circle-alert` for `alert-circle`) and are
      // usually listed last alphabetically among Lucide's renames.
      final name = names.last;
      final aliases = [
        for (final n in names)
          if (n != name) n,
      ];
      final words = {for (final n in names) ...n.split('-')};
      out.add(LucideIcon(name, cp, aliases, _categoriesOf(words)));
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return List.unmodifiable(out);
  }

  static Set<LucideCategory> _categoriesOf(Set<String> words) => {
    for (final MapEntry(:key, :value) in _keywords.entries)
      if (words.any(value.contains)) key,
  };

  /// Name words per category.
  static const Map<LucideCategory, List<String>> _keywords = {
    LucideCategory.arrows: [
      'arrow', 'arrows', 'chevron', 'chevrons', 'move', 'corner', 'undo', //
      'redo', 'refresh', 'rotate', 'repeat', 'shuffle', 'iteration',
      'forward', 'reply', 'redo', 'expand', 'shrink', 'maximize',
      'minimize', 'trending', 'merge', 'split',
    ],
    LucideCategory.business: [
      'briefcase', 'building', 'banknote', 'wallet', 'credit', 'dollar', //
      'euro', 'pound', 'receipt', 'store', 'shopping', 'landmark', 'piggy',
      'coins', 'handshake', 'presentation', 'target', 'award', 'trophy',
      'factory', 'badge', 'percent', 'ticket', 'calculator', 'signature',
      'bitcoin', 'currency', 'shopping', 'tag', 'tags', 'barcode',
      'invoice', 'goal', 'medal', 'crown',
    ],
    LucideCategory.charts: [
      'chart', 'gauge', 'kanban', 'gantt', 'trending', 'sigma', 'pie', //
      'activity', 'presentation', 'table', 'sheet', 'axis',
    ],
    LucideCategory.communication: [
      'message', 'messages', 'mail', 'mails', 'phone', 'at', 'send', //
      'inbox', 'megaphone', 'bell', 'rss', 'voicemail', 'contact',
      'speech', 'reply', 'mailbox', 'mic', 'video', 'share', 'signal',
      'radio', 'podcast', 'webhook', 'wifi', 'satellite',
    ],
    LucideCategory.devices: [
      'monitor', 'laptop', 'smartphone', 'tablet', 'tv', 'keyboard', //
      'mouse', 'printer', 'cpu', 'hard', 'server', 'router', 'watch',
      'battery', 'plug', 'usb', 'headphones', 'speaker', 'webcam',
      'gamepad', 'joystick', 'bluetooth', 'wifi', 'cable', 'memory',
      'disc', 'radio', 'computer', 'projector', 'cast', 'airplay',
      'nfc', 'touchpad', 'microchip', 'hdmi', 'ethernet', 'phone',
    ],
    LucideCategory.development: [
      'code', 'terminal', 'git', 'bug', 'braces', 'brackets', 'binary', //
      'database', 'server', 'cpu', 'webhook', 'variable', 'function',
      'regex', 'container', 'blocks', 'workflow', 'package', 'bot',
      'cloud', 'squircle', 'component', 'api', 'parentheses',
    ],
    LucideCategory.files: [
      'file', 'files', 'folder', 'folders', 'archive', 'clipboard', //
      'paperclip', 'save', 'book', 'books', 'notebook', 'sticky',
      'scroll', 'library', 'newspaper', 'album', 'download', 'upload',
      'import', 'paper', 'copy', 'trash', 'notepad',
    ],
    LucideCategory.food: [
      'coffee', 'cup', 'pizza', 'apple', 'cake', 'cookie', 'beer', 'wine', //
      'utensils', 'chef', 'carrot', 'cherry', 'citrus', 'grape', 'ice',
      'sandwich', 'soup', 'croissant', 'egg', 'milk', 'popcorn', 'salad',
      'donut', 'candy', 'banana', 'beef', 'drumstick', 'fish', 'ham',
      'hamburger', 'lollipop', 'martini', 'nut', 'wheat', 'vegan', 'glass',
      'cooking', 'refrigerator', 'microwave', 'bottle',
    ],
    LucideCategory.media: [
      'play', 'pause', 'music', 'video', 'film', 'camera', 'image', //
      'images', 'mic', 'volume', 'headphones', 'radio', 'tv',
      'clapperboard', 'disc', 'podcast', 'audio', 'skip', 'rewind', 'fast',
      'cast', 'airplay', 'gallery', 'aperture', 'speaker',
      'drum', 'guitar', 'piano', 'youtube',
      'stop', 'record', 'clapper',
    ],
    LucideCategory.nature: [
      'tree', 'trees', 'leaf', 'leafy', 'flower', 'sprout', 'mountain', //
      'waves', 'bug', 'bird', 'fish', 'rabbit', 'squirrel', 'cat', 'dog',
      'turtle', 'snail', 'shell', 'feather', 'clover', 'palmtree', 'shrub',
      'earth', 'globe', 'flame', 'droplet', 'droplets', 'paw', 'rat',
      'worm', 'bean', 'vegan', 'tent', 'sun', 'moon', 'cactus', 'egg',
      'origami', 'panda', 'rose',
    ],
    LucideCategory.people: [
      'user', 'users', 'person', 'baby', 'contact', 'smile', 'frown', //
      'laugh', 'meh', 'accessibility', 'hand', 'footprints', 'brain',
      'heart', 'angry', 'annoyed', 'face', 'ear', 'eye', 'speech', 'venus',
      'mars', 'pregnant', 'skull', 'glasses', 'shirt',
      'handshake', 'thumbs', 'grab',
    ],
    LucideCategory.security: [
      'lock', 'unlock', 'key', 'shield', 'fingerprint', 'scan', 'eye', //
      'siren', 'alarm', 'vault', 'ban', 'cctv', 'id',
      'locked', 'keyhole', 'bomb',
    ],
    LucideCategory.shapes: [
      'square', 'circle', 'triangle', 'hexagon', 'octagon', 'pentagon', //
      'diamond', 'star', 'heart', 'shapes', 'box', 'boxes', 'cuboid',
      'cylinder', 'cone', 'pyramid', 'torus', 'spline', 'squircle', 'dot',
      'rectangle', 'cross', 'plus', 'minus', 'x', 'check', 'infinity',
      'sparkle', 'sparkles', 'blend', 'shell',
    ],
    LucideCategory.text: [
      'text', 'type', 'bold', 'italic', 'underline', 'strikethrough', //
      'heading', 'heading1', 'heading2', 'heading3', 'pilcrow', 'quote',
      'align', 'list', 'indent', 'outdent', 'letter', 'spell', 'case',
      'baseline', 'subscript', 'superscript', 'whole', 'wrap', 'languages',
      'a', 'highlighter', 'signature', 'pen', 'pencil',
      'notebook', 'book', 'captions', 'ligature', 'space',
    ],
    LucideCategory.time: [
      'clock', 'calendar', 'alarm', 'timer', 'hourglass', 'watch', //
      'history', 'calendars', 'stopwatch', 'sunrise', 'sunset',
    ],
    LucideCategory.tools: [
      'wrench', 'hammer', 'settings', 'cog', 'scissors', 'ruler', 'pen', //
      'pencil', 'brush', 'paintbrush', 'palette', 'eraser', 'axe', 'drill',
      'shovel', 'pickaxe', 'pipette', 'construction',
      'magnet', 'flashlight', 'sliders', 'toolbox', 'paint', 'spray',
      'swatch', 'brick', 'anvil', 'saw', 'screwdriver',
    ],
    LucideCategory.travel: [
      'plane', 'car', 'bus', 'train', 'ship', 'bike', 'map', 'compass', //
      'globe', 'luggage', 'hotel', 'tent', 'caravan', 'fuel', 'navigation',
      'route', 'signpost', 'ticket', 'anchor', 'sailboat', 'rocket',
      'tram', 'truck', 'taxi', 'helicopter', 'ambulance',
      'tractor', 'forklift', 'locate', 'pin', 'milestone', 'passport',
      'earth', 'mountain', 'palmtree', 'parking', 'traffic', 'van',
      'motorbike', 'scooter', 'sailboat', 'drone', 'satellite',
    ],
    LucideCategory.weather: [
      'sun', 'moon', 'cloud', 'cloudy', 'rain', 'snowflake', 'wind', //
      'thermometer', 'umbrella', 'rainbow', 'tornado', 'sunrise', 'sunset',
      'haze', 'droplet', 'droplets', 'zap', 'lightning', 'storm', 'snow',
      'fog', 'hail', 'drizzle', 'sunny', 'waves', 'leaf',
    ],
  };

  /// Everyday words → name words.
  static const Map<String, Set<String>> _synonyms = {
    'add': {'plus'},
    'remove': {'minus', 'x', 'trash'},
    'delete': {'trash', 'x'},
    'close': {'x'},
    'cancel': {'x', 'ban'},
    'ok': {'check'},
    'done': {'check'},
    'tick': {'check'},
    'email': {'mail', 'mails', 'inbox'},
    'envelope': {'mail'},
    'money': {'dollar', 'banknote', 'coins', 'wallet', 'euro'},
    'cash': {'banknote', 'coins', 'dollar'},
    'payment': {'credit', 'wallet', 'banknote'},
    'settings': {'cog', 'settings', 'sliders'},
    'gear': {'cog', 'settings'},
    'warning': {'alert', 'triangle'},
    'error': {'alert', 'x', 'octagon'},
    'info': {'info'},
    'help': {'help', 'question', 'lifebuoy'},
    'photo': {'image', 'images', 'camera'},
    'picture': {'image', 'images'},
    'person': {'user', 'users'},
    'people': {'users', 'user'},
    'team': {'users'},
    'location': {'pin', 'map', 'locate', 'navigation'},
    'place': {'pin', 'map'},
    'home': {'house', 'home'},
    'search': {'search', 'scan'},
    'find': {'search'},
    'love': {'heart'},
    'like': {'heart', 'thumbs'},
    'favorite': {'star', 'heart'},
    'idea': {'lightbulb'},
    'light': {'lightbulb', 'lamp', 'sun'},
    'growth': {'trending', 'sprout'},
    'success': {'trophy', 'award', 'check', 'party'},
    'launch': {'rocket'},
    'start': {'rocket', 'play', 'flag'},
    'time': {'clock', 'timer', 'hourglass'},
    'date': {'calendar'},
    'chat': {'message', 'messages'},
    'talk': {'message', 'speech', 'mic'},
    'call': {'phone'},
    'world': {'globe', 'earth'},
    'internet': {'globe', 'wifi'},
    'security': {'shield', 'lock'},
    'password': {'key', 'lock'},
    'edit': {'pencil', 'pen'},
    'write': {'pencil', 'pen', 'notebook'},
    'document': {'file'},
    'doc': {'file'},
    'graph': {'chart'},
    'stats': {'chart'},
    'analytics': {'chart', 'trending'},
    'cart': {'shopping'},
    'shop': {'store', 'shopping'},
    'buy': {'shopping', 'credit'},
    'car': {'car'},
    'travel': {'plane', 'luggage', 'map'},
    'flight': {'plane'},
    'weather': {'cloud', 'sun'},
    'music': {'music'},
    'sound': {'volume', 'speaker'},
    'notification': {'bell'},
    'alarm': {'bell', 'alarm'},
    'upload': {'upload'},
    'download': {'download'},
    'share': {'share'},
    'link': {'link'},
    'code': {'code'},
    'computer': {'monitor', 'laptop'},
    'phone': {'phone', 'smartphone'},
    'mobile': {'smartphone'},
    'ai': {'sparkles', 'bot', 'brain'},
    'magic': {'sparkles', 'wand'},
    'food': {'utensils', 'pizza', 'apple'},
    'drink': {'coffee', 'cup', 'wine', 'beer'},
  };
}
