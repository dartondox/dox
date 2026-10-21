import 'constants/openapi_constants.dart';

/// Anything that can give a JSON Schema, for example a dox_validation schema.
abstract class JsonSchemaSource {
  /// Returns the JSON Schema as a map.
  Map<String, dynamic> toJsonSchema();
}

/// Turns a schema input into a JSON Schema map.
///
/// It accepts a [JsonSchemaSource], any object with a `toJsonSchema()`
/// method, or a raw `Map<String, dynamic>`.
class SchemaResolver {
  /// Creates a resolver.
  const SchemaResolver();

  /// Returns the JSON Schema map for [source].
  /// Throws [ArgumentError] when [source] is not a supported type.
  Map<String, dynamic> resolve(Object source) {
    if (source is Map<String, dynamic>) {
      return source;
    }
    if (source is JsonSchemaSource) {
      return source.toJsonSchema();
    }
    Object? result;
    try {
      result = (source as dynamic).toJsonSchema();
    } on NoSuchMethodError {
      throw ArgumentError.value(
        source,
        'schema',
        'Use a Map, a JsonSchemaSource or an object with toJsonSchema()',
      );
    }
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    throw ArgumentError.value(
      source,
      'schema',
      'toJsonSchema() must return a Map',
    );
  }

  /// Returns a `$ref` map that points to the named schema [name].
  Map<String, dynamic> ref(String name) {
    return <String, dynamic>{
      r'$ref': '${OpenApiConstants.schemaRefPrefix}$name',
    };
  }
}
