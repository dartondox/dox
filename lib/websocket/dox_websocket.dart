import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/websocket/socket_storage.dart';
import 'package:uuid/uuid.dart';

Uuid uuid = Uuid();

class DoxWebsocket {
  /// initially default room is path of the socket eg. /ws
  final String _defaultRoom;

  /// event name to join the room
  final String _joinRoomEventName = 'joinRoom';

  /// storage to store active socket connection
  final SocketStorage _storage = SocketStorage();

  DoxWebsocket(this._defaultRoom);

  /// registered websocket events listener
  final Map<String, Function> _events = <String, Function>{};

  /// register websocket event
  /// ```
  /// DoxWebsocket.on('info', (SocketEmitter emitter, message) {
  ///   /// your logic here
  /// });
  /// ```
  void on(String event, Function(SocketEmitter, dynamic) controller) {
    _events[event] = controller;
  }

  /// handle http request and convert into websocket
  Future<WebSocket> handle(DoxRequest req) async {
    WebSocket ws = await WebSocketTransformer.upgrade(req.httpRequest);
    String socketId = _createSocketId(req);

    /// add to active connection
    _storage.addWebSocketInfo(socketId, ws);
    _storage.addWebSocketIdToRoom(socketId, _defaultRoom);

    ws.listen(
      (dynamic data) async {
        Map<String, dynamic> payload = jsonDecode(data);

        String eventName = payload['event'];
        dynamic message = payload['message'];
        Function? controller = _events[eventName];

        if (controller != null) {
          SocketEmitter emitter =
              SocketEmitter(sender: socketId, roomId: payload['room']);
          Function.apply(controller, <dynamic>[emitter, message]);
        }

        if (eventName == _joinRoomEventName) {
          _storage.addWebSocketIdToRoom(socketId, message);
        }
      },
      onDone: () async {
        _storage.removeWebSocketInfo(socketId);
      },
      onError: (dynamic error) async {
        _storage.removeWebSocketInfo(socketId);
      },
    );
    return ws;
  }

  /// creating socket id with unique timestamp
  String _createSocketId(DoxRequest req) {
    return 'ws:${uuid.v4()}';
  }
}
