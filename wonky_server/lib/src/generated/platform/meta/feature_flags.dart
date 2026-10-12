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
import 'package:serverpod/serverpod.dart' as _is;

/// Config-driven feature flags (specs/13 §3).
abstract class FeatureFlags
    implements _is.SerializableModel, _is.ProtocolSerialization {
  FeatureFlags._({
    required this.ai,
    required this.scripting,
    required this.mcpUiBridge,
    required this.experimentalCharts,
  });

  factory FeatureFlags({
    required bool ai,
    required bool scripting,
    required bool mcpUiBridge,
    required bool experimentalCharts,
  }) = _FeatureFlagsImpl;

  factory FeatureFlags.fromJson(Map<String, dynamic> jsonSerialization) {
    return FeatureFlags(
      ai: _is.BoolJsonExtension.fromJson(jsonSerialization['ai']),
      scripting: _is.BoolJsonExtension.fromJson(jsonSerialization['scripting']),
      mcpUiBridge: _is.BoolJsonExtension.fromJson(
        jsonSerialization['mcpUiBridge'],
      ),
      experimentalCharts: _is.BoolJsonExtension.fromJson(
        jsonSerialization['experimentalCharts'],
      ),
    );
  }

  bool ai;

  bool scripting;

  bool mcpUiBridge;

  bool experimentalCharts;

  /// Returns a shallow copy of this [FeatureFlags]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  FeatureFlags copyWith({
    bool? ai,
    bool? scripting,
    bool? mcpUiBridge,
    bool? experimentalCharts,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'FeatureFlags',
      'ai': ai,
      'scripting': scripting,
      'mcpUiBridge': mcpUiBridge,
      'experimentalCharts': experimentalCharts,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'FeatureFlags',
      'ai': ai,
      'scripting': scripting,
      'mcpUiBridge': mcpUiBridge,
      'experimentalCharts': experimentalCharts,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _FeatureFlagsImpl extends FeatureFlags {
  _FeatureFlagsImpl({
    required bool ai,
    required bool scripting,
    required bool mcpUiBridge,
    required bool experimentalCharts,
  }) : super._(
         ai: ai,
         scripting: scripting,
         mcpUiBridge: mcpUiBridge,
         experimentalCharts: experimentalCharts,
       );

  /// Returns a shallow copy of this [FeatureFlags]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  FeatureFlags copyWith({
    bool? ai,
    bool? scripting,
    bool? mcpUiBridge,
    bool? experimentalCharts,
  }) {
    return FeatureFlags(
      ai: ai ?? this.ai,
      scripting: scripting ?? this.scripting,
      mcpUiBridge: mcpUiBridge ?? this.mcpUiBridge,
      experimentalCharts: experimentalCharts ?? this.experimentalCharts,
    );
  }
}
