import 'package:flutter/foundation.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';

import 'file_downloader.dart';
import 'file_preview_controller.dart';
import 'pdf_rasterizer.dart';
import 'preview_api.dart';
import 'preview_cache.dart';

/// Per-shell state of the file preview (Drive 02 §6): its collaborators
/// (replaceable in tests), the byte cache, the folder listing used for
/// prev/next, and the open preview the `drive.preview.*` commands act on.
class FilePreviewHost {
  FilePreviewHost._(this.services);

  static final Expando<FilePreviewHost> _hosts = Expando('FilePreviewHost');

  /// The host of [services] (created on first use).
  static FilePreviewHost of(ShellServices services) =>
      _hosts[services] ??= FilePreviewHost._(services);

  final ShellServices services;

  FilePreviewApi? _api;
  PdfRasterizer? _rasterizer;

  /// Server access ([ServerFilePreviewApi] unless replaced).
  FilePreviewApi get api => _api ??= ServerFilePreviewApi(services);
  set api(FilePreviewApi v) => _api = v;

  /// PDF rasterizer (`printing` + the self-hosted pdf.js in `web/pdfjs/`).
  PdfRasterizer get rasterizer => _rasterizer ??= PrintingPdfRasterizer(
    pdfJsBaseUrl: services.urls.urlFor(WonkyAppKind.drive, 'pdfjs/'),
  );
  set rasterizer(PdfRasterizer v) => _rasterizer = v;

  /// Starts downloads (hidden anchor on the web).
  FileDownloader downloader = const PlatformFileDownloader();

  /// Bytes of recently previewed files (prev/next, offline fallback).
  final PreviewByteCache cache = PreviewByteCache();

  /// The open preview, if any.
  final ValueNotifier<FilePreviewController?> active = ValueNotifier(null);

  /// The last folder listing (parent uuid → files), so stepping to the
  /// next file shows "4 of 12" right away.
  UuidValue? siblingsOf;
  List<DriveItemView> siblings = const [];
  String? siblingsFolderName;
}
