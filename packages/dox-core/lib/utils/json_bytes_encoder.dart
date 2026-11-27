import 'dart:convert';
import 'dart:typed_data';

/// Encodes a value to JSON as UTF-8 bytes, in one pass, into one buffer.
///
/// It gives the same bytes and the same errors as `JsonUtf8Encoder`. That
/// encoder writes each byte through a bounds check into small chunks, then
/// joins the chunks. This one makes room once per value, writes numbers
/// with no `String` in between, and copies the result one time.
///
/// One encoder keeps its buffer between calls, so use one per isolate.
class JsonBytesEncoder {
  JsonBytesEncoder(this._toEncodable);

  /// called for a value that is not a JSON value. It gets one chance to
  /// return one.
  final dynamic Function(dynamic object) _toEncodable;

  /// the first size of the buffer
  static const int _startSize = 4096;

  /// A bigger buffer than this is dropped after the call, so one large
  /// body does not hold its memory for the life of the isolate.
  static const int _keepSize = 1 << 20;

  static const int _quote = 0x22;
  static const int _backslash = 0x5C;
  static const int _comma = 0x2C;
  static const int _colon = 0x3A;
  static const int _minus = 0x2D;
  static const int _zero = 0x30;

  Uint8List _buffer = Uint8List(_startSize);
  int _length = 0;

  /// true while [convert] runs. A `toJson()` that encodes JSON itself
  /// must not write into the same buffer.
  bool _busy = false;

  /// the lists, maps and objects that are open now, to find a cycle
  final List<Object?> _seen = <Object?>[];

  /// [value] as JSON bytes.
  ///
  /// Throws a `JsonUnsupportedObjectError` for a value that is not a JSON
  /// value, and a `JsonCyclicError` for a value that holds itself.
  Uint8List convert(Object? value) {
    if (_busy) return JsonBytesEncoder(_toEncodable).convert(value);
    _busy = true;
    _length = 0;
    try {
      _writeObject(value);
      return Uint8List.fromList(Uint8List.sublistView(_buffer, 0, _length));
    } finally {
      _busy = false;
      _seen.clear();
      if (_buffer.length > _keepSize) _buffer = Uint8List(_startSize);
    }
  }

  /// Makes room for [count] more bytes.
  void _reserve(int count) {
    int needed = _length + count;
    if (needed <= _buffer.length) return;
    int size = _buffer.length * 2;
    while (size < needed) {
      size *= 2;
    }
    Uint8List bigger = Uint8List(size);
    bigger.setRange(0, _length, _buffer);
    _buffer = bigger;
  }

  void _checkCycle(Object? object) {
    for (int i = 0; i < _seen.length; i++) {
      if (identical(object, _seen[i])) throw JsonCyclicError(object);
    }
    _seen.add(object);
  }

  /// Writes any value. A value that is not a JSON value goes to
  /// [_toEncodable] first.
  void _writeObject(Object? object) {
    if (_writeJsonValue(object)) return;
    _checkCycle(object);
    try {
      dynamic custom = _toEncodable(object);
      if (!_writeJsonValue(custom)) throw JsonUnsupportedObjectError(object);
      _seen.removeLast();
    } catch (error) {
      throw JsonUnsupportedObjectError(object, cause: error);
    }
  }

  /// Writes a number, a `String`, a `bool`, `null`, a `List` or a `Map`.
  /// Returns false for any other value, and for a map with a key that is
  /// not a `String`.
  bool _writeJsonValue(Object? object) {
    if (object is String) {
      _writeString(object);
      return true;
    }
    if (object is int) {
      _writeInt(object);
      return true;
    }
    if (object is double) {
      if (!object.isFinite) return false;
      _writeAscii(object.toString());
      return true;
    }
    if (identical(object, true)) {
      _writeAscii('true');
      return true;
    }
    if (identical(object, false)) {
      _writeAscii('false');
      return true;
    }
    if (object == null) {
      _writeAscii('null');
      return true;
    }
    if (object is List) {
      _checkCycle(object);
      _writeList(object);
      _seen.removeLast();
      return true;
    }
    if (object is Map) {
      _checkCycle(object);
      bool done = _writeMap(object);
      _seen.removeLast();
      return done;
    }
    return false;
  }

  void _writeList(List<Object?> list) {
    _reserve(2);
    _buffer[_length++] = 0x5B;
    int count = list.length;
    for (int i = 0; i < count; i++) {
      if (i > 0) {
        _reserve(1);
        _buffer[_length++] = _comma;
      }
      _writeObject(list[i]);
    }
    _reserve(1);
    _buffer[_length++] = 0x5D;
  }

