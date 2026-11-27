import 'dart:convert';
import 'dart:typed_data';

import 'package:dox_annotation/dox_annotation.dart';

/// Encodes a value to JSON as UTF-8 bytes, in one pass, into one buffer.
///
/// It gives the same bytes and the same errors as `JsonUtf8Encoder`. That
/// encoder writes each byte through a bounds check into small chunks, then
/// joins the chunks. This one makes room once per value, writes numbers
/// with no `String` in between, and copies the result one time. It writes
/// plain text 8 bytes at a time, and it keeps the bytes of the keys it
/// wrote, because an app writes the same few keys again and again.
///
/// One encoder keeps its buffer between calls, so use one per isolate.
class JsonBytesEncoder implements JsonWriter {
  JsonBytesEncoder(
    this._toEncodable, {
    JsonObjectWriter? Function(Object)? writerOf,
    // ignore: prefer_initializing_formals
  }) : _writerOf = writerOf;

  /// called for a value that is not a JSON value. It gets one chance to
  /// return one.
  final dynamic Function(dynamic object) _toEncodable;

  /// gives the writer of an object that is not a JSON value and not a
  /// [JsonWritable], or null. Such an object does not go to
  /// [_toEncodable].
  final JsonObjectWriter? Function(Object object)? _writerOf;

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

  /// the same memory as [_buffer], to write 8 bytes in one step
  late ByteData _data = ByteData.sublistView(_buffer);
  int _length = 0;

  /// The key cache has this many places. A key goes to the place of its
  /// hash code, so two keys with the same place take it from each other.
  /// With 1024 places that is rare for the keys of one app.
  static const int _cacheSize = 1024;

  /// the longest `"key":` the cache keeps, in bytes: 4 words of 8 bytes
  static const int _cacheBytes = 32;

  /// the longest key the cache keeps: [_cacheBytes] less 2 quotes and
  /// the colon
  static const int _cacheKeyLength = _cacheBytes - 3;

  /// the key that was last written at each place
  final List<String?> _cachedKeys = List<String?>.filled(_cacheSize, null);

  /// the bytes `"key":` of each cached key, as 4 words of 8 bytes
  final Int64List _cachedWords = Int64List(_cacheSize * 4);

