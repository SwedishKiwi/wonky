/// The platform a key binding is resolved for.
///
/// `Mod` means ⌘ on macOS and Ctrl elsewhere; web builds additionally must
/// never bind browser-reserved chords (suite 08 §1.2).
class KeyPlatform {
  const KeyPlatform({required this.isMac, required this.isWeb});

  final bool isMac;
  final bool isWeb;

  static const macDesktop = KeyPlatform(isMac: true, isWeb: false);
  static const macWeb = KeyPlatform(isMac: true, isWeb: true);
  static const otherDesktop = KeyPlatform(isMac: false, isWeb: false);
  static const otherWeb = KeyPlatform(isMac: false, isWeb: true);

  @override
  bool operator ==(Object other) =>
      other is KeyPlatform && other.isMac == isMac && other.isWeb == isWeb;

  @override
  int get hashCode => Object.hash(isMac, isWeb);

  @override
  String toString() =>
      'KeyPlatform(${isMac ? 'mac' : 'other'}, ${isWeb ? 'web' : 'desktop'})';
}

/// A modifier key. [mod] is the platform's primary modifier.
enum KeyModifier { mod, ctrl, alt, shift, meta }

/// Canonical key names used by [KeyBinding.key].
///
/// Printable keys are single characters (letters upper case): `A`, `7`, `/`,
/// `.`, `[`. Named keys use these constants.
abstract final class Keys {
  static const enter = 'Enter';
  static const escape = 'Escape';
  static const tab = 'Tab';
  static const space = 'Space';
  static const backspace = 'Backspace';
  static const delete = 'Delete';
  static const insert = 'Insert';
  static const arrowUp = 'ArrowUp';
  static const arrowDown = 'ArrowDown';
  static const arrowLeft = 'ArrowLeft';
  static const arrowRight = 'ArrowRight';
  static const home = 'Home';
  static const end = 'End';
  static const pageUp = 'PageUp';
  static const pageDown = 'PageDown';

  /// `F1`…`F12`.
  static String f(int n) => 'F$n';

  static const named = {
    enter,
    escape,
    tab,
    space,
    backspace,
    delete,
    insert,
    arrowUp,
    arrowDown,
    arrowLeft,
    arrowRight,
    home,
    end,
    pageUp,
    pageDown,
    'F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11', 'F12', //
  };

  static const _aliases = {
    'esc': escape,
    'return': enter,
    'del': delete,
    'up': arrowUp,
    'down': arrowDown,
    'left': arrowLeft,
    'right': arrowRight,
    'pgup': pageUp,
    'pgdn': pageDown,
    'spacebar': space,
  };

  /// Normalizes a key name (`esc` → `Escape`, `a` → `A`); null if invalid.
  static String? normalize(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    if (t.length == 1) return t.toUpperCase();
    final alias = _aliases[t.toLowerCase()];
    if (alias != null) return alias;
    for (final n in named) {
      if (n.toLowerCase() == t.toLowerCase()) return n;
    }
    return null;
  }
}

/// A platform-aware key chord, e.g. `Mod+Shift+Z`.
///
/// [mac] / [web] restrict where the binding applies (null = everywhere):
/// `KeyBinding('Y', mod: true, mac: false)` is Ctrl+Y on Windows/Linux only.
class KeyBinding {
  const KeyBinding(
    this.key, {
    this.mod = false,
    this.ctrl = false,
    this.alt = false,
    this.shift = false,
    this.meta = false,
    this.mac,
    this.web,
  });

  /// Canonical key name (see [Keys]).
  final String key;

  /// ⌘ on macOS, Ctrl elsewhere.
  final bool mod;

  /// The physical Control key (⌃ on macOS). On non-mac platforms `ctrl` and
  /// `mod` resolve to the same key.
  final bool ctrl;
  final bool alt;
  final bool shift;

  /// The physical ⌘/Windows key, independent of [mod].
  final bool meta;

  /// Only on macOS (true) / only off macOS (false) / both (null).
  final bool? mac;

  /// Only on web (true) / only on desktop (false) / both (null).
  final bool? web;

