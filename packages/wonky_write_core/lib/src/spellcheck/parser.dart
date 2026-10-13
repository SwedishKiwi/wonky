part of 'hunspell.dart';

final RegExp _whitespace = RegExp(r'\s+');

/// Line-by-line `.aff` + `.dic` parser that can be suspended between chunks.
final class _Parser {
  _Parser(String aff, String dic)
    : _aff = _stripBom(aff),
      _dic = _stripBom(dic),
      dictionary = HunspellDictionary._();

  final String _aff;
  final String _dic;
  final HunspellDictionary dictionary;

  int _affPos = 0;
  int _dicPos = 0;
  bool _affDone = false;
  bool _dicFirstLine = true;
  bool done = false;

  final Set<String> _tablesSeen = {};
  final Map<String, (bool, int)> _affixHeaders = {};
  final List<_Affix> _prefixes = [];
  final List<_Affix> _suffixes = [];

  double get progress {
    final total = _aff.length + _dic.length;
    if (done || total == 0) return 1;
    final p =
        (math.min(_affPos, _aff.length) + math.min(_dicPos, _dic.length)) /
        total;
    return p > 1 ? 1 : p;
  }

  /// Parses chunks until done or until [timeUp] (checked after each chunk of
  /// 64 `.aff` / 256 `.dic` lines) returns true. Returns whether done.
  bool run(bool Function()? timeUp) {
    while (!done) {
      if (!_affDone) {
        for (var i = 0; i < 64 && !_affDone; i++) {
          _affLine();
        }
        if (_affDone) _finishAff();
      } else {
        for (var i = 0; i < 256 && _dicPos < _dic.length; i++) {
          _dicLine();
        }
        if (_dicPos >= _dic.length) done = true;
      }
      if (!done && timeUp != null && timeUp()) return false;
    }
    return true;
  }

  // ---------------------------------------------------------------- .aff

  void _affLine() {
    final s = _aff;
    if (_affPos >= s.length) {
      _affDone = true;
      return;
    }
    var end = s.indexOf('\n', _affPos);
    if (end < 0) end = s.length;
    final line = s.substring(_affPos, end);
    _affPos = end + 1;
    if (_affPos >= s.length) _affDone = true;
    _parseAffLine(line);
  }

  bool _isHeader(String key, List<String> f) {
    final first = _tablesSeen.add(key);
    return first &&
        f.length >= 2 &&
        _isDigits(f[1]) &&
        (f.length == 2 || f[2].startsWith('#'));
  }

