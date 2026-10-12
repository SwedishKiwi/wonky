/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: dead_code, unnecessary_type_check

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/protocol.dart' as _isp;
import 'package:serverpod/serverpod.dart' as _is;
import 'package:serverpod_auth_core_server/serverpod_auth_core_server.dart'
    as _iacs;
import 'package:serverpod_auth_idp_server/serverpod_auth_idp_server.dart'
    as _iais;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart'
    as _izehhkf5;
import 'package:wonky_sync_models/wonky_sync_models.dart' as _i810rwvy;
import 'platform/activity/activity_event.dart' as _iatdjl5p;
import 'platform/activity/activity_event_view.dart' as _isa7sjzq;
import 'platform/activity/activity_type.dart' as _i50cy468;
import 'platform/comments/comment.dart' as _iyixppck;
import 'platform/comments/comment_anchor_kind.dart' as _iw81twtc;
import 'platform/comments/comment_event.dart' as _imlsyj2p;
import 'platform/comments/comment_event_kind.dart' as _ih1mb6x5;
import 'platform/comments/comment_filter.dart' as _il5y6tzr;
import 'platform/comments/comment_signal.dart' as _ix3p7034;
import 'platform/comments/comment_status.dart' as _iowdswxe;
import 'platform/comments/comment_system_event.dart' as _i94wr3td;
import 'platform/comments/comment_thread.dart' as _ijog60vm;
import 'platform/comments/comment_thread_view.dart' as _i818olql;
import 'platform/comments/comment_view.dart' as _i4xrxro7;
import 'platform/common/access_role.dart' as _ii98prcs;
import 'platform/common/wonky_error_code.dart' as _inb0isem;
import 'platform/common/wonky_exception.dart' as _igdswlrw;
import 'platform/drive/drive_change.dart' as _iktwt5zz;
import 'platform/drive/drive_change_kind.dart' as _ijoqbs82;
import 'platform/drive/drive_change_signal.dart' as _i0atxq9l;
import 'platform/drive/drive_item.dart' as _inge8yy2;
import 'platform/drive/drive_item_kind.dart' as _i8mh39wa;
import 'platform/drive/drive_item_user_state.dart' as _i0g2m831;
import 'platform/drive/drive_item_view.dart' as _infxyf98;
import 'platform/drive/drive_list_filter.dart' as _ivypvw0m;
import 'platform/drive/drive_list_page.dart' as _iavdhzsq;
import 'platform/drive/drive_owner_filter.dart' as _if1dhg5z;
import 'platform/drive/drive_search_filters.dart' as _i6k3d1nc;
import 'platform/drive/drive_sort.dart' as _iu13r4v2;
import 'platform/drive/drive_sort_field.dart' as _ix0g8yw4;
import 'platform/drive/drive_view.dart' as _ipww3kqy;
import 'platform/drive/import_options.dart' as _i2cmzvye;
import 'platform/drive/import_report_view.dart' as _i68yhxa0;
import 'platform/drive/import_warning_view.dart' as _i48sm9f2;
import 'platform/drive/storage_usage.dart' as _i26hsnhw;
import 'platform/drive/template_category.dart' as _iiedu4vz;
import 'platform/drive/template_view.dart' as _i2ox7ta1;
import 'platform/feedback/feedback_kind.dart' as _iv1sk0e8;
import 'platform/feedback/feedback_report.dart' as _iu565i0a;
import 'platform/feedback/feedback_submission.dart' as _ilhpki98;
import 'platform/files/file_upload_ticket.dart' as _irrzp8p9;
import 'platform/files/file_url_view.dart' as _itzt3x6d;
import 'platform/files/stored_file.dart' as _im8eh74x;
import 'platform/files/stored_file_kind.dart' as _i45dmz4a;
import 'platform/files/stored_file_status.dart' as _ik7q11oy;
import 'platform/meta/feature_flags.dart' as _ivk6eyvx;
import 'platform/meta/protocol_info.dart' as _ib575x0y;
import 'platform/meta/server_limits.dart' as _i28el0at;
import 'platform/notifications/notification_event.dart' as _iexg4yzt;
import 'platform/notifications/notification_kind.dart' as _iqlnbbfp;
import 'platform/notifications/notification_page.dart' as _i3r1eo8q;
import 'platform/notifications/notification_signal.dart' as _iqsxdr4a;
import 'platform/notifications/notification_view.dart' as _izfzk9h3;
import 'platform/notifications/user_notification.dart' as _ik59hiyp;
import 'platform/presence/participant.dart' as _iylgyc33;
import 'platform/presence/presence_bus_message.dart' as _i7dp90q0;
import 'platform/presence/presence_event.dart' as _i8r9afjv;
import 'platform/presence/presence_state.dart' as _ik055xb9;
import 'platform/presence/presence_update.dart' as _isz2sju0;
import 'platform/sharing/access_request.dart' as _i8scn8dm;
import 'platform/sharing/access_request_outcome.dart' as _i7trut12;
import 'platform/sharing/access_request_view.dart' as _iimp60a4;
import 'platform/sharing/drive_item_permission.dart' as _iuzgacy4;
import 'platform/sharing/invite_resolution.dart' as _ikeljole;
import 'platform/sharing/item_sharing_settings.dart' as _ih3711er;
import 'platform/sharing/ownership_transfer.dart' as _ijwxtu30;
import 'platform/sharing/ownership_transfer_view.dart' as _iilpsf9g;
import 'platform/sharing/permission_view.dart' as _iead0ok9;
import 'platform/sharing/share_link.dart' as _it712lg1;
import 'platform/sharing/share_link_view.dart' as _iw2xoohn;
import 'platform/sharing/sharing_info.dart' as _itd24os1;
import 'platform/users/access_token_view.dart' as _izha9j5m;
import 'platform/users/account_deletion_preview.dart' as _iq4dupwy;
import 'platform/users/app_theme_mode.dart' as _i6azdr3n;
import 'platform/users/created_access_token.dart' as _iru4pv75;
import 'platform/users/personal_access_token.dart' as _ijodrcyd;
import 'platform/users/ui_density.dart' as _i5lc4gt0;
import 'platform/users/user_preferences.dart' as _i501u5m5;
import 'platform/users/user_preferences_patch.dart' as _id95rrz2;
import 'platform/users/user_profile.dart' as _ihzl7wbq;
import 'platform/users/user_profile_view.dart' as _iufqmqtc;
import 'platform/users/user_summary.dart' as _i6y7tspy;
import 'platform/versions/item_version.dart' as _i7jb115m;
import 'platform/versions/item_version_state.dart' as _ibe5uno1;
import 'platform/versions/item_version_view.dart' as _ipbapjbz;
import 'platform/versions/version_kind.dart' as _in0fdl1f;
import 'platform/versions/version_restore_result.dart' as _in38zbga;
import 'platform/versions/version_storage.dart' as _i5u6d6t4;
import 'sheets/models/cell_history.dart' as _ik5lpvx4;
import 'sheets/models/cell_history_entry.dart' as _ij1xvs09;
import 'sheets/models/cell_history_page.dart' as _i09xo3k8;
import 'sheets/models/revert_result.dart' as _ilv3hlxr;
import 'sheets/models/revert_skip.dart' as _ipqum05l;
import 'sheets/models/server_change_record.dart' as _it4o4dd3;
import 'sheets/models/sheets_activity_summary.dart' as _iaehez21;
import 'sheets/models/sheets_change_log_receipt.dart' as _i5z6gq3n;
import 'sheets/models/sheets_contributor_stat.dart' as _i9yjzgjk;
import 'sheets/models/sheets_merged_signal.dart' as _izigafhu;
import 'sheets/models/sheets_snapshot_index.dart' as _iwl8v9t3;
import 'sheets/models/space_reservation.dart' as _i9g7m0kd;
import 'sheets/models/space_stats.dart' as _izbczo40;
import 'sheets/models/space_subscription.dart' as _i1qxq8ae;
import 'sheets/models/subscribe_result.dart' as _i6dq35xo;
import 'sheets/models/subscription_reason.dart' as _ic8hyldr;
import 'write/messages/doc_bus_message.dart' as _i8zfu67r;
import 'write/messages/doc_client_message.dart' as _imbts8if;
import 'write/messages/doc_server_message.dart' as _icpkpcrn;
import 'write/models/convert_for_insert_result.dart' as _igqu3xcv;
import 'write/models/doc_reject_code.dart' as _i5srcd7q;
import 'write/models/document.dart' as _i4sx4pml;
import 'write/models/document_import_report.dart' as _ixppud51;
import 'write/models/document_info.dart' as _iu022vpf;
import 'write/models/document_meta_change.dart' as _ir38bcqq;
import 'write/models/document_meta_patch.dart' as _inkjv0lb;
import 'write/models/document_meta_view.dart' as _icsyekcn;
import 'write/models/document_op.dart' as _iufsprkx;
import 'write/models/document_op_kind.dart' as _igr6xq1c;
import 'write/models/document_op_view.dart' as _issmv319;
import 'write/models/document_snapshot.dart' as _i2cnn8i8;
import 'write/models/document_snapshot_view.dart' as _i0cy62lm;
import 'write/models/export_progress_event.dart' as _is1ql5wp;
import 'write/models/export_progress_kind.dart' as _isdjhzgs;
import 'write/models/export_result_view.dart' as _if2sngze;
import 'write/models/theme_conflict_exception.dart' as _ittnhawp;
import 'write/models/write_diff_author.dart' as _ii88i7dv;
import 'write/models/write_diff_cache.dart' as _ig4xquf5;
import 'write/models/write_diff_view.dart' as _idky93gt;
import 'write/models/write_theme.dart' as _iynqrh33;
import 'write/models/write_theme_revision.dart' as _i7pbwt05;
import 'write/models/write_theme_revision_view.dart' as _ick3mhj2;
import 'write/models/write_theme_view.dart' as _ixbjd26z;
import 'write/models/write_version_document.dart' as _is9bkd9t;
export 'platform/activity/activity_event.dart';
export 'platform/activity/activity_event_view.dart';
export 'platform/activity/activity_type.dart';
export 'platform/comments/comment.dart';
export 'platform/comments/comment_anchor_kind.dart';
export 'platform/comments/comment_event.dart';
export 'platform/comments/comment_event_kind.dart';
export 'platform/comments/comment_filter.dart';
export 'platform/comments/comment_signal.dart';
export 'platform/comments/comment_status.dart';
export 'platform/comments/comment_system_event.dart';
export 'platform/comments/comment_thread.dart';
export 'platform/comments/comment_thread_view.dart';
export 'platform/comments/comment_view.dart';
export 'platform/common/access_role.dart';
export 'platform/common/wonky_error_code.dart';
export 'platform/common/wonky_exception.dart';
export 'platform/drive/drive_change.dart';
export 'platform/drive/drive_change_kind.dart';
export 'platform/drive/drive_change_signal.dart';
export 'platform/drive/drive_item.dart';
export 'platform/drive/drive_item_kind.dart';
export 'platform/drive/drive_item_user_state.dart';
export 'platform/drive/drive_item_view.dart';
export 'platform/drive/drive_list_filter.dart';
export 'platform/drive/drive_list_page.dart';
export 'platform/drive/drive_owner_filter.dart';
export 'platform/drive/drive_search_filters.dart';
export 'platform/drive/drive_sort.dart';
export 'platform/drive/drive_sort_field.dart';
export 'platform/drive/drive_view.dart';
export 'platform/drive/import_options.dart';
export 'platform/drive/import_report_view.dart';
export 'platform/drive/import_warning_view.dart';
export 'platform/drive/storage_usage.dart';
export 'platform/drive/template_category.dart';
export 'platform/drive/template_view.dart';
export 'platform/feedback/feedback_kind.dart';
export 'platform/feedback/feedback_report.dart';
export 'platform/feedback/feedback_submission.dart';
export 'platform/files/file_upload_ticket.dart';
export 'platform/files/file_url_view.dart';
export 'platform/files/stored_file.dart';
export 'platform/files/stored_file_kind.dart';
export 'platform/files/stored_file_status.dart';
export 'platform/meta/feature_flags.dart';
export 'platform/meta/protocol_info.dart';
export 'platform/meta/server_limits.dart';
export 'platform/notifications/notification_event.dart';
export 'platform/notifications/notification_kind.dart';
export 'platform/notifications/notification_page.dart';
export 'platform/notifications/notification_signal.dart';
export 'platform/notifications/notification_view.dart';
export 'platform/notifications/user_notification.dart';
export 'platform/presence/participant.dart';
export 'platform/presence/presence_bus_message.dart';
export 'platform/presence/presence_event.dart';
export 'platform/presence/presence_state.dart';
export 'platform/presence/presence_update.dart';
export 'platform/sharing/access_request.dart';
export 'platform/sharing/access_request_outcome.dart';
export 'platform/sharing/access_request_view.dart';
export 'platform/sharing/drive_item_permission.dart';
export 'platform/sharing/invite_resolution.dart';
export 'platform/sharing/item_sharing_settings.dart';
export 'platform/sharing/ownership_transfer.dart';
export 'platform/sharing/ownership_transfer_view.dart';
export 'platform/sharing/permission_view.dart';
export 'platform/sharing/share_link.dart';
export 'platform/sharing/share_link_view.dart';
export 'platform/sharing/sharing_info.dart';
export 'platform/users/access_token_view.dart';
export 'platform/users/account_deletion_preview.dart';
export 'platform/users/app_theme_mode.dart';
export 'platform/users/created_access_token.dart';
export 'platform/users/personal_access_token.dart';
export 'platform/users/ui_density.dart';
export 'platform/users/user_preferences.dart';
export 'platform/users/user_preferences_patch.dart';
export 'platform/users/user_profile.dart';
export 'platform/users/user_profile_view.dart';
export 'platform/users/user_summary.dart';
export 'platform/versions/item_version.dart';
export 'platform/versions/item_version_state.dart';
export 'platform/versions/item_version_view.dart';
export 'platform/versions/version_kind.dart';
export 'platform/versions/version_restore_result.dart';
export 'platform/versions/version_storage.dart';
export 'sheets/models/cell_history.dart';
export 'sheets/models/cell_history_entry.dart';
export 'sheets/models/cell_history_page.dart';
export 'sheets/models/revert_result.dart';
export 'sheets/models/revert_skip.dart';
export 'sheets/models/server_change_record.dart';
export 'sheets/models/sheets_activity_summary.dart';
export 'sheets/models/sheets_change_log_receipt.dart';
export 'sheets/models/sheets_contributor_stat.dart';
export 'sheets/models/sheets_merged_signal.dart';
export 'sheets/models/sheets_snapshot_index.dart';
export 'sheets/models/space_reservation.dart';
export 'sheets/models/space_stats.dart';
export 'sheets/models/space_subscription.dart';
export 'sheets/models/subscribe_result.dart';
export 'sheets/models/subscription_reason.dart';
export 'write/messages/doc_bus_message.dart';
export 'write/messages/doc_client_message.dart';
export 'write/messages/doc_server_message.dart';
export 'write/models/convert_for_insert_result.dart';
export 'write/models/doc_reject_code.dart';
export 'write/models/document.dart';
export 'write/models/document_import_report.dart';
export 'write/models/document_info.dart';
export 'write/models/document_meta_change.dart';
export 'write/models/document_meta_patch.dart';
export 'write/models/document_meta_view.dart';
export 'write/models/document_op.dart';
export 'write/models/document_op_kind.dart';
export 'write/models/document_op_view.dart';
export 'write/models/document_snapshot.dart';
export 'write/models/document_snapshot_view.dart';
export 'write/models/export_progress_event.dart';
export 'write/models/export_progress_kind.dart';
export 'write/models/export_result_view.dart';
export 'write/models/theme_conflict_exception.dart';
export 'write/models/write_diff_author.dart';
export 'write/models/write_diff_cache.dart';
export 'write/models/write_diff_view.dart';
export 'write/models/write_theme.dart';
export 'write/models/write_theme_revision.dart';
export 'write/models/write_theme_revision_view.dart';
export 'write/models/write_theme_view.dart';
export 'write/models/write_version_document.dart';
export 'sync_tables.dart';

