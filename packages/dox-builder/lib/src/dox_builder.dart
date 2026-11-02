import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:dox_annotation/dox_annotation.dart';
import 'package:dox_builder/src/model_visitor.dart';
import 'package:dox_builder/src/openapi/dart_literal.dart';
import 'package:dox_builder/src/util.dart';
import 'package:source_gen/source_gen.dart';

class DoxModelBuilder extends GeneratorForAnnotation<DoxModel> {
  @override
  Future<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    String? tableName = annotation.objectValue
        .getField('table')
        ?.toStringValue();
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@DoxModel can only be used on a class.',
        element: element,
      );
    }
    String primaryKeySnakeCase =
        annotation.objectValue.getField('primaryKey')?.toStringValue() ?? 'id';
    String primaryKey = toCamelCase(primaryKeySnakeCase);
    DartType? keyType = annotation.objectValue
        .getField('primaryKeyType')
        ?.toTypeValue();
    String primaryKeyType = keyType == null
        ? 'int'
        : typeCode(keyType, element.library).replaceFirst('?', '');
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

    visitor.castSources = await _castSources(element, buildStep.resolver);
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
    String createdColumn = createdAt != null ? _str(createdAt) : 'null';
    String updatedColumn = updatedAt != null ? _str(updatedAt) : 'null';

    var r = _getRelationsCode(visitor);
    var map = _getCodeForToMap(visitor);

    String computedCode = _getCodeForComputedAndHooks(visitor);

    String softDeleteString = softDelete ? 'with SoftDeletes<$className>' : '';

    return """
    // ignore_for_file: always_specify_types

    class ${className}Generator extends Model<$className> $softDeleteString {
      @override
      String get primaryKey => ${_str(primaryKeySnakeCase)};

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
      ${_getCodeForCasts(visitor)}
      ${_getCodeForGlobalScopes(visitor)}

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

      ${_getCodeForSetColumnValue(visitor)}
      $computedCode
    }
    ${_getCodeForScopeExtension(visitor)}
    """;
  }

  /// [text] as a Dart string literal, with `\`, `'` and `$` escaped
  String _str(String text) => const DartLiteral().string(text);

  /// field name => source of the `cast:` argument of its @Column, read
  /// from the AST of the field, so the generated code can make the same
  /// cast. This also works for a model in a `part` file.
  Future<Map<String, String>> _castSources(
    ClassElement element,
    Resolver resolver,
  ) async {
    Map<String, String> casts = {};
    for (FieldElement field in element.fields) {
      if (!field.isOriginDeclaration || field.isStatic) continue;
      AstNode? node = await resolver.astNodeFor(field.firstFragment);
      FieldDeclaration? member = node?.thisOrAncestorOfType<FieldDeclaration>();
      if (member == null) continue;
      for (Annotation a in member.metadata) {
        if (a.name.name != 'Column') continue;
        for (Argument arg in a.arguments?.arguments ?? <Argument>[]) {
          if (arg is NamedArgument && arg.name.lexeme == 'cast') {
            casts[field.displayName] = arg.argumentExpression.toSource();
          }
        }
      }
    }
    return casts;
  }

  /// one static const cast object for each column with a cast
  String _getCodeForCasts(ModelVisitor visitor) {
    String content = '';
    visitor.columns.forEach((field, values) {
      if (values['cast'] != null && values['beforeGet'] == null) {
        content += "static const _${field}Cast = ${values['cast']};\n";
      }
    });
    return content;
  }

  String _getCodeForGlobalScopes(ModelVisitor visitor) {
    String className = visitor.className;
    String content = '';
    visitor.scopes.forEach((name, scope) {
      if (scope.$1) content += "'$name': $className.$name,";
    });
    if (content.isEmpty) return '';
    return '''
      @override
      Map<String, QueryBuilder<$className> Function(QueryBuilder<$className>)>
          get globalScopes => const {$content};
    ''';
  }

  /// the local scopes as methods on the query of the model
  String _getCodeForScopeExtension(ModelVisitor visitor) {
    String className = visitor.className;
    String content = '';
    visitor.scopes.forEach((name, scope) {
      if (scope.$1) return;
      MethodElement method = scope.$2;
      List<String> required = [];
      List<String> optional = [];
      List<String> named = [];
      List<String> args = ['this'];
      for (FormalParameterElement p in method.formalParameters.skip(1)) {
        String type = typeCode(p.type, method.library);
        String pName = p.displayName;
        String value = p.defaultValueCode != null
            ? ' = ${p.defaultValueCode}'
            : '';
        if (p.isNamed) {
          String req = p.isRequiredNamed ? 'required ' : '';
          named.add('$req$type $pName$value');
          args.add('$pName: $pName');
        } else if (p.isOptionalPositional) {
          optional.add('$type $pName$value');
          args.add(pName);
        } else {
          required.add('$type $pName');
          args.add(pName);
        }
      }
      List<String> params = [
        ...required,
        if (optional.isNotEmpty) '[${optional.join(', ')}]',
        if (named.isNotEmpty) '{${named.join(', ')}}',
      ];
      content +=
          '${typeCode(method.returnType, method.library)} '
          '$name(${params.join(', ')})'
          ' => $className.$name(${args.join(', ')});\n';
    });
    if (content.isEmpty) return '';
    return '''
    extension ${className}Scopes on QueryBuilder<$className> {
      $content
    }
    ''';
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
      content += "map[${_str(jsonKey)}] = instance.$getter;\n";
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

  /// relations that hold one model, not a list
  static const List<String> _singleRelations = <String>[
    'HasOne',
    'BelongsTo',
    'MorphOne',
    'MorphTo',
  ];

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

      /// with no related rows, reload() and preload give an empty list
      /// for a list relation and null for a nullable one-row relation,
      /// so the old value is not kept. A non nullable one-row field keeps
      /// the old guard.
      String result = 'result[i.tempIdValue.toString()]';
      bool single = _singleRelations.contains(value['relationType']);
      String setValue = !single
          ? "i.$key = $result ?? <${value['model']}>[];"
          : value['dataType'].toString().endsWith('?')
          ? "i.$key = $result;"
          : """if ($result != null) {
            i.$key = $result!;
          }""";

      content +=
          """
      static Future<void> $getFunctionName(List<Model<${visitor.className}>> list) async {
        var result = await get${value['relationType']}<${visitor.className}, ${value['model']}>($queryFunctionName(list), list);
        for (dynamic i in list) {
          $setValue
        }
      }

      static ${value['model']}? $queryFunctionName(List<Model<${visitor.className}>> list) {
        return ${lcFirst(value['relationType'])}<${visitor.className}, ${value['model']}>(list
          ${value['morphTo'] == true ? '' : ", () => ${value['model']}()"}
          ${_getParamKeyValue(value, 'name')}
          ${_getParamKeyValue(value, 'typeColumn')}
          ${_getParamKeyValue(value, 'idColumn')}
          ${_getParamKeyValue(value, 'ownerKey')}
          ${_getParamKeyValue(value, 'foreignKey')}
          ${_getParamKeyValue(value, 'localKey')}
          ${_getParamKeyValue(value, 'relatedKey')}
          ${_getParamKeyValue(value, 'pivotForeignKey')}
          ${_getParamKeyValue(value, 'pivotRelatedForeignKey')}
          ${_getParamKeyValue(value, 'pivotTable')}
          ${_getPivotParams(value)}
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

  /// `withPivot:` and `withTimestamps:` of a many to many relation
  String _getPivotParams(Map<String, dynamic> value) {
    List<String>? columns = value['withPivot'];
    String code = columns == null || columns.isEmpty
        ? ''
        : ', withPivot: const <String>[${columns.map(_str).join(', ')}]';
    if (value['withTimestamps'] == true) code += ', withTimestamps: true';
    return code;
  }

  String _getParamKeyValue(Map<String, dynamic> value, String key) {
    return value[key] != null ? ', $key: ${_str(value[key])}' : '';
  }

  String _getTableNameSetter(String? tableName) {
    return tableName != null
        ? """
      @override
      String get tableName => ${_str(tableName)};
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
      String key = _str(values['jsonKey']);
      String? beforeGet = values['beforeGet'];
      String setValue = '';

      if (beforeGet != null) {
        setValue = "$className.$beforeGet(m)";
      } else if (values['cast'] != null) {
        String as = values['nullable'] == false ? " as ${values['type']}" : '';
        setValue = "_${filedName}Cast.get(m[$key])$as";
      } else if (values['type'] == 'DateTime?') {
        setValue =
            """m[$key] is DateTime?
              ? m[$key] as DateTime?
              : DateTime.parse(m[$key] as String)
          """;
      } else {
        setValue = "m[$key] as ${values['type']}";
      }
      content += "..$filedName = $setValue\n";
    });
    return content += ';';
  }

  /// setColumnValue() sets a field by its column name. increment() and
  /// decrement() on a model use it. A value that is not of the field type
  /// is not set, and it returns false.
  String _getCodeForSetColumnValue(ModelVisitor visitor) {
    String className = visitor.className;
    String content = '';
    visitor.columns.forEach((fieldName, values) {
      String key = _str(values['jsonKey']);
      content +=
          """
        case $key:
          if (value is! ${values['type']}) return false;
          instance.$fieldName = value;
          return true;
      """;
    });
    return """
      @override
      bool setColumnValue(String column, dynamic value) {
        $className instance = this as $className;
        switch (column) {
          $content
        }
        return false;
      }
    """;
  }

  Map<String, dynamic> _getCodeForToMap(ModelVisitor visitor) {
    String jsonMapper = '';
    String parseContent = '';
    String relationContent = '';
    List<String> tableColumns = [];
    String className = visitor.className;
    visitor.columns.forEach((filedName, values) {
      String? beforeSave = values['beforeSave'];
      String key = _str(values['jsonKey']);
      String setValue = '';

      if (values['cast'] != null && values['beforeGet'] == null) {
        setValue = "_${filedName}Cast.set(instance.$filedName)";
      } else if (values['type'] == 'DateTime?') {
        setValue = "instance.$filedName?.toIso8601String()";
      } else {
        setValue = "instance.$filedName";
      }

      if (beforeSave != null) {
        parseContent += "map[$key] = $className.$beforeSave(map);\n";
      }
      jsonMapper += "$key : $setValue,\n";
      tableColumns.add(key);
    });

    String toMapRelation = "\nList<String> preload = getPreload();\n";
    List<String> preloadRelations = [];

    visitor.relations.forEach((key, value) {
      if (value['eager'] == true) {
        relationContent +=
            "map[${_str(toSnakeCase(key))}] = toMap(instance.$key);\n";
      } else {
        preloadRelations.add(key);
        toMapRelation +=
            """
        if (preload.contains(${_str(key)})) {
          map[${_str(toSnakeCase(key))}] = toMap(instance.$key);
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
