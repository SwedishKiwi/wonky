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

/// The presenter's full state (Slides 10 §6.2 `state`), sent on every
/// change and every 10 s. Elapsed times are relative to the sending
/// moment; the server stamps `sentAtMs` on the event, so followers derive
/// start times in their own clock (offset estimated from server times).
abstract class PresentationState
    implements _is.SerializableModel, _is.ProtocolSerialization {
  PresentationState._({
    required this.revision,
    this.slideId,
    required this.step,
    required this.stepElapsedMs,
    required this.blank,
    required this.picker,
    required this.endScreen,
    required this.timerRunning,
    required this.timerElapsedMs,
    this.deckRevision,
  });

  factory PresentationState({
    required int revision,
    String? slideId,
    required int step,
    required int stepElapsedMs,
    required String blank,
    required bool picker,
    required bool endScreen,
    required bool timerRunning,
    required int timerElapsedMs,
    String? deckRevision,
  }) = _PresentationStateImpl;

  factory PresentationState.fromJson(Map<String, dynamic> jsonSerialization) {
    return PresentationState(
      revision: jsonSerialization['revision'] as int,
      slideId: jsonSerialization['slideId'] as String?,
      step: jsonSerialization['step'] as int,
      stepElapsedMs: jsonSerialization['stepElapsedMs'] as int,
      blank: jsonSerialization['blank'] as String,
      picker: _is.BoolJsonExtension.fromJson(jsonSerialization['picker']),
      endScreen: _is.BoolJsonExtension.fromJson(jsonSerialization['endScreen']),
      timerRunning: _is.BoolJsonExtension.fromJson(
        jsonSerialization['timerRunning'],
      ),
      timerElapsedMs: jsonSerialization['timerElapsedMs'] as int,
      deckRevision: jsonSerialization['deckRevision'] as String?,
    );
  }

  /// Increases with every change (followers drop older states).
  int revision;

  /// The shown slide (null in an empty deck).
  String? slideId;

  /// Timeline step on the slide (0 = after the automatic step).
  int step;

  /// Milliseconds since the step started when the state was sent.
  int stepElapsedMs;

  /// none, black or white.
  String blank;

  /// The slide picker is open on the audience (no presenter view).
  bool picker;

  /// The end screen is shown.
  bool endScreen;

  bool timerRunning;

  /// Timer milliseconds when the state was sent.
  int timerElapsedMs;

  /// The presenter's deck revision (followers wait for sync when behind).
  String? deckRevision;

  /// Returns a shallow copy of this [PresentationState]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  PresentationState copyWith({
    int? revision,
    String? slideId,
    int? step,
    int? stepElapsedMs,
    String? blank,
    bool? picker,
    bool? endScreen,
    bool? timerRunning,
    int? timerElapsedMs,
    String? deckRevision,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PresentationState',
      'revision': revision,
      if (slideId != null) 'slideId': slideId,
      'step': step,
      'stepElapsedMs': stepElapsedMs,
      'blank': blank,
      'picker': picker,
      'endScreen': endScreen,
      'timerRunning': timerRunning,
      'timerElapsedMs': timerElapsedMs,
      if (deckRevision != null) 'deckRevision': deckRevision,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PresentationState',
      'revision': revision,
      if (slideId != null) 'slideId': slideId,
      'step': step,
      'stepElapsedMs': stepElapsedMs,
      'blank': blank,
      'picker': picker,
      'endScreen': endScreen,
      'timerRunning': timerRunning,
      'timerElapsedMs': timerElapsedMs,
      if (deckRevision != null) 'deckRevision': deckRevision,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _PresentationStateImpl extends PresentationState {
  _PresentationStateImpl({
    required int revision,
    String? slideId,
    required int step,
    required int stepElapsedMs,
    required String blank,
    required bool picker,
    required bool endScreen,
    required bool timerRunning,
    required int timerElapsedMs,
    String? deckRevision,
  }) : super._(
         revision: revision,
         slideId: slideId,
         step: step,
         stepElapsedMs: stepElapsedMs,
         blank: blank,
         picker: picker,
         endScreen: endScreen,
         timerRunning: timerRunning,
         timerElapsedMs: timerElapsedMs,
         deckRevision: deckRevision,
       );

  /// Returns a shallow copy of this [PresentationState]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  PresentationState copyWith({
    int? revision,
    Object? slideId = _Undefined,
    int? step,
    int? stepElapsedMs,
    String? blank,
    bool? picker,
    bool? endScreen,
    bool? timerRunning,
    int? timerElapsedMs,
    Object? deckRevision = _Undefined,
  }) {
    return PresentationState(
      revision: revision ?? this.revision,
      slideId: slideId is String? ? slideId : this.slideId,
      step: step ?? this.step,
      stepElapsedMs: stepElapsedMs ?? this.stepElapsedMs,
      blank: blank ?? this.blank,
      picker: picker ?? this.picker,
      endScreen: endScreen ?? this.endScreen,
      timerRunning: timerRunning ?? this.timerRunning,
      timerElapsedMs: timerElapsedMs ?? this.timerElapsedMs,
      deckRevision: deckRevision is String? ? deckRevision : this.deckRevision,
    );
  }
}
