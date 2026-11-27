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

  /// Writes any other value, with the rules of `JSON.bytes()`: a `double`,
  /// a `bool`, `null`, a `List`, a `Map`, a [JsonWritable] or an object
  /// with `toJson()`.
  void value(Object? value);
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
