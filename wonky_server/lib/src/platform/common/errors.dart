import 'dart:convert';

import 'package:wonky_core/files.dart' show formatStorageBytes;

import 'models.dart';

/// Shorthands for the [WonkyException]s thrown by services.
abstract final class Errors {
  static WonkyException notFound([String what = 'Item']) => WonkyException(
    code: WonkyErrorCode.notFound,
    message: '$what not found.',
  );

  static WonkyException forbidden([
    String message = 'You do not have permission to do this.',
  ]) => WonkyException(code: WonkyErrorCode.forbidden, message: message);

  static WonkyException invalid(String message) =>
      WonkyException(code: WonkyErrorCode.invalidArgument, message: message);

  static WonkyException conflict(String message) =>
      WonkyException(code: WonkyErrorCode.conflict, message: message);

  static WonkyException limit(String message, {String? detailsJson}) =>
      WonkyException(
        code: WonkyErrorCode.limitExceeded,
        message: message,
        detailsJson: detailsJson,
      );

  static WonkyException tooLarge(String message) =>
      WonkyException(code: WonkyErrorCode.tooLarge, message: message);

  static WonkyException expired(String message) =>
      WonkyException(code: WonkyErrorCode.expired, message: message);

  static WonkyException unavailable(String message) =>
      WonkyException(code: WonkyErrorCode.unavailable, message: message);

  static WonkyException busy(String message) =>
      WonkyException(code: WonkyErrorCode.busy, message: message);

  /// (v2) Not enough storage (Drive 03 §7.1): "Not enough storage: this
  /// needs 12.4 MB, 3.1 MB is available." with [details] as `detailsJson`.
  static WonkyException quotaExceeded(
    QuotaExceededDetails details,
  ) => WonkyException(
    code: WonkyErrorCode.quotaExceeded,
    message:
        'Not enough storage: this needs ${formatStorageBytes(details.neededBytes)}, '
        '${formatStorageBytes(details.availableBytes)} is available.',
    detailsJson: jsonEncode(details.toJson()),
  );
}
