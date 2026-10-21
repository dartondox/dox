import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';

import '../openapi/annotation_reader.dart';
import '../openapi/ast_finders.dart';
import 'dto_schema.dart';
import 'model_schema.dart';

/// Gives the resolved AST of an element, for example a method body.
class AstLoader {
  const AstLoader(this.resolver);

  final Resolver resolver;

  /// The AST node of [element], or null when it has none.
  Future<AstNode?> of(Element element) async {
    try {
      return await resolver.astNodeFor(element.firstFragment, resolve: true);
    } catch (_) {
      return null;
    }
  }
}

/// Turns Dart types into JSON Schema.
///
/// Models (`@DoxModel`), DTOs (`@Dto`) and `Pagination` go to
/// [components] once, and a `$ref` to them is returned.
class JsonSchemaReader {
  JsonSchemaReader(
    this.ast, {
    this.annotations = const AnnotationReader(),
    this.dto = const DtoSchema(),
    this.model = const ModelSchema(),
  });

  final AstLoader ast;
  final AnnotationReader annotations;
  final DtoSchema dto;
  final ModelSchema model;

  /// Named schemas for `components/schemas`, by class name.
  final Map<String, Map<String, dynamic>> components =
      <String, Map<String, dynamic>>{};

  static const String refPrefix = '#/components/schemas/';

  static const Map<String, dynamic> _pagination = <String, dynamic>{
    'type': 'object',
    'properties': <String, dynamic>{
      'total': <String, dynamic>{'type': 'integer'},
      'per_page': <String, dynamic>{'type': 'integer'},
      'last_page': <String, dynamic>{'type': 'integer'},
      'current_page': <String, dynamic>{'type': 'integer'},
      'data': <String, dynamic>{'type': 'array', 'items': <String, dynamic>{}},
    },
  };

  /// The schema of [type], or null when it says nothing useful
  /// (`dynamic`, `Object`, `DoxResponse`, ...).
  /// `Future<T>` gives the schema of `T`. When [nullable] is true,
  /// `T?` allows `null` too.
  Future<Map<String, dynamic>?> of(
    DartType type, {
    bool nullable = true,
  }) async {
    if (type is! InterfaceType) return null;
    if (type.isDartAsyncFuture || type.isDartAsyncFutureOr) {
      return of(type.typeArguments.first, nullable: nullable);
    }
    Map<String, dynamic>? schema = await _interface(type);
    if (schema == null) return null;
    bool isNullable = type.nullabilitySuffix == NullabilitySuffix.question;
    return nullable && isNullable ? orNull(schema) : schema;
  }

  /// [schema] that also allows `null`.
  Map<String, dynamic> orNull(Map<String, dynamic> schema) {
    Object? type = schema['type'];
    if (type is String) {
      return <String, dynamic>{
        ...schema,
        'type': <String>[type, 'null'],
      };
    }
    return <String, dynamic>{
      'anyOf': <Map<String, dynamic>>[
        schema,
        <String, dynamic>{'type': 'null'},
      ],
    };
  }

  /// A `$ref` to the named schema [name].
  Map<String, dynamic> ref(String name) {
    return <String, dynamic>{r'$ref': '$refPrefix$name'};
  }

  /// The text of a `///` doc comment, or null.
  String? docText(String? comment) {
    if (comment == null) return null;
    List<String> lines = <String>[];
    for (String line in comment.split('\n')) {
      String text = line.trim();
      if (text.startsWith('///')) {
        text = text.substring(3);
      } else {
        text = text.replaceFirst(RegExp(r'^/\*\*?|\*/$|^\*'), '');
      }
      lines.add(text.startsWith(' ') ? text.substring(1) : text);
    }
    String text = lines.join('\n').trim();
    return text.isEmpty ? null : text;
  }

  /// The schema of a map literal, like `{'status': 'ok', 'id': id}`.
  Future<Map<String, dynamic>> mapLiteral(SetOrMapLiteral node) async {
    Map<String, dynamic> properties = <String, dynamic>{};
    for (CollectionElement item in node.elements) {
      if (item is! MapLiteralEntry) continue;
      Expression key = item.key;
      if (key is! SimpleStringLiteral) continue;
      properties[key.value] =
          await expression(item.value) ?? <String, dynamic>{};
    }
    return <String, dynamic>{'type': 'object', 'properties': properties};
  }

