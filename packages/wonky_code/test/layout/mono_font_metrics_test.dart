import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:wonky_code/wonky_code.dart';

/// A minimal font file with `head`, `hhea` and `hmtx` tables.
Uint8List fakeTtf({
  required int unitsPerEm,
  required int ascender,
  required int descender,
  required List<int> advances,
}) {
  final head = ByteData(54)..setUint16(18, unitsPerEm);
  final hhea = ByteData(36)
    ..setInt16(4, ascender)
    ..setInt16(6, descender)
    ..setInt16(8, 0)
    ..setUint16(34, advances.length);
  final hmtx = ByteData(4 * advances.length);
  for (var i = 0; i < advances.length; i++) {
    hmtx.setUint16(4 * i, advances[i]);
  }
  final tables = {'head': head, 'hhea': hhea, 'hmtx': hmtx};
  var offset = 12 + 16 * tables.length;
  final out = BytesBuilder();
  final dir = ByteData(12 + 16 * tables.length)..setUint16(4, tables.length);
  var i = 0;
  for (final e in tables.entries) {
    final rec = 12 + 16 * i++;
    for (var c = 0; c < 4; c++) {
      dir.setUint8(rec + c, e.key.codeUnitAt(c));
    }
    dir
      ..setUint32(rec + 8, offset)
      ..setUint32(rec + 12, e.value.lengthInBytes);
    offset += e.value.lengthInBytes;
  }
  out.add(dir.buffer.asUint8List());
  for (final t in tables.values) {
    out.add(t.buffer.asUint8List());
  }
  return out.toBytes();
}

void main() {
  group('Given a monospace font file', () {
    test('when reading it then the dominant advance and vertical metrics are '
        'in em', () {
      final bytes = fakeTtf(
        unitsPerEm: 1000,
        ascender: 1020,
        descender: -300,
        advances: [0, 600, 600, 600, 1200],
      );

      final m = MonoFontMetrics.fromTtf('Test Mono', bytes)!;

      expect(m.advanceEm, 0.6);
      expect(m.ascentEm, 1.02);
      expect(m.descentEm, 0.3);
      expect(m.family, 'Test Mono');
    });

    test('when the file is truncated then there are no metrics', () {
      expect(MonoFontMetrics.fromTtf('x', Uint8List(20)), isNull);
    });
  });

  group('Given the bundled families', () {
    test('when asking for JetBrains Mono then its measured metrics are '
        'used', () {
      final m = MonoFontMetrics.forFamily('JetBrains Mono');

      expect(m, MonoFontMetrics.jetBrainsMono);
      expect(m.advanceEm, 0.6);
    });

    test('when asking for the theme mono role then JetBrains Mono is used', () {
      expect(MonoFontMetrics.forFamily('@mono'), MonoFontMetrics.jetBrainsMono);
    });

    test('when asking for an unknown family then the common 0.6 em advance '
        'is used', () {
      expect(MonoFontMetrics.forFamily('Fira Code').advanceEm, 0.6);
    });
  });

  test('when placing the baseline then the glyph box is centered in the '
      'row', () {
    const m = MonoFontMetrics.jetBrainsMono;

    // 20 su font, 1.5 line height: row 30, content 26.4, half leading 1.8.
    expect(m.baselineInRow(20, 1.5), closeTo(1.8 + 20.4, 1e-9));
  });
}
