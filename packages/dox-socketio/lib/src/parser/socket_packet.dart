import '../constants/socket_constants.dart';

/// One Socket.IO packet.
class SocketPacket {
  const SocketPacket({
    required this.type,
    this.nsp = defaultNamespace,
    this.data,
    this.id,
  });

  /// Reads a packet from its JSON map (used by the Redis adapter).
  factory SocketPacket.fromJson(Map<String, dynamic> json) {
    return SocketPacket(
      type: SocketPacketType.values[json['type'] as int],
      nsp: json['nsp'] as String? ?? defaultNamespace,
      data: json['data'],
      id: json['id'] as int?,
    );
  }

  final SocketPacketType type;

  /// Namespace name, like `/` or `/chat`.
  final String nsp;

  /// Payload. For events: `[name, ...args]`. For acks: `[...args]`.
  final Object? data;

  /// Ack id, or null when no ack is used.
  final int? id;

  /// True for EVENT and BINARY_EVENT.
  bool get isEvent =>
      type == SocketPacketType.event || type == SocketPacketType.binaryEvent;

  /// True for ACK and BINARY_ACK.
  bool get isAck =>
      type == SocketPacketType.ack || type == SocketPacketType.binaryAck;

  /// JSON map, same shape as the Node.js packet object.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'type': type.index,
      'data': data,
      'nsp': nsp,
      if (id != null) 'id': id,
    };
  }

  @override
  String toString() => 'SocketPacket(${type.name}, $nsp, $id, $data)';
}
