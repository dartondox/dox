import 'dart:convert';
import 'dart:typed_data';

import '../constants/socket_constants.dart';
import 'socket_packet.dart';

/// Encodes Socket.IO v5 packets.
class SocketEncoder {
  const SocketEncoder();

  /// Encodes [packet].
  ///
  /// The first item is the text packet. Each next item is one binary
  /// attachment ([Uint8List]). Send them in this order.
  List<Object> encode(SocketPacket packet) {
    SocketPacketType type = packet.type;
    Object? data = packet.data;
    List<Uint8List> attachments = <Uint8List>[];
    if ((packet.isEvent || packet.isAck) && hasBinary(data)) {
      data = _deconstruct(data, attachments);
      type = packet.isEvent
          ? SocketPacketType.binaryEvent
          : SocketPacketType.binaryAck;
    }
    StringBuffer out = StringBuffer()..write(type.index);
    if (type == SocketPacketType.binaryEvent ||
        type == SocketPacketType.binaryAck) {
      out.write('${attachments.length}-');
    }
    if (packet.nsp != defaultNamespace) out.write('${packet.nsp},');
    if (packet.id != null) out.write(packet.id);
    if (data != null) out.write(jsonEncode(data));
    return <Object>[out.toString(), ...attachments];
  }

  /// True when [data] holds binary data somewhere inside.
  bool hasBinary(Object? data) {
    if (data is Uint8List || data is ByteBuffer) return true;
    if (data is List) return data.any(hasBinary);
    if (data is Map) return data.values.any(hasBinary);
    return false;
  }

  Object? _deconstruct(Object? data, List<Uint8List> attachments) {
    if (data is Uint8List || data is ByteBuffer) {
      attachments.add(
        data is ByteBuffer ? data.asUint8List() : data as Uint8List,
      );
      return <String, Object>{
        placeholderKey: true,
        'num': attachments.length - 1,
      };
    }
    if (data is List) {
      return <Object?>[
        for (Object? item in data) _deconstruct(item, attachments),
      ];
    }
    if (data is Map) {
      return <String, Object?>{
        for (MapEntry<Object?, Object?> entry in data.entries)
          entry.key.toString(): _deconstruct(entry.value, attachments),
      };
    }
    return data;
  }
}
