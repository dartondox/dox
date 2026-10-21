import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_websocket/dox_websocket.dart';
import 'package:ioredis/ioredis.dart';
import 'package:test/test.dart';

import 'config/app_config.dart';
import 'websocket_rooms_test.dart' show Client, RoomsRouter, roomId;

const int port = 3006;

/// CI has redis on 6379. Locally set REDIS_PORT to use another port.
final String redisHost = Platform.environment['REDIS_HOST'] ?? '127.0.0.1';
final int redisPort = int.parse(Platform.environment['REDIS_PORT'] ?? '6379');

Redis newRedis() => Redis(RedisOptions(host: redisHost, port: redisPort));

Future<bool> redisReachable() async {
  try {
    Socket s = await Socket.connect(redisHost, redisPort,
        timeout: Duration(seconds: 1));
    s.destroy();
    return true;
  } catch (_) {
    return false;
  }
}

class RedisWebsocketService implements DoxService {
  @override
  void setup() {
    Redis sub = newRedis();
    WebsocketServer(Dox()).adapter(WebsocketRedisAdapter(
      subscriber: sub,
      publisher: sub.duplicate(),
    ));
  }
}

void main() async {
  bool up = await redisReachable();

  group('Websocket redis adapter |', () {
    setUpAll(() async {
      Dox().initialize(AppConfig(
        appKey: appConfig.appKey,
        serverPort: port,
        totalIsolate: 1,
        responseHandler: appConfig.responseHandler,
        routers: <Router>[RoomsRouter()],
        cache: appConfig.cache,
      ));
      Dox().addService(RedisWebsocketService());
      await Dox().startServer();
      // let the adapter finish its subscribe call
      await Future<void>.delayed(Duration(milliseconds: 300));
    });

    tearDownAll(() async {
      await Dox().server.close();
    });

    test('emit goes through redis and reaches all clients', () async {
      Client a = await Client.connect(port);
      Client b = await Client.connect(port);
      a.send('all', 'via redis');
      expect((await a.next('all'))['message'], 'via redis');
      expect((await b.next('all'))['message'], 'via redis');
      await a.close();
      await b.close();
    });

    test('event published by another server reaches local clients', () async {
      Client a = await Client.connect(port);
      Redis other = newRedis();
      await other.publish(
        'dox_websocket_redis_adapter_new_emitter',
        WebsocketEmitEvent(
          senderId: 'ws:other-server',
          roomId: roomId(),
          message: 'from far away',
          event: 'remote',
          exclude: <String>[],
        ).toString(),
      );
      Map<String, dynamic> got = await a.next('remote');
      expect(got['message'], 'from far away');
      expect(got['sender'], 'ws:other-server');
      await other.disconnect();
      await a.close();
    });
  }, skip: up ? false : 'redis not reachable on $redisHost:$redisPort');
}
