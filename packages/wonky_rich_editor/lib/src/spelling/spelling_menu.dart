import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_ui/wonky_ui.dart';

/// The labels of the spelling section of a context menu (the host's
/// translations).
class SpellingMenuLabels {
  const SpellingMenuLabels({
    this.noSuggestions = 'No suggestions',
    this.ignore = 'Ignore',
    this.addToDictionary = _add,
  });

  /// The disabled row shown when there are no suggestions.
  final String noSuggestions;
  final String ignore;

  /// *Add "word" to dictionary*.
  final String Function(String word) addToDictionary;

  static String _add(String word) => 'Add “$word” to dictionary';
}

/// The spelling section of a context menu on the misspelled [word] (Slides
/// 03 §14, specs/16 §7.3): up to five [suggestions] (the first with the
/// spelling icon; *No suggestions* when there are none), *Ignore*, *Add
/// "word" to dictionary* and a separator.
///
/// Keys: `<keyPrefix>.suggestion.<i>`, `<keyPrefix>.ignore`,
/// `<keyPrefix>.add`.
List<WonkyMenuEntry> spellingMenuEntries({
  required String word,
  required List<String> suggestions,
  required void Function(String replacement) onReplace,
  required VoidCallback onIgnore,
  required VoidCallback onAddToDictionary,
  SpellingMenuLabels labels = const SpellingMenuLabels(),
  String keyPrefix = 'menu.spell',
}) => [
  if (suggestions.isEmpty)
    WonkyMenuLabel(labels.noSuggestions)
  else
    for (var i = 0; i < suggestions.length; i++)
      WonkyMenuItem(
        key: ValueKey<String>('$keyPrefix.suggestion.$i'),
        label: suggestions[i],
        icon: i == 0 ? LucideIcons.spellCheck : null,
        onSelected: () => onReplace(suggestions[i]),
      ),
  WonkyMenuItem(
    key: ValueKey<String>('$keyPrefix.ignore'),
    label: labels.ignore,
    onSelected: onIgnore,
  ),
  WonkyMenuItem(
    key: ValueKey<String>('$keyPrefix.add'),
    label: labels.addToDictionary(word),
    onSelected: onAddToDictionary,
  ),
  const WonkyMenuSeparator(),
];
