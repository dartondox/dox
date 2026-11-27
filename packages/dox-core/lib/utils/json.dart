import 'dart:convert';
import 'dart:typed_data';

import 'package:dox_annotation/dox_annotation.dart';
import 'package:dox_core/app.dart';
import 'package:dox_core/utils/json_bytes_encoder.dart';
import 'package:dox_validation/dox_validation.dart' show DtoSchema;

/// encodes json straight to utf8 bytes, without building a String first.
/// One encoder for the isolate: it keeps its buffer between calls.
final JsonBytesEncoder _jsonBytesEncoder = JsonBytesEncoder(
  advanceEncode,
  writerOf: _dtoWriter,
);

/// The schema of a DTO (`AppConfig(dtos: dtos)`) that can write the JSON
/// of [object], or null. A DTO class with its own `toJson()` has none.
JsonObjectWriter? _dtoWriter(Object object) {
  DtoSchema<Object>? schema = Dox().dtos.ofType(object.runtimeType);
  return schema is JsonObjectWriter ? schema as JsonObjectWriter : null;
}

/// `CoreFlags.sdkJsonEncoder` of this isolate. `Dox().initialize` sets
/// it, so an encode does not read the flags each time.
bool useSdkJsonEncoder = false;

/// The encoder of the Dart SDK, for `CoreFlags.sdkJsonEncoder`. It calls
/// `toJson()` for a model and makes the map of a DTO: see [advanceEncode].
final JsonUtf8Encoder _sdkEncoder = JsonUtf8Encoder(null, advanceEncode, 1024);

/// [value] as JSON bytes with no copy, for the response of the native
/// server. The result is a part of the encoder buffer: call
/// [giveBackJsonBytes] when it is copied. All other code uses
/// `JSON.bytes`.
///
/// With `CoreFlags.sdkJsonEncoder` the result is a list of its own.
Uint8List jsonBytesView(Object? value) {
  if (useSdkJsonEncoder) return _sdkBytes(value);
  return _jsonBytesEncoder.convertView(value);
}

Uint8List _sdkBytes(Object? value) {
  List<int> bytes = _sdkEncoder.convert(value);
  return bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
}

/// Gives back the buffer of [jsonBytesView]: call it when [view] is
/// copied. Until then, every JSON encode of this isolate writes into a new
/// buffer, so it can not change [view].
void giveBackJsonBytes(List<int> view) => _jsonBytesEncoder.giveBack(view);

/// true while a result of [jsonBytesView] is not given back. For tests.
bool get jsonBytesLent => _jsonBytesEncoder.isLent;

/// decodes utf8 bytes straight into json, without a middle String.
final Converter<List<int>, Object?> _jsonUtf8Decoder = utf8.decoder.fuse(
  json.decoder,
);

/// Small helper to turn data into JSON and JSON back into data.
///
/// It works with a `String` or with UTF-8 bytes.
///
/// ```dart
/// String text = JSON.stringify({'name': 'dox'});
/// List<int> bytes = JSON.bytes({'name': 'dox'});
/// Map<String, dynamic> data = JSON.parse(text);
/// ```
class JSON {
  /// Turns [value] into a JSON `String`.
  ///
  /// A `DateTime` becomes an ISO 8601 string.
  /// Any other object must have a `toJson()` method.
  /// A value with no `toJson()` throws a `JsonUnsupportedObjectError`.
  ///
  /// ```dart
  /// JSON.stringify({'name': 'dox'}); // {"name":"dox"}
  /// JSON.stringify({'at': DateTime.utc(2024)}); // {"at":"2024-01-01T00:00:00.000Z"}
  /// JSON.stringify(user); // calls user.toJson()
  /// ```
  static String stringify(Object? value) {
    return const JsonEncoder(advanceEncode).convert(value);
  }

  /// Turns [value] into UTF-8 bytes, in one pass.
  ///
  /// No `String` is built in between. It follows the same rules as
  /// [stringify].
  /// Use it for sockets, files, queues and HTTP client bodies.
  ///
  /// Do not return it from a controller. Dox already turns a `Map`, a `List`
  /// or a model into JSON bytes for the response.
  ///
  /// ```dart
  /// List<int> body = JSON.bytes({'name': 'dox'});
  /// await File('data.json').writeAsBytes(body);
  /// ```
  static List<int> bytes(Object? value) {
    if (useSdkJsonEncoder) return _sdkBytes(value);
    return _jsonBytesEncoder.convert(value);
  }

  /// Reads JSON from a `String` or from UTF-8 bytes.
  ///
  /// Bytes are read in one pass. No full `String` is built. When you have
  /// both, prefer bytes. For example, use `res.bodyBytes` instead of
  /// `res.body` from an HTTP client.
  ///
  /// The result is a `Map`, `List`, `String`, `num`, `bool` or `null`.
  /// JSON has no date type, so a date comes back as a `String`.
  ///
  /// Throws a `FormatException` for bad JSON or bad UTF-8.
  /// Throws an `ArgumentError` for any other type of [input].
  ///
  /// ```dart
  /// Map<String, dynamic> a = JSON.parse('{"name":"dox"}');
  /// Map<String, dynamic> b = JSON.parse(res.bodyBytes);
  /// ```
  static dynamic parse(Object input) {
    if (input is String) {
      return jsonDecode(input);
    }
    if (input is List<int>) {
      return _jsonUtf8Decoder.convert(input);
    }
    throw ArgumentError.value(
      input,
      'input',
      'must be a String or a List<int> of UTF-8 bytes',
    );
  }
}

dynamic advanceEncode(dynamic object) {
  if (object is DateTime) {
    return object.toIso8601String();
  }
  // a DTO in a response has no toJson(): its schema makes the map
  DtoSchema<Object>? schema = Dox().dtos.ofType(object.runtimeType);
  if (schema != null && schema is JsonObjectWriter) {
    return schema.toMap(object as Object);
  }
  return object.toJson();
}
