import 'controller_reader.dart';
import 'dart_literal.dart';
import 'request_reader.dart';
import 'route_scanner.dart';
import 'security_data.dart';

/// Writes the Dart code of `lib/generated/openapi.g.dart`: one const
/// `openApiRegistry` with the operations, route calls and schemas.
class RegistryWriter {
  const RegistryWriter({this.literal = const DartLiteral()});

  final DartLiteral literal;

  /// The file content (not formatted yet).
  String write(
    List<OperationData> operations,
    List<RouteCall> calls,
    Map<String, Map<String, dynamic>> schemas, [
    Map<String, SecurityData> security = const <String, SecurityData>{},
  ]) {
    Set<String> ids = <String>{for (OperationData op in operations) op.id};
    StringBuffer out = StringBuffer()
      ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND')
      ..writeln('// Made by dox_builder. Run `dart run build_runner build`.')
      ..writeln('// ignore_for_file: type=lint')
      ..writeln()
      ..writeln("import 'package:dox_core/dox_core.dart';")
      ..writeln()
      ..writeln('/// OpenAPI docs found in the code.')
      ..writeln('/// Use it in `OpenApiConfig(registry: openApiRegistry)`.')
      ..writeln('const OpenApiRegistry openApiRegistry = OpenApiRegistry(')
      ..writeln('operations: <OpenApiOperation>[');
    for (OperationData op in operations) {
      out.writeln('${_operation(op)},');
    }
    out.writeln('],');
    out.writeln('routes: <OpenApiRouteBinding>[');
    for (RouteCall call in calls) {
      String id = '${call.controller.displayName}.${call.action}';
      if (!ids.contains(id)) continue;
      String path = call.path == null ? 'null' : literal.string(call.path!);
      out.writeln(
        'OpenApiRouteBinding(${literal.string(call.method)}, $path, '
        '${literal.string(id)}),',
      );
    }
    out.writeln('],');
    out.writeln('schemas: <String, Map<String, dynamic>>{');
    for (MapEntry<String, Map<String, dynamic>> entry in schemas.entries) {
      out.writeln(
        '${literal.string(entry.key)}: ${literal.write(entry.value)},',
      );
    }
    out.writeln('},');
    if (security.isNotEmpty) {
      out.writeln('security: <String, OpenApiSecurity>{');
      for (MapEntry<String, SecurityData> entry in security.entries) {
        out.writeln(
          '${literal.string(entry.key)}: OpenApiSecurity('
          '${literal.string(entry.value.name)}, '
          '${literal.write(entry.value.scheme)}),',
        );
      }
      out.writeln('},');
    }
    out.writeln(');');
    return out.toString();
  }

  String _operation(OperationData op) {
    StringBuffer out = StringBuffer('OpenApiOperation(')
      ..write('controller: ${literal.string(op.controller)}, ')
      ..write('method: ${literal.string(op.method)}, ')
      ..write('argumentTypes: ${literal.strings(op.argumentTypes)}, ');
    if (op.ignore) return '$out ignore: true)';
    _named(out, 'summary', op.summary);
    _named(out, 'description', op.description);
    out.write('tags: ${literal.strings(op.tags)}, ');
    if (op.deprecated) out.write('deprecated: true, ');
    if (op.params.isNotEmpty) {
      out.write('params: <Map<String, dynamic>>[');
      for (Map<String, dynamic> param in op.params) {
        out.write('${literal.write(param)}, ');
      }
      out.write('], ');
    }
    RequestData? request = op.request;
    if (request != null) {
      if (request.schema != null) {
        out.write('schema: ${literal.write(request.schema)}, ');
      }
      _named(out, 'requestIn', request.where);
    }
    out.write('responses: <int, ResponseDoc>{');
    for (MapEntry<int, ResponseData> entry in op.responses.entries) {
      out.write('${entry.key}: ResponseDoc(');
      out.write('description: ${literal.string(entry.value.description)}');
      if (entry.value.schema != null) {
        out.write(', schema: ${literal.write(entry.value.schema)}');
      }
      out.write('), ');
    }
    out.write('}, ');
    out.write(')');
    return out.toString();
  }

  void _named(StringBuffer out, String name, String? value) {
    if (value != null) out.write('$name: ${literal.string(value)}, ');
  }
}
