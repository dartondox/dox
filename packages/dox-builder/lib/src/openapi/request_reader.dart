import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../schema/json_schema_reader.dart';
import 'annotation_reader.dart';
import 'ast_finders.dart';

/// The request of one controller method.
class RequestData {
  const RequestData({this.schema, this.formRequest, this.where});

  /// JSON Schema, often a `$ref` to a `@Dto` class.
  final Map<String, dynamic>? schema;

  /// Class name of a form request. dox_core finds it in the IoC.
  final String? formRequest;

  /// `body`, `query`, or null to choose by the HTTP method.
  final String? where;
}

/// Finds the request class of a controller method.
///
/// This is the one place that decides it. In this order:
/// 1. `@Body(T)`, `@Query(T)` or `@Request(T)` on the method.
/// 2. An argument whose type is a `@Dto` class: `store(CreateUser body)`.
/// 3. A `req.validate<T>()` call in the method body, with a `@Dto` `T`.
/// 4. A first argument that is a `FormRequest`: `store(BlogRequest req)`.
class RequestReader {
  RequestReader(this.types, {this.annotations = const AnnotationReader()});

  final JsonSchemaReader types;
  final AnnotationReader annotations;

  static const Map<String, String?> _annotations = <String, String?>{
    'Body': 'body',
    'Query': 'query',
    'Request': null,
  };

  /// True when [type] is a `@Dto` class.
  bool isDto(DartType type) {
    return type is InterfaceType && types.dto.isDto(type.element);
  }

  /// The request of [method], or null when it has none.
  Future<RequestData?> read(MethodElement method, FunctionBody? body) async {
    for (MapEntry<String, String?> entry in _annotations.entries) {
      DartObject? annotation = annotations.first(method, entry.key);
      DartType? type = annotation?.getField('type')?.toTypeValue();
      if (type != null) return _of(type, entry.value);
    }
    for (FormalParameterElement param in method.formalParameters) {
      if (isDto(param.type)) return _of(param.type, null);
    }
    for (MethodInvocation call in CallCollector.of(body, <String>{
      'validate',
    })) {
      List<TypeAnnotation>? args = call.typeArguments?.arguments;
      DartType? type = args == null || args.isEmpty ? null : args.first.type;
      if (type != null && isDto(type)) return _of(type, null);
    }
    List<FormalParameterElement> params = method.formalParameters;
    if (params.isNotEmpty && _isFormRequest(params.first.type)) {
      return _of(params.first.type, null);
    }
    return null;
  }

  Future<RequestData?> _of(DartType type, String? where) async {
    if (_isFormRequest(type)) {
      return RequestData(
        formRequest: (type as InterfaceType).element.displayName,
        where: where,
      );
    }
    Map<String, dynamic>? schema = await types.of(type, nullable: false);
    return schema == null ? null : RequestData(schema: schema, where: where);
  }

  bool _isFormRequest(DartType type) {
    if (type is! InterfaceType) return false;
    for (InterfaceType parent in type.allSupertypes) {
      if (parent.element.displayName == 'FormRequest') return true;
    }
    return false;
  }
}
