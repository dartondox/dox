import 'dart:convert';
import 'dart:typed_data';

/// A small MessagePack encoder and decoder.
///
/// It has the types that `notepack.io` (used by `@socket.io/redis-adapter`
/// and `@socket.io/redis-emitter`) writes: null, bool, int, double, String,
/// binary ([Uint8List]), List, Map and timestamps ([DateTime]).
class MsgPack {
  const MsgPack._();

  /// Encodes [value]. Other objects are encoded with their `toJson()`.
  static Uint8List encode(Object? value) {
    _Writer writer = _Writer();
    writer.write(value);
    return writer.takeBytes();
  }

  /// Decodes one value from [bytes].
  static Object? decode(Uint8List bytes) {
    _Reader reader = _Reader(bytes);
    Object? value = reader.read();
    if (reader.offset != bytes.length) {
      throw const FormatException('msgpack: extra bytes after the value');
    }
    return value;
  }
}

class _Writer {
  // Copies on add: the scratch buffer is reused.
  final BytesBuilder _out = BytesBuilder();
  final ByteData _scratch = ByteData(8);

  Uint8List takeBytes() => _out.takeBytes();

  void write(Object? value) {
    if (value == null) {
      _out.addByte(0xc0);
    } else if (value is bool) {
      _out.addByte(value ? 0xc3 : 0xc2);
    } else if (value is int) {
      _writeInt(value);
    } else if (value is double) {
      _scratch.setFloat64(0, value);
      _out.addByte(0xcb);
      _out.add(_scratch.buffer.asUint8List(0, 8));
    } else if (value is String) {
      Uint8List bytes = utf8.encode(value);
      _writeHeader(bytes.length, 0xa0, 0x20, 0xd9, 0xda, 0xdb);
      _out.add(bytes);
    } else if (value is Uint8List || value is ByteBuffer) {
      Uint8List bytes = value is ByteBuffer
          ? value.asUint8List()
          : value as Uint8List;
      _writeHeader(bytes.length, null, 0, 0xc4, 0xc5, 0xc6);
      _out.add(bytes);
    } else if (value is DateTime) {
      _writeTimestamp(value);
    } else if (value is List) {
      _writeHeader(value.length, 0x90, 0x10, null, 0xdc, 0xdd);
      for (Object? item in value) {
        write(item);
      }
    } else if (value is Map) {
      _writeHeader(value.length, 0x80, 0x10, null, 0xde, 0xdf);
      for (MapEntry<dynamic, dynamic> entry in value.entries) {
        write(entry.key is String ? entry.key : entry.key.toString());
        write(entry.value);
      }
    } else if (value is Set) {
      write(value.toList());
    } else {
      write((value as dynamic).toJson());
    }
  }

  void _writeInt(int value) {
    if (value >= 0 && value < 0x80) {
      _out.addByte(value);
    } else if (value < 0 && value >= -32) {
      _out.addByte(value & 0xff);
    } else if (value >= 0) {
      if (value < 0x100) {
        _out.add(<int>[0xcc, value]);
      } else if (value < 0x10000) {
        _scratch.setUint16(0, value);
        _put(0xcd, 2);
      } else if (value < 0x100000000) {
        _scratch.setUint32(0, value);
        _put(0xce, 4);
      } else {
        _scratch.setUint64(0, value);
        _put(0xcf, 8);
      }
    } else if (value >= -0x80) {
      _scratch.setInt8(0, value);
      _put(0xd0, 1);
    } else if (value >= -0x8000) {
      _scratch.setInt16(0, value);
      _put(0xd1, 2);
    } else if (value >= -0x80000000) {
      _scratch.setInt32(0, value);
      _put(0xd2, 4);
    } else {
      _scratch.setInt64(0, value);
      _put(0xd3, 8);
    }
  }

  /// Timestamp extension (type -1), 64 or 96 bit.
  void _writeTimestamp(DateTime value) {
    int micros = value.microsecondsSinceEpoch;
    int seconds = micros ~/ 1000000;
    int nanos = (micros % 1000000) * 1000;
    if (micros < 0 && nanos != 0) seconds -= 1;
    if (seconds >= 0 && seconds < 0x400000000) {
      _out.add(<int>[0xd7, 0xff]);
      _scratch.setUint32(0, (nanos << 2) | (seconds >> 32));
      _scratch.setUint32(4, seconds & 0xffffffff);
      _out.add(_scratch.buffer.asUint8List(0, 8));
    } else {
      _out.add(<int>[0xc7, 12, 0xff]);
      _scratch.setUint32(0, nanos);
      _out.add(_scratch.buffer.asUint8List(0, 4));
      _scratch.setInt64(0, seconds);
      _out.add(_scratch.buffer.asUint8List(0, 8));
    }
  }

