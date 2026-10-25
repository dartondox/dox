import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ioredis/ioredis.dart';

import '../constants/socket_constants.dart';
import '../parser/socket_packet.dart';
import '../server/broadcast_operator.dart';
import '../server/namespace.dart';
import '../server/socket.dart';
import '../utils/id_generator.dart';
import 'adapter.dart';
import 'in_memory_adapter.dart';
import 'msgpack.dart';

/// How messages are written to Redis.
enum RedisFormat {
  /// MessagePack. The default of `@socket.io/redis-adapter` and of the
  /// emitters (Node.js, PHP, Python, Go).
  msgpack,

  /// JSON, for a Node.js adapter that uses a JSON parser.
  json;

  /// Encodes [value] in this format.
  Uint8List encode(Object? value) {
    if (this == RedisFormat.msgpack) return MsgPack.encode(value);
    return utf8.encode(jsonEncode(_encodeBinary(value), toEncodable: _other));
  }

  /// Decodes a message in either format. JSON starts with `[` or `{`.
  /// In msgpack those bytes are small numbers, never a whole message.
  static Object? decode(Uint8List bytes) {
    if (bytes.isNotEmpty && (bytes[0] == 0x5b || bytes[0] == 0x7b)) {
      return _decodeBinary(jsonDecode(utf8.decode(bytes)));
    }
    return MsgPack.decode(bytes);
  }

  /// In JSON, binary data uses the shape of a Node.js Buffer. jsonEncode
  /// sees a [Uint8List] as a plain list, so it is replaced first.
  static Object? _encodeBinary(Object? value) {
    if (value is Uint8List) {
      return <String, Object>{'type': 'Buffer', 'data': value.toList()};
    }
    if (value is List) return value.map(_encodeBinary).toList();
    if (value is Map) return value.map(_encodeEntry);
    return value;
  }

  static MapEntry<String, Object?> _encodeEntry(Object? k, Object? v) =>
      MapEntry<String, Object?>(k.toString(), _encodeBinary(v));

  static Object? _other(Object? value) {
    if (value is Set) return _encodeBinary(value.toList());
    if (value is DateTime) return value.toIso8601String();
    return _encodeBinary((value as dynamic).toJson());
  }

  static Object? _decodeBinary(Object? value) {
    if (value is List) return value.map(_decodeBinary).toList();
    if (value is Map) {
      if (value['type'] == 'Buffer' && value['data'] is List) {
        return Uint8List.fromList((value['data'] as List<dynamic>).cast<int>());
      }
      return value.map(_decodeEntry);
    }
    return value;
  }

  static MapEntry<String, Object?> _decodeEntry(Object? k, Object? v) =>
      MapEntry<String, Object?>(k.toString(), _decodeBinary(v));
}

/// Request types on the request channel. Same numbers as
/// `@socket.io/redis-adapter`.
class RedisRequestType {
  static const int sockets = 0;
  static const int allRooms = 1;
  static const int remoteJoin = 2;
  static const int remoteLeave = 3;
  static const int remoteDisconnect = 4;
  static const int remoteFetch = 5;
  static const int serverSideEmit = 6;
  static const int broadcast = 7;
  static const int broadcastClientCount = 8;
}

/// Shares broadcasts between servers with Redis pub/sub.
///
/// Each server keeps its own rooms in memory. A broadcast is sent to the
/// local sockets and also published to Redis, so other servers send it to
/// their sockets too.
///
/// It uses the format of `@socket.io/redis-adapter`, so it works next to
/// Node.js servers and with the Socket.IO emitters of other languages:
///
/// - Broadcasts: `[uid, packet, {rooms, except, flags}]` on
///   `socket.io#<namespace>#`, or `socket.io#<namespace>#<room>#` when
///   there is exactly one room. It listens to both with PSUBSCRIBE.
/// - Requests (`socketsJoin`, `socketsLeave`, `disconnectSockets`,
///   `fetchSockets`, ...) on `socket.io-request#<namespace>#`. Answers go
///   to `socket.io-response#<namespace>#`.
///
/// It reads msgpack and JSON. It writes [format].
class RedisAdapter extends InMemoryAdapter {
  RedisAdapter({
    required this.publisher,
    required this.subscriber,
    this.key = defaultRedisKey,
    this.format = RedisFormat.msgpack,
    IdGenerator? ids,
  }) : uid = (ids ?? IdGenerator()).next();

