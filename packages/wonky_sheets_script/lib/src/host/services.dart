import 'dart:async';
import 'dart:typed_data';

import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_sheets_core/wonky_sheets_core.dart';

/// Kinds of script executions (09 §8.1; `ScriptExecution.triggerKind`).
enum ExecutionKind {
  /// Run from the script editor.
  editor,

  /// Custom menu item.
  menu,

  /// Macro (menu, shortcut, `sheets.macro.<id>`).
  macro,

  /// Custom function evaluated by the formula engine.
  customFunction,

  /// Simple `onOpen`.
  onOpen,

  /// Simple `onEdit`.
  onEdit,

  /// Simple `onSelectionChange`.
  onSelectionChange,

  /// Simple `onChange`.
  onChange,

  /// Installable time-driven trigger.
  timeDriven,

  /// Installable `onEdit`.
  installableOnEdit,

  /// Installable `onChange`.
  installableOnChange,

  /// Installable `onOpen`.
  installableOnOpen,

  /// MCP `sheets.run_function`.
  mcp,

  /// The AI assistant ran a function.
  ai;

  /// Whether the execution is a custom function (pure: no reads of the
  /// spreadsheet, no writes, no UI; 09 §8.6).
  bool get isCustomFunction => this == customFunction;

  /// Installable triggers and other unattended server runs.
  bool get isInstallable =>
      this == timeDriven ||
      this == installableOnEdit ||
      this == installableOnChange ||
      this == installableOnOpen;

  /// Simple triggers (run in `AuthMode.limited` without authorization).
  bool get isSimpleTrigger =>
      this == onOpen ||
      this == onEdit ||
      this == onSelectionChange ||
      this == onChange;
}

/// Script scopes (09 §11.1).
abstract final class ScriptScopes {
  /// Read/write the bound spreadsheet (implicit).
  static const spreadsheetCurrent = 'spreadsheet.current';

  /// Alerts, prompts, toasts, menus (implicit).
  static const ui = 'ui';

  /// `Session.activeUser.email`.
  static const userEmail = 'user.email';

  /// `UrlFetchApp`.
  static const externalRequest = 'external_request';

  /// `ScriptApp` (install/delete triggers).
  static const triggers = 'script.triggers';

  /// Scopes that are always granted.
  static const implicit = {spreadsheetCurrent, ui};

  /// Scopes that need the authorization dialog.
  static const authorizable = [userEmail, externalRequest, triggers];
}

/// A user as scripts see it (`User`, 09 §6.6).
final class ScriptUser {
  /// Creates a user.
  const ScriptUser({required this.id, required this.email, required this.name});

  /// Auth user UUID.
  final String id;

  /// E-mail (shown to scripts only with the `user.email` scope).
  final String email;

  /// Display name.
  final String name;
}

/// The UI selection of the running user (client executions).
final class ScriptSelection {
  /// Creates a selection.
  const ScriptSelection({
    required this.sheetId,
    this.ranges = const [],
    this.currentCell,
  });

  /// Active sheet.
  final String sheetId;

  /// Selected rectangles on [sheetId] (first = active range).
  final List<GridRect> ranges;

  /// Cursor cell.
  final CellPos? currentCell;
}

/// Who runs a script, where and with which permissions.
final class ExecutionContext {
  /// Creates a context.
  const ExecutionContext({
    required this.kind,
    required this.activeUser,
    ScriptUser? effectiveUser,
    required this.role,
    this.grantedScopes = const {},
    this.authorized = true,
    this.isServer = false,
    this.selection,
    this.scriptTimeZone,
    this.userLocale = 'en_US',
    this.spreadsheetUrl = '',
    this.owner,
  }) : effectiveUser = effectiveUser ?? activeUser;

  /// Kind of execution.
  final ExecutionKind kind;

  /// The person running or triggering the script.
  final ScriptUser activeUser;

  /// Run-as user (installer of installable triggers).
  final ScriptUser effectiveUser;

  /// Role of the run-as user on the spreadsheet.
  final Role role;

  /// Scopes the user authorized for this spreadsheet (09 §11.2); the
  /// implicit scopes are always granted.
  final Set<String> grantedScopes;

  /// False for simple triggers of users who have not authorized the project
  /// (`AuthMode.limited`).
  final bool authorized;

  /// Server-side execution: no UI, `activeSheet` = first visible sheet.
  final bool isServer;

  /// Selection of the user's window (client executions).
  final ScriptSelection? selection;

  /// Project time zone; defaults to the spreadsheet's.
  final String? scriptTimeZone;

  /// Locale of the active user.
  final String userLocale;

  /// Link to the spreadsheet (`Spreadsheet.url`).
  final String spreadsheetUrl;