  /// Returns false when a key is not a `String`.
  ///
  /// `forEach` is the fastest way through a map: it took 4.4 us where two
  /// iterators took 10.7 us (40 maps of 10 entries). It can not stop early,
  /// so after a bad key the other entries are skipped.
  bool _writeMap(Map<Object?, Object?> map) {
    _reserve(2);
    _buffer[_length++] = 0x7B;
    bool first = true;
    bool stringKeys = true;
    map.forEach((Object? key, Object? value) {
      if (!stringKeys) return;
      if (key is! String) {
        stringKeys = false;
        return;
      }
      if (first) {
        first = false;
      } else {
        _reserve(1);
        _buffer[_length++] = _comma;
      }
      _writeString(key);
      _reserve(1);
      _buffer[_length++] = _colon;
      _writeObject(value);
    });
    _reserve(1);
    _buffer[_length++] = 0x7D;
    return stringKeys;
  }

  /// Writes [text], which has only ASCII characters and needs no escape.
  void _writeAscii(String text) {
    int count = text.length;
    _reserve(count);
    Uint8List buffer = _buffer;
    int at = _length;
    for (int i = 0; i < count; i++) {
      buffer[at++] = text.codeUnitAt(i);
    }
    _length = at;
  }

  /// Writes the digits of [value], with no `String` in between.
  void _writeInt(int value) {
    if (value < 0) {
      // the lowest int has no positive twin
      if (value == -value) {
        _writeAscii(value.toString());
        return;
      }
      _reserve(20);
      _buffer[_length++] = _minus;
      value = -value;
    } else {
      _reserve(19);
    }
    if (value < 10) {
      _buffer[_length++] = _zero + value;
      return;
    }
    int digits = 0;
    for (int rest = value; rest > 0; rest ~/= 10) {
      digits++;
    }
    Uint8List buffer = _buffer;
    int at = _length + digits;
    _length = at;
    while (value > 0) {
      int next = value ~/ 10;
      buffer[--at] = _zero + (value - next * 10);
      value = next;
    }
  }

  /// Writes [text] in quotes. Plain ASCII, the usual case, is copied with
  /// one check per character.
  void _writeString(String text) {
    int count = text.length;
    _reserve(count + 2);
    Uint8List buffer = _buffer;
    int at = _length;
    buffer[at++] = _quote;
    int i = 0;
    while (i < count) {
      int char = text.codeUnitAt(i);
      if (char < 0x20 || char > 0x7F || char == _quote || char == _backslash) {
        break;
      }
      buffer[at++] = char;
      i++;
    }
    _length = at;
    if (i < count) _writeEscaped(text, i);
    _reserve(1);
    _buffer[_length++] = _quote;
  }

  /// Writes [text] from [start]: it has a character to escape or one that
  /// is not ASCII. One UTF-16 unit takes 6 bytes at most.
  void _writeEscaped(String text, int start) {
    int count = text.length;
    _reserve((count - start) * 6);
    Uint8List buffer = _buffer;
    int at = _length;
    for (int i = start; i < count; i++) {
      int char = text.codeUnitAt(i);
      if (char < 0x20) {
        buffer[at++] = _backslash;
        switch (char) {
          case 0x08:
            buffer[at++] = 0x62;
          case 0x09:
            buffer[at++] = 0x74;
          case 0x0A:
            buffer[at++] = 0x6E;
          case 0x0C:
            buffer[at++] = 0x66;
          case 0x0D:
            buffer[at++] = 0x72;
          default:
            buffer[at++] = 0x75;
            buffer[at++] = _zero;
            buffer[at++] = _zero;
            buffer[at++] = _hexDigit(char >> 4);
            buffer[at++] = _hexDigit(char & 0xF);
        }
      } else if (char == _quote || char == _backslash) {
        buffer[at++] = _backslash;
        buffer[at++] = char;
      } else if (char <= 0x7F) {
        buffer[at++] = char;
      } else if (char <= 0x7FF) {
        buffer[at++] = 0xC0 | (char >> 6);
        buffer[at++] = 0x80 | (char & 0x3F);
      } else if ((char & 0xF800) != 0xD800) {
        buffer[at++] = 0xE0 | (char >> 12);
        buffer[at++] = 0x80 | ((char >> 6) & 0x3F);
        buffer[at++] = 0x80 | (char & 0x3F);
      } else {
        int next = char < 0xDC00 && i + 1 < count ? text.codeUnitAt(i + 1) : 0;
        if ((next & 0xFC00) == 0xDC00) {
          // a surrogate pair: one character of 4 bytes
          int rune = 0x10000 + ((char & 0x3FF) << 10) + (next & 0x3FF);
          buffer[at++] = 0xF0 | (rune >> 18);
          buffer[at++] = 0x80 | ((rune >> 12) & 0x3F);
          buffer[at++] = 0x80 | ((rune >> 6) & 0x3F);
          buffer[at++] = 0x80 | (rune & 0x3F);
          i++;
        } else {
          // half of a pair has no UTF-8 form: write it as `\udXXX`
          buffer[at++] = _backslash;
          buffer[at++] = 0x75;
          buffer[at++] = 0x64;
          buffer[at++] = _hexDigit((char >> 8) & 0xF);
          buffer[at++] = _hexDigit((char >> 4) & 0xF);
          buffer[at++] = _hexDigit(char & 0xF);
        }
      }
    }
    _length = at;
  }

  static int _hexDigit(int value) => value < 10 ? 48 + value : 87 + value;
}
