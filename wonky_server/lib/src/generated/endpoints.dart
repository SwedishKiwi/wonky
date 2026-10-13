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
import 'package:serverpod_auth_core_server/serverpod_auth_core_server.dart'
    as _iacs;
import 'package:serverpod_auth_idp_server/serverpod_auth_idp_server.dart'
    as _iais;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart'
    as _izehhkf5;
import 'package:wonky_server/src/generated/future_calls.dart' as _iwslocjr;
import 'package:wonky_server/src/generated/platform/ai/models/ai_provider.dart'
    as _i02m7u6n;
import 'package:wonky_server/src/generated/platform/ai/models/ai_quality.dart'
    as _idrzmvpg;
import 'package:wonky_server/src/generated/platform/ai/models/assistant_context_hints.dart'
    as _ixc2f7d5;
import 'package:wonky_server/src/generated/platform/ai/models/inline_ai_request.dart'
    as _i4c3y8bm;
import 'package:wonky_server/src/generated/platform/comments/comment_anchor_kind.dart'
    as _i384cqmz;
import 'package:wonky_server/src/generated/platform/comments/comment_filter.dart'
    as _i0f5nb76;
import 'package:wonky_server/src/generated/platform/common/access_role.dart'
    as _i9nsco4y;
import 'package:wonky_server/src/generated/platform/drive/drive_import_options.dart'
    as _iyihga8r;
import 'package:wonky_server/src/generated/platform/drive/drive_item_kind.dart'
    as _i0549mj7;
import 'package:wonky_server/src/generated/platform/drive/drive_list_filter.dart'
    as _iaoi0gn5;
import 'package:wonky_server/src/generated/platform/drive/drive_search_filters.dart'
    as _iub85lgd;
import 'package:wonky_server/src/generated/platform/drive/drive_sort.dart'
    as _il6plm80;
import 'package:wonky_server/src/generated/platform/drive/template_category.dart'
    as _inlkiawi;
import 'package:wonky_server/src/generated/platform/feedback/feedback_submission.dart'
    as _ira9srbn;
import 'package:wonky_server/src/generated/platform/files/stored_file_kind.dart'
    as _idhe6v6s;
import 'package:wonky_server/src/generated/platform/mcp/ui_bridge/ui_bridge_message.dart'
    as _is78z0de;
import 'package:wonky_server/src/generated/platform/presence/presence_update.dart'
    as _ipd65of1;
import 'package:wonky_server/src/generated/platform/sharing/item_sharing_settings.dart'
    as _i55sl7s1;
import 'package:wonky_server/src/generated/platform/users/user_preferences_patch.dart'
    as _ingbfbma;
import 'package:wonky_server/src/generated/write/messages/doc_client_message.dart'
    as _i64vpekp;
import 'package:wonky_server/src/generated/write/models/document_meta_patch.dart'
    as _issank2j;
import '../auth/email_idp_endpoint.dart' as _iuc1hd5t;
import '../auth/jwt_refresh_endpoint.dart' as _inwq3ztq;
import '../platform/activity/activity_endpoint.dart' as _id6etezj;
import '../platform/ai/assistant_endpoint.dart' as _i8k7ge8b;
import '../platform/comments/comment_endpoint.dart' as _iuwjzuw0;
import '../platform/drive/drive_endpoint.dart' as _ijanxtjh;
import '../platform/e2e/e2e_support_endpoint.dart' as _iqj5xom6;
import '../platform/feedback/feedback_endpoint.dart' as _i70eazm1;
import '../platform/files/file_endpoint.dart' as _iokth3bn;
import '../platform/mcp/ui_bridge/ui_bridge_endpoint.dart' as _ipb16bxt;
import '../platform/meta/meta_endpoint.dart' as _isistrmv;
import '../platform/notifications/notification_endpoint.dart' as _ia40tpv4;
import '../platform/presence/presence_endpoint.dart' as _iv7snmpw;
import '../platform/sharing/sharing_endpoint.dart' as _itz30x9e;
import '../platform/users/access_token_endpoint.dart' as _iusd4uiv;
import '../platform/users/google_idp_endpoint.dart' as _i3henulz;
import '../platform/users/user_endpoint.dart' as _iwtyukq6;
import '../platform/versions/version_endpoint.dart' as _im6cm90k;
import '../sheets/endpoints/sheets_endpoint.dart' as _izrkvdrt;
import '../sheets/endpoints/sheets_sync_endpoint.dart' as _iijmdr93;
import '../write/endpoints/document_endpoint.dart' as _iiabxp2u;
import '../write/endpoints/write_export_endpoint.dart' as _ia4kadx2;
import '../write/endpoints/write_history_endpoint.dart' as _izdjh3zj;
import '../write/endpoints/write_theme_endpoint.dart' as _ii3xbyyg;
export 'future_calls.dart' show ServerpodFutureCallsGetter;

