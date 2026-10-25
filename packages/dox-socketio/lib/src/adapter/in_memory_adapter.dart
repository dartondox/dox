import '../engine/engine_packet.dart';
import '../parser/socket_encoder.dart';
import '../parser/socket_packet.dart';
import '../server/namespace.dart';
import '../server/socket.dart';
import 'adapter.dart';

/// Default adapter. Rooms live in memory of this server only.
class InMemoryAdapter implements Adapter {
  InMemoryAdapter({this._encoder = const SocketEncoder()});

  final SocketEncoder _encoder;
  final Map<String, RoomStore> _stores = <String, RoomStore>{};

  RoomStore _store(Namespace nsp) =>
      _stores.putIfAbsent(nsp.name, RoomStore.new);

  @override
  void init(Namespace nsp) => _store(nsp);

  @override
  void addAll(Namespace nsp, String id, Set<String> rooms) =>
      _store(nsp).addAll(id, rooms);

  @override
  void del(Namespace nsp, String id, String room) => _store(nsp).del(id, room);

  @override
  void delAll(Namespace nsp, String id) => _store(nsp).delAll(id);

  @override
  Set<String> socketRooms(Namespace nsp, String id) =>
      _store(nsp).socketRooms(id);

  /// Names of all rooms of [nsp] on this server.
  Set<String> rooms(Namespace nsp) => _store(nsp).rooms;

  @override
  Set<String> socketIds(Namespace nsp, BroadcastOptions options) =>
      _store(nsp).match(options.rooms, options.except);

  @override
  Future<void> broadcast(
    Namespace nsp,
    SocketPacket packet,
    BroadcastOptions options,
  ) async {
    Iterable<String> ids = _store(nsp).members(options.rooms, options.except);
    if (ids.isEmpty) return;
    List<Object> encoded = _encoder.encode(packet);
    // Build the text frame once and share it with every socket.
    encoded[0] = SharedText(encoded[0] as String);
    for (String id in ids) {
      Socket? socket = nsp.sockets[id];
      if (socket != null && socket.connected) {
        socket.client.writeEncoded(encoded);
      }
    }
  }

  @override
  Future<void> close() async {}
}

/// Rooms of one namespace.
class RoomStore {
  final Map<String, Set<String>> _rooms = <String, Set<String>>{};
  final Map<String, Set<String>> _sids = <String, Set<String>>{};

  void addAll(String id, Set<String> rooms) {
    Set<String> joined = _sids.putIfAbsent(id, _newSet);
    for (String room in rooms) {
      joined.add(room);
      _rooms.putIfAbsent(room, _newSet).add(id);
    }
  }

  void del(String id, String room) {
    _sids[id]?.remove(room);
    Set<String>? members = _rooms[room];
    members?.remove(id);
    if (members != null && members.isEmpty) _rooms.remove(room);
  }

  void delAll(String id) {
    Set<String>? joined = _sids.remove(id);
    if (joined == null) return;
    for (String room in joined) {
      Set<String>? members = _rooms[room];
      members?.remove(id);
      if (members != null && members.isEmpty) _rooms.remove(room);
    }
  }

  Set<String> get rooms => _rooms.keys.toSet();

  Set<String> socketRooms(String id) => Set<String>.of(_sids[id] ?? _empty);

  /// Sockets in any of [rooms] (all when empty), minus those in [except].
  Set<String> match(Set<String> rooms, Set<String> except) {
    Set<String> skip = <String>{for (String room in except) ...?_rooms[room]};
    Iterable<String> candidates = rooms.isEmpty
        ? _sids.keys
        : <String>{for (String room in rooms) ...?_rooms[room]};
    return candidates.toSet().difference(skip);
  }

  /// Like [match], but with no copy when [except] is empty and there is at
  /// most one room. The result is live: do not join or leave while you
  /// go over it.
  Iterable<String> members(Set<String> rooms, Set<String> except) {
    if (except.isEmpty) {
      if (rooms.isEmpty) return _sids.keys;
      if (rooms.length == 1) return _rooms[rooms.first] ?? _empty;
    }
    return match(rooms, except);
  }

  static Set<String> _newSet() => <String>{};
  static const Set<String> _empty = <String>{};
}
