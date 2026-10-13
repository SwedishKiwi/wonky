import 'dart:async';

import 'package:serverpod/serverpod.dart';

import '../../common/errors.dart';
import '../../common/models.dart';
import '../../config/wonky_config.dart';
import '../../users/user_service.dart';
import 'ui_bridge_hub.dart';

/// The UI bridge stream (suite 09 §6.1): a signed-in app window that allows
/// MCP control connects here; `ui.*` tool calls are relayed to it as
/// [UiBridgeRequest]s and answered with [UiBridgeResponse]s.
class UiBridgeEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  Stream<UiBridgeMessage> connect(
    Session session,
    Stream<UiBridgeMessage> fromApp,
  ) {
    late final StreamController<UiBridgeMessage> out;
    StreamSubscription<UiBridgeMessage>? input;
    UiBridgeWindow? window;
    var closed = false;

    Future<void> close() async {
      if (closed) return;
      closed = true;
      if (window != null) UiBridgeHub.unregister(window!);
      await input?.cancel();
      if (!out.isClosed) await out.close();
    }

    void send(UiBridgeMessage m) {
      if (!out.isClosed) out.add(m);
    }

    out = StreamController<UiBridgeMessage>(
      onListen: () async {
        try {
          if (!WonkyConfig.current.mcpUiBridgeEnabled) {
            throw Errors.unavailable('The MCP UI bridge is disabled.');
          }
          final actor = await UserService.actorOf(session);
          input = fromApp.listen(
            (m) {
              switch (m) {
                case UiBridgeHello():
                  final previous = window;
                  if (previous != null) UiBridgeHub.unregister(previous);
                  final w = UiBridgeHub.register(
                    session,
                    actor.userId,
                    m,
                    send,
                  );
                  window = w;
                  send(UiBridgeWelcome(sessionId: w.sessionId));
                case UiBridgeStatus():
                  if (window != null) UiBridgeHub.update(window!, m);
                case UiBridgeResponse():
                  if (window != null) UiBridgeHub.complete(window!, m);
                case UiBridgeStop():
                  if (window != null) {
                    UiBridgeHub.stop(
                      window!,
                      Duration(milliseconds: m.pauseMs.clamp(0, 3600000)),
                    );
                  }
                default:
                  break;
              }
            },
            onDone: close,
            onError: (Object _) => close(),
          );
          session.addWillCloseListener((_) => close());
        } on Object catch (e, st) {
          if (!out.isClosed) out.addError(e, st);
          await close();
        }
      },
      onCancel: close,
    );
    return out.stream;
  }
}
