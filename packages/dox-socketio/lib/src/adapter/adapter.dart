import '../parser/socket_packet.dart';
import '../server/namespace.dart';

/// Which sockets a broadcast goes to.
class BroadcastOptions {
  const BroadcastOptions({
    this.rooms = const <String>{},
    this.except = const <String>{},
    this.local = false,
  });

  /// Reads options from JSON (same shape as the Node.js redis adapter).
  factory BroadcastOptions.fromJson(Map<String, dynamic> json) {
    Object? flags = json['flags'];
    return BroadcastOptions(
      rooms: _stringSet(json['rooms']),
      except: _stringSet(json['except']),
      local: flags is Map && flags['local'] == true,
    );
  }

  /// Send to sockets in any of these rooms. Empty means all sockets.
  final Set<String> rooms;

  /// Skip sockets in any of these rooms.
  final Set<String> except;

  /// Do not send to other servers.
  final bool local;

  BroadcastOptions copyWith({
    Set<String>? rooms,
    Set<String>? except,
    bool? local,
  }) {
    return BroadcastOptions(
      rooms: rooms ?? this.rooms,
      except: except ?? this.except,
      local: local ?? this.local,
    );
  }

  Map<String, Object> toJson() {
    return <String, Object>{
      'rooms': rooms.toList(),
      'except': except.toList(),
      'flags': <String, Object>{if (local) 'local': true},
    };
  }

  static Set<String> _stringSet(Object? value) {
    if (value is! List) return <String>{};
    return value.map(_toString).toSet();
  }

  static String _toString(Object? value) => value.toString();
}

/// Keeps rooms and sends broadcasts.
///
/// One adapter serves all namespaces of a server. Replace it to share
/// broadcasts between many servers (see `RedisAdapter`).
abstract class Adapter {
  /// Called once for each new namespace.
  void init(Namespace nsp);

  /// Adds socket [id] to [rooms].
  void addAll(Namespace nsp, String id, Set<String> rooms);

  /// Removes socket [id] from [room].
  void del(Namespace nsp, String id, String room);

  /// Removes socket [id] from all rooms.
  void delAll(Namespace nsp, String id);

  /// Rooms of socket [id].
  Set<String> socketRooms(Namespace nsp, String id);

  /// Ids of the local sockets that match [options].
  Set<String> socketIds(Namespace nsp, BroadcastOptions options);

  /// Sends [packet] to the sockets that match [options].
  Future<void> broadcast(
    Namespace nsp,
    SocketPacket packet,
    BroadcastOptions options,
  );

  /// Frees resources.
  Future<void> close();
}
