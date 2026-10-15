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
import '../../../platform/board/models/board_comment_view.dart' as _i238abrc;
import '../../../platform/board/models/board_post_view.dart' as _iwbngzfz;
import '../../../platform/board/models/board_review_section.dart' as _iqagp1we;
import '../../../platform/board/models/board_task_view.dart' as _i50i73w9;

/// An entry of the admin Review tab.
abstract class BoardReviewItem
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  BoardReviewItem._({
    required this.section,
    this.post,
    this.comment,
    this.task,
  });

  factory BoardReviewItem({
    required _iqagp1we.BoardReviewSection section,
    _iwbngzfz.BoardPostView? post,
    _i238abrc.BoardCommentView? comment,
    _i50i73w9.BoardTaskView? task,
  }) = _BoardReviewItemImpl;

  factory BoardReviewItem.fromJson(Map<String, dynamic> jsonSerialization) {
    return BoardReviewItem(
      section: _iqagp1we.BoardReviewSection.fromJson(
        (jsonSerialization['section'] as String),
      ),
      post: jsonSerialization['post'] == null
          ? null
          : _i8pkqg1o.Protocol().deserialize<_iwbngzfz.BoardPostView>(
              jsonSerialization['post'],
            ),
      comment: jsonSerialization['comment'] == null
          ? null
          : _i8pkqg1o.Protocol().deserialize<_i238abrc.BoardCommentView>(
              jsonSerialization['comment'],
            ),
      task: jsonSerialization['task'] == null
          ? null
          : _i8pkqg1o.Protocol().deserialize<_i50i73w9.BoardTaskView>(
              jsonSerialization['task'],
            ),
    );
  }

  _iqagp1we.BoardReviewSection section;

  _iwbngzfz.BoardPostView? post;

  _i238abrc.BoardCommentView? comment;

  _i50i73w9.BoardTaskView? task;

  /// Returns a shallow copy of this [BoardReviewItem]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  BoardReviewItem copyWith({
    _iqagp1we.BoardReviewSection? section,
    _iwbngzfz.BoardPostView? post = const _UndefinedBoardReviewItem$post(),
    _i238abrc.BoardCommentView? comment =
        const _UndefinedBoardReviewItem$comment(),
    _i50i73w9.BoardTaskView? task = const _UndefinedBoardReviewItem$task(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BoardReviewItem',
      'section': section.toJson(),
      if (post != null) 'post': post?.toJson(),
      if (comment != null) 'comment': comment?.toJson(),
      if (task != null) 'task': task?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BoardReviewItem',
      'section': section.toJson(),
      if (post != null) 'post': post?.toJsonForProtocol(),
      if (comment != null) 'comment': comment?.toJsonForProtocol(),
      if (task != null) 'task': task?.toJsonForProtocol(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _UndefinedBoardReviewItem$post extends _isc.UndefinedSentinel
    implements _iwbngzfz.BoardPostView {
  const _UndefinedBoardReviewItem$post();
}

class _UndefinedBoardReviewItem$comment extends _isc.UndefinedSentinel
    implements _i238abrc.BoardCommentView {
  const _UndefinedBoardReviewItem$comment();
}

class _UndefinedBoardReviewItem$task extends _isc.UndefinedSentinel
    implements _i50i73w9.BoardTaskView {
  const _UndefinedBoardReviewItem$task();
}

class _BoardReviewItemImpl extends BoardReviewItem {
  _BoardReviewItemImpl({
    required _iqagp1we.BoardReviewSection section,
    _iwbngzfz.BoardPostView? post,
    _i238abrc.BoardCommentView? comment,
    _i50i73w9.BoardTaskView? task,
  }) : super._(
         section: section,
         post: post,
         comment: comment,
         task: task,
       );

  /// Returns a shallow copy of this [BoardReviewItem]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  BoardReviewItem copyWith({
    _iqagp1we.BoardReviewSection? section,
    _iwbngzfz.BoardPostView? post = const _UndefinedBoardReviewItem$post(),
    _i238abrc.BoardCommentView? comment =
        const _UndefinedBoardReviewItem$comment(),
    _i50i73w9.BoardTaskView? task = const _UndefinedBoardReviewItem$task(),
  }) {
    return BoardReviewItem(
      section: section ?? this.section,
      post: post is _isc.UndefinedSentinel ? this.post?.copyWith() : post,
      comment: comment is _isc.UndefinedSentinel
          ? this.comment?.copyWith()
          : comment,
      task: task is _isc.UndefinedSentinel ? this.task?.copyWith() : task,
    );
  }
}
