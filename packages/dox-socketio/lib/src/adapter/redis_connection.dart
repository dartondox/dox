import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ioredis/ioredis.dart' show RedisOptions;

/// Called for each pub/sub message. [pattern] is null for SUBSCRIBE.
typedef RedisMessageHandler = void Function(
  String? pattern,
  String channel,
  Uint8List message,
);

/// A small Redis connection for pub/sub with binary messages.
///
/// `ioredis` reads every message as a UTF-8 string, so it can not carry
/// msgpack. This connection sends and gets raw bytes. It only knows
/// PUBLISH, SUBSCRIBE, PSUBSCRIBE and PUBSUB NUMSUB.
///
/// It connects on first use. When the connection drops, it connects again
/// and subscribes again.
class RedisPubSubConnection {
  RedisPubSubConnection(this.options);

  /// Host, port, password, db, TLS and retry delay.
  final RedisOptions options;

  /// Gets the messages of SUBSCRIBE and PSUBSCRIBE.
  RedisMessageHandler? onMessage;

  Socket? _socket;
  Future<void>? _connecting;
  bool _closed = false;
  int _retries = 0;
  final _RespReader _reader = _RespReader();
  final Queue<Completer<Object?>> _pending = Queue<Completer<Object?>>();
  final Set<String> _channels = <String>{};
  final Set<String> _patterns = <String>{};

  /// Publishes [message] on [channel]. Returns how many clients got it.
  Future<int> publish(String channel, Uint8List message) async {
    return await _command(<Object>['PUBLISH', channel, message]) as int;
  }

  /// Subscribes to [channel].
  Future<void> subscribe(String channel) async {
    _channels.add(channel);
    await _command(<Object>['SUBSCRIBE', channel]);
  }

  /// Subscribes to the glob [pattern].
  Future<void> psubscribe(String pattern) async {
    _patterns.add(pattern);
    await _command(<Object>['PSUBSCRIBE', pattern]);
  }

  /// Number of subscribers of [channel].
  Future<int> numsub(String channel) async {
    List<Object?> reply =
        await _command(<Object>['PUBSUB', 'NUMSUB', channel]) as List<Object?>;
    return reply[1] as int;
  }

  /// Closes the connection. It does not connect again.
  Future<void> close() async {
    _closed = true;
    Socket? socket = _socket;
    _socket = null;
    _failPending(StateError('redis connection closed'));
    if (socket != null) await socket.close();
  }

  Future<Object?> _command(List<Object> args) async {
    if (_closed) throw StateError('redis connection closed');
    await _connect();
    return _send(args);
  }

  Future<Object?> _send(List<Object> args) {
    Completer<Object?> reply = Completer<Object?>();
    _pending.add(reply);
    _socket!.add(_encode(args));
    return reply.future;
  }

  Future<void> _connect() {
    if (_socket != null) return Future<void>.value();
    return _connecting ??= _open().whenComplete(_clearConnecting);
  }

  void _clearConnecting() => _connecting = null;

  Future<void> _open() async {
    Socket socket = options.secure
        ? await SecureSocket.connect(
            options.host,
            options.port,
            timeout: options.connectTimeout,
            onBadCertificate: options.onBadCertificate,
          )
        : await Socket.connect(
            options.host,
            options.port,
            timeout: options.connectTimeout,
          );
    socket.setOption(SocketOption.tcpNoDelay, true);
    _reader.reset();
    _socket = socket;
    socket.listen(_onData, onDone: _onDone, onError: _onError);
    List<Future<Object?>> setup = <Future<Object?>>[
      if (options.password != null)
        _send(<Object>[
          'AUTH',
          if (options.username != null) options.username!,
          options.password!,
        ]),
      if (options.db != 0) _send(<Object>['SELECT', '${options.db}']),
      for (String channel in _channels) _send(<Object>['SUBSCRIBE', channel]),
      for (String pattern in _patterns) _send(<Object>['PSUBSCRIBE', pattern]),
    ];
    await Future.wait(setup);
    _retries = 0;
  }

  void _onData(Uint8List chunk) {
    for (Object? reply in _reader.add(chunk)) {
      if (reply is List && _isPush(reply)) continue;
      if (_pending.isEmpty) continue;
      Completer<Object?> done = _pending.removeFirst();
      if (reply is RedisReplyError) {
        done.completeError(reply);
      } else {
        done.complete(reply);
      }
    }
  }