  /// Whether this binding applies on [platform].
  bool appliesTo(KeyPlatform platform) =>
      (mac == null || mac == platform.isMac) &&
      (web == null || web == platform.isWeb);

  /// The concrete chord on [platform].
  ResolvedChord resolve(KeyPlatform platform) => ResolvedChord(
    key: key,
    control: ctrl || (mod && !platform.isMac),
    meta: meta || (mod && platform.isMac),
    alt: alt,
    shift: shift,
  );

  /// Whether this chord is reserved by browsers (⌘W, ⌘T, ⌘N, ⌘L, …) and must
  /// not be bound on web.
  bool isBrowserReserved(KeyPlatform platform) {
    if (!platform.isWeb) return false;
    final c = resolve(platform);
    final primary = platform.isMac ? c.meta : c.control;
    if (!primary || c.alt) return false;
    const reserved = {'W', 'T', 'N', 'L', 'Q'};
    const reservedShift = {'W', 'T', 'N', 'Q'};
    return c.shift ? reservedShift.contains(key) : reserved.contains(key);
  }

  /// Parses `Mod+Shift+Z`, `Ctrl+Alt+M`, `F2`, `Shift+/`. Returns null for
  /// malformed input.
  static KeyBinding? tryParse(String text) {
    final raw = text.trim();
    if (raw.isEmpty) return null;
    // A trailing "+" means the plus key itself ("Mod++").
    final parts = <String>[];
    var rest = raw;
    if (rest.endsWith('++')) {
      parts.add('+');
      rest = rest.substring(0, rest.length - 2);
    } else if (rest == '+') {
      return const KeyBinding('+');
    }
    if (rest.isNotEmpty) parts.insertAll(0, rest.split('+'));
    var mod = false, ctrl = false, alt = false, shift = false, meta = false;
    String? key;
    for (final p in parts) {
      final t = p.trim();
      switch (t.toLowerCase()) {
        case 'mod':
        case 'cmdorctrl':
          mod = true;
        case 'ctrl':
        case 'control':
          ctrl = true;
        case 'alt':
        case 'option':
        case 'opt':
          alt = true;
        case 'shift':
          shift = true;
        case 'meta':
        case 'cmd':
        case 'command':
        case 'super':
        case 'win':
          meta = true;
        default:
          if (key != null) return null;
          key = Keys.normalize(t);
          if (key == null) return null;
      }
    }
    if (key == null) return null;
    return KeyBinding(
      key,
      mod: mod,
      ctrl: ctrl,
      alt: alt,
      shift: shift,
      meta: meta,
    );
  }

  /// Parses or throws [FormatException].
  static KeyBinding parse(String text) =>
      tryParse(text) ?? (throw FormatException('Invalid key binding', text));

  /// Canonical text form (`Mod+Alt+Shift+H`), platform-independent.
  String get canonical => [
    if (mod) 'Mod',
    if (ctrl) 'Ctrl',
    if (alt) 'Alt',
    if (shift) 'Shift',
    if (meta) 'Meta',
    key,
  ].join('+');

  /// Key cap labels for display with `ShadKbd`, e.g. `['⌘', '⇧', 'Z']` on
  /// macOS or `['Ctrl', 'Shift', 'Z']` elsewhere.
  List<String> labels(KeyPlatform platform) =>
      resolve(platform).labels(platform);

  /// Human text: `⌘⇧Z` on macOS, `Ctrl+Shift+Z` elsewhere.
  String format(KeyPlatform platform) => resolve(platform).format(platform);

  /// JSON form: the canonical string plus platform qualifiers.
  Object toJson() => mac == null && web == null
      ? canonical
      : {
          'keys': canonical,
          if (mac != null) 'mac': mac,
          if (web != null) 'web': web,
        };

  /// Inverse of [toJson].
  static KeyBinding? fromJson(Object? json) {
    if (json is String) return tryParse(json);
    if (json is Map) {
      final keys = json['keys'];
      if (keys is! String) return null;
      final b = tryParse(keys);
      if (b == null) return null;
      final mac = json['mac'];
      final web = json['web'];
      return b.copyWith(mac: mac is bool ? mac : null, web: web is bool ? web : null);
    }
    return null;
  }

