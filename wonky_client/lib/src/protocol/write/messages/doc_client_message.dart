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
import '../../protocol.dart' as _iototaiw;
import '../models/document_op_kind.dart' as _idnphvog;
part 'doc_cursor_update.dart';
part 'doc_hash_check.dart';
part 'doc_ping.dart';
part 'doc_request_ops.dart';
part 'doc_submit_op.dart';

/// Client → server messages of `document.connect` (Write 03 §1.1).
sealed class DocClientMessage
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  DocClientMessage();

  /// Returns a shallow copy of this [DocClientMessage]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  DocClientMessage copyWith();
}

class _Undefined {}
