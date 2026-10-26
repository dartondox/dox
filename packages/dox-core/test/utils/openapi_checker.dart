// A copy of test/support/openapi_checker.dart in dartondox/dox-openapi.
// ponytail: copied, not shared. Move it to a dox_openapi testing library if
// the two copies start to differ.
import 'package:dox_openapi/dox_openapi.dart';

/// Structural checks for an OpenAPI 3.1 document.
/// Returns a list of problems. An empty list means the document is valid.
class OpenApiChecker {
  final List<String> _errors = <String>[];
  late Map<String, dynamic> _doc;

  /// Checks [doc] and returns the problems found.
  List<String> check(Map<String, dynamic> doc) {
    _errors.clear();
    _doc = doc;
    Object? version = doc['openapi'];
    if (version is! String || !version.startsWith('3.1.')) {
      _errors.add('openapi must be a 3.1.x string');
    }
    _checkInfo(doc['info']);
    _checkPaths(doc['paths']);
    _checkRefs(doc, '#');
    _checkSecurityNames(doc);
    return List<String>.of(_errors);
  }

  void _checkInfo(Object? info) {
    if (info is! Map) {
      _errors.add('info is required');
      return;
    }
    for (String key in <String>['title', 'version']) {
      if (info[key] is! String) {
        _errors.add('info.$key must be a string');
      }
    }
  }

  void _checkPaths(Object? paths) {
    if (paths is! Map) {
      _errors.add('paths must be an object');
      return;
    }
    Set<String> operationIds = <String>{};
    for (MapEntry<dynamic, dynamic> pathEntry in paths.entries) {
      String path = '${pathEntry.key}';
      if (!path.startsWith('/')) {
        _errors.add('path $path must start with /');
      }
      Map<dynamic, dynamic> item = pathEntry.value as Map<dynamic, dynamic>;
      for (MapEntry<dynamic, dynamic> opEntry in item.entries) {
        String method = '${opEntry.key}';
        if (!OpenApiConstants.methods.contains(method)) {
          _errors.add('$path has bad method $method');
          continue;
        }
        Map<dynamic, dynamic> op = opEntry.value as Map<dynamic, dynamic>;
        String where = '$method $path';
        Object? id = op['operationId'];
        if (id is String && !operationIds.add(id)) {
          _errors.add('$where: duplicate operationId $id');
        }
        _checkResponses(where, op['responses']);
        _checkParams(where, path, op['parameters']);
      }
    }
  }

  void _checkResponses(String where, Object? responses) {
    if (responses is! Map || responses.isEmpty) {
      _errors.add('$where: responses must not be empty');
      return;
    }
    for (MapEntry<dynamic, dynamic> entry in responses.entries) {
      String code = '${entry.key}';
      if (code != 'default' &&
          !RegExp(r'^[1-5]([0-9]{2}|XX)$').hasMatch(code)) {
        _errors.add('$where: bad status code $code');
      }
      Object? response = entry.value;
      if (response is! Map || response['description'] is! String) {
        _errors.add('$where: response $code needs a description');
      }
    }
  }

  void _checkParams(String where, String path, Object? parameters) {
    List<String> template = PathConverter.paramNames(path);
    Set<String> declared = <String>{};
    Set<String> seen = <String>{};
    for (Object? param in parameters is List ? parameters : <Object?>[]) {
      if (param is! Map || param['name'] is! String || param['in'] is! String) {
        _errors.add('$where: parameter needs name and in');
        continue;
      }
      String location = param['in'] as String;
      if (!<String>['path', 'query', 'header', 'cookie'].contains(location)) {
        _errors.add('$where: bad parameter location $location');
      }
      if (!seen.add('${param['name']}|$location')) {
        _errors.add('$where: duplicate parameter ${param['name']}');
      }
      if (param['schema'] == null && param['content'] == null) {
        _errors.add('$where: parameter ${param['name']} needs a schema');
      }
      if (location == 'path') {
        declared.add(param['name'] as String);
        if (param['required'] != true) {
          _errors.add(
            '$where: path parameter ${param['name']} must be required',
          );
        }
      }
    }
    for (String name in template) {
      if (!declared.contains(name)) {
        _errors.add('$where: path parameter $name is not declared');
      }
    }
    for (String name in declared) {
      if (!template.contains(name)) {
        _errors.add('$where: path parameter $name is not in the path');
      }
    }
  }

  void _checkRefs(Object? node, String where) {
    if (node is Map) {
      Object? ref = node[r'$ref'];
      if (ref is String && _resolve(ref) == null) {
        _errors.add('$where: cannot resolve $ref');
      }
      for (MapEntry<dynamic, dynamic> entry in node.entries) {
        _checkRefs(entry.value, '$where/${entry.key}');
      }
    } else if (node is List) {
      for (int i = 0; i < node.length; i++) {
        _checkRefs(node[i], '$where/$i');
      }
    }
  }

  Object? _resolve(String ref) {
    if (!ref.startsWith('#/')) {
      return null;
    }
    Object? current = _doc;
    for (String part in ref.substring(2).split('/')) {
      String key = part.replaceAll('~1', '/').replaceAll('~0', '~');
      if (current is! Map || !current.containsKey(key)) {
        return null;
      }
      current = current[key];
    }
    return current;
  }

  void _checkSecurityNames(Map<String, dynamic> doc) {
    Object? components = doc['components'];
    Object? schemes = components is Map ? components['securitySchemes'] : null;
    Set<Object?> known = schemes is Map ? schemes.keys.toSet() : <Object?>{};
    List<Object?> requirements = <Object?>[];
    if (doc['security'] is List) {
      requirements.addAll(doc['security'] as List<Object?>);
    }
    Object? paths = doc['paths'];
    if (paths is Map) {
      for (Object? item in paths.values) {
        for (Object? op in (item as Map<dynamic, dynamic>).values) {
          Object? security = (op as Map<dynamic, dynamic>)['security'];
          if (security is List) {
            requirements.addAll(security);
          }
        }
      }
    }
    for (Object? requirement in requirements) {
      for (Object? name in (requirement as Map<dynamic, dynamic>).keys) {
        if (!known.contains(name)) {
          _errors.add('security scheme $name is not defined');
        }
      }
    }
  }
}
