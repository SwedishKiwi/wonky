/// RTF tokenizer (07 §3.8): control words with optional numeric parameters,
/// control symbols, groups, `\binN` binary data, `\'hh` bytes decoded with
/// the current code page and `\uN` Unicode characters with `\ucN` fallback
/// skipping.
library;

import 'dart:typed_data';

import '../encoding.dart';

/// A token of an RTF stream.
sealed class RtfToken {
  const RtfToken();
}

/// `{`: a group starts.
final class RtfGroupStart extends RtfToken {
  /// Creates the token.
  const RtfGroupStart();

  @override
  bool operator ==(Object other) => other is RtfGroupStart;

  @override
  int get hashCode => 1;

  @override
  String toString() => '{';
}

/// `}`: a group ends.
final class RtfGroupEnd extends RtfToken {
  /// Creates the token.
  const RtfGroupEnd();

  @override
  bool operator ==(Object other) => other is RtfGroupEnd;

  @override
  int get hashCode => 2;

  @override
  String toString() => '}';
}

/// A control word (`\b0`, `\fs24`, `\par`) or a control symbol (`\*`,
/// `\|`, `\:`) that has no text meaning.
final class RtfControl extends RtfToken {
  /// Creates a control token.
  const RtfControl(this.word, [this.param, this.symbol = false]);

  /// The word without backslash (`fs`), or the symbol character (`*`).
  final String word;

  /// The numeric parameter, if present.
  final int? param;

  /// Whether this is a control symbol (one non-letter character).
  final bool symbol;

  /// Whether a toggle word is on (`\b`, `\b1`; not `\b0`).
  bool get isOn => param != 0;

  @override
  bool operator ==(Object other) =>
      other is RtfControl &&
      other.word == word &&
      other.param == param &&
      other.symbol == symbol;

  @override
  int get hashCode => Object.hash(word, param, symbol);

  @override
  String toString() => '\\$word${param ?? ''}';
}

/// Decoded text (literal characters, escaped `\\ \{ \}`, `\'hh` bytes,
/// `\uN` characters, `\~` as U+00A0, `\_` as U+2011).
final class RtfText extends RtfToken {
  /// Creates a text token.
  const RtfText(this.text);

  /// The text.
  final String text;

  @override
  bool operator ==(Object other) => other is RtfText && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'Text("$text")';
}

/// Binary data of a `\binN` control word.
final class RtfBinary extends RtfToken {
  /// Creates a binary token.
  const RtfBinary(this.bytes);

  /// The raw bytes.
  final Uint8List bytes;

