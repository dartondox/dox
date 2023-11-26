import 'package:dox_websocket/src/adapters/websocket_adapter.dart';
import 'package:dox_websocket/src/websocket_emit_event.dart';
import 'package:dox_websocket/src/websocket_emitter.dart';
import 'package:ioredis/ioredis.dart';

class WebsocketRedisAdapter implements WebsocketAdapterInterface {
  final String _channelKey = 'dox_websocket_redis_adapter_new_emitter';

  bool _alreadyListen = false;

  final Redis subscriber;
  final Redis publisher;

  WebsocketRedisAdapter({
    required this.subscriber,
    required this.publisher,
  }) {
    listen();
  }

  @override
  emit(WebsocketEmitEvent event) async {
    publisher.publish(_channelKey, event.toString());
  }

  Future<void> listen() async {
    /// end if already listen;
    if (_alreadyListen) return;
    _alreadyListen = true;

    RedisSubscriber sub = await subscriber.subscribe(_channelKey);
    sub.onMessage = (String channel, String? message) {
      if (message != null && message.isNotEmpty) {
        WebsocketEmitEvent event = WebsocketEmitEvent.fromString(message);
        WebsocketEmitter.emitEventToSockets(event);
      }
    };
  }
}
