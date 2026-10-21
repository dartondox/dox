import 'engine_packet.dart';

/// Gets events from a [Transport].
abstract class TransportListener {
  /// A packet came in on [transport].
  void onTransportPacket(Transport transport, EnginePacket packet);

  /// [transport] can send now (a new poll request came in).
  void onTransportWritable(Transport transport);

  /// [transport] is closed.
  void onTransportClose(Transport transport, String reason);
}

/// A way to move Engine.IO packets: HTTP long-polling or websocket.
abstract class Transport {
  /// Gets the events of this transport. Set by the session.
  TransportListener? listener;

  /// Transport name, like `polling` or `websocket`.
  String get name;

  /// True when [send] can write now.
  bool get writable;

  /// Sends packets. Only call it when [writable] is true.
  void send(List<EnginePacket> packets);

  /// Closes the transport.
  void close();
}
