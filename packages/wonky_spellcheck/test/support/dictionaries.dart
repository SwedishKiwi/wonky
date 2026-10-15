import 'dart:convert';
import 'dart:io';

import 'package:wonky_spellcheck/wonky_spellcheck.dart';

/// Finds the pub workspace root by walking up from [Directory.current] to
/// the first `pubspec.yaml` declaring `workspace:`.
Directory? findWorkspaceRoot() {
  var dir = Directory.current.absolute;
  final workspace = RegExp(r'^workspace:', multiLine: true);
  while (true) {
    final pubspec = File('${dir.path}/pubspec.yaml');
    if (pubspec.existsSync() &&
        workspace.hasMatch(pubspec.readAsStringSync())) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) return null;
    dir = parent;
  }
}

/// The shipped dictionaries folder (`packages/wonky_spellcheck/dictionaries`), or
/// null when the workspace cannot be found.
Directory? shippedDictionariesDir() {
  final root = findWorkspaceRoot();
  if (root == null) return null;
  final dir = Directory('${root.path}/packages/wonky_spellcheck/dictionaries');
  return dir.existsSync() ? dir : null;
}

/// Reason to skip real-dictionary tests, or null when they can run.
String? get shippedDictionariesSkipReason => shippedDictionariesDir() == null
    ? 'packages/wonky_spellcheck/dictionaries not found (no pub workspace root '
          'above ${Directory.current.path})'
    : null;

/// Entries of the shipped `index.json`.
List<Map<String, Object?>> shippedDictionaryIndex() {
  final dir = shippedDictionariesDir();
  if (dir == null) return const [];
  final json =
      jsonDecode(File('${dir.path}/index.json').readAsStringSync())
          as Map<String, Object?>;
  return [
    for (final e in json['dictionaries']! as List<Object?>)
      e! as Map<String, Object?>,
  ];
}

/// Raw `.aff` and `.dic` text of the shipped dictionary [tag].
(String, String) readShippedDictionary(String tag) {
  final dir = shippedDictionariesDir()!;
  return (
    File('${dir.path}/$tag.aff').readAsStringSync(),
    File('${dir.path}/$tag.dic').readAsStringSync(),
  );
}

final Map<String, HunspellDictionary> _cache = {};

/// Parses (once per test isolate) the shipped dictionary [tag].
HunspellDictionary loadShippedDictionary(String tag) =>
    _cache.putIfAbsent(tag, () {
      final (aff, dic) = readShippedDictionary(tag);
      return HunspellDictionary.parse(aff, dic);
    });
