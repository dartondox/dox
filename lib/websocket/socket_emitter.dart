import 'dart:convert';
import 'dart:io';

import 'package:dox_core/utils/logger.dart';
import 'package:dox_core/websocket/socket_storage.dart';

class SocketEmitter {
  String? roomId;

  final String? sender;

  SocketEmitter({this.sender, this.roomId});

  SocketStorage storage = SocketStorage();

  SocketEmitter room(id) {
    roomId = id;
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
    if (roomId == null) {
      DoxLogger.warn('set a room to emit');
      return;
    }
    List<String> members = storage.getConnectionsFromRoom(roomId!);
    for (String socketId in members) {
      if (!exclude.contains(socketId)) {
        var connection = storage.getConnection(socketId);
        if (connection != null) {
          WebSocket websocket = connection['websocket'] as WebSocket;
          websocket.add(payload);
        }
      }
    }
  }
}
