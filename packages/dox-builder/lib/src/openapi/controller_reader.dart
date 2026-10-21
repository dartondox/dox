import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../schema/json_schema_reader.dart';
import 'annotation_reader.dart';
import 'ast_finders.dart';
import 'request_reader.dart';

/// One response of an operation.
class ResponseData {
  const ResponseData(this.description, this.schema);

  final String description;
  final Map<String, dynamic>? schema;
}

/// The docs of one controller method, ready to be written as code.
class OperationData {
  OperationData(this.controller, this.method);

  final String controller;
  final String method;
  List<String> argumentTypes = <String>[];
  String? summary;
  String? description;
  List<String> tags = <String>[];
  bool deprecated = false;

  /// `@ApiIgnore()`: only the names are written, so the route is left out
  bool ignore = false;
  List<Map<String, dynamic>> params = <Map<String, dynamic>>[];
  RequestData? request;
  Map<int, ResponseData> responses = <int, ResponseData>{};

  String get id => '$controller.$method';
}

/// Reads the docs of each public method of a controller class:
/// the doc comment, the arguments, the request and the return type.
/// Annotations like `@Summary` and `@Response` change the result.
class ControllerReader {
  ControllerReader(
    this.types, {
    this.annotations = const AnnotationReader(),
    RequestReader? requests,
  }) : requests = requests ?? RequestReader(types);

  final JsonSchemaReader types;
  final AnnotationReader annotations;
  final RequestReader requests;

  static const String _ok = 'Successful response';

  /// The docs of all public methods of [controller]. With
  /// `@ApiIgnore()` on the class or method, the method is marked
  /// `ignore`, so its routes are left out.
  Future<List<OperationData>> read(ClassElement controller) async {
    List<OperationData> list = <OperationData>[];
    bool ignoreAll = annotations.has(controller, 'ApiIgnore');
    for (MethodElement method in controller.methods) {
      if (_skip(method)) continue;
      if (ignoreAll || annotations.has(method, 'ApiIgnore')) {
        list.add(
          OperationData(controller.displayName, method.displayName)
            ..argumentTypes = _argumentTypes(method)
            ..ignore = true,
        );
      } else {
        list.add(await _operation(controller, method));
      }
    }
    return list;
  }

  bool _skip(MethodElement method) {
    return method.isStatic ||
        method.isPrivate ||
        method.isOperator ||
        method.formalParameters.isEmpty;
  }

  Future<OperationData> _operation(
    ClassElement controller,
    MethodElement method,
  ) async {
    OperationData op = OperationData(
      controller.displayName,
      method.displayName,
    );
    AstNode? node = await types.ast.of(method);
    FunctionBody? body = node is MethodDeclaration ? node.body : null;
    op.argumentTypes = _argumentTypes(method);
    _texts(op, method);
    op.tags = _tags(controller, method);
    op.deprecated =
        method.metadata.hasDeprecated ||
        annotations.has(method, 'ApiDeprecated') ||
        annotations.has(controller, 'ApiDeprecated');
    op.params = await _params(method);
    op.request = await requests.read(method, body);
    op.responses = await _responses(method, body);
    return op;
  }

  List<String> _argumentTypes(MethodElement method) {
    return <String>[
      for (FormalParameterElement param in method.formalParameters)
        param.type.getDisplayString(),
    ];
  }

  /// summary: the first line of the doc comment, description: the rest.
  void _texts(OperationData op, MethodElement method) {
    String? doc = types.docText(method.documentationComment);
    if (doc != null) {
      int end = doc.indexOf('\n');
      op.summary = end < 0 ? doc : doc.substring(0, end).trim();
      String rest = end < 0 ? '' : doc.substring(end + 1).trim();
      op.description = rest.isEmpty ? null : rest;
    }
    op.summary = _text(method, 'Summary') ?? op.summary;
    op.description = _text(method, 'Description') ?? op.description;
  }

  String? _text(Element element, String annotation) {
    return annotations
        .first(element, annotation)
        ?.getField('text')
        ?.toStringValue();
  }

