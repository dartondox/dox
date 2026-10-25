import 'package:ioredis/ioredis.dart';

import '../constants/socket_constants.dart';
import '../parser/socket_packet.dart';
import 'adapter.dart';
import 'redis_adapter.dart';

/// Sends Socket.IO events through Redis, with no Socket.IO server.
///
/// Use it in a queue worker, a CLI command or any other program. The
/// Socket.IO servers that use a Redis adapter (Dox or Node.js) send the
/// events to their clients. It works like `@socket.io/redis-emitter`.
///
/// ```dart
/// SocketIoEmitter emitter = SocketIoEmitter(Redis(RedisOptions()));
/// await emitter.to('room1').emit('news', {'title': 'hi'});
/// await emitter.of('/admin').socketsJoin('vip');
/// ```
class SocketIoEmitter extends SocketIoEmitterOperator {
  /// Publishes with [redis]. Do not use a connection in subscribe mode.
  SocketIoEmitter(
    Redis redis, {
    String key = defaultRedisKey,
    RedisFormat format = RedisFormat.msgpack,
  }) : this._(redis, key, format, defaultNamespace);

  SocketIoEmitter._(
    Redis connection,
    String key,
    RedisFormat format,
    String nsp,
  ) : super._(connection, key, format, nsp, const BroadcastOptions());

  /// An emitter for namespace [nsp]. It shares this Redis connection.
  SocketIoEmitter of(String nsp) {
    return SocketIoEmitter._(
      _connection,
      _key,
      _format,
      nsp.startsWith('/') ? nsp : '/$nsp',
    );
  }
}

/// Picks rooms and sends to them. Each method returns a new operator.
class SocketIoEmitterOperator {
  SocketIoEmitterOperator._(
    this._connection,
    this._key,
    this._format,
    this._nsp,
    this._options,
  );

  /// The `uid` of messages from an emitter, like in Node.js.
  static const String emitterUid = 'emitter';

  final Redis _connection;
  final String _key;
  final RedisFormat _format;
  final String _nsp;
  final BroadcastOptions _options;

  /// Also sends to sockets in [room].
  SocketIoEmitterOperator to(String room) {
    return _copy(_options.copyWith(rooms: <String>{..._options.rooms, room}));
  }

  /// Skips sockets in [room].
  SocketIoEmitterOperator except(String room) {
    return _copy(_options.copyWith(except: <String>{..._options.except, room}));
  }

  SocketIoEmitterOperator _copy(BroadcastOptions options) {
    return SocketIoEmitterOperator._(_connection, _key, _format, _nsp, options);
  }

  /// Sends [event]. Null [data] sends no argument.
  Future<void> emit(String event, [Object? data]) {
    return emitArgs(event, data == null ? const <Object?>[] : <Object?>[data]);
  }

  /// Sends [event] with many arguments.
  Future<void> emitArgs(String event, List<Object?> args) async {
    if (reservedEvents.contains(event)) {
      throw ArgumentError.value(event, 'event', 'is a reserved event name');
    }
    SocketPacket packet = SocketPacket(
      type: SocketPacketType.event,
      nsp: _nsp,
      data: <Object?>[event, ...args],
    );
    String channel = '$_key#$_nsp#';
    if (_options.rooms.length == 1) channel += '${_options.rooms.first}#';
    await _connection.publish(
      channel,
      _format.encode(<Object>[emitterUid, packet.toJson(), _options.toJson()]),
    );
  }

  /// Makes the matching sockets join [room].
  Future<void> socketsJoin(String room) {
    return _request(<String, Object?>{
      'type': RedisRequestType.remoteJoin,
      'opts': _opts(),
      'rooms': <String>[room],
    });
  }

  /// Makes the matching sockets leave [room].
  Future<void> socketsLeave(String room) {
    return _request(<String, Object?>{
      'type': RedisRequestType.remoteLeave,
      'opts': _opts(),
      'rooms': <String>[room],
    });
  }

  /// Disconnects the matching sockets. With [close], the whole connection
  /// is closed.
  Future<void> disconnectSockets([bool close = false]) {
    return _request(<String, Object?>{
      'type': RedisRequestType.remoteDisconnect,
      'opts': _opts(),
      'close': close,
    });
  }

  /// Sends [args] to the other Socket.IO servers (Node.js
  /// `io.on('event', ...)` gets them). Dox servers ignore it.
  Future<void> serverSideEmit(List<Object?> args) {
    return _request(<String, Object?>{
      'uid': emitterUid,
      'type': RedisRequestType.serverSideEmit,
      'data': args,
    });
  }

  Map<String, Object> _opts() {
    return <String, Object>{
      'rooms': _options.rooms.toList(),
      'except': _options.except.toList(),
    };
  }

  /// Requests are JSON, like in `@socket.io/redis-emitter`.
  Future<void> _request(Map<String, Object?> request) async {
    await _connection.publish(
      '$_key-request#$_nsp#',
      RedisFormat.json.encode(request),
    );
  }
}
