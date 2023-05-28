import 'dart:io';

class WebSocketInfo {
  final String socketId;
  final WebSocket websocket;
  String? activeRoom;
  String? previousRoom;

  WebSocketInfo({
    required this.socketId,
    required this.websocket,
    this.activeRoom,
    this.previousRoom,
  });
}
