import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

import '../openapi/annotation_reader.dart';
import '../openapi/dart_literal.dart';
import 'json_schema_reader.dart';

/// The JSON Schema of a `@Dto` class, from its fields and annotations.
///
/// This is the one place that knows how a DTO looks as JSON Schema.
/// The OpenAPI builder uses it. A DTO validator generator can use it too.
///
/// - Each instance field is one property, by its Dart name.
/// - A non-nullable field without a constructor default is required.
/// - A constructor default becomes `default`.
/// - `@Length`, `@Email`, `@Min`, `@Max`, `@Pattern`, `@MinItems`,
///   `@MaxItems` and `@Format` add JSON Schema keywords. `@Trim` adds none.
class DtoSchema {
  const DtoSchema({
    this.annotations = const AnnotationReader(),
    this.literal = const DartLiteral(),
  });

  final AnnotationReader annotations;
  final DartLiteral literal;

  /// True when [element] has `@Dto()`.
  bool isDto(Element element) {
    return annotations.has(element, 'Dto');
  }

  /// The object schema of [dto]. Field types go through [types], so a
  /// nested `@Dto` or model becomes a `$ref`.
  Future<Map<String, dynamic>> of(
    ClassElement dto,
    JsonSchemaReader types,
  ) async {
    Map<String, Object?> defaults = _defaults(dto);
    Map<String, dynamic> properties = <String, dynamic>{};
    List<String> required = <String>[];
    for (FieldElement field in dto.fields) {
      if (field.isStatic || !field.isOriginDeclaration || field.isPrivate) {
        continue;
      }
      String name = field.displayName;
      Map<String, dynamic> schema = <String, dynamic>{
        ...?await types.of(field.type, nullable: false),
      };
      _constraints(field, schema);
      String? doc = types.docText(field.documentationComment);
      if (doc != null) schema['description'] = doc;
      bool hasDefault = defaults.containsKey(name);
      if (hasDefault && defaults[name] != null) {
        schema['default'] = defaults[name];
      }
      bool nullable =
          field.type.nullabilitySuffix == NullabilitySuffix.question;
      if (nullable) {
        schema = types.orNull(schema);
      } else if (!hasDefault) {
        required.add(name);
      }
      properties[name] = schema;
    }
    return <String, dynamic>{
      'type': 'object',
      'properties': properties,
      if (required.isNotEmpty) 'required': required,
    };
  }

  /// JSON Schema keywords from the field annotations
  void _constraints(FieldElement field, Map<String, dynamic> schema) {
    DartObject? length = annotations.first(field, 'Length');
    if (length != null) {
      int? min = length.getField('min')?.toIntValue();
      int? max = length.getField('max')?.toIntValue();
      if (min != null) schema['minLength'] = min;
      if (max != null) schema['maxLength'] = max;
    }
    if (annotations.has(field, 'Email')) schema['format'] = 'email';
    _number(field, 'Min', 'minimum', schema);
    _number(field, 'Max', 'maximum', schema);
    _number(field, 'MinItems', 'minItems', schema);
    _number(field, 'MaxItems', 'maxItems', schema);
    String? pattern = annotations
        .first(field, 'Pattern')
        ?.getField('regex')
        ?.toStringValue();
    if (pattern != null) schema['pattern'] = pattern;
    String? format = annotations
        .first(field, 'Format')
        ?.getField('name')
        ?.toStringValue();
    if (format != null) schema['format'] = format;
  }

  void _number(
    FieldElement field,
    String annotation,
    String keyword,
    Map<String, dynamic> schema,
  ) {
    DartObject? value = annotations.first(field, annotation)?.getField('value');
    num? number = value?.toIntValue() ?? value?.toDoubleValue();
    if (number != null) schema[keyword] = number;
  }

  /// field name => default value, from the unnamed constructor.
  /// A field with a default that is not JSON-like maps to null.
  Map<String, Object?> _defaults(ClassElement dto) {
    Map<String, Object?> defaults = <String, Object?>{};
    ConstructorElement? constructor = dto.unnamedConstructor;
    if (constructor == null) return defaults;
    for (FormalParameterElement param in constructor.formalParameters) {
      if (!param.hasDefaultValue) continue;
      defaults[param.displayName] = _value(param.computeConstantValue());
    }
    return defaults;
  }

  /// a default value as JSON. an enum value becomes its name.
  Object? _value(DartObject? object) {
    DartType? type = object?.type;
    if (type is InterfaceType && type.element is EnumElement) {
      return object?.variable?.displayName;
    }
    return literal.fromConstant(object);
  }
}
