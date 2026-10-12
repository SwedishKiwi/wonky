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
import 'dart:async' as _ida;
import 'dart:typed_data' as _idt;
import 'package:http/http.dart' as _i85jenna;
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    as _iacc;
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart'
    as _iaic;
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart'
    as _ipulbpi2;
import 'package:wonky_client/src/protocol/platform/activity/activity_event_view.dart'
    as _itempttd;
import 'package:wonky_client/src/protocol/platform/comments/comment_anchor_kind.dart'
    as _i8agtv5a;
import 'package:wonky_client/src/protocol/platform/comments/comment_event.dart'
    as _ikh2q0ca;
import 'package:wonky_client/src/protocol/platform/comments/comment_filter.dart'
    as _ioje6taq;
import 'package:wonky_client/src/protocol/platform/comments/comment_thread_view.dart'
    as _i2c85fb0;
import 'package:wonky_client/src/protocol/platform/comments/comment_view.dart'
    as _ip2r2v4j;
import 'package:wonky_client/src/protocol/platform/common/access_role.dart'
    as _i7gd5xik;
import 'package:wonky_client/src/protocol/platform/drive/drive_change.dart'
    as _i2k3qk48;
import 'package:wonky_client/src/protocol/platform/drive/drive_import_options.dart'
    as _idv1evlb;
import 'package:wonky_client/src/protocol/platform/drive/drive_item_kind.dart'
    as _i37vo1p2;
import 'package:wonky_client/src/protocol/platform/drive/drive_item_view.dart'
    as _iatsgjjq;
import 'package:wonky_client/src/protocol/platform/drive/drive_list_filter.dart'
    as _i8ldc133;
import 'package:wonky_client/src/protocol/platform/drive/drive_list_page.dart'
    as _iawn6g1o;
import 'package:wonky_client/src/protocol/platform/drive/drive_search_filters.dart'
    as _icvnufpf;
import 'package:wonky_client/src/protocol/platform/drive/drive_sort.dart'
    as _ikhtp6t5;
import 'package:wonky_client/src/protocol/platform/drive/import_report_view.dart'
    as _irwfmef9;
import 'package:wonky_client/src/protocol/platform/drive/storage_usage.dart'
    as _i5ixb3en;
import 'package:wonky_client/src/protocol/platform/drive/template_category.dart'
    as _i6of8k2c;
import 'package:wonky_client/src/protocol/platform/drive/template_view.dart'
    as _i1pzk6fp;
import 'package:wonky_client/src/protocol/platform/feedback/feedback_submission.dart'
    as _i70rrzeg;
import 'package:wonky_client/src/protocol/platform/files/file_upload_ticket.dart'
    as _ilpm2pjc;
import 'package:wonky_client/src/protocol/platform/files/file_url_view.dart'
    as _i4i1hokq;
import 'package:wonky_client/src/protocol/platform/files/stored_file_kind.dart'
    as _iaaducpz;
import 'package:wonky_client/src/protocol/platform/mcp/ui_bridge/ui_bridge_message.dart'
    as _i1yu9qix;
import 'package:wonky_client/src/protocol/platform/meta/protocol_info.dart'
    as _ix72qie6;
import 'package:wonky_client/src/protocol/platform/notifications/notification_event.dart'
    as _ibtz26fx;
import 'package:wonky_client/src/protocol/platform/notifications/notification_page.dart'
    as _ispzjfjq;
import 'package:wonky_client/src/protocol/platform/presence/presence_event.dart'
    as _i1lme7np;
import 'package:wonky_client/src/protocol/platform/presence/presence_update.dart'
    as _izu9ijhe;
import 'package:wonky_client/src/protocol/platform/sharing/invite_resolution.dart'
    as _idoq825d;
import 'package:wonky_client/src/protocol/platform/sharing/item_sharing_settings.dart'
    as _i0x662rz;
import 'package:wonky_client/src/protocol/platform/sharing/sharing_info.dart'
    as _idqkfu7d;
import 'package:wonky_client/src/protocol/platform/users/access_token_view.dart'
    as _ip6swqsj;
import 'package:wonky_client/src/protocol/platform/users/account_deletion_preview.dart'
    as _ik5w0ki0;
import 'package:wonky_client/src/protocol/platform/users/created_access_token.dart'
    as _irplbwpp;
import 'package:wonky_client/src/protocol/platform/users/user_preferences.dart'
    as _i59f1kw7;
import 'package:wonky_client/src/protocol/platform/users/user_preferences_patch.dart'
    as _i6jtsw1b;
import 'package:wonky_client/src/protocol/platform/users/user_profile_view.dart'
    as _ioc8dkw9;
import 'package:wonky_client/src/protocol/platform/users/user_summary.dart'
    as _iq7femvs;
import 'package:wonky_client/src/protocol/platform/versions/item_version_view.dart'
    as _itqtmykd;
import 'package:wonky_client/src/protocol/platform/versions/version_restore_result.dart'
    as _iyei7m5z;
import 'package:wonky_client/src/protocol/sheets/models/cell_history_page.dart'
    as _i8ap5j9q;
import 'package:wonky_client/src/protocol/sheets/models/revert_result.dart'
    as _i107v8u3;
import 'package:wonky_client/src/protocol/sheets/models/sheets_activity_summary.dart'
    as _im0q5n3x;
import 'package:wonky_client/src/protocol/sheets/models/space_stats.dart'
    as _imzum1ra;
import 'package:wonky_client/src/protocol/sheets/models/subscribe_result.dart'
    as _ii9ou7kh;
import 'package:wonky_client/src/protocol/write/messages/doc_client_message.dart'
    as _isw33y8i;
import 'package:wonky_client/src/protocol/write/messages/doc_server_message.dart'
    as _ir9iog55;
import 'package:wonky_client/src/protocol/write/models/convert_for_insert_result.dart'
    as _ia522en0;
import 'package:wonky_client/src/protocol/write/models/document_info.dart'
    as _in30vxre;
import 'package:wonky_client/src/protocol/write/models/document_meta_patch.dart'
    as _ih34yxbq;
import 'package:wonky_client/src/protocol/write/models/document_op_view.dart'
    as _i8x9070n;
import 'package:wonky_client/src/protocol/write/models/document_snapshot_view.dart'
    as _i8beogda;
import 'package:wonky_client/src/protocol/write/models/export_progress_event.dart'
    as _i1vrysbd;
import 'package:wonky_client/src/protocol/write/models/export_result_view.dart'
    as _ia6gray1;
import 'package:wonky_client/src/protocol/write/models/write_diff_view.dart'
    as _iohaffow;
import 'package:wonky_client/src/protocol/write/models/write_theme_revision_view.dart'
    as _igytjuh5;
import 'package:wonky_client/src/protocol/write/models/write_theme_view.dart'
    as _i2zuh8f2;
import 'package:wonky_client/src/protocol/write/models/write_version_document.dart'
    as _igd4fcl2;
import 'protocol.dart' as _il2as5qe;