  /// The schema of the value of [node]: a map literal by its keys,
  /// else by its static type.
  Future<Map<String, dynamic>?> expression(
    Expression node, {
    bool nullable = true,
  }) async {
    Expression value = node.unParenthesized;
    if (value is AwaitExpression) value = value.expression.unParenthesized;
    if (value is SetOrMapLiteral && value.isMap) return mapLiteral(value);
    DartType? type = value.staticType;
    return type == null ? null : of(type, nullable: nullable);
  }

  Future<Map<String, dynamic>?> _interface(InterfaceType type) async {
    InterfaceElement element = type.element;
    String name = element.displayName;
    if (type.isDartCoreString) return <String, dynamic>{'type': 'string'};
    if (type.isDartCoreInt) return <String, dynamic>{'type': 'integer'};
    if (type.isDartCoreDouble || type.isDartCoreNum) {
      return <String, dynamic>{'type': 'number'};
    }
    if (type.isDartCoreBool) return <String, dynamic>{'type': 'boolean'};
    if (element.library.isDartCore && name == 'DateTime') {
      return <String, dynamic>{'type': 'string', 'format': 'date-time'};
    }
    if (element.library.isDartCore && name == 'Uri') {
      return <String, dynamic>{'type': 'string', 'format': 'uri'};
    }
    if (type.isDartCoreList || type.isDartCoreSet || type.isDartCoreIterable) {
      Map<String, dynamic>? items = await of(type.typeArguments.first);
      return <String, dynamic>{
        'type': 'array',
        'items': items ?? <String, dynamic>{},
      };
    }
    if (type.isDartCoreMap) {
      Map<String, dynamic>? values = await of(type.typeArguments.last);
      return <String, dynamic>{
        'type': 'object',
        'additionalProperties': ?values,
      };
    }
    if (element is EnumElement) {
      List<String> names = <String>[];
      for (FieldElement value in element.constants) {
        names.add(value.displayName);
      }
      return <String, dynamic>{'type': 'string', 'enum': names};
    }
    if (element is! ClassElement) return null;
    if (dto.isDto(element)) {
      return _component(name, element, _dtoKind);
    }
    if (model.isModel(element)) {
      return _component(name, element, _modelKind);
    }
    if (name == 'Pagination') {
      components[name] = _pagination;
      return ref(name);
    }
    InterfaceType? serializer = _supertype(type, 'Serializer');
    if (serializer != null && serializer.typeArguments.isNotEmpty) {
      return _serializer(element, serializer.typeArguments.first);
    }
    return null;
  }

  static const int _dtoKind = 0;
  static const int _modelKind = 1;

  /// adds the schema of [element] once, and returns a `$ref` to it.
  /// a placeholder is set first, so classes that point to each other
  /// do not loop.
  Future<Map<String, dynamic>> _component(
    String name,
    ClassElement element,
    int kind,
  ) async {
    if (!components.containsKey(name)) {
      components[name] = <String, dynamic>{};
      components[name] = kind == _dtoKind
          ? await dto.of(element, this)
          : await model.of(element, this);
    }
    return ref(name);
  }

  /// a serializer gives what its `convert()` returns: a map literal by
  /// its keys, else the schema of the model [data].
  Future<Map<String, dynamic>?> _serializer(
    ClassElement element,
    DartType data,
  ) async {
    for (MethodElement method in element.methods) {
      if (method.displayName != 'convert') continue;
      AstNode? node = await ast.of(method);
      FunctionBody? body = node is MethodDeclaration ? node.body : null;
      for (Expression value in ReturnCollector.of(body)) {
        Expression plain = value.unParenthesized;
        if (plain is SetOrMapLiteral && plain.isMap) return mapLiteral(plain);
      }
    }
    return of(data, nullable: false);
  }

  InterfaceType? _supertype(InterfaceType type, String name) {
    if (type.element.displayName == name) return type;
    for (InterfaceType parent in type.allSupertypes) {
      if (parent.element.displayName == name) return parent;
    }
    return null;
  }
}
