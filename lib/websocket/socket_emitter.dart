import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/json.dart';
import 'package:dox_core/utils/logger.dart';
import 'package:dox_core/websocket/event.dart';
import 'package:dox_core/websocket/socket_storage.dart';
import 'package:dox_core/websocket/web_socket_info.dart';

class SocketEmitter {
  /// room id to sent message
  String? roomId;

  /// sender socket id
  final String? sender;

  /// where it is sending from
  /// via callback or via isolate
  final String via;

  /// storage to get active connection
  final SocketStorage _storage = SocketStorage();

  SocketEmitter({this.sender, this.roomId, this.via = 'callback'});

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
    String payload = JSON.stringify(<String, dynamic>{
      WEB_SOCKET_EVENT_KEY: event,
      WEB_SOCKET_MESSAGE_KEY: message,
    });
    if (roomId == null) {
      DoxLogger.warn('set a room to emit');
      return;
    }
    List<String> members = _storage.getWebSocketIdsOfTheRoom(roomId!);

    /// If sending from callback, it mean we need to notify other isolates.
    /// So, sending to other isolates to get active connections of the rooms and
    /// sent message to correct clients
    if (via == 'callback' && Dox().sendPort != null) {
      Dox().sendPort?.send(
            WebSocketEmitEvent(sender, roomId!, message, event, exclude),
          );
      return;
    }

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
