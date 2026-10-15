import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/files.dart';

import 'pdf_document.dart';
import 'preview_api.dart';
import 'preview_content.dart';
import 'preview_host.dart';

/// Where a preview is in its lifecycle (Drive 02 §6.1).
enum PreviewPhase {
  /// Loading the item or its bytes (skeleton, spinner after 300 ms).
  loading,

  /// The upload has not finished ("This file is still uploading").
  uploading,

  /// The viewer shows the file (or the "everything else" card).
  ready,

  /// No connection and the bytes aren't cached.
  offline,

  /// Too large to preview; *Download* only.
  tooLarge,

  /// The preview failed; [FilePreviewController.problem] says why.
  failed,

  /// The item doesn't exist or the caller has no access.
  notFound,

  /// The item is not an uploaded file (a document link): opened in its app.
  notAFile,
}

/// Why a preview failed ([PreviewPhase.failed]).
enum PreviewProblem {
  /// Loading failed (server or network error).
  load,

  /// The image doesn't decode (damaged or truncated).
  imageBroken,

  /// The PDF doesn't open (damaged).
  pdfBroken,

  /// The PDF is encrypted.
  pdfPassword,

  /// PDF rendering isn't available (pdf.js not served).
  pdfUnavailable,

  /// A text file whose bytes are binary.
  notText,
}

/// State and actions of one file preview (Drive 02 §6, Drive 04 §6). The
/// `drive.preview.*` and `drive.file.*` commands call into the active
/// controller ([FilePreviewHost.active]).
class FilePreviewController extends ChangeNotifier {
  FilePreviewController(
    this.host,
    this.itemUuid, {
    this.pollInterval = const Duration(seconds: 3),
  });

  final FilePreviewHost host;
  final UuidValue itemUuid;

  /// How often an uploading file's status is checked.
  final Duration pollInterval;

  ShellServices get services => host.services;
  FilePreviewApi get api => host.api;

  DriveItemView? item;
  PreviewType? type;
  PreviewPhase phase = PreviewPhase.loading;
  PreviewProblem? problem;

  /// Upload progress in percent (null = unknown).
  int? uploadPercent;

  /// The bytes shown (the original, or the server preview image).
  Uint8List? bytes;

  /// The image comes from the server's downscaled preview.
  bool fromServerPreview = false;

  /// Image pixel size (from the bytes or `fileMetaJson`).
  int? imageWidth;
  int? imageHeight;

  /// Decoded text (text and CSV viewers).
  TextPreview? text;

  /// The open PDF.
  PdfDocumentState? pdf;

  CsvTable? _csv;

  /// The CSV table (first [PreviewLimits.csvRows] rows), parsed lazily.
  CsvTable? get csv {
    final t = text;
    if (t == null) return null;
    return _csv ??= CsvSniffer.parse(
      t.text,
      fileName: item?.name,
      maxRows: PreviewLimits.csvRows,
    );
  }

  /// Ready files of the folder (prev/next), sorted by name.
  List<DriveItemView> siblings = const [];

  /// The folder's name ("3 of 12 in "Holiday"").
  String? folderName;

  // ------------------------------------------------------------ view state

  /// Zoom factor (1 = actual size); null = fit (image) / fit width (PDF).
  double? zoom;

  /// The scale "fit" currently means (reported by the viewer).
  double fitScale = 1;

  /// Image rotation in quarter turns (view only, never saved).
  int quarterTurns = 0;

  /// Soft wrap of the text viewer (`Alt+Z`).
  bool wrap = false;

  /// CSV shown as a table (else as text).
  bool csvAsTable = true;

  /// The PDF page in view (0-based, reported by the viewer).
  int pdfPage = 0;

  final StreamController<int> _pageJumps = StreamController.broadcast();

  /// Pages the PDF viewer should scroll to ([goToPage]).
  Stream<int> get pageJumps => _pageJumps.stream;

  Timer? _poll;
  bool _disposed = false;
  int _loadId = 0;

  /// The effective zoom (fit resolved).
  double get effectiveZoom => zoom ?? fitScale;

  PreviewViewer? get viewer =>
      phase == PreviewPhase.ready ? type?.viewer : null;

  /// Position in [siblings] (−1 when not listed).
  int get siblingIndex => siblings.indexWhere((s) => s.uuid == itemUuid);

  bool get hasNext {
    final i = siblingIndex;
    return i >= 0 && i < siblings.length - 1;
  }

