import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:dox_annotation/dox_annotation.dart';
import 'package:dox_builder/src/model_visitor.dart';
import 'package:dox_builder/src/util.dart';
import 'package:source_gen/source_gen.dart';

class DoxModelBuilder extends GeneratorForAnnotation<DoxModel> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    String? tableName = annotation.objectValue
        .getField('table')
        ?.toStringValue();
    String primaryKeySnakeCase =
        annotation.objectValue.getField('primaryKey')?.toStringValue() ?? 'id';
    String primaryKey = toCamelCase(primaryKeySnakeCase);
    String primaryKeyType =
        annotation.objectValue
            .getField('primaryKeyType')
            ?.toTypeValue()
            ?.getDisplayString()
            .replaceFirst('?', '') ??
        'int';
    String? createdAt = annotation.objectValue
        .getField('createdAt')
        ?.toStringValue();
    String? updatedAt = annotation.objectValue
        .getField('updatedAt')
        ?.toStringValue();
    bool softDelete =
        annotation.objectValue.getField('softDelete')?.toBoolValue() ?? false;
    if (annotation.objectValue.getField('timestamps')?.toBoolValue() == false) {
      createdAt = null;
      updatedAt = null;
    }

    final visitor = ModelVisitor();

    visitor.columns.addAll({
      primaryKey: {
        'type': '$primaryKeyType?',
        'jsonKey': primaryKeySnakeCase,
        'beforeSave': null,
        'beforeGet': null,
      },
    });

    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@DoxModel can only be used on a class.',
        element: element,
      );
    }
    visitor.visitClass(element);

    if (createdAt != null) {
      visitor.columns.addAll({
        'createdAt': {
          'type': 'DateTime?',
          'jsonKey': createdAt,
          'beforeSave': null,
          'beforeGet': null,
        },
      });
    }
    if (updatedAt != null) {
      visitor.columns.addAll({
        'updatedAt': {
          'type': 'DateTime?',
          'jsonKey': updatedAt,
          'beforeSave': null,
          'beforeGet': null,
        },
      });
    }
    String className = visitor.className;
    String createdColumn = createdAt != null ? "'$createdAt'" : 'null';
    String updatedColumn = updatedAt != null ? "'$updatedAt'" : 'null';

    var r = _getRelationsCode(visitor);
    var map = _getCodeForToMap(visitor);

    String computedCode = _getCodeForComputedAndHooks(visitor);

    String softDeleteString = softDelete ? 'with SoftDeletes<$className>' : '';

    return """
    // ignore_for_file: always_specify_types

    class ${className}Generator extends Model<$className> $softDeleteString {
      @override
      String get primaryKey => '$primaryKeySnakeCase';

      @override
      Map<String, dynamic> get timestampsColumn => const <String, dynamic>{
        'created_at': $createdColumn,
        'updated_at': $updatedColumn,
      };

      ${_getTableNameSetter(tableName)}

      ${_primaryKeySetterAndGetter(primaryKey, primaryKeyType)}

      $className query() => $className();

      ${visitor.columns.values.any((c) => c['beforeGet'] != null) ? '' : '''
      @override
      bool get readsRowDates => true;
      '''}

      @override
      List<String> get tableColumns => const <String>[${map['tableColumns'].join(',')}];

      @override
      List<String> get preloadList => const <String>[
        ${r['eagerLoad']}
      ];

      @override
      Map<String, Function> get relationsResultMatcher => const <String, Function>{
          ${r['mapResultContent']}
      };

      @override
      Map<String, Function> get relationsQueryMatcher => const <String, Function>{
          ${r['mapQueryContent']}
      };

      ${r['content']}

      @override
      $className fromMap(Map<String, dynamic> m) => $className()
        ${_getCodeForFromMap(visitor)}
      @override
      Map<String, dynamic> columnsToMap() {
        $className instance = this as $className;
        Map<String, dynamic> map = <String, dynamic>{
          ${map['jsonMapper']}
        };
        ${map['parseContent']}
        return map;
      }

      @override
      Map<String, dynamic> convertToMap(dynamic i) {
        $className instance = i as $className;
        Map<String, dynamic> map = instance.columnsToMap();
        ${map['relationContent']}
        return map;
      }
      $computedCode
    }
    """;
  }

  /// only models with @Computed getters get setComputedValues(), and only
  /// models with hooks get hasModelHooks. Other models do no extra work.
  String _getCodeForComputedAndHooks(ModelVisitor visitor) {
    String hooks = visitor.hasHooks
        ? '''
      @override
      bool get hasModelHooks => true;
    '''
        : '';
    if (visitor.computed.isEmpty) return hooks;
    String className = visitor.className;
    String content = '';
    visitor.computed.forEach((getter, jsonKey) {
      content += "map['${toSnakeCase(jsonKey)}'] = instance.$getter;\n";
    });
    return """
      $hooks
      @override
      void setComputedValues(Map<String, dynamic> map) {
        $className instance = this as $className;
        $content
      }
    """;
  }

  Map<String, String> _getRelationsCode(ModelVisitor visitor) {
    String content = '';
    String mapResultContent = '';
    String mapQueryContent = '';
    String eagerLoad = '';
    visitor.relations.forEach((key, value) {
      String getFunctionName = 'get${ucFirst(key.toString())}';
      String queryFunctionName = 'query${ucFirst(key.toString())}';

      String onQuery = value['onQuery'] != null
          ? ", onQuery: ${visitor.className}.${value['onQuery']}"
          : '';

      mapResultContent += "'$key': $getFunctionName,";
      mapQueryContent += "'$key': $queryFunctionName,";

      eagerLoad += value['eager'] == true ? "'$key'," : "";

      content +=
          """
      static Future<void> $getFunctionName(List<Model<${visitor.className}>> list) async {
        var result = await get${value['relationType']}<${visitor.className}, ${value['model']}>($queryFunctionName(list), list);
        for (dynamic i in list) {
          if (result[i.tempIdValue.toString()] != null) {
            i.$key = result[i.tempIdValue.toString()]!;
          }
        }
      }

      static ${value['model']}? $queryFunctionName(List<Model<${visitor.className}>> list) {
        return ${lcFirst(value['relationType'])}<${visitor.className}, ${value['model']}>(list, 
          () => ${value['model']}() 
          ${_getParamKeyValue(value, 'foreignKey')}
          ${_getParamKeyValue(value, 'localKey')}
          ${_getParamKeyValue(value, 'relatedKey')}
          ${_getParamKeyValue(value, 'pivotForeignKey')}
          ${_getParamKeyValue(value, 'pivotRelatedForeignKey')}
          ${_getParamKeyValue(value, 'pivotTable')}
          $onQuery,
        );
      }
      """;
    });

    return {
      'mapResultContent': mapResultContent,
      'mapQueryContent': mapQueryContent,
      'content': content,
      'eagerLoad': eagerLoad,
    };
  }

  String _getParamKeyValue(Map<String, dynamic> value, String key) {
    return value[key] != null ? ", $key: '${value[key]}'" : '';
  }

  String _getTableNameSetter(String? tableName) {
    return tableName != null
        ? """
      @override
      String get tableName => '$tableName';
    """
        : '';
  }

  String _primaryKeySetterAndGetter(String primaryKey, String type) {
    return """
      $type? get $primaryKey => tempIdValue as $type?;

      set $primaryKey($type? val) => tempIdValue = val;
    """;
  }

  String _getCodeForFromMap(ModelVisitor visitor) {
    String content = '';
    String className = visitor.className;

    visitor.columns.forEach((filedName, values) {
      String jsonKey = toSnakeCase(values['jsonKey']);
      String? beforeGet = values['beforeGet'];
      String setValue = '';

      if (values['type'] == 'DateTime?') {
        setValue =
            """m['$jsonKey'] is DateTime?
              ? m['$jsonKey'] as DateTime?
              : DateTime.parse(m['$jsonKey'] as String)
          """;
        if (beforeGet != null) {
          setValue = "$className.$beforeGet(m)";
        }
      } else {
        setValue = "m['$jsonKey'] as ${values['type']}";
        if (beforeGet != null) {
          setValue = "$className.$beforeGet(m)";
        }
      }
      content += "..$filedName = $setValue\n";
    });
    return content += ';';
  }

  Map<String, dynamic> _getCodeForToMap(ModelVisitor visitor) {
    String jsonMapper = '';
    String parseContent = '';
    String relationContent = '';
    List<String> tableColumns = [];
    String className = visitor.className;
    visitor.columns.forEach((filedName, values) {
      String? beforeSave = values['beforeSave'];
      String jsonKey = toSnakeCase(values['jsonKey']);
      String setValue = '';

      if (values['type'] == 'DateTime?') {
        setValue = "instance.$filedName?.toIso8601String()";
      } else {
        setValue = "instance.$filedName";
      }

      if (beforeSave != null) {
        parseContent += "map['$jsonKey'] = $className.$beforeSave(map);\n";
      }
      jsonMapper += "'$jsonKey' : $setValue,\n";
      tableColumns.add("'$jsonKey'");
    });

    String toMapRelation = "\nList<String> preload = getPreload();\n";
    List<String> preloadRelations = [];

    visitor.relations.forEach((key, value) {
      if (value['eager'] == true) {
        relationContent +=
            "map['${toSnakeCase(key)}'] = toMap(instance.$key);\n";
      } else {
        preloadRelations.add(key);
        toMapRelation +=
            """
        if (preload.contains('$key')) {
          map['${toSnakeCase(key)}'] = toMap(instance.$key);
        }
        """;
      }
    });

    if (preloadRelations.isNotEmpty) {
      relationContent += toMapRelation;
    }

    return {
      'jsonMapper': jsonMapper,
      'parseContent': parseContent,
      'relationContent': relationContent,
      'tableColumns': tableColumns,
    };
  }
}