  /// Owner of the spreadsheet (`Spreadsheet.owner`).
  final ScriptUser? owner;

  /// Whether [scope] may be used.
  bool hasScope(String scope) =>
      ScriptScopes.implicit.contains(scope) ||
      (authorized && grantedScopes.contains(scope));
}

/// Buttons of an alert or prompt (`ButtonSet`).
enum ScriptButtonSet {
  /// OK.
  ok,

  /// OK, Cancel.
  okCancel,

  /// Yes, No.
  yesNo,

  /// Yes, No, Cancel.
  yesNoCancel,
}

/// Dialog buttons (`Button`).
enum ScriptButton {
  /// OK.
  ok,

  /// Cancel.
  cancel,

  /// Yes.
  yes,

  /// No.
  no,

  /// Closed without a button (or timed out after 5 minutes).
  close,
}

/// An alert or prompt request (09 §16.2). The app renders it as a
/// `WonkyFormDialog` from a `WonkyDialogSpec`.
final class ScriptDialogRequest {
  /// Creates a request.
  const ScriptDialogRequest({
    required this.message,
    this.title,
    required this.buttons,
    this.prompt = false,
  });

  /// Message text.
  final String message;

  /// Optional title.
  final String? title;

  /// Buttons.
  final ScriptButtonSet buttons;

  /// Whether a text field is shown.
  final bool prompt;
}

/// The user's answer to a [ScriptDialogRequest].
final class ScriptDialogResponse {
  /// Creates a response.
  const ScriptDialogResponse(this.button, [this.text = '']);

  /// Selected button.
  final ScriptButton button;

  /// Text of a prompt.
  final String text;
}

/// An item of a custom menu (09 §16.1): an action, a separator or a sub menu.
final class ScriptMenuItem {
  /// An action running [functionName].
  const ScriptMenuItem.action(String this.caption, String this.functionName)
    : separator = false,
      items = const [];

  /// A separator.
  const ScriptMenuItem.separator()
    : caption = null,
      functionName = null,
      separator = true,
      items = const [];

  /// A sub menu.
  const ScriptMenuItem.subMenu(String this.caption, this.items)
    : functionName = null,
      separator = false;

  /// Caption (null for separators).
  final String? caption;

  /// Function run by the item.
  final String? functionName;

  /// Whether this is a separator.
  final bool separator;

  /// Sub menu items.
  final List<ScriptMenuItem> items;
}

/// A top-level custom menu (`Menu.addToUi()`).
final class ScriptMenu {
  /// Creates a menu.
  const ScriptMenu(this.caption, this.items);

  /// Caption in the menubar.
  final String caption;

  /// Items.
  final List<ScriptMenuItem> items;
}

/// The UI side of client executions, implemented by the app (09 §16).
///
/// Server executions have no delegate: `SpreadsheetApp.ui` throws
/// `UiUnavailableException` and toasts are logged.
abstract interface class ScriptUiDelegate {
  /// Shows an alert or prompt and completes with the answer. The host gives
  /// up after 5 minutes (`Button.close`).
  Future<ScriptDialogResponse> showDialog(ScriptDialogRequest request);

  /// Shows a toast (`timeoutSeconds` −1 = until closed).
  void showToast(String message, {String? title, double timeoutSeconds = 5});

  /// Registers a custom menu for this window (`ScriptMenuRegistry`).
  void addMenu(ScriptMenu menu);

  /// Selects [range] in the grid (`Range.activate`).
  void select(ResolvedRange range);

  /// Activates the sheet [sheetId] (`Spreadsheet.activeSheet = …`).
  void activateSheet(String sheetId);
}

/// A key/value property store (09 §6.9).
abstract interface class PropertyStore {
  /// All properties.
  Map<String, String> all();

  /// Sets [key].
  void set(String key, String value);

  /// Deletes [key].
  void delete(String key);
}

/// In-memory [PropertyStore] (tests; user properties without persistence).
final class MemoryPropertyStore implements PropertyStore {
  /// Creates a store with [initial] properties.
  MemoryPropertyStore([Map<String, String>? initial]) : values = {...?initial};

  /// The properties.
  final Map<String, String> values;

  @override
  Map<String, String> all() => Map.of(values);

  @override
  void set(String key, String value) => values[key] = value;

  @override
  void delete(String key) => values.remove(key);
}

/// An HTTP request of `UrlFetchApp` (09 §6.7).
final class FetchRequestData {
  /// Creates a request.
  const FetchRequestData({
    required this.url,
    this.method = 'get',
    this.headers = const {},
    this.payload,
    this.contentType,
    this.followRedirects = true,
    this.muteHttpExceptions = false,
    this.timeoutSeconds = 30,
  });

