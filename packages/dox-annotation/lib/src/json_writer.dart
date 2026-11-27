import 'dart:convert';
import 'dart:typed_data';

/// Writes one JSON object, one piece at a time, with no `Map` in between.
///
/// The JSON encoder of dox_core gives it to [JsonWritable.writeJson].
/// Call [startObject], then [key] and one value for each field, then
/// [endObject]. The writer adds the commas.
abstract interface class JsonWriter {
  /// Starts an object: `{`.
  void startObject();

  /// Writes the name of the next field: `"key":`.
  /// Write exactly one value after it.
  void key(String key);

  /// Ends the object: `}`.
  void endObject();

  /// Writes a text value, or `null`.
  void string(String? value);

  /// Writes a whole number, or `null`.
  void integer(int? value);

  /// Writes a date and time as ISO 8601 text, or `null`. It is the text
  /// of `DateTime.toIso8601String()`.
  void dateTime(DateTime? value);

  /// Writes `true`, `false` or `null`.
  void boolean(bool? value);

  /// Writes any other value, with the rules of `JSON.bytes()`: a `double`,
  /// a `bool`, `null`, a `List`, a `Map`, a [JsonWritable] or an object
  /// with `toJson()`.
  void value(Object? value);

  /// Writes the bytes of [run] as they are, with no check and no comma.
  ///
  /// It is for generated code: the generator of `@Dto` puts the fixed
  /// parts of the JSON of a DTO (like `{"id":` and `,"name":`) into runs.
  /// A run must be a part of valid JSON at that place.
  void run(JsonRun run);
}

/// A fixed part of JSON, as UTF-8 bytes, ready to write.
///
/// The bytes are also kept as 64 bit words. The JSON encoder of dox_core
/// writes a run 8 bytes at a time.
final class JsonRun {
  /// The run of the JSON text [json].
  JsonRun(String json) : this._(Uint8List.fromList(utf8.encode(json)));

  JsonRun._(this.bytes) : words = _words(bytes), length = bytes.length;

  /// the UTF-8 bytes
  final Uint8List bytes;

  /// the count of [bytes]
  final int length;

  /// [bytes] as little-endian words. The bytes after the end of the last
  /// word are 0.
  final Int64List words;

  /// At least one word, so the encoder can write the first one with no
  /// check: an empty run writes a word of zeros and moves 0 bytes.
  static Int64List _words(Uint8List bytes) {
    Int64List words = Int64List(bytes.isEmpty ? 1 : (bytes.length + 7) ~/ 8);
    Uint8List padded = Uint8List(words.length * 8)..setAll(0, bytes);
    ByteData data = ByteData.sublistView(padded);
    for (int i = 0; i < words.length; i++) {
      words[i] = data.getInt64(i * 8, Endian.little);
    }
    return words;
  }

  /// `,`: between the items of a list
  static final JsonRun comma = JsonRun(',');
}

/// A class that writes its own JSON.
///
/// The JSON encoder of dox_core calls [writeJson], and not `toJson()`, for
/// a response and for `JSON.bytes()`. The class then makes no `Map`, so
/// the response is faster.
///
/// `JSON.stringify()` and `jsonEncode()` do not call it. A class that is
/// used with them also needs a `toJson()` that gives the same JSON.
///
/// ```dart
/// class Item implements JsonWritable {
///   Item(this.id, this.name);
///   final int id;
///   final String name;
///
///   @override
///   void writeJson(JsonWriter writer) {
///     writer.startObject();
///     writer.key('id');
///     writer.integer(id);
///     writer.key('name');
///     writer.string(name);
///     writer.endObject();
///   }
/// }
/// ```
///
/// The generator of `@DoxModel` writes this method for a model.
abstract interface class JsonWritable {
  /// Writes this object with [writer].
  void writeJson(JsonWriter writer);
}

/// Writes the JSON of the objects of another class.
///
/// The generator of `@Dto` makes one for a DTO. The JSON encoder of
/// dox_core then writes a DTO in a response with no `Map` in between.
abstract interface class JsonObjectWriter {
  /// Writes [object] with [writer].
  void writeObject(Object object, JsonWriter writer);
}
