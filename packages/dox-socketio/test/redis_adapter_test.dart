@Timeout(Duration(seconds: 60))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dox_socketio/dox_socketio.dart';
import 'package:ioredis/ioredis.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;
import 'package:test/test.dart';

import 'support/node_runner.dart';
import 'support/test_app.dart';

/// Locally: docker run -d --name dox-sio-redis -p 6409:6379 redis:7-alpine
/// and REDIS_PORT=6409. CI uses the redis service on 6379.
final String redisHost = Platform.environment['REDIS_HOST'] ?? '127.0.0.1';
final int redisPort = int.parse(Platform.environment['REDIS_PORT'] ?? '6379');

String? redisSkipReason() {
  try {
    // A sync check, so the tests can be skipped before they are declared.
    ProcessResult result =
        Process.runSync('nc', <String>['-z', redisHost, '$redisPort']);
    return result.exitCode == 0
        ? null
        : 'redis is not reachable at $redisHost:$redisPort';
  } on ProcessException {
    return null; // No nc. Try anyway.
  }
}

RedisAdapter newAdapter() {
  Redis subscriber = Redis(RedisOptions(host: redisHost, port: redisPort));
  return RedisAdapter(
      subscriber: subscriber, publisher: subscriber.duplicate());
}

Future<sio.Socket> connectClient(String url, String room) async {
  sio.Socket socket = sio.io(
    url,
    sio.OptionBuilder()
        .setTransports(<String>['websocket'])
        .disableReconnection()
        .enableForceNew()
        .build(),
  );
  Completer<void> joined = Completer<void>();
  socket.onConnect(_JoinRoom(socket, room, joined).call);
  await joined.future.timeout(Duration(seconds: 5));
  return socket;
}

/// Joins a room once the socket is connected.
class _JoinRoom {
  _JoinRoom(this.socket, this.room, this.joined);

  final sio.Socket socket;
  final String room;
  final Completer<void> joined;

  void call(dynamic _) => socket.emitWithAck('join', room, ack: onAck);

  void onAck(dynamic _) {
    if (!joined.isCompleted) joined.complete();
  }
}

void main() {
  String? skip = redisSkipReason();

  group('RedisAdapter', () {
    late TestApp serverA;
    late TestApp serverB;
    late RedisAdapter adapterA;
    late RedisAdapter adapterB;

    setUp(() async {
      adapterA = newAdapter();
      adapterB = newAdapter();
      serverA = TestApp(adapter: adapterA);
      serverB = TestApp(adapter: adapterB);
      await serverA.start();
      await serverB.start();
      await adapterA.ready();
      await adapterB.ready();
    });

    tearDown(() async {
      await serverA.stop();
      await serverB.stop();
    });

    test('a broadcast on one server reaches clients of the other', () async {
      sio.Socket inRoom = await connectClient(serverA.url, 'room1');
      sio.Socket outside = await connectClient(serverA.url, 'room2');
      Completer<Object?> got = Completer<Object?>();
      bool outsideGot = false;
      inRoom.on('cross', got.complete);
      outside.on('cross', (dynamic _) => outsideGot = true);

      await serverB.io.to('room1').emit('cross', <String, int>{'n': 1});
      expect(await got.future.timeout(Duration(seconds: 5)),
          <String, dynamic>{'n': 1});

      // local() must not leave server B.
      Completer<Object?> local = Completer<Object?>();
      inRoom.on('local', local.complete);
      await serverB.io.local.emit('local', 'x');
      await Future<void>.delayed(Duration(milliseconds: 300));
      expect(local.isCompleted, isFalse);
      expect(outsideGot, isFalse);
      inRoom.dispose();
      outside.dispose();
    });

    test('messages use the Node.js redis adapter JSON format', () async {
      Redis listener = Redis(RedisOptions(host: redisHost, port: redisPort));
      RedisSubscriber subscription = await listener.subscribe('socket.io#/#');
      Completer<String> message = Completer<String>();
      subscription.onMessage = (String channel, String? text) {
        if (!message.isCompleted && text != null) message.complete(text);
      };
      await serverA.io.to('r').except('x').emit('hello', 'world');
      List<dynamic> parts =
          jsonDecode(await message.future.timeout(Duration(seconds: 5)))
              as List<dynamic>;
      expect(parts[0], adapterA.uid);
      expect(parts[1], <String, dynamic>{
        'type': 2,
        'data': <String>['hello', 'world'],
        'nsp': '/',
      });
      expect(parts[2], <String, dynamic>{
        'rooms': <String>['r'],
        'except': <String>['x'],
        'flags': <String, dynamic>{},
      });
    });
  }, skip: skip);

  group('RedisAdapter with a Node.js server', () {
    late TestApp server;

    setUp(() async {
      RedisAdapter adapter = newAdapter();
      server = TestApp(adapter: adapter);
      await server.start();
      await adapter.ready();
    });

    tearDown(() => server.stop());

    test('Dart and Node.js servers share broadcasts', () async {
      NodeRunner node = NodeRunner();
      await node.install();
      sio.Socket dartClient = await connectClient(server.url, 'r1');
      Completer<Object?> fromNode = Completer<Object?>();
      dartClient.on('from-node', fromNode.complete);

      Process process = await node
          .start('redis-node.mjs', <String>['redis://$redisHost:$redisPort']);
      StringBuffer errors = StringBuffer();
      process.stderr.transform(utf8.decoder).listen(errors.write);
      Completer<void> ready = Completer<void>();
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((String line) {
        if (line == 'READY' && !ready.isCompleted) ready.complete();
      });
      await ready.future.timeout(Duration(seconds: 15));

      await server.io.to('r1').emit('from-dart', <String, int>{'x': 1});
      int code = await process.exitCode.timeout(Duration(seconds: 15));
      expect(code, 0, reason: errors.toString());
      expect(await fromNode.future.timeout(Duration(seconds: 5)), 'hi dart');
      dartClient.dispose();
    });
  }, skip: skip ?? NodeRunner.skipReason());
}
