import 'package:dox_app/config/redis.dart';
import 'package:dox_core/dox_core.dart';
import 'package:dox_websocket/dox_websocket.dart';
import 'package:ioredis/ioredis.dart';

class WebsocketService implements DoxService {
  @override
  void setup() {
    Redis sub = redis;
    Redis pub = sub.duplicate();

    WebsocketServer io = WebsocketServer(Dox());
    io.adapter(WebsocketRedisAdapter(
      subscriber: sub,
      publisher: pub,
    ));
  }
}