  void _parseAffLine(String line) {
    final t = line.trim();
    if (t.isEmpty || t.startsWith('#')) return;
    final f = t.split(_whitespace);
    final key = f[0];
    final a1 = f.length > 1 ? f[1] : '';
    final d = dictionary;
    final flags = d._flags;
    switch (key) {
      case 'SET':
        d._encoding = a1;
      case 'FLAG':
        flags.mode = switch (a1.toLowerCase()) {
          'long' => _FlagMode.long,
          'num' => _FlagMode.number,
          'utf-8' || 'utf8' => _FlagMode.utf8,
          _ => _FlagMode.single,
        };
      case 'LANG':
        d._language = a1;
      case 'TRY':
        d._try = a1;
      case 'WORDCHARS':
        d._wordChars = a1;
      case 'KEY':
        d._key = a1;
      case 'IGNORE':
        d._ignore = a1;
      case 'AF':
        if (_isHeader(key, f)) {
          flags.aliases ??= [];
        } else if (a1.isNotEmpty) {
          (flags.aliases ??= []).add(flags.raw(a1));
        }
      case 'REP':
        if (!_isHeader(key, f) && f.length >= 3) {
          d._reps.add(_Rep.parse(f[1], f[2]));
        }
      case 'MAP':
        if (!_isHeader(key, f) && a1.isNotEmpty) d._maps.add(_mapGroup(a1));
      case 'ICONV':
        if (!_isHeader(key, f) && f.length >= 3) d._iconv.add(f[1], f[2]);
      case 'OCONV':
        if (!_isHeader(key, f) && f.length >= 3) d._oconv.add(f[1], f[2]);
      case 'BREAK':
        if (_isHeader(key, f)) {
          d._breaks = [];
        } else if (a1.isNotEmpty) {
          if (identical(d._breaks, const ['-', '^-', r'-$'])) d._breaks = [];
          d._breaks.add(a1);
        }
      case 'PFX' || 'SFX':
        _affix(key == 'PFX', f);
      case 'NEEDAFFIX' || 'PSEUDOROOT':
        d._needAffix = flags.one(a1);
      case 'FORBIDDENWORD':
        d._forbidden = flags.one(a1);
      case 'KEEPCASE':
        d._keepCase = flags.one(a1);
      case 'NOSUGGEST':
        d._noSuggest = flags.one(a1);
      case 'ONLYINCOMPOUND':
        d._onlyInCompound = flags.one(a1);
      case 'CIRCUMFIX':
        d._circumfix = flags.one(a1);
      case 'COMPOUNDFLAG':
        d._compoundFlag = flags.one(a1);
      case 'COMPOUNDBEGIN':
        d._compoundBegin = flags.one(a1);
      case 'COMPOUNDMIDDLE':
        d._compoundMiddle = flags.one(a1);
      case 'COMPOUNDLAST' || 'COMPOUNDEND':
        d._compoundLast = flags.one(a1);
      case 'COMPOUNDPERMITFLAG':
        d._compoundPermit = flags.one(a1);
      case 'COMPOUNDFORBIDFLAG':
        d._compoundForbid = flags.one(a1);
      case 'FORCEUCASE':
        d._forceUcase = flags.one(a1);
      case 'COMPOUNDMIN':
        d._compoundMin = math.max(1, int.tryParse(a1) ?? 3);
      case 'COMPOUNDWORDMAX':
        d._compoundWordMax = int.tryParse(a1) ?? 0;
      case 'COMPOUNDRULE':
        if (!_isHeader(key, f) && a1.isNotEmpty) {
          final rule = flags.rule(a1);
          if (rule != null) {
            d._rules.add(rule);
            d._ruleFlags.addAll(rule.flags);
          }
        }
      case 'CHECKCOMPOUNDDUP':
        d._checkCompoundDup = true;
      case 'CHECKCOMPOUNDTRIPLE':
        d._checkCompoundTriple = true;
      case 'CHECKCOMPOUNDCASE':
        d._checkCompoundCase = true;
      case 'CHECKCOMPOUNDREP':
        d._checkCompoundRep = true;
      case 'CHECKCOMPOUNDPATTERN':
        if (!_isHeader(key, f) && f.length >= 3) {
          // Patterns with a replacement (simplified compounds) are skipped.
          if (f.length >= 4 && !f[3].startsWith('#')) return;
          final (end, endFlag) = _patternPart(f[1]);
          final (begin, beginFlag) = _patternPart(f[2]);
          d._compoundPatterns.add(
            _CompoundPattern(end, endFlag, begin, beginFlag),
          );
        }
      case 'NOSPLITSUGS':
        d._noSplitSugs = true;
      case 'FULLSTRIP':
        d._fullStrip = true;
      case 'MAXNGRAMSUGS':
        d._maxNgramSugs = int.tryParse(a1) ?? d._maxNgramSugs;
      case 'MAXCPDSUGS':
        d._maxCompoundSugs = int.tryParse(a1) ?? d._maxCompoundSugs;
      default:
      // Unknown or unsupported directives (AM, WARN, MAXDIFF, …) are ignored.
    }
  }

  (String, int) _patternPart(String s) {
    final slash = s.indexOf('/');
    var text = slash < 0 ? s : s.substring(0, slash);
    if (text == '0') text = '';
    final flag = slash < 0 ? 0 : dictionary._flags.one(s.substring(slash + 1));
    return (text, flag);
  }

  List<String> _mapGroup(String s) {
    final out = <String>[];
    var i = 0;
    while (i < s.length) {
      if (s[i] == '(') {
        final close = s.indexOf(')', i + 1);
        if (close > i + 1) {
          out.add(s.substring(i + 1, close));
          i = close + 1;
          continue;
        }
      }
      final n = _isHighSurrogate(s.codeUnitAt(i)) && i + 1 < s.length ? 2 : 1;
      out.add(s.substring(i, i + n));
      i += n;
    }
    return out;
  }

