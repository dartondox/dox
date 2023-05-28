import 'dart:io';

import 'package:dox_core/websocket/web_socket_info.dart';

class SocketStorage {
  static final SocketStorage _singleton = SocketStorage._internal();
  factory SocketStorage() => _singleton;
  SocketStorage._internal();

  /// active websocket connections
  final Map<String, WebSocketInfo> _socketConnections = {};

  /// active rooms with active users in the room
  final Map<String, List<String>> _rooms = {};

  /// add new websocket to active connections
  /// this is used when new ws connection is connected
  void addWebSocketInfo(String socketId, WebSocket ws) {
    _socketConnections[socketId] = WebSocketInfo(
      socketId: socketId,
      websocket: ws,
    );
  }

  /// get web socket info of socket Id
  /// this is used to get websocket info
  WebSocketInfo? getWebSocketInfo(String socketId) {
    return _socketConnections[socketId];
  }

  /// remove connection by socketId
  /// this is used when user leave or disconnected or on error
  /// first remove from the room and then remove from connection
  void removeWebSocketInfo(String socketId) {
    WebSocketInfo? info = getWebSocketInfo(socketId);
    if (info != null && info.activeRoom != null) {
      removeWebSocketIdFromRoom(socketId, info.activeRoom);
    }
    _socketConnections.remove(socketId);
  }

  /// add socket Id to the room
  /// this is use to join the room
  void addWebSocketIdToRoom(String socketId, String roomId) {
    if (_rooms[roomId] == null) {
      _rooms[roomId] = [];
    }
    _rooms[roomId]?.add(socketId);
    updateActiveRoomId(socketId, roomId);
  }

  /// update websocket active room id
  /// this is used when user join new room
  /// this remove previous room and set new room
  void updateActiveRoomId(String socketId, String roomId) {
    WebSocketInfo? info = getWebSocketInfo(socketId);
    if (info != null) {
      if (info.previousRoom != null) {
        removeWebSocketIdFromRoom(socketId, info.previousRoom);
      }
      info.activeRoom = roomId;
      info.previousRoom = roomId;
    }
  }

  /// get list of socket id from the room
  /// this is used when we want to emit message to specific room
  List<String> getWebSocketIdsOfTheRoom(String roomId) {
    return _rooms[roomId] ?? [];
  }

  /// remove websocketId from the room
  /// this is used when user leave the room
  void removeWebSocketIdFromRoom(String socketId, String? roomId) {
    if (_rooms[roomId] != null && roomId != null) {
      _rooms[roomId]?.remove(socketId);
    }
  }
}
