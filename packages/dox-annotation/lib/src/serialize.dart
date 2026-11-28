import 'json_writer.dart';

/// Makes dox_builder write fast JSON code for a class.
///
/// Put it on a `Serializer` subclass. Its `convert()` then gets a JSON
/// writer that writes the map of `convert()` with no `Map` in between.
///
/// Put it on a plain class. Its public final fields are then written as
/// JSON, with snake_case keys (`@Name` changes one key), like a `@Dto`.
///
/// Add `part '<file>.g.dart';` to the file and run
/// `dart run build_runner build`. `lib/generated/container.g.dart` then
/// gives the writers to Dox.
///
/// ```dart
/// @Serialize()
/// class UserSerializer extends Serializer<User> {
///   UserSerializer(super.data);
///
///   @override
///   Map<String, dynamic> convert(User m) {
///     return <String, dynamic>{'id': m.id, 'name': m.name};
///   }
/// }
/// ```
class Serialize {
  const Serialize();
}

/// The JSON writer that `@Serialize()` makes for one class.
///
/// The JSON encoder of dox_core finds it by the [type] of an object.
abstract interface class SerializeWriter implements JsonObjectWriter {
  /// The class that this writer writes.
  Type get type;

  /// The value that `JsonUtf8Encoder` of the Dart SDK writes for
  /// [object], with the same JSON as [writeObject]. dox_core uses it for
  /// `CoreFlags.sdkJsonEncoder` and `JSON.stringify()`.
  Object? toJsonValue(Object object);
}
