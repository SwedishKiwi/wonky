/// Fields of the custom date and time builder (06 §5.6, 04 §11.3).
enum DtField {
  day,
  weekday,
  month,
  year,
  hour,
  minute,
  second,
  millisecond,
  ampm,
  elapsedHours,
  elapsedMinutes,
  elapsedSeconds;

  /// The representations (pattern tokens) a field offers, default first.
  List<String> get tokens => switch (this) {
    day => const ['d', 'dd'],
    weekday => const ['ddd', 'dddd'],
    month => const ['m', 'mm', 'mmm', 'mmmm', 'mmmmm'],
    year => const ['yy', 'yyyy'],
    hour => const ['h', 'hh'],
    minute => const ['mm', 'm'],
    second => const ['ss', 's'],
    millisecond => const ['.000', '.00', '.0'],
    ampm => const ['AM/PM', 'am/pm', 'A/P', 'a/p'],
    elapsedHours => const ['[h]', '[hh]'],
    elapsedMinutes => const ['[mm]', '[m]'],
    elapsedSeconds => const ['[ss]', '[s]'],
  };
}

/// One chip of the builder: a date/time token or literal text.
class DtPart {
  const DtPart.token(DtField this.field, this.text);
  const DtPart.literal(this.text) : field = null;

  /// Null for literal text.
  final DtField? field;

  /// The token (`mmm`) or the literal text (unquoted).
  final String text;

  bool get isLiteral => field == null;

  @override
  bool operator ==(Object other) =>
      other is DtPart && other.field == field && other.text == text;

  @override
  int get hashCode => Object.hash(field, text);

  @override
  String toString() => isLiteral ? 'lit($text)' : '${field!.name}($text)';
}

/// Converts between date/time patterns and builder chips.
abstract final class DateTimePatternCodec {
  /// Parses [pattern] (first section) into chips. `m` runs become minutes
  /// right after an hour (skipping literals) or right before seconds
  /// (06 §5.6), months otherwise.
  static List<DtPart> parse(String pattern) {
    final section = _firstSection(pattern);
    final raw = <DtPart>[];
    final lit = StringBuffer();
    void flush() {
      if (lit.isEmpty) return;
      raw.add(DtPart.literal(lit.toString()));
      lit.clear();
    }

    var i = 0;
    while (i < section.length) {
      final ch = section[i];
      final lower = ch.toLowerCase();
      if (ch == '"') {
        final end = section.indexOf('"', i + 1);
        lit.write(section.substring(i + 1, end < 0 ? section.length : end));
        i = end < 0 ? section.length : end + 1;
        continue;
      }
      if (ch == r'\' && i + 1 < section.length) {
        lit.write(section[i + 1]);
        i += 2;
        continue;
      }
      if (ch == '[') {
        final end = section.indexOf(']', i);
        if (end > i) {
          final inner = section.substring(i + 1, end).toLowerCase();
          final field = switch (inner.isEmpty ? '' : inner[0]) {
            'h' when RegExp(r'^h+$').hasMatch(inner) => DtField.elapsedHours,
            'm' when RegExp(r'^m+$').hasMatch(inner) => DtField.elapsedMinutes,
            's' when RegExp(r'^s+$').hasMatch(inner) => DtField.elapsedSeconds,
            _ => null,
          };
          if (field != null) {
            flush();
            raw.add(DtPart.token(field, '[$inner]'));
          }
          // Colors, conditions and locale tags are dropped by the builder.
          i = end + 1;
          continue;
        }
      }
      final rest = section.substring(i);
      final ampm = RegExp(
        r'^(AM/PM|am/pm|A/P|a/p)',
        caseSensitive: false,
      ).firstMatch(rest);
      if (ampm != null) {
        flush();
        final t = ampm.group(0)!;
        final canonical = DtField.ampm.tokens.firstWhere(
          (x) => x == t,
          orElse: () => t.length == 5 ? 'AM/PM' : 'A/P',
        );
        raw.add(DtPart.token(DtField.ampm, canonical));
        i += t.length;
        continue;
      }
      if ('dmyhs'.contains(lower)) {
        var j = i;
        while (j < section.length && section[j].toLowerCase() == lower) {
          j++;
        }
        final n = j - i;
        flush();
        switch (lower) {
          case 'd':
            raw.add(
              n >= 3
                  ? DtPart.token(DtField.weekday, n == 3 ? 'ddd' : 'dddd')
                  : DtPart.token(DtField.day, 'd' * n),
            );
          case 'y':
            raw.add(DtPart.token(DtField.year, n <= 2 ? 'yy' : 'yyyy'));
          case 'h':
            raw.add(DtPart.token(DtField.hour, n == 1 ? 'h' : 'hh'));
          case 's':
            raw.add(DtPart.token(DtField.second, n == 1 ? 's' : 'ss'));
          default:
            raw.add(DtPart.token(DtField.month, 'm' * (n > 5 ? 5 : n)));
        }
        i = j;
        continue;
      }
      if (ch == '.' &&
          raw.isNotEmpty &&
          raw.last.field == DtField.second &&
          lit.isEmpty &&
          i + 1 < section.length &&
          section[i + 1] == '0') {
        var j = i + 1;
        while (j < section.length && section[j] == '0' && j - i <= 3) {
          j++;
        }
        raw.add(DtPart.token(DtField.millisecond, '.${'0' * (j - i - 1)}'));
        i = j;
        continue;
      }
      lit.write(ch);
      i++;
    }
    flush();
    return _resolveMinutes(raw);
  }