/// By extending [EmailIdpBaseEndpoint], the email identity provider endpoints
/// are made available on the server and enable the corresponding sign-in widget
/// on the client.
/// {@category Endpoint}
class EndpointEmailIdp extends _iaic.EndpointEmailIdpBase {
  EndpointEmailIdp(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'emailIdp';

  /// Logs in the user and returns a new session.
  ///
  /// Throws an [EmailAccountLoginException] in case of errors, with reason:
  /// - [EmailAccountLoginExceptionReason.invalidCredentials] if the email or
  ///   password is incorrect.
  /// - [EmailAccountLoginExceptionReason.tooManyAttempts] if there have been
  ///   too many failed login attempts.
  ///
  /// Throws an [AuthUserBlockedException] if the auth user is blocked.
  @override
  _ida.Future<_iacc.AuthSuccess> login({
    required String email,
    required String password,
  }) => caller.callServerEndpoint<_iacc.AuthSuccess>(
    'emailIdp',
    'login',
    {
      'email': email,
      'password': password,
    },
  );

  /// Starts the registration for a new user account with an email-based login
  /// associated to it.
  ///
  /// Upon successful completion of this method, an email will have been
  /// sent to [email] with a verification link, which the user must open to
  /// complete the registration.
  ///
  /// Always returns a account request ID, which can be used to complete the
  /// registration. If the email is already registered, the returned ID will not
  /// be valid.
  @override
  _ida.Future<_isc.UuidValue> startRegistration({required String email}) =>
      caller.callServerEndpoint<_isc.UuidValue>(
        'emailIdp',
        'startRegistration',
        {'email': email},
      );

  /// Verifies an account request code and returns a token
  /// that can be used to complete the account creation.
  ///
  /// Throws an [EmailAccountRequestException] in case of errors, with reason:
  /// - [EmailAccountRequestExceptionReason.expired] if the account request has
  ///   already expired.
  /// - [EmailAccountRequestExceptionReason.policyViolation] if the password
  ///   does not comply with the password policy.
  /// - [EmailAccountRequestExceptionReason.invalid] if no request exists
  ///   for the given [accountRequestId] or [verificationCode] is invalid.
  @override
  _ida.Future<String> verifyRegistrationCode({
    required _isc.UuidValue accountRequestId,
    required String verificationCode,
  }) => caller.callServerEndpoint<String>(
    'emailIdp',
    'verifyRegistrationCode',
    {
      'accountRequestId': accountRequestId,
      'verificationCode': verificationCode,
    },
  );

  /// Completes a new account registration, creating a new auth user with a
  /// profile and attaching the given email account to it.
  ///
  /// Throws an [EmailAccountRequestException] in case of errors, with reason:
  /// - [EmailAccountRequestExceptionReason.expired] if the account request has
  ///   already expired.
  /// - [EmailAccountRequestExceptionReason.policyViolation] if the password
  ///   does not comply with the password policy.
  /// - [EmailAccountRequestExceptionReason.invalid] if the [registrationToken]
  ///   is invalid.
  ///
  /// Throws an [AuthUserBlockedException] if the auth user is blocked.
  ///
  /// Returns a session for the newly created user.
  @override
  _ida.Future<_iacc.AuthSuccess> finishRegistration({
    required String registrationToken,
    required String password,
  }) => caller.callServerEndpoint<_iacc.AuthSuccess>(
    'emailIdp',
    'finishRegistration',
    {
      'registrationToken': registrationToken,
      'password': password,
    },
  );

  /// Requests a password reset for [email].
  ///
  /// If the email address is registered, an email with reset instructions will
  /// be send out. If the email is unknown, this method will have no effect.
  ///
  /// Always returns a password reset request ID, which can be used to complete
  /// the reset. If the email is not registered, the returned ID will not be
  /// valid.
  ///
  /// Throws an [EmailAccountPasswordResetException] in case of errors, with reason:
  /// - [EmailAccountPasswordResetExceptionReason.tooManyAttempts] if the user has
  ///   made too many attempts trying to request a password reset.
  ///
  @override
  _ida.Future<_isc.UuidValue> startPasswordReset({required String email}) =>
      caller.callServerEndpoint<_isc.UuidValue>(
        'emailIdp',
        'startPasswordReset',
        {'email': email},
      );

  /// Verifies a password reset code and returns a finishPasswordResetToken
  /// that can be used to finish the password reset.
  ///
  /// Throws an [EmailAccountPasswordResetException] in case of errors, with reason:
  /// - [EmailAccountPasswordResetExceptionReason.expired] if the password reset
  ///   request has already expired.
  /// - [EmailAccountPasswordResetExceptionReason.tooManyAttempts] if the user has
  ///   made too many attempts trying to verify the password reset.
  /// - [EmailAccountPasswordResetExceptionReason.invalid] if no request exists
  ///   for the given [passwordResetRequestId] or [verificationCode] is invalid.
  ///
  /// If multiple steps are required to complete the password reset, this endpoint
  /// should be overridden to return credentials for the next step instead
  /// of the credentials for setting the password.
  @override
  _ida.Future<String> verifyPasswordResetCode({
    required _isc.UuidValue passwordResetRequestId,
    required String verificationCode,
  }) => caller.callServerEndpoint<String>(
    'emailIdp',
    'verifyPasswordResetCode',
    {
      'passwordResetRequestId': passwordResetRequestId,
      'verificationCode': verificationCode,
    },
  );

  /// Completes a password reset request by setting a new password.
  ///
  /// The [verificationCode] returned from [verifyPasswordResetCode] is used to
  /// validate the password reset request.
  ///
  /// Throws an [EmailAccountPasswordResetException] in case of errors, with reason:
  /// - [EmailAccountPasswordResetExceptionReason.expired] if the password reset
  ///   request has already expired.
  /// - [EmailAccountPasswordResetExceptionReason.policyViolation] if the new
  ///   password does not comply with the password policy.
  /// - [EmailAccountPasswordResetExceptionReason.invalid] if no request exists
  ///   for the given [passwordResetRequestId] or [verificationCode] is invalid.
  ///
  /// Throws an [AuthUserBlockedException] if the auth user is blocked.
  @override
  _ida.Future<void> finishPasswordReset({
    required String finishPasswordResetToken,
    required String newPassword,
  }) => caller.callServerEndpoint<void>(
    'emailIdp',
    'finishPasswordReset',
    {
      'finishPasswordResetToken': finishPasswordResetToken,
      'newPassword': newPassword,
    },
  );

  @override
  _ida.Future<bool> hasAccount() => caller.callServerEndpoint<bool>(
    'emailIdp',
    'hasAccount',
    {},
  );
}

/// By extending [RefreshJwtTokensEndpoint], the JWT token refresh endpoint
/// is made available on the server and enables automatic token refresh on the client.
/// {@category Endpoint}
class EndpointJwtRefresh extends _iacc.EndpointRefreshJwtTokens {
  EndpointJwtRefresh(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'jwtRefresh';

  /// Creates a new token pair for the given [refreshToken].
  ///
  /// If [refreshToken] is omitted, cookie-mode web clients fall back to the
  /// configured HttpOnly refresh cookie. When neither source is present this
  /// throws [RefreshTokenNotFoundException], the same public "no usable refresh
  /// credential" exception used for unknown refresh tokens.
  ///
  /// Can throw the following exceptions:
  /// -[RefreshTokenMalformedException]: refresh token is malformed and could
  ///   not be parsed. Not expected to happen for tokens issued by the server.
  /// -[RefreshTokenNotFoundException]: refresh token is unknown to the server.
  ///   Either the token was deleted or generated by a different server.
  /// -[RefreshTokenExpiredException]: refresh token has expired. Will happen
  ///   only if it has not been used within configured `refreshTokenLifetime`.
  /// -[RefreshTokenInvalidSecretException]: refresh token is incorrect, meaning
  ///   it does not refer to the current secret refresh token. This indicates
  ///   either a malfunctioning client or a malicious attempt by someone who has
  ///   obtained the refresh token. In this case the underlying refresh token
  ///   will be deleted, and access to it will expire fully when the last access
  ///   token is elapsed.
  ///
  /// This endpoint is unauthenticated, meaning the client won't include any
  /// authentication information with the call.
  @override
  _ida.Future<_iacc.AuthSuccess> refreshAccessToken({String? refreshToken}) =>
      caller.callServerEndpoint<_iacc.AuthSuccess>(
        'jwtRefresh',
        'refreshAccessToken',
        {'refreshToken': refreshToken},
        authenticated: false,
      );
}

/// Comment threads (specs/07 §2.2).
/// {@category Endpoint}
class EndpointComment extends _isc.EndpointRef {
  EndpointComment(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'comment';

  _ida.Future<List<_i2c85fb0.CommentThreadView>> listThreads(
    _isc.UuidValue itemUuid,
    _ioje6taq.CommentFilter filter,
  ) => caller.callServerEndpoint<List<_i2c85fb0.CommentThreadView>>(
    'comment',
    'listThreads',
    {
      'itemUuid': itemUuid,
      'filter': filter,
    },
  );

  _ida.Future<_i2c85fb0.CommentThreadView> getThread(
    _isc.UuidValue threadUuid,
  ) => caller.callServerEndpoint<_i2c85fb0.CommentThreadView>(
    'comment',
    'getThread',
    {'threadUuid': threadUuid},
  );

  /// Creates a thread; idempotent on the client-generated [threadUuid].
  _ida.Future<_i2c85fb0.CommentThreadView> createThread(
    _isc.UuidValue threadUuid,
    _isc.UuidValue itemUuid,
    _i8agtv5a.CommentAnchorKind anchorKind,
    String anchorJson,
    String? quotedText,
    String body,
    List<int> mentions,
    int? assigneeId,
  ) => caller.callServerEndpoint<_i2c85fb0.CommentThreadView>(
    'comment',
    'createThread',
    {
      'threadUuid': threadUuid,
      'itemUuid': itemUuid,
      'anchorKind': anchorKind,
      'anchorJson': anchorJson,
      'quotedText': quotedText,
      'body': body,
      'mentions': mentions,
      'assigneeId': assigneeId,
    },
  );

  /// Replies; idempotent on the optional client-generated [commentUuid].
  _ida.Future<_i2c85fb0.CommentThreadView> reply(
    _isc.UuidValue threadUuid,
    String body,
    List<int> mentions, {
    _isc.UuidValue? commentUuid,
    int? assigneeId,
  }) => caller.callServerEndpoint<_i2c85fb0.CommentThreadView>(
    'comment',
    'reply',
    {
      'threadUuid': threadUuid,
      'body': body,
      'mentions': mentions,
      'commentUuid': commentUuid,
      'assigneeId': assigneeId,
    },
  );

  _ida.Future<_ip2r2v4j.CommentView> edit(
    int commentId,
    String body, {
    List<int>? mentions,
  }) => caller.callServerEndpoint<_ip2r2v4j.CommentView>(
    'comment',
    'edit',
    {
      'commentId': commentId,
      'body': body,
      'mentions': mentions,
    },
  );

  _ida.Future<void> delete(int commentId) => caller.callServerEndpoint<void>(
    'comment',
    'delete',
    {'commentId': commentId},
  );

  _ida.Future<void> deleteThread(_isc.UuidValue threadUuid) =>
      caller.callServerEndpoint<void>(
        'comment',
        'deleteThread',
        {'threadUuid': threadUuid},
      );

  _ida.Future<_i2c85fb0.CommentThreadView> resolve(_isc.UuidValue threadUuid) =>
      caller.callServerEndpoint<_i2c85fb0.CommentThreadView>(
        'comment',
        'resolve',
        {'threadUuid': threadUuid},
      );

  _ida.Future<_i2c85fb0.CommentThreadView> reopen(_isc.UuidValue threadUuid) =>
      caller.callServerEndpoint<_i2c85fb0.CommentThreadView>(
        'comment',
        'reopen',
        {'threadUuid': threadUuid},
      );

  /// Toggles the caller's reaction.
  _ida.Future<_ip2r2v4j.CommentView> react(
    int commentId,
    String emoji,
  ) => caller.callServerEndpoint<_ip2r2v4j.CommentView>(
    'comment',
    'react',
    {
      'commentId': commentId,
      'emoji': emoji,
    },
  );

  _ida.Future<_i2c85fb0.CommentThreadView> updateAnchor(
    _isc.UuidValue threadUuid,
    String anchorJson, {
    _i8agtv5a.CommentAnchorKind? anchorKind,
  }) => caller.callServerEndpoint<_i2c85fb0.CommentThreadView>(
    'comment',
    'updateAnchor',
    {
      'threadUuid': threadUuid,
      'anchorJson': anchorJson,
      'anchorKind': anchorKind,
    },
  );

  /// Live comment changes on an item.
  _ida.Stream<_ikh2q0ca.CommentEvent> watch(_isc.UuidValue itemUuid) =>
      caller.callStreamingServerEndpoint<
        _ida.Stream<_ikh2q0ca.CommentEvent>,
        _ikh2q0ca.CommentEvent
      >(
        'comment',
        'watch',
        {'itemUuid': itemUuid},
        {},
      );
}

/// Wonky Drive (specs/05 §2).
/// {@category Endpoint}
class EndpointDrive extends _isc.EndpointRef {
  EndpointDrive(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'drive';

  /// Children of a folder (null = My Drive root) or a virtual view.
  _ida.Future<_iawn6g1o.DriveListPage> list(
    _isc.UuidValue? folderUuid,
    _i8ldc133.DriveListFilter filter,
    _ikhtp6t5.DriveSort sort,
    String? cursor,
    int limit,
  ) => caller.callServerEndpoint<_iawn6g1o.DriveListPage>(
    'drive',
    'list',
    {
      'folderUuid': folderUuid,
      'filter': filter,
      'sort': sort,
      'cursor': cursor,
      'limit': limit,
    },
  );

  _ida.Future<_iatsgjjq.DriveItemView> get(_isc.UuidValue uuid) =>
      caller.callServerEndpoint<_iatsgjjq.DriveItemView>(
        'drive',
        'get',
        {'uuid': uuid},
      );

  /// Breadcrumb ancestors visible to the caller, root first.
  _ida.Future<List<_iatsgjjq.DriveItemView>> path(_isc.UuidValue uuid) =>
      caller.callServerEndpoint<List<_iatsgjjq.DriveItemView>>(
        'drive',
        'path',
        {'uuid': uuid},
      );

  _ida.Future<_iawn6g1o.DriveListPage> search(
    String query,
    _icvnufpf.DriveSearchFilters filters,
    String? cursor,
    int limit,
  ) => caller.callServerEndpoint<_iawn6g1o.DriveListPage>(
    'drive',
    'search',
    {
      'query': query,
      'filters': filters,
      'cursor': cursor,
      'limit': limit,
    },
  );

  _ida.Future<_iatsgjjq.DriveItemView> createFolder(
    _isc.UuidValue? parentUuid,
    String name,
  ) => caller.callServerEndpoint<_iatsgjjq.DriveItemView>(
    'drive',
    'createFolder',
    {
      'parentUuid': parentUuid,
      'name': name,
    },
  );

  /// Creates a document; idempotent on the client-generated [documentUuid]
  /// and [itemUuid] (offline creation).
  _ida.Future<_iatsgjjq.DriveItemView> createDocument(
    _isc.UuidValue? parentUuid,
    String name,
    _isc.UuidValue? templateUuid,
    String? initialMarkdown, {
    _isc.UuidValue? documentUuid,
    _isc.UuidValue? itemUuid,
  }) => caller.callServerEndpoint<_iatsgjjq.DriveItemView>(
    'drive',
    'createDocument',
    {
      'parentUuid': parentUuid,
      'name': name,
      'templateUuid': templateUuid,
      'initialMarkdown': initialMarkdown,
      'documentUuid': documentUuid,
      'itemUuid': itemUuid,
    },
  );

  /// Registers a spreadsheet created locally in a reserved space
  /// (idempotent).
  _ida.Future<_iatsgjjq.DriveItemView> registerSpreadsheet(
    _isc.UuidValue spaceUuid,
    _isc.UuidValue? parentUuid,
    String name,
  ) => caller.callServerEndpoint<_iatsgjjq.DriveItemView>(
    'drive',
    'registerSpreadsheet',
    {
      'spaceUuid': spaceUuid,
      'parentUuid': parentUuid,
      'name': name,
    },
  );

  /// Creates a spreadsheet server-side (space + rows).
  _ida.Future<_iatsgjjq.DriveItemView> createSpreadsheet(
    _isc.UuidValue? parentUuid,
    String name,
    _isc.UuidValue? templateUuid, {
    String? locale,
    String? timeZone,
  }) => caller.callServerEndpoint<_iatsgjjq.DriveItemView>(
    'drive',
    'createSpreadsheet',
    {
      'parentUuid': parentUuid,
      'name': name,
      'templateUuid': templateUuid,
      'locale': locale,
      'timeZone': timeZone,
    },
  );

  _ida.Future<_iatsgjjq.DriveItemView> rename(
    _isc.UuidValue uuid,
    String name,
  ) => caller.callServerEndpoint<_iatsgjjq.DriveItemView>(
    'drive',
    'rename',
    {
      'uuid': uuid,
      'name': name,
    },
  );

  _ida.Future<_iatsgjjq.DriveItemView> updateDescription(
    _isc.UuidValue uuid,
    String? description,
  ) => caller.callServerEndpoint<_iatsgjjq.DriveItemView>(
    'drive',
    'updateDescription',
    {
      'uuid': uuid,
      'description': description,
    },
  );

  /// Moves items into [newParentUuid] (null = My Drive root, owners only).
  _ida.Future<List<_iatsgjjq.DriveItemView>> move(
    List<_isc.UuidValue> uuids,
    _isc.UuidValue? newParentUuid,
  ) => caller.callServerEndpoint<List<_iatsgjjq.DriveItemView>>(
    'drive',
    'move',
    {
      'uuids': uuids,
      'newParentUuid': newParentUuid,
    },
  );

  _ida.Future<_iatsgjjq.DriveItemView> copy(
    _isc.UuidValue uuid,
    String newName,
    _isc.UuidValue? parentUuid,
    bool copyComments,
    bool copySharing,
  ) => caller.callServerEndpoint<_iatsgjjq.DriveItemView>(
    'drive',
    'copy',
    {
      'uuid': uuid,
      'newName': newName,
      'parentUuid': parentUuid,
      'copyComments': copyComments,
      'copySharing': copySharing,
    },
  );

  _ida.Future<_iatsgjjq.DriveItemView> setStarred(
    _isc.UuidValue uuid,
    bool starred,
  ) => caller.callServerEndpoint<_iatsgjjq.DriveItemView>(
    'drive',
    'setStarred',
    {
      'uuid': uuid,
      'starred': starred,
    },
  );

  _ida.Future<_iatsgjjq.DriveItemView> setPinnedOffline(
    _isc.UuidValue uuid,
    bool pinned,
  ) => caller.callServerEndpoint<_iatsgjjq.DriveItemView>(
    'drive',
    'setPinnedOffline',
    {
      'uuid': uuid,
      'pinned': pinned,
    },
  );

  /// Records that the caller opened the item (Recent; link visits appear in
  /// Shared with me).
  _ida.Future<_iatsgjjq.DriveItemView> markOpened(_isc.UuidValue uuid) =>
      caller.callServerEndpoint<_iatsgjjq.DriveItemView>(
        'drive',
        'markOpened',
        {'uuid': uuid},
      );

  /// "Add shortcut to My Drive" ([parentUuid] null = root).
  _ida.Future<_iatsgjjq.DriveItemView> addShortcut(
    _isc.UuidValue uuid,
    _isc.UuidValue? parentUuid,
  ) => caller.callServerEndpoint<_iatsgjjq.DriveItemView>(
    'drive',
    'addShortcut',
    {
      'uuid': uuid,
      'parentUuid': parentUuid,
    },
  );

  _ida.Future<void> removeShortcut(_isc.UuidValue uuid) =>
      caller.callServerEndpoint<void>(
        'drive',
        'removeShortcut',
        {'uuid': uuid},
      );

  _ida.Future<void> trash(List<_isc.UuidValue> uuids) =>
      caller.callServerEndpoint<void>(
        'drive',
        'trash',
        {'uuids': uuids},
      );

  _ida.Future<void> restore(List<_isc.UuidValue> uuids) =>
      caller.callServerEndpoint<void>(
        'drive',
        'restore',
        {'uuids': uuids},
      );

  _ida.Future<void> deletePermanently(List<_isc.UuidValue> uuids) =>
      caller.callServerEndpoint<void>(
        'drive',
        'deletePermanently',
        {'uuids': uuids},
      );

  /// Deletes all owned items in the trash; returns how many.
  _ida.Future<int> emptyTrash() => caller.callServerEndpoint<int>(
    'drive',
    'emptyTrash',
    {},
  );

  /// Live changes of items visible to the caller.
  _ida.Stream<_i2k3qk48.DriveChange> watch() =>
      caller.callStreamingServerEndpoint<
        _ida.Stream<_i2k3qk48.DriveChange>,
        _i2k3qk48.DriveChange
      >(
        'drive',
        'watch',
        {},
        {},
      );

  /// Template gallery ([kind] null = all kinds).
  _ida.Future<List<_i1pzk6fp.TemplateView>> listTemplates(
    _i37vo1p2.DriveItemKind? kind,
  ) => caller.callServerEndpoint<List<_i1pzk6fp.TemplateView>>(
    'drive',
    'listTemplates',
    {'kind': kind},
  );

  /// Publishes an owned item as a template ([category] null = unpublish).
  _ida.Future<_iatsgjjq.DriveItemView> setTemplate(
    _isc.UuidValue uuid,
    _i6of8k2c.TemplateCategory? category,
  ) => caller.callServerEndpoint<_iatsgjjq.DriveItemView>(
    'drive',
    'setTemplate',
    {
      'uuid': uuid,
      'category': category,
    },
  );

  /// Imports an uploaded file (`file.createUpload` with kind importSource)
  /// as a new item.
  _ida.Future<_irwfmef9.ImportReportView> import(
    _isc.UuidValue uploadId,
    _i37vo1p2.DriveItemKind kind,
    _idv1evlb.DriveImportOptions options,
  ) => caller.callServerEndpoint<_irwfmef9.ImportReportView>(
    'drive',
    'import',
    {
      'uploadId': uploadId,
      'kind': kind,
      'options': options,
    },
  );

  _ida.Future<_i5ixb3en.StorageUsage> storageUsage() =>
      caller.callServerEndpoint<_i5ixb3en.StorageUsage>(
        'drive',
        'storageUsage',
        {},
      );

  /// Sets a client-rendered thumbnail (uploaded with kind thumbnail).
  _ida.Future<_iatsgjjq.DriveItemView> setThumbnail(
    _isc.UuidValue uuid,
    _isc.UuidValue uploadedFileUuid,
  ) => caller.callServerEndpoint<_iatsgjjq.DriveItemView>(
    'drive',
    'setThumbnail',
    {
      'uuid': uuid,
      'uploadedFileUuid': uploadedFileUuid,
    },
  );

  /// The activity feed of an item, newest first.
  _ida.Future<List<_itempttd.ActivityEventView>> activity(
    _isc.UuidValue uuid,
    int? beforeId,
    int limit,
  ) => caller.callServerEndpoint<List<_itempttd.ActivityEventView>>(
    'drive',
    'activity',
    {
      'uuid': uuid,
      'beforeId': beforeId,
      'limit': limit,
    },
  );
}

/// Test support for E2E journeys (specs/15 §9, 13 §1): the latest
/// verification codes of `@example.test` addresses. Refuses every call
/// outside the development and test run modes.
/// {@category Endpoint}
class EndpointE2eSupport extends _isc.EndpointRef {
  EndpointE2eSupport(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'e2eSupport';

  _ida.Future<String?> latestVerificationCode(String email) =>
      caller.callServerEndpoint<String?>(
        'e2eSupport',
        'latestVerificationCode',
        {'email': email},
      );

  _ida.Future<String?> latestPasswordResetCode(String email) =>
      caller.callServerEndpoint<String?>(
        'e2eSupport',
        'latestPasswordResetCode',
        {'email': email},
      );
}

/// "Report a problem" and client error reports (specs/03, 11 §5).
/// {@category Endpoint}
class EndpointFeedback extends _isc.EndpointRef {
  EndpointFeedback(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'feedback';

  _ida.Future<void> submit(_i70rrzeg.FeedbackSubmission feedback) =>
      caller.callServerEndpoint<void>(
        'feedback',
        'submit',
        {'feedback': feedback},
      );

  /// Client error reports (anonymized state, no document content).
  _ida.Future<void> reportError(_i70rrzeg.FeedbackSubmission report) =>
      caller.callServerEndpoint<void>(
        'feedback',
        'reportError',
        {'report': report},
      );
}

/// Uploads and signed downloads (suite 12 §1.1). Idempotent on the
/// client-generated [fileUuid]; content may reference `wonky-file://<uuid>`
/// before the bytes arrive.
/// {@category Endpoint}
class EndpointFile extends _isc.EndpointRef {
  EndpointFile(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'file';

  /// Upload description for `FileUploader`. [kind] defaults to image;
  /// imports use `importSource` without an item.
  _ida.Future<_ilpm2pjc.FileUploadTicket> createUpload(
    _isc.UuidValue fileUuid,
    _isc.UuidValue? itemUuid,
    String fileName,
    String mimeType,
    int size, {
    _iaaducpz.StoredFileKind? kind,
  }) => caller.callServerEndpoint<_ilpm2pjc.FileUploadTicket>(
    'file',
    'createUpload',
    {
      'fileUuid': fileUuid,
      'itemUuid': itemUuid,
      'fileName': fileName,
      'mimeType': mimeType,
      'size': size,
      'kind': kind,
    },
  );

  _ida.Future<_i4i1hokq.FileUrlView> completeUpload(_isc.UuidValue fileUuid) =>
      caller.callServerEndpoint<_i4i1hokq.FileUrlView>(
        'file',
        'completeUpload',
        {'fileUuid': fileUuid},
      );

  /// Status and signed URL (15 min) of a file.
  _ida.Future<_i4i1hokq.FileUrlView> getUrl(_isc.UuidValue fileUuid) =>
      caller.callServerEndpoint<_i4i1hokq.FileUrlView>(
        'file',
        'getUrl',
        {'fileUuid': fileUuid},
      );

  _ida.Future<List<_i4i1hokq.FileUrlView>> getUrls(
    List<_isc.UuidValue> fileUuids,
  ) => caller.callServerEndpoint<List<_i4i1hokq.FileUrlView>>(
    'file',
    'getUrls',
    {'fileUuids': fileUuids},
  );
}

/// The UI bridge stream (suite 09 §6.1): a signed-in app window that allows
/// MCP control connects here; `ui.*` tool calls are relayed to it as
/// [UiBridgeRequest]s and answered with [UiBridgeResponse]s.
/// {@category Endpoint}
class EndpointUiBridge extends _isc.EndpointRef {
  EndpointUiBridge(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'uiBridge';

  _ida.Stream<_i1yu9qix.UiBridgeMessage> connect(
    _ida.Stream<_i1yu9qix.UiBridgeMessage> fromApp,
  ) =>
      caller.callStreamingServerEndpoint<
        _ida.Stream<_i1yu9qix.UiBridgeMessage>,
        _i1yu9qix.UiBridgeMessage
      >(
        'uiBridge',
        'connect',
        {},
        {'fromApp': fromApp},
      );
}

/// Protocol information checked by clients on connect (specs/01 §7).
/// {@category Endpoint}
class EndpointMeta extends _isc.EndpointRef {
  EndpointMeta(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'meta';

  _ida.Future<_ix72qie6.ProtocolInfo> getInfo() =>
      caller.callServerEndpoint<_ix72qie6.ProtocolInfo>(
        'meta',
        'getInfo',
        {},
      );
}

/// In-app notifications (specs/07 §4).
/// {@category Endpoint}
class EndpointNotification extends _isc.EndpointRef {
  EndpointNotification(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'notification';

  _ida.Future<_ispzjfjq.NotificationPage> list(
    String? cursor,
    int limit,
    bool unreadOnly,
  ) => caller.callServerEndpoint<_ispzjfjq.NotificationPage>(
    'notification',
    'list',
    {
      'cursor': cursor,
      'limit': limit,
      'unreadOnly': unreadOnly,
    },
  );

  _ida.Future<int> unreadCount() => caller.callServerEndpoint<int>(
    'notification',
    'unreadCount',
    {},
  );

  /// Marks notifications read; returns the unread count.
  _ida.Future<int> markRead(List<int> ids) => caller.callServerEndpoint<int>(
    'notification',
    'markRead',
    {'ids': ids},
  );

  _ida.Future<int> markAllRead() => caller.callServerEndpoint<int>(
    'notification',
    'markAllRead',
    {},
  );

  /// New notifications and unread count changes.
  _ida.Stream<_ibtz26fx.NotificationEvent> watch() =>
      caller.callStreamingServerEndpoint<
        _ida.Stream<_ibtz26fx.NotificationEvent>,
        _ibtz26fx.NotificationEvent
      >(
        'notification',
        'watch',
        {},
        {},
      );
}

/// Ephemeral presence on an item (specs/07 §1).
/// {@category Endpoint}
class EndpointPresence extends _isc.EndpointRef {
  EndpointPresence(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'presence';

  /// Joins [itemUuid]; the first event is a [PresenceRoster].
  _ida.Stream<_i1lme7np.PresenceEvent> join(
    _isc.UuidValue itemUuid,
    _ida.Stream<_izu9ijhe.PresenceUpdate> updates,
  ) =>
      caller.callStreamingServerEndpoint<
        _ida.Stream<_i1lme7np.PresenceEvent>,
        _i1lme7np.PresenceEvent
      >(
        'presence',
        'join',
        {'itemUuid': itemUuid},
        {'updates': updates},
      );
}

/// Sharing (specs/06 §4).
/// {@category Endpoint}
class EndpointSharing extends _isc.EndpointRef {
  EndpointSharing(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'sharing';

  _ida.Future<_idqkfu7d.SharingInfo> getSharing(_isc.UuidValue itemUuid) =>
      caller.callServerEndpoint<_idqkfu7d.SharingInfo>(
        'sharing',
        'getSharing',
        {'itemUuid': itemUuid},
      );

  _ida.Future<_idqkfu7d.SharingInfo> share(
    _isc.UuidValue itemUuid,
    List<String> emails,
    _i7gd5xik.AccessRole role,
    bool notify,
    String? message,
    DateTime? expiresAt,
  ) => caller.callServerEndpoint<_idqkfu7d.SharingInfo>(
    'sharing',
    'share',
    {
      'itemUuid': itemUuid,
      'emails': emails,
      'role': role,
      'notify': notify,
      'message': message,
      'expiresAt': expiresAt,
    },
  );

  _ida.Future<_idqkfu7d.SharingInfo> updateRole(
    _isc.UuidValue itemUuid,
    int userId,
    _i7gd5xik.AccessRole role, {
    DateTime? expiresAt,
  }) => caller.callServerEndpoint<_idqkfu7d.SharingInfo>(
    'sharing',
    'updateRole',
    {
      'itemUuid': itemUuid,
      'userId': userId,
      'role': role,
      'expiresAt': expiresAt,
    },
  );

  /// Removes a person (or a pending invite with [invitedEmail]).
  _ida.Future<_idqkfu7d.SharingInfo> remove(
    _isc.UuidValue itemUuid,
    int? userId, {
    String? invitedEmail,
  }) => caller.callServerEndpoint<_idqkfu7d.SharingInfo>(
    'sharing',
    'remove',
    {
      'itemUuid': itemUuid,
      'userId': userId,
      'invitedEmail': invitedEmail,
    },
  );

  /// Offers ownership; the new owner accepts with
  /// [respondToOwnershipTransfer].
  _ida.Future<_idqkfu7d.SharingInfo> transferOwnership(
    _isc.UuidValue itemUuid,
    int newOwnerUserId,
  ) => caller.callServerEndpoint<_idqkfu7d.SharingInfo>(
    'sharing',
    'transferOwnership',
    {
      'itemUuid': itemUuid,
      'newOwnerUserId': newOwnerUserId,
    },
  );

  _ida.Future<_iatsgjjq.DriveItemView> respondToOwnershipTransfer(
    int transferId,
    bool accept,
  ) => caller.callServerEndpoint<_iatsgjjq.DriveItemView>(
    'sharing',
    'respondToOwnershipTransfer',
    {
      'transferId': transferId,
      'accept': accept,
    },
  );

  /// Link sharing role; null = restricted.
  _ida.Future<_idqkfu7d.SharingInfo> setLink(
    _isc.UuidValue itemUuid,
    _i7gd5xik.AccessRole? role,
  ) => caller.callServerEndpoint<_idqkfu7d.SharingInfo>(
    'sharing',
    'setLink',
    {
      'itemUuid': itemUuid,
      'role': role,
    },
  );

  _ida.Future<_idqkfu7d.SharingInfo> rotateLink(_isc.UuidValue itemUuid) =>
      caller.callServerEndpoint<_idqkfu7d.SharingInfo>(
        'sharing',
        'rotateLink',
        {'itemUuid': itemUuid},
      );

  _ida.Future<_idqkfu7d.SharingInfo> updateSettings(
    _isc.UuidValue itemUuid,
    _i0x662rz.ItemSharingSettings settings,
  ) => caller.callServerEndpoint<_idqkfu7d.SharingInfo>(
    'sharing',
    'updateSettings',
    {
      'itemUuid': itemUuid,
      'settings': settings,
    },
  );

  _ida.Future<void> requestAccess(
    _isc.UuidValue itemUuid,
    _i7gd5xik.AccessRole role,
    String? message,
  ) => caller.callServerEndpoint<void>(
    'sharing',
    'requestAccess',
    {
      'itemUuid': itemUuid,
      'role': role,
      'message': message,
    },
  );

  _ida.Future<_idqkfu7d.SharingInfo> handleAccessRequest(
    int requestId,
    bool approve,
    _i7gd5xik.AccessRole? role,
  ) => caller.callServerEndpoint<_idqkfu7d.SharingInfo>(
    'sharing',
    'handleAccessRequest',
    {
      'requestId': requestId,
      'approve': approve,
      'role': role,
    },
  );

  /// Resolves a share link token (`/invite/<token>`).
  _ida.Future<_idoq825d.InviteResolution> resolveInvite(String token) =>
      caller.callServerEndpoint<_idoq825d.InviteResolution>(
        'sharing',
        'resolveInvite',
        {'token': token},
      );
}

/// Personal access tokens for MCP (specs/04 §5, 09 §2).
/// {@category Endpoint}
class EndpointAccessToken extends _isc.EndpointRef {
  EndpointAccessToken(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'accessToken';

  _ida.Future<List<_ip6swqsj.AccessTokenView>> list() =>
      caller.callServerEndpoint<List<_ip6swqsj.AccessTokenView>>(
        'accessToken',
        'list',
        {},
      );

  /// Creates a token; the secret is returned only here.
  _ida.Future<_irplbwpp.CreatedAccessToken> create(
    String name,
    List<String> scopes,
    DateTime? expiresAt,
  ) => caller.callServerEndpoint<_irplbwpp.CreatedAccessToken>(
    'accessToken',
    'create',
    {
      'name': name,
      'scopes': scopes,
      'expiresAt': expiresAt,
    },
  );

  _ida.Future<_ip6swqsj.AccessTokenView> revoke(int id) =>
      caller.callServerEndpoint<_ip6swqsj.AccessTokenView>(
        'accessToken',
        'revoke',
        {'id': id},
      );
}

/// The signed-in user: profile, preferences, user search and account
/// deletion (specs/04 §5).
/// {@category Endpoint}
class EndpointUser extends _isc.EndpointRef {
  EndpointUser(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'user';

  /// The caller's profile. The first call after sign-up also creates the
  /// welcome document and spreadsheet.
  _ida.Future<_ioc8dkw9.UserProfileView> getMe() =>
      caller.callServerEndpoint<_ioc8dkw9.UserProfileView>(
        'user',
        'getMe',
        {},
      );

  /// Updates the profile; null leaves a field unchanged, an empty string
  /// clears [locale]/[timeZone] (follow the device).
  _ida.Future<_ioc8dkw9.UserProfileView> updateProfile({
    String? displayName,
    String? locale,
    String? timeZone,
  }) => caller.callServerEndpoint<_ioc8dkw9.UserProfileView>(
    'user',
    'updateProfile',
    {
      'displayName': displayName,
      'locale': locale,
      'timeZone': timeZone,
    },
  );

  /// Starts an avatar upload (upload description flow); finish with
  /// `file.completeUpload(fileUuid)` and [setAvatar].
  _ida.Future<_ilpm2pjc.FileUploadTicket> uploadAvatar(
    _isc.UuidValue fileUuid,
    String fileName,
    String mimeType,
    int size,
  ) => caller.callServerEndpoint<_ilpm2pjc.FileUploadTicket>(
    'user',
    'uploadAvatar',
    {
      'fileUuid': fileUuid,
      'fileName': fileName,
      'mimeType': mimeType,
      'size': size,
    },
  );

  /// Sets (or with null removes) the avatar.
  _ida.Future<_ioc8dkw9.UserProfileView> setAvatar(_isc.UuidValue? fileUuid) =>
      caller.callServerEndpoint<_ioc8dkw9.UserProfileView>(
        'user',
        'setAvatar',
        {'fileUuid': fileUuid},
      );

  _ida.Future<_i59f1kw7.UserPreferences> getPreferences() =>
      caller.callServerEndpoint<_i59f1kw7.UserPreferences>(
        'user',
        'getPreferences',
        {},
      );

  _ida.Future<_i59f1kw7.UserPreferences> updatePreferences(
    _i6jtsw1b.UserPreferencesPatch patch,
  ) => caller.callServerEndpoint<_i59f1kw7.UserPreferences>(
    'user',
    'updatePreferences',
    {'patch': patch},
  );

  /// Users for the share dialog and @mentions (people sharing items with the
  /// caller, or exact email matches).
  _ida.Future<List<_iq7femvs.UserSummary>> searchUsers(
    String query,
    int limit,
  ) => caller.callServerEndpoint<List<_iq7femvs.UserSummary>>(
    'user',
    'searchUsers',
    {
      'query': query,
      'limit': limit,
    },
  );

  /// Summaries of users by id (authors, participants).
  _ida.Future<List<_iq7femvs.UserSummary>> getUsers(List<int> ids) =>
      caller.callServerEndpoint<List<_iq7femvs.UserSummary>>(
        'user',
        'getUsers',
        {'ids': ids},
      );

  _ida.Future<_ik5w0ki0.AccountDeletionPreview> accountDeletionPreview() =>
      caller.callServerEndpoint<_ik5w0ki0.AccountDeletionPreview>(
        'user',
        'accountDeletionPreview',
        {},
      );

  /// Deletes the account; [confirmation] must equal the account email.
  _ida.Future<void> deleteAccount(String confirmation) =>
      caller.callServerEndpoint<void>(
        'user',
        'deleteAccount',
        {'confirmation': confirmation},
      );
}

/// Version history shared by both apps (specs/07 §5). Editors+.
/// {@category Endpoint}
class EndpointVersion extends _isc.EndpointRef {
  EndpointVersion(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'version';

  _ida.Future<List<_itqtmykd.ItemVersionView>> list(
    _isc.UuidValue itemUuid,
    bool namedOnly, {
    int? beforeId,
    int? limit,
  }) => caller.callServerEndpoint<List<_itqtmykd.ItemVersionView>>(
    'version',
    'list',
    {
      'itemUuid': itemUuid,
      'namedOnly': namedOnly,
      'beforeId': beforeId,
      'limit': limit,
    },
  );

  /// Captures and names the current state.
  _ida.Future<_itqtmykd.ItemVersionView> nameCurrent(
    _isc.UuidValue itemUuid,
    String name,
  ) => caller.callServerEndpoint<_itqtmykd.ItemVersionView>(
    'version',
    'nameCurrent',
    {
      'itemUuid': itemUuid,
      'name': name,
    },
  );

  /// Names a version; null removes the name.
  _ida.Future<_itqtmykd.ItemVersionView> rename(
    _isc.UuidValue itemUuid,
    int versionId,
    String? name,
  ) => caller.callServerEndpoint<_itqtmykd.ItemVersionView>(
    'version',
    'rename',
    {
      'itemUuid': itemUuid,
      'versionId': versionId,
      'name': name,
    },
  );

  /// Restores a version (a restore point is captured first).
  _ida.Future<_iyei7m5z.VersionRestoreResult> restore(
    _isc.UuidValue itemUuid,
    int versionId,
  ) => caller.callServerEndpoint<_iyei7m5z.VersionRestoreResult>(
    'version',
    'restore',
    {
      'itemUuid': itemUuid,
      'versionId': versionId,
    },
  );

  /// Signed URL (15 min) of a Sheets snapshot (gzip NDJSON).
  _ida.Future<_i4i1hokq.FileUrlView> getSnapshotUrl(
    _isc.UuidValue itemUuid,
    int versionId,
  ) => caller.callServerEndpoint<_i4i1hokq.FileUrlView>(
    'version',
    'getSnapshotUrl',
    {
      'itemUuid': itemUuid,
      'versionId': versionId,
    },
  );
}

/// Online-only Sheets operations (suite 12 §2, Sheets 10, 12 §2.5).
/// {@category Endpoint}
class EndpointSheets extends _isc.EndpointRef {
  EndpointSheets(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'sheets';

  /// Reserves up to [count] (≤ 5) empty spaces for offline creation.
  _ida.Future<List<_isc.UuidValue>> reserveSpaces(int count) =>
      caller.callServerEndpoint<List<_isc.UuidValue>>(
        'sheets',
        'reserveSpaces',
        {'count': count},
      );

  /// Grants membership of the spreadsheet's space (role mirrored from the
  /// ACL) and adds it to the caller's active set.
  _ida.Future<_ii9ou7kh.SubscribeResult> subscribe(_isc.UuidValue itemUuid) =>
      caller.callServerEndpoint<_ii9ou7kh.SubscribeResult>(
        'sheets',
        'subscribe',
        {'itemUuid': itemUuid},
      );

  _ida.Future<void> unsubscribe(_isc.UuidValue itemUuid) =>
      caller.callServerEndpoint<void>(
        'sheets',
        'unsubscribe',
        {'itemUuid': itemUuid},
      );

  /// Pending-change guard: re-grants spaces with unsynced local changes.
  _ida.Future<List<_isc.UuidValue>> ensureSubscribed(
    List<_isc.UuidValue> spaces,
  ) => caller.callServerEndpoint<List<_isc.UuidValue>>(
    'sheets',
    'ensureSubscribed',
    {'spaces': spaces},
  );

  /// Row counts for download progress.
  _ida.Future<_imzum1ra.SpaceStats> spaceStats(_isc.UuidValue itemUuid) =>
      caller.callServerEndpoint<_imzum1ra.SpaceStats>(
        'sheets',
        'spaceStats',
        {'itemUuid': itemUuid},
      );

  /// Undo of a server-side change (`sheets.serverChange`).
  _ida.Future<_i107v8u3.RevertResult> revertChange(_isc.UuidValue changeId) =>
      caller.callServerEndpoint<_i107v8u3.RevertResult>(
        'sheets',
        'revertChange',
        {'changeId': changeId},
      );

  /// Redo of a reverted server-side change ([changeId] of the original or of
  /// its revert).
  _ida.Future<_i107v8u3.RevertResult> reapplyChange(_isc.UuidValue changeId) =>
      caller.callServerEndpoint<_i107v8u3.RevertResult>(
        'sheets',
        'reapplyChange',
        {'changeId': changeId},
      );

  _ida.Future<_i8ap5j9q.CellHistoryPage> cellHistory(
    _isc.UuidValue spreadsheetUuid,
    _isc.UuidValue sheetId,
    _isc.UuidValue rowId,
    _isc.UuidValue colId,
    String? cursor,
  ) => caller.callServerEndpoint<_i8ap5j9q.CellHistoryPage>(
    'sheets',
    'cellHistory',
    {
      'spreadsheetUuid': spreadsheetUuid,
      'sheetId': sheetId,
      'rowId': rowId,
      'colId': colId,
      'cursor': cursor,
    },
  );

  _ida.Future<_im0q5n3x.SheetsActivitySummary> activitySummary(
    _isc.UuidValue spreadsheetUuid,
    int days,
  ) => caller.callServerEndpoint<_im0q5n3x.SheetsActivitySummary>(
    'sheets',
    'activitySummary',
    {
      'spreadsheetUuid': spreadsheetUuid,
      'days': days,
    },
  );
}

/// The Sheets sync stream (suite 12 §2.5): `session.offlineSync.sync` with
/// `onMergeSuccess` processing. Clients use it as their
/// `OfflineSyncClient` transport instead of the module endpoint.
/// {@category Endpoint}
class EndpointSheetsSync extends _isc.EndpointRef {
  EndpointSheetsSync(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'sheetsSync';

  _ida.Stream<_ipulbpi2.OfflineSyncStreamEvent> sync({
    required _ida.Stream<_ipulbpi2.OfflineSyncStreamEvent> changes,
    required bool once,
  }) =>
      caller.callStreamingServerEndpoint<
        _ida.Stream<_ipulbpi2.OfflineSyncStreamEvent>,
        _ipulbpi2.OfflineSyncStreamEvent
      >(
        'sheetsSync',
        'sync',
        {'once': once},
        {'changes': changes},
      );
}

/// Write documents: the OT editing stream and helpers (Write 03 §1).
/// {@category Endpoint}
class EndpointDocument extends _isc.EndpointRef {
  EndpointDocument(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'document';

  /// Opens an editing/viewing session. The first message is [DocInit] with
  /// the ops since [knownRevision] (0 = none) or a snapshot.
  _ida.Stream<_ir9iog55.DocServerMessage> connect(
    _isc.UuidValue documentUuid,
    int knownRevision,
    _ida.Stream<_isw33y8i.DocClientMessage> input,
  ) =>
      caller.callStreamingServerEndpoint<
        _ida.Stream<_ir9iog55.DocServerMessage>,
        _ir9iog55.DocServerMessage
      >(
        'document',
        'connect',
        {
          'documentUuid': documentUuid,
          'knownRevision': knownRevision,
        },
        {'input': input},
      );

  _ida.Future<_in30vxre.DocumentInfo> getInfo(_isc.UuidValue documentUuid) =>
      caller.callServerEndpoint<_in30vxre.DocumentInfo>(
        'document',
        'getInfo',
        {'documentUuid': documentUuid},
      );

  /// Ops in [fromRevision]…[toRevision] (at most 1,000).
  _ida.Future<List<_i8x9070n.DocumentOpView>> getOps(
    _isc.UuidValue documentUuid,
    int fromRevision,
    int toRevision,
  ) => caller.callServerEndpoint<List<_i8x9070n.DocumentOpView>>(
    'document',
    'getOps',
    {
      'documentUuid': documentUuid,
      'fromRevision': fromRevision,
      'toRevision': toRevision,
    },
  );

  /// Content at [revision] (head when null; older revisions need Editor+).
  _ida.Future<_i8beogda.DocumentSnapshotView> getSnapshot(
    _isc.UuidValue documentUuid,
    int? revision,
  ) => caller.callServerEndpoint<_i8beogda.DocumentSnapshotView>(
    'document',
    'getSnapshot',
    {
      'documentUuid': documentUuid,
      'revision': revision,
    },
  );

  /// LWW metadata change (themeId, pageSetup, language, frontMatter).
  _ida.Future<void> updateMeta(
    _isc.UuidValue documentUuid,
    _ih34yxbq.DocumentMetaPatch patch,
    _isc.UuidValue clientOpId,
  ) => caller.callServerEndpoint<void>(
    'document',
    'updateMeta',
    {
      'documentUuid': documentUuid,
      'patch': patch,
      'clientOpId': clientOpId,
    },
  );
}

/// Server-side Write exports and conversions (Write 07 §10). Formats use
/// MCP names: md, md_zip, pdf, html, html_zip, docx, odt, rtf, epub, txt.
/// {@category Endpoint}
class EndpointWriteExport extends _isc.EndpointRef {
  EndpointWriteExport(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'writeExport';

  _ida.Future<_ia6gray1.ExportResultView> export(
    _isc.UuidValue documentUuid,
    String format,
    String optionsJson,
    int? revision,
  ) => caller.callServerEndpoint<_ia6gray1.ExportResultView>(
    'writeExport',
    'export',
    {
      'documentUuid': documentUuid,
      'format': format,
      'optionsJson': optionsJson,
      'revision': revision,
    },
  );

  /// Progress events; the last one is `done` or `error`. Cancel by closing.
  _ida.Stream<_i1vrysbd.ExportProgressEvent> exportWithProgress(
    _isc.UuidValue documentUuid,
    String format,
    String optionsJson,
    int? revision,
  ) =>
      caller.callStreamingServerEndpoint<
        _ida.Stream<_i1vrysbd.ExportProgressEvent>,
        _i1vrysbd.ExportProgressEvent
      >(
        'writeExport',
        'exportWithProgress',
        {
          'documentUuid': documentUuid,
          'format': format,
          'optionsJson': optionsJson,
          'revision': revision,
        },
        {},
      );

  _ida.Future<_ia522en0.ConvertForInsertResult> convertForInsert(
    _isc.UuidValue uploadId,
    String format,
    String optionsJson,
  ) => caller.callServerEndpoint<_ia522en0.ConvertForInsertResult>(
    'writeExport',
    'convertForInsert',
    {
      'uploadId': uploadId,
      'format': format,
      'optionsJson': optionsJson,
    },
  );

  /// Image proxy for client exports (CORS-blocked remote images).
  _ida.Future<_idt.ByteData> fetchImage(
    _isc.UuidValue documentUuid,
    String src,
  ) => caller.callServerEndpoint<_idt.ByteData>(
    'writeExport',
    'fetchImage',
    {
      'documentUuid': documentUuid,
      'src': src,
    },
  );
}

/// Write version history (Write 08 §4.3). Editors+.
/// {@category Endpoint}
class EndpointWriteHistory extends _isc.EndpointRef {
  EndpointWriteHistory(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'writeHistory';

  _ida.Future<_igd4fcl2.WriteVersionDocument> getVersionDocument(
    _isc.UuidValue documentUuid,
    int revision,
  ) => caller.callServerEndpoint<_igd4fcl2.WriteVersionDocument>(
    'writeHistory',
    'getVersionDocument',
    {
      'documentUuid': documentUuid,
      'revision': revision,
    },
  );

  _ida.Future<_iohaffow.WriteDiffView> diff(
    _isc.UuidValue documentUuid,
    int fromRevision,
    int toRevision,
  ) => caller.callServerEndpoint<_iohaffow.WriteDiffView>(
    'writeHistory',
    'diff',
    {
      'documentUuid': documentUuid,
      'fromRevision': fromRevision,
      'toRevision': toRevision,
    },
  );

  _ida.Future<_itqtmykd.ItemVersionView> createRestorePoint(
    _isc.UuidValue documentUuid,
  ) => caller.callServerEndpoint<_itqtmykd.ItemVersionView>(
    'writeHistory',
    'createRestorePoint',
    {'documentUuid': documentUuid},
  );

  _ida.Future<_iyei7m5z.VersionRestoreResult> restore(
    _isc.UuidValue documentUuid,
    int versionId,
  ) => caller.callServerEndpoint<_iyei7m5z.VersionRestoreResult>(
    'writeHistory',
    'restore',
    {
      'documentUuid': documentUuid,
      'versionId': versionId,
    },
  );

  _ida.Future<_iatsgjjq.DriveItemView> copyVersion(
    _isc.UuidValue documentUuid,
    int versionId,
    String name,
    _isc.UuidValue? parentUuid,
  ) => caller.callServerEndpoint<_iatsgjjq.DriveItemView>(
    'writeHistory',
    'copyVersion',
    {
      'documentUuid': documentUuid,
      'versionId': versionId,
      'name': name,
      'parentUuid': parentUuid,
    },
  );
}

/// Write themes (Write 06 §5.5).
/// {@category Endpoint}
class EndpointWriteTheme extends _isc.EndpointRef {
  EndpointWriteTheme(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'writeTheme';

  _ida.Future<List<_i2zuh8f2.WriteThemeView>> listBuiltins() =>
      caller.callServerEndpoint<List<_i2zuh8f2.WriteThemeView>>(
        'writeTheme',
        'listBuiltins',
        {},
      );

  _ida.Future<List<_i2zuh8f2.WriteThemeView>> listMine() =>
      caller.callServerEndpoint<List<_i2zuh8f2.WriteThemeView>>(
        'writeTheme',
        'listMine',
        {},
      );

  _ida.Future<_i2zuh8f2.WriteThemeView> get(
    _isc.UuidValue uuid,
    _isc.UuidValue? viaDocumentUuid,
  ) => caller.callServerEndpoint<_i2zuh8f2.WriteThemeView>(
    'writeTheme',
    'get',
    {
      'uuid': uuid,
      'viaDocumentUuid': viaDocumentUuid,
    },
  );

  _ida.Future<List<_i2zuh8f2.WriteThemeView>> getMany(
    List<_isc.UuidValue> uuids,
    _isc.UuidValue? viaDocumentUuid,
  ) => caller.callServerEndpoint<List<_i2zuh8f2.WriteThemeView>>(
    'writeTheme',
    'getMany',
    {
      'uuids': uuids,
      'viaDocumentUuid': viaDocumentUuid,
    },
  );

  _ida.Future<_i2zuh8f2.WriteThemeView> create(
    String name,
    String json,
    _isc.UuidValue? basedOnUuid,
  ) => caller.callServerEndpoint<_i2zuh8f2.WriteThemeView>(
    'writeTheme',
    'create',
    {
      'name': name,
      'json': json,
      'basedOnUuid': basedOnUuid,
    },
  );

  /// Saves a theme; throws [ThemeConflictException] when [expectedVersion]
  /// is stale.
  _ida.Future<_i2zuh8f2.WriteThemeView> update(
    _isc.UuidValue uuid,
    String json,
    int expectedVersion,
  ) => caller.callServerEndpoint<_i2zuh8f2.WriteThemeView>(
    'writeTheme',
    'update',
    {
      'uuid': uuid,
      'json': json,
      'expectedVersion': expectedVersion,
    },
  );

  _ida.Future<_i2zuh8f2.WriteThemeView> rename(
    _isc.UuidValue uuid,
    String name,
    int expectedVersion,
  ) => caller.callServerEndpoint<_i2zuh8f2.WriteThemeView>(
    'writeTheme',
    'rename',
    {
      'uuid': uuid,
      'name': name,
      'expectedVersion': expectedVersion,
    },
  );

  /// Copies a built-in or readable theme into the caller's library.
  _ida.Future<_i2zuh8f2.WriteThemeView> duplicate(
    _isc.UuidValue uuid,
    String name,
    _isc.UuidValue? viaDocumentUuid,
  ) => caller.callServerEndpoint<_i2zuh8f2.WriteThemeView>(
    'writeTheme',
    'duplicate',
    {
      'uuid': uuid,
      'name': name,
      'viaDocumentUuid': viaDocumentUuid,
    },
  );

  _ida.Future<_i2zuh8f2.WriteThemeView> delete(_isc.UuidValue uuid) =>
      caller.callServerEndpoint<_i2zuh8f2.WriteThemeView>(
        'writeTheme',
        'delete',
        {'uuid': uuid},
      );

  _ida.Future<_i2zuh8f2.WriteThemeView> restore(_isc.UuidValue uuid) =>
      caller.callServerEndpoint<_i2zuh8f2.WriteThemeView>(
        'writeTheme',
        'restore',
        {'uuid': uuid},
      );

  _ida.Future<List<_igytjuh5.WriteThemeRevisionView>> listRevisions(
    _isc.UuidValue uuid,
  ) => caller.callServerEndpoint<List<_igytjuh5.WriteThemeRevisionView>>(
    'writeTheme',
    'listRevisions',
    {'uuid': uuid},
  );

  _ida.Future<_igytjuh5.WriteThemeRevisionView> getRevision(
    _isc.UuidValue uuid,
    int version,
  ) => caller.callServerEndpoint<_igytjuh5.WriteThemeRevisionView>(
    'writeTheme',
    'getRevision',
    {
      'uuid': uuid,
      'version': version,
    },
  );

  /// Number of the caller's documents using the theme.
  _ida.Future<int> usage(_isc.UuidValue uuid) => caller.callServerEndpoint<int>(
    'writeTheme',
    'usage',
    {'uuid': uuid},
  );
}

class Modules {
  Modules(Client client) {
    serverpod_auth_idp = _iaic.Caller(client);
    offline_sync = _ipulbpi2.Caller(client);
    serverpod_auth_core = _iacc.Caller(client);
  }

