import 'dart:io';

class WebsocketInfo {
  final String socketId;
  final WebSocket websocket;
  String? activeRoom;
  String? previousRoom;

  WebsocketInfo({
    required this.socketId,
    required this.websocket,
    this.activeRoom,
    this.previousRoom,
  });
}
