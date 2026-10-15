import 'package:flutter/foundation.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/schema.dart' show ElementCols;
import 'package:wonky_slides_core/themes.dart' show SlidePlaceholderType;
import 'package:wonky_sync_models/ids.dart' show SlidesIds;

import '../editor_screen/deck_editor_controller.dart';
import 'outline_body.dart';

/// The parts of a slide the outline view edits (Slides 04 §10): the title
/// placeholder instance, the first body placeholder (else the subtitle of
/// title slides) and a count of everything else.
class OutlineSlideParts {
  const OutlineSlideParts({
    required this.slideId,
    this.title,
    this.titleDefId,
    this.body,
    this.others = const {},
    this.otherContent = false,
    this.hasNotes = false,
  });

  /// The parts of slide [slideId].
  factory OutlineSlideParts.of(DeckModel m, String slideId) {
    SlideElementRec? title, body, subtitle;
    final others = <ElementKind, int>{};
    var otherContent = false;
    for (final e in m.elementsOf(slideId)) {
      final p = e.placeholderType;
      if (p == SlidePlaceholderType.title && title == null) {
        title = e;
        continue;
      }
      if (p == SlidePlaceholderType.body && body == null) {
        body = e;
        continue;
      }
      if (p == SlidePlaceholderType.subtitle && subtitle == null) {
        subtitle = e;
        continue;
      }
      if (p != null && _blank(e)) continue;
      others[e.kind] = (others[e.kind] ?? 0) + 1;
      otherContent = true;
    }
    if (body == null) {
      body = subtitle;
    } else if (subtitle != null && !_blank(subtitle)) {
      others[subtitle.kind] = (others[subtitle.kind] ?? 0) + 1;
      otherContent = true;
    }
    String? titleDef;
    if (title == null) {
      final slide = m.slide(slideId);
      final layout = slide == null
          ? null
          : m.indexes.themes.effectiveLayout(slide);
      if (layout != null) {
        for (final d in m.indexes.placeholders.placeholdersOf(layout.id)) {
          if (d.placeholderType == SlidePlaceholderType.title) {
            titleDef = d.id;
            break;
          }
        }
      }
    }
    return OutlineSlideParts(
      slideId: slideId,
      title: title,
      titleDefId: titleDef,
      body: body,
      others: others,
      otherContent: otherContent,
      hasNotes: !SlidesText.isBlank(m.slide(slideId)?.notes),
    );
  }

  static bool _blank(SlideElementRec e) => switch (e.kind) {
    ElementKind.text || ElementKind.shape => SlidesText.isBlank(e.text),
    ElementKind.image => !(e.dataJson ?? '').contains('"src"'),
    _ => false,
  };

  final String slideId;

  /// The title placeholder instance.
  final SlideElementRec? title;

  /// The layout's title placeholder when the slide has no instance (the
  /// outline adds one on the first edit).
  final String? titleDefId;

  /// The body placeholder (or subtitle) whose paragraphs are the bullets.
  final SlideElementRec? body;

  /// Other non-empty elements by kind (the muted summary).
  final Map<ElementKind, int> others;

  /// Whether the slide holds anything besides its title and body (a
  /// slide demoted into the previous one would lose it).
  final bool otherContent;

  /// Whether the slide has speaker notes.
  final bool hasNotes;

  /// Whether the title can be edited (an instance, or one can be added).
  bool get titleEditable => title != null || titleDefId != null;

  /// The title body.
  OutlineBody get titleBody => OutlineBody.parse(title?.text);

  /// The bullets.
  OutlineBody get bodyLines => OutlineBody.parse(body?.text);

  /// The operations writing [text] as the title (formatting of untouched
  /// text kept; the first paragraph only): a missing title placeholder
  /// instance is added first (05 §5.2, inheriting its frame).
  List<SlidesOperation> setTitle(String text) {
    final t = title;
    if (t != null) {
      final cur = OutlineBody.parse(t.text);
      final next = cur.withText(0, text);
      if (next.toJson() == cur.toJson()) return const [];
      return [SetText(ElementText(t.id), next.toJson())];
    }
    final def = titleDefId;
    if (def == null || text.isEmpty) return const [];
    final id = SlidesIds.placeholderInstanceId(slideId, def);
    return [
      InsertElements(slideId, [
        ElementSpec(
          kind: ElementKind.text,
          x: 0,
          y: 0,
          width: 100,
          height: 100,
          id: id,
          columns: {
            ElementCols.placeholderType: SlidePlaceholderType.title.name,
            ElementCols.placeholderOf: def,
          },
        ),
      ]),
      ResetPlaceholders([id]),
      SetText(
        ElementText(id),
        OutlineBody([OutlineParagraph.plain(text)]).toJson(),
      ),
    ];
  }