  /// Writes a length header: a fix form (when [fix] is set and the length
  /// is below [fixLimit]), else the 8, 16 or 32 bit form.
  void _writeHeader(
    int length,
    int? fix,
    int fixLimit,
    int? head8,
    int head16,
    int head32,
  ) {
    if (fix != null && length < fixLimit) {
      _out.addByte(fix | length);
    } else if (head8 != null && length < 0x100) {
      _out.add(<int>[head8, length]);
    } else if (length < 0x10000) {
      _scratch.setUint16(0, length);
      _put(head16, 2);
    } else {
      _scratch.setUint32(0, length);
      _put(head32, 4);
    }
  }

  void _put(int head, int size) {
    _out.addByte(head);
    _out.add(_scratch.buffer.asUint8List(0, size));
  }
}

class _Reader {
  _Reader(this.bytes) : _data = ByteData.sublistView(bytes);

  final Uint8List bytes;
  final ByteData _data;
  int offset = 0;

  Object? read() {
    int byte = _u8();
    if (byte < 0x80) return byte;
    if (byte >= 0xe0) return byte - 0x100;
    if (byte < 0x90) return _map(byte & 0x0f);
    if (byte < 0xa0) return _list(byte & 0x0f);
    if (byte < 0xc0) return _str(byte & 0x1f);
    switch (byte) {
      case 0xc0:
        return null;
      case 0xc2:
        return false;
      case 0xc3:
        return true;
      case 0xc4:
        return _bin(_u8());
      case 0xc5:
        return _bin(_u16());
      case 0xc6:
        return _bin(_u32());
      case 0xc7:
        return _ext(_u8());
      case 0xc8:
        return _ext(_u16());
      case 0xc9:
        return _ext(_u32());
      case 0xca:
        return _data.getFloat32(_skip(4)).toDouble();
      case 0xcb:
        return _data.getFloat64(_skip(8));
      case 0xcc:
        return _u8();
      case 0xcd:
        return _u16();
      case 0xce:
        return _u32();
      case 0xcf:
        return _data.getUint64(_skip(8));
      case 0xd0:
        return _data.getInt8(_skip(1));
      case 0xd1:
        return _data.getInt16(_skip(2));
      case 0xd2:
        return _data.getInt32(_skip(4));
      case 0xd3:
        return _data.getInt64(_skip(8));
      case 0xd4:
        return _ext(1);
      case 0xd5:
        return _ext(2);
      case 0xd6:
        return _ext(4);
      case 0xd7:
        return _ext(8);
      case 0xd8:
        return _ext(16);
      case 0xd9:
        return _str(_u8());
      case 0xda:
        return _str(_u16());
      case 0xdb:
        return _str(_u32());
      case 0xdc:
        return _list(_u16());
      case 0xdd:
        return _list(_u32());
      case 0xde:
        return _map(_u16());
      case 0xdf:
        return _map(_u32());
    }
    throw FormatException(
      'msgpack: unknown type byte 0x${byte.toRadixString(16)}',
    );
  }

  /// Moves past [size] bytes and returns where they start.
  int _skip(int size) {
    int start = offset;
    if (start + size > bytes.length) {
      throw const FormatException('msgpack: message is cut off');
    }
    offset += size;
    return start;
  }

  int _u8() => _data.getUint8(_skip(1));
  int _u16() => _data.getUint16(_skip(2));
  int _u32() => _data.getUint32(_skip(4));

  String _str(int length) {
    int start = _skip(length);
    return utf8.decode(Uint8List.sublistView(bytes, start, start + length));
  }

  Uint8List _bin(int length) {
    int start = _skip(length);
    return Uint8List.fromList(
      Uint8List.sublistView(bytes, start, start + length),
    );
  }

  List<Object?> _list(int length) {
    // ponytail: no length cap; the data comes from our own Redis.
    List<Object?> list = <Object?>[];
    for (int i = 0; i < length; i++) {
      list.add(read());
    }
    return list;
  }

  Map<String, Object?> _map(int length) {
    Map<String, Object?> map = <String, Object?>{};
    for (int i = 0; i < length; i++) {
      Object? key = read();
      map[key.toString()] = read();
    }
    return map;
  }

  /// Extension types. Timestamp (-1) gives a [DateTime]. notepack.io also
  /// writes `undefined` as fixext 1 of type 0 (read as null) and old
  /// ArrayBuffers as type 0 (read as bytes). Other types give their bytes.
  Object? _ext(int length) {
    int type = _data.getInt8(_skip(1));
    int start = _skip(length);
    if (type == -1) {
      if (length == 4) return _time(_data.getUint32(start), 0);
      if (length == 8) {
        int high = _data.getUint32(start);
        int seconds = ((high & 0x3) << 32) | _data.getUint32(start + 4);
        return _time(seconds, high >> 2);
      }
      if (length == 12) {
        return _time(_data.getInt64(start + 4), _data.getUint32(start));
      }
    }
    if (type == 0 && length == 1) return null;
    return Uint8List.fromList(
      Uint8List.sublistView(bytes, start, start + length),
    );
  }

  static DateTime _time(int seconds, int nanos) {
    return DateTime.fromMicrosecondsSinceEpoch(
      seconds * 1000000 + nanos ~/ 1000,
      isUtc: true,
    );
  }
}