  bool get hasPrevious => siblingIndex > 0;

  bool get canDownload => item?.canDownload ?? false;

  // ------------------------------------------------------------ loading

  /// Loads the item and its content.
  Future<void> load() async {
    final id = ++_loadId;
    _poll?.cancel();
    _reset();
    phase = PreviewPhase.loading;
    _notify();
    final DriveItemView v;
    try {
      v = await api.item(itemUuid);
    } on Object catch (e) {
      if (id != _loadId) return;
      phase = isOfflineError(e)
          ? PreviewPhase.offline
          : e is WonkyException &&
                (e.code == WonkyErrorCode.notFound ||
                    e.code == WonkyErrorCode.forbidden)
          ? PreviewPhase.notFound
          : PreviewPhase.failed;
      if (phase == PreviewPhase.failed) problem = PreviewProblem.load;
      _notify();
      return;
    }
    if (id != _loadId || _disposed) return;
    item = v;
    services.currentItem.value = v;
    if (v.kind != DriveItemKind.file) {
      phase = PreviewPhase.notAFile;
      _notify();
      return;
    }
    final t = type = PreviewType.of(v);
    unawaited(_loadSiblings(v));
    _readMeta(v);
    switch (v.uploadState) {
      case FileUploadState.uploading:
        phase = PreviewPhase.uploading;
        _notify();
        _startPolling();
        return;
      case FileUploadState.failed:
        _fail(PreviewProblem.load);
        return;
      case FileUploadState.ready || null:
        break;
    }
    if (!t.needsBytes) {
      phase = PreviewPhase.ready;
      _notify();
      return;
    }
    await _loadBytes(id, v, t);
  }

  void _reset() {
    problem = null;
    bytes = null;
    text = null;
    _csv = null;
    fromServerPreview = false;
    uploadPercent = null;
    pdf?.dispose();
    pdf = null;
  }

  void _readMeta(DriveItemView v) {
    final raw = v.fileMetaJson;
    if (raw == null) return;
    try {
      final m = jsonDecode(raw);
      if (m is Map) {
        final w = m['width'];
        final h = m['height'];
        if (w is int && h is int) {
          imageWidth = w;
          imageHeight = h;
        }
      }
    } on FormatException {
      // Ignore malformed metadata.
    }
  }

  Future<void> _loadBytes(int id, DriveItemView v, PreviewType t) async {
    var usePreview = false;
    if (t.viewer == PreviewViewer.image) {
      final px = (imageWidth ?? 0) * (imageHeight ?? 0);
      final large =
          v.sizeBytes > PreviewLimits.imageOriginalBytes ||
          px > PreviewLimits.imageMaxPixels;
      if (large) {
        if (v.previewFileId == null) {
          phase = PreviewPhase.tooLarge;
          _notify();
          return;
        }
        usePreview = true;
      }
    } else if (v.sizeBytes > PreviewLimits.maxBytes) {
      phase = PreviewPhase.tooLarge;
      _notify();
      return;
    }
    final key = usePreview
        ? 'preview:${v.previewFileId!.uuid}'
        : 'file:${(v.contentRef ?? v.uuid).uuid}';
    var data = host.cache.get(key);
    if (data == null) {
      try {
        final url = usePreview
            ? await api.storedFileUrl(v.previewFileId!)
            : await api.contentUrl(v.uuid);
        final u = url.url;
        if (u == null) {
          // Not stored yet (pending) — the upload is still finishing.
          if (id != _loadId) return;
          phase = PreviewPhase.uploading;
          _notify();
          _startPolling();
          return;
        }
        data = await api.fetch(u, maxBytes: PreviewLimits.maxBytes);
        host.cache.put(key, data);
      } on Object catch (e) {
        if (id != _loadId || _disposed) return;
        if (isOfflineError(e)) {
          phase = PreviewPhase.offline;
          _notify();
        } else if (e is PreviewFetchException && e.tooLarge) {
          phase = PreviewPhase.tooLarge;
          _notify();
        } else {
          _fail(PreviewProblem.load);
        }
        return;
      }
    }
    if (id != _loadId || _disposed) return;
    fromServerPreview = usePreview;
    bytes = data;
    await _prepare(id, v, t, data);
  }

