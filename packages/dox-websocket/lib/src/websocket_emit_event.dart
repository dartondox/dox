import 'package:dox_websocket/src/utils/constant.dart';
import 'package:dox_websocket/src/utils/json.dart';

class WebsocketEmitEvent {
  final String senderId;
  final String roomId;
  final dynamic message;
  final String event;
  final List<dynamic> exclude;

  const WebsocketEmitEvent({
    required this.senderId,
    required this.roomId,
    required this.message,
    required this.event,
    required this.exclude,
  });

  @override
  toString() {
    return JSON.stringify(<String, dynamic>{
      'senderId': senderId,
      'roomId': roomId,
      'message': message,
      'event': event,
      'exclude': exclude,
    });
  }

  static fromString(String json) {
    Map<String, dynamic> jsond = JSON.parse(json);
    return WebsocketEmitEvent(
      senderId: jsond['senderId'],
      roomId: jsond['roomId'],
      message: jsond['message'],
      event: jsond['event'],
      exclude: jsond['exclude'],
    );
  }

  String toPayload() {
    return JSON.stringify(<String, dynamic>{
      WEB_SOCKET_EVENT_KEY: event,
      WEB_SOCKET_MESSAGE_KEY: message,
      WEB_SOCKET_SENDER_KEY: senderId,
      WEB_SOCKET_ROOM_KEY: roomId,
    });
  }
}
