import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/websocket/socket_storage.dart';

class DoxWebsocket {
  final String defaultRoom;

  DoxWebsocket(this.defaultRoom);

  SocketStorage storage = SocketStorage();

  /// registered websocket events listener
  Map<String, Function> events = {};

  /// register websocket event
  /// ```
  /// DoxWebsocket.on('info', (SocketEmitter emitter, message) {
  ///   /// do something here
  /// });
  /// ```
  on(event, Function(SocketEmitter, dynamic) controller) {
    events[event] = controller;
  }

  /// handle http request and convert into websocket
  handle(DoxRequest req) async {
    WebSocket ws = await WebSocketTransformer.upgrade(req.httpRequest);
    String socketId = _createSocketId();

    /// add to active connection
    storage.addConnection(socketId, ws);
    _joinRoom(defaultRoom, socketId);

    ws.listen(
      (dynamic data) async {
        Map<String, dynamic> payload = jsonDecode(data);

        String eventName = payload['event'];
        dynamic message = payload['message'];
        Function? controller = events[eventName];

        if (controller != null) {
          var emitter =
              SocketEmitter(sender: socketId, roomId: payload['room']);
          Function.apply(controller, [emitter, message]);
        }

        if (eventName == 'joinRoom') {
          _joinRoom(message, socketId);
        }
      },
      onDone: () async {
        _removeConnectionFromRoom(socketId);
        storage.removeConnection(socketId);
      },
      onError: (dynamic error) async {
        _removeConnectionFromRoom(socketId);
        storage.removeConnection(socketId);
      },
    );
    return ws;
  }

  /// Join the room and
  /// update connection current room joining room Id
  _joinRoom(String roomId, String socketId) {
    storage.addConnectionToRoom(socketId, roomId);
    storage.updateConnectionRoomId(socketId, roomId);
  }

  /// get connection current room and
  /// remove the connection from the room
  _removeConnectionFromRoom(socketId) {
    var connection = storage.getConnection(socketId);
    if (connection != null && connection['current_room'] != null) {
      storage.removeConnectionFromRoom(socketId, connection['current_room']);
    }
  }

  _createSocketId() {
    return 'websocket:${DateTime.now().microsecondsSinceEpoch}';
  }
}
