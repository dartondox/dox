import 'dart:convert';
import 'dart:typed_data';

import '../constants/engine_constants.dart';

/// One Engine.IO packet.
///
/// [data] is a [String], a [Uint8List] (binary message) or null.
class EnginePacket {
  const EnginePacket(this.type, [this.data]);

  final EnginePacketType type;
  final Object? data;

  /// True when this packet carries binary data.
  bool get isBinary => data is Uint8List;

  @override
  String toString() => 'EnginePacket(${type.name}, $data)';
}

/// A text message sent to many clients.
///
/// Use it as the data of a message packet. The websocket frame (`4` and
/// the text) is built and UTF-8 encoded once, on first use, and then
/// shared by every client. Polling uses [text].
class SharedText {
  SharedText(this.text);

  final String text;

  /// UTF-8 bytes of the websocket text frame.
  late final Uint8List frame = utf8.encode(
    '${EnginePacketType.message.index}$text',
  );

  @override
  String toString() => text;
}

/// Encodes and decodes Engine.IO v4 packets and polling payloads.
class EngineParser {
  const EngineParser();

  /// Encodes a packet for a websocket frame.
  ///
  /// Returns a [String] for a text frame or a [Uint8List] for a binary frame.
  /// A [SharedText] is sent with `addUtf8Text`, not with this.
  Object encodeForWebsocket(EnginePacket packet) {
    Object? data = packet.data;
    if (data is Uint8List) return data;
    return '${packet.type.index}${data ?? ''}';
  }

  /// Encodes a packet for a polling payload. Binary becomes base64.
  String encodeForPolling(EnginePacket packet) {
    Object? data = packet.data;
    if (data is Uint8List) return '$pollingBinaryPrefix${base64.encode(data)}';
    if (data is SharedText) return '${packet.type.index}${data.text}';
    return '${packet.type.index}${data ?? ''}';
  }

  /// Joins packets into one polling payload.
  String encodePayload(List<EnginePacket> packets) {
    return packets.map(encodeForPolling).join(pollingSeparator);
  }

  /// Decodes one websocket frame. Throws [FormatException] on bad input.
  EnginePacket decodeFrame(Object frame) {
    if (frame is String) return decodeText(frame);
    if (frame is List<int>) {
      return EnginePacket(EnginePacketType.message, Uint8List.fromList(frame));
    }
    throw const FormatException('unknown frame type');
  }

  /// Decodes one text packet. Throws [FormatException] on bad input.
  EnginePacket decodeText(String text) {
    if (text.isEmpty) throw const FormatException('empty packet');
    if (text.startsWith(pollingBinaryPrefix)) {
      return EnginePacket(
        EnginePacketType.message,
        base64.decode(text.substring(1)),
      );
    }
    int? type = int.tryParse(text[0]);
    if (type == null || type >= EnginePacketType.values.length) {
      throw FormatException('unknown packet type', text);
    }
    return EnginePacket(EnginePacketType.values[type], text.substring(1));
  }

  /// Splits and decodes a polling payload.
  List<EnginePacket> decodePayload(String payload) {
    return payload.split(pollingSeparator).map(decodeText).toList();
  }
}
