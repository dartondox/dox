import 'dart:io';

import 'package:dox_websocket/src/websocket_info.dart';

/// active websocket connections
final Map<String, WebsocketInfo> _socketConnections = <String, WebsocketInfo>{};

/// active rooms with active users in the room
final Map<String, List<String>> _rooms = <String, List<String>>{};

class WebsocketStorage {
  static final WebsocketStorage _singleton = WebsocketStorage._internal();
  factory WebsocketStorage() {
    return _singleton;
  }
  WebsocketStorage._internal();

  /// add new websocket to active connections
  /// this is used when new ws connection is connected
  void addWebSocketInfo(String socketId, WebSocket ws) {
    _socketConnections[socketId] = WebsocketInfo(
      socketId: socketId,
      websocket: ws,
    );
  }

  /// get web socket info of socket Id
  /// this is used to get websocket info
  WebsocketInfo? getWebSocketInfo(String socketId) {
    return _socketConnections[socketId];
  }

  /// remove connection by socketId
  /// this is used when user leave or disconnected or on error
  /// first remove from the room and then remove from connection
  void removeWebSocketInfo(String socketId) {
    WebsocketInfo? info = getWebSocketInfo(socketId);
    if (info != null && info.activeRoom != null) {
      removeWebSocketIdFromRoom(socketId, info.activeRoom);
    }
    _socketConnections.remove(socketId);
  }

  /// add socket Id to the room
  /// this is use to join the room
  void addWebSocketIdToRoom(String socketId, String roomId) {
    if (_rooms[roomId] == null) {
      _rooms[roomId] = <String>[];
    }
    _rooms[roomId]?.add(socketId);
    updateActiveRoomId(socketId, roomId);
  }

  /// update websocket active room id
  /// this is used when user join new room
  /// this remove previous room and set new room
  void updateActiveRoomId(String socketId, String roomId) {
    WebsocketInfo? info = getWebSocketInfo(socketId);
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
    return _rooms[roomId] ?? <String>[];
  }

  /// remove websocketId from the room
  /// this is used when user leave the room
  void removeWebSocketIdFromRoom(String socketId, String? roomId) {
    if (_rooms[roomId] != null && roomId != null) {
      _rooms[roomId]?.remove(socketId);
    }
  }
}