  Future<void> _prepare(
    int id,
    DriveItemView v,
    PreviewType t,
    Uint8List data,
  ) async {
    switch (t.viewer) {
      case PreviewViewer.image:
        final ok = await _checkImage(data);
        if (id != _loadId || _disposed) return;
        if (!ok) return _fail(PreviewProblem.imageBroken);
        final px = (imageWidth ?? 0) * (imageHeight ?? 0);
        if (!fromServerPreview && px > PreviewLimits.imageMaxPixels) {
          // Never decode huge images on the client (§6.2).
          bytes = null;
          phase = PreviewPhase.tooLarge;
          _notify();
          return;
        }
        phase = PreviewPhase.ready;
        _notify();
      case PreviewViewer.text || PreviewViewer.csv:
        final decoded = TextPreview.decode(data);
        if (decoded == null) return _fail(PreviewProblem.notText);
        text = decoded;
        phase = PreviewPhase.ready;
        _notify();
      case PreviewViewer.pdf:
        if (!await host.rasterizer.available()) {
          if (id != _loadId || _disposed) return;
          return _fail(PreviewProblem.pdfUnavailable);
        }
        if (id != _loadId || _disposed) return;
        final doc = pdf = PdfDocumentState(host.rasterizer, data);
        doc.addListener(_onPdfChanged);
        phase = PreviewPhase.ready;
        _notify();
        await doc.open();
        if (id != _loadId || _disposed) return;
        if (doc.passwordProtected) return _fail(PreviewProblem.pdfPassword);
        if (doc.error != null) return _fail(PreviewProblem.pdfBroken);
        unawaited(_writePageCount(v, doc));
      case PreviewViewer.unsupported:
        phase = PreviewPhase.ready;
        _notify();
    }
  }

