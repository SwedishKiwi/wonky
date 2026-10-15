/// Reusable slide compositions of the built-in templates: cards, stats,
/// people, a timeline and a process flow, drawn with shapes and text
/// boxes in theme colors only (no images), so they follow every theme and
/// both appearances.
library;

import '../../ops/operations.dart';
import '../../theme/model/common.dart';
import '../template_builder.dart';
import '../template_text.dart';

/// Left edge of the content area (05 §4 design grid).
const double contentLeft = 120;

/// Width of the content area.
const double contentWidth = 1680;

/// Top of the content area below a `titleOnly` title.
const double contentTop = 288;

/// Splits the content width into [n] columns with [gap].
List<(double x, double w)> columns(int n, {double gap = 48}) {
  final w = (contentWidth - gap * (n - 1)) / n;
  return [for (var i = 0; i < n; i++) (contentLeft + i * (w + gap), w)];
}

/// The card background (rounded, `bg2`).
ElementSpec cardBox(SuRect r, {String fill = 'theme:bg2'}) =>
    TemplateShapes.shape(
      'roundRect',
      r,
      fill: fill,
      adjust: const {'radius': 0.08},
      decorative: true,
    );

/// A round badge with short bold [label] (a number, initials).
ElementSpec badge(
  double x,
  double y,
  String label, {
  double size = 104,
  String fill = 'theme:accent1',
  String color = 'theme:bg1',
}) => TemplateShapes.shape(
  'ellipse',
  SuRect(x, y, size, size),
  fill: fill,
  text: TemplatePara.runs([TemplateRun.bold(label)]),
  textColor: color,
  textStyle: 'heading',
  textSize: size * 0.4,
  insets: const [0, 0, 0, 0],
);

/// Cards in a row: a title and a text each, with an optional badge
/// (numbers 1…n when [numbered]).
List<ElementSpec> cards(
  List<(String title, String body)> items, {
  double top = contentTop + 32,
  double height = 520,
  bool numbered = true,
  List<String>? badges,
}) {
  final out = <ElementSpec>[];
  for (final (i, (x, w)) in columns(items.length).indexed) {
    final (title, body) = items[i];
    out.add(cardBox(SuRect(x, top, w, height)));
    final label = badges?[i] ?? (numbered ? '${i + 1}' : null);
    var y = top + 56;
    if (label != null) {
      out.add(badge(x + 56, y, label));
      y += 152;
    }
    out.add(
      TemplateShapes.text(
        SuRect(x + 56, y, w - 112, 80),
        title,
        textStyle: 'heading',
        size: 52,
        color: 'theme:text1',
        anchor: 'bottom',
      ),
    );
    out.add(
      TemplateShapes.text(
        SuRect(x + 56, y + 104, w - 112, top + height - y - 144),
        body,
        textStyle: 'body2',
        size: 36,
        color: 'theme:text2',
      ),
    );
  }
  return out;
}

/// Key figures in a row: a big number in the accent color over a label.
List<ElementSpec> stats(
  List<(String value, String label)> items, {
  double top = contentTop + 64,
  double height = 480,
}) {
  final out = <ElementSpec>[];
  for (final (i, (x, w)) in columns(items.length).indexed) {
    final (value, label) = items[i];
    out.add(cardBox(SuRect(x, top, w, height)));
    out.add(
      TemplateShapes.text(
        SuRect(x + 48, top + 72, w - 96, 200),
        TemplatePara.runs([TemplateRun.bold(value)]),
        textStyle: 'bigNumber',
        size: 128,
        color: 'theme:accent1',
        align: 'center',
        anchor: 'bottom',
      ),
    );
    out.add(
      TemplateShapes.text(
        SuRect(x + 48, top + 300, w - 96, height - 348),
        label,
        textStyle: 'body2',
        size: 36,
        color: 'theme:text2',
        align: 'center',
      ),
    );
  }
  return out;
}