  void _affix(bool isPrefix, List<String> f) {
    if (f.length < 4) return;
    final d = dictionary;
    final key = '${f[0]}\u0000${f[1]}';
    final header = _affixHeaders[key];
    if ((header == null || header.$2 <= 0) &&
        (f[2] == 'Y' || f[2] == 'N') &&
        _isDigits(f[3])) {
      _affixHeaders[key] = (f[2] == 'Y', int.parse(f[3]));
      return;
    }
    if (header != null) _affixHeaders[key] = (header.$1, header.$2 - 1);
    var strip = f[2] == '0' ? '' : f[2];
    var append = f[3];
    var cont = '';
    final slash = append.indexOf('/');
    if (slash >= 0) {
      cont = append.substring(slash + 1);
      append = append.substring(0, slash);
    }
    if (append == '0') append = '';
    if (d._ignore.isNotEmpty) {
      strip = _removeChars(strip, d._ignore);
      append = _removeChars(append, d._ignore);
    }
    final affix = _Affix(
      isPrefix: isPrefix,
      flag: d._flags.one(f[1]),
      cross: header?.$1 ?? true,
      strip: strip,
      append: append,
      cont: d._flags.set(cont),
      cond: _Condition.parse(f.length > 4 ? f[4] : '.'),
    );
    (isPrefix ? _prefixes : _suffixes).add(affix);
  }

  void _finishAff() {
    final d = dictionary;
    for (final p in _prefixes) {
      d._prefixes.putIfAbsent(p.append, () => []).add(p);
      d._prefixesByFlag.putIfAbsent(p.flag, () => []).add(p);
      d._maxPrefixLen = math.max(d._maxPrefixLen, p.append.length);
    }
    final suffixFlags = <int>{};
    for (final s in _suffixes) {
      d._suffixes.putIfAbsent(s.append, () => []).add(s);
      d._suffixesByFlag.putIfAbsent(s.flag, () => []).add(s);
      d._maxSuffixLen = math.max(d._maxSuffixLen, s.append.length);
      suffixFlags.add(s.flag);
      if (s.cross) d._hasCrossSuffix = true;
    }
    for (final s in _suffixes) {
      for (final f in s.cont.ids) {
        if (suffixFlags.contains(f)) d._twofoldFlags.add(f);
      }
    }
  }

  // ---------------------------------------------------------------- .dic

  void _dicLine() {
    final s = _dic;
    var end = s.indexOf('\n', _dicPos);
    if (end < 0) end = s.length;
    final start = _dicPos;
    _dicPos = end + 1;
    if (end > start && s.codeUnitAt(end - 1) == 0x0D) end--;
    if (end == start) return;
    if (!_dicFirstLine) {
      // Fast path for plain `word` / `word/flags` lines (no allocation of
      // the whole line).
      var slash = -1;
      var plain = true;
      for (var i = start; i < end; i++) {
        final c = s.codeUnitAt(i);
        if (c == 0x2F) {
          if (slash < 0 && i > start) slash = i;
        } else if (c == 0x09 || c == 0x20 || c == 0x5C) {
          plain = false;
          break;
        }
      }
      final d = dictionary;
      if (plain && d._ignore.isEmpty) {
        final word = s.substring(start, slash < 0 ? end : slash);
        final flags = slash < 0 ? '' : s.substring(slash + 1, end);
        d._addWord(word, d._flags.set(flags));
        return;
      }
    }
    _dicSlowLine(s.substring(start, end));
  }

  void _dicSlowLine(String line) {
    if (_dicFirstLine) {
      _dicFirstLine = false;
      if (_isDigits(line.trim())) return;
    }
    final tab = line.indexOf('\t');
    if (tab >= 0) line = line.substring(0, tab);
    // Morphological fields (` po:noun`) start after a space.
    var sp = line.indexOf(' ');
    while (sp >= 0) {
      if (sp + 3 < line.length &&
          line.codeUnitAt(sp + 3) == 0x3A &&
          line.codeUnitAt(sp + 1) != 0x20 &&
          line.codeUnitAt(sp + 2) != 0x20) {
        line = line.substring(0, sp);
        break;
      }
      sp = line.indexOf(' ', sp + 1);
    }
    line = line.trim();
    if (line.isEmpty) return;
    var slash = line.indexOf('/', 1);
    while (slash > 0 && line.codeUnitAt(slash - 1) == 0x5C) {
      slash = line.indexOf('/', slash + 1);
    }
    var word = slash < 0 ? line : line.substring(0, slash);
    final flagText = slash < 0 ? '' : line.substring(slash + 1).trim();
    if (word.contains(r'\')) word = word.replaceAll(r'\/', '/');
    final d = dictionary;
    if (d._ignore.isNotEmpty) word = _removeChars(word, d._ignore);
    if (word.isEmpty) return;
    d._addWord(word, d._flags.set(flagText));
  }
}

String _stripBom(String s) =>
    s.isNotEmpty && s.codeUnitAt(0) == 0xFEFF ? s.substring(1) : s;
