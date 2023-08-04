class WebSocketEmitEvent {
  final String senderId;
  final String roomId;
  final dynamic message;
  final String event;
  final List<String> exclude;

  const WebSocketEmitEvent(
      this.senderId, this.roomId, this.message, this.event, this.exclude);
}