  /// Reads the image header (size, format) without decoding the pixels.
  Future<bool> _checkImage(Uint8List data) async {
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(data);
      final d = await ui.ImageDescriptor.encoded(buffer);
      final w = d.width;
      final h = d.height;
      d.dispose();
      buffer.dispose();
      if (w <= 0 || h <= 0) return false;
      // The original's size from the metadata wins over a preview's.
      if (imageWidth == null || !fromServerPreview) {
        imageWidth = w;
        imageHeight = h;
      }
      return true;
    } on Object {
      return false;
    }
  }

  /// Marks the shown image as undecodable (the viewer's error callback).
  void reportImageBroken() {
    if (phase == PreviewPhase.ready && type?.viewer == PreviewViewer.image) {
      _fail(PreviewProblem.imageBroken);
    }
  }

  void _onPdfChanged() => _notify();

  /// The first Editor+ viewer writes the page count back (Drive 02 §6.3).
  Future<void> _writePageCount(DriveItemView v, PdfDocumentState doc) async {
    if (!v.canEdit || doc.truncated || doc.pageCount == 0) return;
    final raw = v.fileMetaJson;
    try {
      final m = raw == null ? <String, Object?>{} : jsonDecode(raw);
      if (m is Map && m['pages'] == doc.pageCount) return;
      final updated = await api.updateFileMeta(
        v.uuid,
        jsonEncode({'pages': doc.pageCount}),
      );
      if (!_disposed && item?.uuid == updated.uuid) item = updated;
    } on Object {
      // Metadata is best effort.
    }
  }

  void _fail(PreviewProblem p) {
    pdf?.removeListener(_onPdfChanged);
    problem = p;
    phase = PreviewPhase.failed;
    _notify();
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(pollInterval, (_) => _checkUpload());
  }

  Future<void> _checkUpload() async {
    try {
      final s = await api.uploadStatus(itemUuid);
      if (_disposed) return;
      switch (s.uploadState) {
        case FileUploadState.uploading:
          final size = item?.sizeBytes ?? 0;
          uploadPercent = size > 0 && s.receivedBytes > 0
              ? (s.receivedBytes * 100 ~/ size).clamp(0, 99)
              : null;
          _notify();
        case FileUploadState.ready:
          _poll?.cancel();
          await load();
        case FileUploadState.failed:
          _poll?.cancel();
          _fail(PreviewProblem.load);
      }
    } on Object {
      // Keep polling; offline or a transient error.
    }
  }

  Future<void> _loadSiblings(DriveItemView v) async {
    final parent = v.parentUuid;
    if (parent == null) return;
    if (host.siblingsOf == parent) {
      siblings = _ready(host.siblings);
      folderName = host.siblingsFolderName;
      _notify();
    }
    try {
      final files = await api.filesIn(parent);
      String? name;
      try {
        name = (await api.folder(parent)).name;
      } on Object {
        name = null;
      }
      if (_disposed) return;
      host
        ..siblingsOf = parent
        ..siblings = files
        ..siblingsFolderName = name;
      siblings = _ready(files);
      folderName = name;
      _notify();
    } on Object {
      // Prev/next stays unavailable.
    }
  }

  List<DriveItemView> _ready(List<DriveItemView> files) => [
    for (final f in files)
      if (f.kind == DriveItemKind.file &&
          f.uploadState != FileUploadState.uploading &&
          f.uploadState != FileUploadState.failed)
        f,
  ];

  // ------------------------------------------------------------ actions

  /// The next (or previous) ready file of the folder, if any.
  DriveItemView? neighbor(int delta) {
    final i = siblingIndex;
    if (i < 0) return null;
    final j = i + delta;
    return j >= 0 && j < siblings.length ? siblings[j] : null;
  }

  static const _zoomSteps = [
    0.1,
    0.25,
    0.33,
    0.5,
    0.67,
    0.75,
    0.9,
    1.0,
    1.25,
    1.5,
    2.0,
    3.0,
    4.0,
    6.0,
    8.0,
  ];

  /// Zoom limits of the current viewer: images 10–800 %, PDF 25–400 %.
  (double, double) get zoomRange =>
      type?.viewer == PreviewViewer.pdf ? (0.25, 4.0) : (0.1, 8.0);

  bool get canZoom =>
      phase == PreviewPhase.ready &&
      (type?.viewer == PreviewViewer.image ||
          type?.viewer == PreviewViewer.pdf);

  void zoomIn() => _step(1);
  void zoomOut() => _step(-1);

  void _step(int dir) {
    final (lo, hi) = zoomRange;
    final cur = effectiveZoom;
    double next = dir > 0 ? hi : lo;
    if (dir > 0) {
      for (final s in _zoomSteps) {
        if (s > cur + 1e-6) {
          next = s;
          break;
        }
      }
    } else {
      for (final s in _zoomSteps.reversed) {
        if (s < cur - 1e-6) {
          next = s;
          break;
        }
      }
    }
    zoom = next.clamp(lo, hi);
    _notify();
  }

  /// Fit to window (image) / fit width (PDF).
  void zoomFit() {
    zoom = null;
    _notify();
  }

  /// 100 %.
  void zoomActual() {
    zoom = 1.0;
    _notify();
  }

  /// Rotates the image view 90° clockwise (not saved).
  void rotate() {
    quarterTurns = (quarterTurns + 1) % 4;
    _notify();
  }

  /// Sets the zoom (e.g. Mod+scroll, pinch), clamped to [zoomRange].
  void setZoom(double z) {
    final (lo, hi) = zoomRange;
    zoom = z.clamp(lo, hi);
    _notify();
  }

  /// Called by the viewer when its fit scale changes (no notification).
  void reportFitScale(double s) => fitScale = s;

  /// Called by the PDF viewer while scrolling.
  void reportPage(int page) {
    if (page == pdfPage) return;
    pdfPage = page;
    _notify();
  }

  /// Scrolls the PDF to [page] (1-based). Returns false when out of range.
  bool goToPage(int page) {
    final doc = pdf;
    if (doc == null || page < 1 || page > doc.pageCount) return false;
    pdfPage = page - 1;
    _pageJumps.add(page - 1);
    _notify();
    return true;
  }

  void toggleWrap() {
    wrap = !wrap;
    _notify();
  }

  void setCsvAsTable(bool table) {
    csvAsTable = table;
    _notify();
  }

  /// Copies the shown text (*Copy all*).
  Future<bool> copyAll() async {
    final t = text;
    if (t == null) return false;
    await Clipboard.setData(ClipboardData(text: t.text));
    return true;
  }

  /// Starts the download (Drive 02 §8). Returns false when downloads
  /// aren't possible here.
  Future<bool> download() async {
    final v = item;
    if (v == null || !v.canDownload) return false;
    final url = await api.contentUrl(v.uuid, download: true);
    final u = url.url;
    if (u == null) return false;
    return host.downloader.download(u, v.name);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    pdf?.removeListener(_onPdfChanged);
    pdf?.dispose();
    _pageJumps.close();
    if (services.currentItem.value?.uuid == itemUuid) {
      services.currentItem.value = null;
    }
    super.dispose();
  }
}
