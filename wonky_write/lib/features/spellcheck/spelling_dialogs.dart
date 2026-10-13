import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../editor/applier/delta_applier.dart' show DeltaSelection;
import '../editor/commands/write_editor_commands.dart';
import '../editor/controller/write_editor_controller.dart';
import 'write_spellcheck.dart';

/// Stable keys (specs/15 §7).
abstract final class SpellingKeys {
  static const dialog = ValueKey<String>('write.dialog.spelling');
  static const word = ValueKey<String>('write.dialog.spelling.word');
  static const change = ValueKey<String>('write.dialog.spelling.change');
  static const changeAll = ValueKey<String>('write.dialog.spelling.changeAll');
  static const ignore = ValueKey<String>('write.dialog.spelling.ignore');
  static const ignoreAll = ValueKey<String>('write.dialog.spelling.ignoreAll');
  static const add = ValueKey<String>('write.dialog.spelling.add');
  static const done = ValueKey<String>('write.dialog.spelling.done');
  static const dictionary = ValueKey<String>('write.dialog.dictionary');

  static ValueKey<String> suggestion(int i) =>
      ValueKey<String>('write.dialog.spelling.suggestion.$i');

  static ValueKey<String> remove(String word) =>
      ValueKey<String>('write.dialog.dictionary.remove.$word');
}

/// Replaces every occurrence of [word] flagged in the document with
/// [replacement] as one undo step ("Change all"). Returns the count.
int changeAllSpelling(
  WriteSpellcheck spellcheck,
  WriteEditorController controller,
  WriteEditorCommands commands,
  String word,
  String replacement,
) {
  final matches = [
    for (final e in spellcheck.errors)
      if (e.word == word) e,
  ];
  if (matches.isEmpty) return 0;
  controller.group('Correct spelling', () {
    // Back to front so earlier offsets stay valid.
    for (final e in matches.reversed) {
      commands.replaceRangeWithTextLabelled(
        e.start,
        e.length,
        replacement,
        label: 'Correct spelling',
      );
    }
  });
  return matches.length;
}

/// Tools › Spelling › Check spelling… (Write 05 §12): walks the flagged
/// words from the caret with Change, Change all, Ignore, Ignore all and Add
/// to dictionary.
Future<void> showSpellingDialog(
  BuildContext context, {
  required WriteSpellcheck spellcheck,
  required WriteEditorController controller,
  required WriteEditorCommands commands,
  required Future<void> Function(String word) addToDictionary,
}) => showShadDialog<void>(
  context: context,
  builder: (_) => SpellingDialog(
    spellcheck: spellcheck,
    controller: controller,
    commands: commands,
    addToDictionary: addToDictionary,
  ),
);

class SpellingDialog extends StatefulWidget {
  const SpellingDialog({
    super.key,
    required this.spellcheck,
    required this.controller,
    required this.commands,
    required this.addToDictionary,
  });

  final WriteSpellcheck spellcheck;
  final WriteEditorController controller;
  final WriteEditorCommands commands;
  final Future<void> Function(String word) addToDictionary;

  @override
  State<SpellingDialog> createState() => _SpellingDialogState();
}

class _SpellingDialogState extends State<SpellingDialog> {
  SpellError? _current;
  List<String> _suggestions = const [];
  int _chosen = 0;
  int _from = 0;
  final _skipped = <(String, int)>{};

  @override
  void initState() {
    super.initState();
    _from = widget.controller.selection?.start ?? 0;
    _next();
  }

  /// Moves to the next flagged word at or after [_from] (wrapping once).
  void _next() {
    final errors = widget.spellcheck.errors
        .where((e) => !_skipped.contains((e.word, e.start)))
        .toList();
    SpellError? found;
    for (final e in errors) {
      if (e.start >= _from) {
        found = e;
        break;
      }
    }
    found ??= errors.isEmpty ? null : errors.first;
    setState(() {
      _current = found;
      _chosen = 0;
      _suggestions = found == null
          ? const []
          : widget.spellcheck.suggestionsFor(found.word);
    });
    if (found != null) {
      widget.controller.select(
        DeltaSelection(found.start, found.end),
        userInteraction: true,
      );
    }
  }

  String? get _replacement =>
      _suggestions.isEmpty ? null : _suggestions[_chosen];

  void _change() {
    final e = _current;
    final r = _replacement;
    if (e == null || r == null) return;
    widget.commands.replaceRangeWithTextLabelled(
      e.start,
      e.length,
      r,
      label: 'Correct spelling',
    );
    _from = e.start + r.length;
    widget.spellcheck.checkAllNow();
    _next();
  }

  void _changeAll() {
    final e = _current;
    final r = _replacement;
    if (e == null || r == null) return;
    changeAllSpelling(
      widget.spellcheck,
      widget.controller,
      widget.commands,
      e.word,
      r,
    );
    widget.spellcheck.checkAllNow();
    _next();
  }

