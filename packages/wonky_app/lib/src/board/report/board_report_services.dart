import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:wonky_client/wonky_client.dart';

import '../../data/api.dart';
import '../../mcp_bridge/app_screenshot.dart';
import '../../shell/shell_services.dart';
import '../screenshot/jpeg_encoder.dart';
import '../screenshot/screenshot_annotations.dart';

/// The last error the error boundary saw (specs/16 §4.2.4): the message
/// (at most [maxMessage] characters), the top [maxFrames] stack frames and
/// when it happened. The report dialog offers to include it.
@immutable
class BoardLastError {
  const BoardLastError({
    required this.message,
    required this.frames,
    required this.at,
  });

  static const maxMessage = 4000;
  static const maxFrames = 30;

  /// Built from an error and its stack, trimmed to the limits.
  factory BoardLastError.from(
    String message,
    StackTrace? stack, {
    required DateTime at,
  }) => BoardLastError(
    message: message.length > maxMessage
        ? message.substring(0, maxMessage)
        : message,
    frames: [
      for (final line in (stack?.toString() ?? '').split('\n'))
        if (line.trim().isNotEmpty) line.trimRight(),
    ].take(maxFrames).toList(growable: false),
    at: at,
  );

  final String message;
  final List<String> frames;
  final DateTime at;

  /// The `error` entry of the included details.
  Map<String, Object?> toJson() => {
    'message': message,
    'stack': frames,
    'at': at.toUtc().toIso8601String(),
  };
}

/// Uploads screenshot bytes for a [FileUploadTicket] and completes the
/// upload (specs/16 §5.3 steps 2–3).
abstract class BoardScreenshotTransport {
  /// Sends [bytes] with Serverpod's `FileUploader` (skipped when the ticket
  /// says the file is already uploaded).
  Future<void> upload(FileUploadTicket ticket, Uint8List bytes);

  /// `file.completeUpload`.
  Future<void> complete(UuidValue fileUuid);
}

/// [BoardScreenshotTransport] against the server.
class ServerBoardScreenshotTransport implements BoardScreenshotTransport {
  ServerBoardScreenshotTransport(this.api);

  final Api api;

  @override
  Future<void> upload(FileUploadTicket ticket, Uint8List bytes) async {
    final description = ticket.uploadDescription;
    if (ticket.status == StoredFileStatus.ready || description == null) return;
    final ok = await FileUploader(
      description,
    ).uploadByteData(ByteData.sublistView(bytes));
    if (!ok) throw StateError('The screenshot upload failed.');
  }

  @override
  Future<void> complete(UuidValue fileUuid) async {
    await api.guard((c) => c.file.completeUpload(fileUuid));
  }
}

/// Per-shell state and seams of the report dialog (specs/16 §4.2, §5):
/// the last error, the screen capture, the screenshot finisher and the
/// upload transport. One instance per [ShellServices] ([of]); tests
/// replace the seams.
class BoardReportServices {
  BoardReportServices._(this._s);

  static final Expando<BoardReportServices> _instances = Expando(
    'BoardReportServices',
  );

  /// The instance of [s].
  static BoardReportServices of(ShellServices s) =>
      _instances[s] ??= BoardReportServices._(s);

  final ShellServices _s;

  /// The last error of the error boundary (null when none happened).
  final ValueNotifier<BoardLastError?> lastError = ValueNotifier(null);

  /// How old an error may be for *Include the last error* to be on by
  /// default.
  static const recentError = Duration(minutes: 10);

  /// Records an error (called by the error boundary).
  void recordError(String message, StackTrace? stack) =>
      lastError.value = BoardLastError.from(message, stack, at: clock.now());

  /// Captures the app before the dialog opens (`captureAppScreenshot`).
  late Future<ui.Image?> Function() capture = () => captureAppScreenshot(_s);

  /// Flattens and encodes the edited screenshot (*Done* in the editor).
  ScreenshotFinisher finish = (source, annotations) =>
      flattenAndEncodeScreenshot(
        source,
        annotations,
        jpegEncoder: platformJpegEncoder,
      );

  BoardScreenshotTransport? _transport;

  /// The upload transport (the server's by default).
  BoardScreenshotTransport get transport =>
      _transport ??= ServerBoardScreenshotTransport(
        Api(
          _s.client ??
              (throw StateError('No client to upload the screenshot.')),
        ),
      );
  set transport(BoardScreenshotTransport value) => _transport = value;

  /// The similar-posts debounce (specs/16 §4.2.2).
  Duration similarDebounce = const Duration(milliseconds: 400);

  /// Uploads [shot] as a board screenshot (specs/16 §5.3): ticket, bytes,
  /// completion. Returns the file uuid for `BoardPostDraft`.
  Future<UuidValue> uploadScreenshot(EncodedScreenshot shot) async {
    final uuid = _s.ids.next();
    final ticket = await _s.repositories.board.createScreenshotUpload(
      uuid,
      shot.mimeType,
      shot.bytes.length,
    );
    await transport.upload(ticket, shot.bytes);
    await transport.complete(uuid);
    return uuid;
  }
}