  /// True for a `message` or `pmessage` push. It goes to [onMessage].
  bool _isPush(List<Object?> reply) {
    Object? kind = reply.isEmpty ? null : reply[0];
    if (kind is! Uint8List) return false;
    if (kind.length == 7 && reply.length == 3 && _ascii(kind) == 'message') {
      onMessage?.call(
        null,
        utf8.decode(reply[1] as Uint8List),
        reply[2] as Uint8List,
      );
      return true;
    }
    if (kind.length == 8 && reply.length == 4 && _ascii(kind) == 'pmessage') {
      onMessage?.call(
        utf8.decode(reply[1] as Uint8List),
        utf8.decode(reply[2] as Uint8List),
        reply[3] as Uint8List,
      );
      return true;
    }
    return false;
  }

  static String _ascii(Uint8List bytes) => String.fromCharCodes(bytes);

  void _onError(Object error) {
    stderr.writeln('dox_socketio: redis connection error: $error');
  }

  void _onDone() {
    _socket = null;
    _failPending(const SocketException('redis connection lost'));
    if (_closed) return;
    if (_channels.isEmpty && _patterns.isEmpty) return; // next command connects
    _retries++;
    Duration delay =
        options.retryStrategy?.call(_retries) ??
        Duration(milliseconds: (50 * _retries).clamp(50, 2000));
    Timer(delay, _reconnect);
  }

  void _reconnect() {
    if (_closed || _socket != null) return;
    _connect().catchError(_onReconnectError);
  }

  void _onReconnectError(Object error) {
    stderr.writeln('dox_socketio: redis reconnect failed: $error');
    _onDone();
  }

  void _failPending(Object error) {
    while (_pending.isNotEmpty) {
      Completer<Object?> done = _pending.removeFirst();
      done.completeError(error);
      done.future.ignore();
    }
  }

  /// A RESP array of bulk strings.
  static Uint8List _encode(List<Object> args) {
    BytesBuilder out = BytesBuilder(copy: false);
    out.add(latin1.encode('*${args.length}\r\n'));
    for (Object arg in args) {
      Uint8List bytes = arg is Uint8List ? arg : utf8.encode(arg.toString());
      out.add(latin1.encode('\$${bytes.length}\r\n'));
      out.add(bytes);
      out.add(const <int>[13, 10]);
    }
    return out.takeBytes();
  }
}

/// An error reply from Redis.
class RedisReplyError implements Exception {
  const RedisReplyError(this.message);

  final String message;

  @override
  String toString() => 'RedisReplyError: $message';
}

/// Reads RESP2 replies. Bulk strings stay bytes.
class _RespReader {
  Uint8List _buffer = Uint8List(0);
  int _pos = 0;

  void reset() => _buffer = Uint8List(0);

  /// Adds [chunk] and returns the replies that are now complete.
  List<Object?> add(Uint8List chunk) {
    _buffer = _buffer.isEmpty
        ? chunk
        : (BytesBuilder(copy: false)
                ..add(_buffer)
                ..add(chunk))
              .takeBytes();
    List<Object?> replies = <Object?>[];
    int start = 0;
    while (start < _buffer.length) {
      _pos = start;
      Object? reply;
      try {
        reply = _read();
      } on _Incomplete {
        break;
      }
      replies.add(reply);
      start = _pos;
    }
    _buffer = start == _buffer.length
        ? Uint8List(0)
        : Uint8List.sublistView(_buffer, start);
    return replies;
  }

  Object? _read() {
    if (_pos >= _buffer.length) throw const _Incomplete();
    int type = _buffer[_pos++];
    String line = _line();
    switch (type) {
      case 0x2b: // +
        return line;
      case 0x2d: // -
        return RedisReplyError(line);
      case 0x3a: // :
        return int.parse(line);
      case 0x24: // $
        int length = int.parse(line);
        if (length < 0) return null;
        if (_pos + length + 2 > _buffer.length) throw const _Incomplete();
        Uint8List bytes = Uint8List.fromList(
          Uint8List.sublistView(_buffer, _pos, _pos + length),
        );
        _pos += length + 2;
        return bytes;
      case 0x2a: // *
        int length = int.parse(line);
        if (length < 0) return null;
        List<Object?> items = <Object?>[];
        for (int i = 0; i < length; i++) {
          items.add(_read());
        }
        return items;
    }
    throw FormatException('redis: unknown reply type $type');
  }

  String _line() {
    for (int i = _pos; i + 1 < _buffer.length; i++) {
      if (_buffer[i] == 13 && _buffer[i + 1] == 10) {
        String line = latin1.decode(Uint8List.sublistView(_buffer, _pos, i));
        _pos = i + 2;
        return line;
      }
    }
    throw const _Incomplete();
  }
}

class _Incomplete implements Exception {
  const _Incomplete();
}
