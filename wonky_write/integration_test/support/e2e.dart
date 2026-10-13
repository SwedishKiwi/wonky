import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    show AuthSuccess, ClientAuthSuccessStorage;
import 'package:super_editor/super_editor_test.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_write/main.dart' as app;

/// E2E support for the Write journeys (specs/11 §1.1, specs/15 §9). The
/// tests run against the development server started with `serverpod
/// start`; [apiUrl] can be overridden with `--dart-define=WONKY_E2E_API=…`.
const apiUrl = String.fromEnvironment(
  'WONKY_E2E_API',
  defaultValue: 'http://localhost:8080/',
);

/// A per-run id so every test creates its own users and documents.
final runId = DateTime.now().millisecondsSinceEpoch.toRadixString(36);

/// A unique `@example.test` address (the e2eSupport endpoint only serves
/// codes for this domain).
String e2eEmail(String name) => 'e2e+$runId-${name.toLowerCase()}@example.test';

const e2ePassword = 'Wonky-e2e-Passw0rd!';

/// Lets real time pass (network, timers) and pumps a frame. Pumping alone
/// does not yield to the event loop on the live test binding.
Future<void> settle(
  WidgetTester tester, [
  Duration duration = const Duration(milliseconds: 100),
]) async {
  await Future<void>.delayed(duration);
  await tester.pump();
}

/// Polls (pumping frames) until [finder] finds something, or fails after
/// [timeout]. Real network round trips make `pumpAndSettle` unusable.
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
  String? reason,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await settle(tester);
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure(
    'Timed out waiting for ${reason ?? finder}. On screen: ${visibleTexts()}',
  );
}

/// The texts on screen (for failure messages).
List<String> visibleTexts() => [
  for (final e in find.byType(RichText).evaluate())
    (e.widget as RichText).text.toPlainText(),
].where((t) => t.trim().isNotEmpty).take(60).toList();

/// Polls [condition] (pumping frames) until it holds.
Future<void> pumpUntilTrue(
  WidgetTester tester,
  FutureOr<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 30),
  required String reason,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await settle(tester, const Duration(milliseconds: 300));
    if (await condition()) return;
  }
  throw TestFailure('Timed out waiting for $reason');
}

/// Boots Wonky Write and waits for the sign-in screen, signing out a
/// session restored from an earlier run.
Future<void> launchSignedOut(WidgetTester tester) async {
  // A laptop-sized surface (the macOS runner window starts at 800x600).
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  WonkyClient.sessionStorageOverride = MemorySessionStorage();
  _errorWidgetBuilder = ErrorWidget.builder;
  app.main();
  final signIn = find.byKey(const ValueKey<String>('auth.signIn.submit'));
  final shell = find.byKey(const ValueKey<String>('shell.notifications'));
  await pumpUntil(
    tester,
    find.byWidgetPredicate((w) {
      final k = w.key;
      return k == const ValueKey<String>('auth.signIn.submit') ||
          k == const ValueKey<String>('shell.notifications');
    }),
    timeout: const Duration(seconds: 60),
    reason: 'the app to start',
  );
  if (shell.evaluate().isNotEmpty) {
    await services(tester).auth.signOut();
    await pumpUntil(tester, signIn, reason: 'the sign-in screen');
  }
}

ErrorWidgetBuilder? _errorWidgetBuilder;

/// Logs a journey step (visible in the `flutter test` output).
void journeyStep(String step) => debugPrint('[e2e $runId] $step');

/// Ends a journey: unmounts the app, lets pending frame callbacks and
/// animations finish and restores what the shell changed globally.
Future<void> endJourney(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  for (var i = 0; i < 10; i++) {
    await settle(tester);
  }
  if (_errorWidgetBuilder case final b?) ErrorWidget.builder = b;
}

/// The shell services of the running app.
ShellServices services(WidgetTester tester) {
  final anchor = find.byKey(const ValueKey<String>('shell.notifications'));
  final context = anchor.evaluate().isNotEmpty
      ? anchor.evaluate().first
      : find.byType(Router<Object>).evaluate().first;
  return ShellScope.of(context);
}

/// The localized strings of the shell (for finding menu entries by text).
WonkyAppLocalizations shellL10n(WidgetTester tester) =>
    WonkyAppLocalizations.of(find.byType(Router<Object>).evaluate().first);

/// Enters [text] into the text field below the widget with key [key].
Future<void> enterField(WidgetTester tester, String key, String text) async {
  final field = find.descendant(
    of: find.byKey(ValueKey<String>(key)),
    matching: find.byType(EditableText),
  );
  await tester.tap(field.first);
  await tester.pump();
  await tester.enterText(field.first, text);
  await tester.pump();
}

/// Signs in through the sign-in screen.
Future<void> signInWithUi(
  WidgetTester tester, {
  required String email,
  String password = e2ePassword,
}) async {
  await enterField(tester, 'auth.signIn.email', email);
  await enterField(tester, 'auth.signIn.password', password);
  await tester.tap(find.byKey(const ValueKey<String>('auth.signIn.submit')));
  await pumpUntil(
    tester,
    find.byKey(const ValueKey<String>('shell.notifications')),
    reason: 'the home screen after signing in',
  );
}

