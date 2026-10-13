import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'hunspell_engine.dart' deferred as hunspell;
import 'spell_engine.dart';

/// A bundled Hunspell dictionary (`assets/dictionaries/index.json`).
@immutable
class DictionaryInfo {
  const DictionaryInfo({
    required this.tag,
    required this.name,
    required this.aff,
    required this.dic,
    this.license = '',
  });

  factory DictionaryInfo.fromJson(Map<String, dynamic> json) => DictionaryInfo(
    tag: json['tag'] as String,
    name: json['name'] as String? ?? json['tag'] as String,
    aff: json['aff'] as String,
    dic: json['dic'] as String,
    license: json['license'] as String? ?? '',
  );

  final String tag;
  final String name;
  final String aff;
  final String dic;
  final String license;
}

/// Loads spellcheck dictionaries on first need (Write 04 §28.2): the
/// checker library is deferred, the files are fetched from the app bundle
/// and parsed in 8 ms idle-time slices so typing stays smooth.
class SpellDictionaries {
  SpellDictionaries({AssetBundle? bundle, this.slice = const Duration(milliseconds: 8)})
    : _bundle = bundle ?? rootBundle;

  /// The shared instance (dictionaries are cached for the app's lifetime).
  static final SpellDictionaries instance = SpellDictionaries();

  static const _root = 'assets/dictionaries';

  final AssetBundle _bundle;
  final Duration slice;
  Future<List<DictionaryInfo>>? _index;
  final _engines = <String, Future<SpellEngine?>>{};

  /// The bundled dictionaries.
  Future<List<DictionaryInfo>> available() => _index ??= () async {
    try {
      final raw = await _bundle.loadString('$_root/index.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return [
        for (final d in json['dictionaries'] as List)
          DictionaryInfo.fromJson((d as Map).cast<String, dynamic>()),
      ];
    } catch (e) {
      debugPrint('Spellcheck: no dictionary index ($e)');
      return const <DictionaryInfo>[];
    }
  }();

  /// The dictionary for a document language (BCP-47), or `null`: the exact
  /// tag, then a regional default (en-AU/NZ/IE/ZA/IN → en-GB, other `en` →
  /// en-US), then any dictionary of the same language.
  static DictionaryInfo? resolve(List<DictionaryInfo> all, String? language) {
    if (all.isEmpty) return null;
    final wanted = (language == null || language.isEmpty ? 'en-US' : language)
        .replaceAll('_', '-');
    final lower = wanted.toLowerCase();
    DictionaryInfo? byTag(String tag) {
      for (final d in all) {
        if (d.tag.toLowerCase() == tag.toLowerCase()) return d;
      }
      return null;
    }

    final exact = byTag(lower);
    if (exact != null) return exact;
    final primary = lower.split('-').first;
    if (primary == 'en') {
      const british = {'gb', 'uk', 'au', 'nz', 'ie', 'za', 'in'};
      final region = lower.contains('-') ? lower.split('-')[1] : '';
      final preferred = byTag(british.contains(region) ? 'en-GB' : 'en-US');
      if (preferred != null) return preferred;
    }
    for (final d in all) {
      if (d.tag.toLowerCase().split('-').first == primary) return d;
    }
    return null;
  }

  /// The engine for [language], loading it on first use; `null` when no
  /// dictionary fits.
  Future<SpellEngine?> engineFor(String? language) async {
    final info = resolve(await available(), language);
    if (info == null) return null;
    return _engines[info.tag] ??= _load(info);
  }

  Future<SpellEngine?> _load(DictionaryInfo info) async {
    try {
      await hunspell.loadLibrary();
      final aff = await _bundle.loadString('$_root/${info.aff}', cache: false);
      final dic = await _bundle.loadString('$_root/${info.dic}', cache: false);
      return await hunspell.createHunspellEngine(
        tag: info.tag,
        aff: aff,
        dic: dic,
        slice: slice,
        yieldSlice: _idle,
      );
    } catch (e) {
      debugPrint('Spellcheck: loading ${info.tag} failed ($e)');
      _engines.remove(info.tag);
      return null;
    }
  }

  /// Waits for the next idle slot of the UI thread.
  static Future<void> _idle() {
    final completer = Completer<void>();
    SchedulerBinding.instance.scheduleTask<void>(
      completer.complete,
      Priority.animation,
    );
    return completer.future;
  }

  /// Installs an engine (tests).
  @visibleForTesting
  void debugSetEngine(String tag, SpellEngine engine) =>
      _engines[tag] = Future.value(engine);
}