  KeyBinding copyWith({bool? mac, bool? web}) => KeyBinding(
    key,
    mod: mod,
    ctrl: ctrl,
    alt: alt,
    shift: shift,
    meta: meta,
    mac: mac ?? this.mac,
    web: web ?? this.web,
  );

  @override
  bool operator ==(Object other) =>
      other is KeyBinding &&
      other.key == key &&
      other.mod == mod &&
      other.ctrl == ctrl &&
      other.alt == alt &&
      other.shift == shift &&
      other.meta == meta &&
      other.mac == mac &&
      other.web == web;

  @override
  int get hashCode => Object.hash(key, mod, ctrl, alt, shift, meta, mac, web);

  @override
  String toString() => canonical;
}

/// A chord with concrete modifiers, as pressed on one platform.
class ResolvedChord {
  const ResolvedChord({
    required this.key,
    this.control = false,
    this.meta = false,
    this.alt = false,
    this.shift = false,
  });

  final String key;
  final bool control;
  final bool meta;
  final bool alt;
  final bool shift;

  /// Key cap labels (see [KeyBinding.labels]).
  List<String> labels(KeyPlatform platform) {
    if (platform.isMac) {
      return [
        if (control) '⌃',
        if (alt) '⌥',
        if (shift) '⇧',
        if (meta) '⌘',
        _keyLabel(key, mac: true),
      ];
    }
    return [
      if (control) 'Ctrl',
      if (meta) 'Win',
      if (alt) 'Alt',
      if (shift) 'Shift',
      _keyLabel(key, mac: false),
    ];
  }

  /// Text form (`⌘⇧Z` / `Ctrl+Shift+Z`).
  String format(KeyPlatform platform) =>
      platform.isMac ? labels(platform).join() : labels(platform).join('+');

  /// Converts back to a platform-independent binding, expressing the
  /// platform's primary modifier as `Mod`.
  KeyBinding toBinding(KeyPlatform platform) => KeyBinding(
    key,
    mod: platform.isMac ? meta : control,
    ctrl: platform.isMac && control,
    meta: !platform.isMac && meta,
    alt: alt,
    shift: shift,
  );

  @override
  bool operator ==(Object other) =>
      other is ResolvedChord &&
      other.key == key &&
      other.control == control &&
      other.meta == meta &&
      other.alt == alt &&
      other.shift == shift;

  @override
  int get hashCode => Object.hash(key, control, meta, alt, shift);

  @override
  String toString() => format(KeyPlatform.otherDesktop);

  static String _keyLabel(String key, {required bool mac}) => switch (key) {
    Keys.enter => mac ? '↩' : 'Enter',
    Keys.escape => 'Esc',
    Keys.tab => mac ? '⇥' : 'Tab',
    Keys.space => 'Space',
    Keys.backspace => mac ? '⌫' : 'Backspace',
    Keys.delete => mac ? '⌦' : 'Del',
    Keys.arrowUp => '↑',
    Keys.arrowDown => '↓',
    Keys.arrowLeft => '←',
    Keys.arrowRight => '→',
    Keys.pageUp => mac ? 'PgUp' : 'PgUp',
    Keys.pageDown => 'PgDn',
    _ => key,
  };
}

/// Where a key binding is active (suite 08 §1.2). More specific scopes win:
/// a binding in [editor] shadows the same chord in [global] while the editor
/// has focus. Apps may define more scopes.
extension type const KeyScope(String name) {
  /// The app shell (always active).
  static const global = KeyScope('global');

  /// The Write editor has focus.
  static const editor = KeyScope('editor');

  /// The Sheets grid has focus.
  static const grid = KeyScope('grid');

  /// A Sheets cell is being edited.
  static const cellEditor = KeyScope('cellEditor');

  /// A dialog has focus.
  static const dialog = KeyScope('dialog');

  /// The drive list/grid has focus (home screen shortcuts like `N`, `S`).
  static const drive = KeyScope('drive');
}
