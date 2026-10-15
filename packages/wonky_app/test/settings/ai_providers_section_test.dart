import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';

import '../support/screen_pump.dart';

void main() {
  late CommandTestHarness h;
  late FakeAssistantApi api;

  AssistantStatus notConfigured({bool userKeysAllowed = true}) =>
      AssistantStatus(
        available: false,
        reason: 'notConfigured',
        quality: AiQuality.best,
        tokensUsedToday: 0,
        dailyTokenBudget: 0,
        userKeysAllowed: userKeysAllowed,
      );

  setUp(() {
    h = CommandTestHarness();
    h.services.router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SizedBox()),
        GoRoute(
          path: '/settings/:section',
          builder: (_, _) => const SizedBox(),
        ),
      ],
    );
  });
  tearDown(() => h.dispose());

  Future<void> pump(WidgetTester tester, AssistantStatus status) async {
    api = FakeAssistantApi(status: status);
    ShellAssistant.install(h.services, api: api);
    await pumpScreen(
      tester,
      h,
      SettingsScreen(
        services: h.services,
        section: ShellAssistant.aiProvidersSection,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Given no server key when the user saves a key then it is sent once and '
    'only its last four characters are shown',
    (tester) async {
      await pump(tester, notConfigured());

      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey<String>('settings.aiProviders.key')),
          matching: find.byType(EditableText),
        ),
        'sk-test-0123456789-abcd',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('settings.aiProviders.save')),
      );
      await tester.pumpAndSettle();

      expect(api.savedKeys, [(AiProvider.openai, 'sk-test-0123456789-abcd')]);
      expect(find.text('OpenAI key ending in abcd'), findsOneWidget);
      expect(find.textContaining('0123456789'), findsNothing);
    },
  );

  testWidgets(
    'Given a saved key when the user removes it then AI is not configured',
    (tester) async {
      await pump(tester, notConfigured());
      await api.setProviderKey(AiProvider.anthropic, 'sk-ant-0123456789-wxyz');
      await ShellAssistant.of(h.services)!.refreshStatus();
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('settings.aiProviders.remove')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove key').last);
      await tester.pumpAndSettle();

      expect(api.status.reason, 'notConfigured');
      expect(find.textContaining('wxyz'), findsNothing);
    },
  );

  testWidgets(
    'Given the server provides AI when the page shows then no key form is '
    'offered',
    (tester) async {
      await pump(
        tester,
        AssistantStatus(
          available: true,
          quality: AiQuality.best,
          tokensUsedToday: 0,
          dailyTokenBudget: 0,
          provider: AiProvider.anthropic,
          keySource: 'server',
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('settings.aiProviders.server')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('settings.aiProviders.key')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Given personal keys are off when the page shows then it says so',
    (tester) async {
      await pump(tester, notConfigured(userKeysAllowed: false));

      expect(
        find.byKey(const ValueKey<String>('settings.aiProviders.notAllowed')),
        findsOneWidget,
      );
    },
  );
}
