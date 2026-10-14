import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';

import '../../l10n/sheets_l10n.dart';

/// Where an inserted image comes from.
sealed class ImageSourceChoice {
  const ImageSourceChoice();
}

/// Pick a file from the computer.
class UploadImageChoice extends ImageSourceChoice {
  const UploadImageChoice();
}

/// Fetch an https image (through the server).
class UrlImageChoice extends ImageSourceChoice {
  const UrlImageChoice(this.url);
  final String url;
}

/// Insert image dialog (08 §10.1 `ImageInsertDialog`): *Upload from
/// computer…* or an https URL. Null when cancelled.
Future<ImageSourceChoice?> showInsertImageDialog(
  BuildContext context, {
  required bool inCell,
}) async {
  final l = sheetsL10n(context);
  final la = WonkyAppLocalizations.of(context);
  final r = await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      title: inCell ? l.dialogImageInCellTitle : l.dialogImageOverCellsTitle,
      description: l.dialogImageDescription,
      dialogKey: 'dialog.insertImage',
      width: 460,
      fields: [
        TextFieldSpec(
          id: 'url',
          label: l.dialogImageUrl,
          placeholder: 'https://',
          validator: (v) {
            final t = v.trim();
            if (t.isEmpty) return l.dialogImageUrlRequired;
            final u = Uri.tryParse(t);
            if (u == null || u.scheme != 'https' || u.host.isEmpty) {
              return l.dialogImageUrlInvalid;
            }
            return null;
          },
        ),
      ],
      buttons: [
        DialogButtonSpec(id: 'cancel', label: la.actionCancel),
        DialogButtonSpec(
          id: 'upload',
          label: l.dialogImageUpload,
          validates: false,
        ),
        DialogButtonSpec(id: 'ok', label: l.dialogImageInsert, primary: true),
      ],
    ),
  );
  return switch (r?.buttonId) {
    'upload' => const UploadImageChoice(),
    'ok' => UrlImageChoice(r!.text('url').trim()),
    _ => null,
  };
}
