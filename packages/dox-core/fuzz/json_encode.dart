import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/json.dart' show advanceEncode;
import 'package:dox_core/utils/json_bytes_encoder.dart';

import 'src/fuzz_target.dart';

/// The JSON encoder of Dox, against the encoder of the Dart SDK.
///
/// The input is read as steps that build a value: text with any UTF-16
/// units (also a lone surrogate), small and large numbers, `NaN`, lists,
/// maps with any keys, dates, and objects that write their own JSON. Both
/// encoders must give the same bytes, or both must throw the same error.
///
/// It also checks the buffer that the encoder lends for a response: while
/// it is lent, other calls must not change it.
class JsonEncodeTarget extends FuzzTarget {
  const JsonEncodeTarget();

  @override
  String get name => 'json_encode';

  @override
  String get library => 'package:dox_core/utils/json_bytes_encoder.dart';

  @override
  List<String> get seeds => <String>[
    'hello world',
    '\u0006\u0003\u0000\u0005abcde\u0001\u0009\u0004\u0002',
    '\u0007\u0004\u0003key\u0000\u0004text\u0008\u0001\u0002\u0003\u0009',
    '\u0007\u0002\u0002é\u0000\u0003😀"\u0006\u0002\u0003\u0010\u0003\u0011',
    '\u0000\u0010a"b\\c\nd\te\u0000f\u001fg',
    '\u00022\u0000\u0000\u00023￿￿\u0003\u0003',
    '\u0008ሴ噸\u0002\u0009\u0007\u0001\u0002x\u0001\u0005',
    '\u0000\u0004𐀀\ud800z',
  ];

  static final JsonUtf8Encoder _sdk = JsonUtf8Encoder(null, advanceEncode);
  static final JsonBytesEncoder _own = JsonBytesEncoder(advanceEncode);

  @override
  void check(String input) {
    Object? value = _build(_Reader(input), 0);
    Object? other = _build(_Reader(_reverse(input)), 0);
    String sdk = _result(() => _sdk.convert(value));
    String sdkOther = _result(() => _sdk.convert(other));

    String own = _result(() => _own.convert(value));
    if (own != sdk) throw StateError('convert: $own, sdk: $sdk');

    /// the view, and other calls while it is lent
    Uint8List view;
    try {
      view = _own.convertView(value);
    } on Object catch (error) {
      if (!sdk.startsWith('error')) rethrow;
      if ('error ${error.runtimeType}' != sdk) {
        throw StateError('view: ${error.runtimeType}, sdk: $sdk');
      }
      if (_own.isLent) throw StateError('an error left the buffer lent');
      return;
    }
    if ('bytes ${base64.encode(view)}' != sdk) {
      throw StateError('view: ${base64.encode(view)}, sdk: $sdk');
    }
    List<int> before = List<int>.of(view);
    String copy = _result(() => _own.convert(other));
    String second = _result(() => _own.convertView(other));
    if (copy != sdkOther || second != sdkOther) {
      throw StateError('while lent: $copy, $second, sdk: $sdkOther');
    }
    if (!_same(view, before)) {
      throw StateError('a call changed the lent bytes');
    }
    _own.giveBack(Uint8List.fromList(view));
    if (!_own.isLent) throw StateError('a copy gave the buffer back');
    _own.giveBack(view);
    if (_own.isLent) throw StateError('the buffer is still lent');

    /// given back: the next view is right
    String again = _result(() {
      Uint8List next = _own.convertView(other);
      _own.giveBack(next);
      return next;
    });
    if (again != sdkOther) throw StateError('after: $again, sdk: $sdkOther');
  }

  static String _result(List<int> Function() encode) {
    try {
      return 'bytes ${base64.encode(encode())}';
    } on Object catch (error) {
      return 'error ${error.runtimeType}';
    }
  }

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static String _reverse(String text) {
    return String.fromCharCodes(text.codeUnits.reversed);
  }

  /// A value from the next steps of [r]. [depth] stops deep nesting.
  static Object? _build(_Reader r, int depth) {
    int op = r.next() % (depth > 5 ? 6 : 10);
    switch (op) {
      case 0:
        return r.take(r.next() % 48);
      case 1:
        return r.next() * 7919 - 300000;
      case 2:
        int a = r.next();
        if (a % 50 == 0) return -9223372036854775807 - 1;
        if (a % 50 == 1) return 9223372036854775807;
        int big = (a << 40) | (r.next() << 20) | r.next();
        return a.isOdd ? -big : big;
      case 3:
        int a = r.next();
        return switch (a % 8) {
          0 => a / 7,
          1 => -a * 1e-7,
          2 => a * 1e300,
          3 => a / 1e310,
          4 => 0.0,
          5 => -0.0,
          6 => a.isEven ? double.nan : double.infinity,
          _ => a + 0.5,
        };
      case 4:
        return r.next().isEven;
      case 5:
        return null;
      case 6:
        return <Object?>[
          for (int i = r.next() % 6; i > 0 && !r.done; i--)
            _build(r, depth + 1),
        ];
      case 7:
        return <String, Object?>{
          for (int i = r.next() % 6; i > 0 && !r.done; i--)
            r.take(r.next() % 40): _build(r, depth + 1),
        };
      case 8:
        return _Dated(
          _date(r),
          r.next() * 31 - 1000,
          r.next().isEven ? null : r.take(r.next() % 20),
        );
      default:
        return _Fields(<String, Object?>{
          for (int i = r.next() % 5; i > 0 && !r.done; i--)
            r.take(r.next() % 36): _build(r, depth + 1),
        });
    }
  }

  /// A date from the full range of `DateTime`, UTC or local.
  static DateTime _date(_Reader r) {
    const int range = 8640000000000000000;
    int micros =
        ((r.next() << 44) | (r.next() << 28) | (r.next() << 12)) % range;
    if (r.next().isOdd) micros = -micros;
    return DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: r.next().isEven);
  }
}

/// Reads the UTF-16 units of the input, one at a time.
class _Reader {
  _Reader(this.text);
  final String text;
  int at = 0;

  bool get done => at >= text.length;

  int next() => done ? 0 : text.codeUnitAt(at++);

  String take(int count) {
    int end = min(at + count, text.length);
    String part = text.substring(at, end);
    at = end;
    return part;
  }
}

/// Writes a date, a whole number and a text with the writer. The SDK
/// encoder uses [toJson], which gives the same JSON.
class _Dated implements JsonWritable {
  _Dated(this.at, this.n, this.text);
  final DateTime at;
  final int n;
  final String? text;

  @override
  void writeJson(JsonWriter writer) {
    writer.startObject();
    writer.key('at');
    writer.dateTime(at);
    writer.key('n');
    writer.integer(n);
    writer.key('text');
    writer.string(text);
    writer.endObject();
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'at': at.toIso8601String(), 'n': n, 'text': text};
  }
}

/// Writes any keys and values with the writer. The SDK encoder uses
/// [toJson], which gives the same JSON.
class _Fields implements JsonWritable {
  _Fields(this.fields);
  final Map<String, Object?> fields;

  @override
  void writeJson(JsonWriter writer) {
    writer.startObject();
    fields.forEach((String key, Object? value) {
      writer.key(key);
      writer.value(value);
    });
    writer.endObject();
  }

  Map<String, Object?> toJson() => fields;
}

Future<void> main(List<String> args) => const JsonEncodeTarget().run(args);
