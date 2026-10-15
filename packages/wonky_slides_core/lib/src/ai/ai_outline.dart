import 'dart:convert';

/// The role of a slide in an AI outline (Slides 11 §6.4, `propose_outline`):
/// the build maps it to a layout of the deck's theme.
enum AiSlideRole {
  title('title'),
  section('section'),
  agenda('agenda'),
  bullets('titleBody'),
  twoColumn('twoColumns'),
  quote('quote'),
  bigNumber('bigNumber'),
  imageText('imageRight'),
  code('code'),
  chartPlaceholder('chart'),
  closing('title');

  const AiSlideRole(this.layoutKey);

  /// The built-in layout key the role builds with (05 §4).
  final String layoutKey;

  /// The role named [name] (null when unknown).
  static AiSlideRole? fromName(Object? name) {
    for (final r in values) {
      if (r.name == name) return r;
    }
    return null;
  }
}

/// A bullet of an outline slide, with sub-bullets.
class AiOutlineBullet {
  AiOutlineBullet(this.text, [List<AiOutlineBullet>? children])
    : children = children ?? [];

  /// Inline Markdown.
  String text;
  final List<AiOutlineBullet> children;

  /// A bullet from the model's JSON: a string or `{text, children}`.
  static AiOutlineBullet? fromJson(Object? json, {int depth = 0}) {
    if (json is String) {
      final t = json.trim();
      return t.isEmpty ? null : AiOutlineBullet(t);
    }
    if (json is! Map) return null;
    final text = '${json['text'] ?? ''}'.trim();
    if (text.isEmpty) return null;
    return AiOutlineBullet(text, [
      if (depth < 2)
        for (final c in (json['children'] as List?) ?? const [])
          ?fromJson(c, depth: depth + 1),
    ]);
  }

  Object toJson() => children.isEmpty
      ? text
      : {
          'text': text,
          'children': [for (final c in children) c.toJson()],
        };

  AiOutlineBullet copy() =>
      AiOutlineBullet(text, [for (final c in children) c.copy()]);
}

/// One slide of an AI outline.
class AiOutlineSlide {
  AiOutlineSlide({
    required this.title,
    this.role = AiSlideRole.bullets,
    List<AiOutlineBullet>? bullets,
    this.notes,
    this.codeLanguage,
    this.code,
    this.emphasis,
  }) : bullets = bullets ?? [];

  String title;
  AiSlideRole role;
  final List<AiOutlineBullet> bullets;

  /// Speaker notes (Markdown).
  String? notes;

  /// Role `code`: the fenced block.
  String? codeLanguage;
  String? code;

  /// Role `bigNumber`: the number ("4,200"); `quote`: unused.
  String? emphasis;

  static AiOutlineSlide? fromJson(Object? json) {
    if (json is! Map) return null;
    final title = '${json['title'] ?? ''}'.trim();
    final role = AiSlideRole.fromName(json['role']) ?? AiSlideRole.bullets;
    final code = json['code'];
    String? notes = '${json['notes'] ?? ''}'.trim();
    if (notes.isEmpty) notes = null;
    String? emphasis = '${json['emphasis'] ?? ''}'.trim();
    if (emphasis.isEmpty) emphasis = null;
    return AiOutlineSlide(
      title: title,
      role: role,
      bullets: [
        for (final b in (json['bullets'] as List?) ?? const [])
          ?AiOutlineBullet.fromJson(b),
      ],
      notes: notes,
      codeLanguage: code is Map ? '${code['language'] ?? ''}'.trim() : null,
      code: code is Map ? '${code['code'] ?? ''}' : null,
      emphasis: emphasis,
    );
  }

  Map<String, Object?> toJson() => {
    'title': title,
    'role': role.name,
    'bullets': [for (final b in bullets) b.toJson()],
    'notes': ?notes,
    if (code != null) 'code': {'language': codeLanguage ?? '', 'code': code},
    'emphasis': ?emphasis,
  };

  AiOutlineSlide copy() => AiOutlineSlide(
    title: title,
    role: role,
    bullets: [for (final b in bullets) b.copy()],
    notes: notes,
    codeLanguage: codeLanguage,
    code: code,
    emphasis: emphasis,
  );
}