  /// From the API's options map.
  factory FetchRequestData.fromApi(String url, Map<String, Object?>? o) {
    final headers = <String, String>{};
    final h = o?['headers'];
    if (h is Map) {
      for (final e in h.entries) {
        headers['${e.key}'] = '${e.value}';
      }
    }
    return FetchRequestData(
      url: url,
      method: (o?['method'] as String?)?.toLowerCase() ?? 'get',
      headers: headers,
      payload: o?['payload'] as String?,
      contentType: o?['contentType'] as String?,
      followRedirects: o?['followRedirects'] as bool? ?? true,
      muteHttpExceptions: o?['muteHttpExceptions'] as bool? ?? false,
      timeoutSeconds: (o?['timeoutSeconds'] as int? ?? 30).clamp(1, 60),
    );
  }

  /// URL (https only unless the server allows http).
  final String url;

  /// HTTP method, lower case.
  final String method;

  /// Request headers.
  final Map<String, String> headers;

  /// Body.
  final String? payload;

  /// Content type of [payload].
  final String? contentType;

  /// Whether redirects are followed (max 5, each validated).
  final bool followRedirects;

  /// Whether HTTP error statuses are returned instead of thrown.
  final bool muteHttpExceptions;

  /// Timeout (≤ 60 s).
  final int timeoutSeconds;

  /// JSON form (endpoint payloads).
  Map<String, Object?> toJson() => {
    'url': url,
    'method': method,
    'headers': headers,
    'payload': payload,
    'contentType': contentType,
    'followRedirects': followRedirects,
    'muteHttpExceptions': muteHttpExceptions,
    'timeoutSeconds': timeoutSeconds,
  };

  /// From [toJson].
  static FetchRequestData fromJson(Map<String, Object?> j) =>
      FetchRequestData.fromApi(j['url']! as String, j);
}

/// An HTTP response for `UrlFetchApp`.
final class FetchResponseData {
  /// Creates a response.
  const FetchResponseData({
    required this.statusCode,
    this.headers = const {},
    required this.bytes,
    required this.contentText,
  });

  /// Status code.
  final int statusCode;

  /// Response headers (lower-case names).
  final Map<String, String> headers;

  /// Body.
  final Uint8List bytes;

  /// Body decoded per charset.
  final String contentText;

  /// The value scripts receive.
  Map<String, Object?> toApi() => {
    'statusCode': statusCode,
    'headers': headers,
    'contentText': contentText,
    'bytes': bytes,
  };
}

/// Why a fetch failed (`UrlFetchException`).
final class FetchFailure implements Exception {
  /// Creates a failure; [statusCode] 0 when no response was received.
  const FetchFailure(
    this.message, {
    this.statusCode = 0,
    this.code = 'url_fetch',
  });

  /// Message.
  final String message;

  /// HTTP status (0 = none).
  final int statusCode;

  /// `url_fetch`, `offline`, `quota_exceeded` or `scope_not_granted`.
  final String code;

  @override
  String toString() => 'FetchFailure($code, $statusCode): $message';
}

/// Performs `UrlFetchApp` requests: the client forwards to the server proxy
/// (`ScriptEndpoint.urlFetch`), the server uses its SSRF-safe proxy directly.
abstract interface class UrlFetcher {
  /// Fetches [request]; throws [FetchFailure].
  Future<FetchResponseData> fetch(
    FetchRequestData request, {
    required bool customFunction,
  });
}

/// An installable trigger as scripts see it (`Trigger`).
final class ScriptTriggerInfo {
  /// Creates the info.
  const ScriptTriggerInfo({
    required this.uid,
    required this.functionName,
    required this.eventType,
    this.scheduleJson,
    this.runAsUserId,
    this.enabled = true,
  });

  /// Trigger id.
  final String uid;

  /// Target function.
  final String functionName;

  /// `timeDriven`, `onEdit`, `onChange`, `installableOnOpen`.
  final String eventType;

  /// Schedule of time-driven triggers.
  final String? scheduleJson;

  /// Installer.
  final String? runAsUserId;

  /// Whether the trigger is enabled.
  final bool enabled;

  /// The value scripts receive.
  Map<String, Object?> toApi() => {
    'uid': uid,
    'functionName': functionName,
    'eventType': eventType,
  };
}

/// Clock abstraction for scripts (deterministic tests).
typedef ScriptNow = DateTime Function();

/// Waits for [future] up to [timeout], returning [fallback] afterwards.
Future<T> withTimeoutOr<T>(Future<T> future, Duration timeout, T fallback) =>
    future.timeout(timeout, onTimeout: () => fallback);
