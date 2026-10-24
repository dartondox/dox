import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_websocket/dox_websocket.dart';
import 'package:ioredis/ioredis.dart';
import 'package:test/test.dart';

import 'config/app_config.dart';
import 'config/redis_env.dart';

int get port => Dox().server.httpServer.port;

class RoomEmitRouter implements Router {
  @override
  List<dynamic> get middleware => <dynamic>[];

  @override
  String get prefix => '';

  @override
  void register() {
    Route.websocket('ws', (WebsocketEvent event) {
      /// emit to a joined room by its plain name, as the docs show
      event.on('toRoom', (WebsocketEmitter emitter, dynamic message) {
        emitter.room(message['room']).emit('toRoom', message['text']);
      });

      /// emit without a room, goes to the room of the connection
      event.on('plain', (WebsocketEmitter emitter, dynamic message) {
        emitter.emit('plain', message);
      });
    });
  }
}

/// test client that keeps every message it gets
class Client {
  final WebSocket socket;
  final List<Map<String, dynamic>> messages = <Map<String, dynamic>>[];

  Client(this.socket) {
    socket.listen((dynamic data) => messages.add(jsonDecode(data)));
  }

  static Future<Client> connect() async {
    Client c = Client(await WebSocket.connect('ws://localhost:$port/ws'));
    await Future<void>.delayed(Duration(milliseconds: 100));
    return c;
  }

  void send(String event, dynamic message) {
    socket.add(
      jsonEncode(<String, dynamic>{'event': event, 'message': message}),
    );
  }

  List<dynamic> got(String event) => messages
      .where((Map<String, dynamic> m) => m['event'] == event)
      .map((Map<String, dynamic> m) => m['message'])
      .toList();
}

Future<void> wait() => Future<void>.delayed(Duration(milliseconds: 300));

Future<bool> redisReachable() async {
  try {
    Socket s = await Socket.connect(
      redisHost,
      redisPort,
      timeout: Duration(milliseconds: 500),
    );
    s.destroy();
    return true;
  } catch (_) {
    return false;
  }
}

/// check that emit to a joined room reaches its members only
Future<void> roomEmitCheck() async {
  Client a = await Client.connect();
  Client b = await Client.connect();
  Client outside = await Client.connect();
  a.send('joinRoom', 'chat');
  b.send('joinRoom', 'chat');
  await wait();

  a.send('toRoom', <String, String>{'room': 'chat', 'text': 'hi'});
  await wait();
  expect(a.got('toRoom'), <String>['hi']);
  expect(b.got('toRoom'), <String>['hi']);
  expect(outside.got('toRoom'), isEmpty);

  /// room() must not stick: a plain emit after it goes to the
  /// route room (where `outside` still is), not to chat
  a.send('plain', 'again');
  await wait();
  expect(outside.got('plain'), <String>['again']);
  expect(b.got('plain'), isEmpty);

  await a.socket.close();
  await b.socket.close();
  await outside.socket.close();
}

void main() {
  setUpAll(() async {
    Dox().initialize(
      AppConfig(
        appKey: appConfig.appKey,
        // the OS picks a free port, so test files can run in parallel
        serverPort: 0,
        totalIsolate: 1,
        responseHandler: appConfig.responseHandler,
        routers: <Router>[RoomEmitRouter()],
        cache: appConfig.cache,
      ),
    );
    WebsocketServer(Dox()).authorizeJoin = (IDoxRequest req, String room) =>
        true;
    await Dox().startServer();
  });

  tearDownAll(() async {
    await Dox().server.close();
  });

  test('room emit | in-memory', roomEmitCheck);

  test('room emit | redis adapter', () async {
    if (!await redisReachable()) {
      markTestSkipped('redis is not reachable on $redisHost:$redisPort');
      return;
    }
    Redis sub = testRedis();
    WebsocketServer().adapter(
      WebsocketRedisAdapter(subscriber: sub, publisher: sub.duplicate()),
    );
    await wait();
    await roomEmitCheck();
  });
}
