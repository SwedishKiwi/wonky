/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import 'package:wonky_client/src/protocol/protocol.dart' as _i8pkqg1o;
import '../../write/models/write_diff_author.dart' as _iom1l825;

/// Write 08 §4.2.
abstract class WriteDiffView
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  WriteDiffView._({
    required this.fromRevision,
    required this.toRevision,
    required this.exact,
    required this.deltaJson,
    required this.authors,
    required this.changeCount,
  });

  factory WriteDiffView({
    required int fromRevision,
    required int toRevision,
    required bool exact,
    required String deltaJson,
    required List<_iom1l825.WriteDiffAuthor> authors,
    required int changeCount,
  }) = _WriteDiffViewImpl;

  factory WriteDiffView.fromJson(Map<String, dynamic> jsonSerialization) {
    return WriteDiffView(
      fromRevision: jsonSerialization['fromRevision'] as int,
      toRevision: jsonSerialization['toRevision'] as int,
      exact: _isc.BoolJsonExtension.fromJson(jsonSerialization['exact']),
      deltaJson: jsonSerialization['deltaJson'] as String,
      authors: _i8pkqg1o.Protocol()
          .deserialize<List<_iom1l825.WriteDiffAuthor>>(
            jsonSerialization['authors'],
          ),
      changeCount: jsonSerialization['changeCount'] as int,
    );
  }

  int fromRevision;

  int toRevision;

  /// True when authorship is exact (attributed replay).
  bool exact;

  /// doc(to) plus tombstones with diff_ins/diff_del/diff_fmt attributes.
  String deltaJson;

  List<_iom1l825.WriteDiffAuthor> authors;

  int changeCount;

  /// Returns a shallow copy of this [WriteDiffView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  WriteDiffView copyWith({
    int? fromRevision,
    int? toRevision,
    bool? exact,
    String? deltaJson,
    List<_iom1l825.WriteDiffAuthor>? authors,
    int? changeCount,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WriteDiffView',
      'fromRevision': fromRevision,
      'toRevision': toRevision,
      'exact': exact,
      'deltaJson': deltaJson,
      'authors': authors.toJson(valueToJson: (v) => v.toJson()),
      'changeCount': changeCount,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'WriteDiffView',
      'fromRevision': fromRevision,
      'toRevision': toRevision,
      'exact': exact,
      'deltaJson': deltaJson,
      'authors': authors.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      'changeCount': changeCount,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _WriteDiffViewImpl extends WriteDiffView {
  _WriteDiffViewImpl({
    required int fromRevision,
    required int toRevision,
    required bool exact,
    required String deltaJson,
    required List<_iom1l825.WriteDiffAuthor> authors,
    required int changeCount,
  }) : super._(
         fromRevision: fromRevision,
         toRevision: toRevision,
         exact: exact,
         deltaJson: deltaJson,
         authors: authors,
         changeCount: changeCount,
       );

  /// Returns a shallow copy of this [WriteDiffView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  WriteDiffView copyWith({
    int? fromRevision,
    int? toRevision,
    bool? exact,
    String? deltaJson,
    List<_iom1l825.WriteDiffAuthor>? authors,
    int? changeCount,
  }) {
    return WriteDiffView(
      fromRevision: fromRevision ?? this.fromRevision,
      toRevision: toRevision ?? this.toRevision,
      exact: exact ?? this.exact,
      deltaJson: deltaJson ?? this.deltaJson,
      authors: authors ?? this.authors.map((e0) => e0.copyWith()).toList(),
      changeCount: changeCount ?? this.changeCount,
    );
  }
}