/// Creates a blank document from the drive's New menu and waits for the
/// editor.
Future<void> createDocumentWithUi(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('drive.new')));
  await settle(tester, const Duration(milliseconds: 300));
  await pumpUntil(tester, find.text(shellL10n(tester).menuNewDocument));
  await tester.tap(find.text(shellL10n(tester).menuNewDocument).last);
  await waitForEditor(tester);
}

/// Waits until the Write editor shows and its document is loaded.
Future<void> waitForEditor(WidgetTester tester) async {
  await pumpUntil(
    tester,
    find.byKey(const ValueKey<String>('write.editor')),
    timeout: const Duration(seconds: 45),
    reason: 'the editor',
  );
  await settle(tester, const Duration(seconds: 1));
}

/// Types [text] through the IME, the way a user does on web and desktop.
Future<void> typeInEditor(WidgetTester tester, String text) async {
  await tester.typeImeText(text);
  await settle(tester, const Duration(milliseconds: 200));
}

/// Runs a command through the app's dispatcher (the same path as menus,
/// toolbar and shortcuts).
Future<void> runCommand(
  WidgetTester tester,
  String id, {
  Map<String, Object?> args = const {},
}) async {
  final s = services(tester);
  final result = await s.dispatcher.invoke(
    id,
    args: args,
    context:
        find.byKey(const ValueKey<String>('write.editor')).evaluate().isEmpty
        ? null
        : find.byKey(const ValueKey<String>('write.editor')).evaluate().first,
  );
  await settle(tester, const Duration(milliseconds: 200));
  expect(result.isOk, isTrue, reason: '$id: $result');
}

/// The uuid of the document open in the editor (from the route).
UuidValue openDocumentUuid(WidgetTester tester) {
  final path = services(tester).router.state.uri.path;
  final match = RegExp(r'/d/([0-9a-f-]{36})').firstMatch(path);
  if (match == null) throw TestFailure('No document is open ($path)');
  return UuidValue.fromString(match.group(1)!);
}

/// Keeps the app's session in memory (see
/// `WonkyClient.sessionStorageOverride`).
class MemorySessionStorage implements ClientAuthSuccessStorage {
  AuthSuccess? _value;

  @override
  Future<AuthSuccess?> get() async => _value;

  @override
  Future<void> set(AuthSuccess? data) async => _value = data;
}

// ------------------------------------------------------- scripted client

class _BearerKey implements ClientAuthKeyProvider {
  _BearerKey(this.token);
  final String token;

  @override
  Future<String?> get authHeaderValue async =>
      wrapAsBearerAuthHeaderValue(token);
}

/// A second user driven through the generated client (specs/15 §9:
/// "one app instance plus a scripted second client").
class E2eClient {
  E2eClient._(this.client, this.email, this.profile);

  final Client client;
  final String email;
  final UserProfileView profile;

  int get userId => profile.summary.id;

  /// Signs up [name] through the email IDP with the code from e2eSupport.
  static Future<E2eClient> signUp(String name) async {
    final email = e2eEmail(name);
    final client = Client(apiUrl);
    final requestId = await client.emailIdp.startRegistration(email: email);
    final code = await verificationCode(client, email);
    final token = await client.emailIdp.verifyRegistrationCode(
      accountRequestId: requestId,
      verificationCode: code,
    );
    final auth = await client.emailIdp.finishRegistration(
      registrationToken: token,
      password: e2ePassword,
    );
    client.authKeyProvider = _BearerKey(auth.token);
    final profile = await client.user.updateProfile(displayName: name);
    return E2eClient._(client, email, profile);
  }

  /// Signs in an existing account.
  static Future<E2eClient> signIn(String email) async {
    final client = Client(apiUrl);
    final auth = await client.emailIdp.login(
      email: email,
      password: e2ePassword,
    );
    client.authKeyProvider = _BearerKey(auth.token);
    return E2eClient._(client, email, await client.user.getMe());
  }

  /// The latest sign-up code of [email] (development/test run modes only).
  static Future<String> verificationCode(Client client, String email) async {
    for (var i = 0; i < 50; i++) {
      final code = await client.e2eSupport.latestVerificationCode(email);
      if (code != null) return code;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    throw TestFailure('No verification code for $email');
  }

  /// The current content of a document as a Quill Delta (list of ops).
  Future<List<Map<String, Object?>>> documentDelta(UuidValue itemUuid) async {
    final info = await client.drive.get(itemUuid);
    final snap = await client.document.getSnapshot(info.contentRef!, null);
    return [
      for (final op in jsonDecode(snap.deltaJson) as List<Object?>)
        (op as Map).cast<String, Object?>(),
    ];
  }

  /// The plain text of a document.
  Future<String> documentText(UuidValue itemUuid) async => [
    for (final op in await documentDelta(itemUuid))
      if (op['insert'] is String) op['insert'] as String,
  ].join();

  void close() => client.close();
}