  /// Month tokens of length ≤ 2 after an hour or before a second → minutes.
  static List<DtPart> _resolveMinutes(List<DtPart> parts) {
    final out = [...parts];
    for (var i = 0; i < out.length; i++) {
      final p = out[i];
      if (p.field != DtField.month || p.text.length > 2) continue;
      DtField? prev;
      for (var k = i - 1; k >= 0; k--) {
        if (!out[k].isLiteral) {
          prev = out[k].field;
          break;
        }
      }
      DtField? next;
      for (var k = i + 1; k < out.length; k++) {
        if (!out[k].isLiteral) {
          next = out[k].field;
          break;
        }
      }
      if (prev == DtField.hour ||
          prev == DtField.elapsedHours ||
          next == DtField.second) {
        out[i] = DtPart.token(DtField.minute, p.text);
      }
    }
    return out;
  }

  static String _firstSection(String p) {
    var inQuote = false;
    for (var i = 0; i < p.length; i++) {
      final c = p[i];
      if (c == '"') inQuote = !inQuote;
      if (c == r'\') {
        i++;
        continue;
      }
      if (c == ';' && !inQuote) return p.substring(0, i);
    }
    return p;
  }

  static final RegExp _plainLiteral = RegExp(r'^[ /\-:,()]+$');

  /// Builds the pattern of [parts]. Literals that could be read as tokens
  /// are quoted.
  static String build(List<DtPart> parts) {
    final b = StringBuffer();
    for (final p in parts) {
      if (p.isLiteral) {
        if (p.text.isEmpty) continue;
        if (_plainLiteral.hasMatch(p.text)) {
          b.write(p.text);
        } else {
          b.write('"${p.text.replaceAll('"', '')}"');
        }
      } else {
        b.write(p.text);
      }
    }
    return b.toString();
  }
}

/// Date/time presets of the custom date and time dialog (04 §11.3).
const dateTimePresets = [
  'm/d/yyyy',
  'm/d/yyyy h:mm:ss',
  'dddd, mmmm d, yyyy',
  'mmmm d, yyyy',
  'd-mmm-yyyy h:mm',
  'mmm d, yyyy h:mm AM/PM',
  'yyyy-mm-dd',
  'yyyy-mm-dd hh:mm:ss',
  'dd.mm.yyyy',
  'mmm-yy',
  'mmmm yyyy',
  'ddd d mmm',
  'h:mm AM/PM',
  'h:mm:ss',
  'hh:mm:ss.000',
  '[h]:mm:ss',
];
