import 'dart:io';

import 'package:dox_websocket/dox_websocket.dart';
import 'package:dox_websocket/src/websocket_storage.dart';

class WebsocketEmitter {
  /// room id to sent message
  String _roomId;

  /// sender socket id
  final String sender;

  /// where it is sending from
  /// via callback or via isolate
  final String via;

  /// storage to get active connection
  static final WebsocketStorage _storage = WebsocketStorage();

  WebsocketEmitter(this.sender, this._roomId, {this.via = 'callback'});

  /// set room to sent message
  /// ```
  /// emitter.room('ABC');
  /// ```
  WebsocketEmitter room(dynamic id) {
    _roomId = id;
    return this;
  }

  /// emit message only to sender
  /// ```
  /// emitter.emitToSender('event', message);
  /// ```
  void emitToSender(String event, dynamic message) {
    WebsocketInfo? info = _storage.getWebSocketInfo(sender);
    if (info != null) {
      WebsocketEmitEvent emitEvent =
          WebsocketEmitEvent(sender, _roomId, message, event, []);

      /// we do not need to send via adaptor
      /// since sender will be always on the same isolate
      WebSocket websocket = info.websocket;
      websocket.add(emitEvent.toPayload());
    }
  }

  /// set message except the sender
  /// ```
  /// emitter.emitExceptSender('event', message);
  /// ```
  void emitExceptSender(String event, dynamic message) {
    emit(event, message, exclude: <String>[sender]);
  }

  /// set message to everyone in the room
  /// ```
  /// emitter.emit('event', message);
  /// ```
  void emit(String event, dynamic message,
      {List<String> exclude = const <String>[]}) {
    WebsocketEmitEvent emitEvent =
        WebsocketEmitEvent(sender, _roomId, message, event, exclude);

    WebsocketAdapterInterface? adapter = WebsocketServer().getAdapter();

    if (adapter == null) {
      /// send locally without using adapter
      /// this work only with one isolate.
      emitEventToSockets(emitEvent);
      return;
    }

    adapter.emit(emitEvent);
  }

  static emitEventToSockets(WebsocketEmitEvent event) {
    List<String> members = _storage.getWebSocketIdsOfTheRoom(event.roomId);
    for (String socketId in members) {
      if (!event.exclude.contains(socketId)) {
        WebsocketInfo? info = _storage.getWebSocketInfo(socketId);
        if (info != null) {
          WebSocket websocket = info.websocket;
          websocket.add(event.toPayload());
        }
      }
    }
  }
}
