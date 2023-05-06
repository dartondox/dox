import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';

class DoxWebsocket {
  /// Singleton
  static final DoxWebsocket _singleton = DoxWebsocket._internal();
  factory DoxWebsocket() => _singleton;
  DoxWebsocket._internal();

  Map<String, Map<String, dynamic>> activeConnections = {};

  Map<String, List<String>> rooms = {};

  Map<String, Function> events = {};

  static on(event, Function(SocketEmitter, dynamic) controller) {
    DoxWebsocket().events[event] = controller;
  }

  handle(DoxRequest req) async {
    WebSocket websocket = await WebSocketTransformer.upgrade(req.httpRequest);
    String socketId = 'websocket:${DateTime.now().microsecondsSinceEpoch}';
    activeConnections[socketId] = {
      "socket_id": socketId,
      "websocket": websocket,
      "previous_room": null,
      "current_room": null,
    };

    websocket.listen(
      (dynamic msg) async {
        Map<String, dynamic> payload = jsonDecode(msg);
        String event = payload['event'];
        dynamic message = payload['message'];
        if (events[event] != null) {
          Function.apply(
              events[event] as Function, [SocketEmitter(socketId), message]);
        }
        if (event == 'joinRoom') {
          _joinRoom(message, socketId);
        }
      },
      onDone: () async {
        _removeSocketIdFromCurrentRoom(socketId);
        activeConnections.remove(socketId);
      },
      onError: (dynamic error) async {
        _removeSocketIdFromCurrentRoom(socketId);
        activeConnections.remove(socketId);
      },
    );
    return websocket;
  }

  _joinRoom(String roomId, String socketId) {
    /// add socket id to room
    if (DoxWebsocket().rooms[roomId] == null) {
      DoxWebsocket().rooms[roomId] = [];
    }
    DoxWebsocket().rooms[roomId]?.add(socketId);

    /// assign active room to it's connection
    var data = DoxWebsocket().activeConnections[socketId];
    if (data != null) {
      data['current_room'] = roomId;
      if (data['previous_room'] != null) {
        _removeFromRoom(data['previous_room'], socketId);
      }
      data['previous_room'] = roomId;
    }
  }

  _removeSocketIdFromCurrentRoom(socketId) {
    var data = DoxWebsocket().activeConnections[socketId];
    if (data != null && data['current_room'] != null) {
      _removeFromRoom(data['current_room'], socketId);
    }
  }

  _removeFromRoom(String roomId, String socketId) {
    if (DoxWebsocket().rooms[roomId] != null) {
      DoxWebsocket().rooms[roomId]?.remove(socketId);
    }
  }
}

class SocketEmitter {
  String? _roomId;

  final String sender;

  SocketEmitter(this.sender);

  SocketEmitter room(roomId) {
    _roomId = roomId;
    return this;
  }

  emitExceptSender(String event, dynamic message) {
    emit(event, message, exclude: [sender]);
  }

  emit(String event, dynamic message, {List<String> exclude = const []}) {
    String payload = jsonEncode({
      "event": event,
      "message": message,
    });
    List<String> members = DoxWebsocket().rooms[_roomId] ?? [];
    for (String socketId in members) {
      if (!exclude.contains(socketId)) {
        var data = DoxWebsocket().activeConnections[socketId];
        if (data != null) {
          WebSocket websocket = data['websocket'] as WebSocket;
          websocket.add(payload);
        }
      }
    }
  }
}