  void _ignore() {
    final e = _current;
    if (e == null) return;
    _skipped.add((e.word, e.start));
    _from = e.end;
    _next();
  }

  void _ignoreAll() {
    final e = _current;
    if (e == null) return;
    widget.spellcheck.ignore(e.word);
    _next();
  }

  Future<void> _add() async {
    final e = _current;
    if (e == null) return;
    await widget.addToDictionary(e.word);
    if (mounted) _next();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final e = _current;
    return ShadDialog(
      key: SpellingKeys.dialog,
      title: const Text('Spelling'),
      constraints: const BoxConstraints(maxWidth: 440),
      actions: [
        ShadButton(
          key: SpellingKeys.done,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
      child: e == null
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                widget.spellcheck.state == SpellcheckState.ready
                    ? 'No spelling errors found.'
                    : 'Spellcheck isn’t available for this document’s language.',
                style: theme.textTheme.muted,
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Not in dictionary', style: theme.textTheme.small),
                const SizedBox(height: 4),
                Text(
                  e.word,
                  key: SpellingKeys.word,
                  style: theme.textTheme.large.copyWith(
                    color: theme.colorScheme.destructive,
                  ),
                ),
                const SizedBox(height: 12),
                Text('Suggestions', style: theme.textTheme.small),
                const SizedBox(height: 4),
                if (_suggestions.isEmpty)
                  Text('No suggestions', style: theme.textTheme.muted)
                else
                  for (var i = 0; i < _suggestions.length; i += 1)
                    ShadButton.ghost(
                      key: SpellingKeys.suggestion(i),
                      mainAxisAlignment: MainAxisAlignment.start,
                      backgroundColor: i == _chosen
                          ? theme.colorScheme.accent
                          : null,
                      onPressed: () => setState(() => _chosen = i),
                      onDoubleTap: _change,
                      child: Text(_suggestions[i]),
                    ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ShadButton.secondary(
                      key: SpellingKeys.change,
                      enabled: _replacement != null,
                      onPressed: _change,
                      child: const Text('Change'),
                    ),
                    ShadButton.outline(
                      key: SpellingKeys.changeAll,
                      enabled: _replacement != null,
                      onPressed: _changeAll,
                      child: const Text('Change all'),
                    ),
                    ShadButton.outline(
                      key: SpellingKeys.ignore,
                      onPressed: _ignore,
                      child: const Text('Ignore'),
                    ),
                    ShadButton.outline(
                      key: SpellingKeys.ignoreAll,
                      onPressed: _ignoreAll,
                      child: const Text('Ignore all'),
                    ),
                    ShadButton.outline(
                      key: SpellingKeys.add,
                      onPressed: _add,
                      child: const Text('Add to dictionary'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

/// Tools › Spelling › Personal dictionary…: the user's added words.
Future<void> showPersonalDictionaryDialog(
  BuildContext context, {
  required List<String> Function() words,
  required Future<void> Function(String word) onRemove,
  required Future<void> Function(String word) onAdd,
}) => showShadDialog<void>(
  context: context,
  builder: (_) =>
      _PersonalDictionaryDialog(words: words, onRemove: onRemove, onAdd: onAdd),
);

class _PersonalDictionaryDialog extends StatefulWidget {
  const _PersonalDictionaryDialog({
    required this.words,
    required this.onRemove,
    required this.onAdd,
  });

  final List<String> Function() words;
  final Future<void> Function(String word) onRemove;
  final Future<void> Function(String word) onAdd;

  @override
  State<_PersonalDictionaryDialog> createState() =>
      _PersonalDictionaryDialogState();
}

class _PersonalDictionaryDialogState extends State<_PersonalDictionaryDialog> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final word = _field.text.trim();
    if (word.isEmpty || word.contains(RegExp(r'\s'))) return;
    await widget.onAdd(word);
    _field.clear();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final words = [...widget.words()]
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ShadDialog(
      key: SpellingKeys.dictionary,
      title: const Text('Personal dictionary'),
      description: const Text(
        'Words you added are never marked as misspelled, in any document.',
      ),
      constraints: const BoxConstraints(maxWidth: 420),
      actions: [
        ShadButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: ShadInput(
                  controller: _field,
                  placeholder: const Text('Add a word'),
                  onSubmitted: (_) => _add(),
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ShadButton.outline(onPressed: _add, child: const Text('Add')),
            ],
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: words.isEmpty
                ? Text('No words yet.', style: theme.textTheme.muted)
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final w in words)
                        Row(
                          children: [
                            Expanded(child: Text(w)),
                            ShadIconButton.ghost(
                              key: SpellingKeys.remove(w),
                              width: 28,
                              height: 28,
                              iconSize: 14,
                              semanticLabel: 'Remove $w',
                              icon: const Icon(LucideIcons.x),
                              onPressed: () async {
                                await widget.onRemove(w);
                                if (mounted) setState(() {});
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
