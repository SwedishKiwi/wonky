import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart' show DriveItemView, UuidValue;
import 'package:wonky_slides_core/interfaces.dart'
    show SlideImageResolver, SlidesPdfDocumentInfo;
import 'package:wonky_slides_core/model.dart' show DeckModel;

import '../../l10n/slides_l10n.dart';
import '../print/slides_client_export.dart';

/// Overrides the server call of [copySlidesVersion] (tests).
@visibleForTesting
Future<DriveItemView> Function(
  UuidValue item,
  int versionId,
  String name,
  UuidValue? folderUuid,
  bool comments,
  bool sharing,
)?
copySlidesVersionOverride;

/// *Make a copy* of a version (Slides 09 §4.5): the server copies the
/// version's snapshot into a new presentation (`slidesVersion.makeCopy`:
/// `DeckCopier` ids, uploaded images re-homed, the caller's quota) with
/// the deck's comments and sharing when asked. Needs a connection, like
/// all of version history (09 §6.1).
Future<DriveItemView> copySlidesVersion(
  ShellServices services, {
  required UuidValue itemUuid,
  required int versionId,
  required String name,
  UuidValue? folderUuid,
  bool copyComments = false,
  bool copySharing = false,
}) {
  final override = copySlidesVersionOverride;
  if (override != null) {
    return override(
      itemUuid,
      versionId,
      name,
      folderUuid,
      copyComments,
      copySharing,
    );
  }
  final client = services.client;
  if (client == null || Api.simulatedOffline) {
    throw const OfflineException('offline');
  }
  return client.slidesVersion.makeCopy(
    itemUuid,
    versionId,
    name,
    folderUuid,
    copyComments,
    copySharing,
  );
}

/// What the *Make a copy* dialog returned.
typedef VersionCopyChoice = ({String name, bool comments, bool sharing});

/// The *Make a copy* dialog of a version: name, *Copy comments*, *Share
/// with the same people* (MCP-operable, `dialog.versionCopy`).
Future<VersionCopyChoice?> showVersionCopyDialog(
  BuildContext context, {
  required String initialName,
}) async {
  final l = slidesL10n(context);
  final la = WonkyAppLocalizations.of(context);
  final r = await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      title: l.versionCopyTitle,
      dialogKey: 'dialog.versionCopy',
      width: 360,
      fields: [
        TextFieldSpec(
          id: 'name',
          label: l.versionCopyNameLabel,
          initial: initialName,
          maxLength: 255,
          validator: (v) => v.trim().isEmpty ? l.versionCopyNameRequired : null,
        ),
        CheckboxFieldSpec(id: 'comments', label: l.versionCopyComments),
        CheckboxFieldSpec(id: 'sharing', label: l.versionCopySharing),
      ],
      buttons: [
        DialogButtonSpec(id: 'cancel', label: la.actionCancel),
        DialogButtonSpec(
          id: 'ok',
          label: l.cmdHistoryMakeCopy,
          primary: true,
          validates: true,
        ),
      ],
    ),
  );
  if (r?.buttonId != 'ok') return null;
  return (
    name: r!.text('name').trim(),
    comments: r.values['comments'] == true,
    sharing: r.values['sharing'] == true,
  );
}

/// *Download as PDF* of a version (Slides 09 §4.5): the core PDF exporter
/// on the version's model with the user's last-used export options.
/// Returns the file name, or null when the save was cancelled.
Future<String?> downloadSlidesVersionPdf(
  ShellServices services,
  DeckModel model, {
  required SlideImageResolver images,
  required String fileName,
}) async {
  final l = slidesL10nOf(services);
  final result = await SlidesClientExport.render(
    model,
    SlidesClientExport.lastUsed(services),
    images: images,
    l: l,
    info: SlidesPdfDocumentInfo(title: model.deck?.title),
  );
  final saved = await SlidesClientExport.save(
    Uint8List.fromList(result.bytes),
    fileName: fileName,
  );
  return saved ? fileName : null;
}