  /// The operation writing [body] as the bullets, or null when unchanged
  /// (or there is no body placeholder).
  SlidesOperation? setBody(OutlineBody body) {
    final b = this.body;
    if (b == null) return null;
    final json = body.isBlank && body.length == 1 && body[0].level == 0
        ? null
        : body.toJson();
    final cur = b.text;
    if (cur == json ||
        (json != null &&
            cur != null &&
            OutlineBody.parse(cur).toJson() == json)) {
      return null;
    }
    if (json == null && SlidesText.isBlank(cur)) return null;
    return SetText(ElementText(b.id), json);
  }
}

/// One line of the outline: a slide's title ([index] -1) or bullet
/// [index] of its body.
@immutable
class OutlineLine {
  const OutlineLine(this.slideId, this.index);

  const OutlineLine.title(this.slideId) : index = -1;

  final String slideId;

  /// -1 = the title, else the body paragraph.
  final int index;

  bool get isTitle => index < 0;

  @override
  bool operator ==(Object other) =>
      other is OutlineLine && other.slideId == slideId && other.index == index;

  @override
  int get hashCode => Object.hash(slideId, index);

  @override
  String toString() => 'OutlineLine($slideId, $index)';
}

/// What a slide block of the outline view offers the controller.
abstract interface class OutlineSlideHandle {
  /// The unwritten edits of the block as operations (the block is clean
  /// afterwards; its timers are cancelled).
  List<SlidesOperation> takePending();

  /// Focuses [line] with the caret at [offset] (null = the end).
  void focusLine(int index, int? offset);

  /// Writes the unwritten typing now (its own coalesced typing step).
  Future<void> commit();
}

/// The outline view's state of one open deck (04 §10): the focused line
/// and caret (the keyboard commands act on them), the slide blocks on
/// screen, the focus to apply after a structural edit, and the pending
/// typing (written by the blocks after a pause, or flushed into the next
/// structural command so it is one undo step).
class OutlineController extends ChangeNotifier {
  OutlineController._(this.editor);

  static final Expando<OutlineController> _of = Expando('outline');

  final DeckEditorController editor;

  final Map<String, OutlineSlideHandle> _blocks = {};

  OutlineLine? _focused;
  int _caret = 0;
  bool _selection = false;
  (OutlineLine, int?)? _pendingFocus;

  /// The focused line, or null when no outline field has focus.
  OutlineLine? get focused =>
      editor.mode == DeckViewMode.outline ? _focused : null;

  /// The caret offset in the focused line.
  int get caret => _caret;

  /// Whether text is selected in the focused line.
  bool get hasSelection => _selection;

  /// Reported by the fields.
  void reportFocus(OutlineLine? line, {int caret = 0, bool selection = false}) {
    final changed = line != _focused;
    _focused = line;
    _caret = caret;
    _selection = selection;
    if (changed) notifyListeners();
  }

  /// Forgets the focus and pending focus (the view is gone), silently.
  void reset() {
    _focused = null;
    _pendingFocus = null;
    _caret = 0;
    _selection = false;
  }

  /// Called by a field losing focus.
  void clearFocus(OutlineLine line) {
    if (_focused == line) {
      _focused = null;
      notifyListeners();
    }
  }

  void register(String slideId, OutlineSlideHandle block) =>
      _blocks[slideId] = block;

  void unregister(String slideId, OutlineSlideHandle block) {
    if (identical(_blocks[slideId], block)) _blocks.remove(slideId);
  }

  /// The edits of every block not written yet (and the blocks clean).
  List<SlidesOperation> takePending() => [
    for (final b in _blocks.values) ...b.takePending(),
  ];

  /// Writes every block's unwritten typing (before undo and redo).
  Future<void> commitTyping() async {
    for (final b in [..._blocks.values]) {
      await b.commit();
    }
  }

  /// Moves focus to [line] (now, or once its block is built).
  void focusLine(OutlineLine line, {int? offset}) {
    final block = _blocks[line.slideId];
    if (block != null) {
      _pendingFocus = null;
      block.focusLine(line.index, offset);
    } else {
      _pendingFocus = (line, offset);
      notifyListeners();
    }
  }

  /// The focus a block applies when it is built ([takeFocusFor]).
  (OutlineLine, int?)? get pendingFocus => _pendingFocus;

  /// The pending focus for [slideId], consumed.
  (int, int?)? takeFocusFor(String slideId) {
    final p = _pendingFocus;
    if (p == null || p.$1.slideId != slideId) return null;
    _pendingFocus = null;
    return (p.$1.index, p.$2);
  }
}

/// The outline state of [editor].
OutlineController outlineOf(DeckEditorController editor) =>
    OutlineController._of[editor] ??= OutlineController._(editor);
