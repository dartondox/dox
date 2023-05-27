import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';

class SocketEmitter {
  String? _roomId;

  final String? sender;

  SocketEmitter({this.sender});

  SocketEmitter room(roomId) {
    _roomId = roomId;
    return this;
  }

  emitExceptSender(String event, dynamic message) {
    if (sender != null) {
      emit(event, message, exclude: [sender!]);
    }
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
