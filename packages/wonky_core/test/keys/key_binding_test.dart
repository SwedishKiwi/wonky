import 'package:test/test.dart';
import 'package:wonky_core/wonky_core.dart';

void main() {
  group('Given the binding Mod+Shift+Z', () {
    final b = KeyBinding.parse('Mod+Shift+Z');

    test('when resolved on macOS then Mod is Command', () {
      final c = b.resolve(KeyPlatform.macDesktop);
      expect((c.meta, c.control, c.shift), (true, false, true));
    });

    test('when resolved elsewhere then Mod is Control', () {
      final c = b.resolve(KeyPlatform.otherWeb);
      expect((c.meta, c.control, c.shift), (false, true, true));
    });

    test('when labelled then macOS uses glyphs and others use words', () {
      expect(b.labels(KeyPlatform.macDesktop), ['⇧', '⌘', 'Z']);
      expect(b.format(KeyPlatform.macDesktop), '⇧⌘Z');
      expect(b.format(KeyPlatform.otherDesktop), 'Ctrl+Shift+Z');
    });

    test('when serialized then the canonical form round-trips', () {
      expect(b.canonical, 'Mod+Shift+Z');
      expect(KeyBinding.fromJson(b.toJson()), b);
    });
  });

  group('Given key text in various spellings', () {
    for (final (text, canonical) in [
      ('ctrl+alt+m', 'Ctrl+Alt+M'),
      ('Mod+/', 'Mod+/'),
      ('F2', 'F2'),
      ('esc', 'Escape'),
      ('Mod++', 'Mod++'),
      ('Cmd+Shift+[', 'Shift+Meta+['),
    ]) {
      test('when parsing "$text" then it is $canonical', () {
        expect(KeyBinding.parse(text).canonical, canonical);
      });
    }

    test('when parsing two keys then it fails', () {
      expect(KeyBinding.tryParse('A+B'), isNull);
      expect(KeyBinding.tryParse(''), isNull);
    });
  });

  group('Given platform-restricted bindings', () {
    const ctrlY = KeyBinding('Y', mod: true, mac: false);
    test('when checking applicability then Ctrl+Y is not used on macOS', () {
      expect(ctrlY.appliesTo(KeyPlatform.macDesktop), isFalse);
      expect(ctrlY.appliesTo(KeyPlatform.otherWeb), isTrue);
    });
    test('when serialized then the qualifiers are kept', () {
      expect(KeyBinding.fromJson(ctrlY.toJson()), ctrlY);
    });
  });

  group('Given browser-reserved chords', () {
    test('when on web then Mod+W and Mod+T are reserved', () {
      expect(
        KeyBinding.parse('Mod+W').isBrowserReserved(KeyPlatform.otherWeb),
        isTrue,
      );
      expect(
        KeyBinding.parse('Mod+T').isBrowserReserved(KeyPlatform.macWeb),
        isTrue,
      );
    });
    test('when on desktop or with Alt then they are not reserved', () {
      expect(
        KeyBinding.parse('Mod+W').isBrowserReserved(KeyPlatform.macDesktop),
        isFalse,
      );
      expect(
        KeyBinding.parse('Mod+Alt+N').isBrowserReserved(KeyPlatform.otherWeb),
        isFalse,
      );
    });
  });

  test('Given a chord pressed on macOS when converted back then Command '
      'becomes Mod', () {
    const c = ResolvedChord(key: 'B', meta: true);
    expect(c.toBinding(KeyPlatform.macWeb), KeyBinding.parse('Mod+B'));
    const d = ResolvedChord(key: 'B', control: true);
    expect(d.toBinding(KeyPlatform.macWeb), KeyBinding.parse('Ctrl+B'));
    expect(d.toBinding(KeyPlatform.otherWeb), KeyBinding.parse('Mod+B'));
  });
}
