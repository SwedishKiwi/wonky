import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wonky_app/src/mcp_bridge/developer_settings.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_ui/testing.dart';

/// Token storage for the settings tests.
class _TokenUsers extends FakeUserRepository {
  final tokens = <AccessTokenView>[];

  @override
  Future<List<AccessTokenView>> listTokens() async => [...tokens];

  @override
  Future<void> revokeToken(int id) async {
    final i = tokens.indexWhere((t) => t.id == id);
    tokens[i] = tokens[i].copyWith(revokedAt: DateTime.utc(2026, 10, 2));
  }
}

void main() {
  late CommandTestHarness h;
  late _TokenUsers users;

  setUp(() {
    users = _TokenUsers();
    h = CommandTestHarness(users: users);
  });
  tearDown(() => h.dispose());

  Future<void> pump(WidgetTester tester, Brightness b) async {
    await pumpWonky(
      tester,
      SingleChildScrollView(child: McpDeveloperSettings(services: h.services)),
      brightness: b,
      size: const Size(1200, 1400),
      extraDelegates: const [WonkyAppLocalizations.delegate],
      wrap: (context, child) =>
          Provider<ShellServices>.value(value: h.services, child: child!),
    );
    await tester.pumpAndSettle();
  }

  for (final b in Brightness.values) {
    testWidgets('Given no tokens in ${b.name} when the section shows then the '
        'empty state and the Claude Code command are shown', (tester) async {
      await pump(tester, b);

      expect(find.text('No tokens yet.'), findsOneWidget);
      final snippet = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('settings.mcp.snippet')),
          matching: find.byType(Text),
        ),
      );
      expect(snippet.data, contains('claude mcp add --transport http wonky'));
      expect(snippet.data, contains('/mcp'));
    });
  }

  testWidgets('Given a token when revoking it then it is marked revoked', (
    tester,
  ) async {
    users.tokens.add(
      AccessTokenView(
        id: 1,
        name: 'Laptop',
        prefix: 'wkpat_ab12',
        scopes: const ['write:read'],
        createdAt: DateTime.utc(2026, 10),
      ),
    );
    await pump(tester, Brightness.light);
    expect(find.textContaining('wkpat_ab12'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('settings.mcp.revoke.1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('dialog.confirm.confirm')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Laptop · revoked'), findsOneWidget);
    await settleTooltips(tester);
  });

  testWidgets('Given the bridge switch when toggled then MCP control flips', (
    tester,
  ) async {
    await pump(tester, Brightness.light);
    final before = h.services.mcp.enabled;

    await tester.tap(find.byKey(const ValueKey<String>('settings.mcp.bridge')));
    await tester.pumpAndSettle();

    expect(h.services.mcp.enabled, !before);
  });
}
