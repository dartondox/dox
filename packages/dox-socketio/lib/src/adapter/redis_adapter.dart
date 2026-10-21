import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ioredis/ioredis.dart';

import '../constants/socket_constants.dart';
import '../parser/socket_packet.dart';
import '../server/namespace.dart';
import '../utils/id_generator.dart';
import 'adapter.dart';
import 'in_memory_adapter.dart';

/// Shares broadcasts between servers with Redis pub/sub.
///
/// Each server keeps its own rooms in memory. A broadcast is sent to the
/// local sockets and also published to Redis, so other servers send it to
/// their sockets too.
///
/// The message format is the one of `@socket.io/redis-adapter` with a JSON
/// parser: `[uid, packet, {rooms, except, flags}]` on the channel
/// `socket.io#<namespace>#`.
class RedisAdapter extends InMemoryAdapter {
  RedisAdapter({
    required this.publisher,
    required this.subscriber,
    this.key = defaultRedisKey,
    IdGenerator? ids,
  }) : uid = (ids ?? IdGenerator()).next();

  /// Connection used to publish. Do not use it for subscribe.
  final Redis publisher;

  /// Connection used to subscribe. Do not use it for other commands.
  final Redis subscriber;

  /// Channel prefix.
  final String key;

  /// Id of this server. Messages with this id are ignored.
  final String uid;

  final Map<String, Namespace> _channels = <String, Namespace>{};
  final List<String> _toSubscribe = <String>[];
  Future<void> _subscribing = Future<void>.value();

  /// Completes when all namespace channels are subscribed.
  Future<void> ready() => _subscribing;

  /// Channel name of [nsp].
  String channelOf(Namespace nsp) => '$key#${nsp.name}#';

  @override
  void init(Namespace nsp) {
    super.init(nsp);
    String channel = channelOf(nsp);
    _channels[channel] = nsp;
    _toSubscribe.add(channel);
    if (_toSubscribe.length == 1) _subscribing = _subscribeAll();
  }

  // ponytail: one SUBSCRIBE at a time, because parallel SUBSCRIBE calls
  // hang in ioredis 1.0.3.
  Future<void> _subscribeAll() async {
    while (_toSubscribe.isNotEmpty) {
      RedisSubscriber subscription =
          await subscriber.subscribe(_toSubscribe.first);
      subscription.onMessage = onRedisMessage;
      _toSubscribe.removeAt(0);
    }
  }

  @override
  Future<void> broadcast(
    Namespace nsp,
    SocketPacket packet,
    BroadcastOptions options,
  ) async {
    if (!options.local) {
      String message = jsonEncode(
        <Object>[uid, packet.toJson(), options.toJson()],
        toEncodable: _encodeBinary,
      );
      try {
        await publisher.publish(channelOf(nsp), message);
      } catch (error) {
        stderr.writeln('dox_socketio: redis publish failed: $error');
      }
    }
    await super.broadcast(nsp, packet, options);
  }

  /// Handles a message from another server.
  void onRedisMessage(String channel, String? message) {
    if (message == null || message.isEmpty) return;
    Namespace? nsp = _channels[channel];
    if (nsp == null) return;
    try {
      List<dynamic> parts = jsonDecode(message) as List<dynamic>;
      if (parts.length < 3 || parts[0] == uid) return;
      Map<String, dynamic> raw = parts[1] as Map<String, dynamic>;
      raw['data'] = _decodeBinary(raw['data']);
      SocketPacket packet = SocketPacket.fromJson(raw);
      if (packet.nsp != nsp.name) return;
      BroadcastOptions options =
          BroadcastOptions.fromJson(parts[2] as Map<String, dynamic>);
      unawaited(super.broadcast(nsp, packet, options));
    } catch (error) {
      stderr.writeln('dox_socketio: bad redis message: $error');
    }
  }

  /// Binary data uses the JSON shape of a Node.js Buffer.
  static Object? _encodeBinary(Object? value) {
    if (value is Uint8List) {
      return <String, Object>{'type': 'Buffer', 'data': value.toList()};
    }
    return (value as dynamic).toJson();
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