  late final _iaic.Caller serverpod_auth_idp;

  late final _ipulbpi2.Caller offline_sync;

  late final _iacc.Caller serverpod_auth_core;
}

class Client extends _isc.ServerpodClientShared {
  Client(
    String host, {
    dynamic securityContext,
    Duration? streamingConnectionTimeout,
    Duration? connectionTimeout,
    Function(
      _isc.MethodCallContext,
      Object,
      StackTrace,
    )?
    onFailedCall,
    Function(_isc.MethodCallContext)? onSucceededCall,
    bool? disconnectStreamsOnLostInternetConnection,
    _i85jenna.Client? httpClientOverride,
  }) : super(
         host,
         _il2as5qe.Protocol(),
         securityContext: securityContext,
         streamingConnectionTimeout: streamingConnectionTimeout,
         connectionTimeout: connectionTimeout,
         onFailedCall: onFailedCall,
         onSucceededCall: onSucceededCall,
         disconnectStreamsOnLostInternetConnection:
             disconnectStreamsOnLostInternetConnection,
         httpClientOverride: httpClientOverride,
       ) {
    emailIdp = EndpointEmailIdp(this);
    jwtRefresh = EndpointJwtRefresh(this);
    comment = EndpointComment(this);
    drive = EndpointDrive(this);
    e2eSupport = EndpointE2eSupport(this);
    feedback = EndpointFeedback(this);
    file = EndpointFile(this);
    uiBridge = EndpointUiBridge(this);
    meta = EndpointMeta(this);
    notification = EndpointNotification(this);
    presence = EndpointPresence(this);
    sharing = EndpointSharing(this);
    accessToken = EndpointAccessToken(this);
    user = EndpointUser(this);
    version = EndpointVersion(this);
    sheets = EndpointSheets(this);
    sheetsSync = EndpointSheetsSync(this);
    document = EndpointDocument(this);
    writeExport = EndpointWriteExport(this);
    writeHistory = EndpointWriteHistory(this);
    writeTheme = EndpointWriteTheme(this);
    modules = Modules(this);
  }

