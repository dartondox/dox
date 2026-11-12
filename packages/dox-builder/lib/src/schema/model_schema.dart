import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../openapi/annotation_reader.dart';
import '../openapi/ast_finders.dart';
import '../util.dart';
import 'json_schema_reader.dart';

/// The JSON Schema of a `@DoxModel` class: what `toJson()` gives.
///
/// It has the primary key, the `@Column` fields, the timestamps, the
/// relations (only there when loaded) and the `@Computed` getters.
/// Keys in the `hidden` list are left out. With a `visibleFields`
/// list, only its keys are kept.
class ModelSchema {
  const ModelSchema({this.annotations = const AnnotationReader()});

  final AnnotationReader annotations;

  static const List<String> _relations = <String>[
    'HasOne',
    'HasMany',
    'BelongsTo',
    'ManyToMany',
    'HasOneThrough',
    'HasManyThrough',
    'MorphOne',
    'MorphMany',
    'MorphTo',
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
    DartType? primaryKeyType = options
        ?.getField('primaryKeyType')
        ?.toTypeValue();
    Map<String, dynamic> properties = <String, dynamic>{
      primaryKey: primaryKeyType == null
          ? <String, dynamic>{'type': 'integer'}
          : await types.of(primaryKeyType) ??
                <String, dynamic>{'type': 'integer'},
    };
    for (FieldElement field in model.fields) {
      if (field.isStatic || !field.isOriginDeclaration) continue;
      DartObject? column = annotations.first(field, 'Column');
      bool relation = _isRelation(field);
      if (column == null && !relation) continue;
      // a name given in the code is used as it is, like the model builder
      String key = relation
          ? toSnakeCase(field.displayName)
          : column?.getField('name')?.toStringValue() ??
                toSnakeCase(field.displayName);
      properties[key] = await types.of(field.type) ?? <String, dynamic>{};
    }
    bool timestamps = options?.getField('timestamps')?.toBoolValue() ?? true;
    for (String name in <String>['createdAt', 'updatedAt']) {
      String? key = timestamps
          ? options?.getField(name)?.toStringValue()
          : null;
      if (key != null) properties[key] = _timestamp;
    }
    for (GetterElement getter in model.getters) {
      DartObject? computed = annotations.first(getter, 'Computed');
      if (getter.isStatic || computed == null) continue;
      String key =
          computed.getField('name')?.toStringValue() ??
          toSnakeCase(getter.displayName);
      properties[key] =
          await types.of(getter.returnType) ?? <String, dynamic>{};
    }

    /// `visibleFields` of dox_orm keeps only its keys in toJson()
    List<String> only = await _strings(model, types, 'visibleFields');
    if (only.isNotEmpty) {
      for (String key in properties.keys.toList()) {
        if (!only.contains(key)) properties.remove(key);
      }
    }
    for (String hidden in await _strings(model, types, 'hidden')) {
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

  /// the strings of the [name] getter or field of the model, like
  /// `hidden`
  Future<List<String>> _strings(
    ClassElement model,
    JsonSchemaReader types,
    String name,
  ) async {
    for (GetterElement getter in model.getters) {
      if (getter.displayName != name || getter.isStatic) continue;
      Element source = getter.isOriginDeclaration ? getter : getter.variable;
      return StringListCollector.of(await types.ast.of(source));
    }
    return const <String>[];
  }
}
