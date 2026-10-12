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
import '../../sheets/models/sheets_contributor_stat.dart' as _i2dy4tex;

/// Data of the Sheets activity dashboard (Sheets 10 §7).
abstract class SheetsActivitySummary
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  SheetsActivitySummary._({
    required this.days,
    required this.editsPerDay,
    required this.contributors,
    required this.editsPerSheet,
    required this.mcpEdits,
    required this.aiEdits,
    required this.scriptEdits,
  });

  factory SheetsActivitySummary({
    required int days,
    required Map<String, Map<int, int>> editsPerDay,
    required List<_i2dy4tex.SheetsContributorStat> contributors,
    required Map<String, int> editsPerSheet,
    required int mcpEdits,
    required int aiEdits,
    required int scriptEdits,
  }) = _SheetsActivitySummaryImpl;

  factory SheetsActivitySummary.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return SheetsActivitySummary(
      days: jsonSerialization['days'] as int,
      editsPerDay: _i8pkqg1o.Protocol().deserialize<Map<String, Map<int, int>>>(
        jsonSerialization['editsPerDay'],
      ),
      contributors: _i8pkqg1o.Protocol()
          .deserialize<List<_i2dy4tex.SheetsContributorStat>>(
            jsonSerialization['contributors'],
          ),
      editsPerSheet: _i8pkqg1o.Protocol().deserialize<Map<String, int>>(
        jsonSerialization['editsPerSheet'],
      ),
      mcpEdits: jsonSerialization['mcpEdits'] as int,
      aiEdits: jsonSerialization['aiEdits'] as int,
      scriptEdits: jsonSerialization['scriptEdits'] as int,
    );
  }

  int days;

  /// ISO date (yyyy-mm-dd) → user id (0 = others) → edits.
  Map<String, Map<int, int>> editsPerDay;

  List<_i2dy4tex.SheetsContributorStat> contributors;

  /// sheetId → edits.
  Map<String, int> editsPerSheet;

  int mcpEdits;

  int aiEdits;

  int scriptEdits;

  /// Returns a shallow copy of this [SheetsActivitySummary]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  SheetsActivitySummary copyWith({
    int? days,
    Map<String, Map<int, int>>? editsPerDay,
    List<_i2dy4tex.SheetsContributorStat>? contributors,
    Map<String, int>? editsPerSheet,
    int? mcpEdits,
    int? aiEdits,
    int? scriptEdits,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SheetsActivitySummary',
      'days': days,
      'editsPerDay': editsPerDay.toJson(valueToJson: (v) => v.toJson()),
      'contributors': contributors.toJson(valueToJson: (v) => v.toJson()),
      'editsPerSheet': editsPerSheet.toJson(),
      'mcpEdits': mcpEdits,
      'aiEdits': aiEdits,
      'scriptEdits': scriptEdits,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SheetsActivitySummary',
      'days': days,
      'editsPerDay': editsPerDay.toJson(valueToJson: (v) => v.toJson()),
      'contributors': contributors.toJson(
        valueToJson: (v) => v.toJsonForProtocol(),
      ),
      'editsPerSheet': editsPerSheet.toJson(),
      'mcpEdits': mcpEdits,
      'aiEdits': aiEdits,
      'scriptEdits': scriptEdits,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _SheetsActivitySummaryImpl extends SheetsActivitySummary {
  _SheetsActivitySummaryImpl({
    required int days,
    required Map<String, Map<int, int>> editsPerDay,
    required List<_i2dy4tex.SheetsContributorStat> contributors,
    required Map<String, int> editsPerSheet,
    required int mcpEdits,
    required int aiEdits,
    required int scriptEdits,
  }) : super._(
         days: days,
         editsPerDay: editsPerDay,
         contributors: contributors,
         editsPerSheet: editsPerSheet,
         mcpEdits: mcpEdits,
         aiEdits: aiEdits,
         scriptEdits: scriptEdits,
       );

  /// Returns a shallow copy of this [SheetsActivitySummary]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  SheetsActivitySummary copyWith({
    int? days,
    Map<String, Map<int, int>>? editsPerDay,
    List<_i2dy4tex.SheetsContributorStat>? contributors,
    Map<String, int>? editsPerSheet,
    int? mcpEdits,
    int? aiEdits,
    int? scriptEdits,
  }) {
    return SheetsActivitySummary(
      days: days ?? this.days,
      editsPerDay:
          editsPerDay ??
          this.editsPerDay.map(
            (
              key0,
              value0,
            ) => MapEntry(
              key0,
              value0.map(
                (
                  key1,
                  value1,
                ) => MapEntry(
                  key1,
                  value1,
                ),
              ),
            ),
          ),
      contributors:
          contributors ?? this.contributors.map((e0) => e0.copyWith()).toList(),
      editsPerSheet:
          editsPerSheet ??
          this.editsPerSheet.map(
            (
              key0,
              value0,
            ) => MapEntry(
              key0,
              value0,
            ),
          ),
      mcpEdits: mcpEdits ?? this.mcpEdits,
      aiEdits: aiEdits ?? this.aiEdits,
      scriptEdits: scriptEdits ?? this.scriptEdits,
    );
  }
}