  late final EndpointEmailIdp emailIdp;

  late final EndpointJwtRefresh jwtRefresh;

  late final EndpointComment comment;

  late final EndpointDrive drive;

  late final EndpointE2eSupport e2eSupport;

  late final EndpointFeedback feedback;

  late final EndpointFile file;

  late final EndpointUiBridge uiBridge;

  late final EndpointMeta meta;

  late final EndpointNotification notification;

  late final EndpointPresence presence;

  late final EndpointSharing sharing;

  late final EndpointAccessToken accessToken;

  late final EndpointUser user;

  late final EndpointVersion version;

  late final EndpointSheets sheets;

  late final EndpointSheetsSync sheetsSync;

  late final EndpointDocument document;

  late final EndpointWriteExport writeExport;

  late final EndpointWriteHistory writeHistory;

  late final EndpointWriteTheme writeTheme;

  late final Modules modules;

  @override
  Map<String, _isc.EndpointRef> get endpointRefLookup => {
    'emailIdp': emailIdp,
    'jwtRefresh': jwtRefresh,
    'comment': comment,
    'drive': drive,
    'e2eSupport': e2eSupport,
    'feedback': feedback,
    'file': file,
    'uiBridge': uiBridge,
    'meta': meta,
    'notification': notification,
    'presence': presence,
    'sharing': sharing,
    'accessToken': accessToken,
    'user': user,
    'version': version,
    'sheets': sheets,
    'sheetsSync': sheetsSync,
    'document': document,
    'writeExport': writeExport,
    'writeHistory': writeHistory,
    'writeTheme': writeTheme,
  };

  @override
  Map<String, _isc.ModuleEndpointCaller> get moduleLookup => {
    'serverpod_auth_idp': modules.serverpod_auth_idp,
    'offline_sync': modules.offline_sync,
    'serverpod_auth_core': modules.serverpod_auth_core,
  };
}
