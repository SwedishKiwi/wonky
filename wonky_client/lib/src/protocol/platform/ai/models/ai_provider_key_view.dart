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
import '../../../platform/ai/models/ai_provider.dart' as _i1k6plh5;

/// What a client sees of the user's own API key: the provider and the
/// last four characters, never the key.
abstract class AiProviderKeyView
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  AiProviderKeyView._({
    required this.provider,
    required this.last4,
    required this.updatedAt,
  });

  factory AiProviderKeyView({
    required _i1k6plh5.AiProvider provider,
    required String last4,
    required DateTime updatedAt,
  }) = _AiProviderKeyViewImpl;

  factory AiProviderKeyView.fromJson(Map<String, dynamic> jsonSerialization) {
    return AiProviderKeyView(
      provider: _i1k6plh5.AiProvider.fromJson(
        (jsonSerialization['provider'] as String),
      ),
      last4: jsonSerialization['last4'] as String,
      updatedAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
    );
  }

  _i1k6plh5.AiProvider provider;

  String last4;

  DateTime updatedAt;

  /// Returns a shallow copy of this [AiProviderKeyView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  AiProviderKeyView copyWith({
    _i1k6plh5.AiProvider? provider,
    String? last4,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AiProviderKeyView',
      'provider': provider.toJson(),
      'last4': last4,
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AiProviderKeyView',
      'provider': provider.toJson(),
      'last4': last4,
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _AiProviderKeyViewImpl extends AiProviderKeyView {
  _AiProviderKeyViewImpl({
    required _i1k6plh5.AiProvider provider,
    required String last4,
    required DateTime updatedAt,
  }) : super._(
         provider: provider,
         last4: last4,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [AiProviderKeyView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  AiProviderKeyView copyWith({
    _i1k6plh5.AiProvider? provider,
    String? last4,
    DateTime? updatedAt,
  }) {
    return AiProviderKeyView(
      provider: provider ?? this.provider,
      last4: last4 ?? this.last4,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
