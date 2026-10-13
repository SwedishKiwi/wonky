import 'package:serverpod/serverpod.dart';

import '../../sheets/versions/sheets_version_provider.dart';
import '../common/models.dart';
import '../common/time.dart';
import '../config/wonky_config.dart';

/// Protocol information checked by clients on connect (specs/01 §7).
class MetaEndpoint extends Endpoint {
  static String? _hash;

  Future<ProtocolInfo> getInfo(Session session) async {
    final c = WonkyConfig.current;
    final redis = session.serverpod.redisController;
    return ProtocolInfo(
      redisEnabled: redis != null,
      redisConnected: redis != null && await _ping(redis),
      serverVersion: c.serverVersion,
      minClientVersion: c.minClientVersion,
      syncTablesHash: _hash ??= SheetsVersionProvider.syncTablesHashOf(),
      runMode: session.serverpod.runMode,
      features: FeatureFlags(
        ai: c.aiEnabled,
        scripting: c.scriptingEnabled,
        mcpUiBridge: c.mcpUiBridgeEnabled,
        experimentalCharts: c.experimentalCharts,
      ),
      limits: ServerLimits(
        maxCellsPerSpreadsheet: c.maxCellsPerSpreadsheet,
        maxActiveSpacesPerUser: c.maxActiveSpacesPerUser,
        maxSheetsPerSpreadsheet: c.maxSheetsPerSpreadsheet,
        maxDocumentChars: c.maxDocumentChars,
        maxImageUploadBytes: c.maxImageUploadBytes,
        maxImportUploadBytes: c.maxImportUploadBytes,
        scriptTimeoutMs: c.scriptTimeoutMs,
      ),
      serverTime: nowUtc(),
    );
  }

  /// Whether Redis answers a ping (briefly: clients call this on connect).
  static Future<bool> _ping(RedisController redis) async {
    try {
      return await redis.ping().timeout(const Duration(seconds: 1));
    } catch (_) {
      return false;
    }
  }
}
