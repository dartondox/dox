import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../dto/dto_model.dart';
import '../openapi/dart_literal.dart';
import 'json_schema_reader.dart';

/// The JSON Schema of a `@Dto` class, from its fields and annotations.
///
/// The OpenAPI docs and the DTO generator both use it. The keys come
/// from [DtoReader], so they are the same as the keys the DTO reads
/// (snake_case by default).
class DtoJsonSchema {
  const DtoJsonSchema({
    this.reader = const DtoReader(),
    this.literal = const DartLiteral(),
  });

  final DtoReader reader;
  final DartLiteral literal;

  /// True when [element] has `@Dto()`.
  bool isDto(Element element) {
    return reader.isDto(element);
  }

  /// The object schema of [dto]. Field types go through [types], so a
  /// nested `@Dto` becomes a `$ref`.
  Future<Map<String, dynamic>> of(
    ClassElement dto,
    JsonSchemaReader types,
  ) async {
    return ofClass(reader.read(dto), types);
  }

  /// Same as [of], for a class that is already read.
  Future<Map<String, dynamic>> ofClass(
    DtoClass dto,
    JsonSchemaReader types,
  ) async {
    Map<String, dynamic> properties = <String, dynamic>{};
    List<String> required = <String>[];
    for (DtoField field in dto.fields) {
      Map<String, dynamic> schema = <String, dynamic>{
        ...?await types.of(field.type.type, nullable: false),
      };
      for (DtoRule rule in field.rules) {
        if (rule.custom) continue;
        Map<String, dynamic> target = schema;
        if (rule.onItems && schema['items'] is Map<String, dynamic>) {
          target = <String, dynamic>{...schema['items']};
          schema['items'] = target;
        }
        target.addAll(keywords(rule));
      }
      String? doc = types.docText(field.doc);
      if (doc != null) schema['description'] = doc;
      Object? defaultValue = _default(field);
      if (defaultValue != null) schema['default'] = defaultValue;
      if (field.type.nullable) {
        schema = types.orNull(schema);
      } else if (field.required && !field.maybe) {
        required.add(field.key);
      }
      properties[field.key] = schema;
    }
    return <String, dynamic>{
      'type': 'object',
      'title': dto.name,
      'properties': properties,
      if (required.isNotEmpty) 'required': required,
      if (dto.strict) 'additionalProperties': false,
    };
  }

  /// The JSON Schema keywords of one built-in rule.
  Map<String, dynamic> keywords(DtoRule rule) {
    switch (rule.name) {
      case 'Length':
        return <String, dynamic>{
          'minLength': ?rule.intField('min'),
          'maxLength': ?rule.intField('max'),
        };
      case 'MinLength':
        return <String, dynamic>{'minLength': rule.intField('value')};
      case 'MaxLength':
        return <String, dynamic>{'maxLength': rule.intField('value')};
      case 'Email':
        return <String, dynamic>{'format': 'email'};
      case 'Url':
        return <String, dynamic>{'format': 'uri'};
      case 'Uuid':
        return <String, dynamic>{'format': 'uuid'};
      case 'Ip':
        return <String, dynamic>{
          'anyOf': <Map<String, dynamic>>[
            <String, dynamic>{'format': 'ipv4'},
            <String, dynamic>{'format': 'ipv6'},
          ],
        };
      case 'Regex':
        return <String, dynamic>{
          'pattern': '^(?:${rule.stringField('pattern')})\$',
        };
      case 'StartsWith':
        return <String, dynamic>{
          'pattern': '^${RegExp.escape(rule.stringField('prefix') ?? '')}',
        };
      case 'EndsWith':
        return <String, dynamic>{
          'pattern': '${RegExp.escape(rule.stringField('suffix') ?? '')}\$',
        };
      case 'Alpha':
        return <String, dynamic>{'pattern': r'^[a-zA-Z]+$'};
      case 'AlphaNumeric':
        return <String, dynamic>{'pattern': r'^[a-zA-Z0-9]+$'};
      case 'AlphaDash':
        return <String, dynamic>{'pattern': r'^[a-zA-Z_-]+$'};
      case 'In':
        return <String, dynamic>{'enum': _values(rule)};
      case 'NotIn':
        return <String, dynamic>{
          'not': <String, dynamic>{'enum': _values(rule)},
        };
      case 'Min':
        return <String, dynamic>{'minimum': rule.numField('value')};
      case 'Max':
        return <String, dynamic>{'maximum': rule.numField('value')};
      case 'Range':
        return <String, dynamic>{
          'minimum': rule.numField('min'),
          'maximum': rule.numField('max'),
        };
      case 'Positive':
        return <String, dynamic>{'exclusiveMinimum': 0};
      case 'GreaterThan':
        return <String, dynamic>{'exclusiveMinimum': rule.numField('value')};
      case 'LessThan':
        return <String, dynamic>{'exclusiveMaximum': rule.numField('value')};
      case 'MinItems':
        return <String, dynamic>{'minItems': rule.intField('value')};
      case 'MaxItems':
        return <String, dynamic>{'maxItems': rule.intField('value')};
      case 'UniqueItems':
        return <String, dynamic>{'uniqueItems': true};
      case 'After':
      case 'Before':
        return <String, dynamic>{'format': 'date-time'};
      case 'MaxSize':
        return <String, dynamic>{
          'maxLength': DtoReader.sizeOf(rule.stringField('size') ?? ''),
        };
      case 'Mimes':
        return <String, dynamic>{
          'contentMediaType': <String>[
            for (DartObject type
                in rule.value.getField('types')?.toListValue() ??
                    const <DartObject>[])
              mediaType(type.toStringValue() ?? ''),
          ].join(', '),
        };
      case 'Image':
        return <String, dynamic>{'contentMediaType': 'image/*'};
    }
    return <String, dynamic>{};
  }

  /// A media type for a file extension, like `application/pdf`.
  static String mediaType(String extension) {
    return _media[extension.toLowerCase()] ?? 'application/octet-stream';
  }

  static const Map<String, String> _media = <String, String>{
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'bmp': 'image/bmp',
    'svg': 'image/svg+xml',
    'pdf': 'application/pdf',
    'zip': 'application/zip',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'txt': 'text/plain',
    'csv': 'text/csv',
    'json': 'application/json',
    'mp3': 'audio/mpeg',
    'mp4': 'video/mp4',
  };

  List<Object?> _values(DtoRule rule) {
    return <Object?>[
      for (DartObject item
          in rule.value.getField('values')?.toListValue() ??
              const <DartObject>[])
        literal.fromConstant(item),
    ];
  }

  /// The default value as JSON. An enum value becomes its name.
  Object? _default(DtoField field) {
    if (!field.hasDefault) return null;
    ConstructorElement? constructor =
        (field.element.enclosingElement as ClassElement).unnamedConstructor;
    for (FormalParameterElement param
        in constructor?.formalParameters ?? <FormalParameterElement>[]) {
      if (param.displayName != field.name) continue;
      DartObject? object = param.computeConstantValue();
      DartType? type = object?.type;
      if (type is InterfaceType && type.element is EnumElement) {
        return object?.variable?.displayName;
      }
      return literal.fromConstant(object);
    }
    return null;
  }
}
