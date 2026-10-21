import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';

import '../openapi/annotation_reader.dart';
import '../openapi/ast_finders.dart';
import '../util.dart';
import 'json_schema_reader.dart';

/// The JSON Schema of a `@DoxModel` class: what `toJson()` gives.
///
/// It has the primary key, the `@Column` fields, the timestamps, the
/// relations (only there when loaded) and the `@Computed` getters.
/// Keys in the `hidden` list are left out.
class ModelSchema {
  const ModelSchema({this.annotations = const AnnotationReader()});

  final AnnotationReader annotations;

  static const List<String> _relations = <String>[
    'HasOne',
    'HasMany',
    'BelongsTo',
    'ManyToMany',
  ];

  static const Map<String, dynamic> _timestamp = <String, dynamic>{
    'type': <String>['string', 'null'],
    'format': 'date-time',
  };

  /// True when [element] has `@DoxModel()`.
  bool isModel(Element element) {
    return annotations.has(element, 'DoxModel');
  }

  /// The object schema of [model].
  Future<Map<String, dynamic>> of(
    ClassElement model,
    JsonSchemaReader types,
  ) async {
    DartObject? options = annotations.first(model, 'DoxModel');
    String primaryKey =
        options?.getField('primaryKey')?.toStringValue() ?? 'id';
    Map<String, dynamic> properties = <String, dynamic>{
      primaryKey: <String, dynamic>{'type': 'integer'},
    };
    for (FieldElement field in model.fields) {
      if (field.isStatic || !field.isOriginDeclaration) continue;
      DartObject? column = annotations.first(field, 'Column');
      bool relation = _isRelation(field);
      if (column == null && !relation) continue;
      String key = relation
          ? toSnakeCase(field.displayName)
          : toSnakeCase(
              column?.getField('name')?.toStringValue() ?? field.displayName,
            );
      properties[key] = await types.of(field.type) ?? <String, dynamic>{};
    }
    for (String name in <String>['createdAt', 'updatedAt']) {
      String? key = options?.getField(name)?.toStringValue();
      if (key != null) properties[toSnakeCase(key)] = _timestamp;
    }
    for (GetterElement getter in model.getters) {
      DartObject? computed = annotations.first(getter, 'Computed');
      if (getter.isStatic || computed == null) continue;
      String key = toSnakeCase(
        computed.getField('name')?.toStringValue() ?? getter.displayName,
      );
      properties[key] =
          await types.of(getter.returnType) ?? <String, dynamic>{};
    }
    for (String hidden in await _hidden(model, types)) {
      properties.remove(hidden);
    }
    String? doc = types.docText(model.documentationComment);
    return <String, dynamic>{
      'type': 'object',
      'description': ?doc,
      'properties': properties,
    };
  }

  bool _isRelation(FieldElement field) {
    for (String name in _relations) {
      if (annotations.has(field, name)) return true;
    }
    return false;
  }

  /// the strings of the `hidden` getter or field of the model
  Future<List<String>> _hidden(
    ClassElement model,
    JsonSchemaReader types,
  ) async {
    for (GetterElement getter in model.getters) {
      if (getter.displayName != 'hidden' || getter.isStatic) continue;
      Element source = getter.isOriginDeclaration ? getter : getter.variable;
      return StringListCollector.of(await types.ast.of(source));
    }
    return const <String>[];
  }
}