  /// Connection used to publish. Do not use it for subscribe.
  final Redis publisher;

  /// Connection used to subscribe. Do not use it for other commands.
  final Redis subscriber;

  /// Channel prefix.
  final String key;

  /// Format of the messages this server publishes.
  final RedisFormat format;

  /// Id of this server. Messages with this id are ignored.
  final String uid;

  final Map<String, Namespace> _namespaces = <String, Namespace>{};
  final List<Future<void>> _subscribing = <Future<void>>[];

  /// Completes when all namespace channels are subscribed.
  Future<void> ready() => Future.wait(_subscribing);

  /// Broadcast channel of [nsp].
  String channelOf(Namespace nsp) => '$key#${nsp.name}#';

  /// Request channel of [nsp].
  String requestChannelOf(Namespace nsp) => '$key-request#${nsp.name}#';

  /// Response channel of [nsp].
  String responseChannelOf(Namespace nsp) => '$key-response#${nsp.name}#';

  @override
  void init(Namespace nsp) {
    super.init(nsp);
    _namespaces[nsp.name] = nsp;
    _subscribing.add(_subscribe(nsp));
  }

  Future<void> _subscribe(Namespace nsp) async {
    RedisSubscriber broadcasts = await subscriber.psubscribe(
      '${_escapeGlob(channelOf(nsp))}*',
    );
    broadcasts.onPatternMessageBytes = onRedisMessage;
    RedisSubscriber requests = await subscriber.subscribe(
      requestChannelOf(nsp),
    );
    requests.onMessageBytes = _onRequestMessage;
  }

  void _onRequestMessage(String channel, Uint8List message) =>
      onRedisMessage(null, channel, message);

  /// Escape glob characters, so a namespace name is matched as plain text.
  static String _escapeGlob(String text) =>
      text.replaceAllMapped(RegExp(r'[*?\[\]\\]'), _escapeMatch);

  static String _escapeMatch(Match match) => '\\${match[0]}';

  @override
  Future<void> broadcast(
    Namespace nsp,
    SocketPacket packet,
    BroadcastOptions options,
  ) async {
    if (!options.local) {
      String channel = channelOf(nsp);
      if (options.rooms.length == 1) channel += '${options.rooms.first}#';
      await _publish(
        channel,
        format.encode(<Object>[uid, packet.toJson(), options.toJson()]),
      );
    }
    await super.broadcast(nsp, packet, options);
  }

  Future<void> _publish(String channel, Uint8List message) async {
    try {
      await publisher.publish(channel, message);
    } catch (error) {
      stderr.writeln('dox_socketio: redis publish failed: $error');
    }
  }

  /// Handles a message from Redis: a broadcast or a request.
  void onRedisMessage(String? pattern, String channel, Uint8List message) {
    try {
      for (Namespace nsp in _namespaces.values) {
        if (channel.startsWith(channelOf(nsp))) {
          _onBroadcast(nsp, RedisFormat.decode(message));
          return;
        }
        if (channel == requestChannelOf(nsp)) {
          _onRequest(nsp, RedisFormat.decode(message));
          return;
        }
      }
    } catch (error) {
      stderr.writeln('dox_socketio: bad redis message: $error');
    }
  }

  void _onBroadcast(Namespace nsp, Object? decoded) {
    List<dynamic> parts = decoded as List<dynamic>;
    if (parts.length < 3 || parts[0] == uid) return;
    SocketPacket packet = SocketPacket.fromJson(
      parts[1] as Map<String, dynamic>,
    );
    if (packet.nsp != nsp.name) return;
    BroadcastOptions options = BroadcastOptions.fromJson(
      parts[2] as Map<String, dynamic>,
    );
    unawaited(super.broadcast(nsp, packet, options));
  }