/// A group (section) of an AI outline; [title] null = ungrouped slides.
class AiOutlineGroup {
  AiOutlineGroup({this.title, List<AiOutlineSlide>? slides})
    : slides = slides ?? [];

  String? title;
  final List<AiOutlineSlide> slides;

  Map<String, Object?> toJson() => {
    'title': ?title,
    'slides': [for (final s in slides) s.toJson()],
  };
}

/// Options of [AiOutline.toDeckMarkdown].
class AiOutlineBuildOptions {
  const AiOutlineBuildOptions({
    this.titleSlide = true,
    this.groups = true,
    this.notes = true,
    this.transition = 'fade',
  });

  /// Starts with a title slide from the outline's title and subtitle (new
  /// presentations; off when inserting into a deck).
  final bool titleSlide;

  /// Groups become slide groups (sections).
  final bool groups;

  /// Speaker notes are written.
  final bool notes;

  /// The transition of every new slide (null = none).
  final String? transition;
}

/// The outline of an AI-generated presentation (Slides 11 §6.4): the
/// strict `propose_outline` answer, edited in the Generate dialog, built
/// deterministically into deck-outline Markdown (11 §3.3) — no model call —
/// which `slides.add_slides_from_markdown` / `drive.create_presentation`
/// turn into themed slides (roles → layout keys, groups, notes, code).
class AiOutline {
  AiOutline({required this.title, this.subtitle, List<AiOutlineGroup>? groups})
    : groups = groups ?? [];

  String title;
  String? subtitle;
  final List<AiOutlineGroup> groups;

  /// Most slides an outline may have (`slides.add_slides` limit).
  static const maxSlides = 100;

  /// Every slide, in order.
  Iterable<AiOutlineSlide> get slides => [for (final g in groups) ...g.slides];

  int get slideCount => slides.length;

  /// Parses the model's `propose_outline` input (or [toJson]) leniently:
  /// unknown roles become `bullets`, empty bullets and slides without a
  /// title or content are dropped, at most [maxSlides] slides are kept.
  static AiOutline fromJson(Map<String, Object?> json) {
    final out = AiOutline(
      title: '${json['title'] ?? ''}'.trim(),
      subtitle: switch ('${json['subtitle'] ?? ''}'.trim()) {
        '' => null,
        final s => s,
      },
    );
    var n = 0;
    void add(String? title, Object? slides) {
      final g = AiOutlineGroup(
        title: title == null || title.trim().isEmpty ? null : title.trim(),
      );
      for (final s in (slides as List?) ?? const []) {
        if (n >= maxSlides) break;
        final slide = AiOutlineSlide.fromJson(s);
        if (slide == null) continue;
        if (slide.title.isEmpty &&
            slide.bullets.isEmpty &&
            slide.code == null &&
            slide.emphasis == null) {
          continue;
        }
        g.slides.add(slide);
        n++;
      }
      if (g.slides.isNotEmpty) out.groups.add(g);
    }

    final groups = json['groups'];
    if (groups is List) {
      for (final g in groups) {
        if (g is Map) add(g['title'] as String?, g['slides']);
      }
    }
    final flat = json['slides'];
    if (flat is List) add(null, flat);
    return out;
  }

  /// [fromJson] of a JSON text (null when it is not an object).
  static AiOutline? tryDecode(String? text) {
    if (text == null) return null;
    try {
      final j = jsonDecode(text);
      return j is Map ? fromJson(j.cast<String, Object?>()) : null;
    } on FormatException {
      return null;
    }
  }

  Map<String, Object?> toJson() => {
    'title': title,
    'subtitle': ?subtitle,
    'groups': [for (final g in groups) g.toJson()],
  };

  String encode() => jsonEncode(toJson());

  AiOutline copy() =>
      fromJson((jsonDecode(encode()) as Map).cast<String, Object?>());

