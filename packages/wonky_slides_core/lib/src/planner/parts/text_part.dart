part of '../slides_planner.dart';

extension _TextPart on _Planner {
  /// A validated text body (02 §4.1, §13), or null.
  String? _body(String? delta) {
    if (delta == null) return null;
    final String n;
    try {
      n = SlidesText.normalizeJson(delta)!;
    } on FormatException catch (e) {
      invalid('Invalid text: ${e.message}');
    }
    final max = limits.maxTextLength;
    if (SlidesText.lengthOf(n) > max) {
      limit('A text box can hold at most ${_Planner._fmt(max)} characters.');
    }
    return n;
  }

  /// Checks that [e] holds a rich text body.
  void _checkTextElement(SlideElementRec e) {
    final ok =
        e.kind.hasText ||
        (e.placeholderType?.holdsText ?? false) ||
        e.placeholderType != null;
    if (!ok) invalid('${e.kind.name} elements hold no text', {'id': e.id});
  }

  String setText(SetText op) {
    switch (op.target) {
      case ElementText(:final elementId):
        final e = elementOf(elementId);
        _checkTextElement(e);
        b.set(e, {SlidesCols.text: _body(op.delta)});
        return 'Typing';
      case NotesText(:final slideId):
        final s = slideOf(slideId);
        b.set(s, {SlideCols.notes: _notes(op.delta)});
        return 'Edit notes';
      case CellText(:final elementId, :final rowId, :final columnId):
        writeCell(elementId, rowId, columnId, {
          SlidesCols.text: _body(op.delta),
        });
        return 'Typing';
    }
  }

  String formatText(FormatText op) {
    if (op.targets.length > 1 && (op.start != null || op.length != null)) {
      invalid('A range can only be formatted in one text body');
    }
    for (final t in op.targets) {
      final notes = t is NotesText;
      String? current;
      switch (t) {
        case ElementText(:final elementId):
          final e = elementOf(elementId);
          _checkTextElement(e);
          current = e.text;
        case NotesText(:final slideId):
          current = slideOf(slideId).notes;
        case CellText(:final elementId, :final rowId, :final columnId):
          tableOf(elementId);
          current = ix.table(elementId).cell(rowId, columnId)?.text;
      }
      final Delta doc;
      try {
        doc = SlidesText.parse(current);
      } on FormatException {
        invalid('The text body is not valid');
      }
      final next = SlidesText.encode(
        SlidesText.format(
          doc,
          op.attributes,
          start: op.start,
          length: op.length,
          notes: notes,
        ),
      );
      final value =
          current == null && next == SlidesText.encode(Delta()..insert('\n'))
          ? null
          : next;
      switch (t) {
        case ElementText(:final elementId):
          b.update(SlidesTables.slideElement, elementId, {
            SlidesCols.text: value,
          });
        case NotesText(:final slideId):
          b.update(SlidesTables.slide, slideId, {SlideCols.notes: value});
        case CellText(:final elementId, :final rowId, :final columnId):
          writeCell(elementId, rowId, columnId, {SlidesCols.text: value});
      }
    }
    return 'Format text';
  }

  String setTextBoxStyle(SetTextBoxStyle op) {
    for (final id in unique(op.elementIds)) {
      final e = elementOf(id);
      _checkTextElement(e);
      final merged = mergePatch(decodeMap(e.textStyleJson), op.patch);
      merged.remove('v');
      if (merged.isEmpty) {
        b.set(e, {ElementCols.textStyleJson: null});
        continue;
      }
      final sink = IssueSink();
      final box = BoxTextStyle.fromJson(
        {'v': 1, ...merged},
        'textStyleJson',
        sink,
      );
      if (box == null || sink.hasErrors) {
        invalid(
          'Invalid text box style: '
          '${sink.errors.map((i) => '${i.path}: ${i.message}').join('; ')}',
        );
      }
      b.set(e, {ElementCols.textStyleJson: jsonEncode(box.toJson())});
    }
    return 'Text box options';
  }
}

extension _PlaceholderPart on _Planner {
  /// *Reset to layout* (03 §6.2): instance frame and style columns → null
  /// (inherit from the layout placeholder again); the text stays.
  String resetPlaceholders(ResetPlaceholders op) {
    final ids = unique(op.elementIds);
    for (final id in ids) {
      final e = elementOf(id);
      if (e.slideId == null || e.placeholderOf == null) {
        invalid('Only placeholders on a slide can be reset to the layout', {
          'id': id,
        });
      }
      b.set(
        e,
        {
          ElementCols.x: null,
          ElementCols.y: null,
          ElementCols.width: null,
          ElementCols.height: null,
          ElementCols.rotation: null,
          ElementCols.textStyleJson: null,
          ElementCols.fillJson: null,
          ElementCols.strokeJson: null,
          ElementCols.effectsJson: null,
          ElementCols.opacity: null,
        },
        together: const {
          ElementCols.x,
          ElementCols.y,
          ElementCols.width,
          ElementCols.height,
        },
      );
    }
    return plural(ids.length, 'Reset to layout', 'Reset to layout');
  }
}