class Protocol extends _is.DatabaseSerializationManager
    implements _is.DatabaseProtocolDeserializationProvider {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._().._registerHostProtocols();

  @override
  _is.ProtocolDeserialization get deserializationMetadata =>
      _is.ProtocolDeserialization.cached(
        this,
        types: const [
          _is.getType<_iatdjl5p.ActivityEvent>,
          _is.getType<_isa7sjzq.ActivityEventView>,
          _is.getType<_i50cy468.ActivityType>,
          _is.getType<_iyixppck.Comment>,
          _is.getType<_iw81twtc.CommentAnchorKind>,
          _is.getType<_imlsyj2p.CommentEvent>,
          _is.getType<_ih1mb6x5.CommentEventKind>,
          _is.getType<_il5y6tzr.CommentFilter>,
          _is.getType<_ix3p7034.CommentSignal>,
          _is.getType<_iowdswxe.CommentStatus>,
          _is.getType<_i94wr3td.CommentSystemEvent>,
          _is.getType<_ijog60vm.CommentThread>,
          _is.getType<_i818olql.CommentThreadView>,
          _is.getType<_i4xrxro7.CommentView>,
          _is.getType<_ii98prcs.AccessRole>,
          _is.getType<_inb0isem.WonkyErrorCode>,
          _is.getType<_igdswlrw.WonkyException>,
          _is.getType<_iktwt5zz.DriveChange>,
          _is.getType<_ijoqbs82.DriveChangeKind>,
          _is.getType<_i0atxq9l.DriveChangeSignal>,
          _is.getType<_inge8yy2.DriveItem>,
          _is.getType<_i8mh39wa.DriveItemKind>,
          _is.getType<_i0g2m831.DriveItemUserState>,
          _is.getType<_infxyf98.DriveItemView>,
          _is.getType<_ivypvw0m.DriveListFilter>,
          _is.getType<_iavdhzsq.DriveListPage>,
          _is.getType<_if1dhg5z.DriveOwnerFilter>,
          _is.getType<_i6k3d1nc.DriveSearchFilters>,
          _is.getType<_iu13r4v2.DriveSort>,
          _is.getType<_ix0g8yw4.DriveSortField>,
          _is.getType<_ipww3kqy.DriveView>,
          _is.getType<_i2cmzvye.ImportOptions>,
          _is.getType<_i68yhxa0.ImportReportView>,
          _is.getType<_i48sm9f2.ImportWarningView>,
          _is.getType<_i26hsnhw.StorageUsage>,
          _is.getType<_iiedu4vz.TemplateCategory>,
          _is.getType<_i2ox7ta1.TemplateView>,
          _is.getType<_iv1sk0e8.FeedbackKind>,
          _is.getType<_iu565i0a.FeedbackReport>,
          _is.getType<_ilhpki98.FeedbackSubmission>,
          _is.getType<_irrzp8p9.FileUploadTicket>,
          _is.getType<_itzt3x6d.FileUrlView>,
          _is.getType<_im8eh74x.StoredFile>,
          _is.getType<_i45dmz4a.StoredFileKind>,
          _is.getType<_ik7q11oy.StoredFileStatus>,
          _is.getType<_ivk6eyvx.FeatureFlags>,
          _is.getType<_ib575x0y.ProtocolInfo>,
          _is.getType<_i28el0at.ServerLimits>,
          _is.getType<_iexg4yzt.NotificationEvent>,
          _is.getType<_iqlnbbfp.NotificationKind>,
          _is.getType<_i3r1eo8q.NotificationPage>,
          _is.getType<_iqsxdr4a.NotificationSignal>,
          _is.getType<_izfzk9h3.NotificationView>,
          _is.getType<_ik59hiyp.UserNotification>,
          _is.getType<_iylgyc33.Participant>,
          _is.getType<_i7dp90q0.PresenceBusMessage>,
          _is.getType<_i8r9afjv.PresenceFollowerCount>,
          _is.getType<_i8r9afjv.PresenceHints>,
          _is.getType<_i8r9afjv.PresenceJoined>,
          _is.getType<_i8r9afjv.PresenceLeft>,
          _is.getType<_i8r9afjv.PresenceNotice>,
          _is.getType<_i8r9afjv.PresenceRoster>,
          _is.getType<_i8r9afjv.PresenceUpdated>,
          _is.getType<_ik055xb9.PresenceState>,
          _is.getType<_isz2sju0.PresenceUpdate>,
          _is.getType<_i8scn8dm.AccessRequest>,
          _is.getType<_i7trut12.AccessRequestOutcome>,
          _is.getType<_iimp60a4.AccessRequestView>,
          _is.getType<_iuzgacy4.DriveItemPermission>,
          _is.getType<_ikeljole.InviteResolution>,
          _is.getType<_ih3711er.ItemSharingSettings>,
          _is.getType<_ijwxtu30.OwnershipTransfer>,
          _is.getType<_iilpsf9g.OwnershipTransferView>,
          _is.getType<_iead0ok9.PermissionView>,
          _is.getType<_it712lg1.ShareLink>,
          _is.getType<_iw2xoohn.ShareLinkView>,
          _is.getType<_itd24os1.SharingInfo>,
          _is.getType<_izha9j5m.AccessTokenView>,
          _is.getType<_iq4dupwy.AccountDeletionPreview>,
          _is.getType<_i6azdr3n.AppThemeMode>,
          _is.getType<_iru4pv75.CreatedAccessToken>,
          _is.getType<_ijodrcyd.PersonalAccessToken>,
          _is.getType<_i5lc4gt0.UiDensity>,
          _is.getType<_i501u5m5.UserPreferences>,
          _is.getType<_id95rrz2.UserPreferencesPatch>,
          _is.getType<_ihzl7wbq.UserProfile>,
          _is.getType<_iufqmqtc.UserProfileView>,
          _is.getType<_i6y7tspy.UserSummary>,
          _is.getType<_i7jb115m.ItemVersion>,
          _is.getType<_ibe5uno1.ItemVersionState>,
          _is.getType<_ipbapjbz.ItemVersionView>,
          _is.getType<_in0fdl1f.VersionKind>,
          _is.getType<_in38zbga.VersionRestoreResult>,
          _is.getType<_i5u6d6t4.VersionStorage>,
          _is.getType<_ik5lpvx4.CellHistory>,
          _is.getType<_ij1xvs09.CellHistoryEntry>,
          _is.getType<_i09xo3k8.CellHistoryPage>,
          _is.getType<_ilv3hlxr.RevertResult>,
          _is.getType<_ipqum05l.RevertSkip>,
          _is.getType<_it4o4dd3.ServerChangeRecord>,
          _is.getType<_iaehez21.SheetsActivitySummary>,
          _is.getType<_i5z6gq3n.SheetsChangeLogReceipt>,
          _is.getType<_i9yjzgjk.SheetsContributorStat>,
          _is.getType<_izigafhu.SheetsMergedSignal>,
          _is.getType<_iwl8v9t3.SheetsSnapshotIndex>,
          _is.getType<_i9g7m0kd.SpaceReservation>,
          _is.getType<_izbczo40.SpaceStats>,
          _is.getType<_i1qxq8ae.SpaceSubscription>,
          _is.getType<_i6dq35xo.SubscribeResult>,
          _is.getType<_ic8hyldr.SubscriptionReason>,
          _is.getType<_icpkpcrn.DocAck>,
          _is.getType<_i8zfu67r.DocBusMessage>,
          _is.getType<_imbts8if.DocCursorUpdate>,
          _is.getType<_imbts8if.DocHashCheck>,
          _is.getType<_imbts8if.DocPing>,
          _is.getType<_imbts8if.DocRequestOps>,
          _is.getType<_imbts8if.DocSubmitOp>,
          _is.getType<_icpkpcrn.DocHashResult>,
          _is.getType<_icpkpcrn.DocInit>,
          _is.getType<_icpkpcrn.DocMetaChanged>,
          _is.getType<_icpkpcrn.DocOpRejected>,
          _is.getType<_icpkpcrn.DocParticipantJoined>,
          _is.getType<_icpkpcrn.DocParticipantLeft>,
          _is.getType<_icpkpcrn.DocPong>,
          _is.getType<_icpkpcrn.DocRemoteCursor>,
          _is.getType<_icpkpcrn.DocRemoteOp>,
          _is.getType<_icpkpcrn.DocRoleChanged>,
          _is.getType<_igqu3xcv.ConvertForInsertResult>,
          _is.getType<_i5srcd7q.DocRejectCode>,
          _is.getType<_i4sx4pml.Document>,
          _is.getType<_ixppud51.DocumentImportReport>,
          _is.getType<_iu022vpf.DocumentInfo>,
          _is.getType<_ir38bcqq.DocumentMetaChange>,
          _is.getType<_inkjv0lb.DocumentMetaPatch>,
          _is.getType<_icsyekcn.DocumentMetaView>,
          _is.getType<_iufsprkx.DocumentOp>,
          _is.getType<_igr6xq1c.DocumentOpKind>,
          _is.getType<_issmv319.DocumentOpView>,
          _is.getType<_i2cnn8i8.DocumentSnapshot>,
          _is.getType<_i0cy62lm.DocumentSnapshotView>,
          _is.getType<_is1ql5wp.ExportProgressEvent>,
          _is.getType<_isdjhzgs.ExportProgressKind>,
          _is.getType<_if2sngze.ExportResultView>,
          _is.getType<_ittnhawp.ThemeConflictException>,
          _is.getType<_ii88i7dv.WriteDiffAuthor>,
          _is.getType<_ig4xquf5.WriteDiffCache>,
          _is.getType<_idky93gt.WriteDiffView>,
          _is.getType<_iynqrh33.WriteTheme>,
          _is.getType<_i7pbwt05.WriteThemeRevision>,
          _is.getType<_ick3mhj2.WriteThemeRevisionView>,
          _is.getType<_ixbjd26z.WriteThemeView>,
          _is.getType<_is9bkd9t.WriteVersionDocument>,
          _is.getType<_iatdjl5p.ActivityEvent?>,
          _is.getType<_isa7sjzq.ActivityEventView?>,
          _is.getType<_i50cy468.ActivityType?>,
          _is.getType<_iyixppck.Comment?>,
          _is.getType<_iw81twtc.CommentAnchorKind?>,
          _is.getType<_imlsyj2p.CommentEvent?>,
          _is.getType<_ih1mb6x5.CommentEventKind?>,
          _is.getType<_il5y6tzr.CommentFilter?>,
          _is.getType<_ix3p7034.CommentSignal?>,
          _is.getType<_iowdswxe.CommentStatus?>,
          _is.getType<_i94wr3td.CommentSystemEvent?>,
          _is.getType<_ijog60vm.CommentThread?>,
          _is.getType<_i818olql.CommentThreadView?>,
          _is.getType<_i4xrxro7.CommentView?>,
          _is.getType<_ii98prcs.AccessRole?>,
          _is.getType<_inb0isem.WonkyErrorCode?>,
          _is.getType<_igdswlrw.WonkyException?>,
          _is.getType<_iktwt5zz.DriveChange?>,
          _is.getType<_ijoqbs82.DriveChangeKind?>,
          _is.getType<_i0atxq9l.DriveChangeSignal?>,
          _is.getType<_inge8yy2.DriveItem?>,
          _is.getType<_i8mh39wa.DriveItemKind?>,
          _is.getType<_i0g2m831.DriveItemUserState?>,
          _is.getType<_infxyf98.DriveItemView?>,
          _is.getType<_ivypvw0m.DriveListFilter?>,
          _is.getType<_iavdhzsq.DriveListPage?>,
          _is.getType<_if1dhg5z.DriveOwnerFilter?>,
          _is.getType<_i6k3d1nc.DriveSearchFilters?>,
          _is.getType<_iu13r4v2.DriveSort?>,
          _is.getType<_ix0g8yw4.DriveSortField?>,
          _is.getType<_ipww3kqy.DriveView?>,
          _is.getType<_i2cmzvye.ImportOptions?>,
          _is.getType<_i68yhxa0.ImportReportView?>,
          _is.getType<_i48sm9f2.ImportWarningView?>,
          _is.getType<_i26hsnhw.StorageUsage?>,
          _is.getType<_iiedu4vz.TemplateCategory?>,
          _is.getType<_i2ox7ta1.TemplateView?>,
          _is.getType<_iv1sk0e8.FeedbackKind?>,
          _is.getType<_iu565i0a.FeedbackReport?>,
          _is.getType<_ilhpki98.FeedbackSubmission?>,
          _is.getType<_irrzp8p9.FileUploadTicket?>,
          _is.getType<_itzt3x6d.FileUrlView?>,
          _is.getType<_im8eh74x.StoredFile?>,
          _is.getType<_i45dmz4a.StoredFileKind?>,
          _is.getType<_ik7q11oy.StoredFileStatus?>,
          _is.getType<_ivk6eyvx.FeatureFlags?>,
          _is.getType<_ib575x0y.ProtocolInfo?>,
          _is.getType<_i28el0at.ServerLimits?>,
          _is.getType<_iexg4yzt.NotificationEvent?>,
          _is.getType<_iqlnbbfp.NotificationKind?>,
          _is.getType<_i3r1eo8q.NotificationPage?>,
          _is.getType<_iqsxdr4a.NotificationSignal?>,
          _is.getType<_izfzk9h3.NotificationView?>,
          _is.getType<_ik59hiyp.UserNotification?>,
          _is.getType<_iylgyc33.Participant?>,
          _is.getType<_i7dp90q0.PresenceBusMessage?>,
          _is.getType<_i8r9afjv.PresenceFollowerCount?>,
          _is.getType<_i8r9afjv.PresenceHints?>,
          _is.getType<_i8r9afjv.PresenceJoined?>,
          _is.getType<_i8r9afjv.PresenceLeft?>,
          _is.getType<_i8r9afjv.PresenceNotice?>,
          _is.getType<_i8r9afjv.PresenceRoster?>,
          _is.getType<_i8r9afjv.PresenceUpdated?>,
          _is.getType<_ik055xb9.PresenceState?>,
          _is.getType<_isz2sju0.PresenceUpdate?>,
          _is.getType<_i8scn8dm.AccessRequest?>,
          _is.getType<_i7trut12.AccessRequestOutcome?>,
          _is.getType<_iimp60a4.AccessRequestView?>,
          _is.getType<_iuzgacy4.DriveItemPermission?>,
          _is.getType<_ikeljole.InviteResolution?>,
          _is.getType<_ih3711er.ItemSharingSettings?>,
          _is.getType<_ijwxtu30.OwnershipTransfer?>,
          _is.getType<_iilpsf9g.OwnershipTransferView?>,
          _is.getType<_iead0ok9.PermissionView?>,
          _is.getType<_it712lg1.ShareLink?>,
          _is.getType<_iw2xoohn.ShareLinkView?>,
          _is.getType<_itd24os1.SharingInfo?>,
          _is.getType<_izha9j5m.AccessTokenView?>,
          _is.getType<_iq4dupwy.AccountDeletionPreview?>,
          _is.getType<_i6azdr3n.AppThemeMode?>,
          _is.getType<_iru4pv75.CreatedAccessToken?>,
          _is.getType<_ijodrcyd.PersonalAccessToken?>,
          _is.getType<_i5lc4gt0.UiDensity?>,
          _is.getType<_i501u5m5.UserPreferences?>,
          _is.getType<_id95rrz2.UserPreferencesPatch?>,
          _is.getType<_ihzl7wbq.UserProfile?>,
          _is.getType<_iufqmqtc.UserProfileView?>,
          _is.getType<_i6y7tspy.UserSummary?>,
          _is.getType<_i7jb115m.ItemVersion?>,
          _is.getType<_ibe5uno1.ItemVersionState?>,
          _is.getType<_ipbapjbz.ItemVersionView?>,
          _is.getType<_in0fdl1f.VersionKind?>,
          _is.getType<_in38zbga.VersionRestoreResult?>,
          _is.getType<_i5u6d6t4.VersionStorage?>,
          _is.getType<_ik5lpvx4.CellHistory?>,
          _is.getType<_ij1xvs09.CellHistoryEntry?>,
          _is.getType<_i09xo3k8.CellHistoryPage?>,
          _is.getType<_ilv3hlxr.RevertResult?>,
          _is.getType<_ipqum05l.RevertSkip?>,
          _is.getType<_it4o4dd3.ServerChangeRecord?>,
          _is.getType<_iaehez21.SheetsActivitySummary?>,
          _is.getType<_i5z6gq3n.SheetsChangeLogReceipt?>,
          _is.getType<_i9yjzgjk.SheetsContributorStat?>,
          _is.getType<_izigafhu.SheetsMergedSignal?>,
          _is.getType<_iwl8v9t3.SheetsSnapshotIndex?>,
          _is.getType<_i9g7m0kd.SpaceReservation?>,
          _is.getType<_izbczo40.SpaceStats?>,
          _is.getType<_i1qxq8ae.SpaceSubscription?>,
          _is.getType<_i6dq35xo.SubscribeResult?>,
          _is.getType<_ic8hyldr.SubscriptionReason?>,
          _is.getType<_icpkpcrn.DocAck?>,
          _is.getType<_i8zfu67r.DocBusMessage?>,
          _is.getType<_imbts8if.DocCursorUpdate?>,
          _is.getType<_imbts8if.DocHashCheck?>,
          _is.getType<_imbts8if.DocPing?>,
          _is.getType<_imbts8if.DocRequestOps?>,
          _is.getType<_imbts8if.DocSubmitOp?>,
          _is.getType<_icpkpcrn.DocHashResult?>,
          _is.getType<_icpkpcrn.DocInit?>,
          _is.getType<_icpkpcrn.DocMetaChanged?>,
          _is.getType<_icpkpcrn.DocOpRejected?>,
          _is.getType<_icpkpcrn.DocParticipantJoined?>,
          _is.getType<_icpkpcrn.DocParticipantLeft?>,
          _is.getType<_icpkpcrn.DocPong?>,
          _is.getType<_icpkpcrn.DocRemoteCursor?>,
          _is.getType<_icpkpcrn.DocRemoteOp?>,
          _is.getType<_icpkpcrn.DocRoleChanged?>,
          _is.getType<_igqu3xcv.ConvertForInsertResult?>,
          _is.getType<_i5srcd7q.DocRejectCode?>,
          _is.getType<_i4sx4pml.Document?>,
          _is.getType<_ixppud51.DocumentImportReport?>,
          _is.getType<_iu022vpf.DocumentInfo?>,
          _is.getType<_ir38bcqq.DocumentMetaChange?>,
          _is.getType<_inkjv0lb.DocumentMetaPatch?>,
          _is.getType<_icsyekcn.DocumentMetaView?>,
          _is.getType<_iufsprkx.DocumentOp?>,
          _is.getType<_igr6xq1c.DocumentOpKind?>,
          _is.getType<_issmv319.DocumentOpView?>,
          _is.getType<_i2cnn8i8.DocumentSnapshot?>,
          _is.getType<_i0cy62lm.DocumentSnapshotView?>,
          _is.getType<_is1ql5wp.ExportProgressEvent?>,
          _is.getType<_isdjhzgs.ExportProgressKind?>,
          _is.getType<_if2sngze.ExportResultView?>,
          _is.getType<_ittnhawp.ThemeConflictException?>,
          _is.getType<_ii88i7dv.WriteDiffAuthor?>,
          _is.getType<_ig4xquf5.WriteDiffCache?>,
          _is.getType<_idky93gt.WriteDiffView?>,
          _is.getType<_iynqrh33.WriteTheme?>,
          _is.getType<_i7pbwt05.WriteThemeRevision?>,
          _is.getType<_ick3mhj2.WriteThemeRevisionView?>,
          _is.getType<_ixbjd26z.WriteThemeView?>,
          _is.getType<_is9bkd9t.WriteVersionDocument?>,
          _is.getType<List<int>>,
          _is.getType<List<_i4xrxro7.CommentView>>,
          _is.getType<List<_i6y7tspy.UserSummary>>,
          _is.getType<Map<String, List<int>>>,
          _is.getType<List<_i8mh39wa.DriveItemKind>>,
          _is.getType<List<_i8mh39wa.DriveItemKind>?>,
          _is.getType<List<_infxyf98.DriveItemView>>,
          _is.getType<List<_i48sm9f2.ImportWarningView>>,
          _is.getType<List<_izfzk9h3.NotificationView>>,
          _is.getType<List<String>>,
          _is.getType<List<String>?>,
          _is.getType<List<_iylgyc33.Participant>>,
          _is.getType<List<_iead0ok9.PermissionView>>,
          _is.getType<List<_iimp60a4.AccessRequestView>>,
          _is.getType<List<_ij1xvs09.CellHistoryEntry>>,
          _is.getType<List<_ipqum05l.RevertSkip>>,
          _is.getType<Map<String, Map<int, int>>>,
          _is.getType<Map<int, int>>,
          _is.getType<List<_i9yjzgjk.SheetsContributorStat>>,
          _is.getType<Map<String, int>>,
          _is.getType<List<_issmv319.DocumentOpView>>,
          _is.getType<List<_issmv319.DocumentOpView>?>,
          _is.getType<List<_i48sm9f2.ImportWarningView>?>,
          _is.getType<List<_ii88i7dv.WriteDiffAuthor>>,
        ],
        modules: const [
          _iais.Protocol.new,
          _izehhkf5.Protocol.new,
          _iacs.Protocol.new,
          _i810rwvy.Protocol.new,
          _isp.Protocol.new,
        ],
      );

  static List<_isp.TableDefinition> get targetTableDefinitions => [
    _isp.TableDefinition(
      name: 'access_request',
      dartName: 'AccessRequest',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'itemId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'requesterId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'requestedRole',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:AccessRole',
        ),
        _isp.ColumnDefinition(
          name: 'message',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'handledAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _isp.ColumnDefinition(
          name: 'handledById',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'outcome',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'protocol:AccessRequestOutcome?',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'access_request_fk_0',
          columns: ['itemId'],
          referenceTable: 'drive_item',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'access_request_fk_1',
          columns: ['requesterId'],
          referenceTable: 'user_profile',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'access_request_item_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'itemId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'handledAt',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'activity_event',
      dartName: 'ActivityEvent',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'itemId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'actorId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'actorKind',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'wonky_sync_models:ActorKind',
        ),
        _isp.ColumnDefinition(
          name: 'type',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:ActivityType',
        ),
        _isp.ColumnDefinition(
          name: 'summary',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'at',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'activity_event_fk_0',
          columns: ['itemId'],
          referenceTable: 'drive_item',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'activity_item_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'itemId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'at',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'cell_history',
      dartName: 'CellHistory',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'spreadsheetUuid',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'sheetId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'rowId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'colId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'changeLogId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'userUuid',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'actorKind',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'wonky_sync_models:ActorKind',
        ),
        _isp.ColumnDefinition(
          name: 'label',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'at',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'before',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'after',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'cell_history_cell_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'spreadsheetUuid',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'sheetId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'rowId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'colId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'at',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'cell_history_change_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'changeLogId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'rowId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'colId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'comment',
      dartName: 'Comment',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'threadId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'uuid',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isp.ColumnDefinition(
          name: 'authorId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'authorKind',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'wonky_sync_models:ActorKind',
        ),
        _isp.ColumnDefinition(
          name: 'body',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'mentions',
          columnType: _isp.ColumnType.json,
          isNullable: false,
          dartType: 'List<int>',
        ),
        _isp.ColumnDefinition(
          name: 'reactions',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
          columnDefault: '\'{}\'',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'editedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _isp.ColumnDefinition(
          name: 'deletedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _isp.ColumnDefinition(
          name: 'systemEvent',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'protocol:CommentSystemEvent?',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'comment_fk_0',
          columns: ['threadId'],
          referenceTable: 'comment_thread',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'comment_thread_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'threadId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'createdAt',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'comment_uuid_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'uuid',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'comment_thread',
      dartName: 'CommentThread',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'uuid',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'itemId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'anchorKind',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:CommentAnchorKind',
        ),
        _isp.ColumnDefinition(
          name: 'anchorJson',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'quotedText',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'status',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:CommentStatus',
          columnDefault: '\'open\'',
        ),
        _isp.ColumnDefinition(
          name: 'createdById',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'updatedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _isp.ColumnDefinition(
          name: 'resolvedById',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'resolvedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _isp.ColumnDefinition(
          name: 'assigneeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'statusBeforeOrphan',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'protocol:CommentStatus?',
        ),
        _isp.ColumnDefinition(
          name: 'orphanReasonJson',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'suggestionId',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'comment_thread_fk_0',
          columns: ['itemId'],
          referenceTable: 'drive_item',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'comment_thread_item_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'itemId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'status',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'comment_thread_uuid_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'uuid',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'document',
      dartName: 'Document',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'uuid',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'itemId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'headRevision',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
          columnDefault: '0',
        ),
        _isp.ColumnDefinition(
          name: 'latestSnapshotRevision',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
          columnDefault: '0',
        ),
        _isp.ColumnDefinition(
          name: 'themeId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isp.ColumnDefinition(
          name: 'pageSetupJson',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
          columnDefault: '\'{}\'',
        ),
        _isp.ColumnDefinition(
          name: 'language',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'frontMatter',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'charCount',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
          columnDefault: '0',
        ),
        _isp.ColumnDefinition(
          name: 'wordCount',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
          columnDefault: '0',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'updatedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'document_fk_0',
          columns: ['itemId'],
          referenceTable: 'drive_item',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'document_uuid_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'uuid',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'document_item_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'itemId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'document_import_report',
      dartName: 'DocumentImportReport',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'documentId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'userId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'warningsJson',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'seenAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'document_import_report_fk_0',
          columns: ['documentId'],
          referenceTable: 'document',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'document_import_report_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'documentId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'userId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'document_meta_change',
      dartName: 'DocumentMetaChange',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'documentId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'field',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'clientOpId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isp.ColumnDefinition(
          name: 'beforeJson',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'afterJson',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'authorId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'actorKind',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'wonky_sync_models:ActorKind',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'document_meta_change_fk_0',
          columns: ['documentId'],
          referenceTable: 'document',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'document_meta_change_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'documentId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'createdAt',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'document_meta_change_client_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'documentId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'clientOpId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'document_op',
      dartName: 'DocumentOp',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'documentId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'revision',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'clientOpId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'authorId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'actorKind',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'wonky_sync_models:ActorKind',
        ),
        _isp.ColumnDefinition(
          name: 'sessionId',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'kind',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:DocumentOpKind',
        ),
        _isp.ColumnDefinition(
          name: 'baseRevision',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'deltaJson',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'inverseJson',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'document_op_fk_0',
          columns: ['documentId'],
          referenceTable: 'document',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'document_op_rev_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'documentId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'revision',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'document_op_client_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'documentId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'clientOpId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'document_snapshot',
      dartName: 'DocumentSnapshot',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'documentId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'revision',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'deltaJson',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'compressed',
          columnType: _isp.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'document_snapshot_fk_0',
          columns: ['documentId'],
          referenceTable: 'document',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'document_snapshot_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'documentId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'revision',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'drive_item',
      dartName: 'DriveItem',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'uuid',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'kind',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:DriveItemKind',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'ownerId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'parentId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'description',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'contentRef',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isp.ColumnDefinition(
          name: 'thumbnailFileId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isp.ColumnDefinition(
          name: 'sizeBytes',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
          columnDefault: '0',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'createdById',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'modifiedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'modifiedById',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'trashedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _isp.ColumnDefinition(
          name: 'trashedById',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'templateOf',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'protocol:TemplateCategory?',
        ),
        _isp.ColumnDefinition(
          name: 'templateKey',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'editorsCanShare',
          columnType: _isp.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'true',
        ),
        _isp.ColumnDefinition(
          name: 'nonEditorsCanExport',
          columnType: _isp.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'true',
        ),
        _isp.ColumnDefinition(
          name: 'viewersSeeComments',
          columnType: _isp.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
        _isp.ColumnDefinition(
          name: 'searchText',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'drive_item_fk_0',
          columns: ['ownerId'],
          referenceTable: 'user_profile',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.restrict,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'drive_item_fk_1',
          columns: ['parentId'],
          referenceTable: 'drive_item',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.setNull,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'drive_item_uuid_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'uuid',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'drive_item_parent_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'parentId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'drive_item_owner_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'ownerId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'trashedAt',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'drive_item_content_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'contentRef',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'drive_item_template_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'templateOf',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'drive_item_permission',
      dartName: 'DriveItemPermission',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'itemId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'userId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'invitedEmail',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'role',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:AccessRole',
        ),
        _isp.ColumnDefinition(
          name: 'inheritedFromId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'grantedById',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'grantedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'expiresAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'drive_item_permission_fk_0',
          columns: ['itemId'],
          referenceTable: 'drive_item',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'drive_item_permission_fk_1',
          columns: ['userId'],
          referenceTable: 'user_profile',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'perm_item_user_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'itemId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'userId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'inheritedFromId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'invitedEmail',
            ),
          ],
          type: 'btree',
          isUnique: true,
          nullsDistinct: false,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'perm_user_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'userId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'perm_email_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'invitedEmail',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'drive_item_user_state',
      dartName: 'DriveItemUserState',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'itemId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'userId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'starred',
          columnType: _isp.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
        _isp.ColumnDefinition(
          name: 'lastOpenedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _isp.ColumnDefinition(
          name: 'lastEditedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _isp.ColumnDefinition(
          name: 'pinnedOffline',
          columnType: _isp.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
        _isp.ColumnDefinition(
          name: 'shortcutParentId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'viaLink',
          columnType: _isp.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'drive_item_user_state_fk_0',
          columns: ['itemId'],
          referenceTable: 'drive_item',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'drive_item_user_state_fk_1',
          columns: ['userId'],
          referenceTable: 'user_profile',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'drive_item_user_state_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'itemId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'userId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'drive_item_user_recent_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'userId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'lastOpenedAt',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'feedback_report',
      dartName: 'FeedbackReport',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'userId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'kind',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:FeedbackKind',
        ),
        _isp.ColumnDefinition(
          name: 'message',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'app',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'appVersion',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'platform',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'route',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'stackTrace',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'contextJson',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'feedback_report_created_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'createdAt',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'item_version',
      dartName: 'ItemVersion',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'itemId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'kind',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:VersionKind',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'createdById',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'authors',
          columnType: _isp.ColumnType.json,
          isNullable: false,
          dartType: 'List<int>',
        ),
        _isp.ColumnDefinition(
          name: 'storageKind',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:VersionStorage',
        ),
        _isp.ColumnDefinition(
          name: 'revision',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'snapshotFileId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isp.ColumnDefinition(
          name: 'sizeBytes',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
          columnDefault: '0',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'item_version_fk_0',
          columns: ['itemId'],
          referenceTable: 'drive_item',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'item_version_item_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'itemId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'createdAt',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'item_version_state',
      dartName: 'ItemVersionState',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'itemId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'lastEditAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'dirtySince',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _isp.ColumnDefinition(
          name: 'lastVersionAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _isp.ColumnDefinition(
          name: 'editorsSinceLastVersion',
          columnType: _isp.ColumnType.json,
          isNullable: false,
          dartType: 'List<int>',
        ),
        _isp.ColumnDefinition(
          name: 'lastRevision',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'item_version_state_fk_0',
          columns: ['itemId'],
          referenceTable: 'drive_item',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'item_version_state_item_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'itemId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'item_version_state_dirty_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'dirtySince',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'notification',
      dartName: 'UserNotification',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'userId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'kind',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:NotificationKind',
        ),
        _isp.ColumnDefinition(
          name: 'itemId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'actorId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'payload',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'readAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _isp.ColumnDefinition(
          name: 'emailedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'notification_fk_0',
          columns: ['userId'],
          referenceTable: 'user_profile',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'notification_user_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'userId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'createdAt',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'ownership_transfer',
      dartName: 'OwnershipTransfer',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'itemId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'fromUserId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'toUserId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'handledAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _isp.ColumnDefinition(
          name: 'accepted',
          columnType: _isp.ColumnType.boolean,
          isNullable: true,
          dartType: 'bool?',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'ownership_transfer_fk_0',
          columns: ['itemId'],
          referenceTable: 'drive_item',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'ownership_transfer_fk_1',
          columns: ['toUserId'],
          referenceTable: 'user_profile',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'ownership_transfer_item_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'itemId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'handledAt',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'personal_access_token',
      dartName: 'PersonalAccessToken',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'userId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'tokenHash',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'prefix',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'scopes',
          columnType: _isp.ColumnType.json,
          isNullable: false,
          dartType: 'List<String>',
        ),
        _isp.ColumnDefinition(
          name: 'expiresAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _isp.ColumnDefinition(
          name: 'lastUsedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'revokedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'personal_access_token_fk_0',
          columns: ['userId'],
          referenceTable: 'user_profile',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'personal_access_token_user_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'userId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'personal_access_token_hash_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'tokenHash',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'server_change_record',
      dartName: 'ServerChangeRecord',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'changeId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'spreadsheetUuid',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'userId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'actorKind',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'wonky_sync_models:ActorKind',
        ),
        _isp.ColumnDefinition(
          name: 'label',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'inverseJson',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'inverseFileId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isp.ColumnDefinition(
          name: 'forwardFileId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isp.ColumnDefinition(
          name: 'cellsAffected',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'expiresAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'revertedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _isp.ColumnDefinition(
          name: 'revertChangeId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'server_change_sheet_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'spreadsheetUuid',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'createdAt',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'server_change_id_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'changeId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'share_link',
      dartName: 'ShareLink',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'itemId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'token',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'role',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'protocol:AccessRole?',
        ),
        _isp.ColumnDefinition(
          name: 'createdById',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'share_link_fk_0',
          columns: ['itemId'],
          referenceTable: 'drive_item',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'share_link_item_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'itemId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'share_link_token_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'token',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'sheets_change_log_receipt',
      dartName: 'SheetsChangeLogReceipt',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'changeLogId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'spaceUuid',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'processedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'sheets_change_log_receipt_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'changeLogId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'sheets_change_log_receipt_space_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'spaceUuid',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'processedAt',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'sheets_snapshot_index',
      dartName: 'SheetsSnapshotIndex',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'itemVersionId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'sheetsJson',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'changedRangesJson',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'authorIds',
          columnType: _isp.ColumnType.json,
          isNullable: false,
          dartType: 'List<int>',
        ),
        _isp.ColumnDefinition(
          name: 'diffFileId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'sheets_snapshot_index_fk_0',
          columns: ['itemVersionId'],
          referenceTable: 'item_version',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'sheets_snapshot_index_version_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'itemVersionId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'space_reservation',
      dartName: 'SpaceReservation',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'userId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'spaceUuid',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'usedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'space_reservation_fk_0',
          columns: ['userId'],
          referenceTable: 'user_profile',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'space_reservation_space_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'spaceUuid',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'space_reservation_user_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'userId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'usedAt',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'space_subscription',
      dartName: 'SpaceSubscription',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'userId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'spreadsheetItemId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'spaceUuid',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'reason',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:SubscriptionReason',
        ),
        _isp.ColumnDefinition(
          name: 'lastUsedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'pinned',
          columnType: _isp.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
        _isp.ColumnDefinition(
          name: 'reasonExpiresAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'space_subscription_fk_0',
          columns: ['userId'],
          referenceTable: 'user_profile',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'space_subscription_fk_1',
          columns: ['spreadsheetItemId'],
          referenceTable: 'drive_item',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'space_subscription_user_space_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'userId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'spaceUuid',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'space_subscription_space_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'spaceUuid',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'stored_file',
      dartName: 'StoredFile',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'fileUuid',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'ownerId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'itemId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'kind',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:StoredFileKind',
        ),
        _isp.ColumnDefinition(
          name: 'storageId',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'path',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'fileName',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'mimeType',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'sizeBytes',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'status',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:StoredFileStatus',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'completedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _isp.ColumnDefinition(
          name: 'expiresAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'stored_file_fk_0',
          columns: ['ownerId'],
          referenceTable: 'user_profile',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.setNull,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'stored_file_fk_1',
          columns: ['itemId'],
          referenceTable: 'drive_item',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'stored_file_uuid_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'fileUuid',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'stored_file_item_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'itemId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'stored_file_expiry_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'expiresAt',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'user_preferences',
      dartName: 'UserPreferences',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'userId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'appTheme',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:AppThemeMode',
          columnDefault: '\'system\'',
        ),
        _isp.ColumnDefinition(
          name: 'accentColor',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'density',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:UiDensity',
          columnDefault: '\'comfortable\'',
        ),
        _isp.ColumnDefinition(
          name: 'reduceMotion',
          columnType: _isp.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
        _isp.ColumnDefinition(
          name: 'keymapOverrides',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
          columnDefault: '\'{}\'',
        ),
        _isp.ColumnDefinition(
          name: 'writeDefaults',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
          columnDefault: '\'{}\'',
        ),
        _isp.ColumnDefinition(
          name: 'sheetsDefaults',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
          columnDefault: '\'{}\'',
        ),
        _isp.ColumnDefinition(
          name: 'notificationSettings',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
          columnDefault: '\'{}\'',
        ),
        _isp.ColumnDefinition(
          name: 'aiEnabled',
          columnType: _isp.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'true',
        ),
        _isp.ColumnDefinition(
          name: 'updatedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'user_preferences_fk_0',
          columns: ['userId'],
          referenceTable: 'user_profile',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'user_preferences_user_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'userId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'user_profile',
      dartName: 'UserProfile',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'authUserId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'displayName',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'email',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'avatarFileId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isp.ColumnDefinition(
          name: 'avatarColor',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'locale',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'timeZone',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'lastSeenAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _isp.ColumnDefinition(
          name: 'welcomeContentAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'user_profile_fk_0',
          columns: ['authUserId'],
          referenceTable: 'serverpod_auth_core_user',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'user_profile_auth_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'authUserId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'user_profile_email_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'email',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'write_diff_cache',
      dartName: 'WriteDiffCache',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'documentId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'fromRevision',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'toRevision',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'json',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'write_diff_cache_fk_0',
          columns: ['documentId'],
          referenceTable: 'document',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'write_diff_cache_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'documentId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'fromRevision',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'toRevision',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'write_theme',
      dartName: 'WriteTheme',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'uuid',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'ownerId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'isBuiltin',
          columnType: _isp.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
        ),
        _isp.ColumnDefinition(
          name: 'builtinKey',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'description',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'schemaVersion',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'version',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'json',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'contentHash',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'updatedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'deletedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'write_theme_fk_0',
          columns: ['ownerId'],
          referenceTable: 'user_profile',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'write_theme_uuid_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'uuid',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'write_theme_owner_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'ownerId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'deletedAt',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'write_theme_builtin_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'builtinKey',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'write_theme_revision',
      dartName: 'WriteThemeRevision',
      schema: 'public',
      module: 'wonky',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'themeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'version',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'json',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'savedById',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'actorKind',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'wonky_sync_models:ActorKind',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'write_theme_revision_fk_0',
          columns: ['themeId'],
          referenceTable: 'write_theme',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'write_theme_rev_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'themeId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'version',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    ..._iais.Protocol.targetTableDefinitions,
    ..._izehhkf5.Protocol.targetTableDefinitions,
    ..._iacs.Protocol.targetTableDefinitions,
    ..._i810rwvy.Protocol() is _is.DatabaseSerializationManager
        ? (_i810rwvy.Protocol() as _is.DatabaseSerializationManager)
              .getTargetTableDefinitions()
        : [],
    ..._isp.Protocol.targetTableDefinitions,
  ];

  static String? getClassNameFromObjectJson(dynamic data) {
    if (data is! Map) return null;
    final className = data['__className__'] as String?;
    return className;
  }

  @override
  T deserialize<T>(
    dynamic data, [
    Type? t,
  ]) {
    t ??= T;

    final dataClassName = getClassNameFromObjectJson(data);
    if (dataClassName != null && dataClassName != getClassNameForType(t)) {
      try {
        return deserializeByClassName({
          'className': dataClassName,
          'data': data,
        });
      } on _is.DeserializationClassNameNotFoundException catch (_) {
        // If the className is not recognized (e.g., older client receiving
        // data with a new subtype), fall back to deserializing without the
        // className, using the expected type T.
      }
    }

    if (t == _iatdjl5p.ActivityEvent) {
      return _iatdjl5p.ActivityEvent.fromJson(data) as T;
    }
    if (t == _isa7sjzq.ActivityEventView) {
      return _isa7sjzq.ActivityEventView.fromJson(data) as T;
    }
    if (t == _i50cy468.ActivityType) {
      return _i50cy468.ActivityType.fromJson(data) as T;
    }
    if (t == _iyixppck.Comment) {
      return _iyixppck.Comment.fromJson(data) as T;
    }
    if (t == _iw81twtc.CommentAnchorKind) {
      return _iw81twtc.CommentAnchorKind.fromJson(data) as T;
    }
    if (t == _imlsyj2p.CommentEvent) {
      return _imlsyj2p.CommentEvent.fromJson(data) as T;
    }
    if (t == _ih1mb6x5.CommentEventKind) {
      return _ih1mb6x5.CommentEventKind.fromJson(data) as T;
    }
    if (t == _il5y6tzr.CommentFilter) {
      return _il5y6tzr.CommentFilter.fromJson(data) as T;
    }
    if (t == _ix3p7034.CommentSignal) {
      return _ix3p7034.CommentSignal.fromJson(data) as T;
    }
    if (t == _iowdswxe.CommentStatus) {
      return _iowdswxe.CommentStatus.fromJson(data) as T;
    }
    if (t == _i94wr3td.CommentSystemEvent) {
      return _i94wr3td.CommentSystemEvent.fromJson(data) as T;
    }
    if (t == _ijog60vm.CommentThread) {
      return _ijog60vm.CommentThread.fromJson(data) as T;
    }
    if (t == _i818olql.CommentThreadView) {
      return _i818olql.CommentThreadView.fromJson(data) as T;
    }
    if (t == _i4xrxro7.CommentView) {
      return _i4xrxro7.CommentView.fromJson(data) as T;
    }
    if (t == _ii98prcs.AccessRole) {
      return _ii98prcs.AccessRole.fromJson(data) as T;
    }
    if (t == _inb0isem.WonkyErrorCode) {
      return _inb0isem.WonkyErrorCode.fromJson(data) as T;
    }
    if (t == _igdswlrw.WonkyException) {
      return _igdswlrw.WonkyException.fromJson(data) as T;
    }
    if (t == _iktwt5zz.DriveChange) {
      return _iktwt5zz.DriveChange.fromJson(data) as T;
    }
    if (t == _ijoqbs82.DriveChangeKind) {
      return _ijoqbs82.DriveChangeKind.fromJson(data) as T;
    }
    if (t == _i0atxq9l.DriveChangeSignal) {
      return _i0atxq9l.DriveChangeSignal.fromJson(data) as T;
    }
    if (t == _inge8yy2.DriveItem) {
      return _inge8yy2.DriveItem.fromJson(data) as T;
    }
    if (t == _i8mh39wa.DriveItemKind) {
      return _i8mh39wa.DriveItemKind.fromJson(data) as T;
    }
    if (t == _i0g2m831.DriveItemUserState) {
      return _i0g2m831.DriveItemUserState.fromJson(data) as T;
    }
    if (t == _infxyf98.DriveItemView) {
      return _infxyf98.DriveItemView.fromJson(data) as T;
    }
    if (t == _ivypvw0m.DriveListFilter) {
      return _ivypvw0m.DriveListFilter.fromJson(data) as T;
    }
    if (t == _iavdhzsq.DriveListPage) {
      return _iavdhzsq.DriveListPage.fromJson(data) as T;
    }
    if (t == _if1dhg5z.DriveOwnerFilter) {
      return _if1dhg5z.DriveOwnerFilter.fromJson(data) as T;
    }
    if (t == _i6k3d1nc.DriveSearchFilters) {
      return _i6k3d1nc.DriveSearchFilters.fromJson(data) as T;
    }
    if (t == _iu13r4v2.DriveSort) {
      return _iu13r4v2.DriveSort.fromJson(data) as T;
    }
    if (t == _ix0g8yw4.DriveSortField) {
      return _ix0g8yw4.DriveSortField.fromJson(data) as T;
    }
    if (t == _ipww3kqy.DriveView) {
      return _ipww3kqy.DriveView.fromJson(data) as T;
    }
    if (t == _i2cmzvye.ImportOptions) {
      return _i2cmzvye.ImportOptions.fromJson(data) as T;
    }
    if (t == _i68yhxa0.ImportReportView) {
      return _i68yhxa0.ImportReportView.fromJson(data) as T;
    }
    if (t == _i48sm9f2.ImportWarningView) {
      return _i48sm9f2.ImportWarningView.fromJson(data) as T;
    }
    if (t == _i26hsnhw.StorageUsage) {
      return _i26hsnhw.StorageUsage.fromJson(data) as T;
    }
    if (t == _iiedu4vz.TemplateCategory) {
      return _iiedu4vz.TemplateCategory.fromJson(data) as T;
    }
    if (t == _i2ox7ta1.TemplateView) {
      return _i2ox7ta1.TemplateView.fromJson(data) as T;
    }
    if (t == _iv1sk0e8.FeedbackKind) {
      return _iv1sk0e8.FeedbackKind.fromJson(data) as T;
    }
    if (t == _iu565i0a.FeedbackReport) {
      return _iu565i0a.FeedbackReport.fromJson(data) as T;
    }
    if (t == _ilhpki98.FeedbackSubmission) {
      return _ilhpki98.FeedbackSubmission.fromJson(data) as T;
    }
    if (t == _irrzp8p9.FileUploadTicket) {
      return _irrzp8p9.FileUploadTicket.fromJson(data) as T;
    }
    if (t == _itzt3x6d.FileUrlView) {
      return _itzt3x6d.FileUrlView.fromJson(data) as T;
    }
    if (t == _im8eh74x.StoredFile) {
      return _im8eh74x.StoredFile.fromJson(data) as T;
    }
    if (t == _i45dmz4a.StoredFileKind) {
      return _i45dmz4a.StoredFileKind.fromJson(data) as T;
    }
    if (t == _ik7q11oy.StoredFileStatus) {
      return _ik7q11oy.StoredFileStatus.fromJson(data) as T;
    }
    if (t == _ivk6eyvx.FeatureFlags) {
      return _ivk6eyvx.FeatureFlags.fromJson(data) as T;
    }
    if (t == _ib575x0y.ProtocolInfo) {
      return _ib575x0y.ProtocolInfo.fromJson(data) as T;
    }
    if (t == _i28el0at.ServerLimits) {
      return _i28el0at.ServerLimits.fromJson(data) as T;
    }
    if (t == _iexg4yzt.NotificationEvent) {
      return _iexg4yzt.NotificationEvent.fromJson(data) as T;
    }
    if (t == _iqlnbbfp.NotificationKind) {
      return _iqlnbbfp.NotificationKind.fromJson(data) as T;
    }
    if (t == _i3r1eo8q.NotificationPage) {
      return _i3r1eo8q.NotificationPage.fromJson(data) as T;
    }
    if (t == _iqsxdr4a.NotificationSignal) {
      return _iqsxdr4a.NotificationSignal.fromJson(data) as T;
    }
    if (t == _izfzk9h3.NotificationView) {
      return _izfzk9h3.NotificationView.fromJson(data) as T;
    }
    if (t == _ik59hiyp.UserNotification) {
      return _ik59hiyp.UserNotification.fromJson(data) as T;
    }
    if (t == _iylgyc33.Participant) {
      return _iylgyc33.Participant.fromJson(data) as T;
    }
    if (t == _i7dp90q0.PresenceBusMessage) {
      return _i7dp90q0.PresenceBusMessage.fromJson(data) as T;
    }
    if (t == _i8r9afjv.PresenceFollowerCount) {
      return _i8r9afjv.PresenceFollowerCount.fromJson(data) as T;
    }
    if (t == _i8r9afjv.PresenceHints) {
      return _i8r9afjv.PresenceHints.fromJson(data) as T;
    }
    if (t == _i8r9afjv.PresenceJoined) {
      return _i8r9afjv.PresenceJoined.fromJson(data) as T;
    }
    if (t == _i8r9afjv.PresenceLeft) {
      return _i8r9afjv.PresenceLeft.fromJson(data) as T;
    }
    if (t == _i8r9afjv.PresenceNotice) {
      return _i8r9afjv.PresenceNotice.fromJson(data) as T;
    }
    if (t == _i8r9afjv.PresenceRoster) {
      return _i8r9afjv.PresenceRoster.fromJson(data) as T;
    }
    if (t == _i8r9afjv.PresenceUpdated) {
      return _i8r9afjv.PresenceUpdated.fromJson(data) as T;
    }
    if (t == _ik055xb9.PresenceState) {
      return _ik055xb9.PresenceState.fromJson(data) as T;
    }
    if (t == _isz2sju0.PresenceUpdate) {
      return _isz2sju0.PresenceUpdate.fromJson(data) as T;
    }
    if (t == _i8scn8dm.AccessRequest) {
      return _i8scn8dm.AccessRequest.fromJson(data) as T;
    }
    if (t == _i7trut12.AccessRequestOutcome) {
      return _i7trut12.AccessRequestOutcome.fromJson(data) as T;
    }
    if (t == _iimp60a4.AccessRequestView) {
      return _iimp60a4.AccessRequestView.fromJson(data) as T;
    }
    if (t == _iuzgacy4.DriveItemPermission) {
      return _iuzgacy4.DriveItemPermission.fromJson(data) as T;
    }
    if (t == _ikeljole.InviteResolution) {
      return _ikeljole.InviteResolution.fromJson(data) as T;
    }
    if (t == _ih3711er.ItemSharingSettings) {
      return _ih3711er.ItemSharingSettings.fromJson(data) as T;
    }
    if (t == _ijwxtu30.OwnershipTransfer) {
      return _ijwxtu30.OwnershipTransfer.fromJson(data) as T;
    }
    if (t == _iilpsf9g.OwnershipTransferView) {
      return _iilpsf9g.OwnershipTransferView.fromJson(data) as T;
    }
    if (t == _iead0ok9.PermissionView) {
      return _iead0ok9.PermissionView.fromJson(data) as T;
    }
    if (t == _it712lg1.ShareLink) {
      return _it712lg1.ShareLink.fromJson(data) as T;
    }
    if (t == _iw2xoohn.ShareLinkView) {
      return _iw2xoohn.ShareLinkView.fromJson(data) as T;
    }
    if (t == _itd24os1.SharingInfo) {
      return _itd24os1.SharingInfo.fromJson(data) as T;
    }
    if (t == _izha9j5m.AccessTokenView) {
      return _izha9j5m.AccessTokenView.fromJson(data) as T;
    }
    if (t == _iq4dupwy.AccountDeletionPreview) {
      return _iq4dupwy.AccountDeletionPreview.fromJson(data) as T;
    }
    if (t == _i6azdr3n.AppThemeMode) {
      return _i6azdr3n.AppThemeMode.fromJson(data) as T;
    }
    if (t == _iru4pv75.CreatedAccessToken) {
      return _iru4pv75.CreatedAccessToken.fromJson(data) as T;
    }
    if (t == _ijodrcyd.PersonalAccessToken) {
      return _ijodrcyd.PersonalAccessToken.fromJson(data) as T;
    }
    if (t == _i5lc4gt0.UiDensity) {
      return _i5lc4gt0.UiDensity.fromJson(data) as T;
    }
    if (t == _i501u5m5.UserPreferences) {
      return _i501u5m5.UserPreferences.fromJson(data) as T;
    }
    if (t == _id95rrz2.UserPreferencesPatch) {
      return _id95rrz2.UserPreferencesPatch.fromJson(data) as T;
    }
    if (t == _ihzl7wbq.UserProfile) {
      return _ihzl7wbq.UserProfile.fromJson(data) as T;
    }
    if (t == _iufqmqtc.UserProfileView) {
      return _iufqmqtc.UserProfileView.fromJson(data) as T;
    }
    if (t == _i6y7tspy.UserSummary) {
      return _i6y7tspy.UserSummary.fromJson(data) as T;
    }
    if (t == _i7jb115m.ItemVersion) {
      return _i7jb115m.ItemVersion.fromJson(data) as T;
    }
    if (t == _ibe5uno1.ItemVersionState) {
      return _ibe5uno1.ItemVersionState.fromJson(data) as T;
    }
    if (t == _ipbapjbz.ItemVersionView) {
      return _ipbapjbz.ItemVersionView.fromJson(data) as T;
    }
    if (t == _in0fdl1f.VersionKind) {
      return _in0fdl1f.VersionKind.fromJson(data) as T;
    }
    if (t == _in38zbga.VersionRestoreResult) {
      return _in38zbga.VersionRestoreResult.fromJson(data) as T;
    }
    if (t == _i5u6d6t4.VersionStorage) {
      return _i5u6d6t4.VersionStorage.fromJson(data) as T;
    }
    if (t == _ik5lpvx4.CellHistory) {
      return _ik5lpvx4.CellHistory.fromJson(data) as T;
    }
    if (t == _ij1xvs09.CellHistoryEntry) {
      return _ij1xvs09.CellHistoryEntry.fromJson(data) as T;
    }
    if (t == _i09xo3k8.CellHistoryPage) {
      return _i09xo3k8.CellHistoryPage.fromJson(data) as T;
    }
    if (t == _ilv3hlxr.RevertResult) {
      return _ilv3hlxr.RevertResult.fromJson(data) as T;
    }
    if (t == _ipqum05l.RevertSkip) {
      return _ipqum05l.RevertSkip.fromJson(data) as T;
    }
    if (t == _it4o4dd3.ServerChangeRecord) {
      return _it4o4dd3.ServerChangeRecord.fromJson(data) as T;
    }
    if (t == _iaehez21.SheetsActivitySummary) {
      return _iaehez21.SheetsActivitySummary.fromJson(data) as T;
    }
    if (t == _i5z6gq3n.SheetsChangeLogReceipt) {
      return _i5z6gq3n.SheetsChangeLogReceipt.fromJson(data) as T;
    }
    if (t == _i9yjzgjk.SheetsContributorStat) {
      return _i9yjzgjk.SheetsContributorStat.fromJson(data) as T;
    }
    if (t == _izigafhu.SheetsMergedSignal) {
      return _izigafhu.SheetsMergedSignal.fromJson(data) as T;
    }
    if (t == _iwl8v9t3.SheetsSnapshotIndex) {
      return _iwl8v9t3.SheetsSnapshotIndex.fromJson(data) as T;
    }
    if (t == _i9g7m0kd.SpaceReservation) {
      return _i9g7m0kd.SpaceReservation.fromJson(data) as T;
    }
    if (t == _izbczo40.SpaceStats) {
      return _izbczo40.SpaceStats.fromJson(data) as T;
    }
    if (t == _i1qxq8ae.SpaceSubscription) {
      return _i1qxq8ae.SpaceSubscription.fromJson(data) as T;
    }
    if (t == _i6dq35xo.SubscribeResult) {
      return _i6dq35xo.SubscribeResult.fromJson(data) as T;
    }
    if (t == _ic8hyldr.SubscriptionReason) {
      return _ic8hyldr.SubscriptionReason.fromJson(data) as T;
    }
    if (t == _icpkpcrn.DocAck) {
      return _icpkpcrn.DocAck.fromJson(data) as T;
    }
    if (t == _i8zfu67r.DocBusMessage) {
      return _i8zfu67r.DocBusMessage.fromJson(data) as T;
    }
    if (t == _imbts8if.DocCursorUpdate) {
      return _imbts8if.DocCursorUpdate.fromJson(data) as T;
    }
    if (t == _imbts8if.DocHashCheck) {
      return _imbts8if.DocHashCheck.fromJson(data) as T;
    }
    if (t == _imbts8if.DocPing) {
      return _imbts8if.DocPing.fromJson(data) as T;
    }
    if (t == _imbts8if.DocRequestOps) {
      return _imbts8if.DocRequestOps.fromJson(data) as T;
    }
    if (t == _imbts8if.DocSubmitOp) {
      return _imbts8if.DocSubmitOp.fromJson(data) as T;
    }
    if (t == _icpkpcrn.DocHashResult) {
      return _icpkpcrn.DocHashResult.fromJson(data) as T;
    }
    if (t == _icpkpcrn.DocInit) {
      return _icpkpcrn.DocInit.fromJson(data) as T;
    }
    if (t == _icpkpcrn.DocMetaChanged) {
      return _icpkpcrn.DocMetaChanged.fromJson(data) as T;
    }
    if (t == _icpkpcrn.DocOpRejected) {
      return _icpkpcrn.DocOpRejected.fromJson(data) as T;
    }
    if (t == _icpkpcrn.DocParticipantJoined) {
      return _icpkpcrn.DocParticipantJoined.fromJson(data) as T;
    }
    if (t == _icpkpcrn.DocParticipantLeft) {
      return _icpkpcrn.DocParticipantLeft.fromJson(data) as T;
    }
    if (t == _icpkpcrn.DocPong) {
      return _icpkpcrn.DocPong.fromJson(data) as T;
    }
    if (t == _icpkpcrn.DocRemoteCursor) {
      return _icpkpcrn.DocRemoteCursor.fromJson(data) as T;
    }
    if (t == _icpkpcrn.DocRemoteOp) {
      return _icpkpcrn.DocRemoteOp.fromJson(data) as T;
    }
    if (t == _icpkpcrn.DocRoleChanged) {
      return _icpkpcrn.DocRoleChanged.fromJson(data) as T;
    }
    if (t == _igqu3xcv.ConvertForInsertResult) {
      return _igqu3xcv.ConvertForInsertResult.fromJson(data) as T;
    }
    if (t == _i5srcd7q.DocRejectCode) {
      return _i5srcd7q.DocRejectCode.fromJson(data) as T;
    }
    if (t == _i4sx4pml.Document) {
      return _i4sx4pml.Document.fromJson(data) as T;
    }
    if (t == _ixppud51.DocumentImportReport) {
      return _ixppud51.DocumentImportReport.fromJson(data) as T;
    }
    if (t == _iu022vpf.DocumentInfo) {
      return _iu022vpf.DocumentInfo.fromJson(data) as T;
    }
    if (t == _ir38bcqq.DocumentMetaChange) {
      return _ir38bcqq.DocumentMetaChange.fromJson(data) as T;
    }
    if (t == _inkjv0lb.DocumentMetaPatch) {
      return _inkjv0lb.DocumentMetaPatch.fromJson(data) as T;
    }
    if (t == _icsyekcn.DocumentMetaView) {
      return _icsyekcn.DocumentMetaView.fromJson(data) as T;
    }
    if (t == _iufsprkx.DocumentOp) {
      return _iufsprkx.DocumentOp.fromJson(data) as T;
    }
    if (t == _igr6xq1c.DocumentOpKind) {
      return _igr6xq1c.DocumentOpKind.fromJson(data) as T;
    }
    if (t == _issmv319.DocumentOpView) {
      return _issmv319.DocumentOpView.fromJson(data) as T;
    }
    if (t == _i2cnn8i8.DocumentSnapshot) {
      return _i2cnn8i8.DocumentSnapshot.fromJson(data) as T;
    }
    if (t == _i0cy62lm.DocumentSnapshotView) {
      return _i0cy62lm.DocumentSnapshotView.fromJson(data) as T;
    }
    if (t == _is1ql5wp.ExportProgressEvent) {
      return _is1ql5wp.ExportProgressEvent.fromJson(data) as T;
    }
    if (t == _isdjhzgs.ExportProgressKind) {
      return _isdjhzgs.ExportProgressKind.fromJson(data) as T;
    }
    if (t == _if2sngze.ExportResultView) {
      return _if2sngze.ExportResultView.fromJson(data) as T;
    }
    if (t == _ittnhawp.ThemeConflictException) {
      return _ittnhawp.ThemeConflictException.fromJson(data) as T;
    }
    if (t == _ii88i7dv.WriteDiffAuthor) {
      return _ii88i7dv.WriteDiffAuthor.fromJson(data) as T;
    }
    if (t == _ig4xquf5.WriteDiffCache) {
      return _ig4xquf5.WriteDiffCache.fromJson(data) as T;
    }
    if (t == _idky93gt.WriteDiffView) {
      return _idky93gt.WriteDiffView.fromJson(data) as T;
    }
    if (t == _iynqrh33.WriteTheme) {
      return _iynqrh33.WriteTheme.fromJson(data) as T;
    }
    if (t == _i7pbwt05.WriteThemeRevision) {
      return _i7pbwt05.WriteThemeRevision.fromJson(data) as T;
    }
    if (t == _ick3mhj2.WriteThemeRevisionView) {
      return _ick3mhj2.WriteThemeRevisionView.fromJson(data) as T;
    }
    if (t == _ixbjd26z.WriteThemeView) {
      return _ixbjd26z.WriteThemeView.fromJson(data) as T;
    }
    if (t == _is9bkd9t.WriteVersionDocument) {
      return _is9bkd9t.WriteVersionDocument.fromJson(data) as T;
    }
    if (t == _is.getType<_iatdjl5p.ActivityEvent?>()) {
      return (data != null ? _iatdjl5p.ActivityEvent.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_isa7sjzq.ActivityEventView?>()) {
      return (data != null ? _isa7sjzq.ActivityEventView.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i50cy468.ActivityType?>()) {
      return (data != null ? _i50cy468.ActivityType.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_iyixppck.Comment?>()) {
      return (data != null ? _iyixppck.Comment.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_iw81twtc.CommentAnchorKind?>()) {
      return (data != null ? _iw81twtc.CommentAnchorKind.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_imlsyj2p.CommentEvent?>()) {
      return (data != null ? _imlsyj2p.CommentEvent.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ih1mb6x5.CommentEventKind?>()) {
      return (data != null ? _ih1mb6x5.CommentEventKind.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_il5y6tzr.CommentFilter?>()) {
      return (data != null ? _il5y6tzr.CommentFilter.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ix3p7034.CommentSignal?>()) {
      return (data != null ? _ix3p7034.CommentSignal.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_iowdswxe.CommentStatus?>()) {
      return (data != null ? _iowdswxe.CommentStatus.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i94wr3td.CommentSystemEvent?>()) {
      return (data != null ? _i94wr3td.CommentSystemEvent.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ijog60vm.CommentThread?>()) {
      return (data != null ? _ijog60vm.CommentThread.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i818olql.CommentThreadView?>()) {
      return (data != null ? _i818olql.CommentThreadView.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i4xrxro7.CommentView?>()) {
      return (data != null ? _i4xrxro7.CommentView.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ii98prcs.AccessRole?>()) {
      return (data != null ? _ii98prcs.AccessRole.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_inb0isem.WonkyErrorCode?>()) {
      return (data != null ? _inb0isem.WonkyErrorCode.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_igdswlrw.WonkyException?>()) {
      return (data != null ? _igdswlrw.WonkyException.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_iktwt5zz.DriveChange?>()) {
      return (data != null ? _iktwt5zz.DriveChange.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ijoqbs82.DriveChangeKind?>()) {
      return (data != null ? _ijoqbs82.DriveChangeKind.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i0atxq9l.DriveChangeSignal?>()) {
      return (data != null ? _i0atxq9l.DriveChangeSignal.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_inge8yy2.DriveItem?>()) {
      return (data != null ? _inge8yy2.DriveItem.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_i8mh39wa.DriveItemKind?>()) {
      return (data != null ? _i8mh39wa.DriveItemKind.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i0g2m831.DriveItemUserState?>()) {
      return (data != null ? _i0g2m831.DriveItemUserState.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_infxyf98.DriveItemView?>()) {
      return (data != null ? _infxyf98.DriveItemView.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ivypvw0m.DriveListFilter?>()) {
      return (data != null ? _ivypvw0m.DriveListFilter.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_iavdhzsq.DriveListPage?>()) {
      return (data != null ? _iavdhzsq.DriveListPage.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_if1dhg5z.DriveOwnerFilter?>()) {
      return (data != null ? _if1dhg5z.DriveOwnerFilter.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i6k3d1nc.DriveSearchFilters?>()) {
      return (data != null ? _i6k3d1nc.DriveSearchFilters.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_iu13r4v2.DriveSort?>()) {
      return (data != null ? _iu13r4v2.DriveSort.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ix0g8yw4.DriveSortField?>()) {
      return (data != null ? _ix0g8yw4.DriveSortField.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ipww3kqy.DriveView?>()) {
      return (data != null ? _ipww3kqy.DriveView.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_i2cmzvye.ImportOptions?>()) {
      return (data != null ? _i2cmzvye.ImportOptions.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i68yhxa0.ImportReportView?>()) {
      return (data != null ? _i68yhxa0.ImportReportView.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i48sm9f2.ImportWarningView?>()) {
      return (data != null ? _i48sm9f2.ImportWarningView.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i26hsnhw.StorageUsage?>()) {
      return (data != null ? _i26hsnhw.StorageUsage.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_iiedu4vz.TemplateCategory?>()) {
      return (data != null ? _iiedu4vz.TemplateCategory.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i2ox7ta1.TemplateView?>()) {
      return (data != null ? _i2ox7ta1.TemplateView.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_iv1sk0e8.FeedbackKind?>()) {
      return (data != null ? _iv1sk0e8.FeedbackKind.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_iu565i0a.FeedbackReport?>()) {
      return (data != null ? _iu565i0a.FeedbackReport.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ilhpki98.FeedbackSubmission?>()) {
      return (data != null ? _ilhpki98.FeedbackSubmission.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_irrzp8p9.FileUploadTicket?>()) {
      return (data != null ? _irrzp8p9.FileUploadTicket.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_itzt3x6d.FileUrlView?>()) {
      return (data != null ? _itzt3x6d.FileUrlView.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_im8eh74x.StoredFile?>()) {
      return (data != null ? _im8eh74x.StoredFile.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_i45dmz4a.StoredFileKind?>()) {
      return (data != null ? _i45dmz4a.StoredFileKind.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ik7q11oy.StoredFileStatus?>()) {
      return (data != null ? _ik7q11oy.StoredFileStatus.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ivk6eyvx.FeatureFlags?>()) {
      return (data != null ? _ivk6eyvx.FeatureFlags.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ib575x0y.ProtocolInfo?>()) {
      return (data != null ? _ib575x0y.ProtocolInfo.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_i28el0at.ServerLimits?>()) {
      return (data != null ? _i28el0at.ServerLimits.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_iexg4yzt.NotificationEvent?>()) {
      return (data != null ? _iexg4yzt.NotificationEvent.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_iqlnbbfp.NotificationKind?>()) {
      return (data != null ? _iqlnbbfp.NotificationKind.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i3r1eo8q.NotificationPage?>()) {
      return (data != null ? _i3r1eo8q.NotificationPage.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_iqsxdr4a.NotificationSignal?>()) {
      return (data != null ? _iqsxdr4a.NotificationSignal.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_izfzk9h3.NotificationView?>()) {
      return (data != null ? _izfzk9h3.NotificationView.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ik59hiyp.UserNotification?>()) {
      return (data != null ? _ik59hiyp.UserNotification.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_iylgyc33.Participant?>()) {
      return (data != null ? _iylgyc33.Participant.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_i7dp90q0.PresenceBusMessage?>()) {
      return (data != null ? _i7dp90q0.PresenceBusMessage.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i8r9afjv.PresenceFollowerCount?>()) {
      return (data != null
              ? _i8r9afjv.PresenceFollowerCount.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_i8r9afjv.PresenceHints?>()) {
      return (data != null ? _i8r9afjv.PresenceHints.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i8r9afjv.PresenceJoined?>()) {
      return (data != null ? _i8r9afjv.PresenceJoined.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i8r9afjv.PresenceLeft?>()) {
      return (data != null ? _i8r9afjv.PresenceLeft.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_i8r9afjv.PresenceNotice?>()) {
      return (data != null ? _i8r9afjv.PresenceNotice.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i8r9afjv.PresenceRoster?>()) {
      return (data != null ? _i8r9afjv.PresenceRoster.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i8r9afjv.PresenceUpdated?>()) {
      return (data != null ? _i8r9afjv.PresenceUpdated.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ik055xb9.PresenceState?>()) {
      return (data != null ? _ik055xb9.PresenceState.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_isz2sju0.PresenceUpdate?>()) {
      return (data != null ? _isz2sju0.PresenceUpdate.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i8scn8dm.AccessRequest?>()) {
      return (data != null ? _i8scn8dm.AccessRequest.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i7trut12.AccessRequestOutcome?>()) {
      return (data != null
              ? _i7trut12.AccessRequestOutcome.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_iimp60a4.AccessRequestView?>()) {
      return (data != null ? _iimp60a4.AccessRequestView.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_iuzgacy4.DriveItemPermission?>()) {
      return (data != null
              ? _iuzgacy4.DriveItemPermission.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_ikeljole.InviteResolution?>()) {
      return (data != null ? _ikeljole.InviteResolution.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ih3711er.ItemSharingSettings?>()) {
      return (data != null
              ? _ih3711er.ItemSharingSettings.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_ijwxtu30.OwnershipTransfer?>()) {
      return (data != null ? _ijwxtu30.OwnershipTransfer.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_iilpsf9g.OwnershipTransferView?>()) {
      return (data != null
              ? _iilpsf9g.OwnershipTransferView.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_iead0ok9.PermissionView?>()) {
      return (data != null ? _iead0ok9.PermissionView.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_it712lg1.ShareLink?>()) {
      return (data != null ? _it712lg1.ShareLink.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_iw2xoohn.ShareLinkView?>()) {
      return (data != null ? _iw2xoohn.ShareLinkView.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_itd24os1.SharingInfo?>()) {
      return (data != null ? _itd24os1.SharingInfo.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_izha9j5m.AccessTokenView?>()) {
      return (data != null ? _izha9j5m.AccessTokenView.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_iq4dupwy.AccountDeletionPreview?>()) {
      return (data != null
              ? _iq4dupwy.AccountDeletionPreview.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_i6azdr3n.AppThemeMode?>()) {
      return (data != null ? _i6azdr3n.AppThemeMode.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_iru4pv75.CreatedAccessToken?>()) {
      return (data != null ? _iru4pv75.CreatedAccessToken.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ijodrcyd.PersonalAccessToken?>()) {
      return (data != null
              ? _ijodrcyd.PersonalAccessToken.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_i5lc4gt0.UiDensity?>()) {
      return (data != null ? _i5lc4gt0.UiDensity.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_i501u5m5.UserPreferences?>()) {
      return (data != null ? _i501u5m5.UserPreferences.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_id95rrz2.UserPreferencesPatch?>()) {
      return (data != null
              ? _id95rrz2.UserPreferencesPatch.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_ihzl7wbq.UserProfile?>()) {
      return (data != null ? _ihzl7wbq.UserProfile.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_iufqmqtc.UserProfileView?>()) {
      return (data != null ? _iufqmqtc.UserProfileView.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i6y7tspy.UserSummary?>()) {
      return (data != null ? _i6y7tspy.UserSummary.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_i7jb115m.ItemVersion?>()) {
      return (data != null ? _i7jb115m.ItemVersion.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ibe5uno1.ItemVersionState?>()) {
      return (data != null ? _ibe5uno1.ItemVersionState.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ipbapjbz.ItemVersionView?>()) {
      return (data != null ? _ipbapjbz.ItemVersionView.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_in0fdl1f.VersionKind?>()) {
      return (data != null ? _in0fdl1f.VersionKind.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_in38zbga.VersionRestoreResult?>()) {
      return (data != null
              ? _in38zbga.VersionRestoreResult.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_i5u6d6t4.VersionStorage?>()) {
      return (data != null ? _i5u6d6t4.VersionStorage.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ik5lpvx4.CellHistory?>()) {
      return (data != null ? _ik5lpvx4.CellHistory.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ij1xvs09.CellHistoryEntry?>()) {
      return (data != null ? _ij1xvs09.CellHistoryEntry.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i09xo3k8.CellHistoryPage?>()) {
      return (data != null ? _i09xo3k8.CellHistoryPage.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ilv3hlxr.RevertResult?>()) {
      return (data != null ? _ilv3hlxr.RevertResult.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ipqum05l.RevertSkip?>()) {
      return (data != null ? _ipqum05l.RevertSkip.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_it4o4dd3.ServerChangeRecord?>()) {
      return (data != null ? _it4o4dd3.ServerChangeRecord.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_iaehez21.SheetsActivitySummary?>()) {
      return (data != null
              ? _iaehez21.SheetsActivitySummary.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_i5z6gq3n.SheetsChangeLogReceipt?>()) {
      return (data != null
              ? _i5z6gq3n.SheetsChangeLogReceipt.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_i9yjzgjk.SheetsContributorStat?>()) {
      return (data != null
              ? _i9yjzgjk.SheetsContributorStat.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_izigafhu.SheetsMergedSignal?>()) {
      return (data != null ? _izigafhu.SheetsMergedSignal.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_iwl8v9t3.SheetsSnapshotIndex?>()) {
      return (data != null
              ? _iwl8v9t3.SheetsSnapshotIndex.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_i9g7m0kd.SpaceReservation?>()) {
      return (data != null ? _i9g7m0kd.SpaceReservation.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_izbczo40.SpaceStats?>()) {
      return (data != null ? _izbczo40.SpaceStats.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_i1qxq8ae.SpaceSubscription?>()) {
      return (data != null ? _i1qxq8ae.SpaceSubscription.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i6dq35xo.SubscribeResult?>()) {
      return (data != null ? _i6dq35xo.SubscribeResult.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ic8hyldr.SubscriptionReason?>()) {
      return (data != null ? _ic8hyldr.SubscriptionReason.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_icpkpcrn.DocAck?>()) {
      return (data != null ? _icpkpcrn.DocAck.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_i8zfu67r.DocBusMessage?>()) {
      return (data != null ? _i8zfu67r.DocBusMessage.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_imbts8if.DocCursorUpdate?>()) {
      return (data != null ? _imbts8if.DocCursorUpdate.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_imbts8if.DocHashCheck?>()) {
      return (data != null ? _imbts8if.DocHashCheck.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_imbts8if.DocPing?>()) {
      return (data != null ? _imbts8if.DocPing.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_imbts8if.DocRequestOps?>()) {
      return (data != null ? _imbts8if.DocRequestOps.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_imbts8if.DocSubmitOp?>()) {
      return (data != null ? _imbts8if.DocSubmitOp.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_icpkpcrn.DocHashResult?>()) {
      return (data != null ? _icpkpcrn.DocHashResult.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_icpkpcrn.DocInit?>()) {
      return (data != null ? _icpkpcrn.DocInit.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_icpkpcrn.DocMetaChanged?>()) {
      return (data != null ? _icpkpcrn.DocMetaChanged.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_icpkpcrn.DocOpRejected?>()) {
      return (data != null ? _icpkpcrn.DocOpRejected.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_icpkpcrn.DocParticipantJoined?>()) {
      return (data != null
              ? _icpkpcrn.DocParticipantJoined.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_icpkpcrn.DocParticipantLeft?>()) {
      return (data != null ? _icpkpcrn.DocParticipantLeft.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_icpkpcrn.DocPong?>()) {
      return (data != null ? _icpkpcrn.DocPong.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_icpkpcrn.DocRemoteCursor?>()) {
      return (data != null ? _icpkpcrn.DocRemoteCursor.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_icpkpcrn.DocRemoteOp?>()) {
      return (data != null ? _icpkpcrn.DocRemoteOp.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_icpkpcrn.DocRoleChanged?>()) {
      return (data != null ? _icpkpcrn.DocRoleChanged.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_igqu3xcv.ConvertForInsertResult?>()) {
      return (data != null
              ? _igqu3xcv.ConvertForInsertResult.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_i5srcd7q.DocRejectCode?>()) {
      return (data != null ? _i5srcd7q.DocRejectCode.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i4sx4pml.Document?>()) {
      return (data != null ? _i4sx4pml.Document.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ixppud51.DocumentImportReport?>()) {
      return (data != null
              ? _ixppud51.DocumentImportReport.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_iu022vpf.DocumentInfo?>()) {
      return (data != null ? _iu022vpf.DocumentInfo.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ir38bcqq.DocumentMetaChange?>()) {
      return (data != null ? _ir38bcqq.DocumentMetaChange.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_inkjv0lb.DocumentMetaPatch?>()) {
      return (data != null ? _inkjv0lb.DocumentMetaPatch.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_icsyekcn.DocumentMetaView?>()) {
      return (data != null ? _icsyekcn.DocumentMetaView.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_iufsprkx.DocumentOp?>()) {
      return (data != null ? _iufsprkx.DocumentOp.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_igr6xq1c.DocumentOpKind?>()) {
      return (data != null ? _igr6xq1c.DocumentOpKind.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_issmv319.DocumentOpView?>()) {
      return (data != null ? _issmv319.DocumentOpView.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i2cnn8i8.DocumentSnapshot?>()) {
      return (data != null ? _i2cnn8i8.DocumentSnapshot.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i0cy62lm.DocumentSnapshotView?>()) {
      return (data != null
              ? _i0cy62lm.DocumentSnapshotView.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_is1ql5wp.ExportProgressEvent?>()) {
      return (data != null
              ? _is1ql5wp.ExportProgressEvent.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_isdjhzgs.ExportProgressKind?>()) {
      return (data != null ? _isdjhzgs.ExportProgressKind.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_if2sngze.ExportResultView?>()) {
      return (data != null ? _if2sngze.ExportResultView.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ittnhawp.ThemeConflictException?>()) {
      return (data != null
              ? _ittnhawp.ThemeConflictException.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_ii88i7dv.WriteDiffAuthor?>()) {
      return (data != null ? _ii88i7dv.WriteDiffAuthor.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ig4xquf5.WriteDiffCache?>()) {
      return (data != null ? _ig4xquf5.WriteDiffCache.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_idky93gt.WriteDiffView?>()) {
      return (data != null ? _idky93gt.WriteDiffView.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_iynqrh33.WriteTheme?>()) {
      return (data != null ? _iynqrh33.WriteTheme.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_i7pbwt05.WriteThemeRevision?>()) {
      return (data != null ? _i7pbwt05.WriteThemeRevision.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ick3mhj2.WriteThemeRevisionView?>()) {
      return (data != null
              ? _ick3mhj2.WriteThemeRevisionView.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_ixbjd26z.WriteThemeView?>()) {
      return (data != null ? _ixbjd26z.WriteThemeView.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_is9bkd9t.WriteVersionDocument?>()) {
      return (data != null
              ? _is9bkd9t.WriteVersionDocument.fromJson(data)
              : null)
          as T;
    }
    if (t == List<int>) {
      return (data as List).map((e) => deserialize<int>(e)).toList() as T;
    }
    if (t == List<_i4xrxro7.CommentView>) {
      return (data as List)
              .map((e) => deserialize<_i4xrxro7.CommentView>(e))
              .toList()
          as T;
    }
    if (t == List<_i6y7tspy.UserSummary>) {
      return (data as List)
              .map((e) => deserialize<_i6y7tspy.UserSummary>(e))
              .toList()
          as T;
    }
    if (t == Map<String, List<int>>) {
      return (data as Map).map(
            (k, v) =>
                MapEntry(deserialize<String>(k), deserialize<List<int>>(v)),
          )
          as T;
    }
    if (t == List<_i8mh39wa.DriveItemKind>) {
      return (data as List)
              .map((e) => deserialize<_i8mh39wa.DriveItemKind>(e))
              .toList()
          as T;
    }
    if (t == _is.getType<List<_i8mh39wa.DriveItemKind>?>()) {
      return (data != null
              ? (data as List)
                    .map((e) => deserialize<_i8mh39wa.DriveItemKind>(e))
                    .toList()
              : null)
          as T;
    }
    if (t == List<_infxyf98.DriveItemView>) {
      return (data as List)
              .map((e) => deserialize<_infxyf98.DriveItemView>(e))
              .toList()
          as T;
    }
    if (t == List<_i48sm9f2.ImportWarningView>) {
      return (data as List)
              .map((e) => deserialize<_i48sm9f2.ImportWarningView>(e))
              .toList()
          as T;
    }
    if (t == List<_izfzk9h3.NotificationView>) {
      return (data as List)
              .map((e) => deserialize<_izfzk9h3.NotificationView>(e))
              .toList()
          as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
    }
    if (t == _is.getType<List<String>?>()) {
      return (data != null
              ? (data as List).map((e) => deserialize<String>(e)).toList()
              : null)
          as T;
    }
    if (t == List<_iylgyc33.Participant>) {
      return (data as List)
              .map((e) => deserialize<_iylgyc33.Participant>(e))
              .toList()
          as T;
    }
    if (t == List<_iead0ok9.PermissionView>) {
      return (data as List)
              .map((e) => deserialize<_iead0ok9.PermissionView>(e))
              .toList()
          as T;
    }
    if (t == List<_iimp60a4.AccessRequestView>) {
      return (data as List)
              .map((e) => deserialize<_iimp60a4.AccessRequestView>(e))
              .toList()
          as T;
    }
    if (t == List<_ij1xvs09.CellHistoryEntry>) {
      return (data as List)
              .map((e) => deserialize<_ij1xvs09.CellHistoryEntry>(e))
              .toList()
          as T;
    }
    if (t == List<_ipqum05l.RevertSkip>) {
      return (data as List)
              .map((e) => deserialize<_ipqum05l.RevertSkip>(e))
              .toList()
          as T;
    }
    if (t == Map<String, Map<int, int>>) {
      return (data as Map).map(
            (k, v) =>
                MapEntry(deserialize<String>(k), deserialize<Map<int, int>>(v)),
          )
          as T;
    }
    if (t == Map<int, int>) {
      return Map.fromEntries(
            (data as List).map(
              (e) =>
                  MapEntry(deserialize<int>(e['k']), deserialize<int>(e['v'])),
            ),
          )
          as T;
    }
    if (t == List<_i9yjzgjk.SheetsContributorStat>) {
      return (data as List)
              .map((e) => deserialize<_i9yjzgjk.SheetsContributorStat>(e))
              .toList()
          as T;
    }
    if (t == Map<String, int>) {
      return (data as Map).map(
            (k, v) => MapEntry(deserialize<String>(k), deserialize<int>(v)),
          )
          as T;
    }
    if (t == List<_issmv319.DocumentOpView>) {
      return (data as List)
              .map((e) => deserialize<_issmv319.DocumentOpView>(e))
              .toList()
          as T;
    }
    if (t == _is.getType<List<_issmv319.DocumentOpView>?>()) {
      return (data != null
              ? (data as List)
                    .map((e) => deserialize<_issmv319.DocumentOpView>(e))
                    .toList()
              : null)
          as T;
    }
    if (t == _is.getType<List<_i48sm9f2.ImportWarningView>?>()) {
      return (data != null
              ? (data as List)
                    .map((e) => deserialize<_i48sm9f2.ImportWarningView>(e))
                    .toList()
              : null)
          as T;
    }
    if (t == List<_ii88i7dv.WriteDiffAuthor>) {
      return (data as List)
              .map((e) => deserialize<_ii88i7dv.WriteDiffAuthor>(e))
              .toList()
          as T;
    }
    final modules = dataClassName == null
        ? deserializationMetadata.modulesForType(t)
        : deserializationMetadata.modules;
    for (final module in modules) {
      try {
        return module.deserialize<T>(data, t);
      } on _is.DeserializationTypeNotFoundException catch (_) {}
    }

    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _iatdjl5p.ActivityEvent => 'ActivityEvent',
      _isa7sjzq.ActivityEventView => 'ActivityEventView',
      _i50cy468.ActivityType => 'ActivityType',
      _iyixppck.Comment => 'Comment',
      _iw81twtc.CommentAnchorKind => 'CommentAnchorKind',
      _imlsyj2p.CommentEvent => 'CommentEvent',
      _ih1mb6x5.CommentEventKind => 'CommentEventKind',
      _il5y6tzr.CommentFilter => 'CommentFilter',
      _ix3p7034.CommentSignal => 'CommentSignal',
      _iowdswxe.CommentStatus => 'CommentStatus',
      _i94wr3td.CommentSystemEvent => 'CommentSystemEvent',
      _ijog60vm.CommentThread => 'CommentThread',
      _i818olql.CommentThreadView => 'CommentThreadView',
      _i4xrxro7.CommentView => 'CommentView',
      _ii98prcs.AccessRole => 'AccessRole',
      _inb0isem.WonkyErrorCode => 'WonkyErrorCode',
      _igdswlrw.WonkyException => 'WonkyException',
      _iktwt5zz.DriveChange => 'DriveChange',
      _ijoqbs82.DriveChangeKind => 'DriveChangeKind',
      _i0atxq9l.DriveChangeSignal => 'DriveChangeSignal',
      _inge8yy2.DriveItem => 'DriveItem',
      _i8mh39wa.DriveItemKind => 'DriveItemKind',
      _i0g2m831.DriveItemUserState => 'DriveItemUserState',
      _infxyf98.DriveItemView => 'DriveItemView',
      _ivypvw0m.DriveListFilter => 'DriveListFilter',
      _iavdhzsq.DriveListPage => 'DriveListPage',
      _if1dhg5z.DriveOwnerFilter => 'DriveOwnerFilter',
      _i6k3d1nc.DriveSearchFilters => 'DriveSearchFilters',
      _iu13r4v2.DriveSort => 'DriveSort',
      _ix0g8yw4.DriveSortField => 'DriveSortField',
      _ipww3kqy.DriveView => 'DriveView',
      _i2cmzvye.ImportOptions => 'ImportOptions',
      _i68yhxa0.ImportReportView => 'ImportReportView',
      _i48sm9f2.ImportWarningView => 'ImportWarningView',
      _i26hsnhw.StorageUsage => 'StorageUsage',
      _iiedu4vz.TemplateCategory => 'TemplateCategory',
      _i2ox7ta1.TemplateView => 'TemplateView',
      _iv1sk0e8.FeedbackKind => 'FeedbackKind',
      _iu565i0a.FeedbackReport => 'FeedbackReport',
      _ilhpki98.FeedbackSubmission => 'FeedbackSubmission',
      _irrzp8p9.FileUploadTicket => 'FileUploadTicket',
      _itzt3x6d.FileUrlView => 'FileUrlView',
      _im8eh74x.StoredFile => 'StoredFile',
      _i45dmz4a.StoredFileKind => 'StoredFileKind',
      _ik7q11oy.StoredFileStatus => 'StoredFileStatus',
      _ivk6eyvx.FeatureFlags => 'FeatureFlags',
      _ib575x0y.ProtocolInfo => 'ProtocolInfo',
      _i28el0at.ServerLimits => 'ServerLimits',
      _iexg4yzt.NotificationEvent => 'NotificationEvent',
      _iqlnbbfp.NotificationKind => 'NotificationKind',
      _i3r1eo8q.NotificationPage => 'NotificationPage',
      _iqsxdr4a.NotificationSignal => 'NotificationSignal',
      _izfzk9h3.NotificationView => 'NotificationView',
      _ik59hiyp.UserNotification => 'UserNotification',
      _iylgyc33.Participant => 'Participant',
      _i7dp90q0.PresenceBusMessage => 'PresenceBusMessage',
      _i8r9afjv.PresenceFollowerCount => 'PresenceFollowerCount',
      _i8r9afjv.PresenceHints => 'PresenceHints',
      _i8r9afjv.PresenceJoined => 'PresenceJoined',
      _i8r9afjv.PresenceLeft => 'PresenceLeft',
      _i8r9afjv.PresenceNotice => 'PresenceNotice',
      _i8r9afjv.PresenceRoster => 'PresenceRoster',
      _i8r9afjv.PresenceUpdated => 'PresenceUpdated',
      _ik055xb9.PresenceState => 'PresenceState',
      _isz2sju0.PresenceUpdate => 'PresenceUpdate',
      _i8scn8dm.AccessRequest => 'AccessRequest',
      _i7trut12.AccessRequestOutcome => 'AccessRequestOutcome',
      _iimp60a4.AccessRequestView => 'AccessRequestView',
      _iuzgacy4.DriveItemPermission => 'DriveItemPermission',
      _ikeljole.InviteResolution => 'InviteResolution',
      _ih3711er.ItemSharingSettings => 'ItemSharingSettings',
      _ijwxtu30.OwnershipTransfer => 'OwnershipTransfer',
      _iilpsf9g.OwnershipTransferView => 'OwnershipTransferView',
      _iead0ok9.PermissionView => 'PermissionView',
      _it712lg1.ShareLink => 'ShareLink',
      _iw2xoohn.ShareLinkView => 'ShareLinkView',
      _itd24os1.SharingInfo => 'SharingInfo',
      _izha9j5m.AccessTokenView => 'AccessTokenView',
      _iq4dupwy.AccountDeletionPreview => 'AccountDeletionPreview',
      _i6azdr3n.AppThemeMode => 'AppThemeMode',
      _iru4pv75.CreatedAccessToken => 'CreatedAccessToken',
      _ijodrcyd.PersonalAccessToken => 'PersonalAccessToken',
      _i5lc4gt0.UiDensity => 'UiDensity',
      _i501u5m5.UserPreferences => 'UserPreferences',
      _id95rrz2.UserPreferencesPatch => 'UserPreferencesPatch',
      _ihzl7wbq.UserProfile => 'UserProfile',
      _iufqmqtc.UserProfileView => 'UserProfileView',
      _i6y7tspy.UserSummary => 'UserSummary',
      _i7jb115m.ItemVersion => 'ItemVersion',
      _ibe5uno1.ItemVersionState => 'ItemVersionState',
      _ipbapjbz.ItemVersionView => 'ItemVersionView',
      _in0fdl1f.VersionKind => 'VersionKind',
      _in38zbga.VersionRestoreResult => 'VersionRestoreResult',
      _i5u6d6t4.VersionStorage => 'VersionStorage',
      _ik5lpvx4.CellHistory => 'CellHistory',
      _ij1xvs09.CellHistoryEntry => 'CellHistoryEntry',
      _i09xo3k8.CellHistoryPage => 'CellHistoryPage',
      _ilv3hlxr.RevertResult => 'RevertResult',
      _ipqum05l.RevertSkip => 'RevertSkip',
      _it4o4dd3.ServerChangeRecord => 'ServerChangeRecord',
      _iaehez21.SheetsActivitySummary => 'SheetsActivitySummary',
      _i5z6gq3n.SheetsChangeLogReceipt => 'SheetsChangeLogReceipt',
      _i9yjzgjk.SheetsContributorStat => 'SheetsContributorStat',
      _izigafhu.SheetsMergedSignal => 'SheetsMergedSignal',
      _iwl8v9t3.SheetsSnapshotIndex => 'SheetsSnapshotIndex',
      _i9g7m0kd.SpaceReservation => 'SpaceReservation',
      _izbczo40.SpaceStats => 'SpaceStats',
      _i1qxq8ae.SpaceSubscription => 'SpaceSubscription',
      _i6dq35xo.SubscribeResult => 'SubscribeResult',
      _ic8hyldr.SubscriptionReason => 'SubscriptionReason',
      _icpkpcrn.DocAck => 'DocAck',
      _i8zfu67r.DocBusMessage => 'DocBusMessage',
      _imbts8if.DocCursorUpdate => 'DocCursorUpdate',
      _imbts8if.DocHashCheck => 'DocHashCheck',
      _imbts8if.DocPing => 'DocPing',
      _imbts8if.DocRequestOps => 'DocRequestOps',
      _imbts8if.DocSubmitOp => 'DocSubmitOp',
      _icpkpcrn.DocHashResult => 'DocHashResult',
      _icpkpcrn.DocInit => 'DocInit',
      _icpkpcrn.DocMetaChanged => 'DocMetaChanged',
      _icpkpcrn.DocOpRejected => 'DocOpRejected',
      _icpkpcrn.DocParticipantJoined => 'DocParticipantJoined',
      _icpkpcrn.DocParticipantLeft => 'DocParticipantLeft',
      _icpkpcrn.DocPong => 'DocPong',
      _icpkpcrn.DocRemoteCursor => 'DocRemoteCursor',
      _icpkpcrn.DocRemoteOp => 'DocRemoteOp',
      _icpkpcrn.DocRoleChanged => 'DocRoleChanged',
      _igqu3xcv.ConvertForInsertResult => 'ConvertForInsertResult',
      _i5srcd7q.DocRejectCode => 'DocRejectCode',
      _i4sx4pml.Document => 'Document',
      _ixppud51.DocumentImportReport => 'DocumentImportReport',
      _iu022vpf.DocumentInfo => 'DocumentInfo',
      _ir38bcqq.DocumentMetaChange => 'DocumentMetaChange',
      _inkjv0lb.DocumentMetaPatch => 'DocumentMetaPatch',
      _icsyekcn.DocumentMetaView => 'DocumentMetaView',
      _iufsprkx.DocumentOp => 'DocumentOp',
      _igr6xq1c.DocumentOpKind => 'DocumentOpKind',
      _issmv319.DocumentOpView => 'DocumentOpView',
      _i2cnn8i8.DocumentSnapshot => 'DocumentSnapshot',
      _i0cy62lm.DocumentSnapshotView => 'DocumentSnapshotView',
      _is1ql5wp.ExportProgressEvent => 'ExportProgressEvent',
      _isdjhzgs.ExportProgressKind => 'ExportProgressKind',
      _if2sngze.ExportResultView => 'ExportResultView',
      _ittnhawp.ThemeConflictException => 'ThemeConflictException',
      _ii88i7dv.WriteDiffAuthor => 'WriteDiffAuthor',
      _ig4xquf5.WriteDiffCache => 'WriteDiffCache',
      _idky93gt.WriteDiffView => 'WriteDiffView',
      _iynqrh33.WriteTheme => 'WriteTheme',
      _i7pbwt05.WriteThemeRevision => 'WriteThemeRevision',
      _ick3mhj2.WriteThemeRevisionView => 'WriteThemeRevisionView',
      _ixbjd26z.WriteThemeView => 'WriteThemeView',
      _is9bkd9t.WriteVersionDocument => 'WriteVersionDocument',
      _ => null,
    };
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;

    if (data is Map<String, dynamic> && data['__className__'] is String) {
      return (data['__className__'] as String).replaceFirst('wonky.', '');
    }

    switch (data) {
      case _iatdjl5p.ActivityEvent():
        return 'ActivityEvent';
      case _isa7sjzq.ActivityEventView():
        return 'ActivityEventView';
      case _i50cy468.ActivityType():
        return 'ActivityType';
      case _iyixppck.Comment():
        return 'Comment';
      case _iw81twtc.CommentAnchorKind():
        return 'CommentAnchorKind';
      case _imlsyj2p.CommentEvent():
        return 'CommentEvent';
      case _ih1mb6x5.CommentEventKind():
        return 'CommentEventKind';
      case _il5y6tzr.CommentFilter():
        return 'CommentFilter';
      case _ix3p7034.CommentSignal():
        return 'CommentSignal';
      case _iowdswxe.CommentStatus():
        return 'CommentStatus';
      case _i94wr3td.CommentSystemEvent():
        return 'CommentSystemEvent';
      case _ijog60vm.CommentThread():
        return 'CommentThread';
      case _i818olql.CommentThreadView():
        return 'CommentThreadView';
      case _i4xrxro7.CommentView():
        return 'CommentView';
      case _ii98prcs.AccessRole():
        return 'AccessRole';
      case _inb0isem.WonkyErrorCode():
        return 'WonkyErrorCode';
      case _igdswlrw.WonkyException():
        return 'WonkyException';
      case _iktwt5zz.DriveChange():
        return 'DriveChange';
      case _ijoqbs82.DriveChangeKind():
        return 'DriveChangeKind';
      case _i0atxq9l.DriveChangeSignal():
        return 'DriveChangeSignal';
      case _inge8yy2.DriveItem():
        return 'DriveItem';
      case _i8mh39wa.DriveItemKind():
        return 'DriveItemKind';
      case _i0g2m831.DriveItemUserState():
        return 'DriveItemUserState';
      case _infxyf98.DriveItemView():
        return 'DriveItemView';
      case _ivypvw0m.DriveListFilter():
        return 'DriveListFilter';
      case _iavdhzsq.DriveListPage():
        return 'DriveListPage';
      case _if1dhg5z.DriveOwnerFilter():
        return 'DriveOwnerFilter';
      case _i6k3d1nc.DriveSearchFilters():
        return 'DriveSearchFilters';
      case _iu13r4v2.DriveSort():
        return 'DriveSort';
      case _ix0g8yw4.DriveSortField():
        return 'DriveSortField';
      case _ipww3kqy.DriveView():
        return 'DriveView';
      case _i2cmzvye.ImportOptions():
        return 'ImportOptions';
      case _i68yhxa0.ImportReportView():
        return 'ImportReportView';
      case _i48sm9f2.ImportWarningView():
        return 'ImportWarningView';
      case _i26hsnhw.StorageUsage():
        return 'StorageUsage';
      case _iiedu4vz.TemplateCategory():
        return 'TemplateCategory';
      case _i2ox7ta1.TemplateView():
        return 'TemplateView';
      case _iv1sk0e8.FeedbackKind():
        return 'FeedbackKind';
      case _iu565i0a.FeedbackReport():
        return 'FeedbackReport';
      case _ilhpki98.FeedbackSubmission():
        return 'FeedbackSubmission';
      case _irrzp8p9.FileUploadTicket():
        return 'FileUploadTicket';
      case _itzt3x6d.FileUrlView():
        return 'FileUrlView';
      case _im8eh74x.StoredFile():
        return 'StoredFile';
      case _i45dmz4a.StoredFileKind():
        return 'StoredFileKind';
      case _ik7q11oy.StoredFileStatus():
        return 'StoredFileStatus';
      case _ivk6eyvx.FeatureFlags():
        return 'FeatureFlags';
      case _ib575x0y.ProtocolInfo():
        return 'ProtocolInfo';
      case _i28el0at.ServerLimits():
        return 'ServerLimits';
      case _iexg4yzt.NotificationEvent():
        return 'NotificationEvent';
      case _iqlnbbfp.NotificationKind():
        return 'NotificationKind';
      case _i3r1eo8q.NotificationPage():
        return 'NotificationPage';
      case _iqsxdr4a.NotificationSignal():
        return 'NotificationSignal';
      case _izfzk9h3.NotificationView():
        return 'NotificationView';
      case _ik59hiyp.UserNotification():
        return 'UserNotification';
      case _iylgyc33.Participant():
        return 'Participant';
      case _i7dp90q0.PresenceBusMessage():
        return 'PresenceBusMessage';
      case _i8r9afjv.PresenceFollowerCount():
        return 'PresenceFollowerCount';
      case _i8r9afjv.PresenceHints():
        return 'PresenceHints';
      case _i8r9afjv.PresenceJoined():
        return 'PresenceJoined';
      case _i8r9afjv.PresenceLeft():
        return 'PresenceLeft';
      case _i8r9afjv.PresenceNotice():
        return 'PresenceNotice';
      case _i8r9afjv.PresenceRoster():
        return 'PresenceRoster';
      case _i8r9afjv.PresenceUpdated():
        return 'PresenceUpdated';
      case _ik055xb9.PresenceState():
        return 'PresenceState';
      case _isz2sju0.PresenceUpdate():
        return 'PresenceUpdate';
      case _i8scn8dm.AccessRequest():
        return 'AccessRequest';
      case _i7trut12.AccessRequestOutcome():
        return 'AccessRequestOutcome';
      case _iimp60a4.AccessRequestView():
        return 'AccessRequestView';
      case _iuzgacy4.DriveItemPermission():
        return 'DriveItemPermission';
      case _ikeljole.InviteResolution():
        return 'InviteResolution';
      case _ih3711er.ItemSharingSettings():
        return 'ItemSharingSettings';
      case _ijwxtu30.OwnershipTransfer():
        return 'OwnershipTransfer';
      case _iilpsf9g.OwnershipTransferView():
        return 'OwnershipTransferView';
      case _iead0ok9.PermissionView():
        return 'PermissionView';
      case _it712lg1.ShareLink():
        return 'ShareLink';
      case _iw2xoohn.ShareLinkView():
        return 'ShareLinkView';
      case _itd24os1.SharingInfo():
        return 'SharingInfo';
      case _izha9j5m.AccessTokenView():
        return 'AccessTokenView';
      case _iq4dupwy.AccountDeletionPreview():
        return 'AccountDeletionPreview';
      case _i6azdr3n.AppThemeMode():
        return 'AppThemeMode';
      case _iru4pv75.CreatedAccessToken():
        return 'CreatedAccessToken';
      case _ijodrcyd.PersonalAccessToken():
        return 'PersonalAccessToken';
      case _i5lc4gt0.UiDensity():
        return 'UiDensity';
      case _i501u5m5.UserPreferences():
        return 'UserPreferences';
      case _id95rrz2.UserPreferencesPatch():
        return 'UserPreferencesPatch';
      case _ihzl7wbq.UserProfile():
        return 'UserProfile';
      case _iufqmqtc.UserProfileView():
        return 'UserProfileView';
      case _i6y7tspy.UserSummary():
        return 'UserSummary';
      case _i7jb115m.ItemVersion():
        return 'ItemVersion';
      case _ibe5uno1.ItemVersionState():
        return 'ItemVersionState';
      case _ipbapjbz.ItemVersionView():
        return 'ItemVersionView';
      case _in0fdl1f.VersionKind():
        return 'VersionKind';
      case _in38zbga.VersionRestoreResult():
        return 'VersionRestoreResult';
      case _i5u6d6t4.VersionStorage():
        return 'VersionStorage';
      case _ik5lpvx4.CellHistory():
        return 'CellHistory';
      case _ij1xvs09.CellHistoryEntry():
        return 'CellHistoryEntry';
      case _i09xo3k8.CellHistoryPage():
        return 'CellHistoryPage';
      case _ilv3hlxr.RevertResult():
        return 'RevertResult';
      case _ipqum05l.RevertSkip():
        return 'RevertSkip';
      case _it4o4dd3.ServerChangeRecord():
        return 'ServerChangeRecord';
      case _iaehez21.SheetsActivitySummary():
        return 'SheetsActivitySummary';
      case _i5z6gq3n.SheetsChangeLogReceipt():
        return 'SheetsChangeLogReceipt';
      case _i9yjzgjk.SheetsContributorStat():
        return 'SheetsContributorStat';
      case _izigafhu.SheetsMergedSignal():
        return 'SheetsMergedSignal';
      case _iwl8v9t3.SheetsSnapshotIndex():
        return 'SheetsSnapshotIndex';
      case _i9g7m0kd.SpaceReservation():
        return 'SpaceReservation';
      case _izbczo40.SpaceStats():
        return 'SpaceStats';
      case _i1qxq8ae.SpaceSubscription():
        return 'SpaceSubscription';
      case _i6dq35xo.SubscribeResult():
        return 'SubscribeResult';
      case _ic8hyldr.SubscriptionReason():
        return 'SubscriptionReason';
      case _icpkpcrn.DocAck():
        return 'DocAck';
      case _i8zfu67r.DocBusMessage():
        return 'DocBusMessage';
      case _imbts8if.DocCursorUpdate():
        return 'DocCursorUpdate';
      case _imbts8if.DocHashCheck():
        return 'DocHashCheck';
      case _imbts8if.DocPing():
        return 'DocPing';
      case _imbts8if.DocRequestOps():
        return 'DocRequestOps';
      case _imbts8if.DocSubmitOp():
        return 'DocSubmitOp';
      case _icpkpcrn.DocHashResult():
        return 'DocHashResult';
      case _icpkpcrn.DocInit():
        return 'DocInit';
      case _icpkpcrn.DocMetaChanged():
        return 'DocMetaChanged';
      case _icpkpcrn.DocOpRejected():
        return 'DocOpRejected';
      case _icpkpcrn.DocParticipantJoined():
        return 'DocParticipantJoined';
      case _icpkpcrn.DocParticipantLeft():
        return 'DocParticipantLeft';
      case _icpkpcrn.DocPong():
        return 'DocPong';
      case _icpkpcrn.DocRemoteCursor():
        return 'DocRemoteCursor';
      case _icpkpcrn.DocRemoteOp():
        return 'DocRemoteOp';
      case _icpkpcrn.DocRoleChanged():
        return 'DocRoleChanged';
      case _igqu3xcv.ConvertForInsertResult():
        return 'ConvertForInsertResult';
      case _i5srcd7q.DocRejectCode():
        return 'DocRejectCode';
      case _i4sx4pml.Document():
        return 'Document';
      case _ixppud51.DocumentImportReport():
        return 'DocumentImportReport';
      case _iu022vpf.DocumentInfo():
        return 'DocumentInfo';
      case _ir38bcqq.DocumentMetaChange():
        return 'DocumentMetaChange';
      case _inkjv0lb.DocumentMetaPatch():
        return 'DocumentMetaPatch';
      case _icsyekcn.DocumentMetaView():
        return 'DocumentMetaView';
      case _iufsprkx.DocumentOp():
        return 'DocumentOp';
      case _igr6xq1c.DocumentOpKind():
        return 'DocumentOpKind';
      case _issmv319.DocumentOpView():
        return 'DocumentOpView';
      case _i2cnn8i8.DocumentSnapshot():
        return 'DocumentSnapshot';
      case _i0cy62lm.DocumentSnapshotView():
        return 'DocumentSnapshotView';
      case _is1ql5wp.ExportProgressEvent():
        return 'ExportProgressEvent';
      case _isdjhzgs.ExportProgressKind():
        return 'ExportProgressKind';
      case _if2sngze.ExportResultView():
        return 'ExportResultView';
      case _ittnhawp.ThemeConflictException():
        return 'ThemeConflictException';
      case _ii88i7dv.WriteDiffAuthor():
        return 'WriteDiffAuthor';
      case _ig4xquf5.WriteDiffCache():
        return 'WriteDiffCache';
      case _idky93gt.WriteDiffView():
        return 'WriteDiffView';
      case _iynqrh33.WriteTheme():
        return 'WriteTheme';
      case _i7pbwt05.WriteThemeRevision():
        return 'WriteThemeRevision';
      case _ick3mhj2.WriteThemeRevisionView():
        return 'WriteThemeRevisionView';
      case _ixbjd26z.WriteThemeView():
        return 'WriteThemeView';
      case _is9bkd9t.WriteVersionDocument():
        return 'WriteVersionDocument';
    }
    className = _iais.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.')
          ? className
          : 'serverpod_auth_idp.$className';
    }
    className = _izehhkf5.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.')
          ? className
          : 'serverpod_offline_sync.$className';
    }
    className = _iacs.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.')
          ? className
          : 'serverpod_auth_core.$className';
    }
    className = _i810rwvy.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.')
          ? className
          : 'wonky_sync_models.$className';
    }
    className = _isp.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.') ? className : 'serverpod.$className';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'ActivityEvent') {
      return deserialize<_iatdjl5p.ActivityEvent>(data['data']);
    }
    if (dataClassName == 'ActivityEventView') {
      return deserialize<_isa7sjzq.ActivityEventView>(data['data']);
    }
    if (dataClassName == 'ActivityType') {
      return deserialize<_i50cy468.ActivityType>(data['data']);
    }
    if (dataClassName == 'Comment') {
      return deserialize<_iyixppck.Comment>(data['data']);
    }
    if (dataClassName == 'CommentAnchorKind') {
      return deserialize<_iw81twtc.CommentAnchorKind>(data['data']);
    }
    if (dataClassName == 'CommentEvent') {
      return deserialize<_imlsyj2p.CommentEvent>(data['data']);
    }
    if (dataClassName == 'CommentEventKind') {
      return deserialize<_ih1mb6x5.CommentEventKind>(data['data']);
    }
    if (dataClassName == 'CommentFilter') {
      return deserialize<_il5y6tzr.CommentFilter>(data['data']);
    }
    if (dataClassName == 'CommentSignal') {
      return deserialize<_ix3p7034.CommentSignal>(data['data']);
    }
    if (dataClassName == 'CommentStatus') {
      return deserialize<_iowdswxe.CommentStatus>(data['data']);
    }
    if (dataClassName == 'CommentSystemEvent') {
      return deserialize<_i94wr3td.CommentSystemEvent>(data['data']);
    }
    if (dataClassName == 'CommentThread') {
      return deserialize<_ijog60vm.CommentThread>(data['data']);
    }
    if (dataClassName == 'CommentThreadView') {
      return deserialize<_i818olql.CommentThreadView>(data['data']);
    }
    if (dataClassName == 'CommentView') {
      return deserialize<_i4xrxro7.CommentView>(data['data']);
    }
    if (dataClassName == 'AccessRole') {
      return deserialize<_ii98prcs.AccessRole>(data['data']);
    }
    if (dataClassName == 'WonkyErrorCode') {
      return deserialize<_inb0isem.WonkyErrorCode>(data['data']);
    }
    if (dataClassName == 'WonkyException') {
      return deserialize<_igdswlrw.WonkyException>(data['data']);
    }
    if (dataClassName == 'DriveChange') {
      return deserialize<_iktwt5zz.DriveChange>(data['data']);
    }
    if (dataClassName == 'DriveChangeKind') {
      return deserialize<_ijoqbs82.DriveChangeKind>(data['data']);
    }
    if (dataClassName == 'DriveChangeSignal') {
      return deserialize<_i0atxq9l.DriveChangeSignal>(data['data']);
    }
    if (dataClassName == 'DriveItem') {
      return deserialize<_inge8yy2.DriveItem>(data['data']);
    }
    if (dataClassName == 'DriveItemKind') {
      return deserialize<_i8mh39wa.DriveItemKind>(data['data']);
    }
    if (dataClassName == 'DriveItemUserState') {
      return deserialize<_i0g2m831.DriveItemUserState>(data['data']);
    }
    if (dataClassName == 'DriveItemView') {
      return deserialize<_infxyf98.DriveItemView>(data['data']);
    }
    if (dataClassName == 'DriveListFilter') {
      return deserialize<_ivypvw0m.DriveListFilter>(data['data']);
    }
    if (dataClassName == 'DriveListPage') {
      return deserialize<_iavdhzsq.DriveListPage>(data['data']);
    }
    if (dataClassName == 'DriveOwnerFilter') {
      return deserialize<_if1dhg5z.DriveOwnerFilter>(data['data']);
    }
    if (dataClassName == 'DriveSearchFilters') {
      return deserialize<_i6k3d1nc.DriveSearchFilters>(data['data']);
    }
    if (dataClassName == 'DriveSort') {
      return deserialize<_iu13r4v2.DriveSort>(data['data']);
    }
    if (dataClassName == 'DriveSortField') {
      return deserialize<_ix0g8yw4.DriveSortField>(data['data']);
    }
    if (dataClassName == 'DriveView') {
      return deserialize<_ipww3kqy.DriveView>(data['data']);
    }
    if (dataClassName == 'ImportOptions') {
      return deserialize<_i2cmzvye.ImportOptions>(data['data']);
    }
    if (dataClassName == 'ImportReportView') {
      return deserialize<_i68yhxa0.ImportReportView>(data['data']);
    }
    if (dataClassName == 'ImportWarningView') {
      return deserialize<_i48sm9f2.ImportWarningView>(data['data']);
    }
    if (dataClassName == 'StorageUsage') {
      return deserialize<_i26hsnhw.StorageUsage>(data['data']);
    }
    if (dataClassName == 'TemplateCategory') {
      return deserialize<_iiedu4vz.TemplateCategory>(data['data']);
    }
    if (dataClassName == 'TemplateView') {
      return deserialize<_i2ox7ta1.TemplateView>(data['data']);
    }
    if (dataClassName == 'FeedbackKind') {
      return deserialize<_iv1sk0e8.FeedbackKind>(data['data']);
    }
    if (dataClassName == 'FeedbackReport') {
      return deserialize<_iu565i0a.FeedbackReport>(data['data']);
    }
    if (dataClassName == 'FeedbackSubmission') {
      return deserialize<_ilhpki98.FeedbackSubmission>(data['data']);
    }
    if (dataClassName == 'FileUploadTicket') {
      return deserialize<_irrzp8p9.FileUploadTicket>(data['data']);
    }
    if (dataClassName == 'FileUrlView') {
      return deserialize<_itzt3x6d.FileUrlView>(data['data']);
    }
    if (dataClassName == 'StoredFile') {
      return deserialize<_im8eh74x.StoredFile>(data['data']);
    }
    if (dataClassName == 'StoredFileKind') {
      return deserialize<_i45dmz4a.StoredFileKind>(data['data']);
    }
    if (dataClassName == 'StoredFileStatus') {
      return deserialize<_ik7q11oy.StoredFileStatus>(data['data']);
    }
    if (dataClassName == 'FeatureFlags') {
      return deserialize<_ivk6eyvx.FeatureFlags>(data['data']);
    }
    if (dataClassName == 'ProtocolInfo') {
      return deserialize<_ib575x0y.ProtocolInfo>(data['data']);
    }
    if (dataClassName == 'ServerLimits') {
      return deserialize<_i28el0at.ServerLimits>(data['data']);
    }
    if (dataClassName == 'NotificationEvent') {
      return deserialize<_iexg4yzt.NotificationEvent>(data['data']);
    }
    if (dataClassName == 'NotificationKind') {
      return deserialize<_iqlnbbfp.NotificationKind>(data['data']);
    }
    if (dataClassName == 'NotificationPage') {
      return deserialize<_i3r1eo8q.NotificationPage>(data['data']);
    }
    if (dataClassName == 'NotificationSignal') {
      return deserialize<_iqsxdr4a.NotificationSignal>(data['data']);
    }
    if (dataClassName == 'NotificationView') {
      return deserialize<_izfzk9h3.NotificationView>(data['data']);
    }
    if (dataClassName == 'UserNotification') {
      return deserialize<_ik59hiyp.UserNotification>(data['data']);
    }
    if (dataClassName == 'Participant') {
      return deserialize<_iylgyc33.Participant>(data['data']);
    }
    if (dataClassName == 'PresenceBusMessage') {
      return deserialize<_i7dp90q0.PresenceBusMessage>(data['data']);
    }
    if (dataClassName == 'PresenceFollowerCount') {
      return deserialize<_i8r9afjv.PresenceFollowerCount>(data['data']);
    }
    if (dataClassName == 'PresenceHints') {
      return deserialize<_i8r9afjv.PresenceHints>(data['data']);
    }
    if (dataClassName == 'PresenceJoined') {
      return deserialize<_i8r9afjv.PresenceJoined>(data['data']);
    }
    if (dataClassName == 'PresenceLeft') {
      return deserialize<_i8r9afjv.PresenceLeft>(data['data']);
    }
    if (dataClassName == 'PresenceNotice') {
      return deserialize<_i8r9afjv.PresenceNotice>(data['data']);
    }
    if (dataClassName == 'PresenceRoster') {
      return deserialize<_i8r9afjv.PresenceRoster>(data['data']);
    }
    if (dataClassName == 'PresenceUpdated') {
      return deserialize<_i8r9afjv.PresenceUpdated>(data['data']);
    }
    if (dataClassName == 'PresenceState') {
      return deserialize<_ik055xb9.PresenceState>(data['data']);
    }
    if (dataClassName == 'PresenceUpdate') {
      return deserialize<_isz2sju0.PresenceUpdate>(data['data']);
    }
    if (dataClassName == 'AccessRequest') {
      return deserialize<_i8scn8dm.AccessRequest>(data['data']);
    }
    if (dataClassName == 'AccessRequestOutcome') {
      return deserialize<_i7trut12.AccessRequestOutcome>(data['data']);
    }
    if (dataClassName == 'AccessRequestView') {
      return deserialize<_iimp60a4.AccessRequestView>(data['data']);
    }
    if (dataClassName == 'DriveItemPermission') {
      return deserialize<_iuzgacy4.DriveItemPermission>(data['data']);
    }
    if (dataClassName == 'InviteResolution') {
      return deserialize<_ikeljole.InviteResolution>(data['data']);
    }
    if (dataClassName == 'ItemSharingSettings') {
      return deserialize<_ih3711er.ItemSharingSettings>(data['data']);
    }
    if (dataClassName == 'OwnershipTransfer') {
      return deserialize<_ijwxtu30.OwnershipTransfer>(data['data']);
    }
    if (dataClassName == 'OwnershipTransferView') {
      return deserialize<_iilpsf9g.OwnershipTransferView>(data['data']);
    }
    if (dataClassName == 'PermissionView') {
      return deserialize<_iead0ok9.PermissionView>(data['data']);
    }
    if (dataClassName == 'ShareLink') {
      return deserialize<_it712lg1.ShareLink>(data['data']);
    }
    if (dataClassName == 'ShareLinkView') {
      return deserialize<_iw2xoohn.ShareLinkView>(data['data']);
    }
    if (dataClassName == 'SharingInfo') {
      return deserialize<_itd24os1.SharingInfo>(data['data']);
    }
    if (dataClassName == 'AccessTokenView') {
      return deserialize<_izha9j5m.AccessTokenView>(data['data']);
    }
    if (dataClassName == 'AccountDeletionPreview') {
      return deserialize<_iq4dupwy.AccountDeletionPreview>(data['data']);
    }
    if (dataClassName == 'AppThemeMode') {
      return deserialize<_i6azdr3n.AppThemeMode>(data['data']);
    }
    if (dataClassName == 'CreatedAccessToken') {
      return deserialize<_iru4pv75.CreatedAccessToken>(data['data']);
    }
    if (dataClassName == 'PersonalAccessToken') {
      return deserialize<_ijodrcyd.PersonalAccessToken>(data['data']);
    }
    if (dataClassName == 'UiDensity') {
      return deserialize<_i5lc4gt0.UiDensity>(data['data']);
    }
    if (dataClassName == 'UserPreferences') {
      return deserialize<_i501u5m5.UserPreferences>(data['data']);
    }
    if (dataClassName == 'UserPreferencesPatch') {
      return deserialize<_id95rrz2.UserPreferencesPatch>(data['data']);
    }
    if (dataClassName == 'UserProfile') {
      return deserialize<_ihzl7wbq.UserProfile>(data['data']);
    }
    if (dataClassName == 'UserProfileView') {
      return deserialize<_iufqmqtc.UserProfileView>(data['data']);
    }
    if (dataClassName == 'UserSummary') {
      return deserialize<_i6y7tspy.UserSummary>(data['data']);
    }
    if (dataClassName == 'ItemVersion') {
      return deserialize<_i7jb115m.ItemVersion>(data['data']);
    }
    if (dataClassName == 'ItemVersionState') {
      return deserialize<_ibe5uno1.ItemVersionState>(data['data']);
    }
    if (dataClassName == 'ItemVersionView') {
      return deserialize<_ipbapjbz.ItemVersionView>(data['data']);
    }
    if (dataClassName == 'VersionKind') {
      return deserialize<_in0fdl1f.VersionKind>(data['data']);
    }
    if (dataClassName == 'VersionRestoreResult') {
      return deserialize<_in38zbga.VersionRestoreResult>(data['data']);
    }
    if (dataClassName == 'VersionStorage') {
      return deserialize<_i5u6d6t4.VersionStorage>(data['data']);
    }
    if (dataClassName == 'CellHistory') {
      return deserialize<_ik5lpvx4.CellHistory>(data['data']);
    }
    if (dataClassName == 'CellHistoryEntry') {
      return deserialize<_ij1xvs09.CellHistoryEntry>(data['data']);
    }
    if (dataClassName == 'CellHistoryPage') {
      return deserialize<_i09xo3k8.CellHistoryPage>(data['data']);
    }
    if (dataClassName == 'RevertResult') {
      return deserialize<_ilv3hlxr.RevertResult>(data['data']);
    }
    if (dataClassName == 'RevertSkip') {
      return deserialize<_ipqum05l.RevertSkip>(data['data']);
    }
    if (dataClassName == 'ServerChangeRecord') {
      return deserialize<_it4o4dd3.ServerChangeRecord>(data['data']);
    }
    if (dataClassName == 'SheetsActivitySummary') {
      return deserialize<_iaehez21.SheetsActivitySummary>(data['data']);
    }
    if (dataClassName == 'SheetsChangeLogReceipt') {
      return deserialize<_i5z6gq3n.SheetsChangeLogReceipt>(data['data']);
    }
    if (dataClassName == 'SheetsContributorStat') {
      return deserialize<_i9yjzgjk.SheetsContributorStat>(data['data']);
    }
    if (dataClassName == 'SheetsMergedSignal') {
      return deserialize<_izigafhu.SheetsMergedSignal>(data['data']);
    }
    if (dataClassName == 'SheetsSnapshotIndex') {
      return deserialize<_iwl8v9t3.SheetsSnapshotIndex>(data['data']);
    }
    if (dataClassName == 'SpaceReservation') {
      return deserialize<_i9g7m0kd.SpaceReservation>(data['data']);
    }
    if (dataClassName == 'SpaceStats') {
      return deserialize<_izbczo40.SpaceStats>(data['data']);
    }
    if (dataClassName == 'SpaceSubscription') {
      return deserialize<_i1qxq8ae.SpaceSubscription>(data['data']);
    }
    if (dataClassName == 'SubscribeResult') {
      return deserialize<_i6dq35xo.SubscribeResult>(data['data']);
    }
    if (dataClassName == 'SubscriptionReason') {
      return deserialize<_ic8hyldr.SubscriptionReason>(data['data']);
    }
    if (dataClassName == 'DocAck') {
      return deserialize<_icpkpcrn.DocAck>(data['data']);
    }
    if (dataClassName == 'DocBusMessage') {
      return deserialize<_i8zfu67r.DocBusMessage>(data['data']);
    }
    if (dataClassName == 'DocCursorUpdate') {
      return deserialize<_imbts8if.DocCursorUpdate>(data['data']);
    }
    if (dataClassName == 'DocHashCheck') {
      return deserialize<_imbts8if.DocHashCheck>(data['data']);
    }
    if (dataClassName == 'DocPing') {
      return deserialize<_imbts8if.DocPing>(data['data']);
    }
    if (dataClassName == 'DocRequestOps') {
      return deserialize<_imbts8if.DocRequestOps>(data['data']);
    }
    if (dataClassName == 'DocSubmitOp') {
      return deserialize<_imbts8if.DocSubmitOp>(data['data']);
    }
    if (dataClassName == 'DocHashResult') {
      return deserialize<_icpkpcrn.DocHashResult>(data['data']);
    }
    if (dataClassName == 'DocInit') {
      return deserialize<_icpkpcrn.DocInit>(data['data']);
    }
    if (dataClassName == 'DocMetaChanged') {
      return deserialize<_icpkpcrn.DocMetaChanged>(data['data']);
    }
    if (dataClassName == 'DocOpRejected') {
      return deserialize<_icpkpcrn.DocOpRejected>(data['data']);
    }
    if (dataClassName == 'DocParticipantJoined') {
      return deserialize<_icpkpcrn.DocParticipantJoined>(data['data']);
    }
    if (dataClassName == 'DocParticipantLeft') {
      return deserialize<_icpkpcrn.DocParticipantLeft>(data['data']);
    }
    if (dataClassName == 'DocPong') {
      return deserialize<_icpkpcrn.DocPong>(data['data']);
    }
    if (dataClassName == 'DocRemoteCursor') {
      return deserialize<_icpkpcrn.DocRemoteCursor>(data['data']);
    }
    if (dataClassName == 'DocRemoteOp') {
      return deserialize<_icpkpcrn.DocRemoteOp>(data['data']);
    }
    if (dataClassName == 'DocRoleChanged') {
      return deserialize<_icpkpcrn.DocRoleChanged>(data['data']);
    }
    if (dataClassName == 'ConvertForInsertResult') {
      return deserialize<_igqu3xcv.ConvertForInsertResult>(data['data']);
    }
    if (dataClassName == 'DocRejectCode') {
      return deserialize<_i5srcd7q.DocRejectCode>(data['data']);
    }
    if (dataClassName == 'Document') {
      return deserialize<_i4sx4pml.Document>(data['data']);
    }
    if (dataClassName == 'DocumentImportReport') {
      return deserialize<_ixppud51.DocumentImportReport>(data['data']);
    }
    if (dataClassName == 'DocumentInfo') {
      return deserialize<_iu022vpf.DocumentInfo>(data['data']);
    }
    if (dataClassName == 'DocumentMetaChange') {
      return deserialize<_ir38bcqq.DocumentMetaChange>(data['data']);
    }
    if (dataClassName == 'DocumentMetaPatch') {
      return deserialize<_inkjv0lb.DocumentMetaPatch>(data['data']);
    }
    if (dataClassName == 'DocumentMetaView') {
      return deserialize<_icsyekcn.DocumentMetaView>(data['data']);
    }
    if (dataClassName == 'DocumentOp') {
      return deserialize<_iufsprkx.DocumentOp>(data['data']);
    }
    if (dataClassName == 'DocumentOpKind') {
      return deserialize<_igr6xq1c.DocumentOpKind>(data['data']);
    }
    if (dataClassName == 'DocumentOpView') {
      return deserialize<_issmv319.DocumentOpView>(data['data']);
    }
    if (dataClassName == 'DocumentSnapshot') {
      return deserialize<_i2cnn8i8.DocumentSnapshot>(data['data']);
    }
    if (dataClassName == 'DocumentSnapshotView') {
      return deserialize<_i0cy62lm.DocumentSnapshotView>(data['data']);
    }
    if (dataClassName == 'ExportProgressEvent') {
      return deserialize<_is1ql5wp.ExportProgressEvent>(data['data']);
    }
    if (dataClassName == 'ExportProgressKind') {
      return deserialize<_isdjhzgs.ExportProgressKind>(data['data']);
    }
    if (dataClassName == 'ExportResultView') {
      return deserialize<_if2sngze.ExportResultView>(data['data']);
    }
    if (dataClassName == 'ThemeConflictException') {
      return deserialize<_ittnhawp.ThemeConflictException>(data['data']);
    }
    if (dataClassName == 'WriteDiffAuthor') {
      return deserialize<_ii88i7dv.WriteDiffAuthor>(data['data']);
    }
    if (dataClassName == 'WriteDiffCache') {
      return deserialize<_ig4xquf5.WriteDiffCache>(data['data']);
    }
    if (dataClassName == 'WriteDiffView') {
      return deserialize<_idky93gt.WriteDiffView>(data['data']);
    }
    if (dataClassName == 'WriteTheme') {
      return deserialize<_iynqrh33.WriteTheme>(data['data']);
    }
    if (dataClassName == 'WriteThemeRevision') {
      return deserialize<_i7pbwt05.WriteThemeRevision>(data['data']);
    }
    if (dataClassName == 'WriteThemeRevisionView') {
      return deserialize<_ick3mhj2.WriteThemeRevisionView>(data['data']);
    }
    if (dataClassName == 'WriteThemeView') {
      return deserialize<_ixbjd26z.WriteThemeView>(data['data']);
    }
    if (dataClassName == 'WriteVersionDocument') {
      return deserialize<_is9bkd9t.WriteVersionDocument>(data['data']);
    }
    if (dataClassName.startsWith('serverpod_auth_idp.')) {
      data['className'] = dataClassName.substring(19);
      return _iais.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('serverpod_offline_sync.')) {
      data['className'] = dataClassName.substring(23);
      return _izehhkf5.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('serverpod_auth_core.')) {
      data['className'] = dataClassName.substring(20);
      return _iacs.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('wonky_sync_models.')) {
      data['className'] = dataClassName.substring(18);
      return _i810rwvy.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('serverpod.')) {
      data['className'] = dataClassName.substring(10);
      return _isp.Protocol().deserializeByClassName(data);
    }
    return super.deserializeByClassName(data);
  }

  void _registerHostProtocols() {
    _iais.Protocol().registerHostProtocol('wonky', this);
    _izehhkf5.Protocol().registerHostProtocol('wonky', this);
    _iacs.Protocol().registerHostProtocol('wonky', this);
    _i810rwvy.Protocol().registerHostProtocol('wonky', this);
  }

  @override
  _is.Table? getTableForType(Type t) {
    {
      var table = _iais.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    {
      var table = _izehhkf5.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    {
      var table = _iacs.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    {
      var protocol = _i810rwvy.Protocol();
      var table = protocol is _is.DatabaseSerializationManager
          ? (protocol as _is.DatabaseSerializationManager).getTableForType(t)
          : null;
      if (table != null) {
        return table;
      }
    }
    {
      var table = _isp.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    switch (t) {
      case _iatdjl5p.ActivityEvent:
        return _iatdjl5p.ActivityEvent.t;
      case _iyixppck.Comment:
        return _iyixppck.Comment.t;
      case _ijog60vm.CommentThread:
        return _ijog60vm.CommentThread.t;
      case _inge8yy2.DriveItem:
        return _inge8yy2.DriveItem.t;
      case _i0g2m831.DriveItemUserState:
        return _i0g2m831.DriveItemUserState.t;
      case _iu565i0a.FeedbackReport:
        return _iu565i0a.FeedbackReport.t;
      case _im8eh74x.StoredFile:
        return _im8eh74x.StoredFile.t;
      case _ik59hiyp.UserNotification:
        return _ik59hiyp.UserNotification.t;
      case _i8scn8dm.AccessRequest:
        return _i8scn8dm.AccessRequest.t;
      case _iuzgacy4.DriveItemPermission:
        return _iuzgacy4.DriveItemPermission.t;
      case _ijwxtu30.OwnershipTransfer:
        return _ijwxtu30.OwnershipTransfer.t;
      case _it712lg1.ShareLink:
        return _it712lg1.ShareLink.t;
      case _ijodrcyd.PersonalAccessToken:
        return _ijodrcyd.PersonalAccessToken.t;
      case _i501u5m5.UserPreferences:
        return _i501u5m5.UserPreferences.t;
      case _ihzl7wbq.UserProfile:
        return _ihzl7wbq.UserProfile.t;
      case _i7jb115m.ItemVersion:
        return _i7jb115m.ItemVersion.t;
      case _ibe5uno1.ItemVersionState:
        return _ibe5uno1.ItemVersionState.t;
      case _ik5lpvx4.CellHistory:
        return _ik5lpvx4.CellHistory.t;
      case _it4o4dd3.ServerChangeRecord:
        return _it4o4dd3.ServerChangeRecord.t;
      case _i5z6gq3n.SheetsChangeLogReceipt:
        return _i5z6gq3n.SheetsChangeLogReceipt.t;
      case _iwl8v9t3.SheetsSnapshotIndex:
        return _iwl8v9t3.SheetsSnapshotIndex.t;
      case _i9g7m0kd.SpaceReservation:
        return _i9g7m0kd.SpaceReservation.t;
      case _i1qxq8ae.SpaceSubscription:
        return _i1qxq8ae.SpaceSubscription.t;
      case _i4sx4pml.Document:
        return _i4sx4pml.Document.t;
      case _ixppud51.DocumentImportReport:
        return _ixppud51.DocumentImportReport.t;
      case _ir38bcqq.DocumentMetaChange:
        return _ir38bcqq.DocumentMetaChange.t;
      case _iufsprkx.DocumentOp:
        return _iufsprkx.DocumentOp.t;
      case _i2cnn8i8.DocumentSnapshot:
        return _i2cnn8i8.DocumentSnapshot.t;
      case _ig4xquf5.WriteDiffCache:
        return _ig4xquf5.WriteDiffCache.t;
      case _iynqrh33.WriteTheme:
        return _iynqrh33.WriteTheme.t;
      case _i7pbwt05.WriteThemeRevision:
        return _i7pbwt05.WriteThemeRevision.t;
    }
    return null;
  }

  @override
  List<_isp.TableDefinition> getTargetTableDefinitions() =>
      targetTableDefinitions;

  @override
  String getModuleName() => 'wonky';

  /// Maps any `Record`s known to this [Protocol] to their JSON representation
  ///
  /// Throws in case the record type is not known.
  ///
  /// This method will return `null` (only) for `null` inputs.
  Map<String, dynamic>? mapRecordToJson(Record? record) {
    if (record == null) {
      return null;
    }
    try {
      return _iais.Protocol().mapRecordToJson(record);
    } catch (_) {}
    try {
      return _izehhkf5.Protocol().mapRecordToJson(record);
    } catch (_) {}
    try {
      return _iacs.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