  @override
  bool operator ==(Object other) {
    if (other is! RtfBinary || other.bytes.length != bytes.length) {
      return false;
    }
    for (var i = 0; i < bytes.length; i++) {
      if (other.bytes[i] != bytes[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(bytes);

  @override
  String toString() => 'Binary(${bytes.length})';
}

final class _Scope {
  _Scope(this.font, this.uc);

  _Scope.copy(_Scope o) : font = o.font, uc = o.uc;

  int font;
  int uc;
}

/// Splits RTF bytes into [RtfToken]s.
///
/// Byte decoding follows the document: `\ansicpgN` sets the default code
/// page, `\fcharsetN` / `\cpgN` in the font table give fonts their own code
/// page, and `\fN` (group scoped, reset by `\plain` to `\deffN`) selects the
/// one used for `\'hh`. Code pages without a built-in table (East Asian
/// double-byte pages) fall back to Windows-1252 and are listed in
/// [unsupportedCodePages]. `\uN` characters (negative values are signed
/// 16-bit) skip the next `\ucN` fallback characters; text, `\'hh`, control
/// words and symbols count as one each and group boundaries end the skip.
///
/// Carriage returns and line feeds are ignored, except that a backslash
/// followed by one is a paragraph mark (`\par`). Never throws.
final class RtfTokenizer {
  /// Creates a tokenizer for [bytes].
  RtfTokenizer(this.bytes);

  /// The RTF bytes.
  final Uint8List bytes;

  /// Code pages requested by the document that are not built in.
  final Set<int> unsupportedCodePages = {};

  var _ansiCodePage = 1252;
  var _defaultFont = -1;
  final _fontCodePages = <int, int>{};

  /// Tokenizes [bytes].
  List<RtfToken> tokenize() {
    final out = <RtfToken>[];
    final text = StringBuffer();
    final stack = <_Scope>[_Scope(-1, 1)];
    var skip = 0;
    var pos = 0;
    final n = bytes.length;

    void flush() {
      if (text.isEmpty) return;
      out.add(RtfText(text.toString()));
      text.clear();
    }

    void emitChar(int unit) {
      if (skip > 0) {
        skip--;
        return;
      }
      text.writeCharCode(unit);
    }

    void control(RtfControl c) {
      if (skip > 0) {
        skip--;
        return;
      }
      flush();
      out.add(c);
    }

    while (pos < n) {
      final b = bytes[pos];
      switch (b) {
        case 0x7B: // {
          pos++;
          skip = 0;
          flush();
          out.add(const RtfGroupStart());
          stack.add(_Scope.copy(stack.last));
        case 0x7D: // }
          pos++;
          skip = 0;
          flush();
          out.add(const RtfGroupEnd());
          if (stack.length > 1) stack.removeLast();
        case 0x0D || 0x0A:
          pos++;
        case 0x5C: // backslash
          pos++;
          if (pos >= n) break;
          final c = bytes[pos];
          if (_isLetter(c)) {
            final start = pos;
            while (pos < n && _isLetter(bytes[pos]) && pos - start < 32) {
              pos++;
            }
            final word = String.fromCharCodes(bytes, start, pos);
            int? param;
            var neg = false;
            if (pos < n && bytes[pos] == 0x2D && pos + 1 < n) {
              if (_isDigit(bytes[pos + 1])) {
                neg = true;
                pos++;
              }
            }
            if (pos < n && _isDigit(bytes[pos])) {
              var v = 0;
              var digits = 0;
              while (pos < n && _isDigit(bytes[pos])) {
                if (digits < 10) v = v * 10 + (bytes[pos] - 0x30);
                digits++;
                pos++;
              }
              param = neg ? -v : v;
            }
            if (pos < n && bytes[pos] == 0x20) pos++;
            final scope = stack.last;
            switch (word) {
              case 'u' when param != null:
                if (skip > 0) {
                  skip--;
                  break;
                }
                var unit = param;
                if (unit < 0) unit += 0x10000;
                if (unit >= 0 && unit <= 0xFFFF) text.writeCharCode(unit);
                skip = scope.uc;
              case 'uc':
                scope.uc = (param ?? 1).clamp(0, 16);
              case 'bin':
                final len = (param ?? 0).clamp(0, n - pos);
                if (skip > 0) {
                  // A binary run counts as one fallback character.
                  skip--;
                } else {
                  flush();
                  out.add(
                    RtfBinary(
                      Uint8List.fromList(bytes.sublist(pos, pos + len)),
                    ),
                  );
                }
                pos += len;
              case 'ansicpg' when param != null:
                _ansiCodePage = param;
                if (CodePage.forNumber(param) == null) {
                  unsupportedCodePages.add(param);
                }
                control(RtfControl(word, param));
              case 'deff' when param != null:
                _defaultFont = param;
                control(RtfControl(word, param));
              case 'f' when param != null:
                scope.font = param;
                control(RtfControl(word, param));
              case 'fcharset' when param != null:
                final cp = CodePage.numberForCharset(param);
                if (cp != null) _fontCodePages[scope.font] = cp;
                control(RtfControl(word, param));
              case 'cpg' when param != null:
                _fontCodePages[scope.font] = param;
                control(RtfControl(word, param));
              case 'plain':
                scope.font = _defaultFont;
                control(RtfControl(word, param));
              default:
                control(RtfControl(word, param));
            }
          } else {
            pos++;
            switch (c) {
              case 0x5C || 0x7B || 0x7D:
                emitChar(c);
              case 0x27: // \'hh
                final hi = pos < n ? _hex(bytes[pos]) : -1;
                final lo = pos + 1 < n ? _hex(bytes[pos + 1]) : -1;
                if (hi >= 0 && lo >= 0) {
                  pos += 2;
                  emitChar(_decodeByte(hi * 16 + lo, stack.last.font));
                } else if (hi >= 0) {
                  pos += 1;
                  emitChar(_decodeByte(hi, stack.last.font));
                }
              case 0x7E: // \~
                emitChar(0xA0);
              case 0x5F: // \_
                emitChar(0x2011);
              case 0x2D: // \- optional hyphen
                if (skip > 0) skip--;
              case 0x0D || 0x0A:
                control(const RtfControl('par'));
              case 0x09:
                control(const RtfControl('tab'));
              default:
                control(RtfControl(String.fromCharCode(c), null, true));
            }
          }
        case 0x09:
          pos++;
          control(const RtfControl('tab'));
        default:
          pos++;
          if (b < 0x20) break;
          emitChar(b < 0x80 ? b : _decodeByte(b, stack.last.font));
      }
    }
    flush();
    return out;
  }

  int _decodeByte(int byte, int font) {
    final cpNumber = _fontCodePages[font] ?? _ansiCodePage;
    var cp = CodePage.forNumber(cpNumber);
    if (cp == null) {
      unsupportedCodePages.add(cpNumber);
      cp = CodePage.windows1252;
    }
    return cp.decodeByte(byte);
  }

  static bool _isLetter(int c) =>
      (c >= 0x61 && c <= 0x7A) || (c >= 0x41 && c <= 0x5A);

  static bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

  static int _hex(int c) {
    if (c >= 0x30 && c <= 0x39) return c - 0x30;
    if (c >= 0x61 && c <= 0x66) return c - 0x61 + 10;
    if (c >= 0x41 && c <= 0x46) return c - 0x41 + 10;
    return -1;
  }
}
