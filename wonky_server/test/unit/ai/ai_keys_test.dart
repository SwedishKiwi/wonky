import 'package:test/test.dart';
import 'package:wonky_server/src/platform/ai/ai_config.dart';
import 'package:wonky_server/src/platform/ai/ai_keys.dart';
import 'package:wonky_server/src/platform/ai/ai_models.dart';
import 'package:wonky_server/src/platform/common/models.dart';

AiUserKey _userKey(AiProvider provider, String key) => AiUserKey(
  userId: 1,
  provider: provider,
  apiKey: key,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  group('Given key resolution (server key > user key > none)', () {
    test('when the server has a key then it is used over the user key', () {
      final config = AiConfig(serverKeys: {AiProvider.openai: 'sk-server'});

      final c = AiKeys.resolve(
        config,
        userKey: _userKey(AiProvider.gemini, 'user-key-0123456789'),
      );

      expect(c?.provider, AiProvider.openai);
      expect(c?.apiKey, 'sk-server');
      expect(c?.source, AiKeySource.server);
    });

    test('when the server has no key then the user key is used', () {
      final c = AiKeys.resolve(
        AiConfig(),
        userKey: _userKey(AiProvider.gemini, ' user-key-0123456789 '),
      );

      expect(c?.provider, AiProvider.gemini);
      expect(c?.apiKey, 'user-key-0123456789');
      expect(c?.source, AiKeySource.user);
    });

    test('when there is neither then AI is not configured', () {
      expect(AiKeys.resolve(AiConfig()), isNull);
    });

    test('when personal keys are off then a user key is ignored', () {
      final c = AiKeys.resolve(
        AiConfig(allowUserKeys: false),
        userKey: _userKey(AiProvider.openai, 'user-key-0123456789'),
      );

      expect(c, isNull);
    });

    test('when a blank server key is configured then it does not count', () {
      final config = AiConfig(serverKeys: {AiProvider.anthropic: '  '});

      expect(config.configured, isFalse);
      expect(config.userKeysAllowed, isTrue);
    });
  });

  group('Given several server keys', () {
    final keys = {
      AiProvider.openai: 'sk-openai',
      AiProvider.anthropic: 'sk-ant',
      AiProvider.gemini: 'g-key',
    };

    test('when no provider is configured then Anthropic is preferred', () {
      expect(AiConfig(serverKeys: keys).serverProvider, AiProvider.anthropic);
    });

    test('when a provider is configured then it is used', () {
      final config = AiConfig(serverKeys: keys, provider: AiProvider.gemini);

      expect(config.serverProvider, AiProvider.gemini);
      expect(AiKeys.resolve(config)?.apiKey, 'g-key');
    });

    test('when the configured provider has no key then another is used', () {
      final config = AiConfig(
        serverKeys: {AiProvider.openai: 'sk-openai'},
        provider: AiProvider.anthropic,
      );

      expect(config.serverProvider, AiProvider.openai);
      expect(config.userKeysAllowed, isFalse);
    });
  });

  group('Given the ai config section', () {
    test('when provider and models are set then they are read', () {
      final config = AiConfig.fromMap({
        'provider': 'google',
        'allowUserKeys': false,
        'models': {
          'gemini': {'model': 'gemini-x-pro'},
          'anthropic': {'model': 'claude-a', 'fastModel': 'claude-b'},
        },
      });

      expect(config.provider, AiProvider.gemini);
      expect(config.allowUserKeys, isFalse);
      expect(
        config.modelFor(AiProvider.gemini, AiModelSize.large),
        'gemini-x-pro',
      );
      expect(
        config.modelFor(AiProvider.gemini, AiModelSize.small),
        AiModels.geminiFlash,
      );
      expect(
        config.modelFor(AiProvider.anthropic, AiModelSize.small),
        'claude-b',
      );
    });

    test('when nothing is set then each provider has its defaults', () {
      final config = AiConfig.fromMap(const {});

      expect(config.provider, isNull);
      expect(config.allowUserKeys, isTrue);
      expect(
        [
          for (final p in AiProvider.values)
            config.modelFor(p, AiModelSize.large),
        ],
        [AiModels.gpt, AiModels.opus, AiModels.geminiPro],
      );
    });

    test('when the environment names a provider then it wins', () {
      final config = AiConfig.fromMap(
        {'provider': 'anthropic'},
        environment: {'WONKY_AI_PROVIDER': 'openai'},
      );

      expect(config.provider, AiProvider.openai);
    });
  });

  group('Given a stored key', () {
    test('when shown then only the last four characters are visible', () {
      final view = AiKeys.view(
        _userKey(AiProvider.openai, 'sk-proj-secret-abcd'),
      );

      expect(view.last4, 'abcd');
      expect(view.toJson().toString(), isNot(contains('secret')));
    });
  });
}
