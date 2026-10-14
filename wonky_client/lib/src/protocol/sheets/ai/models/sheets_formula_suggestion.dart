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

/// A formula proposed from natural language (Sheets 12 §6.4): never
/// written by the server; the app inserts it with `sheets.edit.setCellInput`.
abstract class SheetsFormulaSuggestion
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  SheetsFormulaSuggestion._({
    required this.formula,
    required this.localizedFormula,
    required this.explanation,
    required this.references,
    this.previewValue,
    this.previewType,
    this.errorMessage,
    bool? usesExternalData,
  }) : usesExternalData = usesExternalData ?? false;

  factory SheetsFormulaSuggestion({
    required String formula,
    required String localizedFormula,
    required String explanation,
    required List<String> references,
    String? previewValue,
    String? previewType,
    String? errorMessage,
    bool? usesExternalData,
  }) = _SheetsFormulaSuggestionImpl;

  factory SheetsFormulaSuggestion.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return SheetsFormulaSuggestion(
      formula: jsonSerialization['formula'] as String,
      localizedFormula: jsonSerialization['localizedFormula'] as String,
      explanation: jsonSerialization['explanation'] as String,
      references: _i8pkqg1o.Protocol().deserialize<List<String>>(
        jsonSerialization['references'],
      ),
      previewValue: jsonSerialization['previewValue'] as String?,
      previewType: jsonSerialization['previewType'] as String?,
      errorMessage: jsonSerialization['errorMessage'] as String?,
      usesExternalData: jsonSerialization['usesExternalData'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(
              jsonSerialization['usesExternalData'],
            ),
    );
  }

  /// The formula in English syntax (`=SUMIF(A:A,"x",B:B)`).
  String formula;

  /// The formula in the spreadsheet locale (shown in the popover).
  String localizedFormula;

  String explanation;

  /// A1 ranges the formula references.
  List<String> references;

  /// The value it evaluates to at the target cell.
  String? previewValue;

  /// number, text, bool, error or array.
  String? previewType;

  /// Set when the formula does not parse or evaluates to an error.
  String? errorMessage;

  /// The formula fetches external data (IMPORTDATA, IMAGE, …).
  bool usesExternalData;

  /// Returns a shallow copy of this [SheetsFormulaSuggestion]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  SheetsFormulaSuggestion copyWith({
    String? formula,
    String? localizedFormula,
    String? explanation,
    List<String>? references,
    String? previewValue,
    String? previewType,
    String? errorMessage,
    bool? usesExternalData,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SheetsFormulaSuggestion',
      'formula': formula,
      'localizedFormula': localizedFormula,
      'explanation': explanation,
      'references': references.toJson(),
      if (previewValue != null) 'previewValue': previewValue,
      if (previewType != null) 'previewType': previewType,
      if (errorMessage != null) 'errorMessage': errorMessage,
      'usesExternalData': usesExternalData,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SheetsFormulaSuggestion',
      'formula': formula,
      'localizedFormula': localizedFormula,
      'explanation': explanation,
      'references': references.toJson(),
      if (previewValue != null) 'previewValue': previewValue,
      if (previewType != null) 'previewType': previewType,
      if (errorMessage != null) 'errorMessage': errorMessage,
      'usesExternalData': usesExternalData,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SheetsFormulaSuggestionImpl extends SheetsFormulaSuggestion {
  _SheetsFormulaSuggestionImpl({
    required String formula,
    required String localizedFormula,
    required String explanation,
    required List<String> references,
    String? previewValue,
    String? previewType,
    String? errorMessage,
    bool? usesExternalData,
  }) : super._(
         formula: formula,
         localizedFormula: localizedFormula,
         explanation: explanation,
         references: references,
         previewValue: previewValue,
         previewType: previewType,
         errorMessage: errorMessage,
         usesExternalData: usesExternalData,
       );

  /// Returns a shallow copy of this [SheetsFormulaSuggestion]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  SheetsFormulaSuggestion copyWith({
    String? formula,
    String? localizedFormula,
    String? explanation,
    List<String>? references,
    Object? previewValue = _Undefined,
    Object? previewType = _Undefined,
    Object? errorMessage = _Undefined,
    bool? usesExternalData,
  }) {
    return SheetsFormulaSuggestion(
      formula: formula ?? this.formula,
      localizedFormula: localizedFormula ?? this.localizedFormula,
      explanation: explanation ?? this.explanation,
      references: references ?? this.references.map((e0) => e0).toList(),
      previewValue: previewValue is String? ? previewValue : this.previewValue,
      previewType: previewType is String? ? previewType : this.previewType,
      errorMessage: errorMessage is String? ? errorMessage : this.errorMessage,
      usesExternalData: usesExternalData ?? this.usesExternalData,
    );
  }
}
