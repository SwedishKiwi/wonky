/// Pure-Dart, Hunspell-compatible spell checking: `.aff`/`.dic` parsing,
/// word checking (affixes, compounds, case rules) and suggestions.
///
/// Public entry point: `package:wonky_spellcheck/wonky_spellcheck.dart`.
/// Runs on the VM and on the web (no `dart:io`, no isolates, no 64-bit
/// integer tricks).
library;

import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import 'tokenizer.dart';

part 'affix.dart';
part 'casing.dart';
part 'checker.dart';
part 'dictionary.dart';
part 'flags.dart';
part 'parser.dart';
part 'suggester.dart';
