@Timeout(Duration(seconds: 60))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dox_socketio/dox_socketio.dart';
import 'package:ioredis/ioredis.dart' show RedisOptions;
import 'package:socket_io_client/socket_io_client.dart' as sio;
import 'package:test/test.dart';

import 'msgpack_test.dart' show emitterFixture, hex;
import 'support/node_runner.dart';
import 'support/test_app.dart';

/// Locally: docker run -d --name dox-sio-redis -p 6409:6379 redis:7-alpine
/// and REDIS_PORT=6409. CI uses the redis service on 6379.
final String redisHost = Platform.environment['REDIS_HOST'] ?? '127.0.0.1';
final int redisPort = int.parse(Platform.environment['REDIS_PORT'] ?? '6379');
final RedisOptions redisOptions = RedisOptions(
  host: redisHost,
  port: redisPort,
);

String? redisSkipReason() {
  try {
    // A sync check, so the tests can be skipped before they are declared.
    ProcessResult result = Process.runSync('nc', <String>[
      '-z',
      redisHost,
      '$redisPort',
    ]);
    return result.exitCode == 0
        ? null
        : 'redis is not reachable at $redisHost:$redisPort';
  } on ProcessException {
    return null; // No nc. Try anyway.
  }
}

RedisAdapter newAdapter([RedisFormat format = RedisFormat.msgpack]) {
  return RedisAdapter(redis: redisOptions, format: format);
}

