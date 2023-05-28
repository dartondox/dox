import 'dart:io';

class SocketStorage {
  static final SocketStorage _singleton = SocketStorage._internal();
  factory SocketStorage() => _singleton;
  SocketStorage._internal();

  /// active websocket connections
  final Map<String, Map<String, dynamic>> _socketConnections = {};

  /// active rooms with active users in the room
  final Map<String, List<String>> _rooms = {};

  void addConnection(String socketId, WebSocket ws) {
    _socketConnections[socketId] = {
      "socket_id": socketId,
      "websocket": ws,
      "previous_room": null,
      "current_room": null,
    };
  }

  Map<String, dynamic>? getConnection(String socketId) {
    return _socketConnections[socketId];
  }

  void removeConnection(String socketId) {
    _socketConnections.remove(socketId);
  }

  addConnectionToRoom(String socketId, String roomId) {
    if (_rooms[roomId] == null) {
      _rooms[roomId] = [];
    }
    _rooms[roomId]?.add(socketId);
  }

  updateConnectionRoomId(String socketId, String roomId) {
    var connection = getConnection(socketId);
    if (connection != null) {
      connection['current_room'] = roomId;
      if (connection['previous_room'] != null) {
        removeConnectionFromRoom(socketId, connection['previous_room']);
      }
      connection['previous_room'] = roomId;
    }
  }

  List<String> getConnectionsFromRoom(String roomId) {
    return _rooms[roomId] ?? [];
  }

  removeConnectionFromRoom(String socketId, String roomId) {
    if (_rooms[roomId] != null) {
      _rooms[roomId]?.remove(socketId);
    }
  }
}
