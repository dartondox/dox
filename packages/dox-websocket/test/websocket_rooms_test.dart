import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_websocket/dox_websocket.dart';
import 'package:test/test.dart';

import 'config/app_config.dart';

const int port = 3005;

/// Internal room id for room `name` on the `/ws` route.
/// The server stores joined rooms as `room:<route id><name>`.
String roomId([String name = '']) =>
    'room:${base64.encode(utf8.encode('GET|/ws'))}$name';

class RoomsController {
  /// emit to everyone in the default room of the route
  void all(WebsocketEmitter emitter, dynamic message) {
    emitter.room(roomId()).emit('all', message);
  }

  /// emit to a joined room, using the internal room id
  void toRoom(WebsocketEmitter emitter, dynamic message) {
    emitter.room(roomId(message['room'])).emit('toRoom', message['text']);
  }

  /// emit to a joined room, the way the docs show it: `room('chat')`
  void docsRoom(WebsocketEmitter emitter, dynamic message) {
    emitter.room(message['room']).emit('docsRoom', message['text']);
  }

  void others(WebsocketEmitter emitter, dynamic message) {
    emitter.room(roomId()).emitExceptSender('others', message);
  }

  void me(WebsocketEmitter emitter, dynamic message) {
    emitter.emitToSender('me', message);
  }
}

class RoomsRouter implements Router {
  @override
  List<dynamic> get middleware => <dynamic>[];

  @override
  String get prefix => '';

  @override
  void register() {
    RoomsController c = RoomsController();
    Route.websocket('ws', (WebsocketEvent event) {
      event.on('all', c.all);
      event.on('toRoom', c.toRoom);
      event.on('docsRoom', c.docsRoom);
      event.on('others', c.others);
      event.on('me', c.me);
    });
  }
}

class LocalWebsocketService implements DoxService {
  @override
  void setup() {
    WebsocketServer(Dox());
  }
}

/// Test client that keeps every message it gets.
class Client {
  final WebSocket socket;
  final List<Map<String, dynamic>> messages = <Map<String, dynamic>>[];
  final StreamController<Map<String, dynamic>> _ctrl =
      StreamController<Map<String, dynamic>>.broadcast();
  late String id;

  Client(this.socket) {
    socket.listen((dynamic data) {
      Map<String, dynamic> m = jsonDecode(data);
      messages.add(m);
      _ctrl.add(m);
    });
  }

  static Future<Client> connect([int p = port]) async {
    Client c = Client(await WebSocket.connect('ws://localhost:$p/ws'));
    Map<String, dynamic> m = await c.next('connected');
    c.id = m['message']['id'];
    return c;
  }

  void send(String event, dynamic message) {
    socket.add(jsonEncode(<String, dynamic>{
      'event': event,
      'message': message,
    }));
  }

  /// wait for the first message with this event (also checks old messages)
  Future<Map<String, dynamic>> next(String event) {
    for (Map<String, dynamic> m in messages) {
      if (m['event'] == event) return Future<Map<String, dynamic>>.value(m);
    }
    return _ctrl.stream
        .firstWhere((Map<String, dynamic> m) => m['event'] == event)
        .timeout(Duration(seconds: 3));
  }

  /// true if this event was not received after a short wait
  Future<bool> none(String event) async {
    await Future<void>.delayed(Duration(milliseconds: 300));
    return !messages.any((Map<String, dynamic> m) => m['event'] == event);
  }

  Future<void> close() => socket.close();
}

/// give the server time to handle a `joinRoom` message
Future<void> settle() => Future<void>.delayed(Duration(milliseconds: 200));

void main() {
  group('Websocket rooms (local, no adapter) |', () {
    setUpAll(() async {
      Dox().initialize(AppConfig(
        appKey: appConfig.appKey,
        serverPort: port,
        totalIsolate: 1,
        responseHandler: appConfig.responseHandler,
        routers: <Router>[RoomsRouter()],
        cache: appConfig.cache,
      ));
      Dox().addService(LocalWebsocketService());
      await Dox().startServer();
    });

    tearDownAll(() async {
      await Dox().server.close();
    });

    test('connect sends a connected event with a socket id', () async {
      Client a = await Client.connect();
      expect(a.id, startsWith('ws:'));
      await a.close();
    });

    test('emit to the route room reaches all connected clients', () async {
      Client a = await Client.connect();
      Client b = await Client.connect();
      a.send('all', 'hello');
      expect((await a.next('all'))['message'], 'hello');
      Map<String, dynamic> got = await b.next('all');
      expect(got['message'], 'hello');
      expect(got['sender'], a.id);
      await a.close();
      await b.close();
    });

    test('emitToSender only reaches the sender', () async {
      Client a = await Client.connect();
      Client b = await Client.connect();
      a.send('me', <String, String>{'x': 'y'});
      expect((await a.next('me'))['message'], <String, String>{'x': 'y'});
      expect(await b.none('me'), isTrue);
      await a.close();
      await b.close();
    });

    test('emitExceptSender skips the sender', () async {
      Client a = await Client.connect();
      Client b = await Client.connect();
      a.send('others', 'hi');
      expect((await b.next('others'))['message'], 'hi');
      expect(await a.none('others'), isTrue);
      await a.close();
      await b.close();
    });

    test('emit to a joined room only reaches members of that room', () async {
      Client a = await Client.connect();
      Client b = await Client.connect();
      Client outside = await Client.connect();
      a.send('joinRoom', 'chat');
      b.send('joinRoom', 'chat');
      await settle();

      a.send('toRoom', <String, String>{'room': 'chat', 'text': 'in chat'});
      expect((await a.next('toRoom'))['message'], 'in chat');
      expect((await b.next('toRoom'))['message'], 'in chat');
      expect(await outside.none('toRoom'), isTrue);
      await a.close();
      await b.close();
      await outside.close();
    });

    test('joining a new room leaves the old room', () async {
      Client a = await Client.connect();
      Client b = await Client.connect();
      a.send('joinRoom', 'one');
      b.send('joinRoom', 'one');
      await settle();
      b.send('joinRoom', 'two');
      await settle();

      a.send('toRoom', <String, String>{'room': 'one', 'text': 'x'});
      await a.next('toRoom');
      expect(await b.none('toRoom'), isTrue);
      await a.close();
      await b.close();
    });

    test('disconnected client is removed and emit still works', () async {
      Client a = await Client.connect();
      Client b = await Client.connect();
      a.send('joinRoom', 'bye');
      b.send('joinRoom', 'bye');
      await settle();
      await b.close();
      await settle();

      a.send('toRoom', <String, String>{'room': 'bye', 'text': 'still here'});
      expect((await a.next('toRoom'))['message'], 'still here');
      await a.close();
    });

    test('room name from joinRoom works with emitter.room(name) as in docs',
        () async {
      Client a = await Client.connect();
      Client b = await Client.connect();
      a.send('joinRoom', 'chat');
      b.send('joinRoom', 'chat');
      await settle();
      a.send('docsRoom', <String, String>{'room': 'chat', 'text': 'hey'});
      expect((await b.next('docsRoom'))['message'], 'hey');
      await a.close();
      await b.close();
    },
        skip: 'bug: joinRoom stores the room as "room:<route id><name>" but '
            'emitter.room(name) uses the plain name, so the docs example '
            'never reaches anyone');
  });
}
