import 'dart:convert';
import 'dart:typed_data';

import '../constants/socket_constants.dart';
import 'socket_packet.dart';

/// Decodes Socket.IO v5 packets. Keeps state for binary attachments.
///
/// Use one decoder per connection.
class SocketDecoder {
  SocketPacket? _pending;
  int _expected = 0;
  final List<Uint8List> _buffers = <Uint8List>[];

  /// Adds one Engine.IO message ([String] or binary).
  ///
  /// Returns the full packet, or null while it waits for attachments.
  /// Throws [FormatException] on bad input.
  SocketPacket? add(Object data) {
    if (data is String) {
      if (_pending != null) {
        throw const FormatException('got text while waiting for binary');
      }
      return _start(_decodeText(data));
    }
    if (data is List<int>) {
      if (_pending == null) {
        throw const FormatException('got binary without a packet');
      }
      _buffers.add(data is Uint8List ? data : Uint8List.fromList(data));
      return _buffers.length == _expected ? _finish() : null;
    }
    throw const FormatException('unknown message type');
  }

  SocketPacket? _start(_DecodedText decoded) {
    if (decoded.attachments == 0) return decoded.packet;
    _pending = decoded.packet;
    _expected = decoded.attachments;
    return null;
  }

  SocketPacket _finish() {
    SocketPacket packet = _pending!;
    Object? data = _reconstruct(packet.data);
    _pending = null;
    _buffers.clear();
    return SocketPacket(
      type: packet.type,
      nsp: packet.nsp,
      data: data,
      id: packet.id,
    );
  }

  Object? _reconstruct(Object? data) {
    if (data is List) return data.map(_reconstruct).toList();
    if (data is Map) {
      if (data[placeholderKey] == true) {
        Object? num = data['num'];
        if (num is! int || num < 0 || num >= _buffers.length) {
          throw const FormatException('illegal attachment');
        }
        return _buffers[num];
      }
      return data.map(_reconstructEntry);
    }
    return data;
  }

  MapEntry<String, Object?> _reconstructEntry(Object? key, Object? value) {
    return MapEntry<String, Object?>(key.toString(), _reconstruct(value));
  }

  /// Decodes the text part of a packet.
  _DecodedText _decodeText(String text) {
    if (text.isEmpty) throw const FormatException('empty packet');
    int? typeIndex = int.tryParse(text[0]);
    if (typeIndex == null || typeIndex >= SocketPacketType.values.length) {
      throw FormatException('unknown packet type', text);
    }
    SocketPacketType type = SocketPacketType.values[typeIndex];
    int i = 1;

    int attachments = 0;
    if (type == SocketPacketType.binaryEvent ||
        type == SocketPacketType.binaryAck) {
      int dash = text.indexOf('-', i);
      int? count = dash < 0 ? null : int.tryParse(text.substring(i, dash));
      if (count == null || count < 0) {
        throw FormatException('illegal attachments', text);
      }
      attachments = count;
      i = dash + 1;
    }

    String nsp = defaultNamespace;
    if (i < text.length && text[i] == '/') {
      int comma = text.indexOf(',', i);
      int end = comma < 0 ? text.length : comma;
      nsp = text.substring(i, end);
      i = comma < 0 ? text.length : comma + 1;
    }

    int idStart = i;
    while (i < text.length && _isDigit(text.codeUnitAt(i))) {
      i++;
    }
    int? id = i > idStart ? int.parse(text.substring(idStart, i)) : null;

    Object? data;
    if (i < text.length) {
      try {
        data = jsonDecode(text.substring(i));
      } on FormatException {
        throw FormatException('invalid payload', text);
      }
      if (!_isPayloadValid(type, data)) {
        throw FormatException('invalid payload', text);
      }
    }
    return _DecodedText(
      SocketPacket(type: type, nsp: nsp, data: data, id: id),
      attachments,
    );
  }

  bool _isDigit(int code) => code >= 48 && code <= 57;

  bool _isPayloadValid(SocketPacketType type, Object? data) {
    switch (type) {
      case SocketPacketType.connect:
        return data is Map;
      case SocketPacketType.disconnect:
        return false;
      case SocketPacketType.connectError:
        return data is String || data is Map;
      case SocketPacketType.event:
      case SocketPacketType.binaryEvent:
        if (data is! List || data.isEmpty) return false;
        Object? name = data.first;
        return name is num ||
            (name is String && !reservedEvents.contains(name));
      case SocketPacketType.ack:
      case SocketPacketType.binaryAck:
        return data is List;
    }
  }
}

/// A decoded text packet and its number of attachments.
class _DecodedText {
  const _DecodedText(this.packet, this.attachments);

  final SocketPacket packet;
  final int attachments;
}