  /// The deck outline Markdown (11 §3.3) of this outline: one slide per
  /// outline slide with a `layout:` directive from its role, `group:`
  /// directives for groups, `Notes:` and fenced code. Text that would be
  /// read as outline syntax (separators, directives, fences) is escaped,
  /// so generated text can never add slides or directives.
  String toDeckMarkdown([
    AiOutlineBuildOptions options = const AiOutlineBuildOptions(),
  ]) {
    final parts = <String>[];
    if (options.titleSlide && title.trim().isNotEmpty) {
      final b = StringBuffer()
        ..writeln('<!-- deck: title="${_attr(title)}" -->')
        ..writeln('<!-- layout: title -->');
      if (options.groups && groups.any((g) => g.title != null)) {
        b.writeln('<!-- group: none -->');
      }
      if (options.transition != null) {
        b.writeln('<!-- transition: ${options.transition} -->');
      }
      b.writeln('# ${_line(title)}');
      if (subtitle != null) b.writeln(_line(subtitle!));
      parts.add(b.toString().trimRight());
    }
    var grouped = false;
    for (final g in groups) {
      for (final (i, s) in g.slides.indexed) {
        final b = StringBuffer();
        if (options.groups && i == 0) {
          if (g.title != null) {
            b.writeln('<!-- group: ${_line(g.title!)} -->');
            grouped = true;
          } else if (grouped) {
            b.writeln('<!-- group: none -->');
            grouped = false;
          }
        }
        b.writeln('<!-- layout: ${s.role.layoutKey} -->');
        if (options.transition != null) {
          b.writeln('<!-- transition: ${options.transition} -->');
        }
        if (s.title.trim().isNotEmpty) b.writeln('## ${_line(s.title)}');
        b.write(_body(s));
        if (options.notes && (s.notes ?? '').trim().isNotEmpty) {
          b.writeln('Notes:');
          for (final l in s.notes!.trim().split('\n')) {
            b.writeln(_escape(l));
          }
        }
        parts.add(b.toString().trimRight());
      }
    }
    return '${parts.join('\n---\n')}\n';
  }

  static String _body(AiOutlineSlide s) {
    final b = StringBuffer();
    void bullets(List<AiOutlineBullet> list, [int depth = 0]) {
      for (final x in list) {
        b.writeln('${'  ' * depth}- ${_line(x.text)}');
        bullets(x.children, depth + 1);
      }
    }

    switch (s.role) {
      case AiSlideRole.bigNumber:
        final number = s.emphasis ?? s.bullets.firstOrNull?.text;
        final rest = s.emphasis == null ? s.bullets.skip(1) : s.bullets;
        if (number != null) {
          b.writeln(_line(number));
          final caption = [for (final x in rest) _line(x.text)].join(' ');
          if (caption.isNotEmpty) b.writeln(caption);
        }
      case AiSlideRole.quote:
        if (s.bullets.isNotEmpty) {
          b.writeln('> ${_line(s.emphasis ?? s.bullets.first.text)}');
          final by = s.emphasis == null
              ? s.bullets.skip(1).firstOrNull
              : s.bullets.firstOrNull;
          if (by != null) b.writeln('— ${_line(by.text)}');
        } else if (s.emphasis != null) {
          b.writeln('> ${_line(s.emphasis!)}');
        }
      case AiSlideRole.twoColumn:
        final half = (s.bullets.length + 1) ~/ 2;
        bullets(s.bullets.sublist(0, half));
        if (s.bullets.length > half) {
          b.writeln('|||');
          bullets(s.bullets.sublist(half));
        }
      case AiSlideRole.title || AiSlideRole.closing || AiSlideRole.section:
        // A subtitle line (the first bullet, plain).
        if (s.bullets.isNotEmpty) b.writeln(_line(s.bullets.first.text));
      case AiSlideRole.code:
        bullets(s.bullets);
        if (s.code != null && s.code!.trim().isNotEmpty) {
          final fence = s.code!.contains('```') ? '~~~~' : '```';
          final lang = (s.codeLanguage ?? '').replaceAll(RegExp(r'\s'), '');
          b
            ..writeln('$fence$lang')
            ..writeln(s.code!.trimRight())
            ..writeln(fence);
        }
      default:
        bullets(s.bullets);
    }
    return b.toString();
  }

  /// One line of text: newlines folded, outline syntax escaped.
  static String _line(String s) =>
      _escape(s.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim());

  static final _syntax = RegExp(r'^\s*(---+\s*$|<!--|```|~~~|\|\|\||\?\?\?$)');

  static String _escape(String line) {
    if (!_syntax.hasMatch(line)) {
      return line.trim() == 'Notes:' ? '\\$line' : line;
    }
    final t = line.trimLeft();
    return '\\$t';
  }

  static String _attr(String s) =>
      _line(s).replaceAll(r'\', r'\\').replaceAll('"', r'\"');
}