  List<String> _tags(ClassElement controller, MethodElement method) {
    List<String>? tags = _tagList(method) ?? _tagList(controller);
    if (tags != null) return tags;
    String? tag = annotations
        .first(controller, 'DoxController')
        ?.getField('tag')
        ?.toStringValue();
    if (tag != null) return <String>[tag];
    String name = controller.displayName;
    String short = name.endsWith('Controller')
        ? name.substring(0, name.length - 'Controller'.length)
        : name;
    return <String>[short.isEmpty ? name : short];
  }

  List<String>? _tagList(Element element) {
    List<DartObject>? names = annotations
        .first(element, 'Tags')
        ?.getField('names')
        ?.toListValue();
    if (names == null) return null;
    return <String>[for (DartObject name in names) ?name.toStringValue()];
  }

  /// schemas of the path params: the arguments after the first one,
  /// except a `@Dto` argument.
  Future<List<Map<String, dynamic>>> _params(MethodElement method) async {
    List<Map<String, dynamic>> params = <Map<String, dynamic>>[];
    List<FormalParameterElement> args = method.formalParameters;
    for (int i = 1; i < args.length; i++) {
      if (!args[i].isPositional || requests.isDto(args[i].type)) continue;
      params.add(
        await types.of(args[i].type, nullable: false) ??
            <String, dynamic>{'type': 'string'},
      );
    }
    return params;
  }

  /// `@Response` annotations, else the return type, else the types of
  /// the `return` values when the return type is `dynamic`.
  Future<Map<int, ResponseData>> _responses(
    MethodElement method,
    FunctionBody? body,
  ) async {
    Map<int, ResponseData> responses = <int, ResponseData>{};
    bool success = false;
    for (DartObject annotation in annotations.all(method, 'Response')) {
      int? status = annotation.getField('status')?.toIntValue();
      if (status == null) continue;
      DartType? type = annotation.getField('type')?.toTypeValue();
      String? text = annotation.getField('description')?.toStringValue();
      success = success || (status >= 200 && status < 300);
      responses[status] = ResponseData(
        text ?? (status < 300 ? _ok : 'Response'),
        type == null ? null : await types.of(type, nullable: false),
      );
    }
    if (!success) {
      responses[200] = ResponseData(_ok, await _returnSchema(method, body));
    }
    return responses;
  }

  Future<Map<String, dynamic>?> _returnSchema(
    MethodElement method,
    FunctionBody? body,
  ) async {
    DartType type = method.returnType;
    Map<String, dynamic>? schema = await types.of(type, nullable: false);
    if (schema != null || !_isDynamic(type)) return schema;
    return _returnValues(body);
  }

  /// `dynamic`, `Object`, `Future<dynamic>` and the like
  bool _isDynamic(DartType type) {
    if (type is InterfaceType &&
        (type.isDartAsyncFuture || type.isDartAsyncFutureOr)) {
      return _isDynamic(type.typeArguments.first);
    }
    return type is DynamicType || type.isDartCoreObject;
  }

  /// the schema of the `return` values. errors (exceptions) are left
  /// out. null when one value is unknown.
  Future<Map<String, dynamic>?> _returnValues(FunctionBody? body) async {
    Map<String, Map<String, dynamic>> found = <String, Map<String, dynamic>>{};
    for (Expression value in ReturnCollector.of(body)) {
      if (_isError(value.staticType)) continue;
      Map<String, dynamic>? schema = await types.expression(
        value,
        nullable: false,
      );
      if (schema == null) return null;
      found['$schema'] = schema;
    }
    if (found.isEmpty) return null;
    if (found.length == 1) return found.values.first;
    return <String, dynamic>{'anyOf': found.values.toList()};
  }

  bool _isError(DartType? type) {
    if (type is! InterfaceType) return false;
    for (InterfaceType parent in <InterfaceType>[type, ...type.allSupertypes]) {
      String name = parent.element.displayName;
      if (name == 'Exception' || name == 'Error' || name == 'IHttpException') {
        return true;
      }
    }
    return false;
  }
}
