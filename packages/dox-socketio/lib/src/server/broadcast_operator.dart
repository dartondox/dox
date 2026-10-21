import '../adapter/adapter.dart';
import '../constants/socket_constants.dart';
import '../parser/socket_packet.dart';
import 'namespace.dart';
import 'socket.dart';

/// Picks a group of sockets (rooms, except rooms) and sends to them.
///
/// Each method returns a new operator, so you can chain calls:
/// `io.to('a').to('b').except('c').emit('news', data)`.
class BroadcastOperator {
  BroadcastOperator(
    this._nsp, {
    Set<String> rooms = const <String>{},
    Set<String> except = const <String>{},
    bool local = false,
  }) : _options = BroadcastOptions(rooms: rooms, except: except, local: local);

  BroadcastOperator._(this._nsp, this._options);

  final Namespace _nsp;
  final BroadcastOptions _options;

  /// Also sends to sockets in [room].
  BroadcastOperator to(String room) {
    return BroadcastOperator._(
      _nsp,
      _options.copyWith(rooms: <String>{..._options.rooms, room}),
    );
  }

  /// Skips sockets in [room].
  BroadcastOperator except(String room) {
    return BroadcastOperator._(
      _nsp,
      _options.copyWith(except: <String>{..._options.except, room}),
    );
  }

  /// Sends only to sockets of this server, not to other servers.
  BroadcastOperator get local {
    return BroadcastOperator._(_nsp, _options.copyWith(local: true));
  }

  /// Sends [event]. Null [data] sends no argument.
  Future<void> emit(String event, [Object? data]) {
    return emitArgs(event, data == null ? const <Object?>[] : <Object?>[data]);
  }

  /// Sends [event] with many arguments.
  Future<void> emitArgs(String event, List<Object?> args) {
    if (reservedEvents.contains(event)) {
      throw ArgumentError.value(event, 'event', 'is a reserved event name');
    }
    SocketPacket packet = SocketPacket(
      type: SocketPacketType.event,
      nsp: _nsp.name,
      data: <Object?>[event, ...args],
    );
    return _nsp.adapter.broadcast(_nsp, packet, _options);
  }

  /// Matching sockets on this server.
  List<Socket> fetchSockets() {
    return <Socket>[
      for (String id in _nsp.adapter.socketIds(_nsp, _options))
        if (_nsp.sockets[id] != null) _nsp.sockets[id]!,
    ];
  }

  /// Makes the matching sockets on this server join [room].
  void socketsJoin(String room) {
    for (Socket socket in fetchSockets()) {
      socket.join(room);
    }
  }

  /// Makes the matching sockets on this server leave [room].
  void socketsLeave(String room) {
    for (Socket socket in fetchSockets()) {
      socket.leave(room);
    }
  }

  /// Disconnects the matching sockets on this server.
  void disconnectSockets([bool close = false]) {
    for (Socket socket in fetchSockets()) {
      socket.disconnect(close);
    }
  }
}