  /// how many of those bytes are used
  final Uint8List _cachedLengths = Uint8List(_cacheSize);

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
    if (_busy) return _fresh().convert(value);
    return Uint8List.fromList(_encode(value));
  }

  /// [value] as JSON bytes, with no copy: the result is a part of the
  /// buffer of this encoder.
  ///
  /// The next [convert] or [convertView] writes over these bytes. So use
  /// the result only when it is copied or sent before any other code can
  /// encode JSON. If you are not sure, use [convert].
  Uint8List convertView(Object? value) {
    if (_busy) return _fresh().convert(value);
    return _encode(value);
  }

  /// A new encoder with the same settings, for a call from inside a call.
  JsonBytesEncoder _fresh() {
    return JsonBytesEncoder(_toEncodable, writerOf: _writerOf);
  }

  /// Writes [value] into the buffer and gives the written part of it.
  Uint8List _encode(Object? value) {
    _busy = true;
    _length = 0;
    try {
      _writeObject(value);
      return Uint8List.sublistView(_buffer, 0, _length);
    } finally {
      _busy = false;
      _seen.clear();
      // the result keeps the large buffer until it is not used any more
      if (_buffer.length > _keepSize) {
        _buffer = Uint8List(_startSize);
        _data = ByteData.sublistView(_buffer);
      }
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
    _data = ByteData.sublistView(bigger);
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
      if (object is JsonWritable) {
        // the object writes its fields itself: no map is made
        object.writeJson(this);
      } else if (_writerOf?.call(object!) case JsonObjectWriter writer) {
        writer.writeObject(object!, this);
      } else {
        dynamic custom = _toEncodable(object);
        if (!_writeJsonValue(custom)) throw JsonUnsupportedObjectError(object);
      }
      _seen.removeLast();
    } catch (error) {
      throw JsonUnsupportedObjectError(object, cause: error);
    }
  }

  @override
  void startObject() {
    _reserve(1);
    _buffer[_length++] = 0x7B;
  }

  /// A comma goes before each key but the first. The byte before the
  /// first key is the `{` of [startObject]: no value ends with that byte.
  @override
  void key(String key) {
    bool comma = _length > 0 && _buffer[_length - 1] != 0x7B;
    if (key.length <= _cacheKeyLength) {
      _writeCachedKey(key, key.hashCode & (_cacheSize - 1), comma);
      return;
    }
    _reserve(1);
    if (comma) _buffer[_length++] = _comma;
    _writeString(key);
    _reserve(1);
    _buffer[_length++] = _colon;
  }

  @override
  void endObject() {
    _reserve(1);
    _buffer[_length++] = 0x7D;
  }

  @override
  void string(String? value) {
    if (value == null) {
      _writeAscii('null');
    } else {
      _writeString(value);
    }
  }

  @override
  void integer(int? value) {
    if (value == null) {
      _writeAscii('null');
    } else {
      _writeInt(value);
    }
  }

  /// The same text as `toIso8601String()`, with no `String` in between:
  /// `2024-05-17T03:04:05.006Z`. The 3 digits of the microseconds are
  /// there only when they are not 0, and the `Z` only for a UTC time.
  @override
  void dateTime(DateTime? value) {
    if (value == null) {
      _writeAscii('null');
      return;
    }
    int year = value.year;
    if (year < 0 || year > 9999) {
      // a sign or 6 digits: rare, so the SDK makes the text
      _writeString(value.toIso8601String());
      return;
    }
    // the longest text: 2 quotes, 26 characters and the Z
    _reserve(29);
    Uint8List buffer = _buffer;
    int at = _length;
    buffer[at++] = _quote;
    buffer[at++] = _zero + year ~/ 1000;
    buffer[at++] = _zero + year ~/ 100 % 10;
    buffer[at++] = _zero + year ~/ 10 % 10;
    buffer[at++] = _zero + year % 10;
    buffer[at++] = _minus;
    int part = value.month;
    buffer[at++] = _zero + part ~/ 10;
    buffer[at++] = _zero + part % 10;
    buffer[at++] = _minus;
    part = value.day;
    buffer[at++] = _zero + part ~/ 10;
    buffer[at++] = _zero + part % 10;
    buffer[at++] = 0x54; // T
    part = value.hour;
    buffer[at++] = _zero + part ~/ 10;
    buffer[at++] = _zero + part % 10;
    buffer[at++] = _colon;
    part = value.minute;
    buffer[at++] = _zero + part ~/ 10;
    buffer[at++] = _zero + part % 10;
    buffer[at++] = _colon;
    part = value.second;
    buffer[at++] = _zero + part ~/ 10;
    buffer[at++] = _zero + part % 10;
    buffer[at++] = 0x2E; // .
    part = value.millisecond;
    buffer[at++] = _zero + part ~/ 100;
    buffer[at++] = _zero + part ~/ 10 % 10;
    buffer[at++] = _zero + part % 10;
    part = value.microsecond;
    if (part != 0) {
      buffer[at++] = _zero + part ~/ 100;
      buffer[at++] = _zero + part ~/ 10 % 10;
      buffer[at++] = _zero + part % 10;
    }
    if (value.isUtc) buffer[at++] = 0x5A; // Z
    buffer[at++] = _quote;
    _length = at;
  }

  @override
  void value(Object? value) => _writeObject(value);

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
  /// so after a bad key the other entries are skipped. The part of the
  /// map that is already in the buffer is then taken out again: the caller
  /// writes what `toEncodable` gives for the map in its place.
  bool _writeMap(Map<Object?, Object?> map) {
    int start = _length;
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
      if (key.length <= _cacheKeyLength) {
        // a map has the hash code of its keys already, so this is a read
        _writeCachedKey(key, key.hashCode & (_cacheSize - 1), !first);
      } else {
        _reserve(1);
        if (!first) _buffer[_length++] = _comma;
        _writeString(key);
        _reserve(1);
        _buffer[_length++] = _colon;
      }
      first = false;
      _writeObject(value);
    });
    if (!stringKeys) {
      _length = start;
      return false;
    }
    _reserve(1);
    _buffer[_length++] = 0x7D;
    return true;
  }

  /// Writes `"key":` with the place [slot] of the key cache, after a comma
  /// when [comma] is true.
  ///
  /// An app writes the same few keys again and again (the fields of its
  /// rows and models). So when [key] is the key that was last written
  /// with this place, its bytes are in the cache, and they are written
  /// again 8 at a time with no look at the characters. This made a list
  /// of 40 rows 10% faster to encode.
  void _writeCachedKey(String key, int slot, bool comma) {
    // room for a comma and the 4 words of a cached key
    _reserve(1 + _cacheBytes);
    if (comma) _buffer[_length++] = _comma;
    String? cached = _cachedKeys[slot];
    int word = slot * 4;
    if (identical(cached, key) || (cached != null && cached == key)) {
      int count = _cachedLengths[slot];
      ByteData data = _data;
      int at = _length;
      // a whole word is written each time. The bytes after the key are
      // not part of the result: the next write goes over them.
      data.setUint64(at, _cachedWords[word], Endian.little);
      if (count > 8) {
        data.setUint64(at + 8, _cachedWords[word + 1], Endian.little);
        if (count > 16) {
          data.setUint64(at + 16, _cachedWords[word + 2], Endian.little);
          if (count > 24) {
            data.setUint64(at + 24, _cachedWords[word + 3], Endian.little);
          }
        }
      }
      _length = at + count;
      return;
    }
    int from = _length;
    _writeString(key);
    // room for the colon, and to read 4 whole words from the key start
    _reserve(1 + _cacheBytes);
    _buffer[_length++] = _colon;
    int count = _length - from;
    // 3 bytes more than the key has characters: 2 quotes and the colon.
    // So each character took 1 byte: plain ASCII with no escape.
    if (count <= _cacheBytes && count == key.length + 3) {
      ByteData data = _data;
      _cachedWords[word] = data.getUint64(from, Endian.little);
      _cachedWords[word + 1] = data.getUint64(from + 8, Endian.little);
      _cachedWords[word + 2] = data.getUint64(from + 16, Endian.little);
      _cachedWords[word + 3] = data.getUint64(from + 24, Endian.little);
      _cachedLengths[slot] = count;
      _cachedKeys[slot] = key;
    } else {
      _cachedKeys[slot] = null;
    }
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
    if (count >= 8) {
      // 8 characters at a time: they go into one 64 bit number, one test
      // finds a character that needs more work, one write stores them.
      // This made a list of long texts 35% faster to encode.
      ByteData data = _data;
      int last = count - 8;
      while (i <= last) {
        int c0 = text.codeUnitAt(i);
        int c1 = text.codeUnitAt(i + 1);
        int c2 = text.codeUnitAt(i + 2);
        int c3 = text.codeUnitAt(i + 3);
        int c4 = text.codeUnitAt(i + 4);
        int c5 = text.codeUnitAt(i + 5);
        int c6 = text.codeUnitAt(i + 6);
        int c7 = text.codeUnitAt(i + 7);
        // not ASCII: the loop below takes it from here
        if ((c0 | c1 | c2 | c3 | c4 | c5 | c6 | c7) > 0x7F) break;
        int word =
            c0 |
            (c1 << 8) |
            (c2 << 16) |
            (c3 << 24) |
            (c4 << 32) |
            (c5 << 40) |
            (c6 << 48) |
            (c7 << 56);
        // Each byte is under 0x80 here. A byte under 0x20 gets its top
        // bit set by the first term. A quote or a backslash is zero after
        // the xor, and zero minus 1 has the top bit set.
        int quotes = word ^ 0x2222222222222222;
        int backslashes = word ^ 0x5C5C5C5C5C5C5C5C;
        int special =
            (word - 0x2020202020202020) |
            (quotes - 0x0101010101010101) |
            (backslashes - 0x0101010101010101);
        if ((special & 0x8080808080808080) != 0) break;
        data.setUint64(at, word, Endian.little);
        at += 8;
        i += 8;
      }
    }
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
