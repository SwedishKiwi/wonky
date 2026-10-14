import 'dart:convert';
import 'dart:typed_data';

/// A cell error value crossing the script boundary (`#N/A`, `#DIV/0!`, …).
///
/// Scripts see it as the bridged class `CellError` (09 §6.4); hosts convert
/// it to and from the workbook's error kinds.
final class CellError {
  /// Creates an error value with the literal [code] (e.g. `#N/A`).
  const CellError(this.code, [this.message]);

  /// The error literal, e.g. `#N/A`.
  final String code;

  /// Optional explanation (tooltip text).
  final String? message;

  @override
  bool operator ==(Object other) => other is CellError && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => code;
}

/// Compact binary codec for values crossing the host/guest channel (09
/// §8.2.2): `null`, `bool`, `int` (64-bit), `double`, `String`, `DateTime`,
/// [CellError], `Uint8List`, `List` and `Map<String, Object?>`.
///
/// Tag-length-value; strings UTF-8. 2-D arrays are plain nested lists (the
/// per-element overhead is one tag byte for small integers and booleans).
abstract final class ValueCodec {
  static const _null = 0,
      _true = 1,
      _false = 2,
      _int8 = 3,
      _int64 = 4,
      _double = 5,
      _string = 6,
      _dateTime = 7,
      _error = 8,
      _bytes = 9,
      _list = 10,
      _map = 11;

  /// Encodes [value]. Throws [ArgumentError] for unsupported types.
  static Uint8List encode(Object? value) {
    final w = _Writer();
    w.value(value);
    return w.takeBytes();
  }

  /// Decodes bytes produced by [encode].
  static Object? decode(Uint8List bytes) {
    final r = _Reader(bytes);
    return r.value();
  }
}

final class _Writer {
  Uint8List _buf = Uint8List(256);
  late ByteData _data = ByteData.view(_buf.buffer);
  int _len = 0;

  void _ensure(int n) {
    if (_len + n <= _buf.length) return;
    var size = _buf.length * 2;
    while (size < _len + n) {
      size *= 2;
    }
    final next = Uint8List(size)..setRange(0, _len, _buf);
    _buf = next;
    _data = ByteData.view(_buf.buffer);
  }

  void _byte(int b) {
    _ensure(1);
    _buf[_len++] = b;
  }

  void _uint32(int v) {
    _ensure(4);
    _data.setUint32(_len, v);
    _len += 4;
  }

  void _int64(int v) {
    _ensure(8);
    // Two 32-bit halves keep the codec working on the web (no setInt64).
    final hi = (v / 4294967296).floor();
    final lo = v - hi * 4294967296;
    _data.setInt32(_len, hi);
    _data.setUint32(_len + 4, lo);
    _len += 8;
  }

  void _float64(double v) {
    _ensure(8);
    _data.setFloat64(_len, v);
    _len += 8;
  }

  void _raw(List<int> bytes) {
    _ensure(bytes.length);
    _buf.setRange(_len, _len + bytes.length, bytes);
    _len += bytes.length;
  }

  void _string(String s) {
    final units = utf8.encode(s);
    _uint32(units.length);
    _raw(units);
  }

  void value(Object? v) {
    switch (v) {
      case null:
        _byte(ValueCodec._null);
      case true:
        _byte(ValueCodec._true);
      case false:
        _byte(ValueCodec._false);
      case int i when i >= -128 && i <= 127:
        _byte(ValueCodec._int8);
        _byte(i & 0xff);
      case int i:
        _byte(ValueCodec._int64);
        _int64(i);
      case double d:
        _byte(ValueCodec._double);
        _float64(d);
      case String s:
        _byte(ValueCodec._string);
        _string(s);
      case DateTime d:
        _byte(ValueCodec._dateTime);
        _int64(d.microsecondsSinceEpoch);
        _byte(d.isUtc ? 1 : 0);
      case CellError e:
        _byte(ValueCodec._error);
        _string(e.code);
        _string(e.message ?? '');
      case Uint8List b:
        _byte(ValueCodec._bytes);
        _uint32(b.length);
        _raw(b);
      case List<Object?> l:
        _byte(ValueCodec._list);
        _uint32(l.length);
        for (final e in l) {
          value(e);
        }
      case Map<Object?, Object?> m:
        _byte(ValueCodec._map);
        _uint32(m.length);
        for (final e in m.entries) {
          _string(e.key.toString());
          value(e.value);
        }
      default:
        throw ArgumentError.value(v, 'value', 'Unsupported type');
    }
  }

  Uint8List takeBytes() => Uint8List.sublistView(_buf, 0, _len);
}

final class _Reader {
  _Reader(this._buf) : _data = ByteData.sublistView(_buf);
  final Uint8List _buf;
  final ByteData _data;
  int _pos = 0;

  int _byte() => _buf[_pos++];

  int _uint32() {
    final v = _data.getUint32(_pos);
    _pos += 4;
    return v;
  }

  int _int64() {
    final hi = _data.getInt32(_pos);
    final lo = _data.getUint32(_pos + 4);
    _pos += 8;
    return hi * 4294967296 + lo;
  }

  String _string() {
    final n = _uint32();
    final s = utf8.decode(Uint8List.sublistView(_buf, _pos, _pos + n));
    _pos += n;
    return s;
  }

  Object? value() {
    final tag = _byte();
    switch (tag) {
      case ValueCodec._null:
        return null;
      case ValueCodec._true:
        return true;
      case ValueCodec._false:
        return false;
      case ValueCodec._int8:
        final b = _byte();
        return b >= 128 ? b - 256 : b;
      case ValueCodec._int64:
        return _int64();
      case ValueCodec._double:
        final d = _data.getFloat64(_pos);
        _pos += 8;
        return d;
      case ValueCodec._string:
        return _string();
      case ValueCodec._dateTime:
        final micros = _int64();
        final utc = _byte() == 1;
        return DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: utc);
      case ValueCodec._error:
        final code = _string();
        final message = _string();
        return CellError(code, message.isEmpty ? null : message);
      case ValueCodec._bytes:
        final n = _uint32();
        final b = Uint8List.fromList(_buf.sublist(_pos, _pos + n));
        _pos += n;
        return b;
      case ValueCodec._list:
        final n = _uint32();
        return List<Object?>.generate(n, (_) => value(), growable: true);
      case ValueCodec._map:
        final n = _uint32();
        final m = <String, Object?>{};
        for (var i = 0; i < n; i++) {
          final k = _string();
          m[k] = value();
        }
        return m;
      default:
        throw FormatException('Unknown value tag $tag at ${_pos - 1}');
    }
  }
}
