import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_sheets_core/model.dart';

/// Checks an operation before `SheetEditorController.apply` plans and
/// writes it (protected ranges 03 §16, data validation of typed input
/// 03 §8.4). Throws [WriteRefused] or [WriteNeedsConfirmation] to stop the
/// command before anything is written; returns normally to let it pass.
typedef WriteGate = void Function(CommandContext? ctx, SheetsOperation op);

/// A write the gate refuses (blocked protection, rejected input). The
/// command aborts; nothing of it is written.
class WriteRefused implements Exception {
  WriteRefused(this.message, {this.code, this.show});

  final String message;

  /// Machine-readable reason for MCP callers (`protected_range`,
  /// `validation`).
  final String? code;

  /// Explains the refusal to the user (a dialog); used for human
  /// invocations when a dialog context exists.
  final Future<void> Function(BuildContext context)? show;

  /// The failure text of the command result.
  String get resultMessage => code == null ? message : '$code: $message';

  @override
  String toString() => 'WriteRefused($resultMessage)';
}

/// A write that may go on after the user confirms (warning-only
/// protections, 03 §16). The command is run again once [confirm] returns
/// true; the gate lets the repeated run pass.
class WriteNeedsConfirmation implements Exception {
  WriteNeedsConfirmation(this.message, {required this.confirm, this.retryDone});

  final String message;

  /// Asks the user; true continues (the gate then lets the repeated run of
  /// the command pass).
  final Future<bool> Function(BuildContext context) confirm;

  /// Called after the repeated run (the gate stops letting warnings pass).
  final VoidCallback? retryDone;

  @override
  String toString() => 'WriteNeedsConfirmation($message)';
}