Future<sio.Socket> connectClient(
  String url,
  String room, {
  String nsp = '',
  Map<String, String>? auth,
}) async {
  sio.OptionBuilder options = sio.OptionBuilder()
      .setTransports(<String>['websocket'])
      .disableReconnection()
      .enableForceNew();
  if (auth != null) options = options.setAuth(auth);
  sio.Socket socket = sio.io('$url$nsp', options.build());
  Completer<void> joined = Completer<void>();
  if (room.isEmpty) {
    socket.onConnect((dynamic _) => joined.complete());
  } else {
    socket.onConnect(_JoinRoom(socket, room, joined).call);
  }
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

/// The next [event] on [socket].
Future<Object?> next(sio.Socket socket, String event) {
  Completer<Object?> got = Completer<Object?>();
  socket.once(event, (dynamic data) => got.complete(data));
  return got.future.timeout(Duration(seconds: 5));
}

/// Collects the [event]s on [socket].
List<Object?> collect(sio.Socket socket, String event) {
  List<Object?> got = <Object?>[];
  socket.on(event, got.add);
  return got;
}

Future<void> settle() => Future<void>.delayed(Duration(milliseconds: 300));

/// Runs a script in test/interop and waits for exit code 0.
Future<void> runNode(NodeRunner node, String script, List<String> args) async {
  ProcessResult result = await node.run(script, args);
  expect(
    result.exitCode,
    0,
    reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}',
  );
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
      adapterB = newAdapter(RedisFormat.json);
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
      List<Object?> outsideGot = collect(outside, 'cross');

      Future<Object?> got = next(inRoom, 'cross');
      await serverB.io.to('room1').emit('cross', <String, int>{'n': 1});
      expect(await got, <String, dynamic>{'n': 1});

      // Binary data, msgpack server to JSON server and back.
      Future<Object?> bin = next(inRoom, 'bin');
      await serverB.io.to('room1').emit('bin', Uint8List.fromList(<int>[1]));
      expect(await bin, <int>[1]);

      // local must not leave server B.
      List<Object?> local = collect(inRoom, 'local');
      await serverB.io.local.emit('local', 'x');
      await settle();
      expect(local, isEmpty);
      expect(outsideGot, isEmpty);
      inRoom.dispose();
      outside.dispose();
    });

    test('messages use the Node.js redis adapter format', () async {
      RedisPubSubConnection listener = RedisPubSubConnection(redisOptions);
      List<Uint8List> messages = <Uint8List>[];
      listener.onMessage = (String? p, String channel, Uint8List message) {
        messages.add(message);
      };
      await listener.psubscribe('socket.io#/#*');
      await serverA.io.to('r').except('x').emit('hello', 'world');
      await serverB.io.to('r').except('x').emit('hello', 'world');
      await settle();
      await listener.close();
      expect(messages, hasLength(2));
      List<Object?> packed = MsgPack.decode(messages[0]) as List<Object?>;
      expect(messages[1][0], 0x5b, reason: 'server B writes JSON');
      List<dynamic> json =
          jsonDecode(utf8.decode(messages[1])) as List<dynamic>;
      for (List<Object?> parts in <List<Object?>>[packed, json]) {
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
      }
      expect(packed[0], adapterA.uid);
      expect(json[0], adapterB.uid);
    });

    test('reads the bytes that @socket.io/redis-emitter sends', () async {
      sio.Socket inRoom = await connectClient(serverA.url, 'r1');
      sio.Socket skipped = await connectClient(serverA.url, 'x');
      List<Object?> skippedGot = collect(skipped, 'news');
      Completer<List<dynamic>> got = Completer<List<dynamic>>();
      inRoom.on('news', (dynamic data) => got.complete(data as List<dynamic>));
      RedisPubSubConnection redis = RedisPubSubConnection(redisOptions);
      await redis.publish('socket.io#/#r1#', hex(emitterFixture));
      await redis.close();
      // socket_io_client gives all arguments as a list.
      List<dynamic> args = await got.future.timeout(Duration(seconds: 5));
      expect(args[0], <String, dynamic>{
        'a': 1,
        'bin': <int>[1, 2, 3],
      });
      expect(args.sublist(1), <Object?>[1.5, -5, 300, null, true, 'ü']);
      await settle();
      expect(skippedGot, isEmpty);
      inRoom.dispose();
      skipped.dispose();
    });
  }, skip: skip);

  group('SocketIoEmitter', () {
    late TestApp server;
    late SocketIoEmitter emitter;

    setUp(() async {
      RedisAdapter adapter = newAdapter();
      server = TestApp(adapter: adapter);
      await server.start();
      await adapter.ready();
      emitter = SocketIoEmitter(redis: redisOptions);
    });

    tearDown(() async {
      await emitter.close();
      await server.stop();
    });

    test('emits to all, rooms and except', () async {
      sio.Socket a = await connectClient(server.url, 'a');
      sio.Socket b = await connectClient(server.url, 'b');
      List<Object?> aGot = collect(a, 'news');
      List<Object?> bGot = collect(b, 'news');
      await emitter.emit('news', 'all');
      await emitter.to('a').emit('news', 'only a');
      await emitter.to('a').to('b').except('b').emit('news', 'a not b');
      await emitter.emit('news', Uint8List.fromList(<int>[5, 6]));
      await settle();
      expect(aGot, <Object?>[
        'all',
        'only a',
        'a not b',
        <int>[5, 6],
      ]);
      expect(bGot, <Object?>[
        'all',
        <int>[5, 6],
      ]);
      a.dispose();
      b.dispose();
    });

    test('emits to a namespace', () async {
      sio.Socket main = await connectClient(server.url, '');
      sio.Socket admin = await connectClient(
        server.url,
        '',
        nsp: '/admin',
        auth: <String, String>{'token': 'secret'},
      );
      List<Object?> mainGot = collect(main, 'news');
      Future<Object?> adminGot = next(admin, 'news');
      await emitter.of('admin').emit('news', 'admins');
      expect(await adminGot, 'admins');
      await settle();
      expect(mainGot, isEmpty);
      main.dispose();
      admin.dispose();
    });

    test('socketsJoin, socketsLeave and disconnectSockets', () async {
      sio.Socket a = await connectClient(server.url, 'a');
      sio.Socket b = await connectClient(server.url, 'b');
      List<Object?> bGot = collect(b, 'news');
      await emitter.to('a').socketsJoin('vip');
      await settle();
      Future<Object?> aGot = next(a, 'news');
      await emitter.to('vip').emit('news', 'vip');
      expect(await aGot, 'vip');

      await emitter.socketsLeave('vip');
      await settle();
      List<Object?> aLate = collect(a, 'news');
      await emitter.to('vip').emit('news', 'vip again');
      await settle();
      expect(aLate, isEmpty);
      expect(bGot, isEmpty);

      Future<Object?> gone = next(a, 'disconnect');
      await emitter.except('b').disconnectSockets();
      expect(await gone, 'io server disconnect');
      await settle();
      expect(b.connected, isTrue);
      a.dispose();
      b.dispose();
    });
  }, skip: skip);

  group('Node.js', () {
    NodeRunner node = NodeRunner();
    late TestApp server;

    setUpAll(node.install);

    tearDown(() => server.stop());

    for (RedisFormat format in RedisFormat.values) {
      test(
        'Dart and Node.js servers share broadcasts (${format.name})',
        () async {
          RedisAdapter adapter = newAdapter(format);
          server = TestApp(adapter: adapter);
          await server.start();
          await adapter.ready();
          sio.Socket dartClient = await connectClient(server.url, 'r1');
          Future<Object?> fromNode = next(dartClient, 'from-node');
          Future<Object?> fromNodeRoom = next(dartClient, 'from-node-room');

          Process process = await node.start('redis-node.mjs', <String>[
            'redis://$redisHost:$redisPort',
            format.name,
          ]);
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
          expect(await fromNode, 'hi dart');
          expect(await fromNodeRoom, 'hi room');
          dartClient.dispose();
        },
      );
    }

    test('@socket.io/redis-emitter reaches Dart clients', () async {
      RedisAdapter adapter = newAdapter();
      server = TestApp(adapter: adapter);
      await server.start();
      await adapter.ready();
      sio.Socket a = await connectClient(server.url, 'r1');
      sio.Socket b = await connectClient(server.url, 'r2');
      List<Object?> aGot = collect(a, 'news');
      List<Object?> bGot = collect(b, 'news');
      Future<Object?> aGone = next(a, 'disconnect');

      await runNode(node, 'redis-emitter.mjs', <String>[
        'redis://$redisHost:$redisPort',
      ]);
      expect(await aGone, 'io server disconnect');
      expect(aGot, <Object?>[
        'all',
        <String, dynamic>{
          'bin': <int>[1, 2, 3],
        },
        'joined',
      ]);
      expect(bGot, <Object?>['all']);
      expect(b.connected, isTrue);
      a.dispose();
      b.dispose();
    });
  }, skip: skip ?? NodeRunner.skipReason());
}