class Endpoints extends _is.EndpointDispatch {
  @override
  void initializeEndpoints(_is.Server server) {
    var endpoints = <String, _is.Endpoint>{
      'emailIdp': _iuc1hd5t.EmailIdpEndpoint()
        ..initialize(
          server,
          'emailIdp',
          null,
        ),
      'jwtRefresh': _inwq3ztq.JwtRefreshEndpoint()
        ..initialize(
          server,
          'jwtRefresh',
          null,
        ),
      'activity': _id6etezj.ActivityEndpoint()
        ..initialize(
          server,
          'activity',
          null,
        ),
      'assistant': _i8k7ge8b.AssistantEndpoint()
        ..initialize(
          server,
          'assistant',
          null,
        ),
      'comment': _iuwjzuw0.CommentEndpoint()
        ..initialize(
          server,
          'comment',
          null,
        ),
      'drive': _ijanxtjh.DriveEndpoint()
        ..initialize(
          server,
          'drive',
          null,
        ),
      'e2eSupport': _iqj5xom6.E2eSupportEndpoint()
        ..initialize(
          server,
          'e2eSupport',
          null,
        ),
      'feedback': _i70eazm1.FeedbackEndpoint()
        ..initialize(
          server,
          'feedback',
          null,
        ),
      'file': _iokth3bn.FileEndpoint()
        ..initialize(
          server,
          'file',
          null,
        ),
      'uiBridge': _ipb16bxt.UiBridgeEndpoint()
        ..initialize(
          server,
          'uiBridge',
          null,
        ),
      'meta': _isistrmv.MetaEndpoint()
        ..initialize(
          server,
          'meta',
          null,
        ),
      'notification': _ia40tpv4.NotificationEndpoint()
        ..initialize(
          server,
          'notification',
          null,
        ),
      'presence': _iv7snmpw.PresenceEndpoint()
        ..initialize(
          server,
          'presence',
          null,
        ),
      'sharing': _itz30x9e.SharingEndpoint()
        ..initialize(
          server,
          'sharing',
          null,
        ),
      'accessToken': _iusd4uiv.AccessTokenEndpoint()
        ..initialize(
          server,
          'accessToken',
          null,
        ),
      'googleIdp': _i3henulz.GoogleIdpEndpoint()
        ..initialize(
          server,
          'googleIdp',
          null,
        ),
      'user': _iwtyukq6.UserEndpoint()
        ..initialize(
          server,
          'user',
          null,
        ),
      'version': _im6cm90k.VersionEndpoint()
        ..initialize(
          server,
          'version',
          null,
        ),
      'sheets': _izrkvdrt.SheetsEndpoint()
        ..initialize(
          server,
          'sheets',
          null,
        ),
      'sheetsSync': _iijmdr93.SheetsSyncEndpoint()
        ..initialize(
          server,
          'sheetsSync',
          null,
        ),
      'document': _iiabxp2u.DocumentEndpoint()
        ..initialize(
          server,
          'document',
          null,
        ),
      'writeExport': _ia4kadx2.WriteExportEndpoint()
        ..initialize(
          server,
          'writeExport',
          null,
        ),
      'writeHistory': _izdjh3zj.WriteHistoryEndpoint()
        ..initialize(
          server,
          'writeHistory',
          null,
        ),
      'writeTheme': _ii3xbyyg.WriteThemeEndpoint()
        ..initialize(
          server,
          'writeTheme',
          null,
        ),
    };
    connectors['emailIdp'] = _is.EndpointConnector(
      name: 'emailIdp',
      endpoint: endpoints['emailIdp']!,
      methodConnectors: {
        'login': _is.MethodConnector(
          name: 'login',
          params: {
            'email': _is.ParameterDescription(
              name: 'email',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'password': _is.ParameterDescription(
              name: 'password',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint).login(
                    session,
                    email: params['email'],
                    password: params['password'],
                  ),
        ),
        'startRegistration': _is.MethodConnector(
          name: 'startRegistration',
          params: {
            'email': _is.ParameterDescription(
              name: 'email',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint)
                  .startRegistration(
                    session,
                    email: params['email'],
                  ),
        ),
        'verifyRegistrationCode': _is.MethodConnector(
          name: 'verifyRegistrationCode',
          params: {
            'accountRequestId': _is.ParameterDescription(
              name: 'accountRequestId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'verificationCode': _is.ParameterDescription(
              name: 'verificationCode',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint)
                  .verifyRegistrationCode(
                    session,
                    accountRequestId: params['accountRequestId'],
                    verificationCode: params['verificationCode'],
                  ),
        ),
        'finishRegistration': _is.MethodConnector(
          name: 'finishRegistration',
          params: {
            'registrationToken': _is.ParameterDescription(
              name: 'registrationToken',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'password': _is.ParameterDescription(
              name: 'password',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint)
                  .finishRegistration(
                    session,
                    registrationToken: params['registrationToken'],
                    password: params['password'],
                  ),
        ),
        'startPasswordReset': _is.MethodConnector(
          name: 'startPasswordReset',
          params: {
            'email': _is.ParameterDescription(
              name: 'email',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint)
                  .startPasswordReset(
                    session,
                    email: params['email'],
                  ),
        ),
        'verifyPasswordResetCode': _is.MethodConnector(
          name: 'verifyPasswordResetCode',
          params: {
            'passwordResetRequestId': _is.ParameterDescription(
              name: 'passwordResetRequestId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'verificationCode': _is.ParameterDescription(
              name: 'verificationCode',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint)
                  .verifyPasswordResetCode(
                    session,
                    passwordResetRequestId: params['passwordResetRequestId'],
                    verificationCode: params['verificationCode'],
                  ),
        ),
        'finishPasswordReset': _is.MethodConnector(
          name: 'finishPasswordReset',
          params: {
            'finishPasswordResetToken': _is.ParameterDescription(
              name: 'finishPasswordResetToken',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'newPassword': _is.ParameterDescription(
              name: 'newPassword',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint)
                  .finishPasswordReset(
                    session,
                    finishPasswordResetToken:
                        params['finishPasswordResetToken'],
                    newPassword: params['newPassword'],
                  ),
        ),
        'hasAccount': _is.MethodConnector(
          name: 'hasAccount',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint)
                  .hasAccount(session),
        ),
      },
    );
    connectors['jwtRefresh'] = _is.EndpointConnector(
      name: 'jwtRefresh',
      endpoint: endpoints['jwtRefresh']!,
      methodConnectors: {
        'refreshAccessToken': _is.MethodConnector(
          name: 'refreshAccessToken',
          params: {
            'refreshToken': _is.ParameterDescription(
              name: 'refreshToken',
              type: _is.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['jwtRefresh'] as _inwq3ztq.JwtRefreshEndpoint)
                      .refreshAccessToken(
                        session,
                        refreshToken: params['refreshToken'],
                      ),
        ),
      },
    );
    connectors['activity'] = _is.EndpointConnector(
      name: 'activity',
      endpoint: endpoints['activity']!,
      methodConnectors: {
        'dashboard': _is.MethodConnector(
          name: 'dashboard',
          params: {
            'itemUuid': _is.ParameterDescription(
              name: 'itemUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'days': _is.ParameterDescription(
              name: 'days',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['activity'] as _id6etezj.ActivityEndpoint)
                  .dashboard(
                    session,
                    params['itemUuid'],
                    params['days'],
                  ),
        ),
        'showViewHistory': _is.MethodConnector(
          name: 'showViewHistory',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['activity'] as _id6etezj.ActivityEndpoint)
                  .showViewHistory(session),
        ),
        'setShowViewHistory': _is.MethodConnector(
          name: 'setShowViewHistory',
          params: {
            'show': _is.ParameterDescription(
              name: 'show',
              type: _is.getType<bool>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['activity'] as _id6etezj.ActivityEndpoint)
                  .setShowViewHistory(
                    session,
                    params['show'],
                  ),
        ),
      },
    );
    connectors['assistant'] = _is.EndpointConnector(
      name: 'assistant',
      endpoint: endpoints['assistant']!,
      methodConnectors: {
        'getStatus': _is.MethodConnector(
          name: 'getStatus',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['assistant'] as _i8k7ge8b.AssistantEndpoint)
                  .getStatus(session),
        ),
        'setQuality': _is.MethodConnector(
          name: 'setQuality',
          params: {
            'quality': _is.ParameterDescription(
              name: 'quality',
              type: _is.getType<_idrzmvpg.AiQuality>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['assistant'] as _i8k7ge8b.AssistantEndpoint)
                  .setQuality(
                    session,
                    params['quality'],
                  ),
        ),
        'setProviderKey': _is.MethodConnector(
          name: 'setProviderKey',
          params: {
            'provider': _is.ParameterDescription(
              name: 'provider',
              type: _is.getType<_i02m7u6n.AiProvider>(),
              nullable: false,
            ),
            'apiKey': _is.ParameterDescription(
              name: 'apiKey',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['assistant'] as _i8k7ge8b.AssistantEndpoint)
                  .setProviderKey(
                    session,
                    params['provider'],
                    params['apiKey'],
                  ),
        ),
        'removeProviderKey': _is.MethodConnector(
          name: 'removeProviderKey',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['assistant'] as _i8k7ge8b.AssistantEndpoint)
                  .removeProviderKey(session),
        ),
        'stop': _is.MethodConnector(
          name: 'stop',
          params: {
            'threadId': _is.ParameterDescription(
              name: 'threadId',
              type: _is.getType<int?>(),
              nullable: true,
            ),
            'runId': _is.ParameterDescription(
              name: 'runId',
              type: _is.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['assistant'] as _i8k7ge8b.AssistantEndpoint).stop(
                    session,
                    params['threadId'],
                    params['runId'],
                  ),
        ),
        'confirm': _is.MethodConnector(
          name: 'confirm',
          params: {
            'runId': _is.ParameterDescription(
              name: 'runId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'confirmationId': _is.ParameterDescription(
              name: 'confirmationId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'allow': _is.ParameterDescription(
              name: 'allow',
              type: _is.getType<bool>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['assistant'] as _i8k7ge8b.AssistantEndpoint)
                  .confirm(
                    session,
                    params['runId'],
                    params['confirmationId'],
                    params['allow'],
                  ),
        ),
        'listThreads': _is.MethodConnector(
          name: 'listThreads',
          params: {
            'itemUuid': _is.ParameterDescription(
              name: 'itemUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['assistant'] as _i8k7ge8b.AssistantEndpoint)
                  .listThreads(
                    session,
                    params['itemUuid'],
                  ),
        ),
        'getThread': _is.MethodConnector(
          name: 'getThread',
          params: {
            'threadId': _is.ParameterDescription(
              name: 'threadId',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['assistant'] as _i8k7ge8b.AssistantEndpoint)
                  .getThread(
                    session,
                    params['threadId'],
                  ),
        ),
        'deleteThread': _is.MethodConnector(
          name: 'deleteThread',
          params: {
            'threadId': _is.ParameterDescription(
              name: 'threadId',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['assistant'] as _i8k7ge8b.AssistantEndpoint)
                  .deleteThread(
                    session,
                    params['threadId'],
                  ),
        ),
        'clearHistory': _is.MethodConnector(
          name: 'clearHistory',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['assistant'] as _i8k7ge8b.AssistantEndpoint)
                  .clearHistory(session),
        ),
        'revertChange': _is.MethodConnector(
          name: 'revertChange',
          params: {
            'changeId': _is.ParameterDescription(
              name: 'changeId',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['assistant'] as _i8k7ge8b.AssistantEndpoint)
                  .revertChange(
                    session,
                    params['changeId'],
                  ),
        ),
        'chat': _is.MethodStreamConnector(
          name: 'chat',
          params: {
            'threadId': _is.ParameterDescription(
              name: 'threadId',
              type: _is.getType<int?>(),
              nullable: true,
            ),
            'itemUuid': _is.ParameterDescription(
              name: 'itemUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'message': _is.ParameterDescription(
              name: 'message',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'hints': _is.ParameterDescription(
              name: 'hints',
              type: _is.getType<_ixc2f7d5.AssistantContextHints>(),
              nullable: false,
            ),
          },
          streamParams: {},
          returnType: _is.MethodStreamReturnType.streamType,
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
                Map<String, Stream> streamParams,
              ) => (endpoints['assistant'] as _i8k7ge8b.AssistantEndpoint).chat(
                session,
                params['threadId'],
                params['itemUuid'],
                params['message'],
                params['hints'],
              ),
        ),
        'inline': _is.MethodStreamConnector(
          name: 'inline',
          params: {
            'request': _is.ParameterDescription(
              name: 'request',
              type: _is.getType<_i4c3y8bm.InlineAiRequest>(),
              nullable: false,
            ),
          },
          streamParams: {},
          returnType: _is.MethodStreamReturnType.streamType,
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
                Map<String, Stream> streamParams,
              ) => (endpoints['assistant'] as _i8k7ge8b.AssistantEndpoint)
                  .inline(
                    session,
                    params['request'],
                  ),
        ),
        'proofread': _is.MethodStreamConnector(
          name: 'proofread',
          params: {
            'itemUuid': _is.ParameterDescription(
              name: 'itemUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'start': _is.ParameterDescription(
              name: 'start',
              type: _is.getType<int?>(),
              nullable: true,
            ),
            'length': _is.ParameterDescription(
              name: 'length',
              type: _is.getType<int?>(),
              nullable: true,
            ),
          },
          streamParams: {},
          returnType: _is.MethodStreamReturnType.streamType,
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
                Map<String, Stream> streamParams,
              ) => (endpoints['assistant'] as _i8k7ge8b.AssistantEndpoint)
                  .proofread(
                    session,
                    params['itemUuid'],
                    params['start'],
                    params['length'],
                  ),
        ),
      },
    );
    connectors['comment'] = _is.EndpointConnector(
      name: 'comment',
      endpoint: endpoints['comment']!,
      methodConnectors: {
        'listThreads': _is.MethodConnector(
          name: 'listThreads',
          params: {
            'itemUuid': _is.ParameterDescription(
              name: 'itemUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'filter': _is.ParameterDescription(
              name: 'filter',
              type: _is.getType<_i0f5nb76.CommentFilter>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['comment'] as _iuwjzuw0.CommentEndpoint)
                  .listThreads(
                    session,
                    params['itemUuid'],
                    params['filter'],
                  ),
        ),
        'getThread': _is.MethodConnector(
          name: 'getThread',
          params: {
            'threadUuid': _is.ParameterDescription(
              name: 'threadUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['comment'] as _iuwjzuw0.CommentEndpoint).getThread(
                    session,
                    params['threadUuid'],
                  ),
        ),
        'createThread': _is.MethodConnector(
          name: 'createThread',
          params: {
            'threadUuid': _is.ParameterDescription(
              name: 'threadUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'itemUuid': _is.ParameterDescription(
              name: 'itemUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'anchorKind': _is.ParameterDescription(
              name: 'anchorKind',
              type: _is.getType<_i384cqmz.CommentAnchorKind>(),
              nullable: false,
            ),
            'anchorJson': _is.ParameterDescription(
              name: 'anchorJson',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'quotedText': _is.ParameterDescription(
              name: 'quotedText',
              type: _is.getType<String?>(),
              nullable: true,
            ),
            'body': _is.ParameterDescription(
              name: 'body',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'mentions': _is.ParameterDescription(
              name: 'mentions',
              type: _is.getType<List<int>>(),
              nullable: false,
            ),
            'assigneeId': _is.ParameterDescription(
              name: 'assigneeId',
              type: _is.getType<int?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['comment'] as _iuwjzuw0.CommentEndpoint)
                  .createThread(
                    session,
                    params['threadUuid'],
                    params['itemUuid'],
                    params['anchorKind'],
                    params['anchorJson'],
                    params['quotedText'],
                    params['body'],
                    params['mentions'],
                    params['assigneeId'],
                  ),
        ),
        'reply': _is.MethodConnector(
          name: 'reply',
          params: {
            'threadUuid': _is.ParameterDescription(
              name: 'threadUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'body': _is.ParameterDescription(
              name: 'body',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'mentions': _is.ParameterDescription(
              name: 'mentions',
              type: _is.getType<List<int>>(),
              nullable: false,
            ),
            'commentUuid': _is.ParameterDescription(
              name: 'commentUuid',
              type: _is.getType<_is.UuidValue?>(),
              nullable: true,
            ),
            'assigneeId': _is.ParameterDescription(
              name: 'assigneeId',
              type: _is.getType<int?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['comment'] as _iuwjzuw0.CommentEndpoint).reply(
                    session,
                    params['threadUuid'],
                    params['body'],
                    params['mentions'],
                    commentUuid: params['commentUuid'],
                    assigneeId: params['assigneeId'],
                  ),
        ),
        'edit': _is.MethodConnector(
          name: 'edit',
          params: {
            'commentId': _is.ParameterDescription(
              name: 'commentId',
              type: _is.getType<int>(),
              nullable: false,
            ),
            'body': _is.ParameterDescription(
              name: 'body',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'mentions': _is.ParameterDescription(
              name: 'mentions',
              type: _is.getType<List<int>?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['comment'] as _iuwjzuw0.CommentEndpoint).edit(
                    session,
                    params['commentId'],
                    params['body'],
                    mentions: params['mentions'],
                  ),
        ),
        'delete': _is.MethodConnector(
          name: 'delete',
          params: {
            'commentId': _is.ParameterDescription(
              name: 'commentId',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['comment'] as _iuwjzuw0.CommentEndpoint).delete(
                    session,
                    params['commentId'],
                  ),
        ),
        'deleteThread': _is.MethodConnector(
          name: 'deleteThread',
          params: {
            'threadUuid': _is.ParameterDescription(
              name: 'threadUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['comment'] as _iuwjzuw0.CommentEndpoint)
                  .deleteThread(
                    session,
                    params['threadUuid'],
                  ),
        ),
        'resolve': _is.MethodConnector(
          name: 'resolve',
          params: {
            'threadUuid': _is.ParameterDescription(
              name: 'threadUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['comment'] as _iuwjzuw0.CommentEndpoint).resolve(
                    session,
                    params['threadUuid'],
                  ),
        ),
        'reopen': _is.MethodConnector(
          name: 'reopen',
          params: {
            'threadUuid': _is.ParameterDescription(
              name: 'threadUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['comment'] as _iuwjzuw0.CommentEndpoint).reopen(
                    session,
                    params['threadUuid'],
                  ),
        ),
        'react': _is.MethodConnector(
          name: 'react',
          params: {
            'commentId': _is.ParameterDescription(
              name: 'commentId',
              type: _is.getType<int>(),
              nullable: false,
            ),
            'emoji': _is.ParameterDescription(
              name: 'emoji',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['comment'] as _iuwjzuw0.CommentEndpoint).react(
                    session,
                    params['commentId'],
                    params['emoji'],
                  ),
        ),
        'updateAnchor': _is.MethodConnector(
          name: 'updateAnchor',
          params: {
            'threadUuid': _is.ParameterDescription(
              name: 'threadUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'anchorJson': _is.ParameterDescription(
              name: 'anchorJson',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'anchorKind': _is.ParameterDescription(
              name: 'anchorKind',
              type: _is.getType<_i384cqmz.CommentAnchorKind?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['comment'] as _iuwjzuw0.CommentEndpoint)
                  .updateAnchor(
                    session,
                    params['threadUuid'],
                    params['anchorJson'],
                    anchorKind: params['anchorKind'],
                  ),
        ),
        'watch': _is.MethodStreamConnector(
          name: 'watch',
          params: {
            'itemUuid': _is.ParameterDescription(
              name: 'itemUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          streamParams: {},
          returnType: _is.MethodStreamReturnType.streamType,
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
                Map<String, Stream> streamParams,
              ) => (endpoints['comment'] as _iuwjzuw0.CommentEndpoint).watch(
                session,
                params['itemUuid'],
              ),
        ),
      },
    );
    connectors['drive'] = _is.EndpointConnector(
      name: 'drive',
      endpoint: endpoints['drive']!,
      methodConnectors: {
        'list': _is.MethodConnector(
          name: 'list',
          params: {
            'folderUuid': _is.ParameterDescription(
              name: 'folderUuid',
              type: _is.getType<_is.UuidValue?>(),
              nullable: true,
            ),
            'filter': _is.ParameterDescription(
              name: 'filter',
              type: _is.getType<_iaoi0gn5.DriveListFilter>(),
              nullable: false,
            ),
            'sort': _is.ParameterDescription(
              name: 'sort',
              type: _is.getType<_il6plm80.DriveSort>(),
              nullable: false,
            ),
            'cursor': _is.ParameterDescription(
              name: 'cursor',
              type: _is.getType<String?>(),
              nullable: true,
            ),
            'limit': _is.ParameterDescription(
              name: 'limit',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['drive'] as _ijanxtjh.DriveEndpoint).list(
                session,
                params['folderUuid'],
                params['filter'],
                params['sort'],
                params['cursor'],
                params['limit'],
              ),
        ),
        'get': _is.MethodConnector(
          name: 'get',
          params: {
            'uuid': _is.ParameterDescription(
              name: 'uuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['drive'] as _ijanxtjh.DriveEndpoint).get(
                session,
                params['uuid'],
              ),
        ),
        'path': _is.MethodConnector(
          name: 'path',
          params: {
            'uuid': _is.ParameterDescription(
              name: 'uuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['drive'] as _ijanxtjh.DriveEndpoint).path(
                session,
                params['uuid'],
              ),
        ),
        'search': _is.MethodConnector(
          name: 'search',
          params: {
            'query': _is.ParameterDescription(
              name: 'query',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'filters': _is.ParameterDescription(
              name: 'filters',
              type: _is.getType<_iub85lgd.DriveSearchFilters>(),
              nullable: false,
            ),
            'cursor': _is.ParameterDescription(
              name: 'cursor',
              type: _is.getType<String?>(),
              nullable: true,
            ),
            'limit': _is.ParameterDescription(
              name: 'limit',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['drive'] as _ijanxtjh.DriveEndpoint).search(
                session,
                params['query'],
                params['filters'],
                params['cursor'],
                params['limit'],
              ),
        ),
        'createFolder': _is.MethodConnector(
          name: 'createFolder',
          params: {
            'parentUuid': _is.ParameterDescription(
              name: 'parentUuid',
              type: _is.getType<_is.UuidValue?>(),
              nullable: true,
            ),
            'name': _is.ParameterDescription(
              name: 'name',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['drive'] as _ijanxtjh.DriveEndpoint).createFolder(
                    session,
                    params['parentUuid'],
                    params['name'],
                  ),
        ),
        'createDocument': _is.MethodConnector(
          name: 'createDocument',
          params: {
            'parentUuid': _is.ParameterDescription(
              name: 'parentUuid',
              type: _is.getType<_is.UuidValue?>(),
              nullable: true,
            ),
            'name': _is.ParameterDescription(
              name: 'name',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'templateUuid': _is.ParameterDescription(
              name: 'templateUuid',
              type: _is.getType<_is.UuidValue?>(),
              nullable: true,
            ),
            'initialMarkdown': _is.ParameterDescription(
              name: 'initialMarkdown',
              type: _is.getType<String?>(),
              nullable: true,
            ),
            'documentUuid': _is.ParameterDescription(
              name: 'documentUuid',
              type: _is.getType<_is.UuidValue?>(),
              nullable: true,
            ),
            'itemUuid': _is.ParameterDescription(
              name: 'itemUuid',
              type: _is.getType<_is.UuidValue?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['drive'] as _ijanxtjh.DriveEndpoint)
                  .createDocument(
                    session,
                    params['parentUuid'],
                    params['name'],
                    params['templateUuid'],
                    params['initialMarkdown'],
                    documentUuid: params['documentUuid'],
                    itemUuid: params['itemUuid'],
                  ),
        ),
        'registerSpreadsheet': _is.MethodConnector(
          name: 'registerSpreadsheet',
          params: {
            'spaceUuid': _is.ParameterDescription(
              name: 'spaceUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'parentUuid': _is.ParameterDescription(
              name: 'parentUuid',
              type: _is.getType<_is.UuidValue?>(),
              nullable: true,
            ),
            'name': _is.ParameterDescription(
              name: 'name',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['drive'] as _ijanxtjh.DriveEndpoint)
                  .registerSpreadsheet(
                    session,
                    params['spaceUuid'],
                    params['parentUuid'],
                    params['name'],
                  ),
        ),
        'createSpreadsheet': _is.MethodConnector(
          name: 'createSpreadsheet',
          params: {
            'parentUuid': _is.ParameterDescription(
              name: 'parentUuid',
              type: _is.getType<_is.UuidValue?>(),
              nullable: true,
            ),
            'name': _is.ParameterDescription(
              name: 'name',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'templateUuid': _is.ParameterDescription(
              name: 'templateUuid',
              type: _is.getType<_is.UuidValue?>(),
              nullable: true,
            ),
            'locale': _is.ParameterDescription(
              name: 'locale',
              type: _is.getType<String?>(),
              nullable: true,
            ),
            'timeZone': _is.ParameterDescription(
              name: 'timeZone',
              type: _is.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['drive'] as _ijanxtjh.DriveEndpoint)
                  .createSpreadsheet(
                    session,
                    params['parentUuid'],
                    params['name'],
                    params['templateUuid'],
                    locale: params['locale'],
                    timeZone: params['timeZone'],
                  ),
        ),
        'rename': _is.MethodConnector(
          name: 'rename',
          params: {
            'uuid': _is.ParameterDescription(
              name: 'uuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'name': _is.ParameterDescription(
              name: 'name',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['drive'] as _ijanxtjh.DriveEndpoint).rename(
                session,
                params['uuid'],
                params['name'],
              ),
        ),
        'updateDescription': _is.MethodConnector(
          name: 'updateDescription',
          params: {
            'uuid': _is.ParameterDescription(
              name: 'uuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'description': _is.ParameterDescription(
              name: 'description',
              type: _is.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['drive'] as _ijanxtjh.DriveEndpoint)
                  .updateDescription(
                    session,
                    params['uuid'],
                    params['description'],
                  ),
        ),
        'move': _is.MethodConnector(
          name: 'move',
          params: {
            'uuids': _is.ParameterDescription(
              name: 'uuids',
              type: _is.getType<List<_is.UuidValue>>(),
              nullable: false,
            ),
            'newParentUuid': _is.ParameterDescription(
              name: 'newParentUuid',
              type: _is.getType<_is.UuidValue?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['drive'] as _ijanxtjh.DriveEndpoint).move(
                session,
                params['uuids'],
                params['newParentUuid'],
              ),
        ),
        'copy': _is.MethodConnector(
          name: 'copy',
          params: {
            'uuid': _is.ParameterDescription(
              name: 'uuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'newName': _is.ParameterDescription(
              name: 'newName',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'parentUuid': _is.ParameterDescription(
              name: 'parentUuid',
              type: _is.getType<_is.UuidValue?>(),
              nullable: true,
            ),
            'copyComments': _is.ParameterDescription(
              name: 'copyComments',
              type: _is.getType<bool>(),
              nullable: false,
            ),
            'copySharing': _is.ParameterDescription(
              name: 'copySharing',
              type: _is.getType<bool>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['drive'] as _ijanxtjh.DriveEndpoint).copy(
                session,
                params['uuid'],
                params['newName'],
                params['parentUuid'],
                params['copyComments'],
                params['copySharing'],
              ),
        ),
        'setStarred': _is.MethodConnector(
          name: 'setStarred',
          params: {
            'uuid': _is.ParameterDescription(
              name: 'uuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'starred': _is.ParameterDescription(
              name: 'starred',
              type: _is.getType<bool>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['drive'] as _ijanxtjh.DriveEndpoint).setStarred(
                    session,
                    params['uuid'],
                    params['starred'],
                  ),
        ),
        'setPinnedOffline': _is.MethodConnector(
          name: 'setPinnedOffline',
          params: {
            'uuid': _is.ParameterDescription(
              name: 'uuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'pinned': _is.ParameterDescription(
              name: 'pinned',
              type: _is.getType<bool>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['drive'] as _ijanxtjh.DriveEndpoint)
                  .setPinnedOffline(
                    session,
                    params['uuid'],
                    params['pinned'],
                  ),
        ),
        'markOpened': _is.MethodConnector(
          name: 'markOpened',
          params: {
            'uuid': _is.ParameterDescription(
              name: 'uuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['drive'] as _ijanxtjh.DriveEndpoint).markOpened(
                    session,
                    params['uuid'],
                  ),
        ),
        'addShortcut': _is.MethodConnector(
          name: 'addShortcut',
          params: {
            'uuid': _is.ParameterDescription(
              name: 'uuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'parentUuid': _is.ParameterDescription(
              name: 'parentUuid',
              type: _is.getType<_is.UuidValue?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['drive'] as _ijanxtjh.DriveEndpoint).addShortcut(
                    session,
                    params['uuid'],
                    params['parentUuid'],
                  ),
        ),
        'removeShortcut': _is.MethodConnector(
          name: 'removeShortcut',
          params: {
            'uuid': _is.ParameterDescription(
              name: 'uuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['drive'] as _ijanxtjh.DriveEndpoint)
                  .removeShortcut(
                    session,
                    params['uuid'],
                  ),
        ),
        'trash': _is.MethodConnector(
          name: 'trash',
          params: {
            'uuids': _is.ParameterDescription(
              name: 'uuids',
              type: _is.getType<List<_is.UuidValue>>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['drive'] as _ijanxtjh.DriveEndpoint).trash(
                session,
                params['uuids'],
              ),
        ),
        'restore': _is.MethodConnector(
          name: 'restore',
          params: {
            'uuids': _is.ParameterDescription(
              name: 'uuids',
              type: _is.getType<List<_is.UuidValue>>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['drive'] as _ijanxtjh.DriveEndpoint).restore(
                    session,
                    params['uuids'],
                  ),
        ),
        'deletePermanently': _is.MethodConnector(
          name: 'deletePermanently',
          params: {
            'uuids': _is.ParameterDescription(
              name: 'uuids',
              type: _is.getType<List<_is.UuidValue>>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['drive'] as _ijanxtjh.DriveEndpoint)
                  .deletePermanently(
                    session,
                    params['uuids'],
                  ),
        ),
        'emptyTrash': _is.MethodConnector(
          name: 'emptyTrash',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['drive'] as _ijanxtjh.DriveEndpoint)
                  .emptyTrash(session),
        ),
        'listTemplates': _is.MethodConnector(
          name: 'listTemplates',
          params: {
            'kind': _is.ParameterDescription(
              name: 'kind',
              type: _is.getType<_i0549mj7.DriveItemKind?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['drive'] as _ijanxtjh.DriveEndpoint).listTemplates(
                    session,
                    params['kind'],
                  ),
        ),
        'setTemplate': _is.MethodConnector(
          name: 'setTemplate',
          params: {
            'uuid': _is.ParameterDescription(
              name: 'uuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'category': _is.ParameterDescription(
              name: 'category',
              type: _is.getType<_inlkiawi.TemplateCategory?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['drive'] as _ijanxtjh.DriveEndpoint).setTemplate(
                    session,
                    params['uuid'],
                    params['category'],
                  ),
        ),
        'import': _is.MethodConnector(
          name: 'import',
          params: {
            'uploadId': _is.ParameterDescription(
              name: 'uploadId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'kind': _is.ParameterDescription(
              name: 'kind',
              type: _is.getType<_i0549mj7.DriveItemKind>(),
              nullable: false,
            ),
            'options': _is.ParameterDescription(
              name: 'options',
              type: _is.getType<_iyihga8r.DriveImportOptions>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['drive'] as _ijanxtjh.DriveEndpoint).import(
                session,
                params['uploadId'],
                params['kind'],
                params['options'],
              ),
        ),
        'storageUsage': _is.MethodConnector(
          name: 'storageUsage',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['drive'] as _ijanxtjh.DriveEndpoint)
                  .storageUsage(session),
        ),
        'setThumbnail': _is.MethodConnector(
          name: 'setThumbnail',
          params: {
            'uuid': _is.ParameterDescription(
              name: 'uuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'uploadedFileUuid': _is.ParameterDescription(
              name: 'uploadedFileUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['drive'] as _ijanxtjh.DriveEndpoint).setThumbnail(
                    session,
                    params['uuid'],
                    params['uploadedFileUuid'],
                  ),
        ),
        'activity': _is.MethodConnector(
          name: 'activity',
          params: {
            'uuid': _is.ParameterDescription(
              name: 'uuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'beforeId': _is.ParameterDescription(
              name: 'beforeId',
              type: _is.getType<int?>(),
              nullable: true,
            ),
            'limit': _is.ParameterDescription(
              name: 'limit',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['drive'] as _ijanxtjh.DriveEndpoint).activity(
                    session,
                    params['uuid'],
                    params['beforeId'],
                    params['limit'],
                  ),
        ),
        'watch': _is.MethodStreamConnector(
          name: 'watch',
          params: {},
          streamParams: {},
          returnType: _is.MethodStreamReturnType.streamType,
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
                Map<String, Stream> streamParams,
              ) => (endpoints['drive'] as _ijanxtjh.DriveEndpoint).watch(
                session,
              ),
        ),
      },
    );
    connectors['e2eSupport'] = _is.EndpointConnector(
      name: 'e2eSupport',
      endpoint: endpoints['e2eSupport']!,
      methodConnectors: {
        'latestVerificationCode': _is.MethodConnector(
          name: 'latestVerificationCode',
          params: {
            'email': _is.ParameterDescription(
              name: 'email',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['e2eSupport'] as _iqj5xom6.E2eSupportEndpoint)
                      .latestVerificationCode(
                        session,
                        params['email'],
                      ),
        ),
        'latestPasswordResetCode': _is.MethodConnector(
          name: 'latestPasswordResetCode',
          params: {
            'email': _is.ParameterDescription(
              name: 'email',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['e2eSupport'] as _iqj5xom6.E2eSupportEndpoint)
                      .latestPasswordResetCode(
                        session,
                        params['email'],
                      ),
        ),
      },
    );
    connectors['feedback'] = _is.EndpointConnector(
      name: 'feedback',
      endpoint: endpoints['feedback']!,
      methodConnectors: {
        'submit': _is.MethodConnector(
          name: 'submit',
          params: {
            'feedback': _is.ParameterDescription(
              name: 'feedback',
              type: _is.getType<_ira9srbn.FeedbackSubmission>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['feedback'] as _i70eazm1.FeedbackEndpoint).submit(
                    session,
                    params['feedback'],
                  ),
        ),
        'reportError': _is.MethodConnector(
          name: 'reportError',
          params: {
            'report': _is.ParameterDescription(
              name: 'report',
              type: _is.getType<_ira9srbn.FeedbackSubmission>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['feedback'] as _i70eazm1.FeedbackEndpoint)
                  .reportError(
                    session,
                    params['report'],
                  ),
        ),
      },
    );
    connectors['file'] = _is.EndpointConnector(
      name: 'file',
      endpoint: endpoints['file']!,
      methodConnectors: {
        'createUpload': _is.MethodConnector(
          name: 'createUpload',
          params: {
            'fileUuid': _is.ParameterDescription(
              name: 'fileUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'itemUuid': _is.ParameterDescription(
              name: 'itemUuid',
              type: _is.getType<_is.UuidValue?>(),
              nullable: true,
            ),
            'fileName': _is.ParameterDescription(
              name: 'fileName',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'mimeType': _is.ParameterDescription(
              name: 'mimeType',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'size': _is.ParameterDescription(
              name: 'size',
              type: _is.getType<int>(),
              nullable: false,
            ),
            'kind': _is.ParameterDescription(
              name: 'kind',
              type: _is.getType<_idhe6v6s.StoredFileKind?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['file'] as _iokth3bn.FileEndpoint).createUpload(
                    session,
                    params['fileUuid'],
                    params['itemUuid'],
                    params['fileName'],
                    params['mimeType'],
                    params['size'],
                    kind: params['kind'],
                  ),
        ),
        'completeUpload': _is.MethodConnector(
          name: 'completeUpload',
          params: {
            'fileUuid': _is.ParameterDescription(
              name: 'fileUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['file'] as _iokth3bn.FileEndpoint).completeUpload(
                    session,
                    params['fileUuid'],
                  ),
        ),
        'getUrl': _is.MethodConnector(
          name: 'getUrl',
          params: {
            'fileUuid': _is.ParameterDescription(
              name: 'fileUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['file'] as _iokth3bn.FileEndpoint).getUrl(
                session,
                params['fileUuid'],
              ),
        ),
        'getUrls': _is.MethodConnector(
          name: 'getUrls',
          params: {
            'fileUuids': _is.ParameterDescription(
              name: 'fileUuids',
              type: _is.getType<List<_is.UuidValue>>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['file'] as _iokth3bn.FileEndpoint).getUrls(
                session,
                params['fileUuids'],
              ),
        ),
      },
    );
    connectors['uiBridge'] = _is.EndpointConnector(
      name: 'uiBridge',
      endpoint: endpoints['uiBridge']!,
      methodConnectors: {
        'connect': _is.MethodStreamConnector(
          name: 'connect',
          params: {},
          streamParams: {
            'fromApp':
                _is.StreamParameterDescription<_is78z0de.UiBridgeMessage>(
                  name: 'fromApp',
                  nullable: false,
                ),
          },
          returnType: _is.MethodStreamReturnType.streamType,
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
                Map<String, Stream> streamParams,
              ) =>
                  (endpoints['uiBridge'] as _ipb16bxt.UiBridgeEndpoint).connect(
                    session,
                    streamParams['fromApp']!.cast<_is78z0de.UiBridgeMessage>(),
                  ),
        ),
      },
    );
    connectors['meta'] = _is.EndpointConnector(
      name: 'meta',
      endpoint: endpoints['meta']!,
      methodConnectors: {
        'getInfo': _is.MethodConnector(
          name: 'getInfo',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['meta'] as _isistrmv.MetaEndpoint).getInfo(
                session,
              ),
        ),
      },
    );
    connectors['notification'] = _is.EndpointConnector(
      name: 'notification',
      endpoint: endpoints['notification']!,
      methodConnectors: {
        'list': _is.MethodConnector(
          name: 'list',
          params: {
            'cursor': _is.ParameterDescription(
              name: 'cursor',
              type: _is.getType<String?>(),
              nullable: true,
            ),
            'limit': _is.ParameterDescription(
              name: 'limit',
              type: _is.getType<int>(),
              nullable: false,
            ),
            'unreadOnly': _is.ParameterDescription(
              name: 'unreadOnly',
              type: _is.getType<bool>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['notification'] as _ia40tpv4.NotificationEndpoint)
                      .list(
                        session,
                        params['cursor'],
                        params['limit'],
                        params['unreadOnly'],
                      ),
        ),
        'unreadCount': _is.MethodConnector(
          name: 'unreadCount',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['notification'] as _ia40tpv4.NotificationEndpoint)
                      .unreadCount(session),
        ),
        'markRead': _is.MethodConnector(
          name: 'markRead',
          params: {
            'ids': _is.ParameterDescription(
              name: 'ids',
              type: _is.getType<List<int>>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['notification'] as _ia40tpv4.NotificationEndpoint)
                      .markRead(
                        session,
                        params['ids'],
                      ),
        ),
        'markAllRead': _is.MethodConnector(
          name: 'markAllRead',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['notification'] as _ia40tpv4.NotificationEndpoint)
                      .markAllRead(session),
        ),
        'watch': _is.MethodStreamConnector(
          name: 'watch',
          params: {},
          streamParams: {},
          returnType: _is.MethodStreamReturnType.streamType,
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
                Map<String, Stream> streamParams,
              ) => (endpoints['notification'] as _ia40tpv4.NotificationEndpoint)
                  .watch(session),
        ),
      },
    );
    connectors['presence'] = _is.EndpointConnector(
      name: 'presence',
      endpoint: endpoints['presence']!,
      methodConnectors: {
        'join': _is.MethodStreamConnector(
          name: 'join',
          params: {
            'itemUuid': _is.ParameterDescription(
              name: 'itemUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          streamParams: {
            'updates': _is.StreamParameterDescription<_ipd65of1.PresenceUpdate>(
              name: 'updates',
              nullable: false,
            ),
          },
          returnType: _is.MethodStreamReturnType.streamType,
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
                Map<String, Stream> streamParams,
              ) => (endpoints['presence'] as _iv7snmpw.PresenceEndpoint).join(
                session,
                params['itemUuid'],
                streamParams['updates']!.cast<_ipd65of1.PresenceUpdate>(),
              ),
        ),
      },
    );
    connectors['sharing'] = _is.EndpointConnector(
      name: 'sharing',
      endpoint: endpoints['sharing']!,
      methodConnectors: {
        'getSharing': _is.MethodConnector(
          name: 'getSharing',
          params: {
            'itemUuid': _is.ParameterDescription(
              name: 'itemUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['sharing'] as _itz30x9e.SharingEndpoint)
                  .getSharing(
                    session,
                    params['itemUuid'],
                  ),
        ),
        'share': _is.MethodConnector(
          name: 'share',
          params: {
            'itemUuid': _is.ParameterDescription(
              name: 'itemUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'emails': _is.ParameterDescription(
              name: 'emails',
              type: _is.getType<List<String>>(),
              nullable: false,
            ),
            'role': _is.ParameterDescription(
              name: 'role',
              type: _is.getType<_i9nsco4y.AccessRole>(),
              nullable: false,
            ),
            'notify': _is.ParameterDescription(
              name: 'notify',
              type: _is.getType<bool>(),
              nullable: false,
            ),
            'message': _is.ParameterDescription(
              name: 'message',
              type: _is.getType<String?>(),
              nullable: true,
            ),
            'expiresAt': _is.ParameterDescription(
              name: 'expiresAt',
              type: _is.getType<DateTime?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['sharing'] as _itz30x9e.SharingEndpoint).share(
                    session,
                    params['itemUuid'],
                    params['emails'],
                    params['role'],
                    params['notify'],
                    params['message'],
                    params['expiresAt'],
                  ),
        ),
        'updateRole': _is.MethodConnector(
          name: 'updateRole',
          params: {
            'itemUuid': _is.ParameterDescription(
              name: 'itemUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'userId': _is.ParameterDescription(
              name: 'userId',
              type: _is.getType<int>(),
              nullable: false,
            ),
            'role': _is.ParameterDescription(
              name: 'role',
              type: _is.getType<_i9nsco4y.AccessRole>(),
              nullable: false,
            ),
            'expiresAt': _is.ParameterDescription(
              name: 'expiresAt',
              type: _is.getType<DateTime?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['sharing'] as _itz30x9e.SharingEndpoint)
                  .updateRole(
                    session,
                    params['itemUuid'],
                    params['userId'],
                    params['role'],
                    expiresAt: params['expiresAt'],
                  ),
        ),
        'remove': _is.MethodConnector(
          name: 'remove',
          params: {
            'itemUuid': _is.ParameterDescription(
              name: 'itemUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'userId': _is.ParameterDescription(
              name: 'userId',
              type: _is.getType<int?>(),
              nullable: true,
            ),
            'invitedEmail': _is.ParameterDescription(
              name: 'invitedEmail',
              type: _is.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['sharing'] as _itz30x9e.SharingEndpoint).remove(
                    session,
                    params['itemUuid'],
                    params['userId'],
                    invitedEmail: params['invitedEmail'],
                  ),
        ),
        'transferOwnership': _is.MethodConnector(
          name: 'transferOwnership',
          params: {
            'itemUuid': _is.ParameterDescription(
              name: 'itemUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'newOwnerUserId': _is.ParameterDescription(
              name: 'newOwnerUserId',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['sharing'] as _itz30x9e.SharingEndpoint)
                  .transferOwnership(
                    session,
                    params['itemUuid'],
                    params['newOwnerUserId'],
                  ),
        ),
        'respondToOwnershipTransfer': _is.MethodConnector(
          name: 'respondToOwnershipTransfer',
          params: {
            'transferId': _is.ParameterDescription(
              name: 'transferId',
              type: _is.getType<int>(),
              nullable: false,
            ),
            'accept': _is.ParameterDescription(
              name: 'accept',
              type: _is.getType<bool>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['sharing'] as _itz30x9e.SharingEndpoint)
                  .respondToOwnershipTransfer(
                    session,
                    params['transferId'],
                    params['accept'],
                  ),
        ),
        'setLink': _is.MethodConnector(
          name: 'setLink',
          params: {
            'itemUuid': _is.ParameterDescription(
              name: 'itemUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'role': _is.ParameterDescription(
              name: 'role',
              type: _is.getType<_i9nsco4y.AccessRole?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['sharing'] as _itz30x9e.SharingEndpoint).setLink(
                    session,
                    params['itemUuid'],
                    params['role'],
                  ),
        ),
        'rotateLink': _is.MethodConnector(
          name: 'rotateLink',
          params: {
            'itemUuid': _is.ParameterDescription(
              name: 'itemUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['sharing'] as _itz30x9e.SharingEndpoint)
                  .rotateLink(
                    session,
                    params['itemUuid'],
                  ),
        ),
        'updateSettings': _is.MethodConnector(
          name: 'updateSettings',
          params: {
            'itemUuid': _is.ParameterDescription(
              name: 'itemUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'settings': _is.ParameterDescription(
              name: 'settings',
              type: _is.getType<_i55sl7s1.ItemSharingSettings>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['sharing'] as _itz30x9e.SharingEndpoint)
                  .updateSettings(
                    session,
                    params['itemUuid'],
                    params['settings'],
                  ),
        ),
        'requestAccess': _is.MethodConnector(
          name: 'requestAccess',
          params: {
            'itemUuid': _is.ParameterDescription(
              name: 'itemUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'role': _is.ParameterDescription(
              name: 'role',
              type: _is.getType<_i9nsco4y.AccessRole>(),
              nullable: false,
            ),
            'message': _is.ParameterDescription(
              name: 'message',
              type: _is.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['sharing'] as _itz30x9e.SharingEndpoint)
                  .requestAccess(
                    session,
                    params['itemUuid'],
                    params['role'],
                    params['message'],
                  ),
        ),
        'handleAccessRequest': _is.MethodConnector(
          name: 'handleAccessRequest',
          params: {
            'requestId': _is.ParameterDescription(
              name: 'requestId',
              type: _is.getType<int>(),
              nullable: false,
            ),
            'approve': _is.ParameterDescription(
              name: 'approve',
              type: _is.getType<bool>(),
              nullable: false,
            ),
            'role': _is.ParameterDescription(
              name: 'role',
              type: _is.getType<_i9nsco4y.AccessRole?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['sharing'] as _itz30x9e.SharingEndpoint)
                  .handleAccessRequest(
                    session,
                    params['requestId'],
                    params['approve'],
                    params['role'],
                  ),
        ),
        'resolveInvite': _is.MethodConnector(
          name: 'resolveInvite',
          params: {
            'token': _is.ParameterDescription(
              name: 'token',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['sharing'] as _itz30x9e.SharingEndpoint)
                  .resolveInvite(
                    session,
                    params['token'],
                  ),
        ),
      },
    );
    connectors['accessToken'] = _is.EndpointConnector(
      name: 'accessToken',
      endpoint: endpoints['accessToken']!,
      methodConnectors: {
        'list': _is.MethodConnector(
          name: 'list',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['accessToken'] as _iusd4uiv.AccessTokenEndpoint)
                      .list(session),
        ),
        'create': _is.MethodConnector(
          name: 'create',
          params: {
            'name': _is.ParameterDescription(
              name: 'name',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'scopes': _is.ParameterDescription(
              name: 'scopes',
              type: _is.getType<List<String>>(),
              nullable: false,
            ),
            'expiresAt': _is.ParameterDescription(
              name: 'expiresAt',
              type: _is.getType<DateTime?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['accessToken'] as _iusd4uiv.AccessTokenEndpoint)
                      .create(
                        session,
                        params['name'],
                        params['scopes'],
                        params['expiresAt'],
                      ),
        ),
        'revoke': _is.MethodConnector(
          name: 'revoke',
          params: {
            'id': _is.ParameterDescription(
              name: 'id',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['accessToken'] as _iusd4uiv.AccessTokenEndpoint)
                      .revoke(
                        session,
                        params['id'],
                      ),
        ),
      },
    );
    connectors['googleIdp'] = _is.EndpointConnector(
      name: 'googleIdp',
      endpoint: endpoints['googleIdp']!,
      methodConnectors: {
        'login': _is.MethodConnector(
          name: 'login',
          params: {
            'idToken': _is.ParameterDescription(
              name: 'idToken',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'accessToken': _is.ParameterDescription(
              name: 'accessToken',
              type: _is.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['googleIdp'] as _i3henulz.GoogleIdpEndpoint).login(
                    session,
                    idToken: params['idToken'],
                    accessToken: params['accessToken'],
                  ),
        ),
        'loginWithCode': _is.MethodConnector(
          name: 'loginWithCode',
          params: {
            'code': _is.ParameterDescription(
              name: 'code',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'codeVerifier': _is.ParameterDescription(
              name: 'codeVerifier',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'redirectUri': _is.ParameterDescription(
              name: 'redirectUri',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['googleIdp'] as _i3henulz.GoogleIdpEndpoint)
                  .loginWithCode(
                    session,
                    code: params['code'],
                    codeVerifier: params['codeVerifier'],
                    redirectUri: params['redirectUri'],
                  ),
        ),
        'hasAccount': _is.MethodConnector(
          name: 'hasAccount',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['googleIdp'] as _i3henulz.GoogleIdpEndpoint)
                  .hasAccount(session),
        ),
      },
    );
    connectors['user'] = _is.EndpointConnector(
      name: 'user',
      endpoint: endpoints['user']!,
      methodConnectors: {
        'getMe': _is.MethodConnector(
          name: 'getMe',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['user'] as _iwtyukq6.UserEndpoint).getMe(session),
        ),
        'updateProfile': _is.MethodConnector(
          name: 'updateProfile',
          params: {
            'displayName': _is.ParameterDescription(
              name: 'displayName',
              type: _is.getType<String?>(),
              nullable: true,
            ),
            'locale': _is.ParameterDescription(
              name: 'locale',
              type: _is.getType<String?>(),
              nullable: true,
            ),
            'timeZone': _is.ParameterDescription(
              name: 'timeZone',
              type: _is.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['user'] as _iwtyukq6.UserEndpoint).updateProfile(
                    session,
                    displayName: params['displayName'],
                    locale: params['locale'],
                    timeZone: params['timeZone'],
                  ),
        ),
        'uploadAvatar': _is.MethodConnector(
          name: 'uploadAvatar',
          params: {
            'fileUuid': _is.ParameterDescription(
              name: 'fileUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'fileName': _is.ParameterDescription(
              name: 'fileName',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'mimeType': _is.ParameterDescription(
              name: 'mimeType',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'size': _is.ParameterDescription(
              name: 'size',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['user'] as _iwtyukq6.UserEndpoint).uploadAvatar(
                    session,
                    params['fileUuid'],
                    params['fileName'],
                    params['mimeType'],
                    params['size'],
                  ),
        ),
        'setAvatar': _is.MethodConnector(
          name: 'setAvatar',
          params: {
            'fileUuid': _is.ParameterDescription(
              name: 'fileUuid',
              type: _is.getType<_is.UuidValue?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['user'] as _iwtyukq6.UserEndpoint).setAvatar(
                    session,
                    params['fileUuid'],
                  ),
        ),
        'getPreferences': _is.MethodConnector(
          name: 'getPreferences',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['user'] as _iwtyukq6.UserEndpoint)
                  .getPreferences(session),
        ),
        'updatePreferences': _is.MethodConnector(
          name: 'updatePreferences',
          params: {
            'patch': _is.ParameterDescription(
              name: 'patch',
              type: _is.getType<_ingbfbma.UserPreferencesPatch>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['user'] as _iwtyukq6.UserEndpoint)
                  .updatePreferences(
                    session,
                    params['patch'],
                  ),
        ),
        'searchUsers': _is.MethodConnector(
          name: 'searchUsers',
          params: {
            'query': _is.ParameterDescription(
              name: 'query',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'limit': _is.ParameterDescription(
              name: 'limit',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['user'] as _iwtyukq6.UserEndpoint).searchUsers(
                    session,
                    params['query'],
                    params['limit'],
                  ),
        ),
        'getUsers': _is.MethodConnector(
          name: 'getUsers',
          params: {
            'ids': _is.ParameterDescription(
              name: 'ids',
              type: _is.getType<List<int>>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['user'] as _iwtyukq6.UserEndpoint).getUsers(
                session,
                params['ids'],
              ),
        ),
        'accountDeletionPreview': _is.MethodConnector(
          name: 'accountDeletionPreview',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['user'] as _iwtyukq6.UserEndpoint)
                  .accountDeletionPreview(session),
        ),
        'deleteAccount': _is.MethodConnector(
          name: 'deleteAccount',
          params: {
            'confirmation': _is.ParameterDescription(
              name: 'confirmation',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['user'] as _iwtyukq6.UserEndpoint).deleteAccount(
                    session,
                    params['confirmation'],
                  ),
        ),
      },
    );
    connectors['version'] = _is.EndpointConnector(
      name: 'version',
      endpoint: endpoints['version']!,
      methodConnectors: {
        'list': _is.MethodConnector(
          name: 'list',
          params: {
            'itemUuid': _is.ParameterDescription(
              name: 'itemUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'namedOnly': _is.ParameterDescription(
              name: 'namedOnly',
              type: _is.getType<bool>(),
              nullable: false,
            ),
            'beforeId': _is.ParameterDescription(
              name: 'beforeId',
              type: _is.getType<int?>(),
              nullable: true,
            ),
            'limit': _is.ParameterDescription(
              name: 'limit',
              type: _is.getType<int?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['version'] as _im6cm90k.VersionEndpoint).list(
                    session,
                    params['itemUuid'],
                    params['namedOnly'],
                    beforeId: params['beforeId'],
                    limit: params['limit'],
                  ),
        ),
        'nameCurrent': _is.MethodConnector(
          name: 'nameCurrent',
          params: {
            'itemUuid': _is.ParameterDescription(
              name: 'itemUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'name': _is.ParameterDescription(
              name: 'name',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['version'] as _im6cm90k.VersionEndpoint)
                  .nameCurrent(
                    session,
                    params['itemUuid'],
                    params['name'],
                  ),
        ),
        'rename': _is.MethodConnector(
          name: 'rename',
          params: {
            'itemUuid': _is.ParameterDescription(
              name: 'itemUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'versionId': _is.ParameterDescription(
              name: 'versionId',
              type: _is.getType<int>(),
              nullable: false,
            ),
            'name': _is.ParameterDescription(
              name: 'name',
              type: _is.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['version'] as _im6cm90k.VersionEndpoint).rename(
                    session,
                    params['itemUuid'],
                    params['versionId'],
                    params['name'],
                  ),
        ),
        'restore': _is.MethodConnector(
          name: 'restore',
          params: {
            'itemUuid': _is.ParameterDescription(
              name: 'itemUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'versionId': _is.ParameterDescription(
              name: 'versionId',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['version'] as _im6cm90k.VersionEndpoint).restore(
                    session,
                    params['itemUuid'],
                    params['versionId'],
                  ),
        ),
        'getSnapshotUrl': _is.MethodConnector(
          name: 'getSnapshotUrl',
          params: {
            'itemUuid': _is.ParameterDescription(
              name: 'itemUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'versionId': _is.ParameterDescription(
              name: 'versionId',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['version'] as _im6cm90k.VersionEndpoint)
                  .getSnapshotUrl(
                    session,
                    params['itemUuid'],
                    params['versionId'],
                  ),
        ),
      },
    );
    connectors['sheets'] = _is.EndpointConnector(
      name: 'sheets',
      endpoint: endpoints['sheets']!,
      methodConnectors: {
        'reserveSpaces': _is.MethodConnector(
          name: 'reserveSpaces',
          params: {
            'count': _is.ParameterDescription(
              name: 'count',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['sheets'] as _izrkvdrt.SheetsEndpoint)
                  .reserveSpaces(
                    session,
                    params['count'],
                  ),
        ),
        'subscribe': _is.MethodConnector(
          name: 'subscribe',
          params: {
            'itemUuid': _is.ParameterDescription(
              name: 'itemUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['sheets'] as _izrkvdrt.SheetsEndpoint).subscribe(
                    session,
                    params['itemUuid'],
                  ),
        ),
        'unsubscribe': _is.MethodConnector(
          name: 'unsubscribe',
          params: {
            'itemUuid': _is.ParameterDescription(
              name: 'itemUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['sheets'] as _izrkvdrt.SheetsEndpoint).unsubscribe(
                    session,
                    params['itemUuid'],
                  ),
        ),
        'ensureSubscribed': _is.MethodConnector(
          name: 'ensureSubscribed',
          params: {
            'spaces': _is.ParameterDescription(
              name: 'spaces',
              type: _is.getType<List<_is.UuidValue>>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['sheets'] as _izrkvdrt.SheetsEndpoint)
                  .ensureSubscribed(
                    session,
                    params['spaces'],
                  ),
        ),
        'spaceStats': _is.MethodConnector(
          name: 'spaceStats',
          params: {
            'itemUuid': _is.ParameterDescription(
              name: 'itemUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['sheets'] as _izrkvdrt.SheetsEndpoint).spaceStats(
                    session,
                    params['itemUuid'],
                  ),
        ),
        'revertChange': _is.MethodConnector(
          name: 'revertChange',
          params: {
            'changeId': _is.ParameterDescription(
              name: 'changeId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['sheets'] as _izrkvdrt.SheetsEndpoint)
                  .revertChange(
                    session,
                    params['changeId'],
                  ),
        ),
        'reapplyChange': _is.MethodConnector(
          name: 'reapplyChange',
          params: {
            'changeId': _is.ParameterDescription(
              name: 'changeId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['sheets'] as _izrkvdrt.SheetsEndpoint)
                  .reapplyChange(
                    session,
                    params['changeId'],
                  ),
        ),
        'cellHistory': _is.MethodConnector(
          name: 'cellHistory',
          params: {
            'spreadsheetUuid': _is.ParameterDescription(
              name: 'spreadsheetUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'sheetId': _is.ParameterDescription(
              name: 'sheetId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'rowId': _is.ParameterDescription(
              name: 'rowId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'colId': _is.ParameterDescription(
              name: 'colId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'cursor': _is.ParameterDescription(
              name: 'cursor',
              type: _is.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['sheets'] as _izrkvdrt.SheetsEndpoint).cellHistory(
                    session,
                    params['spreadsheetUuid'],
                    params['sheetId'],
                    params['rowId'],
                    params['colId'],
                    params['cursor'],
                  ),
        ),
        'activitySummary': _is.MethodConnector(
          name: 'activitySummary',
          params: {
            'spreadsheetUuid': _is.ParameterDescription(
              name: 'spreadsheetUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'days': _is.ParameterDescription(
              name: 'days',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['sheets'] as _izrkvdrt.SheetsEndpoint)
                  .activitySummary(
                    session,
                    params['spreadsheetUuid'],
                    params['days'],
                  ),
        ),
      },
    );
    connectors['sheetsSync'] = _is.EndpointConnector(
      name: 'sheetsSync',
      endpoint: endpoints['sheetsSync']!,
      methodConnectors: {
        'sync': _is.MethodStreamConnector(
          name: 'sync',
          params: {
            'once': _is.ParameterDescription(
              name: 'once',
              type: _is.getType<bool>(),
              nullable: false,
            ),
          },
          streamParams: {
            'changes':
                _is.StreamParameterDescription<
                  _izehhkf5.OfflineSyncStreamEvent
                >(
                  name: 'changes',
                  nullable: false,
                ),
          },
          returnType: _is.MethodStreamReturnType.streamType,
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
                Map<String, Stream> streamParams,
              ) => (endpoints['sheetsSync'] as _iijmdr93.SheetsSyncEndpoint)
                  .sync(
                    session,
                    changes: streamParams['changes']!
                        .cast<_izehhkf5.OfflineSyncStreamEvent>(),
                    once: params['once'],
                  ),
        ),
      },
    );
    connectors['document'] = _is.EndpointConnector(
      name: 'document',
      endpoint: endpoints['document']!,
      methodConnectors: {
        'getInfo': _is.MethodConnector(
          name: 'getInfo',
          params: {
            'documentUuid': _is.ParameterDescription(
              name: 'documentUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['document'] as _iiabxp2u.DocumentEndpoint).getInfo(
                    session,
                    params['documentUuid'],
                  ),
        ),
        'getOps': _is.MethodConnector(
          name: 'getOps',
          params: {
            'documentUuid': _is.ParameterDescription(
              name: 'documentUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'fromRevision': _is.ParameterDescription(
              name: 'fromRevision',
              type: _is.getType<int>(),
              nullable: false,
            ),
            'toRevision': _is.ParameterDescription(
              name: 'toRevision',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['document'] as _iiabxp2u.DocumentEndpoint).getOps(
                    session,
                    params['documentUuid'],
                    params['fromRevision'],
                    params['toRevision'],
                  ),
        ),
        'getSnapshot': _is.MethodConnector(
          name: 'getSnapshot',
          params: {
            'documentUuid': _is.ParameterDescription(
              name: 'documentUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'revision': _is.ParameterDescription(
              name: 'revision',
              type: _is.getType<int?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['document'] as _iiabxp2u.DocumentEndpoint)
                  .getSnapshot(
                    session,
                    params['documentUuid'],
                    params['revision'],
                  ),
        ),
        'updateMeta': _is.MethodConnector(
          name: 'updateMeta',
          params: {
            'documentUuid': _is.ParameterDescription(
              name: 'documentUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'patch': _is.ParameterDescription(
              name: 'patch',
              type: _is.getType<_issank2j.DocumentMetaPatch>(),
              nullable: false,
            ),
            'clientOpId': _is.ParameterDescription(
              name: 'clientOpId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['document'] as _iiabxp2u.DocumentEndpoint)
                  .updateMeta(
                    session,
                    params['documentUuid'],
                    params['patch'],
                    params['clientOpId'],
                  ),
        ),
        'connect': _is.MethodStreamConnector(
          name: 'connect',
          params: {
            'documentUuid': _is.ParameterDescription(
              name: 'documentUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'knownRevision': _is.ParameterDescription(
              name: 'knownRevision',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          streamParams: {
            'input': _is.StreamParameterDescription<_i64vpekp.DocClientMessage>(
              name: 'input',
              nullable: false,
            ),
          },
          returnType: _is.MethodStreamReturnType.streamType,
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
                Map<String, Stream> streamParams,
              ) =>
                  (endpoints['document'] as _iiabxp2u.DocumentEndpoint).connect(
                    session,
                    params['documentUuid'],
                    params['knownRevision'],
                    streamParams['input']!.cast<_i64vpekp.DocClientMessage>(),
                  ),
        ),
      },
    );
    connectors['writeExport'] = _is.EndpointConnector(
      name: 'writeExport',
      endpoint: endpoints['writeExport']!,
      methodConnectors: {
        'export': _is.MethodConnector(
          name: 'export',
          params: {
            'documentUuid': _is.ParameterDescription(
              name: 'documentUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'format': _is.ParameterDescription(
              name: 'format',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'optionsJson': _is.ParameterDescription(
              name: 'optionsJson',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'revision': _is.ParameterDescription(
              name: 'revision',
              type: _is.getType<int?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['writeExport'] as _ia4kadx2.WriteExportEndpoint)
                      .export(
                        session,
                        params['documentUuid'],
                        params['format'],
                        params['optionsJson'],
                        params['revision'],
                      ),
        ),
        'convertForInsert': _is.MethodConnector(
          name: 'convertForInsert',
          params: {
            'uploadId': _is.ParameterDescription(
              name: 'uploadId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'format': _is.ParameterDescription(
              name: 'format',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'optionsJson': _is.ParameterDescription(
              name: 'optionsJson',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['writeExport'] as _ia4kadx2.WriteExportEndpoint)
                      .convertForInsert(
                        session,
                        params['uploadId'],
                        params['format'],
                        params['optionsJson'],
                      ),
        ),
        'fetchImage': _is.MethodConnector(
          name: 'fetchImage',
          params: {
            'documentUuid': _is.ParameterDescription(
              name: 'documentUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'src': _is.ParameterDescription(
              name: 'src',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['writeExport'] as _ia4kadx2.WriteExportEndpoint)
                      .fetchImage(
                        session,
                        params['documentUuid'],
                        params['src'],
                      ),
        ),
        'exportWithProgress': _is.MethodStreamConnector(
          name: 'exportWithProgress',
          params: {
            'documentUuid': _is.ParameterDescription(
              name: 'documentUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'format': _is.ParameterDescription(
              name: 'format',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'optionsJson': _is.ParameterDescription(
              name: 'optionsJson',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'revision': _is.ParameterDescription(
              name: 'revision',
              type: _is.getType<int?>(),
              nullable: true,
            ),
          },
          streamParams: {},
          returnType: _is.MethodStreamReturnType.streamType,
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
                Map<String, Stream> streamParams,
              ) => (endpoints['writeExport'] as _ia4kadx2.WriteExportEndpoint)
                  .exportWithProgress(
                    session,
                    params['documentUuid'],
                    params['format'],
                    params['optionsJson'],
                    params['revision'],
                  ),
        ),
      },
    );
    connectors['writeHistory'] = _is.EndpointConnector(
      name: 'writeHistory',
      endpoint: endpoints['writeHistory']!,
      methodConnectors: {
        'getVersionDocument': _is.MethodConnector(
          name: 'getVersionDocument',
          params: {
            'documentUuid': _is.ParameterDescription(
              name: 'documentUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'revision': _is.ParameterDescription(
              name: 'revision',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['writeHistory'] as _izdjh3zj.WriteHistoryEndpoint)
                      .getVersionDocument(
                        session,
                        params['documentUuid'],
                        params['revision'],
                      ),
        ),
        'diff': _is.MethodConnector(
          name: 'diff',
          params: {
            'documentUuid': _is.ParameterDescription(
              name: 'documentUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'fromRevision': _is.ParameterDescription(
              name: 'fromRevision',
              type: _is.getType<int>(),
              nullable: false,
            ),
            'toRevision': _is.ParameterDescription(
              name: 'toRevision',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['writeHistory'] as _izdjh3zj.WriteHistoryEndpoint)
                      .diff(
                        session,
                        params['documentUuid'],
                        params['fromRevision'],
                        params['toRevision'],
                      ),
        ),
        'createRestorePoint': _is.MethodConnector(
          name: 'createRestorePoint',
          params: {
            'documentUuid': _is.ParameterDescription(
              name: 'documentUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['writeHistory'] as _izdjh3zj.WriteHistoryEndpoint)
                      .createRestorePoint(
                        session,
                        params['documentUuid'],
                      ),
        ),
        'restore': _is.MethodConnector(
          name: 'restore',
          params: {
            'documentUuid': _is.ParameterDescription(
              name: 'documentUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'versionId': _is.ParameterDescription(
              name: 'versionId',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['writeHistory'] as _izdjh3zj.WriteHistoryEndpoint)
                      .restore(
                        session,
                        params['documentUuid'],
                        params['versionId'],
                      ),
        ),
        'copyVersion': _is.MethodConnector(
          name: 'copyVersion',
          params: {
            'documentUuid': _is.ParameterDescription(
              name: 'documentUuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'versionId': _is.ParameterDescription(
              name: 'versionId',
              type: _is.getType<int>(),
              nullable: false,
            ),
            'name': _is.ParameterDescription(
              name: 'name',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'parentUuid': _is.ParameterDescription(
              name: 'parentUuid',
              type: _is.getType<_is.UuidValue?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['writeHistory'] as _izdjh3zj.WriteHistoryEndpoint)
                      .copyVersion(
                        session,
                        params['documentUuid'],
                        params['versionId'],
                        params['name'],
                        params['parentUuid'],
                      ),
        ),
      },
    );
    connectors['writeTheme'] = _is.EndpointConnector(
      name: 'writeTheme',
      endpoint: endpoints['writeTheme']!,
      methodConnectors: {
        'listBuiltins': _is.MethodConnector(
          name: 'listBuiltins',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['writeTheme'] as _ii3xbyyg.WriteThemeEndpoint)
                      .listBuiltins(session),
        ),
        'listMine': _is.MethodConnector(
          name: 'listMine',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['writeTheme'] as _ii3xbyyg.WriteThemeEndpoint)
                      .listMine(session),
        ),
        'get': _is.MethodConnector(
          name: 'get',
          params: {
            'uuid': _is.ParameterDescription(
              name: 'uuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'viaDocumentUuid': _is.ParameterDescription(
              name: 'viaDocumentUuid',
              type: _is.getType<_is.UuidValue?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['writeTheme'] as _ii3xbyyg.WriteThemeEndpoint).get(
                    session,
                    params['uuid'],
                    params['viaDocumentUuid'],
                  ),
        ),
        'getMany': _is.MethodConnector(
          name: 'getMany',
          params: {
            'uuids': _is.ParameterDescription(
              name: 'uuids',
              type: _is.getType<List<_is.UuidValue>>(),
              nullable: false,
            ),
            'viaDocumentUuid': _is.ParameterDescription(
              name: 'viaDocumentUuid',
              type: _is.getType<_is.UuidValue?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['writeTheme'] as _ii3xbyyg.WriteThemeEndpoint)
                      .getMany(
                        session,
                        params['uuids'],
                        params['viaDocumentUuid'],
                      ),
        ),
        'create': _is.MethodConnector(
          name: 'create',
          params: {
            'name': _is.ParameterDescription(
              name: 'name',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'json': _is.ParameterDescription(
              name: 'json',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'basedOnUuid': _is.ParameterDescription(
              name: 'basedOnUuid',
              type: _is.getType<_is.UuidValue?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['writeTheme'] as _ii3xbyyg.WriteThemeEndpoint)
                      .create(
                        session,
                        params['name'],
                        params['json'],
                        params['basedOnUuid'],
                      ),
        ),
        'update': _is.MethodConnector(
          name: 'update',
          params: {
            'uuid': _is.ParameterDescription(
              name: 'uuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'json': _is.ParameterDescription(
              name: 'json',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'expectedVersion': _is.ParameterDescription(
              name: 'expectedVersion',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['writeTheme'] as _ii3xbyyg.WriteThemeEndpoint)
                      .update(
                        session,
                        params['uuid'],
                        params['json'],
                        params['expectedVersion'],
                      ),
        ),
        'rename': _is.MethodConnector(
          name: 'rename',
          params: {
            'uuid': _is.ParameterDescription(
              name: 'uuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'name': _is.ParameterDescription(
              name: 'name',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'expectedVersion': _is.ParameterDescription(
              name: 'expectedVersion',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['writeTheme'] as _ii3xbyyg.WriteThemeEndpoint)
                      .rename(
                        session,
                        params['uuid'],
                        params['name'],
                        params['expectedVersion'],
                      ),
        ),
        'duplicate': _is.MethodConnector(
          name: 'duplicate',
          params: {
            'uuid': _is.ParameterDescription(
              name: 'uuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'name': _is.ParameterDescription(
              name: 'name',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'viaDocumentUuid': _is.ParameterDescription(
              name: 'viaDocumentUuid',
              type: _is.getType<_is.UuidValue?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['writeTheme'] as _ii3xbyyg.WriteThemeEndpoint)
                      .duplicate(
                        session,
                        params['uuid'],
                        params['name'],
                        params['viaDocumentUuid'],
                      ),
        ),
        'delete': _is.MethodConnector(
          name: 'delete',
          params: {
            'uuid': _is.ParameterDescription(
              name: 'uuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['writeTheme'] as _ii3xbyyg.WriteThemeEndpoint)
                      .delete(
                        session,
                        params['uuid'],
                      ),
        ),
        'restore': _is.MethodConnector(
          name: 'restore',
          params: {
            'uuid': _is.ParameterDescription(
              name: 'uuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['writeTheme'] as _ii3xbyyg.WriteThemeEndpoint)
                      .restore(
                        session,
                        params['uuid'],
                      ),
        ),
        'listRevisions': _is.MethodConnector(
          name: 'listRevisions',
          params: {
            'uuid': _is.ParameterDescription(
              name: 'uuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['writeTheme'] as _ii3xbyyg.WriteThemeEndpoint)
                      .listRevisions(
                        session,
                        params['uuid'],
                      ),
        ),
        'getRevision': _is.MethodConnector(
          name: 'getRevision',
          params: {
            'uuid': _is.ParameterDescription(
              name: 'uuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'version': _is.ParameterDescription(
              name: 'version',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['writeTheme'] as _ii3xbyyg.WriteThemeEndpoint)
                      .getRevision(
                        session,
                        params['uuid'],
                        params['version'],
                      ),
        ),
        'usage': _is.MethodConnector(
          name: 'usage',
          params: {
            'uuid': _is.ParameterDescription(
              name: 'uuid',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['writeTheme'] as _ii3xbyyg.WriteThemeEndpoint)
                      .usage(
                        session,
                        params['uuid'],
                      ),
        ),
      },
    );
    modules['serverpod_auth_idp'] = _iais.Endpoints()
      ..initializeEndpoints(server);
    modules['serverpod_offline_sync'] = _izehhkf5.Endpoints()
      ..initializeEndpoints(server);
    modules['serverpod_auth_core'] = _iacs.Endpoints()
      ..initializeEndpoints(server);
  }

  @override
  _is.FutureCallDispatch? get futureCalls {
    return _iwslocjr.FutureCalls();
  }
}
