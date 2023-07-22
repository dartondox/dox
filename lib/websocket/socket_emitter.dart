import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/logger.dart';
import 'package:dox_core/websocket/socket_storage.dart';
import 'package:dox_core/websocket/web_socket_info.dart';

class SocketEmitter {
  /// room id to sent message
  String? roomId;

  /// sender socket id
  final String? sender;

  /// storage to get active connection
  final SocketStorage _storage = SocketStorage();

  SocketEmitter({this.sender, this.roomId});

  /// set room to sent message
  /// ```
  /// emitter.room('ABC');
  /// ```
  SocketEmitter room(dynamic id) {
    roomId = id;
    return this;
  }

  /// set message except the sender
  /// ```
  /// emitter.emitExceptSender('event', message);
  /// ```
  void emitExceptSender(String event, dynamic message) {
    if (sender != null) {
      emit(event, message, exclude: <String>[sender!]);
    }
  }

  /// set message to everyone in the room
  /// ```
  /// emitter.emit('event', message);
  /// ```
  void emit(String event, dynamic message,
      {List<String> exclude = const <String>[]}) {
    String payload = jsonEncode(<String, dynamic>{
      WEB_SOCKET_EVENT_KEY: event,
      WEB_SOCKET_MESSAGE_KEY: message,
    });
    if (roomId == null) {
      DoxLogger.warn('set a room to emit');
      return;
    }
    List<String> members = _storage.getWebSocketIdsOfTheRoom(roomId!);
    for (String socketId in members) {
      if (!exclude.contains(socketId)) {
        WebSocketInfo? info = _storage.getWebSocketInfo(socketId);
        if (info != null) {
          WebSocket websocket = info.websocket;
          websocket.add(payload);
        }
      }
    }
  }
}
