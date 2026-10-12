/// Canonical JSON and SHA-256 hashing of documents (03 §3.2 integrity check).
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dart_quill_delta/dart_quill_delta.dart';

import 'delta_utils.dart';

/// Canonical JSON of [delta]: canonical op structure, map keys sorted, no
/// whitespace. Equal documents always produce identical strings.
String canonicalJson(Delta delta) =>
    canonicalJsonEncode(DeltaUtils.canonical(delta).toJson());

/// SHA-256 (lower-case hex) of [canonicalJson] of [document].
String documentHash(Delta document) =>
    sha256.convert(utf8.encode(canonicalJson(document))).toString();

/// Encodes [value] as JSON with recursively sorted map keys and no
/// whitespace.
String canonicalJsonEncode(Object? value) {
  final b = StringBuffer();
  void write(Object? v) {
    if (v is Map) {
      final keys = v.keys.map((k) => '$k').toList()..sort();
      b.write('{');
      for (var i = 0; i < keys.length; i++) {
        if (i > 0) b.write(',');
        b.write(jsonEncode(keys[i]));
        b.write(':');
        write(v[keys[i]]);
      }
      b.write('}');
    } else if (v is List) {
      b.write('[');
      for (var i = 0; i < v.length; i++) {
        if (i > 0) b.write(',');
        write(v[i]);
      }
      b.write(']');
    } else {
      b.write(jsonEncode(v));
    }
  }

  write(value);
  return b.toString();
}