  void _onRequest(Namespace nsp, Object? decoded) {
    Map<String, dynamic> request = decoded as Map<String, dynamic>;
    if (request['uid'] == uid) return;
    BroadcastOperator target = _target(nsp, request['opts']);
    switch (request['type']) {
      case RedisRequestType.remoteJoin:
        for (String room in _rooms(request)) {
          target.socketsJoin(room);
        }
      case RedisRequestType.remoteLeave:
        for (String room in _rooms(request)) {
          target.socketsLeave(room);
        }
      case RedisRequestType.remoteDisconnect:
        if (request['opts'] == null) {
          nsp.sockets[request['sid']]?.disconnect(request['close'] == true);
        } else {
          target.disconnectSockets(request['close'] == true);
        }
      case RedisRequestType.sockets:
        BroadcastOptions options = BroadcastOptions.fromJson(<String, dynamic>{
          'rooms': request['rooms'],
        });
        _respond(nsp, <String, Object?>{
          'requestId': request['requestId'],
          'sockets': socketIds(nsp, options).toList(),
        });
      case RedisRequestType.allRooms:
        _respond(nsp, <String, Object?>{
          'requestId': request['requestId'],
          'rooms': rooms(nsp).toList(),
        });
      case RedisRequestType.remoteFetch:
        _respond(nsp, <String, Object?>{
          'requestId': request['requestId'],
          'sockets': target.fetchSockets().map(_socketJson).toList(),
        });
      case RedisRequestType.broadcast:
        // ponytail: acks from our clients are not sent back. Our clients
        // get the event, and we answer "0 clients" so the sender does not
        // wait for them.
        Map<String, dynamic> raw = Map<String, dynamic>.of(
          request['packet'] as Map<String, dynamic>,
        )..remove('id');
        unawaited(
          super.broadcast(
            nsp,
            SocketPacket.fromJson(raw),
            BroadcastOptions.fromJson(request['opts'] as Map<String, dynamic>),
          ),
        );
        _respond(nsp, <String, Object?>{
          'type': RedisRequestType.broadcastClientCount,
          'requestId': request['requestId'],
          'clientCount': 0,
        });
      // ponytail: serverSideEmit is ignored; Dox has no server-side events.
    }
  }

  /// The sockets a request is for: `opts.rooms` minus `opts.except`.
  BroadcastOperator _target(Namespace nsp, Object? opts) {
    BroadcastOptions options = opts is Map<String, dynamic>
        ? BroadcastOptions.fromJson(opts)
        : const BroadcastOptions();
    return BroadcastOperator(
      nsp,
      rooms: options.rooms,
      except: options.except,
      local: true,
    );
  }

  static List<String> _rooms(Map<String, dynamic> request) {
    Object? rooms = request['rooms'] ?? request['room'];
    if (rooms is List) return rooms.map(_toString).toList();
    return rooms == null ? const <String>[] : <String>[rooms.toString()];
  }

  static String _toString(Object? value) => value.toString();

  /// Same shape as a socket in the Node.js `fetchSockets` answer.
  static Map<String, Object?> _socketJson(Socket socket) {
    return <String, Object?>{
      'id': socket.id,
      'handshake': <String, Object?>{
        'headers': socket.handshake.headers,
        'time': socket.handshake.time.toIso8601String(),
        'address': socket.handshake.address,
        'xdomain': false,
        'secure': socket.handshake.secure,
        'issued': socket.handshake.issued,
        'url': socket.handshake.url,
        'query': socket.handshake.query,
        'auth': socket.handshake.auth,
      },
      'rooms': socket.rooms.toList(),
      'data': socket.data,
    };
  }

  /// Answers are JSON, like in the Node.js adapter.
  void _respond(Namespace nsp, Map<String, Object?> response) {
    unawaited(
      _publish(responseChannelOf(nsp), RedisFormat.json.encode(response)),
    );
  }
}