/// People in a row: initials badge, name, role and a short line.
List<ElementSpec> people(
  List<(String initials, String name, String role, String line)> items, {
  double top = contentTop + 32,
  double height = 560,
}) {
  final out = <ElementSpec>[];
  for (final (i, (x, w)) in columns(items.length).indexed) {
    final (initials, name, role, line) = items[i];
    out.add(cardBox(SuRect(x, top, w, height)));
    out.add(badge(x + (w - 160) / 2, top + 56, initials, size: 160));
    out.add(
      TemplateShapes.text(
        SuRect(x + 40, top + 248, w - 80, 64),
        TemplatePara.runs([TemplateRun.bold(name)]),
        textStyle: 'heading',
        size: 40,
        color: 'theme:text1',
        align: 'center',
      ),
    );
    out.add(
      TemplateShapes.text(
        SuRect(x + 40, top + 320, w - 80, 48),
        role,
        textStyle: 'label',
        size: 26,
        color: 'theme:text2',
        align: 'center',
      ),
    );
    out.add(
      TemplateShapes.text(
        SuRect(x + 40, top + 396, w - 80, height - 436),
        line,
        textStyle: 'body2',
        size: 30,
        color: 'theme:text2',
        align: 'center',
      ),
    );
  }
  return out;
}

/// A horizontal timeline: a rule, a dot per milestone, the period above
/// and the milestone below.
List<ElementSpec> timeline(
  List<(String when, String what)> items, {
  double y = 600,
}) {
  final out = <ElementSpec>[
    TemplateShapes.line(
      contentLeft,
      y,
      contentLeft + contentWidth,
      y,
      color: 'theme:text2',
      width: 6,
    ),
  ];
  final step = contentWidth / items.length;
  for (final (i, (period, what)) in items.indexed) {
    final cx = contentLeft + step * (i + 0.5);
    out.add(
      TemplateShapes.shape(
        'ellipse',
        SuRect(cx - 28, y - 28, 56, 56),
        fill: 'theme:accent1',
        stroke: 'theme:bg1',
        strokeWidth: 8,
        decorative: true,
      ),
    );
    out.add(
      TemplateShapes.text(
        SuRect(cx - step / 2 + 16, y - 168, step - 32, 104),
        TemplatePara.runs([TemplateRun.bold(period)]),
        textStyle: 'heading',
        size: 56,
        color: 'theme:text1',
        align: 'center',
        anchor: 'bottom',
      ),
    );
    out.add(
      TemplateShapes.text(
        SuRect(cx - step / 2 + 16, y + 72, step - 32, 220),
        what,
        textStyle: 'body2',
        size: 34,
        color: 'theme:text2',
        align: 'center',
      ),
    );
  }
  return out;
}

/// A flow of rounded "pills" joined by [joints] (a `+`, or an arrow for
/// `null`): [items] are the pill texts; the last pill (the result) is
/// filled with the accent color.
List<ElementSpec> flow(
  List<String> items,
  List<String?> joints, {
  double y = 520,
  double height = 200,
  double jointWidth = 96,
}) {
  assert(joints.length == items.length - 1);
  final pillW = (contentWidth - jointWidth * joints.length) / items.length;
  final out = <ElementSpec>[];
  var x = contentLeft;
  for (final (i, text) in items.indexed) {
    final result = i == items.length - 1;
    out.add(
      TemplateShapes.shape(
        'roundRect',
        SuRect(x, y, pillW, height),
        fill: result ? 'theme:accent1' : 'theme:bg2',
        stroke: 'theme:accent1',
        strokeWidth: 6,
        adjust: const {'radius': 0.5},
        text: TemplatePara.runs([TemplateRun.bold(text)]),
        textColor: result ? 'theme:bg1' : 'theme:text1',
        textStyle: 'body',
        textSize: 40,
        insets: const [16, 24, 16, 24],
      ),
    );
    x += pillW;
    if (i < joints.length) {
      final j = joints[i];
      if (j == null) {
        out.add(
          TemplateShapes.line(
            x + 16,
            y + height / 2,
            x + jointWidth - 16,
            y + height / 2,
            color: 'theme:text2',
            width: 8,
            endArrow: 'triangle',
          ),
        );
      } else {
        out.add(
          TemplateShapes.text(
            SuRect(x, y, jointWidth, height),
            TemplatePara.runs([TemplateRun.bold(j)]),
            textStyle: 'heading',
            size: 72,
            color: 'theme:text2',
            align: 'center',
            anchor: 'middle',
          ),
        );
      }
      x += jointWidth;
    }
  }
  return out;
}
